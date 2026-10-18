import CoreGraphics
import HaloCore

// Component tokens for onboarding and About (PLAN-PHASE2 §2, "Onboarding" mood):
// full-bleed pages, a left-aligned editorial column, heavy uppercase headlines,
// one banded gradient per page used like a spotlight.
extension DesignTokens.Component {
    enum Onboarding {
        /// Window content size.
        static let windowWidth: CGFloat = 760
        static let windowHeight: CGFloat = 600
        /// Left and right page margin.
        static let margin: CGFloat = 48
        /// Top of the content, below the transparent title bar.
        static let top: CGFloat = 52
        /// Width of a page's band column when it has one.
        static let heatColumn: CGFloat = 232
        static let cobaltColumn: CGFloat = 120
        /// Headline sizes: the poster size, and the size for long headlines.
        static let headline: CGFloat = DesignTokens.Typeface.Size.displayXL
        static let headlineWelcome: CGFloat = 56
        static let headlineCompact: CGFloat = 52
        /// Display lines sit tight, like the board (a fraction of the point size).
        static let headlineLeading: CGFloat = -0.2
        /// Readable measure for the subtitle.
        static let subtitleWidth: CGFloat = 440
        static let subtitleSize: CGFloat = 15
        /// Widest a tile on a page grows.
        static let tileWidth: CGFloat = 560
        /// Short display tag in front of a fact line ("LOCAL").
        static let tagWidth: CGFloat = 68
        static let tagSize: CGFloat = 13

        /// Progress dots: the rest colour is large-UI grey (3:1+ on both
        /// surfaces); the current step is cobalt *and* wider, so it never
        /// rides on colour alone.
        /// The permissions page's cobalt column: deep to bright, never toward violet.
        static let cobaltBands = [DesignTokens.Primitive.cobalt700, DesignTokens.Primitive.cobalt500,
                                  DesignTokens.Primitive.cobaltBright, DesignTokens.Primitive.cobalt400]

        static let dotSize: CGFloat = 6
        static let dotCurrentWidth: CGFloat = 20
        static let dotSpacing: CGFloat = 7
        static let dotRest = (light: DesignTokens.Primitive.ink400, dark: DesignTokens.Primitive.ink500)

        /// The demo stage (a charcoal tile) and its wheel.
        static let stageWidth: CGFloat = 420
        static let stageHeight: CGFloat = 392
        static let demoColumn: CGFloat = 216
        static let keyCapWidth: CGFloat = 96
        static let keyCapHeight: CGFloat = 26
        /// The demo wheel is a black disc in both appearances, like a record.
        static let wheelDisc = DesignTokens.Primitive.ink1000
        static let wheelWedge = DesignTokens.Primitive.ink800
        static let wheelLabel = DesignTokens.Primitive.paper0
        static let wheelLabelOnBand = DesignTokens.Primitive.ink1000
        /// Wide enough that the lifted, scaled hot wedge stays on the disc.
        static let wheelRim: CGFloat = 13
        static let wheelGap: CGFloat = 5
        static let formatLabel: CGFloat = 19
        static let toolLabel: CGFloat = 10
        static let toolLabelWidth: CGFloat = 66
        /// The sample file as Finder shows it.
        static let fileIcon: CGFloat = 72
        static let fileBorder: CGFloat = 3

        /// About window.
        static let aboutWidth: CGFloat = 440
        static let aboutHeight: CGFloat = 580
        static let aboutBand: CGFloat = 92
        static let aboutIcon: CGFloat = 56
    }
}
