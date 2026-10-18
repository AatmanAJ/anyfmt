import CoreGraphics
import HaloCore

// Component tokens for the tool editors (crop, adjust, trim, bleep …), PLAN-PHASE2 §2.
// Editors read these instead of hard-coding sizes or colours. Everything here is
// bound to primitives or semantics in `DesignTokens`.

extension DesignTokens.Component {
    enum Editor {
        // MARK: Layout

        static let sidebarWidth: CGFloat = 300
        /// Outer margin of the window and the gap between canvas and sidebar.
        static let gutter: CGFloat = DesignTokens.Space.l
        /// Space between sidebar tiles.
        static let sectionSpacing: CGFloat = DesignTokens.Component.Tile.spacing
        /// Inner padding of a sidebar tile.
        static let sectionPadding: CGFloat = DesignTokens.Space.m + 2
        /// The editor's name at the top of the sidebar ("CROP").
        static let titleSize: CGFloat = DesignTokens.Typeface.Size.displayL
        /// Headline of an empty, loading or error state.
        static let stateTitleSize: CGFloat = DesignTokens.Typeface.Size.displayM
        static let stateMaxWidth: CGFloat = 380
        static let stateGlyphSize: CGFloat = DesignTokens.Typeface.Size.displayM
        /// Chips: choice rows and small secondary actions.
        static let chipHeight: CGFloat = 26
        static let chipPadding: CGFloat = DesignTokens.Space.m
        /// Big option cells (aspect ratios, annotate tools).
        static let cellHeight: CGFloat = 46
        static let cellGlyphSize: CGFloat = DesignTokens.TypeRamp.title
        /// Keyboard legend caps.
        static let keyCapMinWidth: CGFloat = 44
        /// Switch track.
        static let switchSize = CGSize(width: 32, height: 18)
        /// Sidebar thumbnails (frames, reorder rows).
        static let thumbnail = CGSize(width: 64, height: 36)
        static let rowThumbnail: CGFloat = 34
        static let swatch: CGFloat = 20

        // MARK: Colour (light / dark pairs)

        /// The well the image or video sits in: pure black on the dark hero,
        /// light grey on white so white images keep an edge.
        static let canvas = (light: DesignTokens.Primitive.paper50, dark: DesignTokens.Primitive.ink1000)
        /// Raised controls on a tile (chips, keycaps, list wells).
        static let chip = DesignTokens.Semantic.raised
        /// Selected chips and cells: cobalt with white text (5.0:1).
        static let selected = (light: DesignTokens.Primitive.cobalt500, dark: DesignTokens.Primitive.cobalt500)
        static let onSelected = DesignTokens.Semantic.onAccentPrimary
        /// Warnings ("this re-encodes"): deep orange on white (5.3:1), orange on black.
        /// Always paired with a glyph and words.
        static let warning = DesignTokens.Palette.proGold
        /// Transparency checkerboard (content backdrop, same in both appearances).
        static let checkerLight = DesignTokens.Primitive.paper0
        static let checkerDark = DesignTokens.Primitive.paper100

        /// Marks drawn over arbitrary pixels (crop frame, selection, playhead).
        /// A dark halo, a white rim and a cobalt core, so they read on any image.
        enum Overlay {
            static let core = DesignTokens.Primitive.cobalt500
            static let rim = DesignTokens.Primitive.paper0
            static let halo = DesignTokens.Primitive.ink1000
            static let haloOpacity: Double = 0.55
            static let haloOpacityIncreased: Double = 0.9
            /// Core line width; the rim and halo add `rimWidth` / `haloWidth` per side.
            static let lineWidth: CGFloat = 1.5
            static let lineWidthIncreased: CGFloat = 2.5
            static let rimWidth: CGFloat = 1
            static let haloWidth: CGFloat = 1
            /// Square resize handles and round point handles.
            static let handle: CGFloat = 11
            /// Crop corner brackets.
            static let cornerLength: CGFloat = 18
            static let cornerWidth: CGFloat = 3.5
            /// Dimming outside a crop or trim selection.
            static let dim: Double = 0.55
            static let dimIncreased: Double = 0.72
            static let thirds: Double = 0.4
            static let thirdsActive: Double = 0.7
            /// Size badge text on the dark halo colour.
            static let badgeOpacity: Double = 0.78
        }

        /// Filmstrip and waveform timelines.
        enum Timeline {
            static let stripHeight: CGFloat = 56
            static let handleWidth: CGFloat = 14
            static let rulerHeight: CGFloat = 18
            static let playheadWidth: CGFloat = 2
            static let knob: CGFloat = 11
            /// In / out labels above the handles.
            static let labelHeight: CGFloat = 18
            static let waveformMinHeight: CGFloat = 150
            static let waveformMaxHeight: CGFloat = 340
            static let overviewHeight: CGFloat = 6
            static let partsHeight: CGFloat = 22
        }
    }
}
