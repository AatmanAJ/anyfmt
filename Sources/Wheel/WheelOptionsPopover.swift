import AppKit
import AnyfmtCore
import SwiftUI

/// Options popover for a conversion target, built from `RouteTarget.schema`
/// (quality, size, DPI, codecs…). Opened by right-click or by holding the
/// pointer on a segment.
///
/// Mid-drag the mouse button is held, so controls can't be clicked yet: the
/// popover shows the values that will be used and is itself a drop target.
/// Dropping the files on it ends the drag, makes the controls live, and
/// "Convert" applies them.
@MainActor
final class WheelOptionsPopover: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private var model: WheelOptionsModel?
    private(set) var target: RouteTarget?
    private(set) var itemID: String?

    var onApply: ((RouteTarget, OptionValues) -> Void)?
    var onDrop: ((NSDraggingInfo) -> Bool)?
    var onClose: (() -> Void)?
    var draggedTypes: [NSPasteboard.PasteboardType] = []

    var isShown: Bool { popover.isShown }
    var window: NSWindow? { popover.contentViewController?.view.window }

    override init() {
        super.init()
        popover.delegate = self
        popover.animates = true
    }

    func show(target: RouteTarget, itemID: String, values: OptionValues, interactive: Bool, cloud: CloudSegments,
              relativeTo rect: NSRect, of view: NSView, edge: NSRectEdge) {
        self.target = target
        self.itemID = itemID
        let title = String(localized: "\(Formats.label(target.format)) options",
                           comment: "Title of the conversion options popover, e.g. MP4 options")
        let schema = Brand.cloudAvailable ? target.schema
            : OptionsSchema(target.schema.id, target.schema.specs.filter { $0.id != OptionKey.cloud })
        let model = WheelOptionsModel(title: title, schema: schema, values: values, interactive: interactive)
        model.allowCloud = { [weak cloud] in cloud?.allowsCloudJobs() ?? false }
        model.apply = { [weak self] values in
            guard let self, let target = self.target else { return }
            self.onApply?(target, values)
        }
        model.cancel = { [weak self] in self?.close() }
        self.model = model
        let host = NSHostingView(rootView: WheelOptionsView(model: model))
        let container = OptionsDropView(content: host)
        container.registerForDraggedTypes(draggedTypes)
        container.onDrop = { [weak self] info in self?.onDrop?(info) ?? false }
        let controller = NSViewController()
        controller.view = container
        popover.contentViewController = controller
        popover.contentSize = host.fittingSize
        popover.behavior = interactive ? .transient : .applicationDefined
        popover.show(relativeTo: rect, of: view, preferredEdge: edge)
    }

    /// The drag ended on the popover: controls become usable.
    func makeInteractive() {
        model?.interactive = true
        popover.behavior = .transient
        window?.makeKey()
    }

    func close() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        target = nil
        itemID = nil
        model = nil
        onClose?()
    }

    /// Popover edge that points away from the hub for a segment at `angle` (clock radians).
    static func edge(forClockAngle angle: CGFloat) -> NSRectEdge {
        let x = sin(angle), y = cos(angle)
        if abs(x) >= abs(y) { return x >= 0 ? .maxX : .minX }
        return y >= 0 ? .maxY : .minY
    }
}

/// Hosts the SwiftUI content and accepts drops (mid-drag "drop here to adjust").
private final class OptionsDropView: NSView {
    var onDrop: ((NSDraggingInfo) -> Bool)?

    init(content: NSView) {
        super.init(frame: NSRect(origin: .zero, size: content.fittingSize))
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool { onDrop?(sender) ?? false }
}

@MainActor
final class WheelOptionsModel: ObservableObject {
    let title: String
    let schema: OptionsSchema
    @Published var values: OptionValues
    @Published var interactive: Bool
    var allowCloud: () -> Bool = { false }
    var apply: (OptionValues) -> Void = { _ in }
    var cancel: () -> Void = {}

    init(title: String, schema: OptionsSchema, values: OptionValues, interactive: Bool) {
        self.title = title
        self.schema = schema
        self.values = values
        self.interactive = interactive
    }

    func value(_ spec: OptionSpec) -> OptionValue { values[spec.id] ?? spec.defaultValue }

    var visibleSpecs: [OptionSpec] {
        schema.specs.filter { spec in
            spec.visibleWhen.allSatisfy { key, expected in
                (values[key] ?? schema.spec(key)?.defaultValue) == expected
            }
        }
    }

    func binding(bool spec: OptionSpec) -> Binding<Bool> {
        Binding(get: { [weak self] in
            guard let self else { return false }
            if case .bool(let b) = self.value(spec) { return b }
            return false
        }, set: { [weak self] new in
            guard let self else { return }
            // The cloud toggle is a Pro feature: the gate shows the explainer when needed.
            if spec.id == OptionKey.cloud && new && !self.allowCloud() { return }
            self.values[spec.id] = .bool(new)
        })
    }

    func binding(number spec: OptionSpec) -> Binding<Double> {
        Binding(get: { [weak self] in
            guard let self else { return 0 }
            switch self.value(spec) {
            case .int(let i): return Double(i)
            case .double(let d): return d
            case .string(let s): return Double(s) ?? 0
            case .bool(let b): return b ? 1 : 0
            }
        }, set: { [weak self] new in
            guard let self else { return }
            if case .decimal = spec.kind { self.values[spec.id] = .double(new) } else { self.values[spec.id] = .int(Int(new.rounded())) }
        })
    }

