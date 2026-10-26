import SwiftUI
import AnyfmtCore

/// Compact option views for lane G2's instant tools (change speed, compress
/// video, normalize, change channels, compress PDF), sized for the wheel's
/// options popover (~280 pt wide). Values are read from and written to
/// `options` using the tool's schema keys; missing keys show the defaults.
struct MediaOptionsPanel: View {
    let tool: ToolSpec
    @Binding var options: OptionValues

    static let tools: [ToolID] = [ToolIDs.speedVideo, ToolIDs.compressVideo, ToolIDs.normalizeAudio, ToolIDs.channelsAudio, ToolIDs.compressPDF]
    static func supports(_ id: ToolID) -> Bool { tools.contains(id) }

    init(tool: ToolSpec, options: Binding<OptionValues>) {
        self.tool = tool
        _options = options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
            Label(tool.title, systemImage: tool.glyph)
                .font(MediaStyle.body(.semibold))
                .accessibilityAddTraits(.isHeader)
            switch tool.id {
            case ToolIDs.speedVideo: speed
            case ToolIDs.compressVideo: compressVideo
            case ToolIDs.normalizeAudio: normalize
            case ToolIDs.channelsAudio: channels
            case ToolIDs.compressPDF: compressPDF
            default: EmptyView()
            }
        }
        .padding(DesignTokens.Space.l)
        .frame(width: 280, alignment: .leading)
    }

    // MARK: Bindings

    private func string(_ key: String) -> Binding<String> {
        let d = tool.defaultOptions.string(key, default: "")
        return Binding(get: { options.string(key, default: d) }, set: { options[key] = .string($0) })
    }

    private func bool(_ key: String) -> Binding<Bool> {
        let d = tool.defaultOptions.bool(key, default: false)
        return Binding(get: { options.bool(key, default: d) }, set: { options[key] = .bool($0) })
    }

    private func int(_ key: String) -> Binding<Int> {
        let d = tool.defaultOptions.int(key, default: 0)
        return Binding(get: { options.int(key, default: d) }, set: { options[key] = .int($0) })
    }

    private func choices(_ key: String) -> [OptionChoice] {
        if case .choice(let c) = tool.schema.spec(key)?.kind { return c }
        return []
    }

    // MARK: Tools

    private var speed: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            ChipGrid(choices: choices("factor"), selection: string("factor"), columns: 4)
            Toggle(String(localized: "Keep audio pitch"), isOn: bool("keepPitch")).toggleStyle(.editorSwitch)
            let f = options.double("factor", default: 2)
            Text(f > 1 ? String(localized: "Plays \(Self.factorText(f)) faster: a 1-minute clip becomes \(MediaTimes.timecode(60 / f, fraction: 0)).")
                       : String(localized: "Plays \(Self.factorText(f)) as fast: a 1-minute clip becomes \(MediaTimes.timecode(60 / f, fraction: 0))."))
                .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    static func factorText(_ f: Double) -> String {
        var s = String(format: "%.2f", f)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s + "×"
    }

    private var compressVideo: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            EditorChoiceChips(String(localized: "Mode"), selection: string(OptionKey.sizeMode),
                              options: choices(OptionKey.sizeMode).map { .init($0.id, $0.label) })
            if options.string(OptionKey.sizeMode, default: "quality") == "size" {
                SizeField(bytes: int(OptionKey.targetSize), presets: [(8_000_000, String(localized: "8 MB")), (25_000_000, String(localized: "25 MB")),
                                                                      (50_000_000, String(localized: "50 MB")), (100_000_000, String(localized: "100 MB"))])
                Text("Two-pass encode that lands within a few percent of the size, sound included.")
                    .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                RadioRows(selection: string(OptionKey.videoQuality), rows: [
                    ("high", String(localized: "High"), String(localized: "Looks like the original, noticeably smaller")),
                    ("balanced", String(localized: "Balanced"), String(localized: "Good for sharing and email")),
                    ("small", String(localized: "Small file"), String(localized: "Smallest, softer detail")),
                ])
            }
            HStack {
                Text("Resolution").font(MediaStyle.label()).foregroundStyle(.secondary)
                Spacer()
                Picker(String(localized: "Resolution"), selection: string(OptionKey.resolution)) {
                    ForEach(choices(OptionKey.resolution)) { Text($0.label).tag($0.id) }
                }
                .labelsHidden().frame(width: 110)
            }
        }
    }

    private var normalize: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            RadioRows(selection: string("target"), rows: [
                ("-14", String(localized: "−14 LUFS"), String(localized: "Streaming: Spotify, YouTube, Apple Music")),
                ("-16", String(localized: "−16 LUFS"), String(localized: "Podcasts and spoken word")),
                ("-23", String(localized: "−23 LUFS"), String(localized: "Broadcast (EBU R128)")),
            ])
            Text("Measures the whole file first, then applies one even gain, so dynamics are untouched. Video is copied as-is.")
                .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var channels: some View {
        RadioRows(selection: string("mode"), rows: [
            ("mono", String(localized: "Mono"), String(localized: "Mix left and right into one channel")),
            ("stereo", String(localized: "Stereo"), String(localized: "Play a mono track on both sides")),
            ("swap", String(localized: "Swap left / right"), String(localized: "Fix reversed channels")),
        ])
    }

    private var compressPDF: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            EditorChoiceChips(String(localized: "Mode"), selection: string(OptionKey.sizeMode),
                              options: choices(OptionKey.sizeMode).map { .init($0.id, $0.label) })
            if options.string(OptionKey.sizeMode, default: "quality") == "size" {
                SizeField(bytes: int(OptionKey.targetSize), presets: [(1_000_000, String(localized: "1 MB")), (2_000_000, String(localized: "2 MB")),
                                                                      (5_000_000, String(localized: "5 MB")), (10_000_000, String(localized: "10 MB"))])
                Text("Finds the gentlest image settings that fit. Text and drawings never change.")
                    .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Text("Image quality").font(MediaStyle.label()).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(options.int(OptionKey.quality, default: 60))%").font(MediaStyle.label().monospacedDigit())
                }
                Slider(value: Binding(get: { Double(options.int(OptionKey.quality, default: 60)) },
                                      set: { options[OptionKey.quality] = .int(Int(($0 / 5).rounded() * 5)) }), in: 10...95)
                    .controlSize(.small)
                    .accessibilityLabel(Text("Image quality"))
                HStack {
                    Text("Image resolution").font(MediaStyle.label()).foregroundStyle(.secondary)
                    Spacer()
                    Picker(String(localized: "Image resolution"), selection: string(OptionKey.dpi)) {
                        ForEach(choices(OptionKey.dpi)) { Text($0.label).tag($0.id) }
                    }
                    .labelsHidden().frame(width: 110)
                }
                Text("Only photos and scans are recompressed. Text stays sharp and searchable.")
                    .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Grid of selectable chips for a `.choice` option.
