import AppKit
import HaloCore

/// Colours, type, metrics and accessibility state shared by the shelf and the
/// Move chooser. Everything comes from `DesignTokens` (component tokens in
/// `DesignTokens+Actions.swift`): charcoal tiles, cobalt for selection and
/// drop targets, flame for errors, the display face for counts.
@MainActor
enum ActionStyle {
    // MARK: Colour

    /// A dynamic colour from a token pair, resolved per appearance.
    static func color(_ pair: (light: Int, dark: Int), alpha: CGFloat = 1) -> NSColor {
        let c = NSColor.halo(pair)
        return alpha < 1 ? c.withAlphaComponent(alpha) : c
    }

    /// One value in both appearances.
    static func fixed(_ hex: Int) -> NSColor { .halo((light: hex, dark: hex)) }

    /// Cobalt as a fill (behind white text: 5.0:1).
    static let iris = fixed(DesignTokens.Primitive.cobalt500)
    /// Cobalt as a glyph or text (AA on black and on white).
    static let accentText = color(DesignTokens.Semantic.accentPrimaryText)
    static let ink = color(DesignTokens.Semantic.textPrimary)
    static let mist = color(DesignTokens.Semantic.textSecondary)
    static let danger = color(DesignTokens.Palette.danger)
    /// Selected-row fill under white text.
    static let selection = fixed(DesignTokens.Primitive.cobalt500)
    static let onSelection = fixed(DesignTokens.Semantic.onAccentPrimary)

    /// The card fill: charcoal in dark, the light tile in light. Always solid:
    /// no materials, so Reduce Transparency changes nothing and renders match.
    static let solidCard = color(DesignTokens.Semantic.tile)

    /// The tile's edge: a hairline in light (so the tile reads on a white
    /// desktop), none on dark; full strength under Increased Contrast.
    static func strokeColor(highContrast: Bool) -> NSColor {
        if highContrast { return color(DesignTokens.Semantic.textPrimary, alpha: 0.7) }
        let hairline = color(DesignTokens.Semantic.hairline)
        return NSColor(name: nil) { appearance in appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .clear : hairline }
    }

    /// Behind a hovered cell: the raised step above the tile.
    static let hoverFill = color(DesignTokens.Semantic.raised)

    /// Small round control background (shelf ✕, ⋯, chevron).
    static let controlFill = color(DesignTokens.Semantic.raised)
    /// The ✕ badge on a thumbnail: raised, with a hairline so it reads on any picture.
    static let badgeFill = color(DesignTokens.Semantic.raised)
    static let badgeEdge = color(DesignTokens.Semantic.hairline)

    /// Thumbnail "prints": a white paper border (slightly off-white in dark so it doesn't glare).
    static let printPaper = color((light: DesignTokens.Primitive.paper0, dark: DesignTokens.Primitive.paper50))
    static let printEdge = color((light: DesignTokens.Primitive.paper100, dark: DesignTokens.Primitive.paper50))

    /// Resolves a dynamic colour for a CALayer under `appearance`.
    static func cg(_ color: NSColor, in appearance: NSAppearance) -> CGColor {
        var result = color.cgColor
        appearance.performAsCurrentDrawingAppearance { result = color.cgColor }
        return result
    }

    static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    // MARK: Accessibility display options

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static var reduceTransparency: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency }
    static var increaseContrast: Bool { NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast }

    // MARK: Type

    static func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// The display face (Inter Display Black) for counts.
    static func display(_ size: CGFloat) -> NSFont { HaloFonts.display(size) }

    /// "5 items": the count in the display face, the noun in the system face.
    static func countTitle(_ count: Int, noun: String, color: NSColor) -> NSAttributedString {
        let t = DesignTokens.Component.Shelf.self
        let digits = "\(count)"
        let result = NSMutableAttributedString(string: digits, attributes: [
            .font: display(t.countSize), .foregroundColor: color,
        ])
        // Display tracking between the digits only, so the word space stays a full space.
        if digits.count > 1 {
            result.addAttribute(.kern, value: t.countSize * DesignTokens.Typeface.displayTracking,
                                range: NSRange(location: 0, length: (digits as NSString).length - 1))
        }
        result.append(NSAttributedString(string: " \(noun)", attributes: [
            .font: font(t.titleSize, .bold), .foregroundColor: color,
        ]))
        return result
    }

    // MARK: Motion

    /// A spring described the way designers tune it (response, damping ratio),
    /// converted to Core Animation's mass/stiffness/damping.
    static func spring(_ keyPath: String, response: Double, damping: Double) -> CASpringAnimation {
        let a = CASpringAnimation(keyPath: keyPath)
        a.mass = 1
        a.stiffness = pow(2 * .pi / response, 2)
        a.damping = 4 * .pi * damping / response
        a.duration = a.settlingDuration
        return a
    }

    /// A named curve from `DesignTokens.Curve` (snap, glide, settle, exit).
    static func curve(_ c: (c1: CGPoint, c2: CGPoint, duration: Double)) -> CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: Float(c.c1.x), Float(c.c1.y), Float(c.c2.x), Float(c.c2.y))
    }

    /// Duration for a move: the curve's own, or the short crossfade under Reduce Motion.
    static func duration(_ c: (c1: CGPoint, c2: CGPoint, duration: Double)) -> Double {
        reduceMotion ? DesignTokens.Curve.reducedCrossfade : c.duration
    }

    /// Shadow margin around cards: their windows are this much larger so the
    /// card can cast its own (animatable) layer shadow.
    static let shadowMargin = DesignTokens.Component.ActionCard.shadowMargin
}

