import Foundation
import CoreGraphics

/// anyfmt's own visual language. Every UI surface (wheel, editors, settings,
/// progress, onboarding) pulls sizes, type, colour and motion from here.
public enum DesignTokens {
    // MARK: - Phase 2 system: primitives → semantic → component (PLAN-PHASE2 §2)
    //
    // Primitives are raw values sampled from the art direction (or derived for
    // contrast). Semantic tokens say what a colour is *for*, per appearance.
    // Component tokens bind semantics to a part. UI code uses semantic or
    // component tokens only; primitives exist so the system can be read in one place.

    /// Raw colours, sRGB hex: the anyfmt brand (ink and paper greys, one ember accent, a volt
    /// highlight used sparingly), with a few shades derived so text passes WCAG AA.
    public enum Primitive {
        public static let ink1000 = 0x000000   //    pure black (badge text on ember)
        public static let ink950 = 0x0A0A0A    //    ink: type, primary buttons, dark windows
        public static let ink900 = 0x141414    //    dark tiles
        public static let ink800 = 0x1E1E1E    //    dark raised controls, segments at rest
        public static let ink700 = 0x2E2E2E    //    hairlines on dark
        public static let ink500 = 0x6E6E6E    //    dimmed display text: large type only
        public static let ink400 = 0x9A9A9A    // d  secondary text on dark (7.0:1)
        public static let ink300 = 0x5C5C5C    // d  secondary text on paper (6.7:1)
        public static let paper0 = 0xFFFFFF    //    paper: light windows and cards
        public static let paper50 = 0xF4F2EF   //    sand: light tiles and sections
        public static let paper75 = 0xEFEFEF   //    fog: behind the glass
        public static let paper100 = 0xE6E3DF  //    light hairlines (warm)
        public static let ember500 = 0xFF4A14  //    the accent: the dot, the hot segment, progress
        public static let ember600 = 0xEE1200  //    the deep end of the heat
        public static let ember700 = 0xC2300A  // d  ember as text on paper (5.6:1) and errors on paper
        public static let ember300 = 0xFF6B4D  // d  ember as text on ink (7.0:1) and errors on ink
        public static let amber400 = 0xFFB23E  //    the hot end of the heat
        public static let peach200 = 0xFFD2B0  //    heat fading to paper
        public static let cream100 = 0xFFF1D6  //    the light's core
        public static let volt400 = 0xE4FF3A   //    highlight: one per surface, ink text only
    }

    /// What colours are for, per appearance (sRGB hex).
    public enum Semantic {
        public static let windowBackground = (light: Primitive.paper0, dark: Primitive.ink950)
        public static let tile = (light: Primitive.paper50, dark: Primitive.ink900)
        public static let raised = (light: Primitive.paper0, dark: Primitive.ink800)
        public static let hairline = (light: Primitive.paper100, dark: Primitive.ink700)
        public static let textPrimary = (light: Primitive.ink950, dark: Primitive.paper0)
        public static let textSecondary = (light: Primitive.ink300, dark: Primitive.ink400)
        /// Big display words only (≥ 24 pt).
        public static let textDimDisplay = (light: Primitive.ink400, dark: Primitive.ink500)
        /// The action colour: primary buttons, selected chips and segments of a control. Ink on
        /// paper, paper on ink, so it always reads as the strongest thing on the surface.
        public static let accentPrimary = (light: Primitive.ink950, dark: Primitive.paper0)
        /// Ember as text or a small glyph, AA on both appearances.
        public static let accentPrimaryText = (light: Primitive.ember700, dark: Primitive.ember300)
        /// The heat: the hot wheel segment, progress, the dot. Text on it is large and bold, or ink.
        public static let accentSecondary = (light: Primitive.ember500, dark: Primitive.ember500)
        /// Errors always carry an icon and a label too; never colour alone.
        public static let stateError = (light: Primitive.ember700, dark: Primitive.ember300)
        /// Success is ink plus a check glyph (no green).
        public static let stateSuccess = (light: Primitive.ink950, dark: Primitive.paper0)
        public static let focusRing = (light: Primitive.ember700, dark: Primitive.ember300)
        /// Text on `accentPrimary`.
        public static let onAccentPrimary = (light: Primitive.paper0, dark: Primitive.ink950)
        /// Text on `accentSecondary` (ember): ink, 5.9:1.
        public static let onAccentSecondary = Primitive.ink1000
        /// The one highlight per surface ("New", "None needed"). Ink text only.
        public static let highlight = Primitive.volt400
    }

    /// The heat: the ember glow behind the brand's fluted glass, used once per surface like a
    /// spotlight. Reduce Transparency / Increased Contrast swap it for a flat fill.
    public enum Band {
        public static let heat = [Primitive.ember600, Primitive.ember500, Primitive.amber400,
                                  Primitive.peach200, Primitive.cream100, Primitive.paper0]
        /// The quiet counterpart: ink into charcoal, for dark panels that sit beside the heat.
        public static let night = [Primitive.ink950, Primitive.ink900, Primitive.ink800]
        /// The solid stand-ins when bands are off.
        public static let heatFlat = Primitive.ember500
        public static let nightFlat = Primitive.ink950
    }

