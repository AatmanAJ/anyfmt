import AppKit
import SwiftUI
import HaloCore

/// Schema-driven options editor shared by Settings › Formats, the wheel's
/// options popover and the tool editors.
///
/// - `.regular` emits one row per visible option, meant to sit inside a
///   grouped `Form` section (labels left, controls right, help as a subtitle).
/// - `.compact` is self-contained: a vertical stack with labels above small
///   controls, for popovers and editor sidebars.
///
/// Values the user never touched stay absent from `values` (absent = schema
/// default), so engines keep honouring their own defaults.
struct OptionsForm: View {
    enum Size { case regular, compact }

    let schema: OptionsSchema
    @Binding var values: OptionValues
    var size: Size = .regular

    init(schema: OptionsSchema, values: Binding<OptionValues>, size: Size = .regular) {
        self.schema = schema
        self._values = values
        self.size = size
    }

    var body: some View {
        let visible = OptionsFormLogic.visibleSpecs(schema, values)
        switch size {
        case .regular:
            ForEach(visible) { spec in
                OptionRow(spec: spec, value: binding(for: spec), compact: false)
            }
        case .compact:
            VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
                ForEach(visible) { spec in
                    OptionRow(spec: spec, value: binding(for: spec), compact: true)
                }
            }
            .controlSize(.small)
            .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: visible.map(\.id))
        }
    }

    private func binding(for spec: OptionSpec) -> Binding<OptionValue> {
        Binding(
            get: { OptionsFormLogic.effectiveValue(spec, in: values) },
            set: { values[spec.id] = OptionsFormLogic.coerce($0, to: spec.kind, default: spec.defaultValue) }
        )
    }
}

// MARK: - One row

private struct OptionRow: View {
    let spec: OptionSpec
    @Binding var value: OptionValue
    let compact: Bool

    var body: some View {
        switch spec.kind {
        case .toggle where compact:
            HStack {
                Text(verbatim: spec.label)
                    .font(.system(size: DesignTokens.TypeRamp.label, weight: .medium))
                Spacer(minLength: DesignTokens.Space.s)
                Toggle(isOn: boolBinding) { Text(verbatim: spec.label) }
                    .labelsHidden()
                    .toggleStyle(HaloSwitchStyle())
                    .controlSize(.mini)
            }
            .accessibilityIdentifier("option.\(spec.id)")
        case .toggle:
            Toggle(isOn: boolBinding) { labelTexts }
                .toggleStyle(HaloSwitchStyle())
                .accessibilityIdentifier("option.\(spec.id)")
        default:
            labeled { control }
                .accessibilityIdentifier("option.\(spec.id)")
        }
    }

    @ViewBuilder private var labelTexts: some View {
        Text(verbatim: spec.label)
        if let help = spec.help, !compact { Text(verbatim: help) }
    }

