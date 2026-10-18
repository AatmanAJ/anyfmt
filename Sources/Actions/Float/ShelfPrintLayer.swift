import AppKit
import HaloCore

/// One item drawn as a physical object: a content thumbnail becomes a
/// bordered "print" with a soft shadow; a Finder icon is drawn as-is with a
/// lighter shadow. (Not main-actor isolated: Core Animation copies layers
/// for presentation on its own thread through `init(layer:)`.)
final class ShelfPrintLayer: CALayer {
    private let imageLayer = CALayer()
    private(set) var isIcon = true
    /// The image shown, reused as the drag image.
    private(set) var image: NSImage?
    static let border: CGFloat = 3

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

    /// Sizes the layer for `thumbnail` inside a `side`×`side` box.
    @MainActor
    func configure(_ thumbnail: ShelfThumbnail, side: CGFloat, scale: CGFloat, appearance: NSAppearance) {
        isIcon = thumbnail.isIcon
        image = thumbnail.image
        contentsScale = scale
        imageLayer.contentsScale = scale
        imageLayer.contents = thumbnail.image.layerContents(forContentsScale: scale)
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        if isIcon {
            bounds = CGRect(x: 0, y: 0, width: side, height: side)
            imageLayer.frame = bounds
            backgroundColor = nil
            cornerRadius = 0
            borderWidth = 0
            shadowOpacity = isDark ? 0.45 : 0.22
            shadowRadius = 3
            shadowOffset = CGSize(width: 0, height: -1.5)
            shadowPath = nil
        } else {
            let inner = QuickLookThumbnails.fit(thumbnail.image.size, in: side - 2 * Self.border)
            bounds = CGRect(x: 0, y: 0, width: inner.width + 2 * Self.border, height: inner.height + 2 * Self.border)
            imageLayer.frame = bounds.insetBy(dx: Self.border, dy: Self.border)
            imageLayer.cornerRadius = 1.5
            imageLayer.masksToBounds = true
            backgroundColor = (isDark ? NSColor(white: 0.93, alpha: 1) : NSColor.white).cgColor
            cornerRadius = 4
            cornerCurve = .continuous
            borderWidth = isDark ? 0 : 0.5
            borderColor = NSColor(white: 0, alpha: 0.08).cgColor
            shadowOpacity = isDark ? 0.55 : 0.28
            shadowRadius = 5
            shadowOffset = CGSize(width: 0, height: -2)
            shadowPath = CGPath(roundedRect: bounds, cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }
}

/// Count badge on the pile: iris capsule, white tabular digits, ringed in the
/// card colour so it reads on any thumbnail.
final class ShelfBadgeLayer: CALayer {
    private let text = CATextLayer()

    override init() {
        super.init()
        actions = ShelfPrintLayer.noActions
        text.actions = ShelfPrintLayer.noActions
        text.alignmentMode = .center
        text.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        text.fontSize = 11
        text.foregroundColor = NSColor.white.cgColor
        addSublayer(text)
        borderWidth = 2
        shadowColor = NSColor.black.cgColor
        shadowOpacity = 0.18
        shadowRadius = 2
        shadowOffset = CGSize(width: 0, height: -1)
    }

    override init(layer: Any) { super.init(layer: layer) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @MainActor
    func configure(count: Int, scale: CGFloat, appearance: NSAppearance) {
        let label = count > 999 ? "999+" : "\(count)"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        let width = ceil((label as NSString).size(withAttributes: [.font: font]).width)
        let height: CGFloat = 20
        bounds = CGRect(x: 0, y: 0, width: max(height, width + 12), height: height)
        cornerRadius = height / 2
        backgroundColor = ActionStyle.selection.cgColor
        borderColor = ActionStyle.cg(ActionStyle.solidCard, in: appearance)
        contentsScale = scale
        text.contentsScale = scale
        text.font = font
        text.string = label
        // CATextLayer has no vertical centring; offset by the font's metrics.
        let lineHeight = ceil(font.ascender - font.descender)
        text.frame = CGRect(x: 0, y: (height - lineHeight) / 2 - 0.5, width: bounds.width, height: lineHeight)
    }
}
