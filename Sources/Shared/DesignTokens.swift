import Foundation
import CoreGraphics

/// Halo's own visual language. Every UI surface (wheel, editors, settings,
/// progress, onboarding) pulls sizes, type, colour and motion from here.
/// Palette: "iris" violet accent + "mint" secondary on neutral greys.
public enum DesignTokens {
    public enum Palette {
        /// sRGB hex, light / dark.
        public static let iris = (light: 0x6E56F8, dark: 0x8B78FF)
        public static let mint = (light: 0x14B8A0, dark: 0x3DD9BF)
        public static let ink = (light: 0x1C1B22, dark: 0xF4F3F8)
        public static let mist = (light: 0x6B6977, dark: 0xA19FAD)
        public static let danger = (light: 0xE5484D, dark: 0xFF6369)
        public static let success = (light: 0x30A46C, dark: 0x4CC38A)
        public static let proGold = (light: 0xC28A00, dark: 0xF5C451)
    }

    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let small: CGFloat = 6
        public static let medium: CGFloat = 10
        public static let large: CGFloat = 14
        public static let window: CGFloat = 16
    }

    /// Type ramp (points). Wheel labels use `caption`/`label`; editors use `body`.
    public enum TypeRamp {
        public static let micro: CGFloat = 9      // Pro chip
        public static let caption: CGFloat = 10.5 // secondary segment text
        public static let label: CGFloat = 12     // segment label
        public static let body: CGFloat = 13
        public static let title: CGFloat = 15
        public static let headline: CGFloat = 20
        public static let display: CGFloat = 28   // onboarding
    }

    public enum Motion {
        /// Spring for hover lift. Tuned by eye at 120 Hz.
        public static let hoverResponse: Double = 0.25
        public static let hoverDamping: Double = 0.8
        /// Whole open animation budget (segments staggered inside it).
        public static let openTotal: Double = 0.17
        public static let openStaggerPerSegment: Double = 0.012
        public static let close: Double = 0.12
        public static let morph: Double = 0.16
        public static let dropConfirm: Double = 0.09
        public static let crossfade: Double = 0.12
    }

    /// Wheel geometry in points. Starting values informed by
    /// research/INTERACTION_NOTES.md; see docs/DECISIONS.md.
    public enum Wheel {
        public static let hubRadius: CGFloat = 44
        public static let hubDeadZone: CGFloat = 36
        public static let ringInner: CGFloat = 58
        public static let ringOuter: CGFloat = 138
        public static let secondRingOuter: CGFloat = 206
        public static let segmentGapDegrees: CGFloat = 1.6
        public static let segmentCornerRadius: CGFloat = 8
        public static let maxPerInnerRing = 8
        public static let maxPerOuterRing = 14
        public static let hoverScale: CGFloat = 1.06
        public static let hoverLift: CGFloat = 6
        public static let glyphSize: CGFloat = 20
        public static let screenEdgeInset: CGFloat = 8
    }
}
