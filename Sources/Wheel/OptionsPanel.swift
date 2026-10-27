import AppKit
import AVFoundation
import Combine
import AnyfmtCore
import SwiftUI

/// The pinned options panel: opened by a drop on a segment's tune lip, a drop
/// with ⌥ held, or ⌥-Return in keyboard mode (D-038). The drag is over, so the
/// panel can take focus and nothing can be mis-aimed. Every control comes from
/// the target's `OptionsSchema`, the same one Settings, presets and the CLI use.
@MainActor
final class OptionsPanelController: NSObject, NSWindowDelegate {
    /// What the estimate tiles show. The host fills it from `Estimator`.
    struct Estimate: Equatable, Sendable {
        var bytes: Int64?
        var duration: Double?
        var frames: Int?
        var inputBytes: Int64?
        var isExact = false
        /// Output width in pixels, when known (scales provisional GIF sizes).
        var pixelWidth: Double?
        /// Scaled from the last measured estimate while a fresh one is computed.
        var isProvisional = false
    }

    /// Estimates for (first input, target, options). nil = none available.
    var estimator: (@Sendable (URL, FormatID, OptionValues) async -> Estimate?)?
    /// Convert pressed.
    var onConvert: ((RouteTarget, OptionValues, [URL], [NSFilePromiseReceiver], CGPoint) -> Void)?
    /// "Remember as default" was on when Convert was pressed.
    var onRememberDefault: ((FormatID, OptionValues) -> Void)?
    var presetStore: PresetStore = .shared

    private(set) var window: NSPanel?
    private(set) var model: OptionsPanelModel?
    private var files: [URL] = []
    private var promises: [NSFilePromiseReceiver] = []
    private var point: CGPoint = .zero

    var isShown: Bool { window?.isVisible == true }

    func show(target: RouteTarget, values: OptionValues, files: [URL], promises: [NSFilePromiseReceiver], near point: CGPoint) {
        close()
        self.files = files
        self.promises = promises
        self.point = point
        let model = OptionsPanelModel(target: target, values: values, input: files.first, presetStore: presetStore)
        model.estimator = estimator
        model.convert = { [weak self] in self?.convert() }
        model.cancel = { [weak self] in self?.close() }
        self.model = model

        let host = NSHostingView(rootView: OptionsPanelView(model: model))
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.title = model.title
        panel.contentView = host
        panel.delegate = self
        panel.setFrameOrigin(Self.origin(for: host.fittingSize, near: point))
        window = panel
        if #available(macOS 14.0, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        panel.makeKeyAndOrderFront(nil)
        model.scheduleEstimate(immediately: true)
    }

    func close() {
        model?.cancelEstimate()
        window?.delegate = nil
        window?.close()
        window = nil
        model = nil
    }

    func windowWillClose(_ notification: Notification) {
        model?.cancelEstimate()
        window = nil
        model = nil
    }

    private func convert() {
        guard let model else { return }
        let values = model.values
        if model.rememberAsDefault { onRememberDefault?(model.target.format, values) }
        let handler = onConvert, target = model.target, files = files, promises = promises, point = point
        close()
        handler?(target, values, files, promises, point)
    }

    /// Centred above the drop point, kept inside that screen's visible frame.
    static func origin(for size: CGSize, near point: CGPoint, screens: [NSScreen] = NSScreen.screens) -> CGPoint {
        let screen = screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var x = point.x - size.width / 2
        var y = point.y - size.height / 2
        x = min(max(x, visible.minX + 12), visible.maxX - size.width - 12)
        y = min(max(y, visible.minY + 12), visible.maxY - size.height - 12)
        return CGPoint(x: x, y: y)
    }
}

@MainActor
final class OptionsPanelModel: ObservableObject {
    let target: RouteTarget
    let schema: OptionsSchema
    let input: URL?
    let title: String
    private let presetStore: PresetStore

