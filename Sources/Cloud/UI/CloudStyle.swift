import SwiftUI
import AppKit
import HaloCore

/// Colours for the cloud UI from `DesignTokens.Palette`, resolved per
/// appearance (light / dark / increased contrast). Namespaced so nothing
/// here collides with other lanes' helpers in the app module.
enum CloudStyle {
    typealias Pair = (light: Int, dark: Int)

    static func color(_ pair: Pair, highContrast: Pair? = nil) -> Color {
        Color(nsColor: nsColor(pair, highContrast: highContrast))
    }

    static func nsColor(_ pair: Pair, highContrast: Pair? = nil) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            let increased = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
            let chosen = increased ? (highContrast ?? pair) : pair
            return rgb(dark ? chosen.dark : chosen.light)
        }
    }

    static func rgb(_ hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    static let proGold = color(DesignTokens.Palette.proGold, highContrast: (light: 0x8F6400, dark: 0xFFD978))
    static let iris = color(DesignTokens.Palette.iris, highContrast: (light: 0x4A32D4, dark: 0xB4A8FF))
    static let mint = color(DesignTokens.Palette.mint, highContrast: (light: 0x0B7A6A, dark: 0x6FF0D9))
    static let ink = color(DesignTokens.Palette.ink, highContrast: (light: 0x000000, dark: 0xFFFFFF))
    static let mist = color(DesignTokens.Palette.mist, highContrast: (light: 0x3F3D49, dark: 0xD0CEDA))
    static let danger = color(DesignTokens.Palette.danger, highContrast: (light: 0xB4161B, dark: 0xFF8A8F))
    static let success = color(DesignTokens.Palette.success, highContrast: (light: 0x1C6B44, dark: 0x7FE0AE))
    /// Text on a gold or light fill: always near-black so it reads in both modes.
    static let onGold = color((light: 0x1C1B22, dark: 0x1C1B22))
}

/// "Free" / "Pro" / "Team" capsule for Settings › Account.
struct CloudPlanBadge: View {
    let plan: Plan

    var body: some View {
        Text(plan.displayName.uppercased())
            .font(.system(size: DesignTokens.TypeRamp.caption, weight: .bold, design: .rounded))
            .tracking(0.6)
            .padding(.horizontal, DesignTokens.Space.s)
            .padding(.vertical, DesignTokens.Space.xxs + 1)
            .foregroundStyle(foreground)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(stroke, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Plan: \(plan.displayName)"))
    }

    private var fill: Color {
        switch plan {
        case .free: .clear
        case .pro: CloudStyle.proGold
        case .team: CloudStyle.iris
        }
    }

    private var stroke: Color {
        plan == .free ? CloudStyle.mist.opacity(0.6) : .clear
    }

    private var foreground: Color {
        switch plan {
        case .free: CloudStyle.mist
        case .pro: CloudStyle.onGold
        case .team: .white
        }
    }
}

/// The small cloud glyph + "PRO" chip shown on server-backed features.
struct CloudProChip: View {
    var body: some View {
        HStack(spacing: DesignTokens.Space.xxs) {
            Image(systemName: "icloud.fill")
                .font(.system(size: DesignTokens.TypeRamp.micro, weight: .bold))
            Text("PRO")
                .font(.system(size: DesignTokens.TypeRamp.micro, weight: .heavy, design: .rounded))
                .tracking(0.5)
        }
        .padding(.horizontal, DesignTokens.Space.xs + 1)
        .padding(.vertical, DesignTokens.Space.xxs)
        .foregroundStyle(CloudStyle.onGold)
        .background(Capsule().fill(CloudStyle.proGold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pro, uses \(Brand.name) Cloud"))
    }
}
