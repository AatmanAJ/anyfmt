import AppKit
import Combine
import HaloCore
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

    @Published var values: OptionValues { didSet { if values != oldValue { scheduleEstimate() } } }
    @Published private(set) var estimate: OptionsPanelController.Estimate?
    @Published private(set) var estimating = false
    @Published var rememberAsDefault = false
    @Published private(set) var presets: [ConversionPreset] = []
    @Published private(set) var savedPresetTitle: String?

    var estimator: (@Sendable (URL, FormatID, OptionValues) async -> OptionsPanelController.Estimate?)?
    var convert: () -> Void = {}
    var cancel: () -> Void = {}
    private var estimateTask: Task<Void, Never>?
    /// Debounce while a slider moves.
    static let estimateDelay: UInt64 = 250_000_000

    init(target: RouteTarget, values: OptionValues, input: URL?, presetStore: PresetStore) {
        self.target = target
        // Cloud runs are chosen on the wheel's cloud segments, not here.
        self.schema = OptionsSchema(target.schema.id, target.schema.specs.filter { $0.id != OptionKey.cloud })
        self.values = values
        self.input = input
        self.presetStore = presetStore
        self.title = Formats.label(target.format)
        presets = presetStore.presets(for: target.format)
    }

    func apply(_ preset: ConversionPreset) { values = PresetStore.validated(preset.values, against: schema) }

    func saveAsPreset() {
        let title = PresetNaming.summary(values, schema: schema)
            ?? String(localized: "Preset \(presetStore.allUserPresets().filter { $0.format == target.format }.count + 1)")
        let saved = presetStore.add(title, format: target.format, values: values)
        presets = presetStore.presets(for: target.format)
        savedPresetTitle = saved.title
    }

    func scheduleEstimate(immediately: Bool = false) {
        estimateTask?.cancel()
        guard let input, let estimator else {
            estimate = nil
            return
        }
        let format = target.format, values = values
        estimating = true
        estimateTask = Task { [weak self] in
            if !immediately { try? await Task.sleep(nanoseconds: Self.estimateDelay) }
            guard !Task.isCancelled else { return }
            let result = await estimator(input, format, values)
            guard !Task.isCancelled, let self else { return }
            self.estimate = result
            self.estimating = false
        }
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
                Text(verbatim: model.title)
                    .font(.haloDisplay(DesignTokens.Typeface.Size.displayL))
                    .displayTracking(DesignTokens.Typeface.Size.displayL)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let input = model.input {
                    Text(verbatim: "\(input.lastPathComponent) → \(model.title)")
                        .font(.system(size: DesignTokens.TypeRamp.body))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            EstimateTiles(estimate: model.estimate, estimating: model.estimating, hasInput: model.input != nil)
            if !model.presets.isEmpty {
                PresetRow(presets: model.presets) { model.apply($0) }
            }
            ScrollView {
                OptionsForm(schema: model.schema, values: $model.values, size: .compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 320)
            HStack {
                Toggle(String(localized: "Remember as default for \(model.title)",
                              comment: "Options panel checkbox, e.g. Remember as default for GIF"),
                       isOn: $model.rememberAsDefault)
                    .toggleStyle(.checkbox)
                Spacer()
                Button(String(localized: "Cancel", comment: "Options panel button")) { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Save as Preset", comment: "Options panel button")) { model.saveAsPreset() }
                Button(String(localized: "Convert", comment: "Options panel button that runs the conversion")) { model.convert() }
                    .keyboardShortcut(.defaultAction)
            }
            if let saved = model.savedPresetTitle {
                Text("Saved “\(saved)”. It’s on the wheel next time.", comment: "Options panel confirmation after saving a preset")
                    .font(.system(size: DesignTokens.TypeRamp.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Space.xl)
        .frame(width: 520)
        .font(.system(size: DesignTokens.TypeRamp.body))
        .tint(Color(nsColor: WheelTheme.style.accentColor))
    }
}

private struct EstimateTiles: View {
    let estimate: OptionsPanelController.Estimate?
    let estimating: Bool
    let hasInput: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Space.s) {
            tile(size, caption: sizeCaption)
            tile(estimate?.duration.map { Self.seconds($0) } ?? "—",
                 caption: String(localized: "Duration", comment: "Options panel estimate tile"))
            tile(estimate?.frames.map { "\($0)" } ?? "—",
                 caption: String(localized: "Frames", comment: "Options panel estimate tile"))
        }
        .opacity(estimating ? 0.6 : 1)
        .accessibilityElement(children: .combine)
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
        return "\(prefix)\(change > 0 ? "+" : "")\(change) % vs \(from)"
    }

    static func seconds(_ s: Double) -> String { s < 10 ? String(format: "%.1f s", s) : "\(Int(s.rounded())) s" }

    private func tile(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
            Text(verbatim: value)
                .font(.haloDisplay(DesignTokens.Typeface.Size.displayM))
                .monospacedDigit()
            Text(verbatim: caption)
                .font(.system(size: DesignTokens.TypeRamp.caption, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(DesignTokens.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile).fill(Color.primary.opacity(0.06)))
    }
}

private struct PresetRow: View {
    let presets: [ConversionPreset]
    let apply: (ConversionPreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Space.xs) {
                ForEach(presets) { preset in
                    Button(preset.title) { apply(preset) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(String(localized: "Use these options", comment: "Tooltip on a preset in the options panel"))
                }
            }
        }
    }
}