    @Published var values: OptionValues { didSet { if values != oldValue { valuesChanged() } } }
    /// A fresh estimate is being computed; the numbers shown are provisional.
    @Published private(set) var refining = false
    /// The last measured estimate and the options it was measured with.
    private var base: (values: OptionValues, estimate: OptionsPanelController.Estimate)?
    @Published private(set) var estimate: OptionsPanelController.Estimate?
    @Published private(set) var estimating = false
    @Published var rememberAsDefault = false
    @Published private(set) var presets: [ConversionPreset] = []
    @Published private(set) var savedPresetTitle: String?

    var estimator: (@Sendable (URL, FormatID, OptionValues) async -> OptionsPanelController.Estimate?)?
    var convert: () -> Void = {}
    var cancel: () -> Void = {}
    private var estimateTask: Task<Void, Never>?
    /// Debounce while choices change (the provisional numbers cover the gap).
    static let estimateDelay: UInt64 = 200_000_000

    init(target: RouteTarget, values: OptionValues, input: URL?, presetStore: PresetStore) {
        self.target = target
        // Cloud runs are chosen on the wheel's cloud segments, not here.
        self.schema = OptionsSchema(target.schema.id, target.schema.specs.filter { $0.id != OptionKey.cloud })
        self.values = values
        self.input = input
        self.presetStore = presetStore
        self.title = Formats.label(target.format)
        presets = presetStore.presets(for: target.format)
        loadVideoWidth()
    }

    func apply(_ preset: ConversionPreset) { values = PresetStore.validated(preset.values, against: schema) }

    func saveAsPreset() {
        let title = PresetNaming.summary(values, schema: schema)
            ?? String(localized: "Preset \(presetStore.allUserPresets().filter { $0.format == target.format }.count + 1)")
        let saved = presetStore.add(title, format: target.format, values: values)
        presets = presetStore.presets(for: target.format)
        savedPresetTitle = saved.title
    }

    private func valuesChanged() {
        // Instant feedback: scale the last measurement for the new options, then refine.
        if let p = provisional(for: values) { estimate = p }
        scheduleEstimate()
    }

    /// Option value as a number (choices are stored as strings), falling back to the schema default.
    private func number(_ v: OptionValues, _ key: String) -> Double? {
        if let x = Double(v[key]?.description ?? "") { return x }
        return schema.spec(key).flatMap { Double($0.defaultValue.description) }
    }

    /// The last measured estimate scaled for `v`: frames = duration × fps exactly;
    /// GIF bytes ∝ fps × width² × colours^0.3 (a first-order model, refined by the
    /// real sample encode a moment later). nil when there's no basis yet, or for
    /// targets where a scale model would mislead.
    func provisional(for v: OptionValues) -> OptionsPanelController.Estimate? {
        guard let base, target.format == Formats.gif else { return nil }
        var e = base.estimate
        e.isExact = false
        e.isProvisional = true
        let fps0 = number(base.values, OptionKey.fps), fps1 = number(v, OptionKey.fps)
        if let d = e.duration, let fps1, fps1 > 0 { e.frames = Int((d * fps1).rounded()) }
        guard var bytes = base.estimate.bytes.map(Double.init) else { return e }
        if let fps0, let fps1, fps0 > 0, fps1 > 0 { bytes *= fps1 / fps0 }
        let w0 = effectiveWidth(base.values, measured: base.estimate.pixelWidth)
        let w1 = effectiveWidth(v, measured: base.estimate.pixelWidth)
        if let w0, let w1, w0 > 0, w1 > 0 {
            bytes *= (w1 / w0) * (w1 / w0)
            e.pixelWidth = w1
        } else if number(v, OptionKey.gifWidth) != number(base.values, OptionKey.gifWidth) {
            // The width changed to something we can't size yet (Keep, source unknown): don't guess.
            e.bytes = nil
            e.pixelWidth = nil
            return e
        }
        if let c0 = number(base.values, OptionKey.gifColors), let c1 = number(v, OptionKey.gifColors), c0 > 0, c1 > 0 {
            bytes *= pow(c1 / c0, 0.3)
        }
        e.bytes = Int64(bytes.rounded())
        return e
    }

