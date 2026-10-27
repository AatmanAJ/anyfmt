import AppKit
import SwiftUI
import AnyfmtCore

// Building blocks for every editor window in the phase 2 language (PLAN-PHASE2 §2):
// near-black chrome, charcoal tiles in the sidebar, heavy uppercase titles, cobalt
// for selection, and canvas marks drawn with a dark anyfmt + white rim + cobalt core
// so they read on any picture. Shared by the image and media editors.

typealias EditorTokens = DesignTokens.Component.Editor

/// Editor colours, resolved per appearance.
enum EditorPalette {
    static let canvas = Color.token(EditorTokens.canvas)
    static let chip = Color.token(EditorTokens.chip)
    static let selected = Color.token(EditorTokens.selected)
    static let onSelected = Color.token(EditorTokens.onSelected)
    static let warning = Color.token(EditorTokens.warning)
    static let overlayCore = Color(hex: EditorTokens.Overlay.core)
    static let overlayRim = Color(hex: EditorTokens.Overlay.rim)
    static let overlayHalo = Color(hex: EditorTokens.Overlay.anyfmt)
    /// Text that sits on an orange or flame fill (black, 6.3:1 or better).
    static let onWarm = Color(hex: DesignTokens.Semantic.onAccentSecondary)
    static let orange = Color(hex: DesignTokens.Primitive.ember500)
    static let flame = Color(hex: DesignTokens.Primitive.ember600)
}

// MARK: - Titles

/// The one heavy word at the top of an editor's sidebar.
enum EditorTitle {
    static func display(_ tool: ToolSpec) -> String {
        switch tool.id {
        case ToolIDs.cropImage, ToolIDs.cropVideo: String(localized: "Crop")
        case ToolIDs.adjustImage: String(localized: "Adjust")
        case ToolIDs.annotateImage: String(localized: "Annotate")
        case ToolIDs.redactImage: String(localized: "Redact")
        case ToolIDs.addBackground: String(localized: "Background")
        case ToolIDs.collage: String(localized: "Collage")
        case ToolIDs.imagesToPDF: String(localized: "To PDF")
        case ToolIDs.editMetadata: String(localized: "Metadata")
        case ToolIDs.trimVideo, ToolIDs.trimAudio: String(localized: "Trim")
        case ToolIDs.splitVideo: String(localized: "Split")
        case ToolIDs.joinVideo: String(localized: "Join")
        case ToolIDs.snapshotVideo: String(localized: "Frames")
        case ToolIDs.bleepAudio: String(localized: "Bleep")
        case ToolIDs.organizePDF: String(localized: "Pages")
        default: tool.title
        }
    }
}

// MARK: - Sidebar tiles

/// A titled charcoal tile in an editor sidebar.
struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s + DesignTokens.Space.xxs) {
            EditorCaption(title)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .anyfmtTile(padding: EditorTokens.sectionPadding)
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).strokeBorder(Color.anyfmtSecondaryText)
            }
        }
    }
}

/// Small uppercase label over a group ("ASPECT RATIO").
struct EditorCaption: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold))
            .foregroundStyle(Color.anyfmtSecondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Buttons and choices

/// Raised pill for small actions and choices. Selected: cobalt with white text
/// and a heavier weight (so selection never rides on colour alone).
struct EditorChipButtonStyle: ButtonStyle {
    var selected = false
    var fill = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignTokens.TypeRamp.label, weight: selected ? .bold : .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(foreground(configuration.role))
            .padding(.horizontal, fill ? DesignTokens.Space.s : EditorTokens.chipPadding)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: EditorTokens.chipHeight)
            .background {
                Capsule().fill(selected ? EditorPalette.selected : EditorPalette.chip)
                    // Light needs an edge (white on light grey); dark reads by fill alone.
                    .overlay(Capsule().stroke(contrast == .increased ? Color.anyfmtSecondaryText
                                              : (selected || scheme == .dark ? Color.clear : Color.anyfmtHairline),
                                              lineWidth: DesignTokens.Shape.hairline))
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.4)
    }

    private func foreground(_ role: ButtonRole?) -> Color {
        if selected { return EditorPalette.onSelected }
        return role == .destructive ? Color.anyfmtDanger : Color.anyfmtInk
    }
}

