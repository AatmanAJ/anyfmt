import AppKit
import SwiftUI
import HaloCore

// Small shared controls for Halo's SwiftUI windows (settings, onboarding,
// about, the wheel's options popover). Phase 2 language: ink tiles, cobalt
// for "on", one tile radius or a pill, icons beside every coloured state.

// MARK: - Snapshot rendering

private struct SnapshotKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while a view is rendered offscreen for docs/screens (D-025).
    /// Offscreen windows are never key, so AppKit switches draw their inactive
    /// grey; snapshot mode swaps in a drawn switch that matches the active look.
    var isSnapshot: Bool {
        get { self[SnapshotKey.self] }
        set { self[SnapshotKey.self] = newValue }
    }
}

/// In snapshot renders, makes SwiftUI-drawn controls use their active
/// (key window) appearance. No effect in the running app.
struct SnapshotActiveAppearance: ViewModifier {
    @Environment(\.isSnapshot) private var isSnapshot

    func body(content: Content) -> some View {
        if isSnapshot {
            if #available(macOS 15, *) {
                content.environment(\.controlActiveState, .key).environment(\.appearsActive, true)
            } else {
                content.environment(\.controlActiveState, .key)
            }
        } else {
            content
        }
    }
}

extension View {
    func snapshotActiveAppearance() -> some View { modifier(SnapshotActiveAppearance()) }
}

/// The standard switch tinted cobalt, except in snapshot renders (see `isSnapshot`).
struct HaloSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HaloSwitchBody(configuration: configuration)
    }
}

private struct HaloSwitchBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isSnapshot) private var isSnapshot
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        if isSnapshot {
            LabeledContent {
                SnapshotSwitch(isOn: configuration.isOn, small: controlSize == .small || controlSize == .mini)
            } label: {
                configuration.label
            }
        } else {
            Toggle(configuration).toggleStyle(.switch).tint(Color.iris)
        }
    }
}

/// Drawn copy of an active macOS switch, used only for offscreen renders.
struct SnapshotSwitch: View {
    let isOn: Bool
    var small = false

    var body: some View {
        let w: CGFloat = small ? 26 : 36, h: CGFloat = small ? 12 : 16
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? Color.iris : Color(nsColor: .tertiaryLabelColor).opacity(0.55))
            Capsule()
                .fill(Color(hex: DesignTokens.Primitive.paper0))
                .frame(width: w * 0.6, height: h - 3)
                .padding(.horizontal, 1.5)
        }
        .frame(width: w, height: h)
        .accessibilityHidden(true)
    }
}

/// Title, subtitle and a trailing switch, for toggles outside a grouped Form
/// (onboarding cards).
struct CardToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var identifier: String?

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.l) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                Text(verbatim: title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                Text(verbatim: subtitle)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(Color.haloSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle(isOn: $isOn) { Text(verbatim: title) }
                .labelsHidden()
                .toggleStyle(HaloSwitchStyle())
                .accessibilityIdentifier(identifier ?? "")
                .accessibilityHint(Text(verbatim: subtitle))
        }
    }
}

// MARK: - Borders

extension View {
    /// A border on `shape` drawn as a ring of fill (outer shape minus the
    /// inset shape) instead of a stroked path. Stroked rounded paths pick up
    /// notches where arcs meet edges in offscreen captures (docs/screens);
    /// fills don't, and look identical on screen.
    func haloBorder<S: InsettableShape>(_ shape: S, _ color: Color,
                                        width: CGFloat = DesignTokens.Shape.hairline) -> some View {
        overlay {
            BorderRing(shape: shape, width: width)
                .fill(color, style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
        }
    }
}

/// The outline of `shape` as an even-odd ring: the shape minus itself inset.
private struct BorderRing<S: InsettableShape>: Shape {
    let shape: S
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = shape.path(in: rect)
        p.addPath(shape.inset(by: width).path(in: rect))
        return p
    }
}

// MARK: - Key caps

/// A key as a small ink tile: "⇧ Shift", "⌘", "Space". One radius
/// (`Shape.tile`), a hairline instead of a shadow. `prominent` is the key
/// that's live right now: cobalt with white text (5.0:1).
struct KeyCap: View {
    let text: String
    var prominent = false
    var compact = false
    @Environment(\.colorSchemeContrast) private var contrast

    private typealias T = DesignTokens.Component.KeyCap

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
        Text(verbatim: text)
            .font(.system(size: compact ? T.compactFontSize : T.fontSize, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(prominent ? Color(hex: DesignTokens.Semantic.onAccentPrimary) : Color.haloInk)
            .padding(.horizontal, compact ? T.compactHorizontalPadding : T.horizontalPadding)
            .frame(minWidth: compact ? T.compactMinWidth : T.minWidth,
                   minHeight: compact ? T.compactHeight : T.height)
            .background(shape.fill(prominent ? Color.iris : Color.token(T.fill)))
            .haloBorder(shape, prominent ? Color.clear : strokeColor)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: KeyCap.spoken(text)))
    }

    private var strokeColor: Color {
        contrast == .increased ? Color.haloInk : Color.token(T.stroke)
    }

    /// VoiceOver reads modifier symbols as words; it would otherwise skip "⌃".
    nonisolated static func spoken(_ text: String) -> String {
        let names: [Character: String] = [
            "⌃": String(localized: "Control", comment: "Key name read by VoiceOver"),
            "⌥": String(localized: "Option", comment: "Key name read by VoiceOver"),
            "⇧": String(localized: "Shift", comment: "Key name read by VoiceOver"),
            "⌘": String(localized: "Command", comment: "Key name read by VoiceOver"),
        ]
        guard text.count == 1, let c = text.first, let name = names[c] else { return text }
        return name
    }
}

