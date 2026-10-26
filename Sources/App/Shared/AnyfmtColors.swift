import AppKit
import SwiftUI
import AnyfmtCore

// SwiftUI / AppKit colours built from `DesignTokens` (Palette + Semantic). Every colour is
// dynamic: it resolves to the light or dark value for the view's appearance.

extension NSColor {
    /// sRGB colour from a 0xRRGGBB integer.
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    /// Dynamic colour from a DesignTokens light/dark pair.
    static func anyfmt(_ pair: (light: Int, dark: Int)) -> NSColor {
        let light = pair.light, dark = pair.dark
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }
}

extension Color {
    /// anyfmt's accent.
    static let iris = Color(nsColor: .anyfmt(DesignTokens.Palette.iris))
    /// Secondary accent.
    static let mint = Color(nsColor: .anyfmt(DesignTokens.Palette.mint))
    static let anyfmtInk = Color(nsColor: .anyfmt(DesignTokens.Palette.ink))
    static let anyfmtMist = Color(nsColor: .anyfmt(DesignTokens.Palette.mist))
    static let anyfmtDanger = Color(nsColor: .anyfmt(DesignTokens.Palette.danger))
    static let anyfmtSuccess = Color(nsColor: .anyfmt(DesignTokens.Palette.success))
    /// The accent as text or small glyphs (AA on both appearances).
    static let accentText = Color(nsColor: .anyfmt(DesignTokens.Semantic.accentPrimaryText))
    static let anyfmtWindow = Color(nsColor: .anyfmt(DesignTokens.Semantic.windowBackground))
    static let anyfmtTile = Color(nsColor: .anyfmt(DesignTokens.Semantic.tile))
    static let anyfmtRaised = Color(nsColor: .anyfmt(DesignTokens.Semantic.raised))
    static let anyfmtHairline = Color(nsColor: .anyfmt(DesignTokens.Semantic.hairline))
    static let anyfmtSecondaryText = Color(nsColor: .anyfmt(DesignTokens.Semantic.textSecondary))
}

extension Font {
    /// DesignTokens type ramp as SwiftUI fonts.
    static func anyfmt(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