    func binding(text spec: OptionSpec) -> Binding<String> {
        Binding(get: { [weak self] in self?.value(spec).description ?? "" },
                set: { [weak self] new in self?.values[spec.id] = .string(new) })
    }

    /// File sizes are edited in megabytes.
    func binding(megabytes spec: OptionSpec) -> Binding<Double> {
        Binding(get: { [weak self] in
            guard let self else { return 0 }
            if case .int(let bytes) = self.value(spec) { return Double(bytes) / 1_000_000 }
            return 0
        }, set: { [weak self] new in self?.values[spec.id] = .int(Int(max(0.01, new) * 1_000_000)) })
    }

    func binding(color spec: OptionSpec) -> Binding<Color> {
        Binding(get: { [weak self] in
            Color(nsColor: NSColor(hexString: self?.value(spec).description ?? "") ?? .white)
        }, set: { [weak self] new in
            self?.values[spec.id] = .string(NSColor(new).hexString)
        })
    }
}

struct WheelOptionsView: View {
    @ObservedObject var model: WheelOptionsModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
            Text(verbatim: model.title)
                .font(.system(size: DesignTokens.TypeRamp.title, weight: .semibold))
            if model.visibleSpecs.isEmpty {
                Text("No options for this format.", comment: "Options popover with nothing to set")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.visibleSpecs) { spec in
                row(spec)
            }
            if !model.interactive {
                Label {
                    Text("Drop here to adjust these before converting", comment: "Hint in the options popover while dragging")
                } icon: {
                    Image(systemName: "arrow.down.to.line")
                }
                .font(.system(size: DesignTokens.TypeRamp.caption))
                .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button(String(localized: "Cancel", comment: "Options popover button")) { model.cancel() }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "Convert", comment: "Options popover button that runs the conversion")) {
                    model.apply(model.values)
                }
                .keyboardShortcut(.defaultAction)
            }
            .disabled(!model.interactive)
        }
        .padding(DesignTokens.Space.l)
        .frame(width: 280)
        .tint(Color(nsColor: WheelTheme.style.accentColor))
        .font(.system(size: DesignTokens.TypeRamp.body))
        .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: model.visibleSpecs.map(\.id))
    }

    @ViewBuilder
    private func row(_ spec: OptionSpec) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            switch spec.kind {
            case .toggle:
                Toggle(spec.label, isOn: model.binding(bool: spec))
            case .slider(let min, let max, let step, let unit):
                HStack {
                    Text(verbatim: spec.label)
                    Spacer()
                    Text(verbatim: "\(Int(model.binding(number: spec).wrappedValue))\(unit ?? "")")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: model.binding(number: spec), in: Double(min)...Double(max), step: Double(step))
            case .decimal(let min, let max, let step):
                HStack {
                    Text(verbatim: spec.label)
                    Spacer()
                    Text(model.binding(number: spec).wrappedValue, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: model.binding(number: spec), in: min...max, step: step)
            case .integer(_, _, let unit):
                LabeledField(label: spec.label, unit: unit) {
                    TextField(spec.label, value: model.binding(number: spec), format: .number)
                }
            case .choice(let choices):
                if choices.count <= 3 {
                    // Segmented controls get the full width under their label.
                    Text(verbatim: spec.label)
                    Picker(spec.label, selection: model.binding(text: spec)) {
                        ForEach(choices) { Text(verbatim: $0.label).tag($0.id) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } else {
                    HStack {
                        Text(verbatim: spec.label)
                        Spacer()
                        Picker(spec.label, selection: model.binding(text: spec)) {
                            ForEach(choices) { Text(verbatim: $0.label).tag($0.id) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            case .fileSize:
                LabeledField(label: spec.label, unit: "MB") {
                    TextField(spec.label, value: model.binding(megabytes: spec), format: .number.precision(.fractionLength(0...2)))
                }
            case .color:
                ColorPicker(spec.label, selection: model.binding(color: spec), supportsOpacity: false)
            case .pageRange, .timeRange, .text, .rect:
                LabeledField(label: spec.label, unit: nil) {
                    TextField(placeholder(for: spec), text: model.binding(text: spec))
                }
            }
            if let help = spec.help {
                Text(verbatim: help)
                    .font(.system(size: DesignTokens.TypeRamp.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!model.interactive)
    }

    private func placeholder(for spec: OptionSpec) -> String {
        switch spec.kind {
        case .pageRange: String(localized: "All pages", comment: "Placeholder of an empty page range")
        case .timeRange: String(localized: "Whole file", comment: "Placeholder of an empty time range")
        default: spec.label
        }
    }

}

private struct LabeledField<Field: View>: View {
    let label: String
    let unit: String?
    @ViewBuilder let field: () -> Field

    var body: some View {
        HStack {
            Text(verbatim: label)
            Spacer()
            field()
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .labelsHidden()
            if let unit { Text(verbatim: unit).foregroundStyle(.secondary) }
        }
    }
}

extension NSColor {
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let r = CGFloat((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = CGFloat((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = CGFloat((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? CGFloat(v & 0xFF) / 255 : 1
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}