    /// GIF width for `v`: the option ("Keep" = the source), never wider than the
    /// source. nil when it can't be known yet, so no number is guessed.
    private func effectiveWidth(_ v: OptionValues, measured: Double?) -> Double? {
        let source = videoWidth ?? keptWidth(measured)
        guard let w = number(v, OptionKey.gifWidth) else { return source }
        if w <= 0 { return source }
        return source.map { min(w, $0) } ?? w
    }

    /// The measured output width is the source width only when it was measured with "Keep".
    private func keptWidth(_ measured: Double?) -> Double? {
        guard let base, let w = number(base.values, OptionKey.gifWidth), w <= 0 else { return nil }
        return measured
    }

    /// The input video's display width (read once from the file; cheap).
    @Published private(set) var videoWidth: Double?

    private func loadVideoWidth() {
        guard let input, target.format == Formats.gif else { return }
        Task { [weak self] in
            let asset = AVURLAsset(url: input)
            guard let track = try? await asset.loadTracks(withMediaType: .video).first,
                  let (size, transform) = try? await track.load(.naturalSize, .preferredTransform) else { return }
            let shown = size.applying(transform)
            self?.videoWidth = abs(shown.width)
        }
    }

    /// The preset these options match exactly, if any (its chip shows selected).
    func matchingPreset() -> ConversionPreset? {
        presets.first { preset in
            let v = PresetStore.validated(preset.values, against: schema)
            return v.values.allSatisfy { key, value in (values[key] ?? schema.spec(key)?.defaultValue)?.description == value.description }
        }
    }

    /// "≈ 2.4 MB" for a choice chip: what picking it would roughly produce.
    func hint(for spec: OptionSpec, choice: OptionChoice) -> String? {
        guard [OptionKey.fps, OptionKey.gifWidth, OptionKey.gifColors].contains(spec.id) else { return nil }
        var v = values
        v[spec.id] = .string(choice.id)
        guard let bytes = provisional(for: v)?.bytes else { return nil }
        return "≈ " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func scheduleEstimate(immediately: Bool = false) {
        estimateTask?.cancel()
        guard let input, let estimator else {
            estimate = nil
            return
        }
        let format = target.format, values = values
        estimating = true
        refining = base != nil
        estimateTask = Task { [weak self] in
            if !immediately { try? await Task.sleep(nanoseconds: Self.estimateDelay) }
            guard !Task.isCancelled else { return }
            let result = await estimator(input, format, values)
            guard !Task.isCancelled, let self else { return }
            self.estimate = result
            if let result { self.base = (values, result) }
            self.estimating = false
            self.refining = false
        }
    }

    func overrideEstimate(_ e: OptionsPanelController.Estimate?) {
        cancelEstimate()
        estimate = e
        if let e { base = (values, e) }
        estimating = false
        refining = false
    }

    func cancelEstimate() {
        estimateTask?.cancel()
        estimateTask = nil
    }
}

/// A short title for a preset from its values: "480 px · 10 fps".
enum PresetNaming {
    static func summary(_ values: OptionValues, schema: OptionsSchema) -> String? {
        let parts: [String] = schema.specs.compactMap { spec in
            guard let v = values[spec.id], v != spec.defaultValue else { return nil }
            switch spec.kind {
            case .choice(let choices):
                return choices.first { $0.id == v.description }?.label
            case .toggle:
                if case .bool(let on) = v { return on ? spec.label : nil }
                return nil
            default:
                return "\(spec.label) \(v)"
            }
        }
        return parts.isEmpty ? nil : parts.prefix(3).joined(separator: " · ")
    }
}

struct OptionsPanelView: View {
    @ObservedObject var model: OptionsPanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.l) {
            HStack(alignment: .firstTextBaseline) {
                DisplayText(model.title, size: DesignTokens.Typeface.Size.displayXL)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let input = model.input {
                    Text(verbatim: "\(input.lastPathComponent) → \(model.title)")
                        .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                        .foregroundStyle(Color.anyfmtSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            EstimateTiles(estimate: model.estimate, refining: model.refining, hasInput: model.input != nil)
            if !model.presets.isEmpty {
                PresetRow(presets: model.presets, selectedID: model.matchingPreset()?.id) { model.apply($0) }
            }
            ScrollView {
                PanelOptions(model: model)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 340)
            HStack(spacing: DesignTokens.Space.s) {
                Toggle(String(localized: "Make default for \(model.title)",
                              comment: "Options panel checkbox: use these options for every future conversion to this format, e.g. Make default for GIF"),
                       isOn: $model.rememberAsDefault)
                    .toggleStyle(.checkbox)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Color.anyfmtSecondaryText)
                Spacer()
                Button(String(localized: "Cancel", comment: "Options panel button")) { model.cancel() }
                    .buttonStyle(.anyfmtQuiet)
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Save as Preset", comment: "Options panel button")) { model.saveAsPreset() }
                    .buttonStyle(.anyfmtSecondary)
                Button(String(localized: "Convert", comment: "Options panel button that runs the conversion")) { model.convert() }
                    .buttonStyle(.anyfmtPrimary)
                    .keyboardShortcut(.defaultAction)
            }
            if let saved = model.savedPresetTitle {
                Label {
                    Text("Saved “\(saved)”. It’s on the wheel next time.", comment: "Options panel confirmation after saving a preset")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentText)
                }
                .font(.system(size: DesignTokens.TypeRamp.caption))
                .foregroundStyle(Color.anyfmtSecondaryText)
            }
        }
        .padding(DesignTokens.Space.xl + DesignTokens.Space.xs)
        .frame(width: 560)
        .font(.system(size: DesignTokens.TypeRamp.body))
        .tint(Color.iris)
        .anyfmtWindowBackground()
    }
}

