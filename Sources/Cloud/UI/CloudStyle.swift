import SwiftUI
import AppKit
import AnyfmtCore

/// Colours for the cloud UI from `DesignTokens.Component.Cloud`, resolved per
/// appearance (light / dark / increased contrast). Namespaced so nothing
/// here collides with other lanes' helpers in the app module.
enum CloudStyle {
    typealias Pair = (light: Int, dark: Int)
    private typealias T = DesignTokens.Component.Cloud

    static func color(_ pair: Pair, highContrast: Pair? = nil) -> Color {
        Color(nsColor: nsColor(pair, highContrast: highContrast))
    }

    static func nsColor(_ pair: Pair, highContrast: Pair? = nil) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let chosen = isIncreased(match) ? (highContrast ?? pair) : pair
            return rgb(dark ? chosen.dark : chosen.light)
        }
    }

    private static func isIncreased(_ match: NSAppearance.Name?) -> Bool {
        match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
            || increasedContrastPreview.current
    }

    /// Renders the increased-contrast variants regardless of the system setting.
    /// Only the offscreen screenshot tests set this: AppKit can't force the
    /// accessibility appearances on a view (they resolve to plain Aqua).
    static let increasedContrastPreview = CloudLocked(false)

    /// Increased contrast from the environment, or forced by the screenshot tests.
    static func isHighContrast(_ contrast: ColorSchemeContrast) -> Bool {
        contrast == .increased || increasedContrastPreview.current
    }

    static func rgb(_ hex: Int) -> NSColor { NSColor(hex: hex) } // token-ok: resolves a token value, never a literal

    /// Pro marks: orange fill, black text (9.6:1). Never gold.
    static let proGold = color(T.proFill)
    static let onGold = color(T.proText)
    static let proOutline = color(T.proOutline)
    /// Cobalt fill (pills, Team badge).
    static let iris = color(T.accent, highContrast: T.accentHC)
    /// Cobalt as text or a small glyph.
    static let irisText = color(T.accentText, highContrast: T.accentTextHC)
    /// Kept for callers of the old name; the secondary accent is orange now.
    static let mint = proGold
    static let ink = color(T.ink, highContrast: T.inkHC)
    static let mist = color(T.secondary, highContrast: T.secondaryHC)
    static let danger = color(T.danger, highContrast: T.dangerHC)
    static let success = color(T.success, highContrast: T.successHC)
    static let tile = color(T.tile, highContrast: T.tileHC)
    static let hairline = color(T.hairline, highContrast: T.hairlineHC)
    static let window = color(T.window)
    static let onAccent = color(T.onAccent)
}

/// "Free" / "Pro" / "Team" pill for Settings › Account. Pro is orange with
/// black text, Team cobalt with white, Free a quiet outlined pill. The word
/// itself carries the plan, so colour is never the only signal.
struct CloudPlanBadge: View {
    let plan: Plan
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(plan.displayName)
            .font(.system(size: DesignTokens.TypeRamp.caption, weight: .bold))
            .padding(.horizontal, DesignTokens.Space.s + DesignTokens.Space.xxs)
            .padding(.vertical, DesignTokens.Space.xxs + 1)
            .foregroundStyle(foreground)
            .background(Capsule().fill(fill))
            .anyfmtBorder(Capsule(), stroke)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Plan: \(plan.displayName)"))
    }

    private var fill: Color {
        switch plan {
        case .free: CloudStyle.tile
        case .pro: CloudStyle.proGold
        case .team: CloudStyle.iris
        }
    }

    private var foreground: Color {
        switch plan {
        case .free: CloudStyle.ink
        case .pro: CloudStyle.onGold
        case .team: CloudStyle.onAccent
        }
    }

    private var stroke: Color {
        switch plan {
        case .free: CloudStyle.hairline
        case .pro, .team: CloudStyle.isHighContrast(contrast) ? CloudStyle.proOutline : .clear
        }
    }
}

/// The small cloud glyph + "PRO" chip shown on server-backed features:
/// orange, black text, a pill.
struct CloudProChip: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: DesignTokens.Space.xxs) {
            Image(systemName: "icloud.fill")
                .font(.system(size: DesignTokens.TypeRamp.micro, weight: .bold))
            Text("Pro")
                .font(.system(size: DesignTokens.TypeRamp.micro + 1, weight: .bold))
        }
        .padding(.horizontal, DesignTokens.Space.xs + DesignTokens.Space.xxs)
        .padding(.vertical, DesignTokens.Space.xxs)
        .foregroundStyle(CloudStyle.onGold)
        .background(Capsule().fill(CloudStyle.proGold))
        .anyfmtBorder(Capsule(), CloudStyle.isHighContrast(contrast) ? CloudStyle.proOutline : .clear)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pro, uses \(Brand.name) Cloud"))
    }
}

/// Inline status line for the cloud screens: glyph + plain sentence.
struct CloudStatusLine: View {
    enum Tone { case info, success, error }
    let text: String
    var tone: Tone = .info
    var size: CGFloat = DesignTokens.TypeRamp.body

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.s) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(verbatim: text)
                .foregroundStyle(tone == .error ? CloudStyle.danger : CloudStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .font(.system(size: size, weight: tone == .error ? .medium : .regular))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch tone {
        case .info: "info.circle"
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .info: CloudStyle.mist
        case .success: CloudStyle.success
        case .error: CloudStyle.danger
        }
    }
}
