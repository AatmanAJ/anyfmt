import AppKit
import SwiftUI
import HaloCore

// Small shared controls for Halo's SwiftUI windows (settings, onboarding,
// about, the wheel's options popover).

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

/// The standard switch, except in snapshot renders (see `isSnapshot`).
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
                .fill(Color.white)
                .frame(width: w * 0.6, height: h - 3)
                .shadow(color: .black.opacity(0.18), radius: 0.8, y: 0.5)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                Text(verbatim: subtitle)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(.secondary)
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

// MARK: - Key caps

/// A key as printed on an Apple keyboard: "⇧ Shift" on a small cap.
struct KeyCap: View {
    let text: String
    var prominent = false
    var compact = false

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .rounded))
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 3)
            .frame(minWidth: compact ? 20 : 26)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(Color.iris) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
                    .shadow(color: .black.opacity(prominent ? 0.25 : 0.12), radius: 0, y: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(prominent ? Color.clear : Color.primary.opacity(0.14), lineWidth: 0.5)
            }
    }
}

// MARK: - Status

/// Coloured dot + label, e.g. "● Granted".
struct StatusBadge: View {
    enum Tone { case good, waiting, off, warning }
    let tone: Tone
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(verbatim: text).foregroundStyle(.secondary)
        }
        .font(.system(size: DesignTokens.TypeRamp.label))
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch tone {
        case .good: .haloSuccess
        case .waiting: Color(nsColor: .systemYellow)
        case .off: Color(nsColor: .tertiaryLabelColor)
        case .warning: .haloDanger
        }
    }
}

/// Secondary explanatory line with an optional SF Symbol.
struct FootnoteText: View {
    let text: String
    var symbol: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(.secondary).imageScale(.small)
            }
            Text(verbatim: text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: DesignTokens.TypeRamp.label))
    }
}

/// Short format label in a rounded chip ("JPG").
struct FormatChip: View {
    let label: String
    var kind: FileKind = .other
    var size: CGFloat = 10.5

    var body: some View {
        Text(verbatim: label)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(Color.white)
            .padding(.horizontal, size * 0.55)
            .padding(.vertical, size * 0.2)
            .frame(minWidth: size * 3.6)
            .background(RoundedRectangle(cornerRadius: size * 0.45, style: .continuous).fill(FormatChip.tint(for: kind)))
    }

    /// One calm hue per family, all from the iris/mint palette family.
    static func tint(for kind: FileKind) -> Color {
        switch kind {
        case .image, .vector: .iris
        case .video: Color(nsColor: .halo((light: 0x5B4BD6, dark: 0x7A6CF0)))
        case .audio: .mint
        case .pdf: Color(nsColor: .halo((light: 0xD14D72, dark: 0xF06A8F)))
        case .document, .ebook: Color(nsColor: .halo((light: 0x3B82C4, dark: 0x5EA2E6)))
        case .slides: Color(nsColor: .halo((light: 0x8E5BD0, dark: 0xA97BEB)))
        case .spreadsheet: Color(nsColor: .halo((light: 0x2E9E6A, dark: 0x45BE85)))
        case .subtitle: Color(nsColor: .halo((light: 0x6B6977, dark: 0x8E8C99)))
        case .archive, .folder, .other: Color(nsColor: .halo((light: 0x7A7484, dark: 0x8F8999)))
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