    @ViewBuilder private func labeled<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if compact {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                Text(verbatim: spec.label)
                    .font(.system(size: DesignTokens.TypeRamp.label - 1, weight: .medium))
                    .foregroundStyle(Color.haloSecondaryText)
                content()
                if let help = spec.help {
                    Text(verbatim: help)
                        .font(.system(size: DesignTokens.TypeRamp.caption))
                        .foregroundStyle(Color.haloSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            LabeledContent { content() } label: { labelTexts }
        }
    }

    @ViewBuilder private var control: some View {
        switch spec.kind {
        case .slider(let lo, let hi, let step, let unit):
            NumberSlider(value: intAsDouble, range: Double(lo)...Double(max(hi, lo + 1)), step: Double(max(step, 1)),
                         decimals: 0, unit: unit, signed: false, compact: compact)
        case .decimal(let lo, let hi, let step):
            NumberSlider(value: doubleBinding, range: lo...max(hi, lo + 0.0001), step: step,
                         decimals: OptionsFormLogic.decimals(for: step), unit: nil, signed: lo < 0, compact: compact)
        case .integer(let lo, let hi, let unit):
            IntegerField(value: intBinding, range: lo...max(hi, lo), unit: unit)
        case .choice(let choices):
            ChoicePicker(choices: choices, selection: stringBinding, compact: compact)
        case .fileSize:
            FileSizeField(bytes: intBinding)
        case .pageRange:
            ValidatedTextField(text: stringBinding, prompt: String(localized: "All pages"),
                               validate: OptionsFormLogic.validatePageRange, compact: compact)
        case .timeRange:
            ValidatedTextField(text: stringBinding, prompt: String(localized: "Whole file"),
                               validate: OptionsFormLogic.validateTimeRange, compact: compact)
        case .text:
            ValidatedTextField(text: stringBinding, prompt: "", validate: { _ in nil }, compact: compact)
        case .color:
            HexColorField(text: stringBinding)
        case .rect:
            RectFields(text: stringBinding)
        case .toggle:
            EmptyView()
        }
    }

    // MARK: Typed bindings

    private var intBinding: Binding<Int> {
        Binding(get: { Int(OptionsFormLogic.number(value) ?? 0) }, set: { value = .int($0) })
    }

    private var intAsDouble: Binding<Double> {
        Binding(get: { OptionsFormLogic.number(value) ?? 0 }, set: { value = .int(Int($0.rounded())) })
    }

    private var doubleBinding: Binding<Double> {
        Binding(get: { OptionsFormLogic.number(value) ?? 0 }, set: { value = .double($0) })
    }

    private var boolBinding: Binding<Bool> {
        Binding(get: { OptionsFormLogic.bool(value) ?? false }, set: { value = .bool($0) })
    }

    private var stringBinding: Binding<String> {
        Binding(get: { value.description }, set: { value = .string($0) })
    }
}

// MARK: - Controls

/// Slider with a live value read-out. Snaps in the binding instead of using
/// `Slider(step:)`, which would draw a tick for every step.
private struct NumberSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let decimals: Int
    let unit: String?
    let signed: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Space.s) {
            Slider(value: Binding(get: { value }, set: { value = OptionsFormLogic.snap($0, min: range.lowerBound, max: range.upperBound, step: step) }),
                   in: range)
                .labelsHidden()
                .tint(Color.iris)
                .frame(minWidth: compact ? 120 : 150, maxWidth: compact ? .infinity : 240)
            Text(verbatim: readout)
                .font(.system(size: compact ? DesignTokens.TypeRamp.label - 1 : DesignTokens.TypeRamp.body).monospacedDigit())
                .foregroundStyle(Color.haloSecondaryText)
                .frame(minWidth: compact ? 38 : 48, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: readout))
    }

    private var readout: String {
        let s = OptionsFormLogic.display(value, decimals: decimals, unit: unit)
        return signed && value > 0 ? "+" + s : s
    }
}

private struct IntegerField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String?

    var body: some View {
        HStack(spacing: DesignTokens.Space.xs + 2) {
            TextField("", value: Binding(get: { value }, set: { value = OptionsFormLogic.clamp($0, range.lowerBound, range.upperBound) }),
                      format: .number.grouping(.never))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
            if let unit, !unit.isEmpty {
                Text(verbatim: unit).foregroundStyle(Color.haloSecondaryText)
            }
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
    }
}

private struct ChoicePicker: View {
    let choices: [OptionChoice]
    @Binding var selection: String
    let compact: Bool

    var body: some View {
        let picker = Picker("", selection: $selection) {
            ForEach(choices) { Text(verbatim: $0.label).tag($0.id) }
        }
        .labelsHidden()
        switch OptionsFormLogic.choiceStyle(choices) {
        case .segmented:
            picker.pickerStyle(.segmented).fixedSize()
        case .menu:
            picker.pickerStyle(.menu).fixedSize()
        }
    }
}

/// Bytes shown as a number plus a KB / MB / GB unit.
private struct FileSizeField: View {
    @Binding var bytes: Int
    @State private var unit: OptionsFormLogic.SizeUnit?

