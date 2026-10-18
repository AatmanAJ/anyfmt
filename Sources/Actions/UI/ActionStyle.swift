import AppKit
import HaloCore

/// Colours, metrics and accessibility state shared by the shelf and the Move
/// chooser. Everything derives from `DesignTokens`.
@MainActor
enum ActionStyle {
    // MARK: Colour

    static func color(_ pair: (light: Int, dark: Int), alpha: CGFloat = 1) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return rgb(isDark ? pair.dark : pair.light, alpha: alpha)
        }
    }

    nonisolated static func rgb(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha)
    }

    static let iris = color(DesignTokens.Palette.iris)
    static let ink = color(DesignTokens.Palette.ink)
    static let mist = color(DesignTokens.Palette.mist)
    static let danger = color(DesignTokens.Palette.danger)
    /// Selected-row fill under white text. The light iris in both appearances:
    /// the dark-mode iris is too light for white text (≈3.3:1; this is ≈4.9:1).
    static let selection = rgb(DesignTokens.Palette.iris.light)

    /// Solid card fill used when transparency is reduced (and in offscreen renders,
    /// where window-server materials can't be captured).
    static let solidCard = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? rgb(0x26252C) : rgb(0xF7F6FA)
    }

    /// Hairline inner stroke that defines the card's edge on any wallpaper.
    static func strokeColor(highContrast: Bool) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            if highContrast { return isDark ? NSColor(white: 1, alpha: 0.55) : NSColor(white: 0, alpha: 0.5) }
            return isDark ? NSColor(white: 1, alpha: 0.14) : NSColor(white: 0, alpha: 0.09)
        }
    }

    /// Tint behind a hovered row or cell.
    static let hoverFill = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return rgb(isDark ? DesignTokens.Palette.iris.dark : DesignTokens.Palette.iris.light, alpha: isDark ? 0.22 : 0.12)
    }

    /// Small round control background (shelf ✕ and ⋯).
    static let controlFill = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(white: 1, alpha: 0.16) : NSColor(white: 0, alpha: 0.07)
    }

    /// Resolves a dynamic colour for a CALayer under `appearance`.
    static func cg(_ color: NSColor, in appearance: NSAppearance) -> CGColor {
        var result = color.cgColor
        appearance.performAsCurrentDrawingAppearance { result = color.cgColor }
        return result
    }

    // MARK: Accessibility display options

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    static var reduceTransparency: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency }
    static var increaseContrast: Bool { NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast }

    // MARK: Type

    static func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
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

    /// Shadow margin around cards: their windows are this much larger so the
    /// card can cast its own (animatable) layer shadow.
    static let shadowMargin: CGFloat = 26
}

/// Rounded "card" chrome: material (or solid fill), hairline stroke and a
/// layer shadow. The card's content goes in `contentView`.
@MainActor
class ActionCardView: NSView {
    let contentView = NSView()
    /// The card's drop shadow lives on its own layer (AppKit owns the backing
    /// layer's shadow properties) and is masked to the outside of the card so
    /// it never darkens a translucent material from underneath.
    private let shadowLayer = CALayer()
    private let shadowMask = CAShapeLayer()
    private let effect = NSVisualEffectView()
    private let solid = CALayer()
    private let stroke = CALayer()
    private let glow = CALayer()
    let cornerRadius: CGFloat

    /// Forces the solid fill (offscreen renders can't capture materials).
    var forceSolid = false { didSet { refreshAppearance() } }
    /// Iris ring shown while something is dragged over the card.
    var isHighlighted = false { didSet { if isHighlighted != oldValue { animateHighlight() } } }

    init(cornerRadius: CGFloat = DesignTokens.Radius.window + 2, material: NSVisualEffectView.Material = .popover) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false

        effect.material = material
        effect.blendingMode = .behindWindow
        // Our app is almost never active while the card is up; keep the material vivid.
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.autoresizingMask = [.width, .height]
        addSubview(effect)

        solid.cornerRadius = cornerRadius
        solid.cornerCurve = .continuous
        stroke.cornerRadius = cornerRadius
        stroke.cornerCurve = .continuous
        stroke.borderWidth = 1
        glow.cornerRadius = cornerRadius
        glow.cornerCurve = .continuous
        glow.borderWidth = 2
        glow.opacity = 0
        glow.shadowOpacity = 0
        glow.shadowRadius = 10
        glow.shadowOffset = .zero

        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        addSubview(contentView)