    /// Two radii only, plus the wheel's segment corner.
    public enum Shape {
        public static let tile: CGFloat = 14
        public static let pill: CGFloat = 999
        public static let segment: CGFloat = 8
        public static let hairline: CGFloat = 1
    }

    /// Type: Inter Tight (the brand face) for format names, numerals and headlines, set in
    /// sentence case with tight tracking; the system face for body text and controls.
    public enum Typeface {
        /// Bundled, SIL OFL 1.1 (LICENSES/inter-4.1). PostScript names.
        public static let displayBlack = "InterTight-ExtraBold"
        public static let displayExtraBold = "InterTight-Bold"
        public static let displaySemibold = "InterTight-SemiBold"
        /// Tracking for display sizes, as a fraction of the point size.
        public static let displayTracking: CGFloat = -0.04
        public enum Size {
            public static let displayXL: CGFloat = 64
            public static let displayL: CGFloat = 40
            public static let displayM: CGFloat = 24
            public static let title: CGFloat = 17
            public static let body: CGFloat = 13
            public static let label: CGFloat = 11
            public static let micro: CGFloat = 10
        }
    }

    /// Named motion curves (cubic bezier control points) and their durations.
    /// Reduce Motion replaces each with a crossfade of at most `reducedCrossfade`.
    public enum Curve {
        public static let snap = (c1: CGPoint(x: 0.2, y: 0), c2: CGPoint(x: 0, y: 1), duration: 0.12)
        public static let glide = (c1: CGPoint(x: 0.16, y: 1), c2: CGPoint(x: 0.3, y: 1), duration: 0.22)
        public static let settle = (c1: CGPoint(x: 0.34, y: 1.36), c2: CGPoint(x: 0.64, y: 1), duration: 0.28)
        public static let exit = (c1: CGPoint(x: 0.4, y: 0), c2: CGPoint(x: 1, y: 1), duration: 0.11)
        public static let reducedCrossfade = 0.12
    }

    /// Component tokens. Each area extends this in its own file
    /// (`DesignTokens+<Area>.swift`) so redesign work never collides in one file.
    public enum Component {
        public enum Pill {
            public static let height: CGFloat = 30
            public static let largeHeight: CGFloat = 36
            public static let horizontalPadding: CGFloat = 18
        }
        public enum Tile {
            public static let padding: CGFloat = 16
            public static let spacing: CGFloat = 10
        }
        public enum Stat {
            public static let valueSize: CGFloat = Typeface.Size.displayL
            public static let compactValueSize: CGFloat = Typeface.Size.displayM
        }
        public enum Focus {
            public static let ringWidth: CGFloat = 2
            public static let ringOffset: CGFloat = 2
        }
    }

    // MARK: - Palette (phase 2: the legacy names, now bound to the new primitives)
    //
    // Call sites predate the semantic layer; these names keep them working with
    // the new direction. New code uses `Semantic`, `Band` and `Shape`.

    public enum Palette {
        /// sRGB hex, light / dark. Action *fill* (buttons, selection): ink on paper, paper on ink.
        public static let iris = Semantic.accentPrimary
        /// The heat (ember) as a fill; text on it is ink or large bold paper.
        public static let mint = Semantic.accentSecondary
        public static let ink = (light: Primitive.ink950, dark: Primitive.paper0)
        public static let mist = (light: Primitive.ink300, dark: Primitive.ink400)
        /// Errors: always with an icon + label.
        public static let danger = Semantic.stateError
        /// Success is ink + a check glyph (no green, no colour-only meaning).
        public static let success = Semantic.stateSuccess
        /// Pro marks: ember (text shade on paper).
        public static let proGold = (light: Primitive.ember700, dark: Primitive.ember500)
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
        public static let openTotal: Double = 0.15
        public static let openStaggerPerSegment: Double = 0.008
        public static let close: Double = 0.11
        public static let morph: Double = 0.16
        public static let dropConfirm: Double = 0.09
        public static let crossfade: Double = 0.12
    }

    /// Wheel geometry in points. Starting values informed by
    /// research/INTERACTION_NOTES.md; see docs/DECISIONS.md.
    public enum Wheel {
        public static let hubRadius: CGFloat = 40
        public static let hubDeadZone: CGFloat = 34
        public static let thumbnailSize: CGFloat = 56
        public static let ringInner: CGFloat = 52
        public static let ringOuter: CGFloat = 124
        public static let secondRingInner: CGFloat = 130
        public static let secondRingOuter: CGFloat = 192
        public static let segmentGapDegrees: CGFloat = 3.5
        public static let segmentCornerRadius: CGFloat = 13
        public static let maxPerInnerRing = 8
        public static let maxPerOuterRing = 12
        public static let hoverScale: CGFloat = 1.06
        public static let hoverLift: CGFloat = 5
        public static let glyphSize: CGFloat = 18
        public static let labelSize: CGFloat = 11.5
        /// Format names in the display face (phase 2).
        public static let titleLabelSize: CGFloat = 16
        public static let toolLabelSize: CGFloat = 9.5
        public static let screenEdgeInset: CGFloat = 8
        /// Keep the wheel out of the Mission Control / menu bar drag band.
        public static let topExclusion: CGFloat = 24
        /// Minimum alpha painted on every hit area so drags are delivered (D-003).
        public static let minimumHitAlpha: CGFloat = 0.01
    }
}