private struct EstimateTiles: View {
    let estimate: OptionsPanelController.Estimate?
    let refining: Bool
    let hasInput: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DesignTokens.Component.Tile.spacing) {
            StatNumeral(value: size, caption: sizeCaption, hero: estimate?.bytes != nil)
            StatNumeral(value: estimate?.duration.map { Self.seconds($0) } ?? "—",
                        caption: String(localized: "Duration", comment: "Options panel estimate tile"))
            StatNumeral(value: estimate?.frames.map { "\($0)" } ?? "—",
                        caption: String(localized: "Frames", comment: "Options panel estimate tile"))
        }
        // Numbers change in place (provisional first, then measured): no dimming, no jump.
        .animation(AnyfmtMotion.snap.animation(reduceMotion: reduceMotion), value: estimate)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Estimate", comment: "VoiceOver label of the estimate tiles"))
    }

    private var size: String {
        guard let bytes = estimate?.bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private var sizeCaption: String {
        guard hasInput else { return String(localized: "Size known after receiving", comment: "Estimate tile for promised files") }
        guard let bytes = estimate?.bytes, let input = estimate?.inputBytes, input > 0 else {
            return String(localized: "Estimated size", comment: "Options panel estimate tile")
        }
        let change = Int((Double(bytes) / Double(input) - 1) * 100)
        let from = ByteCountFormatter.string(fromByteCount: input, countStyle: .file)
        let prefix = estimate?.isExact == true ? "" : "≈ "
        let line = "\(prefix)\(change > 0 ? "+" : "")\(change) % vs \(from)"
        return refining ? line + " · " + String(localized: "updating", comment: "Estimate caption while a fresh estimate is measured") : line
    }

    static func seconds(_ s: Double) -> String { s < 10 ? String(format: "%.1f s", s) : "\(Int(s.rounded())) s" }
}

