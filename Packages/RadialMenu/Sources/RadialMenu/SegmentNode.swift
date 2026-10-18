import AppKit
import QuartzCore

/// Everything Core Animation needs for one segment, across the three layer
/// trees (shadow under the material, material mask, overlay above it). Every
/// geometry change is applied to all of them with the same animation, so the
/// vibrancy, shadow and tint always move as one piece.
@MainActor
final class SegmentNode {
    let shadow = CALayer()
    let mask = CAShapeLayer()
    let container = CALayer()
    private let material = CAShapeLayer()
    private let fill = CAShapeLayer()
    private let rim = CAShapeLayer()
    private let stroke = CAShapeLayer()
    private(set) var content = CALayer()
    private var normalImage = CALayer()
    private var highlightImage = CALayer()

    private(set) var slot: RadialSlot
    private(set) var itemID: String
    private(set) var isEnabled = true
    private(set) var isHighlighted = false
    private var restSpec: WedgePath.Spec
    private var contentCenter: CGPoint = .zero
    private var outward: CGPoint = .zero

    init(slot: RadialSlot, itemID: String, canvas: CGRect, scale: CGFloat) {
        self.slot = slot
        self.itemID = itemID
        restSpec = WedgePath.Spec(start: slot.midAngle, end: slot.midAngle, inner: slot.band.inner,
                                  outer: slot.band.inner, gap: 0, corner: 0)
        for layer in [shadow, mask, container, material, fill, rim, stroke] as [CALayer] {
            layer.frame = canvas
            layer.contentsScale = scale
            layer.actions = SegmentNode.noActions
        }
        for layer in [material, fill, rim, stroke] as [CAShapeLayer] {
            layer.frame = canvas
        }
        mask.fillColor = NSColor.black.cgColor
        rim.fillColor = nil
        stroke.fillColor = nil
        shadow.shadowOffset = CGSize(width: 0, height: -2)
        fill.shadowOffset = CGSize(width: 0, height: -2)
        fill.shadowRadius = 12
        fill.shadowOpacity = 0
        container.addSublayer(material)
        container.addSublayer(fill)
        container.addSublayer(rim)
        container.addSublayer(stroke)
        configureContent(content, normal: normalImage, highlight: highlightImage, scale: scale)
        container.addSublayer(content)
    }

    static let noActions: [String: any CAAction] = [
        "position": NSNull(), "bounds": NSNull(), "path": NSNull(), "transform": NSNull(), "opacity": NSNull(),
        "contents": NSNull(), "fillColor": NSNull(), "strokeColor": NSNull(), "shadowPath": NSNull(),
        "shadowOpacity": NSNull(), "zPosition": NSNull(), "hidden": NSNull(), "sublayers": NSNull(),
        "onOrderIn": NSNull(), "onOrderOut": NSNull(), "lineWidth": NSNull(), "frame": NSNull(),
    ]

    private func configureContent(_ c: CALayer, normal: CALayer, highlight: CALayer, scale: CGFloat) {
        for l in [c, normal, highlight] {
            l.contentsScale = scale
            l.actions = SegmentNode.noActions
        }
        normal.contentsGravity = .center
        highlight.contentsGravity = .center
        highlight.opacity = 0
        c.addSublayer(normal)
        c.addSublayer(highlight)
    }

    func install(shadowRoot: CALayer, maskRoot: CALayer?, overlayRoot: CALayer) {
        shadowRoot.addSublayer(shadow)
        maskRoot?.addSublayer(mask)
        overlayRoot.addSublayer(container)
    }

    func removeFromTrees() {
        shadow.removeFromSuperlayer()
        mask.removeFromSuperlayer()
        container.removeFromSuperlayer()
    }

    /// The three layers that move together for entrances and exits.
    var movingLayers: [CALayer] { [shadow, mask, container] }

    // MARK: Appearance

    func applyPalette(_ p: RadialPalette, liveMaterial: Bool) {
        LayerAnimation.withoutActions {
            material.fillColor = liveMaterial ? nil : p.material
            material.isHidden = liveMaterial
            fill.fillColor = isHighlighted ? (isEnabled ? p.highlightFill : p.disabledHighlightFill) : p.restFill
            fill.shadowColor = p.glowColor
            rim.strokeColor = p.rim
            rim.lineWidth = p.rimWidth
            stroke.strokeColor = isHighlighted && isEnabled ? p.highlightStroke : p.stroke
            stroke.lineWidth = max(1 / max(1, container.contentsScale), p.strokeWidth)
            shadow.shadowColor = p.shadowColor
            shadow.shadowOpacity = p.shadowOpacity
            shadow.shadowRadius = p.shadowRadius
        }
    }

