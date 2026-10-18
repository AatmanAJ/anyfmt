import SwiftUI
import HaloCore

/// Every `OptionKind` once, regular (grouped Form) and compact (popover),
/// for screenshots and for eyeballing the renderer.
struct OptionsGallery: View {
    static let schema = OptionsSchema("gallery", [
        OptionSpec(OptionKey.quality, L("Quality"), .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(85)),
        OptionSpec(OptionKey.maxDimension, L("Max size"), .integer(min: 0, max: 32768, unit: "px"), default: .int(0),
                   help: L("Longest edge in pixels. 0 keeps the original size.")),
        OptionSpec("exposure", L("Exposure"), .decimal(min: -2, max: 2, step: 0.05), default: .double(0.35)),
        OptionSpec(OptionKey.lossless, L("Lossless"), .toggle, default: .bool(false)),
        OptionSpec(OptionKey.sizeMode, L("Mode"), .choice([
            OptionChoice("quality", L("Quality")), OptionChoice("size", L("Target size")), OptionChoice("percent", L("Percentage")),
        ]), default: .string("size")),
        OptionSpec(OptionKey.targetSize, L("Target size"), .fileSize, default: .int(2_500_000),
                   visibleWhen: [OptionKey.sizeMode: .string("size")]),
        OptionSpec(OptionKey.resolution, L("Resolution"), .choice([
            OptionChoice("0", L("Keep")), OptionChoice("2160", "4K"), OptionChoice("1080", "1080p"),
            OptionChoice("720", "720p"), OptionChoice("480", "480p"),
        ]), default: .string("1080")),
        OptionSpec(OptionKey.pages, L("Pages"), .pageRange, default: .string("1-3, 5"), help: L("Leave empty for all pages, or e.g. 1-3,5")),
        OptionSpec("range", L("Range"), .timeRange, default: .string("9-2")),
        OptionSpec("title", L("Title"), .text, default: .string("Holiday")),
        OptionSpec(OptionKey.background, L("Background"), .color, default: .string("#FF9500")), // token-ok: sample user value (a colour the user picked)
        OptionSpec("rect", L("Crop"), .rect, default: .string("0.1,0.1,0.8,0.75")),
    ])

    @State private var regular = OptionsGallery.schema.defaults
    @State private var compact = ToolSchemas.compress.defaults.merging(OptionValues([OptionKey.sizeMode: .string("size")]))
    @State private var background = ToolSchemas.addBackground.defaults

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Form {
                Section("Regular") {
                    OptionsForm(schema: Self.schema, values: $regular)
                }
            }
            .formStyle(.grouped)
            .frame(width: 560)

            VStack(alignment: .leading, spacing: DesignTokens.Space.l) {
                Text("Compact").font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                popover(ToolSchemas.compress, $compact)
                popover(ToolSchemas.addBackground, $background)
            }
            .padding(DesignTokens.Space.xl)
            .frame(width: 340, alignment: .topLeading)
        }
        .toggleStyle(HaloSwitchStyle())
        .fixedSize(horizontal: false, vertical: true)
    }

    private func popover(_ schema: OptionsSchema, _ values: Binding<OptionValues>) -> some View {
        OptionsForm(schema: schema, values: values, size: .compact)
            .padding(DesignTokens.Space.l)
            .frame(width: 280, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08)))
    }
}