private struct PresetRow: View {
    let presets: [ConversionPreset]
    var selectedID: String?
    let apply: (ConversionPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Space.xs) {
                ForEach(presets) { preset in
                    let on = preset.id == selectedID
                    Button(preset.title) { apply(preset) }
                        .buttonStyle(.plain)
                        .font(.system(size: DesignTokens.TypeRamp.body, weight: on ? .bold : .medium))
                        .foregroundStyle(on ? Color.token(DesignTokens.Semantic.onAccentPrimary) : Color.anyfmtInk)
                        .padding(.horizontal, DesignTokens.Space.m)
                        .padding(.vertical, DesignTokens.Space.xs + 2)
                        .background(Capsule().fill(on ? Color.iris : Color.anyfmtTile))
                        .contentShape(Capsule())
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .help(String(localized: "Use these options", comment: "Tooltip on a preset in the options panel"))
                }
            }
        }
    }
}

/// The panel's options: choices as chip rows (with a size hint per chip for GIF),
/// everything else through the shared schema form.
private struct PanelOptions: View {
    @ObservedObject var model: OptionsPanelModel

    var body: some View {
        let visible = OptionsFormLogic.visibleSpecs(model.schema, model.values)
        let rest = visible.filter { if case .choice(let c) = $0.kind { return c.count > 6 } else { return true } }
        VStack(alignment: .leading, spacing: DesignTokens.Space.l) {
            ForEach(visible) { spec in
                if case .choice(let choices) = spec.kind, choices.count <= 6 {
                    PanelChoiceRow(spec: spec, choices: choices, values: $model.values) { model.hint(for: spec, choice: $0) }
                }
            }
            if !rest.isEmpty {
                OptionsForm(schema: OptionsSchema(model.schema.id, rest), values: $model.values, size: .compact)
            }
        }
    }
}

/// One option as a row of equal chips: selected = cobalt with bold white text
/// (and the VoiceOver "selected" trait), each with its rough size underneath.
struct PanelChoiceRow: View {
    let spec: OptionSpec
    let choices: [OptionChoice]
    @Binding var values: OptionValues
    var hint: (OptionChoice) -> String? = { _ in nil }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedID: String { (values[spec.id] ?? spec.defaultValue).description }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            Text(verbatim: spec.label)
                .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold))
                .foregroundStyle(Color.anyfmtSecondaryText)
            HStack(spacing: DesignTokens.Space.xs) {
                ForEach(choices) { choice in chip(choice) }
            }
            if let help = spec.help {
                Text(verbatim: help)
                    .font(.system(size: DesignTokens.TypeRamp.caption))
                    .foregroundStyle(Color.anyfmtSecondaryText)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: spec.label))
    }

    private func chip(_ choice: OptionChoice) -> some View {
        let selected = choice.id == selectedID
        let sub = hint(choice)
        return Button {
            withAnimation(AnyfmtMotion.snap.animation(reduceMotion: reduceMotion)) { values[spec.id] = .string(choice.id) }
        } label: {
            VStack(spacing: 1) {
                Text(verbatim: choice.label)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: selected ? .bold : .medium))
                if let sub {
                    Text(verbatim: sub)
                        .font(.system(size: DesignTokens.TypeRamp.micro, weight: .medium))
                        .monospacedDigit()
                        .opacity(selected ? 0.9 : 0.75)
                }
            }
            .lineLimit(1)
            .foregroundStyle(selected ? Color.token(DesignTokens.Semantic.onAccentPrimary) : Color.anyfmtInk)
            .frame(minWidth: 58)
            .padding(.horizontal, DesignTokens.Space.s)
            .padding(.vertical, sub == nil ? DesignTokens.Space.xs + 2 : DesignTokens.Space.xs)
            .background(Capsule().fill(selected ? Color.iris : Color.anyfmtTile))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: sub.map { "\(choice.label), \($0)" } ?? choice.label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
