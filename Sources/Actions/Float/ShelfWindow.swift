import AppKit
import HaloCore

/// Floating, non-activating panel that hosts the shelf card. Joins every
/// Space and full-screen apps, never steals focus from the app you're in.
@MainActor
final class ShelfPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        // The card casts its own layer shadow so it can scale with the pop-in.
        hasShadow = false
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        setAccessibilitySubrole(.floatingWindow)
        setAccessibilityLabel(String(localized: "Float shelf"))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// What `FloatShelf` needs from a window, so its rules can be tested without one.
@MainActor
protocol ShelfPresenting: AnyObject {
    var onCommand: ((ShelfCommand) -> Void)? { get set }
    /// Card frame on screen while shown (saved as the shelf position).
    var cardFrame: CGRect? { get }
    func show(items: [ShelfItem], near point: CGPoint?, savedOrigin: CGPoint?)
    func update(items: [ShelfItem], change: ShelfChange)
    func hide()
}

/// The real presenter: a `ShelfPanel` with a `ShelfCardView`.
@MainActor
final class ShelfWindowPresenter: ShelfPresenting {
    var onCommand: ((ShelfCommand) -> Void)? {
        didSet { card.onCommand = onCommand }
    }

    private lazy var panel: ShelfPanel = {
        let p = ShelfPanel()
        let root = NSView()
        root.wantsLayer = true
        p.contentView = root
        root.addSubview(card)
        return p
    }()
    let card = ShelfCardView()
    private var hiding = false
    private let margin = ActionStyle.shadowMargin

    init() {
        card.onModeChange = { [weak self] mode in self?.resize(for: mode) }
        card.onWindowDragEnded = { [weak self] in self?.snapToEdges() }
    }

    var cardFrame: CGRect? {
        guard panel.isVisible else { return nil }
        return panel.frame.insetBy(dx: margin, dy: margin)
    }

    func show(items: [ShelfItem], near point: CGPoint?, savedOrigin: CGPoint?) {
        hiding = false
        card.layer?.removeAllAnimations()
        card.apply(items: items, change: nil, animated: false)
        let size = ShelfCardView.size(mode: card.mode, count: items.count)
        let frame = Self.initialCardFrame(size: size, near: point, savedOrigin: savedOrigin)
        setCardFrame(frame, animated: false)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        popIn(from: point.map { CGPoint(x: $0.x - frame.minX, y: $0.y - frame.minY) })
    }

    func update(items: [ShelfItem], change: ShelfChange) {
        card.apply(items: items, change: change, animated: panel.isVisible)
    }

