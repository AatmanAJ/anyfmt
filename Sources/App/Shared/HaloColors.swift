import AppKit
import SwiftUI
import HaloCore

// SwiftUI / AppKit colours built from `DesignTokens.Palette`. Every colour is
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
    static func halo(_ pair: (light: Int, dark: Int)) -> NSColor {
        let light = pair.light, dark = pair.dark
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }
}

extension Color {
    /// Halo's accent.
    static let iris = Color(nsColor: .halo(DesignTokens.Palette.iris))
    /// Secondary accent.
    static let mint = Color(nsColor: .halo(DesignTokens.Palette.mint))
    static let haloInk = Color(nsColor: .halo(DesignTokens.Palette.ink))
    static let haloMist = Color(nsColor: .halo(DesignTokens.Palette.mist))
    static let haloDanger = Color(nsColor: .halo(DesignTokens.Palette.danger))
    static let haloSuccess = Color(nsColor: .halo(DesignTokens.Palette.success))
}

extension Font {
    /// DesignTokens type ramp as SwiftUI fonts.
    static func halo(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
