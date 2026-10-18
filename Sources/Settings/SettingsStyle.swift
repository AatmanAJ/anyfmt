import SwiftUI
import HaloCore

// Small pieces the Settings panes share, in the phase 2 language: ink tiles,
// cobalt for "on", Inter Display only where a word or number leads the pane.

/// A square glyph on a tile beside a row label (wheel roles, packs, notes).
/// Cobalt with a white glyph, or `quiet`: a charcoal tile with a cobalt glyph.
struct SettingsGlyphTile: View {
    let symbol: String
    var quiet = false
    @Environment(\.colorSchemeContrast) private var contrast

    private typealias T = DesignTokens.Component.Settings

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: T.glyphSize, weight: .semibold))
            .foregroundStyle(quiet ? Color.accentText : Color(hex: DesignTokens.Semantic.onAccentPrimary))
            .frame(width: T.glyphTile, height: T.glyphTile)
            .background(shape.fill(quiet ? Color.haloRaised : Color.iris))
            .haloBorder(shape, contrast == .increased ? Color.haloInk : .clear)
            .accessibilityHidden(true)
    }
}

/// A calm empty, loading or problem state inside a section: glyph, one line
/// of plain copy, an optional next step.
struct SettingsStateRow<Action: View>: View {
    enum Kind { case empty, loading, problem }
    let kind: Kind
    let title: String
    var detail: String?
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.m) {
            Group {
                switch kind {
                case .loading: ProgressView().controlSize(.small)
                case .empty: Image(systemName: "tray").foregroundStyle(Color.haloSecondaryText)
                case .problem: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.haloDanger)
                }
            }
            .frame(width: DesignTokens.Component.Settings.rowIconWidth)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                Text(verbatim: title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                    .foregroundStyle(kind == .problem ? Color.haloDanger : Color.haloInk)
                if let detail {
                    Text(verbatim: detail)
                        .font(.system(size: DesignTokens.TypeRamp.label))
                        .foregroundStyle(Color.haloSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DesignTokens.Space.s)
            action()
        }
        .padding(.vertical, DesignTokens.Space.xxs)
        .accessibilityElement(children: .combine)
    }
}

extension SettingsStateRow where Action == EmptyView {
    init(kind: Kind, title: String, detail: String? = nil) {
        self.init(kind: kind, title: title, detail: detail) { EmptyView() }
    }
}

/// A pill-shaped token button (naming tokens): charcoal pill, cobalt text.
struct SettingsTokenPill: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.accentText)
            .padding(.horizontal, DesignTokens.Space.s)
            .padding(.vertical, DesignTokens.Space.xxs + 1)
            .background(Capsule().fill(Color.token(DesignTokens.Component.Settings.chipFill)))
            .contentShape(Capsule())
    }
}