private struct ChipGrid: View {
    let choices: [OptionChoice]
    @Binding var selection: String
    let columns: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(choices) { c in
                let on = selection == c.id
                Button { selection = c.id } label: {
                    Text(c.label)
                        .monospacedDigit()
                }
                .buttonStyle(.editorChip(selected: on, fill: true))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Radio list with a title and one-line explanation per row.
private struct RadioRows: View {
    @Binding var selection: String
    let rows: [(id: String, title: String, detail: String)]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows, id: \.id) { row in
                let on = selection == row.id
                Button { selection = row.id } label: {
                    HStack(alignment: .top, spacing: DesignTokens.Space.s) {
                        Image(systemName: on ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(on ? Color.accentText : Color.anyfmtSecondaryText)
                            .font(.system(size: DesignTokens.TypeRamp.body))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.title).font(MediaStyle.label(on ? .bold : .medium)).foregroundStyle(Color.anyfmtInk)
                            Text(row.detail).font(MediaStyle.caption()).foregroundStyle(Color.anyfmtSecondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DesignTokens.Space.s).padding(.vertical, DesignTokens.Space.xs + 2)
                    .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
                        .fill(on ? MediaStyle.accent.opacity(0.14) : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

/// Target size in megabytes with quick presets.
private struct SizeField: View {
    @Binding var bytes: Int
    let presets: [(Int, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Target size").font(MediaStyle.label()).foregroundStyle(.secondary)
                Spacer()
                TextField(String(localized: "Megabytes"), value: Binding(get: { Double(bytes) / 1_000_000 },
                                                                       set: { bytes = max(100_000, Int(($0 * 1_000_000).rounded())) }),
                          format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.roundedBorder).frame(width: 64).multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text("Target size in megabytes"))
                Text("MB").font(MediaStyle.caption()).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(presets, id: \.0) { p in
                    Button(p.1) { bytes = p.0 }
                        .buttonStyle(.editorChip(selected: bytes == p.0))
                        .accessibilityAddTraits(bytes == p.0 ? .isSelected : [])
                }
            }
        }
    }
}
