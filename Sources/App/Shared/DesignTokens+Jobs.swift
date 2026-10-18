import CoreGraphics
import HaloCore

// Component tokens for the jobs surfaces: progress cards, the "+N more" card
// and toasts (PLAN-PHASE2 §2, board 5-progress-cards-dark). Built only from
// the shared scales, so a change to the system flows through.

extension DesignTokens.Component {
    /// A progress card: a charcoal tile with the big numeral on the left and
    /// the file, detail and cobalt band bar on the right.
    enum ProgressCard {
        typealias S = DesignTokens.Space
        typealias T = DesignTokens.Typeface.Size

        static let width: CGFloat = 420
        static let padding = S.l
        static let numeralColumn: CGFloat = 116
        static let columnGap = S.m
        /// Percent, size change or duration.
        static let numeralSize = T.displayL
        /// The failure glyph sits where the numeral would.
        static let glyphSize = T.displayM + S.s
        static let headlineSize = T.body
        static let detailSize = T.label
        static let rowGap = S.xs
        static let barHeight: CGFloat = 6
        static let barTop = S.s + S.xxs
        /// The small check / warning glyph before the headline.
        static let statusGlyphSize = T.body + S.xxs
        /// Compact quiet button (Cancel, Show in Finder) in the detail row.
        static let quietButtonHeight: CGFloat = 20
        static let messageTop = S.s
        static let actionsTop = S.m
        /// Gap between stacked cards (the board's rhythm).
        static let stackSpacing = DesignTokens.Component.Tile.spacing
        /// "+3 more" card.
        static let summaryHeight: CGFloat = 44
        static let summaryNumeralSize = T.displayM
        /// Transparent margin around each card inside its panel, for its one shadow.
        static let shadowMargin: CGFloat = 22
        static let edgeInset = S.m
        /// The newest card's top edge sits this far below the drop point, so the
        /// pointer isn't left resting on it (which would pause auto-close).
        static let anchorGap: CGFloat = 26
        static let maxVisible = 5
    }

    /// The single floating-window shadow (`elevation.float`). One layer, no stack.
    enum Elevation {
        static let floatRadius: CGFloat = 18
        static let floatOffsetY: CGFloat = 8
        static let floatOpacityDark = 0.6
        static let floatOpacityLight = 0.12
    }

    /// Toasts: a charcoal pill (one line) or tile (wrapped), icon + text.
    enum Toast {
        static let maxWidth: CGFloat = 360
        static let horizontalPadding = DesignTokens.Space.l
        static let verticalPadding = DesignTokens.Space.s + DesignTokens.Space.xxs
        static let iconSpacing = DesignTokens.Space.s
        static let glyphSize = DesignTokens.Typeface.Size.body + DesignTokens.Space.xxs
        static let textSize = DesignTokens.Typeface.Size.body
        static let gapBelowPointer: CGFloat = 28
        static let screenInset = DesignTokens.Space.s
        static let successDuration: Double = 1.6
        static let errorDuration: Double = 3.5
    }
}
