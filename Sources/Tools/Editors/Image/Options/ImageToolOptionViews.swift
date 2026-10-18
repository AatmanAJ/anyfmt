import AppKit
import SwiftUI
import HaloCore

/// Compact options for the instant Compress tool, for the wheel's options
/// popover. Edits `ToolSchemas.compress` values in place.
public struct ImageCompressOptionsView: View {
    @Binding var options: OptionValues
    /// Size of the (first) file, for "≈ 1.2 MB" estimates in percentage mode.
    let originalBytes: Int?

    public init(options: Binding<OptionValues>, originalBytes: Int? = nil) {
        _options = options
        self.originalBytes = originalBytes
    }

    private var mode: Binding<String> { stringBinding(OptionKey.sizeMode, "quality") }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
            Picker(String(localized: "Mode"), selection: mode) {
                Text("Quality").tag("quality")
                Text("Target size").tag("size")
                Text("Percentage").tag("percent")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            switch mode.wrappedValue {
            case "size":
                TargetSizeField(bytes: intBinding(OptionKey.targetSize, 1_000_000))
                ImageEditorKit.Hint(String(localized: "Highest quality that fits; very small targets also shrink the image."))
            case "percent":
                let pct = intBinding(OptionKey.percent, 50)
                ImageEditorKit.ValueSlider(label: String(localized: "Percentage of original"),
                                           value: Binding(get: { Double(pct.wrappedValue) }, set: { pct.wrappedValue = Int($0) }),
                                           range: 5...95, step: 5, neutral: 50, format: { "\(Int($0)) %" })
                if let originalBytes {
                    ImageEditorKit.Hint(String(localized: "About \(ByteCountFormatter.string(fromByteCount: Int64(Double(originalBytes) * Double(pct.wrappedValue) / 100), countStyle: .file)) per file"))
                } else {
                    ImageEditorKit.Hint(String(localized: "Each file is compressed to this share of its own size."))
                }
            default:
                let q = intBinding(OptionKey.quality, 70)
                ImageEditorKit.ValueSlider(label: String(localized: "Quality"),
                                           value: Binding(get: { Double(q.wrappedValue) }, set: { q.wrappedValue = Int($0) }),
                                           range: 1...100, step: 1, neutral: 70, format: { "\(Int($0)) %" })
                ImageEditorKit.Hint(String(localized: "PNGs keep full quality above 95 % and switch to an optimised palette below."))
            }
        }
        .padding(DesignTokens.Space.l)
        .frame(width: 300)
    }

    private func stringBinding(_ key: String, _ d: String) -> Binding<String> {
        Binding(get: { options.string(key, default: d) }, set: { options[key] = .string($0) })
    }

    private func intBinding(_ key: String, _ d: Int) -> Binding<Int> {
        Binding(get: { options.int(key, default: d) }, set: { options[key] = .int($0) })
    }

    /// Number + KB/MB unit, stored as bytes.
    struct TargetSizeField: View {
        @Binding var bytes: Int
        @State private var unit: Int = 1_000_000
        @State private var text = ""

        var body: some View {
            HStack(spacing: DesignTokens.Space.s) {
                Text("Target size").font(.system(size: DesignTokens.TypeRamp.body))
                Spacer()
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .onSubmit(commit)
                    .accessibilityLabel(String(localized: "Target size"))
                Picker("", selection: $unit) {
                    Text("KB").tag(1_000)
                    Text("MB").tag(1_000_000)
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(String(localized: "Unit"))
            }
            .onAppear {
                unit = bytes >= 1_000_000 ? 1_000_000 : 1_000
                text = Self.format(Double(bytes) / Double(unit))
            }
            .onChange(of: unit) { _ in commit() }
            .onChange(of: text) { _ in commit() }
        }

        private func commit() {
            let v = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
            if v > 0 { bytes = max(1_000, Int(v * Double(unit))) }
        }

        static func format(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
    }
}

/// Compact options for the instant Resize tool (`ToolSchemas.resize`).
public struct ImageResizeOptionsView: View {
    @Binding var options: OptionValues
    /// Upright pixel size of the (first) file, for the live readout.
    let sourceSize: CGSize?

    public init(options: Binding<OptionValues>, sourceSize: CGSize? = nil) {
        _options = options
        self.sourceSize = sourceSize
    }

    private static let presets = ["3840", "2048", "1920", "1280", "1080", "800", "512"]

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
            Picker(String(localized: "Mode"), selection: string("mode", "percent")) {
                Text("Preset").tag("preset")
                Text("Exact size").tag("pixels")
                Text("Percentage").tag("percent")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            switch options.string("mode", default: "percent") {
            case "preset":
                Picker(String(localized: "Longest edge"), selection: string("preset", "1920")) {
                    ForEach(Self.presets, id: \.self) { Text("\($0) px").tag($0) }
                }
                ImageEditorKit.Hint(String(localized: "Fits the longest edge. Smaller images are left as they are."))
            case "pixels":
                HStack(spacing: DesignTokens.Space.s) {
                    numberField(String(localized: "Width"), key: "width", fallback: 1920)
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                    numberField(String(localized: "Height"), key: "height", fallback: 0)
                    Text("px").foregroundStyle(.secondary)
                }
                ImageEditorKit.Hint(String(localized: "Leave height at 0 to keep the aspect ratio."))
            default:
                let p = int(OptionKey.percent, 50)
                ImageEditorKit.ValueSlider(label: String(localized: "Scale"), value: Binding(get: { Double(p.wrappedValue) }, set: { p.wrappedValue = Int($0) }),
                                           range: 5...400, step: 5, neutral: 100, format: { "\(Int($0)) %" })
            }
            if let sourceSize {
                let target = ResizePlan.targetSize(for: sourceSize, options: options)
                HStack {
                    Text(ImageEditorKit.pixelText(sourceSize)).foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    Text(ImageEditorKit.pixelText(target)).fontWeight(.semibold)
                }
                .font(.system(size: DesignTokens.TypeRamp.caption).monospacedDigit())
                .accessibilityElement(children: .combine)
            }
        }
        .padding(DesignTokens.Space.l)
        .frame(width: 300)
    }

    private func string(_ key: String, _ d: String) -> Binding<String> {
        Binding(get: { options.string(key, default: d) }, set: { options[key] = .string($0) })
    }

    private func int(_ key: String, _ d: Int) -> Binding<Int> {
        Binding(get: { options.int(key, default: d) }, set: { options[key] = .int($0) })
    }

    private func numberField(_ label: String, key: String, fallback: Int) -> some View {
        TextField(label, value: int(key, fallback), format: .number.grouping(.never))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 76)
            .accessibilityLabel(label)
    }
}
