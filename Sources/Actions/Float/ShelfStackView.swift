import AppKit
import HaloCore

/// What the shelf's views ask the controller to do.
enum ShelfCommand {
    case receive(urls: [URL], promises: [NSFilePromiseReceiver], at: CGPoint)
    case remove(Set<UUID>)
    case clear
    /// `nil` = every item.
    case reveal(Set<UUID>?)
    case copy(Set<UUID>?)
    case copyPaths(Set<UUID>?)
    case airDrop(Set<UUID>?)
    case open(Set<UUID>)
    /// A drag-out finished. `keepOnShelf` = Option was held at the drop.
    case dragEnded(Set<UUID>, operation: NSDragOperation, keepOnShelf: Bool)
    /// The user moved the shelf; save its position.
    case moved
    /// The pointer came over the shelf: a good moment to refresh stale items.
    case hovered
}

/// The collapsed shelf: the newest items as a small physical pile with a
/// count badge. Dragging the pile drags every item; a click expands the grid.
@MainActor
final class ShelfStackView: NSView, NSDraggingSource {
    static let printSide: CGFloat = 94

    var thumbnails: ShelfThumbnailProviding = QuickLookThumbnails.shared
    var onCommand: ((ShelfCommand) -> Void)?
    var onClick: (() -> Void)?
    /// Offscreen renders use a fixed scale (there's no window screen).
    var renderScale: CGFloat?