    // MARK: Geometry

    struct Images {
        var normal: CGImage?
        /// Rendered lazily on first hover (keeps the open path short).
        var highlight: (() -> CGImage?)?
        var size: CGSize
    }

    private var highlightProvider: (() -> CGImage?)?

    /// Moves this node to `slot` (morphing paths) and shows `images`. When the item
    /// changes during an animated move, old content fades out while new content fades in.
    func update(slot newSlot: RadialSlot, itemID newID: String, enabled: Bool, images: Images,
                layout: RadialLayout, center: CGPoint, palette p: RadialPalette, animation: CABasicAnimation?) {
        let itemChanged = newID != itemID
        slot = newSlot
        itemID = newID
        isEnabled = enabled
        let config = layout.configuration
        restSpec = WedgePath.Spec(start: newSlot.startAngle, end: newSlot.endAngle, inner: newSlot.band.inner,
                                  outer: newSlot.band.outer, gap: config.gapWidth, corner: config.cornerRadius)
        if newSlot.span >= 2 * .pi - 1e-4 {
            // A single item is a seamless ring.
            restSpec.gap = 0
            restSpec.corner = 0
        }
        let offset = layout.contentCenter(of: newSlot)
        contentCenter = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
        let len = max(1, hypot(offset.x, offset.y))
        outward = CGPoint(x: offset.x / len, y: offset.y / len)
        if isHighlighted {
            isHighlighted = false
            resetHighlightVisuals(palette: p)
        }
        applyGeometry(restSpec, center: center, animation: animation)

        if itemChanged, let animation {
            let old = content
            let fresh = CALayer(), n = CALayer(), h = CALayer()
            configureContent(fresh, normal: n, highlight: h, scale: container.contentsScale)
            set(images, on: fresh, normal: n, highlight: h)
            fresh.position = old.presentation()?.position ?? old.position
            container.addSublayer(fresh)
            content = fresh
            normalImage = n
            highlightImage = h
            fresh.set("position", to: contentCenter, animation: animation)
            fresh.animate("opacity", from: 0, animation: animation)
            old.set("position", to: contentCenter, animation: animation)
            CATransaction.begin()
            CATransaction.setCompletionBlock { old.removeFromSuperlayer() }
            old.set("opacity", to: 0, animation: LayerAnimation.basic(animation.duration * 0.6))
            CATransaction.commit()
        } else {
            set(images, on: content, normal: normalImage, highlight: highlightImage)
            content.set("position", to: contentCenter, animation: animation)
        }
        content.set("transform", to: CATransform3DIdentity, animation: animation)
    }

    private func set(_ images: Images, on c: CALayer, normal: CALayer, highlight: CALayer) {
        highlightProvider = images.highlight
        LayerAnimation.withoutActions {
            c.bounds = CGRect(origin: .zero, size: images.size)
            normal.frame = c.bounds
            highlight.frame = c.bounds
            normal.contents = images.normal
            highlight.contents = nil
        }
    }

    private func ensureHighlightImage() {
        guard highlightImage.contents == nil, let provider = highlightProvider else { return }
        let image = provider()
        LayerAnimation.withoutActions { highlightImage.contents = image }
    }

    /// Re-renders content in place (appearance or scale change).
    func replaceImages(_ images: Images) {
        set(images, on: content, normal: normalImage, highlight: highlightImage)
    }

    private func applyGeometry(_ spec: WedgePath.Spec, center: CGPoint, animation: CABasicAnimation?) {
        let path = WedgePath.path(spec, center: center)
        var strokeSpec = spec
        strokeSpec.inset = stroke.lineWidth / 2
        let full = WedgePath.isFullRing(spec)
        let strokePath = full ? WedgePath.ringOutline(strokeSpec, center: center) : WedgePath.path(strokeSpec, center: center)
        for layer in [mask, material, fill] {
            layer.set("path", to: path, animation: animation)
        }
        rim.set("path", to: full ? WedgePath.ringOutline(spec, center: center) : path, animation: animation)
        stroke.set("path", to: strokePath, animation: animation)
        shadow.set("shadowPath", to: path, animation: animation)
        fill.set("shadowPath", to: path, animation: animation)
    }

    /// Collapses to a sliver at its own bisector (for segments a morph removes).
    func collapse(center: CGPoint, animation: CABasicAnimation?) {
        var spec = restSpec
        spec.start = slot.midAngle
        spec.end = slot.midAngle
        applyGeometry(spec, center: center, animation: animation)
        content.set("opacity", to: 0, animation: animation.map { a in
            let b = LayerAnimation.basic(a.duration * 0.5)
            return b
        })
    }