    func hide() {
        guard panel.isVisible, !hiding else { return }
        hiding = true
        let finish: @MainActor () -> Void = { [weak self] in
            guard let self, self.hiding else { return }
            self.panel.orderOut(nil)
            self.card.layer?.removeAllAnimations()
            self.hiding = false
        }
        guard let layer = card.layer else { finish(); return }
        CATransaction.begin()
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { finish() } }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.16
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        layer.add(fade, forKey: "hideFade")
        if !ActionStyle.reduceMotion {
            let shrink = CABasicAnimation(keyPath: "transform")
            shrink.toValue = NSValue(caTransform3D: Self.scale(0.86, about: CGPoint(x: card.bounds.midX, y: card.bounds.midY)))
            shrink.duration = 0.18
            shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
            shrink.fillMode = .forwards
            shrink.isRemovedOnCompletion = false
            layer.add(shrink, forKey: "hideShrink")
        }
        CATransaction.commit()
    }

    // MARK: Geometry

    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    /// Centred on the drop point (the shelf pops out of the wheel), else where
    /// the user left it, else the right side of the main screen. Always fully on screen.
    static func initialCardFrame(size: NSSize, near point: CGPoint?, savedOrigin: CGPoint?) -> CGRect {
        if let point {
            let f = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
            return clamp(f, to: screen(containing: point)?.visibleFrame)
        }
        if let o = savedOrigin, let s = NSScreen.screens.first(where: { $0.visibleFrame.insetBy(dx: -40, dy: -40).contains(o) }) {
            return clamp(CGRect(origin: o, size: size), to: s.visibleFrame)
        }
        let vf = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        return clamp(CGRect(x: vf.maxX - size.width - 24, y: vf.midY - size.height / 2 + 80, width: size.width, height: size.height), to: vf)
    }

    static func clamp(_ f: CGRect, to visible: CGRect?, inset: CGFloat = DesignTokens.Wheel.screenEdgeInset) -> CGRect {
        guard let vf = visible?.insetBy(dx: inset, dy: inset) else { return f }
        var r = f
        r.origin.x = min(max(r.minX, vf.minX), vf.maxX - r.width)
        r.origin.y = min(max(r.minY, vf.minY), vf.maxY - r.height)
        return r
    }

    private func setCardFrame(_ cardFrame: CGRect, animated: Bool) {
        let windowFrame = cardFrame.insetBy(dx: -margin, dy: -margin)
        card.frame = NSRect(x: margin, y: margin, width: cardFrame.width, height: cardFrame.height)
        card.autoresizingMask = [.width, .height]
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = ActionStyle.reduceMotion ? 0 : 0.22
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
                panel.animator().setFrame(windowFrame, display: true)
            }
        } else {
            panel.setFrame(windowFrame, display: true)
        }
    }

    /// Expanding keeps the top edge and centre where they are (then stays on screen).
    private func resize(for mode: ShelfCardView.Mode) {
        guard panel.isVisible || hiding == false else { return }
        let current = panel.frame.insetBy(dx: margin, dy: margin)
        let size = ShelfCardView.size(mode: mode, count: card.items.count)
        guard size != current.size else { return }
        var f = CGRect(x: current.midX - size.width / 2, y: current.maxY - size.height, width: size.width, height: size.height)
        f = Self.clamp(f, to: Self.screen(containing: CGPoint(x: current.midX, y: current.midY))?.visibleFrame)
        setCardFrame(f, animated: panel.isVisible)
    }

    /// After a drag: within 24 pt of a screen edge, settle against it.
    private func snapToEdges() {
        let current = panel.frame.insetBy(dx: margin, dy: margin)
        guard let vf = Self.screen(containing: CGPoint(x: current.midX, y: current.midY))?.visibleFrame else { return }
        let inset: CGFloat = 10, reach: CGFloat = 24
        var f = current
        if f.minX - vf.minX < reach { f.origin.x = vf.minX + inset }
        if vf.maxX - f.maxX < reach { f.origin.x = vf.maxX - inset - f.width }
        if f.minY - vf.minY < reach { f.origin.y = vf.minY + inset }
        if vf.maxY - f.maxY < reach { f.origin.y = vf.maxY - inset - f.height }
        f = Self.clamp(f, to: vf)
        if f != current { setCardFrame(f, animated: true) }
        onCommand?(.moved)
    }

    // MARK: Motion

    static func scale(_ s: CGFloat, about p: CGPoint) -> CATransform3D {
        var t = CATransform3DMakeTranslation(p.x, p.y, 0)
        t = CATransform3DScale(t, s, s, 1)
        return CATransform3DTranslate(t, -p.x, -p.y, 0)
    }

    /// Springs out of the drop point (or its own centre) like it was thrown there.
    private func popIn(from local: CGPoint?) {
        guard let layer = card.layer else { return }
        layer.removeAllAnimations()
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = ActionStyle.reduceMotion ? 0.15 : 0.1
        layer.add(fade, forKey: "popFade")
        guard !ActionStyle.reduceMotion else { return }
        let b = card.bounds
        let anchor = local.map { CGPoint(x: min(max($0.x, 0), b.width), y: min(max($0.y, 0), b.height)) }
            ?? CGPoint(x: b.midX, y: b.midY)
        let spring = ActionStyle.spring("transform", response: 0.42, damping: 0.7)
        spring.fromValue = NSValue(caTransform3D: Self.scale(0.35, about: anchor))
        spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        layer.add(spring, forKey: "pop")
    }
}