    private(set) var items: [ShelfItem] = []
    private var layers: [UUID: ShelfPrintLayer] = [:]
    private let badge = ShelfBadgeLayer()
    private var mouseDown: NSEvent?
    private var draggingIDs: Set<UUID> = []
    private var elements: [UUID: ShelfItemAccessibilityElement] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        badge.zPosition = 100
        badge.opacity = 0
        layer?.addSublayer(badge)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var scale: CGFloat { renderScale ?? window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2 }
    private var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        reloadThumbnails()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        reloadThumbnails()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (depth, item) in stackItems.enumerated() {
            if let l = layers[item.id] { place(l, item: item, depth: depth) }
        }
        placeBadge()
        CATransaction.commit()
    }

    // MARK: State

    /// Top of the pile first.
    private var stackItems: [ShelfItem] { Array(items.reversed().prefix(ShelfModel.visibleStackDepth)) }

    func apply(items newItems: [ShelfItem], change: ShelfChange?, animated: Bool) {
        let oldVisible = Set(stackItems.map(\.id))
        items = newItems
        let visible = stackItems
        let visibleIDs = Set(visible.map(\.id))
        let motion = animated && !ActionStyle.reduceMotion
        let fade = animated && ActionStyle.reduceMotion
        let arriving = Set((change?.added ?? []).map(\.id)).union((change?.raised ?? []).map(\.id))
        let removedIDs = Set((change?.removed ?? []).map(\.id))

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Leaving the visible pile.
        for (id, l) in layers where !visibleIDs.contains(id) {
            layers[id] = nil
            if motion && removedIDs.contains(id) {
                fallOut(l)
            } else if animated && oldVisible.contains(id) {
                fadeOut(l)
            } else {
                l.removeFromSuperlayer()
            }
        }

        // Arriving or staying. Create and place first, then fix the sublayer
        // order (bottom of the pile first, falling items and the badge above;
        // zPosition alone isn't honoured by every renderer), then animate.
        var fresh = Set<UUID>()
        for (depth, item) in visible.enumerated() {
            if layers[item.id] == nil { _ = makeLayer(for: item); fresh.insert(item.id) }
            if let l = layers[item.id] { place(l, item: item, depth: depth) }
        }
        for (index, item) in visible.reversed().enumerated() {
            if let l = layers[item.id], layer?.sublayers?.firstIndex(of: l) != index {
                layer?.insertSublayer(l, at: UInt32(index))
            }
        }
        if layer?.sublayers?.last !== badge { layer?.addSublayer(badge) }

        // Bottom first so the newest lands last, on top.
        var landingIndex = 0
        for item in visible.reversed() {
            guard let l = layers[item.id] else { continue }
            let isNew = fresh.contains(item.id)
            if arriving.contains(item.id) {
                if motion { land(l, item: item, delay: Double(landingIndex) * 0.06); landingIndex += 1 }
                else if fade { fadeIn(l) }
            } else if isNew && animated {
                fadeIn(l) // surfaced from under the pile after a removal
            } else if motion && !arriving.isEmpty && oldVisible.contains(item.id) {
                absorb(l, item: item)
            }
        }
        CATransaction.commit()

        updateBadge(animated: animated)
        updateAccessibility()
    }

    private func makeLayer(for item: ShelfItem) -> ShelfPrintLayer {
        let l = ShelfPrintLayer()
        let side = Self.printSide
        let thumb = thumbnails.thumbnail(for: item.url, side: side, scale: scale) { [weak self, weak l] better in
            guard let self, let l, self.layers[item.id] === l else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            l.configure(better, side: side, scale: self.scale, appearance: self.effectiveAppearance)
            if let depth = self.stackItems.firstIndex(where: { $0.id == item.id }) { self.place(l, item: item, depth: depth) }
            CATransaction.commit()
            if ActionStyle.reduceMotion == false {
                let a = CABasicAnimation(keyPath: "opacity")
                a.fromValue = 0.6
                a.toValue = 1
                a.duration = DesignTokens.Motion.crossfade
                l.add(a, forKey: "thumb")
            }
            self.placeBadge()
        }
        l.configure(thumb, side: side, scale: scale, appearance: effectiveAppearance)
        layers[item.id] = l
        layer?.addSublayer(l)
        return l
    }

    private func reloadThumbnails() {
        for item in stackItems {
            guard let l = layers[item.id] else { continue }
            let thumb = thumbnails.thumbnail(for: item.url, side: Self.printSide, scale: scale) { _ in }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            l.configure(thumb, side: Self.printSide, scale: scale, appearance: effectiveAppearance)
            CATransaction.commit()
        }
        updateBadge(animated: false)
        needsLayout = true
    }

    /// Resting pose: the item's own tilt/offset, the top one a little straighter.
    private func restingTransform(_ item: ShelfItem, depth: Int) -> CATransform3D {
        let pose = item.pose
        let angle = depth == 0 ? pose.angle * 0.45 : pose.angle * (1 + 0.25 * CGFloat(depth))
        return CATransform3DMakeRotation(angle, 0, 0, 1)
    }

    private func place(_ l: ShelfPrintLayer, item: ShelfItem, depth: Int) {
        let pose = item.pose
        let spread: CGFloat = depth == 0 ? 0.4 : 1
        l.position = CGPoint(x: center.x + pose.dx * spread, y: center.y + pose.dy * spread + CGFloat(depth) * 1.5)
        l.zPosition = CGFloat(10 - depth)
        l.transform = restingTransform(item, depth: depth)
        l.opacity = draggingIDs.contains(item.id) ? 0.35 : 1
    }

    // MARK: Physics

    /// Drops in from above with a tilt, then settles with a little bounce.
    private func land(_ l: ShelfPrintLayer, item: ShelfItem, delay: Double) {
        let rest = l.transform
        var start = CATransform3DMakeTranslation(0, 34, 0)
        start = CATransform3DRotate(start, item.pose.angle + 0.22, 0, 0, 1)
        start = CATransform3DScale(start, 1.14, 1.14, 1)
        let spring = ActionStyle.spring("transform", response: 0.42, damping: 0.62)
        spring.fromValue = NSValue(caTransform3D: start)
        spring.toValue = NSValue(caTransform3D: rest)
        spring.beginTime = CACurrentMediaTime() + delay
        spring.fillMode = .backwards
        l.add(spring, forKey: "land")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = l.opacity
        fade.duration = 0.12
        fade.beginTime = spring.beginTime
        fade.fillMode = .backwards
        l.add(fade, forKey: "landFade")
    }

    /// The pile gives a little as something lands on it.
    private func absorb(_ l: ShelfPrintLayer, item: ShelfItem) {
        let rest = l.transform
        let squashed = CATransform3DScale(rest, 0.95, 0.95, 1)
        let key = CAKeyframeAnimation(keyPath: "transform")
        key.values = [NSValue(caTransform3D: rest), NSValue(caTransform3D: squashed), NSValue(caTransform3D: rest)]
        key.keyTimes = [0, 0.35, 1]
        key.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeInEaseOut)]
        key.duration = 0.32
        key.beginTime = CACurrentMediaTime() + 0.08
        l.add(key, forKey: "absorb")
    }

    /// Tips over and drops out of the pile.
    private func fallOut(_ l: ShelfPrintLayer) {
        var end = CATransform3DTranslate(l.transform, 0, -46, 0)
        end = CATransform3DRotate(end, -0.45, 0, 0, 1)
        end = CATransform3DScale(end, 0.9, 0.9, 1)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak l] in l?.removeFromSuperlayer() }
        let move = CABasicAnimation(keyPath: "transform")
        move.fromValue = NSValue(caTransform3D: l.transform)
        move.toValue = NSValue(caTransform3D: end)
        move.timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 0, 0.9, 0.6)
        move.duration = 0.28
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = l.opacity
        fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 0.08
        fade.duration = 0.2
        fade.fillMode = .backwards
        l.transform = end
        l.opacity = 0
        l.add(move, forKey: "fall")
        l.add(fade, forKey: "fallFade")
        CATransaction.commit()
    }

    private func fadeOut(_ l: CALayer) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak l] in l?.removeFromSuperlayer() }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = l.opacity
        fade.toValue = 0
        fade.duration = DesignTokens.Motion.crossfade
        l.opacity = 0
        l.add(fade, forKey: "fadeOut")
        CATransaction.commit()
    }

    private func fadeIn(_ l: CALayer) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = l.opacity
        fade.duration = DesignTokens.Motion.crossfade + 0.06
        l.add(fade, forKey: "fadeIn")
    }

    // MARK: Badge

    private func updateBadge(animated: Bool) {
        let count = items.count
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if count >= 2 { badge.configure(count: count, scale: scale, appearance: effectiveAppearance) }
        placeBadge()
        CATransaction.commit()
        let show: Float = count >= 2 ? 1 : 0
        guard badge.opacity != show || animated else { return }
        if animated && !ActionStyle.reduceMotion && show == 1 {
            let pop = ActionStyle.spring("transform.scale", response: 0.3, damping: 0.55)
            pop.fromValue = badge.opacity == 0 ? 0.4 : 1.25
            pop.toValue = 1
            badge.add(pop, forKey: "pop")
        }
        if animated {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = badge.opacity
            fade.toValue = show
            fade.duration = DesignTokens.Motion.crossfade
            badge.add(fade, forKey: "fade")
        }
        badge.opacity = show
    }

    private func placeBadge() {
        guard let top = stackItems.first, let l = layers[top.id] else { return }
        let half = CGSize(width: l.bounds.width / 2, height: l.bounds.height / 2)
        badge.position = CGPoint(x: min(l.position.x + half.width - 4, bounds.maxX - badge.bounds.width / 2 - 2),
                                 y: min(l.position.y + half.height - 4, bounds.maxY - badge.bounds.height / 2 - 2))
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        mouseDown = event
        if event.clickCount == 2 {
            onCommand?(.open(Set(items.map(\.id))))
            mouseDown = nil
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDown else { return }
        let a = down.locationInWindow, b = event.locationInWindow
        guard hypot(b.x - a.x, b.y - a.y) > 3 else { return }
        mouseDown = nil
        beginDrag(with: down)
    }

    override func mouseUp(with event: NSEvent) {
        if mouseDown != nil, event.clickCount == 1 { onClick?() }
        mouseDown = nil
    }

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event) // the card shows its menu
    }

    // MARK: Drag out

    private func beginDrag(with event: NSEvent) {
        guard !items.isEmpty else { return }
        let ordered = Array(items.reversed()) // top of the pile first
        let topFrame = stackItems.first.flatMap { layers[$0.id]?.frame } ?? bounds
        let dragItems: [NSDraggingItem] = ordered.map { item in
            let pb = NSPasteboardItem()
            pb.setString(item.url.absoluteString, forType: .fileURL)
            let d = NSDraggingItem(pasteboardWriter: pb)
            let l = layers[item.id]
            let image = l?.image ?? NSWorkspace.shared.icon(forFile: item.url.path)
            d.setDraggingFrame(l?.frame ?? topFrame, contents: image)
            return d
        }
        draggingIDs = Set(items.map(\.id))
        let session = beginDraggingSession(with: dragItems, event: event, source: self)
        session.draggingFormation = .pile
        session.animatesToStartingPositionsOnCancelOrFail = true
        dimDragged()
    }

    private func dimDragged() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.12)
        for item in stackItems { layers[item.id]?.opacity = draggingIDs.contains(item.id) ? 0.35 : 1 }
        CATransaction.commit()
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Outside: behave like a Finder drag (same disk moves, other disk or ⌥ copies).
        // Inside the app (e.g. onto the wheel): copy only. Never .delete.
        context == .outsideApplication ? [.copy, .move, .link, .generic] : [.copy]
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        MainActor.assumeIsolated {
            let keep = NSEvent.modifierFlags.contains(.option)
            let ids = draggingIDs
            draggingIDs = []
            dimDragged()
            onCommand?(.dragEnded(ids, operation: operation, keepOnShelf: keep))
        }
    }

    // MARK: Accessibility

    private func updateAccessibility() {
        let count = items.count
        setAccessibilityLabel(count == 1
            ? String(localized: "Pile with 1 item")
            : String(localized: "Pile with \(count) items"))
        setAccessibilityHelp(String(localized: "Drag to move every item out of the shelf. Press to show them all."))
        var fresh: [UUID: ShelfItemAccessibilityElement] = [:]
        let topFrame = stackItems.first.flatMap { layers[$0.id]?.frame } ?? bounds
        for item in items.reversed() {
            let e = elements[item.id] ?? ShelfItemAccessibilityElement(itemID: item.id)
            e.configure(name: item.name, parent: self, frame: layers[item.id]?.frame ?? topFrame, onCommand: { [weak self] in self?.onCommand?($0) })
            fresh[item.id] = e
        }
        elements = fresh
        setAccessibilityChildren(items.reversed().compactMap { fresh[$0.id] })
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}

