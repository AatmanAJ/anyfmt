import CoreGraphics
import AnyfmtCore

// Component tokens for the cloud screens (Pro explainer, share-link options,
// upload notice, account, licence, plan badges). Colours come only from
// `DesignTokens.Primitive` / `Semantic`; `CloudStyle` resolves them per
// appearance, including the increased-contrast variants.

extension DesignTokens.Component {
    enum Cloud {
        typealias Pair = (light: Int, dark: Int)
        private typealias P = DesignTokens.Primitive

        // Panel widths: one editorial column each.
        static let explainerWidth: CGFloat = 420
        static let shareWidth: CGFloat = 440
        static let noticeWidth: CGFloat = 400
        static let panelPadding: CGFloat = DesignTokens.Space.xxl

        /// Headline sizes.
        static let headline: CGFloat = DesignTokens.Typeface.Size.displayL
        static let headlineCompact: CGFloat = DesignTokens.Typeface.Size.displayM

        /// The one band per surface: a square glyph tile on the cobalt band.
        static let glyphTile: CGFloat = 56
        static let glyphSize: CGFloat = DesignTokens.Typeface.Size.displayM
        static let factIconWidth: CGFloat = 18
        static let inboxIcon: CGFloat = 16

        // Pro chip: orange with black text (9.6:1), never gold.
        static let proFill: Pair = (light: P.ember500, dark: P.ember500)
        static let proText: Pair = (light: P.ink1000, dark: P.ink1000)
        /// Increased contrast keeps the orange and adds an ink outline.
        static let proOutline: Pair = (light: P.ink1000, dark: P.paper0)

        // Semantic colours with their increased-contrast partners.
        static let accent: Pair = DesignTokens.Palette.iris
        static let accentHC: Pair = (light: P.ink950, dark: P.paper0)
        static let accentText: Pair = DesignTokens.Semantic.accentPrimaryText
        static let accentTextHC: Pair = (light: P.ink950, dark: P.paper0)
        static let ink: Pair = DesignTokens.Palette.ink
        static let inkHC: Pair = (light: P.ink1000, dark: P.paper0)
        static let secondary: Pair = DesignTokens.Semantic.textSecondary
        static let secondaryHC: Pair = (light: P.ink950, dark: P.paper50)
        static let danger: Pair = DesignTokens.Palette.danger
        static let dangerHC: Pair = (light: P.ember700, dark: P.ember300)
        static let success: Pair = DesignTokens.Palette.success
        static let successHC: Pair = (light: P.ink950, dark: P.paper0)
        static let tile: Pair = DesignTokens.Semantic.tile
        static let tileHC: Pair = (light: P.paper0, dark: P.ink1000)
        static let hairline: Pair = DesignTokens.Semantic.hairline
        static let hairlineHC: Pair = (light: P.ink950, dark: P.paper0)
        static let window: Pair = DesignTokens.Semantic.windowBackground
        static let onAccent: Pair = (light: P.paper0, dark: P.paper0)
    }
}