// MARK: - Status

/// Icon + label, e.g. a check and "Granted". The icon's shape carries the
/// state as well as its colour, so nothing rides on colour alone.
struct StatusBadge: View {
    enum Tone { case good, waiting, off, warning }
    let tone: Tone
    let text: String

    private typealias T = DesignTokens.Component.StatusBadge

    var body: some View {
        HStack(spacing: T.spacing) {
            Image(systemName: symbol)
                .font(.system(size: T.iconSize, weight: .semibold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .foregroundStyle(tone == .off ? Color.haloSecondaryText : Color.haloInk)
        }
        .font(.system(size: DesignTokens.TypeRamp.label, weight: .medium))
        .accessibilityElement(children: .combine)
    }

    /// SF Symbol for the tone (also used by tests and the docs).
    var symbol: String {
        switch tone {
        case .good: "checkmark.circle.fill"
        case .waiting: "clock.fill"
        case .off: "minus.circle"
        case .warning: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .good: .haloSuccess
        case .waiting: Color.token(T.waiting)
        case .off: .haloSecondaryText
        case .warning: .haloDanger
        }
    }
}

/// Secondary explanatory line with an optional SF Symbol.
struct FootnoteText: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.xs + DesignTokens.Space.xxs) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(Color.haloSecondaryText)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(verbatim: text)
                .foregroundStyle(Color.haloSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: DesignTokens.TypeRamp.label))
        .accessibilityElement(children: .combine)
    }
}

/// Short format label in a pill ("JPG"). Families share four fills (cobalt,
/// orange, flame, ink); the label itself always says what it is.
struct FormatChip: View {
    let label: String
    var kind: FileKind = .other
    var size: CGFloat = DesignTokens.Component.FormatChip.defaultSize

    var body: some View {
        Text(verbatim: label)
            .font(.system(size: size, weight: .bold))
            .lineLimit(1)
            .foregroundStyle(FormatChip.onTint(for: kind))
            .padding(.horizontal, size * 0.6)
            .padding(.vertical, size * 0.22)
            .frame(minWidth: size * 3.6)
            .background(Capsule().fill(FormatChip.tint(for: kind)))
            .accessibilityLabel(Text(verbatim: label))
    }

    /// The family fill.
    static func tint(for kind: FileKind) -> Color {
        let t = DesignTokens.Component.FormatChip.self
        switch kind {
        case .image, .vector: return .iris
        case .video, .audio: return Color(hex: DesignTokens.Primitive.orange500)
        case .pdf: return Color(hex: DesignTokens.Primitive.flame500)
        case .document, .ebook, .slides, .spreadsheet, .subtitle: return Color.token(t.neutralFill)
        case .archive, .folder, .other: return Color.token(t.quietFill)
        }
    }

    /// Text or glyph colour on `tint(for:)`, AA in both appearances: white on
    /// cobalt (5.0:1) and grey, black on orange (9.6:1) and flame (6.3:1).
    static func onTint(for kind: FileKind) -> Color {
        switch kind {
        case .image, .vector, .archive, .folder, .other: return Color(hex: DesignTokens.Semantic.onAccentPrimary)
        case .video, .audio, .pdf: return Color(hex: DesignTokens.Semantic.onAccentSecondary)
        case .document, .ebook, .slides, .spreadsheet, .subtitle:
            return Color.token(DesignTokens.Component.FormatChip.neutralText)
        }
    }
}

extension FileKind {
    /// Plural section title for settings lists.
    var sectionTitle: String {
        switch self {
        case .image: String(localized: "Images")
        case .vector: String(localized: "Vector")
        case .audio: String(localized: "Audio")
        case .video: String(localized: "Video")
        case .pdf: String(localized: "PDF")
        case .document: String(localized: "Documents")
        case .slides: String(localized: "Presentations")
        case .spreadsheet: String(localized: "Spreadsheets & data")
        case .ebook: String(localized: "Ebooks")
        case .subtitle: String(localized: "Subtitles")
        case .archive: String(localized: "Archives")
        case .folder: String(localized: "Folders")
        case .other: String(localized: "Other")
        }
    }
}

// MARK: - System Settings links

enum SystemSettingsLink {
    static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    static let automation = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    static let inputMonitoring = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    static let keyboardShortcuts = "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts"

    @MainActor
    static func open(_ link: String) {
        guard let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Compatibility

extension View {
    /// `onChange(of:)` that compiles cleanly on macOS 13 and 14+.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14, *) {
            onChange(of: value) { _, new in action(new) }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
