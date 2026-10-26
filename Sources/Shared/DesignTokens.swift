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

    /// Raw colours, sRGB hex. *s* = sampled from the reference, *d* = derived for AA contrast.
    public enum Primitive {
        public static let ink1000 = 0x000000   // s  page black
        public static let ink950 = 0x0A0A0A    // d  window background (dark)
        public static let ink900 = 0x1F1F1F    // s  charcoal tiles
        public static let ink800 = 0x2A2A2A    // d  raised controls, segments at rest
        public static let ink700 = 0x3A3A3A    // d  hairlines on charcoal
        public static let ink500 = 0x6E6E6E    // s  dimmed display text: large type only (3.2:1 on charcoal)
        public static let ink400 = 0x9A9A9A    // d  secondary text on charcoal (5.9:1)
        public static let ink300 = 0x5C5C5C    // d  secondary text on white (6.7:1)
        public static let paper0 = 0xFFFFFF    // s  text on dark, light surface
        public static let paper50 = 0xF2F2F2   // d  light tiles
        public static let paper100 = 0xE4E4E4  // d  light hairlines
        public static let cobalt500 = 0x2766EE // s  primary pill, progress, focus (white text 5.0:1)
        public static let cobalt400 = 0x5B8CFF // d  cobalt text/glyph on black (6.3:1)
        public static let cobalt700 = 0x1D4FD8 // d  cobalt text on white (6.6:1)
        public static let cobaltTop = 0x3E28D1 // s  sampled, kept for the record; unused (too close to violet)
        public static let cobaltBright = 0x2E6BF2 // s blue gradient bottom band
        public static let orange500 = 0xFF9500 // s  secondary pill (black text 9.6:1; white fails at 2.2:1)
        public static let orange600 = 0xFF7D00 // s  gradient mid band
        public static let flame500 = 0xFF4C00  // s  errors, big numerals (black text 6.3:1; white only ≥ 18 pt bold)
        public static let flame600 = 0xFF2600  // s  gradient hot end
        public static let ember700 = 0xC91B00  // s  deep red band
        public static let peach200 = 0xFFCAA0  // s  orange → white fade
        public static let cream100 = 0xFFF0D9  // s  last band before white
    }

    /// What colours are for, per appearance (sRGB hex). Dark is the hero.
    public enum Semantic {
        public static let windowBackground = (light: Primitive.paper0, dark: Primitive.ink950)
        public static let tile = (light: Primitive.paper50, dark: Primitive.ink900)
        public static let raised = (light: Primitive.paper0, dark: Primitive.ink800)
        public static let hairline = (light: Primitive.paper100, dark: Primitive.ink700)
        public static let textPrimary = (light: Primitive.ink950, dark: Primitive.paper0)
        public static let textSecondary = (light: Primitive.ink300, dark: Primitive.ink400)
        /// Big display words only (≥ 24 pt): the reference's dimmed grey.
        public static let textDimDisplay = (light: Primitive.ink400, dark: Primitive.ink500)
        public static let accentPrimary = (light: Primitive.cobalt500, dark: Primitive.cobalt500)
        public static let accentPrimaryText = (light: Primitive.cobalt700, dark: Primitive.cobalt400)
        public static let accentSecondary = (light: Primitive.orange500, dark: Primitive.orange500)
        /// Errors always carry an icon and a label too; never colour alone.
        public static let stateError = (light: Primitive.flame500, dark: Primitive.flame500)
        /// Success is cobalt plus a check glyph (no green).
        public static let stateSuccess = (light: Primitive.cobalt500, dark: Primitive.cobalt500)
        public static let focusRing = (light: Primitive.cobalt700, dark: Primitive.cobalt400)
        public static let onAccentPrimary = Primitive.paper0
        public static let onAccentSecondary = Primitive.ink1000
    }

    /// Banded gradients: hard-edged vertical bands, each a short fade, used once
    /// per surface like a spotlight. Reduce Transparency / Increased Contrast swap
    /// them for a flat fill and an outline.
    public enum Band {
        public static let heat = [Primitive.flame600, Primitive.orange600, Primitive.orange500,
                                  Primitive.peach200, Primitive.cream100, Primitive.paper0]
        /// Starts from deep cobalt, not the reference's indigo top band (#3E28D1),
        /// which reads as the purple the brief rules out.
        public static let cobalt = [Primitive.cobalt700, Primitive.cobalt500, Primitive.cobaltBright]
        /// The solid stand-in when bands are off.
        public static let heatFlat = Primitive.orange500
        public static let cobaltFlat = Primitive.cobalt500
    }

    /// Two radii only, plus the wheel's segment corner.
    public enum Shape {
        public static let tile: CGFloat = 14
        public static let pill: CGFloat = 999
        public static let segment: CGFloat = 8
        public static let hairline: CGFloat = 1
    }

    /// Type: a heavy display face for format names, numerals and headlines;
    /// the system face for everything else.
    public enum Typeface {
        /// Bundled, SIL OFL 1.1 (LICENSES/inter-4.1). PostScript names.
        public static let displayBlack = "InterDisplay-Black"
        public static let displayExtraBold = "InterDisplay-ExtraBold"
        /// Tracking for display sizes, as a fraction of the point size.
        public static let displayTracking: CGFloat = -0.03
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
        /// sRGB hex, light / dark. Accent *fill* (buttons, selection, progress).
        /// As small text on black use `Semantic.accentPrimaryText` (4.97:1 vs 3.95:1).
        public static let iris = (light: Primitive.cobalt500, dark: Primitive.cobalt500)
        /// Secondary accent (fills with black text).
        public static let mint = (light: Primitive.orange500, dark: Primitive.orange500)
        public static let ink = (light: Primitive.ink950, dark: Primitive.paper0)
        public static let mist = (light: Primitive.ink300, dark: Primitive.ink400)
        /// Errors: ember on white (5.9:1), flame on black (6.6:1). Always with an icon + label.
        public static let danger = (light: Primitive.ember700, dark: Primitive.flame500)
        /// Success is cobalt + a check glyph (no green, no colour-only meaning).
        public static let success = (light: Primitive.cobalt700, dark: Primitive.cobalt400)
        /// Pro marks: orange (light text needs the deeper shade, 5.3:1 on white).
        public static let proGold = (light: 0xB54A00, dark: Primitive.orange500)
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
        public static let segmentGapDegrees: CGFloat = 2
        public static let segmentCornerRadius: CGFloat = 8
        public static let maxPerInnerRing = 8
        public static let maxPerOuterRing = 12
        public static let hoverScale: CGFloat = 1.06
        public static let hoverLift: CGFloat = 5
        public static let glyphSize: CGFloat = 18
        public static let labelSize: CGFloat = 11.5
        /// Format names in the display face (phase 2).
        public static let titleLabelSize: CGFloat = 17
        public static let toolLabelSize: CGFloat = 9.5
        public static let screenEdgeInset: CGFloat = 8
        /// Keep the wheel out of the Mission Control / menu bar drag band.
        public static let topExclusion: CGFloat = 24
        /// Minimum alpha painted on every hit area so drags are delivered (D-003).
        public static let minimumHitAlpha: CGFloat = 0.01
    }
}