    var body: some View {
        let current = unit ?? OptionsFormLogic.split(bytes: bytes).unit
        HStack(spacing: DesignTokens.Space.xs + 2) {
            TextField("", value: Binding(get: { Double(bytes) / current.bytes },
                                         set: { bytes = OptionsFormLogic.bytes($0, current) }),
                      format: .number.precision(.fractionLength(0...2)).grouping(.never))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
            Picker("", selection: Binding(get: { current }, set: { unit = $0 })) {
                ForEach(OptionsFormLogic.SizeUnit.allCases) { Text(verbatim: $0.rawValue).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        // Freeze the unit once shown, so typing 0.5 MB doesn't flip to 500 KB mid-edit.
        .onAppear { if unit == nil { unit = OptionsFormLogic.split(bytes: bytes).unit } }
    }
}

private struct ValidatedTextField: View {
    @Binding var text: String
    let prompt: String
    let validate: (String) -> String?
    let compact: Bool

    var body: some View {
        let issue = validate(text)
        VStack(alignment: compact ? .leading : .trailing, spacing: DesignTokens.Space.xs) {
            TextField("", text: $text, prompt: prompt.isEmpty ? nil : Text(verbatim: prompt))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: compact ? 120 : 180, maxWidth: compact ? .infinity : 240)
            if let issue {
                OptionIssue(text: issue)
            }
        }
    }
}

/// "#RRGGBB(AA)" text field and a colour well, kept in sync.
private struct HexColorField: View {
    @Binding var text: String
    @State private var draft = ""

    var body: some View {
        HStack(spacing: DesignTokens.Space.s) {
            TextField("", text: $draft)
                .labelsHidden()
                .font(.system(size: DesignTokens.TypeRamp.body, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(width: 96)
                .onSubmit(commit)
                .onChangeCompat(of: draft) { new in
                    if OptionsFormLogic.parseHex(new) != nil, new.count >= 7 { text = normalised(new) }
                }
            ColorPicker("", selection: colorBinding, supportsOpacity: true)
                .labelsHidden()
        }
        .onAppear { draft = text }
        .onChangeCompat(of: text) { new in
            if OptionsFormLogic.parseHex(draft) != OptionsFormLogic.parseHex(new) { draft = new }
        }
    }

    private func commit() {
        if OptionsFormLogic.parseHex(draft) != nil { text = normalised(draft) } else { draft = text }
    }

    private func normalised(_ s: String) -> String {
        OptionsFormLogic.parseHex(s).map(OptionsFormLogic.hex) ?? s
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                let c = OptionsFormLogic.parseHex(text) ?? .init(r: 1, g: 1, b: 1, a: 1)
                return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
            },
            set: { color in
                guard let ns = NSColor(color).usingColorSpace(.sRGB) else { return }
                let hex = OptionsFormLogic.hex(.init(r: Double(ns.redComponent), g: Double(ns.greenComponent),
                                                     b: Double(ns.blueComponent), a: Double(ns.alphaComponent)))
                text = hex
                draft = hex
            }
        )
    }
}

/// Normalised "x,y,w,h" as four small fields.
private struct RectFields: View {
    @Binding var text: String

    var body: some View {
        let parts = OptionsFormLogic.parseRect(text) ?? [0, 0, 1, 1]
        let names = [String(localized: "X"), String(localized: "Y"), String(localized: "W"), String(localized: "H")]
        VStack(alignment: .trailing, spacing: DesignTokens.Space.xs) {
            HStack(spacing: DesignTokens.Space.s) {
                ForEach(0..<4, id: \.self) { i in
                    VStack(spacing: DesignTokens.Space.xxs) {
                        TextField("", value: Binding(get: { parts[i] }, set: { new in
                            var p = parts
                            p[i] = OptionsFormLogic.clamp(new, 0, 1)
                            text = OptionsFormLogic.formatRect(p)
                        }), format: .number.precision(.fractionLength(0...3)))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 54)
                        Text(verbatim: names[i])
                            .font(.system(size: DesignTokens.TypeRamp.caption))
                            .foregroundStyle(Color.haloSecondaryText)
                    }
                }
            }
            if let issue = OptionsFormLogic.validateRect(text) {
                OptionIssue(text: issue)
            }
        }
    }
}

/// An inline problem with a value: warning glyph + text in the error colour,
/// so it never relies on colour alone.
private struct OptionIssue: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: DesignTokens.TypeRamp.caption, weight: .medium))
        .foregroundStyle(Color.haloDanger)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Problem: \(text)", comment: "VoiceOver prefix for an invalid option value"))
    }
}
