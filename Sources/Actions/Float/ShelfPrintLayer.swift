import AppKit
import AnyfmtCore

/// One item drawn as a physical object: a content thumbnail becomes a
/// bordered, square-cornered "print"; a Finder icon is drawn as-is with a
/// contact shadow. (Not main-actor isolated: Core Animation copies layers
/// for presentation on its own thread through `init(layer:)`.)
final class ShelfPrintLayer: CALayer {
    private let imageLayer = CALayer()
    private(set) var isIcon = true
    /// The image shown, reused as the drag image.
    private(set) var image: NSImage?
    static let border = DesignTokens.Component.Shelf.printBorder

    override init() {
        super.init()
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.minificationFilter = .trilinear
        addSublayer(imageLayer)
        shadowColor = NSColor.black.cgColor
        actions = Self.noActions
        imageLayer.actions = Self.noActions
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Implicit animations off: every animation here is explicit.
    static var noActions: [String: CAAction] {
        ["position": NSNull(), "bounds": NSNull(), "transform": NSNull(), "opacity": NSNull(),
         "contents": NSNull(), "backgroundColor": NSNull(), "shadowOpacity": NSNull(), "zPosition": NSNull(),
         "hidden": NSNull(), "sublayers": NSNull(), "frame": NSNull(), "borderColor": NSNull(),
         "shadowPath": NSNull(), "cornerRadius": NSNull(), "string": NSNull(), "foregroundColor": NSNull()]
    }

    /// Sizes the layer for `thumbnail` inside a `side`×`side` box. Content
    /// thumbnails become square-cornered prints with a paper border (the
    /// direction allows only the tile and pill radii, and a print has neither).
    @MainActor
    func configure(_ thumbnail: ShelfThumbnail, side: CGFloat, scale: CGFloat, appearance: NSAppearance) {
        isIcon = thumbnail.isIcon
        image = thumbnail.image
        contentsScale = scale
        imageLayer.contentsScale = scale
        imageLayer.contents = thumbnail.image.layerContents(forContentsScale: scale)
        let isDark = ActionStyle.isDark(appearance)
        cornerRadius = 0
        imageLayer.cornerRadius = 0

        if isIcon {
            bounds = CGRect(x: 0, y: 0, width: side, height: side)
            imageLayer.frame = bounds
            backgroundColor = nil
            borderWidth = 0
            // A Finder icon carries its own shape; just a contact shadow.
            shadowOpacity = isDark ? 0.5 : 0.18
            shadowRadius = 2
            shadowOffset = CGSize(width: 0, height: -1)
            shadowPath = nil
        } else {
            let inner = QuickLookThumbnails.fit(thumbnail.image.size, in: side - 2 * Self.border)
            bounds = CGRect(x: 0, y: 0, width: inner.width + 2 * Self.border, height: inner.height + 2 * Self.border)
            imageLayer.frame = bounds.insetBy(dx: Self.border, dy: Self.border)
            imageLayer.masksToBounds = true
            backgroundColor = ActionStyle.cg(ActionStyle.printPaper, in: appearance)
            borderWidth = isDark ? 0 : DesignTokens.Shape.hairline / 2
            borderColor = ActionStyle.cg(ActionStyle.printEdge, in: appearance)
            shadowOpacity = isDark ? 0.55 : 0.22
            shadowRadius = 4
            shadowOffset = CGSize(width: 0, height: -2)
            shadowPath = CGPath(rect: bounds, transform: nil)
        }
    }
}
