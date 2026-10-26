import CoreGraphics
import AnyfmtCore

// Component tokens for Settings and the small shared controls (KeyCap,
// StatusBadge, FormatChip, the hotkey recorder). Colours are semantic pairs
// built only from `DesignTokens.Primitive`, so the token lint stays clean.

extension DesignTokens.Component {
    /// A key as a small ink tile. One radius (`Shape.tile`), no shadow.
    enum KeyCap {
        static let fontSize: CGFloat = DesignTokens.TypeRamp.label
        static let compactFontSize: CGFloat = DesignTokens.TypeRamp.caption
        static let minWidth: CGFloat = 24
        static let compactMinWidth: CGFloat = 20
        static let height: CGFloat = 22
        static let compactHeight: CGFloat = 18
        static let horizontalPadding: CGFloat = DesignTokens.Space.s
        static let compactHorizontalPadding: CGFloat = DesignTokens.Space.xs + DesignTokens.Space.xxs
        /// Dark: a raised charcoal key. Light: a white key with a hairline.
        static let fill = (light: DesignTokens.Primitive.paper0, dark: DesignTokens.Primitive.ink800)
        static let stroke = (light: DesignTokens.Primitive.paper100, dark: DesignTokens.Primitive.ink700)
    }

    /// Icon + label status line ("Granted", "Waiting", "Off", "Needs attention").
    enum StatusBadge {
        static let iconSize: CGFloat = DesignTokens.TypeRamp.label
        static let spacing: CGFloat = DesignTokens.Space.xs + DesignTokens.Space.xxs
        /// Waiting: deep orange on white (5.3:1), orange on black.
        static let waiting = DesignTokens.Palette.proGold
    }

    /// Format family chips. Every fill is paired with a text colour that passes AA.
    enum FormatChip {
        static let defaultSize: CGFloat = DesignTokens.TypeRamp.caption
        /// Neutral families: ink text chip that inverts with the appearance.
        static let neutralFill = DesignTokens.Semantic.textPrimary
        static let neutralText = DesignTokens.Semantic.windowBackground
        /// Archives, folders and the rest: mid grey with white text (5.0:1 / 6.7:1).
        static let quietFill = (light: DesignTokens.Primitive.ink300, dark: DesignTokens.Primitive.ink500)
    }

    /// Settings window chrome and pane furniture.
    enum Settings {
        /// Square glyph tile beside a row (wheel roles, packs).
        static let glyphTile: CGFloat = 28
        static let glyphSize: CGFloat = DesignTokens.TypeRamp.body
        /// Big format name at the top of Formats › detail.
        static let formatTitleSize: CGFloat = DesignTokens.Typeface.Size.displayL
        /// Key numeral in the Engines header.
        static let numeralSize: CGFloat = DesignTokens.Typeface.Size.displayL
        /// Display headline in the Account fallback.
        static let headlineSize: CGFloat = DesignTokens.Typeface.Size.displayM
        static let sidebarWidth: CGFloat = 272
        static let searchHeight: CGFloat = 26
        static let rowIconWidth: CGFloat = 22
        static let tapTestIcon: CGFloat = DesignTokens.TypeRamp.title
        static let recorderMinWidth: CGFloat = 132
        static let tapSliderWidth: CGFloat = 170
        static let readoutWidth: CGFloat = 46
        /// Small pills inside a section row (naming tokens, "Built-in").
        static let chipFill = (light: DesignTokens.Primitive.paper100, dark: DesignTokens.Primitive.ink800)
    }
}