/// VoiceOver element for one shelf item, with Open as its press action and
/// Remove / Reveal / Copy as custom actions. NSAccessibilityElement isn't
/// main-actor isolated (AppKit still calls it on the main thread), so the
/// press handler is held as a Sendable main-actor closure.
final class ShelfItemAccessibilityElement: NSAccessibilityElement {
    let itemID: UUID
    private var onPress: (@MainActor @Sendable () -> Void)?

    init(itemID: UUID) {
        self.itemID = itemID
        super.init()
        setAccessibilityRole(.button)
        setAccessibilityRoleDescription(String(localized: "file"))
    }

    @MainActor
    func configure(name: String, parent: NSView, frame: CGRect,
                   onCommand: @escaping @MainActor @Sendable (ShelfCommand) -> Void) {
        let id = itemID
        onPress = { onCommand(.open([id])) }
        setAccessibilityLabel(name)
        setAccessibilityParent(parent)
        setAccessibilityFrameInParentSpace(frame)
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: String(localized: "Remove from Shelf")) { onCommand(.remove([id])); return true },
            NSAccessibilityCustomAction(name: String(localized: "Reveal in Finder")) { onCommand(.reveal([id])); return true },
            NSAccessibilityCustomAction(name: String(localized: "Copy")) { onCommand(.copy([id])); return true },
        ])
    }

    override func accessibilityPerformPress() -> Bool {
        guard let handler = onPress else { return false }
        MainActor.assumeIsolated { handler() }
        return true
    }
}