    /// Grows a brand-new node out of a sliver at its bisector (morph entrances).
    func growFromSliver(center: CGPoint, animation: CABasicAnimation) {
        var sliver = restSpec
        sliver.start = slot.midAngle
        sliver.end = slot.midAngle
        applyGeometry(sliver, center: center, animation: nil)
        applyGeometry(restSpec, center: center, animation: animation)
        LayerAnimation.withoutActions { content.opacity = 1 }
        content.animate("opacity", from: Float(0), animation: animation)
    }

    // MARK: Hover

    func setHighlighted(_ on: Bool, palette p: RadialPalette, config: RadialMenuConfiguration, center: CGPoint,
                        reduceMotion: Bool, animated: Bool = true) {
        guard on != isHighlighted else { return }
        isHighlighted = on
        let spring: CABasicAnimation? = animated ? LayerAnimation.spring(config) : nil
        let quick: CABasicAnimation? = animated ? LayerAnimation.basic(0.1, LayerAnimation.easeOut) : nil
        let liftable = on && isEnabled && !reduceMotion
        applyGeometry(liftable ? lifted(config) : restSpec, center: center, animation: reduceMotion ? nil : spring)

        let fillColor = on ? (isEnabled ? p.highlightFill : p.disabledHighlightFill) : p.restFill
        fill.set("fillColor", to: fillColor, animation: quick)
        fill.set("shadowOpacity", to: liftable ? p.glowOpacity : Float(0), animation: quick)
        stroke.set("strokeColor", to: on && isEnabled ? p.highlightStroke : p.stroke, animation: quick)
        let showHighlight = on && isEnabled
        if showHighlight { ensureHighlightImage() }
        highlightImage.set("opacity", to: showHighlight ? Float(1) : Float(0), animation: quick)
        normalImage.set("opacity", to: showHighlight ? Float(0) : Float(1), animation: quick)
        LayerAnimation.withoutActions {
            for l in movingLayers { l.zPosition = on ? 1 : 0 }
        }
        let target: CATransform3D
        if liftable {
            let lift = config.hoverLift * 0.6
            target = CATransform3DScale(CATransform3DMakeTranslation(outward.x * lift, outward.y * lift, 0),
                                        config.hoverScale, config.hoverScale, 1)
        } else {
            target = CATransform3DIdentity
        }
        content.set("transform", to: target, animation: reduceMotion ? nil : spring)
    }

    private func resetHighlightVisuals(palette p: RadialPalette) {
        LayerAnimation.withoutActions {
            fill.removeAllAnimations()
            fill.fillColor = p.restFill
            stroke.strokeColor = p.stroke
            fill.shadowOpacity = 0
            highlightImage.opacity = 0
            normalImage.opacity = 1
            for l in movingLayers { l.zPosition = 0 }
        }
    }

    /// Hovered shape: reaches outward by the lift plus the scale, and widens a
    /// touch into the gaps so it reads as sitting above its neighbours.
    private func lifted(_ config: RadialMenuConfiguration) -> WedgePath.Spec {
        var s = restSpec
        let depth = s.outer - s.inner
        s.outer += config.hoverLift + depth * (config.hoverScale - 1)
        let full = WedgePath.isFullRing(s)
        let widen = full ? 0 : min((s.end - s.start) * (config.hoverScale - 1) / 2, config.gapWidth * 0.35 / max(1, slot.band.mid))
        s.start -= widen
        s.end += widen
        return s
    }

    /// Brief fill pulse when a drop lands on this segment.
    func pulse(palette p: RadialPalette, duration: Double) {
        let a = CAKeyframeAnimation(keyPath: "fillColor")
        a.values = [p.highlightFill, p.confirmFill, p.highlightFill]
        a.keyTimes = [0, 0.35, 1]
        a.duration = duration * 2
        fill.add(a, forKey: "pulse")
        let base = content.transform
        let s = CAKeyframeAnimation(keyPath: "transform")
        s.values = [base, CATransform3DScale(base, 1.08, 1.08, 1), base].map { NSValue(caTransform3D: $0) }
        s.keyTimes = [0, 0.35, 1]
        s.duration = duration * 2
        content.add(s, forKey: "pulse")
    }

    /// Centre of the content (canvas coordinates), for accessibility and popovers.
    var contentFrame: CGRect {
        CGRect(x: contentCenter.x - content.bounds.width / 2, y: contentCenter.y - content.bounds.height / 2,
               width: content.bounds.width, height: content.bounds.height)
    }
}