extension ButtonStyle where Self == EditorChipButtonStyle {
    static var editorChip: EditorChipButtonStyle { EditorChipButtonStyle() }
    static func editorChip(selected: Bool, fill: Bool = false) -> EditorChipButtonStyle {
        EditorChipButtonStyle(selected: selected, fill: fill)
    }
}

/// A row of chips standing in for a segmented picker.
struct EditorChoiceChips<Value: Hashable>: View {
    struct Option {
        let value: Value
        let label: String
        var systemImage: String? = nil
        init(_ value: Value, _ label: String, systemImage: String? = nil) {
            self.value = value
            self.label = label
            self.systemImage = systemImage
        }
    }

    let label: String
    let options: [Option]
    @Binding var selection: Value

    init(_ label: String, selection: Binding<Value>, options: [Option]) {
        self.label = label
        _selection = selection
        self.options = options
    }

    var body: some View {
        HStack(spacing: DesignTokens.Space.xs + DesignTokens.Space.xxs) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let on = option.value == selection
                Button { selection = option.value } label: {
                    HStack(spacing: DesignTokens.Space.xs) {
                        if let symbol = option.systemImage { Image(systemName: symbol).accessibilityHidden(true) }
                        Text(verbatim: option.label)
                    }
                }
                .buttonStyle(.editorChip(selected: on, fill: true))
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// A large selectable cell with a glyph over a short label (aspect ratios, tools).
struct EditorCellButtonStyle: ButtonStyle {
    var selected: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignTokens.TypeRamp.caption, weight: selected ? .bold : .medium))
            .foregroundStyle(selected ? EditorPalette.onSelected : Color.anyfmtInk)
            .frame(maxWidth: .infinity, minHeight: EditorTokens.cellHeight)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
                .fill(selected ? EditorPalette.selected : EditorPalette.chip))
            .overlay {
                if !selected || contrast == .increased {
                    RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
                        .strokeBorder(contrast == .increased ? Color.anyfmtSecondaryText : Color.anyfmtHairline, lineWidth: DesignTokens.Shape.hairline)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.4)
    }
}

/// A drawn switch: cobalt track when on, the knob moves (state is never colour alone).
/// Drawn rather than native so it reads the same live and in offscreen renders.
struct EditorSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        EditorSwitchBody(configuration: configuration)
    }
}