/// The shared card chrome: a solid charcoal tile (one radius, `Shape.tile`),
/// its edge, one floating shadow, and a 2 pt cobalt outline while something is
/// dragged over it. The card's content goes in `contentView`.
@MainActor
class ActionCardView: NSView {
    let contentView = NSView()
    /// The drop shadow lives on its own layer (AppKit owns the backing layer's
    /// shadow properties).
    private let shadowLayer = CALayer()
    private let solid = CALayer()
    private let stroke = CALayer()
    private let outline = CALayer()
    let cornerRadius: CGFloat

    /// Kept for offscreen renders; the card is always solid now.
    var forceSolid = false { didSet { refreshAppearance() } }
    /// Cobalt outline shown while something is dragged over the card.
    var isHighlighted = false { didSet { if isHighlighted != oldValue { animateHighlight() } } }

    init(cornerRadius: CGFloat = DesignTokens.Shape.tile) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false

        for l in [solid, stroke, outline, shadowLayer] {
            l.cornerRadius = cornerRadius
            l.cornerCurve = .continuous
        }
        stroke.borderWidth = DesignTokens.Shape.hairline
        outline.borderWidth = DesignTokens.Component.Shelf.dropOutlineWidth
        outline.opacity = 0

        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        addSubview(contentView)

        shadowLayer.shadowOpacity = 1
        shadowLayer.shadowRadius = DesignTokens.Component.Elevation.floatRadius
        shadowLayer.shadowOffset = CGSize(width: 0, height: -DesignTokens.Component.Elevation.floatOffsetY)
        layer?.insertSublayer(solid, at: 0)
        layer?.insertSublayer(shadowLayer, at: 0)
        layer?.addSublayer(stroke)
        layer?.addSublayer(outline)

        refreshAppearance()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { false }

    override func layout() {
        super.layout()
        contentView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solid.frame = bounds
        stroke.frame = bounds
        outline.frame = bounds
        shadowLayer.frame = bounds
        shadowLayer.shadowPath = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    @objc private func displayOptionsChanged() { refreshAppearance() }

    func refreshAppearance() {
        let appearance = effectiveAppearance
        let dark = ActionStyle.isDark(appearance)
        let highContrast = ActionStyle.increaseContrast
        let e = DesignTokens.Component.Elevation.self
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solid.backgroundColor = ActionStyle.cg(ActionStyle.solidCard, in: appearance)
        shadowLayer.backgroundColor = solid.backgroundColor
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOpacity = Float(dark ? e.floatOpacityDark : e.floatOpacityLight)
        stroke.borderColor = ActionStyle.cg(ActionStyle.strokeColor(highContrast: highContrast), in: appearance)
        outline.borderColor = ActionStyle.cg(ActionStyle.accentText, in: appearance)
        CATransaction.commit()
    }

    private func animateHighlight() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(ActionStyle.duration(DesignTokens.Curve.snap))
        CATransaction.setAnimationTimingFunction(ActionStyle.curve(DesignTokens.Curve.snap))
        outline.opacity = isHighlighted ? 1 : 0
        CATransaction.commit()
    }
}

/// A non-interactive label: clicks fall through to the card (so the card can
/// be dragged by it) and it never takes focus.
@MainActor
final class PassiveLabel: NSTextField {
    convenience init(size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = ActionStyle.ink, lines: Int = 1) {
        self.init(labelWithString: "")
        font = ActionStyle.font(size, weight)
        textColor = color
        isSelectable = false
        if lines > 1 {
            usesSingleLineMode = false
            cell?.wraps = true
            cell?.isScrollable = false
            lineBreakMode = .byWordWrapping
        } else {
            lineBreakMode = .byTruncatingMiddle
        }
        maximumNumberOfLines = lines
        cell?.truncatesLastVisibleLine = true
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A small round symbol button (✕, ⋯, chevron) that works on the first click
/// even though our app isn't active. `.badge` is the opaque style for a ✕
/// sitting on top of a thumbnail.
@MainActor
final class RoundSymbolButton: NSButton {
    enum Style { case plain, badge }

    private let fill = CALayer()
    private var style: Style = .plain
    private var tracking: NSTrackingArea?
    private var hovering = false { didSet { needsLayout = true } }

    convenience init(symbol: String, label: String,
                     diameter: CGFloat = DesignTokens.Component.Shelf.controlDiameter,
                     pointSize: CGFloat = DesignTokens.Component.Shelf.controlGlyph, style: Style = .plain) {
        self.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        self.style = style
        isBordered = false
        bezelStyle = .regularSquare
        imagePosition = .imageOnly
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?.withSymbolConfiguration(config)
        contentTintColor = ActionStyle.mist
        setAccessibilityLabel(label)
        toolTip = label
        wantsLayer = true
        layer?.masksToBounds = false
        fill.cornerRadius = diameter / 2
        fill.actions = ["backgroundColor": NSNull(), "bounds": NSNull(), "position": NSNull(), "borderColor": NSNull()]
        if style == .badge { fill.borderWidth = DesignTokens.Shape.hairline }
        layer?.insertSublayer(fill, at: 0)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func layout() {
        super.layout()
        let appearance = effectiveAppearance
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = bounds
        switch style {
        case .plain:
            fill.backgroundColor = ActionStyle.cg(ActionStyle.controlFill, in: appearance)
        case .badge:
            fill.backgroundColor = ActionStyle.cg(ActionStyle.badgeFill, in: appearance)
            fill.borderColor = ActionStyle.cg(ActionStyle.badgeEdge, in: appearance)
        }
        CATransaction.commit()
        contentTintColor = hovering ? ActionStyle.ink : ActionStyle.mist
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }
}