        shadowLayer.shadowOpacity = 1
        shadowLayer.cornerRadius = cornerRadius
        shadowLayer.cornerCurve = .continuous
        shadowLayer.shadowRadius = 16
        shadowLayer.shadowOffset = CGSize(width: 0, height: -7)
        shadowMask.fillRule = .evenOdd
        layer?.insertSublayer(solid, at: 0)
        layer?.insertSublayer(shadowLayer, at: 0)
        layer?.addSublayer(stroke)
        layer?.addSublayer(glow)

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
        effect.frame = bounds
        contentView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solid.frame = bounds
        stroke.frame = bounds
        glow.frame = bounds.insetBy(dx: -1, dy: -1)
        glow.cornerRadius = cornerRadius + 1
        let shape = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        shadowLayer.frame = bounds
        shadowLayer.shadowPath = shape
        let outside = CGMutablePath()
        outside.addRect(bounds.insetBy(dx: -80, dy: -80))
        outside.addPath(shape)
        shadowMask.frame = bounds
        shadowMask.path = outside
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    @objc private func displayOptionsChanged() { refreshAppearance() }

    func refreshAppearance() {
        let appearance = effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let useSolid = forceSolid || ActionStyle.reduceTransparency
        let highContrast = ActionStyle.increaseContrast
        effect.isHidden = useSolid
        // Over an opaque fill the shadow can sit under the whole card; only a
        // translucent material needs it cut to the outside.
        shadowLayer.mask = useSolid ? nil : shadowMask
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        solid.backgroundColor = ActionStyle.cg(ActionStyle.solidCard, in: appearance)
        // Some renderers only cast a shadow from a filled layer; over material
        // the mask removes this fill, leaving only the outside shadow.
        shadowLayer.backgroundColor = solid.backgroundColor
        solid.opacity = useSolid ? 1 : 0
        stroke.borderColor = ActionStyle.cg(ActionStyle.strokeColor(highContrast: highContrast), in: appearance)
        stroke.borderWidth = highContrast ? 1.5 : 1
        glow.borderColor = ActionStyle.cg(ActionStyle.iris, in: appearance)
        glow.shadowColor = ActionStyle.cg(ActionStyle.iris, in: appearance)
        shadowLayer.shadowColor = NSColor(white: 0, alpha: isDark ? 0.55 : 0.2).cgColor
        CATransaction.commit()
    }

    private func animateHighlight() {
        let on = isHighlighted
        CATransaction.begin()
        CATransaction.setAnimationDuration(ActionStyle.reduceMotion ? 0.08 : 0.16)
        glow.opacity = on ? 1 : 0
        glow.shadowOpacity = on ? 0.6 : 0
        CATransaction.commit()
    }
}

/// A non-interactive label: clicks fall through to the card (so the card can
/// be dragged by it) and it never takes focus.
@MainActor
final class PassiveLabel: NSTextField {
    convenience init(size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor, lines: Int = 1) {
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
/// even though our app isn't active. `.badge` is the opaque, shadowed style
/// for a ✕ sitting on top of a thumbnail.
@MainActor
final class RoundSymbolButton: NSButton {
    enum Style { case plain, badge }

    private let fill = CALayer()
    private var style: Style = .plain

    convenience init(symbol: String, label: String, diameter: CGFloat = 20, pointSize: CGFloat = 9.5, style: Style = .plain) {
        self.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        self.style = style
        isBordered = false
        bezelStyle = .regularSquare
        imagePosition = .imageOnly
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?.withSymbolConfiguration(config)
        contentTintColor = .secondaryLabelColor
        setAccessibilityLabel(label)
        toolTip = label
        wantsLayer = true
        layer?.masksToBounds = false
        fill.cornerRadius = diameter / 2
        fill.actions = ["backgroundColor": NSNull(), "bounds": NSNull(), "position": NSNull(), "borderColor": NSNull()]
        if style == .badge {
            fill.shadowColor = NSColor.black.cgColor
            fill.shadowOpacity = 0.25
            fill.shadowRadius = 1.5
            fill.shadowOffset = CGSize(width: 0, height: -0.5)
            fill.borderWidth = 0.5
        }
        layer?.insertSublayer(fill, at: 0)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func layout() {
        super.layout()
        let appearance = effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = bounds
        fill.shadowPath = CGPath(ellipseIn: bounds, transform: nil)
        switch style {
        case .plain:
            fill.backgroundColor = ActionStyle.cg(ActionStyle.controlFill, in: appearance)
        case .badge:
            fill.backgroundColor = (isDark ? ActionStyle.rgb(0x4A4853) : NSColor.white).cgColor
            fill.borderColor = NSColor(white: isDark ? 1 : 0, alpha: 0.12).cgColor
        }
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }
}
