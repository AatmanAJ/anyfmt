import AppKit
import QuartzCore

/// The centre disc: thumbnail (stacked for multi-file), count chip and the
/// label pill that shows the hovered target's name (or the idle text).
@MainActor
final class HubNode {
    let shadow = CALayer()
    let mask = CAShapeLayer()
    let container = CALayer()
    private let material = CAShapeLayer()
    private let fill = CAShapeLayer()
    private let rim = CAShapeLayer()
    private let stroke = CAShapeLayer()
    private let thumbnail = CALayer()
    private let countBadge = CALayer()
    private let pill = CALayer()

    private var pillCache: [String: (CGImage?, CGSize)] = [:]
    private var pillText = ""
    private var pillHighlighted = false

    init(canvas: CGRect, scale: CGFloat) {
        for layer in [shadow, mask, container, material, fill, rim, stroke, thumbnail, countBadge, pill] as [CALayer] {
            layer.contentsScale = scale
            layer.actions = SegmentNode.noActions
        }
        for layer in [shadow, mask, container, material, fill, rim, stroke] as [CALayer] { layer.frame = canvas }
        mask.fillColor = NSColor.black.cgColor
        rim.fillColor = nil
        stroke.fillColor = nil
        shadow.shadowOffset = CGSize(width: 0, height: -2)
        thumbnail.contentsGravity = .center
        countBadge.contentsGravity = .center
        pill.contentsGravity = .center
        for l in [material, fill, rim, stroke, thumbnail, countBadge, pill] { container.addSublayer(l) }
    }

    func install(shadowRoot: CALayer, maskRoot: CALayer?, overlayRoot: CALayer) {
        shadowRoot.addSublayer(shadow)
        maskRoot?.addSublayer(mask)
        overlayRoot.addSublayer(container)
    }

    var movingLayers: [CALayer] { [shadow, mask, container] }

    func layout(center: CGPoint, config: RadialMenuConfiguration, palette p: RadialPalette, liveMaterial: Bool) {
        let disc = WedgePath.circle(radius: config.hubRadius, center: center)
        var strokeDisc = WedgePath.circle(radius: config.hubRadius - max(0.25, p.strokeWidth / 2), center: center)
        if p.strokeWidth <= 0 { strokeDisc = disc }
        LayerAnimation.withoutActions {
            for l in [mask, material, fill, rim] { l.path = disc }
            stroke.path = strokeDisc
            shadow.shadowPath = disc
            material.fillColor = liveMaterial ? nil : p.material
            material.isHidden = liveMaterial
            fill.fillColor = p.hubFill
            rim.strokeColor = p.rim
            rim.lineWidth = p.rimWidth
            stroke.strokeColor = p.stroke
            stroke.lineWidth = max(1 / max(1, container.contentsScale), p.strokeWidth)
            shadow.shadowColor = p.shadowColor
            shadow.shadowOpacity = p.shadowOpacity
            shadow.shadowRadius = p.shadowRadius
            thumbnail.position = CGPoint(x: center.x, y: center.y + 5)
            pill.position = CGPoint(x: center.x, y: center.y - config.hubRadius + 9)
        }
        pillCache.removeAll()
    }

    func setThumbnail(_ content: RadialHubContent, config: RadialMenuConfiguration, palette p: RadialPalette,
                      center: CGPoint, scale: CGFloat, animated: Bool) {
        let side = config.thumbnailSize
        let image = ContentRenderer.thumbnailImage(content.image, stackCount: content.stackCount, side: side,
                                                   palette: p, scale: scale)
        if animated {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.12
            thumbnail.add(fade, forKey: "contents")
        }
        LayerAnimation.withoutActions {
            thumbnail.bounds = CGRect(x: 0, y: 0, width: side + 16, height: side + 16)
            thumbnail.contents = image
        }
        if content.stackCount > 1 {
            let (badge, size) = ContentRenderer.countBadge(content.stackCount, palette: p, scale: scale)
            LayerAnimation.withoutActions {
                countBadge.isHidden = false
                countBadge.bounds = CGRect(origin: .zero, size: size)
                countBadge.contents = badge
                countBadge.position = CGPoint(x: center.x + side * 0.36, y: center.y + 5 + side * 0.36)
            }
        } else {
            LayerAnimation.withoutActions { countBadge.isHidden = true }
        }
    }

    /// Shows `text` in the pill. `highlighted` paints it in the accent colour.
    func setPill(_ text: String, highlighted: Bool, config: RadialMenuConfiguration,
                 palette p: RadialPalette, scale: CGFloat, animated: Bool) {
        if text != pillText || highlighted != pillHighlighted || pill.contents == nil {
            pillText = text
            pillHighlighted = highlighted
            let key = "\(highlighted ? 1 : 0)|\(text)"
            let rendered = pillCache[key] ?? ContentRenderer.pillImage(text: text, highlighted: highlighted, palette: p,
                                                                       config: config, maxWidth: pillMaxWidth(config),
                                                                       scale: scale)
            pillCache[key] = rendered
            if animated {
                let fade = CATransition()
                fade.type = .fade
                fade.duration = 0.08
                pill.add(fade, forKey: "contents")
            }
            pill.set("bounds", to: CGRect(origin: .zero, size: rendered.1), animation: animated ? LayerAnimation.basic(0.12) : nil)
            LayerAnimation.withoutActions {
                pill.contents = rendered.0
                pill.isHidden = text.isEmpty
            }
        }
    }