private struct EditorSwitchBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let size = EditorTokens.switchSize
        let on = configuration.isOn
        Button { configuration.$isOn.wrappedValue.toggle() } label: {
            HStack(spacing: DesignTokens.Space.s) {
                configuration.label
                    .font(.system(size: DesignTokens.TypeRamp.body))
                    .foregroundStyle(Color.anyfmtInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule().fill(on ? EditorPalette.selected : EditorPalette.chip)
                        .overlay(Capsule().strokeBorder(contrast == .increased ? Color.anyfmtSecondaryText : Color.anyfmtHairline,
                                                        lineWidth: DesignTokens.Shape.hairline))
                    Circle().fill(Color(hex: DesignTokens.Primitive.paper0))
                        .overlay(Circle().strokeBorder(Color.anyfmtHairline, lineWidth: DesignTokens.Shape.hairline))
                        .padding(DesignTokens.Space.xxs)
                }
                .frame(width: size.width, height: size.height)
                .animation(reduceMotion ? nil : .easeOut(duration: DesignTokens.Curve.snap.duration), value: on)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

extension ToggleStyle where Self == EditorSwitchStyle {
    static var editorSwitch: EditorSwitchStyle { EditorSwitchStyle() }
}

// MARK: - States

/// What an editor shows instead of its canvas while it loads, when the file
/// can't be opened, or when there is nothing to show yet. Left-aligned, in a tile.
struct EditorStateView: View {
    enum Kind { case loading, problem, empty }

    let kind: Kind
    let title: String
    var message: String? = nil
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
            glyph
            DisplayText(title, size: EditorTokens.stateTitleSize)
                .foregroundStyle(Color.anyfmtInk)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(verbatim: message)
                    .font(.system(size: DesignTokens.TypeRamp.body))
                    .foregroundStyle(Color.anyfmtSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: EditorTokens.stateMaxWidth, alignment: .leading)
        .anyfmtTile(padding: DesignTokens.Space.xl)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var glyph: some View {
        switch kind {
        case .loading:
            ProgressView().controlSize(.small).accessibilityHidden(true)
        case .problem:
            Image(systemName: systemImage ?? "exclamationmark.triangle.fill")
                .font(.system(size: EditorTokens.stateGlyphSize, weight: .semibold))
                .foregroundStyle(Color.anyfmtDanger)
                .accessibilityLabel(String(localized: "Problem"))
        case .empty:
            Image(systemName: systemImage ?? "photo")
                .font(.system(size: EditorTokens.stateGlyphSize, weight: .semibold))
                .foregroundStyle(Color.accentText)
                .accessibilityHidden(true)
        }
    }
}

extension EditorStateView {
    /// The image couldn't be decoded.
    static func unreadableImage(_ url: URL?) -> EditorStateView {
        EditorStateView(kind: .problem, title: String(localized: "Can’t open this image"),
                        message: String(localized: "\(url?.lastPathComponent ?? String(localized: "This file")) couldn’t be read. It may be damaged, or in a format this editor can’t show. Your file hasn’t been changed."),
                        systemImage: "photo.badge.exclamationmark")
    }
}

// MARK: - Canvas marks

/// A path stroked as dark anyfmt + white rim + cobalt core, legible on any pixels.
struct OverlayStroke: View {
    let path: Path
    var dash: [CGFloat] = []
    var width: CGFloat? = nil
    /// White-only core for secondary marks (thirds grid, unselected regions).
    var quiet = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let o = EditorTokens.Overlay.self
        let core = width ?? (contrast == .increased ? o.lineWidthIncreased : o.lineWidth)
        let rim = core + o.rimWidth * 2, anyfmt = quiet ? core + o.haloWidth : rim + o.haloWidth * 2
        ZStack {
            path.stroke(EditorPalette.overlayHalo.opacity(contrast == .increased ? o.haloOpacityIncreased : o.haloOpacity), style: style(anyfmt))
            path.stroke(EditorPalette.overlayRim, style: style(quiet ? core : rim))
            if !quiet { path.stroke(EditorPalette.overlayCore, style: style(core)) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func style(_ w: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: w, lineCap: dash.isEmpty ? .round : .butt, lineJoin: .round, dash: dash)
    }
}

/// A drag handle: cobalt with a white rim and a dark anyfmt. Square for resize
/// handles, round for points.
struct OverlayHandle: View {
    var round = false
    var size: CGFloat = EditorTokens.Overlay.handle
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let o = EditorTokens.Overlay.self
        let anyfmt = EditorPalette.overlayHalo.opacity(contrast == .increased ? o.haloOpacityIncreased : o.haloOpacity)
        ZStack {
            shape.fill(anyfmt).frame(width: size + o.haloWidth * 2, height: size + o.haloWidth * 2)
            shape.fill(EditorPalette.overlayRim).frame(width: size, height: size)
            shape.fill(EditorPalette.overlayCore).frame(width: size - o.rimWidth * 3, height: size - o.rimWidth * 3)
        }
        .accessibilityHidden(true)
    }

    private var shape: AnyShape { round ? AnyShape(Circle()) : AnyShape(Rectangle()) }
}

/// A short readout pinned on the canvas ("882 × 662", "Original"): white on the dark anyfmt colour.
struct OverlayBadge: View {
    let text: String
    var accent = false

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: DesignTokens.TypeRamp.caption, weight: .bold).monospacedDigit())
            .foregroundStyle(EditorPalette.overlayRim)
            .padding(.horizontal, DesignTokens.Space.s)
            .padding(.vertical, DesignTokens.Space.xxs + 1)
            .background(Capsule().fill(accent ? EditorPalette.overlayCore : EditorPalette.overlayHalo.opacity(EditorTokens.Overlay.badgeOpacity)))
            .overlay(Capsule().strokeBorder(EditorPalette.overlayRim.opacity(accent ? 1 : 0), lineWidth: DesignTokens.Shape.hairline))
    }
}

// MARK: - Before / after

/// The compare toggle under the canvas (B).
struct BeforeAfterToggle: View {
    @Binding var showOriginal: Bool

    var body: some View {
        Button { showOriginal.toggle() } label: {
            Label(String(localized: "Before / After"), systemImage: "square.split.2x1")
        }
        .buttonStyle(.editorChip(selected: showOriginal))
        .keyboardShortcut("b", modifiers: [])
        .help(String(localized: "Compare with the original (B)"))
        .accessibilityAddTraits(showOriginal ? .isSelected : [])
        .accessibilityValue(showOriginal ? String(localized: "Showing the original") : String(localized: "Showing your changes"))
    }
}
