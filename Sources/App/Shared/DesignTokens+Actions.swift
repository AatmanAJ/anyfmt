import CoreGraphics
import AnyfmtCore

// Component tokens for the action surfaces: the Float shelf, the Move chooser
// and the small controls they share (PLAN-PHASE2 §2). Charcoal tiles, display
// numerals for counts, cobalt for selection and drop targets.

extension DesignTokens.Component {
    enum Shelf {
        typealias S = DesignTokens.Space
        typealias T = DesignTokens.Typeface.Size

        static let cornerRadius = DesignTokens.Shape.tile
        static let padding: CGFloat = 14
        static let headerHeight: CGFloat = 40
        /// The count in "5 items", set in the display face.
        static let countSize = T.displayM
        static let titleSize = T.body
        static let detailSize = T.label
        static let cellLabelSize = T.label
        /// Thumbnails drawn as square-cornered prints with a paper border.
        static let printBorder: CGFloat = 3
        /// The ✕ / ⋯ / chevron controls.
        static let controlDiameter: CGFloat = 20
        static let controlGlyph: CGFloat = 9.5
        static let badgeDiameter: CGFloat = 18
        static let badgeGlyph: CGFloat = 7.5
        /// Dashed drop zone on the empty shelf.
        static let dropDash: [CGFloat] = [5, 4]
        static let dropLineWidth: CGFloat = 1.5
        static let emptyGlyph: CGFloat = 24
        /// The cobalt outline while files are dragged over the shelf (no glow).
        static let dropOutlineWidth: CGFloat = 2
    }

    enum MoveChooser {
        static let width: CGFloat = 300
        static let rowHeight: CGFloat = 38
        static let headerHeight: CGFloat = 34
        static let padding = DesignTokens.Space.s - DesignTokens.Space.xxs
        static let iconSize: CGFloat = 22
        static let nameSize = DesignTokens.Typeface.Size.body
        static let detailSize = DesignTokens.Typeface.Size.label
        static let headerSize = DesignTokens.Typeface.Size.label
    }

    /// Shadow margin around action cards: their windows are this much larger so
    /// the card can cast its one (animatable) floating shadow.
    enum ActionCard {
        static let shadowMargin: CGFloat = 26
    }
}