    /// Widest pill that stays clear of the inner ring at the pill's height.
    private func pillMaxWidth(_ config: RadialMenuConfiguration) -> CGFloat {
        let r = config.innerRing.inner - 3
        let dy = config.hubRadius - 9
        return max(config.hubRadius * 1.5, 2 * sqrt(max(0, r * r - dy * dy)))
    }

    func pulse(palette p: RadialPalette) {
        let a = CAKeyframeAnimation(keyPath: "fillColor")
        a.values = [p.hubFill, p.highlightFill, p.hubFill]
        a.keyTimes = [0, 0.4, 1]
        a.duration = 0.18
        fill.add(a, forKey: "pulse")
    }
}

/// An empty ring that invites a drop (hotkey "drop ring").
@MainActor
final class DropZoneNode {
    let shadow = CALayer()
    let mask = CAShapeLayer()
    let container = CALayer()
    private let material = CAShapeLayer()
    private let fill = CAShapeLayer()
    private let rim = CAShapeLayer()
    private let dots = CAShapeLayer()
    private let glyph = CALayer()
    private var isTargeted = false

    init(canvas: CGRect, scale: CGFloat) {
        for layer in [shadow, mask, container, material, fill, rim, dots, glyph] as [CALayer] {
            layer.contentsScale = scale
            layer.actions = SegmentNode.noActions
        }
        for layer in [shadow, mask, container, material, fill, rim, dots] as [CALayer] { layer.frame = canvas }
        mask.fillColor = NSColor.black.cgColor
        mask.fillRule = .evenOdd
        material.fillRule = .evenOdd
        fill.fillRule = .evenOdd
        rim.fillColor = nil
        dots.fillColor = nil
        dots.lineCap = .round
        dots.lineDashPattern = [0.01, 9]
        dots.lineWidth = 2.5
        shadow.shadowOffset = CGSize(width: 0, height: -2)
        glyph.contentsGravity = .center
        for l in [material, fill, rim, dots, glyph] { container.addSublayer(l) }
        // Above the hub (which sits at 2) so the glyph shows in the centre.
        for l in movingLayers { l.zPosition = 3 }
    }

    var movingLayers: [CALayer] { [shadow, mask, container] }

    func install(shadowRoot: CALayer, maskRoot: CALayer?, overlayRoot: CALayer) {
        shadowRoot.addSublayer(shadow)
        maskRoot?.addSublayer(mask)
        overlayRoot.addSublayer(container)
    }

    func removeFromTrees() {
        for l in movingLayers { l.removeFromSuperlayer() }
    }

    func layout(zone: RadialDropZone, center: CGPoint, config: RadialMenuConfiguration, palette p: RadialPalette,
                liveMaterial: Bool, scale: CGFloat) {
        let ring = config.innerRing
        let band = CGMutablePath()
        band.addEllipse(in: CGRect(x: center.x - ring.outer, y: center.y - ring.outer, width: ring.outer * 2, height: ring.outer * 2))
        band.addEllipse(in: CGRect(x: center.x - ring.inner, y: center.y - ring.inner, width: ring.inner * 2, height: ring.inner * 2))
        let mid = ring.mid
        let dotted = CGPath(ellipseIn: CGRect(x: center.x - mid, y: center.y - mid, width: mid * 2, height: mid * 2), transform: nil)
        var glyphImage: CGImage?
        var glyphSize = CGSize.zero
        if let image = zone.image {
            let g = ContentRenderer.glyphImage(image, pointSize: 24)
            glyphSize = ContentRenderer.fit(g.size, into: 32)
            glyphImage = ContentRenderer.draw(size: glyphSize, scale: scale) { _ in
                ContentRenderer.drawImage(g, in: CGRect(origin: .zero, size: glyphSize), tint: p.secondaryContent)
            }
        }
        LayerAnimation.withoutActions {
            for l in [mask, material, fill, rim] { l.path = band }
            shadow.shadowPath = band
            material.fillColor = liveMaterial ? nil : p.material
            material.isHidden = liveMaterial
            fill.fillColor = p.restFill
            rim.strokeColor = p.rim
            rim.lineWidth = p.rimWidth
            dots.path = dotted
            dots.strokeColor = p.dropZoneStroke
            shadow.shadowColor = p.shadowColor
            shadow.shadowOpacity = p.shadowOpacity
            shadow.shadowRadius = p.shadowRadius
            glyph.bounds = CGRect(origin: .zero, size: glyphSize)
            glyph.contents = glyphImage
            glyph.position = CGPoint(x: center.x, y: center.y + 6)
        }
    }

    func setTargeted(_ on: Bool, palette p: RadialPalette, config: RadialMenuConfiguration, center: CGPoint,
                     reduceMotion: Bool, bounds: CGRect) {
        guard on != isTargeted else { return }
        isTargeted = on
        let quick = LayerAnimation.basic(0.12)
        fill.set("fillColor", to: on ? p.accent.withAlphaComponent(p.appearance.isDark ? 0.32 : 0.2).cgColor : p.restFill,
                 animation: quick)
        dots.set("strokeColor", to: on ? p.accent.cgColor : p.dropZoneStroke, animation: quick)
        guard !reduceMotion else { return }
        let spring = LayerAnimation.spring(config)
        let t = on ? CATransform3D.scale(1.035, about: center, in: bounds) : CATransform3DIdentity
        for l in movingLayers { l.set("transform", to: t, animation: spring) }
    }
}
