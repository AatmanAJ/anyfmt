import AppKit
import QuartzCore

/// Callbacks from a `RadialMenuView`. Everything is optional.
@MainActor
public protocol RadialMenuViewDelegate: AnyObject {
    /// Hover/selection moved (nil = nothing selected).
    func radialMenu(_ menu: RadialMenuView, didHighlight item: RadialItem?)
    /// Enter, click or VoiceOver press on an enabled item.
    func radialMenu(_ menu: RadialMenuView, didActivate item: RadialItem)
    /// Extra veto for drops (default: enabled items accept).
    func radialMenu(_ menu: RadialMenuView, canAcceptDropOn item: RadialItem, info: NSDraggingInfo) -> Bool
    /// A drag was released over `item`. Return true if you took it.
    func radialMenu(_ menu: RadialMenuView, didDrop info: NSDraggingInfo, on item: RadialItem) -> Bool
    /// A drag was released on the empty drop-zone ring.
    func radialMenu(_ menu: RadialMenuView, didDropOnEmptyRing info: NSDraggingInfo) -> Bool
    /// Escape, a click in the hub, or a drop in the dead zone.
    func radialMenuDidCancel(_ menu: RadialMenuView)
    /// Tab (forward) / Shift-Tab: the host may switch to another item set.
    func radialMenu(_ menu: RadialMenuView, didRequestNextMenu forward: Bool)
    /// Whether `item` has options (enables right-click and hold-to-open).
    func radialMenu(_ menu: RadialMenuView, hasOptionsFor item: RadialItem) -> Bool
    /// Right-click or hover-dwell on an item with options. `anchor` is in view coordinates.
    func radialMenu(_ menu: RadialMenuView, didRequestOptionsFor item: RadialItem, anchor: NSRect)
    /// The drag left the wheel.
    func radialMenuDragDidExit(_ menu: RadialMenuView)
}

public extension RadialMenuViewDelegate {
    func radialMenu(_ menu: RadialMenuView, didHighlight item: RadialItem?) {}
    func radialMenu(_ menu: RadialMenuView, didActivate item: RadialItem) {}
    func radialMenu(_ menu: RadialMenuView, canAcceptDropOn item: RadialItem, info: NSDraggingInfo) -> Bool { true }
    func radialMenu(_ menu: RadialMenuView, didDrop info: NSDraggingInfo, on item: RadialItem) -> Bool { false }
    func radialMenu(_ menu: RadialMenuView, didDropOnEmptyRing info: NSDraggingInfo) -> Bool { false }
    func radialMenuDidCancel(_ menu: RadialMenuView) {}
    func radialMenu(_ menu: RadialMenuView, didRequestNextMenu forward: Bool) {}
    func radialMenu(_ menu: RadialMenuView, hasOptionsFor item: RadialItem) -> Bool { false }
    func radialMenu(_ menu: RadialMenuView, didRequestOptionsFor item: RadialItem, anchor: NSRect) {}
    func radialMenuDragDidExit(_ menu: RadialMenuView) {}
}

/// Text the menu draws itself. Hosts pass localised versions.
public struct RadialMenuStrings: Equatable, Sendable {
    public var morePages: String = "More"
    public var morePagesHint: String = "Shows the next page of options"
    public var pageFormat: String = "Page %d of %d"
    public var menuHint: String = "Arrow keys move, Return chooses, Escape cancels, Tab switches wheels"
    public init() {}
}

/// A radial menu drawn entirely with Core Animation. All hover, open, close and
/// morph motion runs on layers (springs and basic animations), so nothing runs
/// in Swift per frame. Usable inside any window; `RadialMenuPanel` hosts it as
/// a mid-drag overlay.
@MainActor
public final class RadialMenuView: NSView {
    public enum MaterialMode: Sendable {
        /// Real behind-window vibrancy (`NSVisualEffectView`), masked to the segment shapes.
        case live
        /// A painted stand-in. Used offscreen, where vibrancy can't render.
        case painted
    }

    public weak var delegate: RadialMenuViewDelegate?
    public let configuration: RadialMenuConfiguration
    public let materialMode: MaterialMode
    public var style: RadialMenuStyle { didSet { refreshAppearance() } }
    public var strings = RadialMenuStrings() { didSet { rebuild(animation: nil) } }
    /// Spoken as the wheel's name, e.g. "Convert".
    public var menuTitle: String = "" { didSet { setAccessibilityLabel(menuTitle) } }
    /// Allows first responder (arrows, Return, Escape, Tab, 1–9).
    public var keyboardEnabled = false
    /// Hub content (thumbnail, stack count, idle pill text).
    public var hub = RadialHubContent() { didSet { if hub != oldValue { applyHub(animated: window != nil) } } }
    /// Shown when there are no items: an empty ring that accepts drops.
    public var dropZone: RadialDropZone? { didSet { rebuild(animation: nil) } }

    public private(set) var items: [RadialItem] = []
    public private(set) var radialLayout: RadialLayout
    /// Item index currently highlighted (hover or keyboard).
    public var highlightedItemIndex: Int? { highlightedSlot.flatMap { radialLayout.slots[$0].itemIndex } }
    public var highlightedItem: RadialItem? { highlightedItemIndex.map { items[$0] } }
    /// The resolved appearance being drawn.
    public private(set) var resolvedAppearance: RadialAppearance

    /// Centre of the wheel in view coordinates.
    public var wheelCenter: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    /// Radius of what's drawn now (for edge push-in).
    public var wheelRadius: CGFloat {
        (items.isEmpty ? configuration.innerRing.outer : radialLayout.outerRadius) + configuration.hoverLift
    }

    // Layer trees
    private let shadowView = LayerHostView()
    private let overlayView = LayerHostView()
    private var materialView: NSVisualEffectView?
    private let maskRoot = CALayer()
    private let hitLayer = CAShapeLayer()
    private var nodes: [SegmentNode] = []
    private var hubNode: HubNode
    private var dropZoneNode: DropZoneNode?
    private(set) var palette: RadialPalette

    // Interaction state
    private(set) var highlightedSlot: Int?
    private var lastPointer: CGPoint?
    private var dwell: Task<Void, Never>?
    private var dropZoneTargeted = false
    var scrollAccumulatorValue: CGFloat = 0
    private var segmentElements: [RadialSegmentElement] = []
    private var renderScale: CGFloat = 2
    private var isDismissing = false

    public init(configuration: RadialMenuConfiguration = RadialMenuConfiguration(),
                style: RadialMenuStyle = RadialMenuStyle(), materialMode: MaterialMode = .live) {
        self.configuration = configuration
        self.style = style
        self.materialMode = materialMode
        let appearance = style.appearanceOverride ?? RadialAppearance.system()
        resolvedAppearance = appearance
        palette = RadialPalette(style: style, appearance: appearance, hitAlpha: configuration.minimumHitAlpha)
        radialLayout = RadialLayout(itemCount: 0, configuration: configuration)
        let side = configuration.canvasSide
        let canvas = CGRect(x: 0, y: 0, width: side, height: side)
        hubNode = HubNode(canvas: canvas, scale: 2)
        super.init(frame: canvas)
        wantsLayer = true
        layer?.backgroundColor = nil
        for v in [shadowView, overlayView] {
            v.frame = bounds
            v.autoresizingMask = [.width, .height]
        }
        addSubview(shadowView)
        if materialMode == .live {
            let vfx = NSVisualEffectView(frame: bounds)
            vfx.autoresizingMask = [.width, .height]
            vfx.blendingMode = .behindWindow
            // Stay vibrant while our app is inactive (always, during a Finder drag).
            vfx.state = .active
            vfx.material = style.material.visualEffectMaterial
            vfx.wantsLayer = true
            maskRoot.frame = bounds
            vfx.layer?.mask = maskRoot
            addSubview(vfx)
            materialView = vfx
        }
        addSubview(overlayView)
        hitLayer.actions = SegmentNode.noActions
        shadowView.root.addSublayer(hitLayer)
        hubNode.install(shadowRoot: shadowView.root, maskRoot: liveMaskRoot, overlayRoot: overlayView.root)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        refreshAppearance()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityDisplayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var liveMaskRoot: CALayer? { materialMode == .live ? maskRoot : nil }

    public override var isFlipped: Bool { false }

    // MARK: Items

    /// Replaces the items. With `animated`, existing segments morph to their new
    /// angles while labels crossfade (wheel switches never flash).
    public func setItems(_ newItems: [RadialItem], animated: Bool) {
        let previousID = highlightedItem?.id
        items = newItems
        let reduce = resolvedAppearance.reduceMotion
        if animated && !reduce {
            rebuild(animation: LayerAnimation.basic(configuration.morphDuration, LayerAnimation.easeInOut))
        } else if animated {
            crossfadeRebuild()
        } else {
            rebuild(animation: nil)
        }
        if let previousID, lastPointer == nil, let index = items.firstIndex(where: { $0.id == previousID }),
           let slot = radialLayout.slotIndex(forItem: index) {
            setHighlightedSlot(slot, animated: false)
        } else if let lastPointer {
            updateHover(at: lastPointer, animated: animated)
        }
    }

    /// Selects an item programmatically (keyboard mode, gallery, tests). Flips pages as needed.
    public func highlightItem(at index: Int?, animated: Bool = true) {
        guard let index, items.indices.contains(index) else {
            setHighlightedSlot(nil, animated: animated)
            return
        }
        let page = radialLayout.page(containing: index)
        if page != radialLayout.page { showPage(page, animated: animated) }
        setHighlightedSlot(radialLayout.slotIndex(forItem: index), animated: animated)
    }

    /// Flips the paginated outer ring.
    public func showPage(_ page: Int, animated: Bool) {
        guard radialLayout.isPaginated else { return }
        requestedPage = page
        rebuild(animation: animated && !resolvedAppearance.reduceMotion
                ? LayerAnimation.basic(configuration.morphDuration, LayerAnimation.easeInOut) : nil)
        if animated {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            announce(String(format: strings.pageFormat, radialLayout.page + 1, radialLayout.pageCount))
        }
    }

    private var requestedPage = 0

    /// Item index under a point in view coordinates.
    public func itemIndex(at point: NSPoint) -> Int? {
        if case .slot(let s) = radialLayout.hitTest(relative(point)) { return radialLayout.slots[s].itemIndex }
        return nil
    }

    /// Bounds of an item's wedge in view coordinates (anchor for popovers).
    public func frameForItem(at index: Int) -> NSRect? {
        guard let slot = radialLayout.slotIndex(forItem: index) else { return nil }
        return frame(forSlot: slot)
    }

    func frame(forSlot slot: Int) -> NSRect {
        radialLayout.bounds(of: radialLayout.slots[slot]).offsetBy(dx: wheelCenter.x, dy: wheelCenter.y)
    }

    // MARK: Build

    private func pagerItem() -> RadialItem {
        let dots = (0..<radialLayout.pageCount).map { $0 == radialLayout.page ? "●" : "○" }.joined(separator: " ")
        return RadialItem(id: "radialmenu.pager", title: strings.morePages, symbolName: "arrow.clockwise",
                          subtitle: dots, prominence: .glyph,
                          accessibilityLabel: "\(strings.morePages), \(String(format: strings.pageFormat, radialLayout.page + 1, radialLayout.pageCount))",
                          accessibilityHint: strings.morePagesHint)
    }

    private func item(for slot: RadialSlot) -> RadialItem {
        switch slot.content {
        case .item(let i): items[i]
        case .pager: pagerItem()
        }
    }

    private func images(for item: RadialItem, slot: RadialSlot) -> SegmentNode.Images {
        let size = radialLayout.contentSize(of: slot)
        let enabled = item.isEnabled
        let normal = ContentRenderer.segmentImage(item: item, ring: slot.ring, size: size, scale: renderScale,
                                                  state: enabled ? .normal : .disabled, palette: palette,
                                                  style: style, config: configuration)
        let highlight = enabled
            ? ContentRenderer.segmentImage(item: item, ring: slot.ring, size: size, scale: renderScale, state: .highlighted,
                                           palette: palette, style: style, config: configuration)
            : normal
        return SegmentNode.Images(normal: normal, highlight: highlight, size: size)
    }

    private var canvas: CGRect { CGRect(origin: .zero, size: bounds.size) }

    /// Lays out every segment for the current items and page. With an animation,
    /// reused segments morph, extra ones collapse into slivers and new ones grow.
    private func rebuild(animation: CABasicAnimation?) {
        let previousHighlight = highlightedSlot.flatMap { nodes.indices.contains($0) ? nodes[$0].itemID : nil }
        if let h = highlightedSlot, nodes.indices.contains(h) {
            nodes[h].setHighlighted(false, palette: palette, config: configuration, center: wheelCenter,
                                    reduceMotion: true, animated: false)
        }
        highlightedSlot = nil
        cancelDwell()
        radialLayout = RadialLayout(itemCount: items.count, configuration: configuration, page: requestedPage)
        requestedPage = radialLayout.page
        let center = wheelCenter
        var kept: [SegmentNode] = []
        for (i, slot) in radialLayout.slots.enumerated() {
            let item = item(for: slot)
            let imgs = images(for: item, slot: slot)
            if i < nodes.count {
                let node = nodes[i]
                node.update(slot: slot, itemID: item.id, enabled: item.isEnabled, images: imgs, layout: radialLayout,
                            center: center, palette: palette, animation: animation)
                kept.append(node)
            } else {
                let node = SegmentNode(slot: slot, itemID: item.id, canvas: canvas, scale: renderScale)
                node.applyPalette(palette, liveMaterial: materialMode == .live && !resolvedAppearance.reduceTransparency)
                node.install(shadowRoot: shadowView.root, maskRoot: liveMaskRoot, overlayRoot: overlayView.root)
                node.update(slot: slot, itemID: item.id, enabled: item.isEnabled, images: imgs, layout: radialLayout,
                            center: center, palette: palette, animation: nil)
                if let animation { node.growFromSliver(center: center, animation: animation) }
                kept.append(node)
            }
        }
        if nodes.count > radialLayout.slots.count {
            for node in nodes[radialLayout.slots.count...] {
                if let animation {
                    CATransaction.begin()
                    CATransaction.setCompletionBlock { node.removeFromTrees() }
                    node.collapse(center: center, animation: animation)
                    for l in node.movingLayers { l.set("opacity", to: Float(0), animation: animation) }
                    CATransaction.commit()
                } else {
                    node.removeFromTrees()
                }
            }
        }
        nodes = kept
        // The hub stays above segments so lifted wedges never cover it.
        LayerAnimation.withoutActions {
            for l in hubNode.movingLayers { l.zPosition = 2 }
        }
        updateDropZone()
        updateHitArea()
        rebuildAccessibility()
        if let previousHighlight, let index = nodes.firstIndex(where: { $0.itemID == previousHighlight }), lastPointer == nil {
            setHighlightedSlot(index, animated: false)
        }
        applyPill(animated: animation != nil)
    }

    /// Reduce Motion: wheel switches crossfade instead of morphing.
    private func crossfadeRebuild() {
        let fade = CATransition()
        fade.type = .fade
        fade.duration = configuration.crossfadeDuration
        for v in [shadowView, overlayView] { v.root.add(fade, forKey: "crossfade") }
        maskRoot.add(fade, forKey: "crossfade")
        rebuild(animation: nil)
    }

    private func updateDropZone() {
        if items.isEmpty, let zone = dropZone {
            let node = dropZoneNode ?? {
                let n = DropZoneNode(canvas: canvas, scale: renderScale)
                n.install(shadowRoot: shadowView.root, maskRoot: liveMaskRoot, overlayRoot: overlayView.root)
                dropZoneNode = n
                return n
            }()
            node.layout(zone: zone, center: wheelCenter, config: configuration, palette: palette,
                        liveMaterial: materialMode == .live && !resolvedAppearance.reduceTransparency, scale: renderScale)
        } else if let node = dropZoneNode {
            node.removeFromTrees()
            dropZoneNode = nil
            dropZoneTargeted = false
        }
    }

    private func updateHitArea() {
        let r = (items.isEmpty ? configuration.innerRing.outer : radialLayout.outerRadius) + configuration.outerTolerance
        let c = wheelCenter
        LayerAnimation.withoutActions {
            hitLayer.frame = canvas
            hitLayer.path = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
            hitLayer.fillColor = palette.hitFill
        }
    }

    // MARK: Appearance

    private func refreshAppearance() {
        let appearance = style.appearanceOverride ?? RadialAppearance.system(for: effectiveAppearance)
        resolvedAppearance = appearance
        palette = RadialPalette(style: style, appearance: appearance, hitAlpha: configuration.minimumHitAlpha)
        if let vfx = materialView {
            vfx.material = style.material.visualEffectMaterial
            vfx.appearance = style.appearanceOverride.map { $0.nsAppearance }
            // Reduce Transparency: AppKit already makes vibrancy opaque; we also paint solid fills.
            vfx.isHidden = appearance.reduceTransparency
        }
        let live = materialMode == .live && !appearance.reduceTransparency
        hubNode.layout(center: wheelCenter, config: configuration, palette: palette, liveMaterial: live)
        for node in nodes { node.applyPalette(palette, liveMaterial: live) }
        rebuild(animation: nil)
        applyHub(animated: false)
    }

    @objc private func accessibilityDisplayOptionsChanged() {
        refreshAppearance()
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if style.appearanceOverride == nil { refreshAppearance() }
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        guard scale != renderScale else { return }
        setRenderScale(scale)
    }

    /// Rasterisation scale for content bitmaps (window backing scale, or the snapshot scale).
    func setRenderScale(_ scale: CGFloat) {
        renderScale = scale
        let all: [CALayer] = [hitLayer] + nodes.flatMap(\.movingLayers) + hubNode.movingLayers
        LayerAnimation.withoutActions {
            for l in all { applyScale(scale, to: l) }
        }
        refreshAppearance()
    }

    private func applyScale(_ scale: CGFloat, to layer: CALayer) {
        layer.contentsScale = scale
        for s in layer.sublayers ?? [] { applyScale(scale, to: s) }
    }

    public override func layout() {
        super.layout()
        LayerAnimation.withoutActions { maskRoot.frame = bounds }
    }

    // MARK: Hub

    private func applyHub(animated: Bool) {
        hubNode.setThumbnail(hub, config: configuration, palette: palette, center: wheelCenter, scale: renderScale,
                             animated: animated)
        applyPill(animated: animated)
    }

    private func applyPill(animated: Bool) {
        if items.isEmpty, let zone = dropZone {
            hubNode.setPill(zone.title, highlighted: dropZoneTargeted, config: configuration, palette: palette,
                            scale: renderScale, animated: animated)
            return
        }
        if let slot = highlightedSlot {
            let item = item(for: radialLayout.slots[slot])
            let title = style.uppercaseTitleProminence && item.prominence == .title ? item.title.localizedUppercase : item.title
            hubNode.setPill(title, highlighted: item.isEnabled, config: configuration, palette: palette,
                            scale: renderScale, animated: animated)
        } else {
            hubNode.setPill(hub.idleText, highlighted: false, config: configuration, palette: palette,
                            scale: renderScale, animated: animated)
        }
    }

    // MARK: Hover

    func relative(_ point: NSPoint) -> CGPoint {
        CGPoint(x: point.x - wheelCenter.x, y: point.y - wheelCenter.y)
    }

    /// Updates hover for a pointer location in view coordinates.
    func updateHover(at point: NSPoint, animated: Bool = true) {
        lastPointer = point
        guard !isDismissing else { return }
        switch radialLayout.hitTest(relative(point), current: highlightedSlot) {
        case .slot(let s): setHighlightedSlot(s, animated: animated)
        case .deadZone, .outside: setHighlightedSlot(nil, animated: animated)
        }
    }

    func clearHover() {
        lastPointer = nil
        setHighlightedSlot(nil, animated: true)
    }

    func setHighlightedSlot(_ slot: Int?, animated: Bool) {
        guard slot != highlightedSlot else { return }
        let center = wheelCenter
        let reduce = resolvedAppearance.reduceMotion
        if let old = highlightedSlot, nodes.indices.contains(old) {
            nodes[old].setHighlighted(false, palette: palette, config: configuration, center: center,
                                      reduceMotion: reduce, animated: animated)
        }
        highlightedSlot = slot.flatMap { nodes.indices.contains($0) ? $0 : nil }
        if let new = highlightedSlot {
            nodes[new].setHighlighted(true, palette: palette, config: configuration, center: center,
                                      reduceMotion: reduce, animated: animated)
            if animated {
                // Best effort: AppKit ignores haptics while our app isn't active (mid-drag).
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
        applyPill(animated: animated)
        scheduleDwell()
        for e in segmentElements { e.refreshSelection() }
        if keyboardEnabled, let new = highlightedSlot, segmentElements.indices.contains(new) {
            NSAccessibility.post(element: segmentElements[new], notification: .focusedUIElementChanged)
        }
        delegate?.radialMenu(self, didHighlight: highlightedItem)
    }

    // MARK: Dwell (spring-loaded pager, options)

    private func scheduleDwell() {
        cancelDwell()
        guard let slot = highlightedSlot else { return }
        let target = radialLayout.slots[slot]
        let delay: Double
        let action: @MainActor (RadialMenuView) -> Void
        if target.isPager {
            delay = configuration.pagerDwell
            action = { menu in
                menu.showPage(menu.radialLayout.page + 1, animated: true)
                if let p = menu.lastPointer { menu.updateHover(at: p) }
            }
        } else if let index = target.itemIndex, configuration.optionsDwell > 0,
                  delegate?.radialMenu(self, hasOptionsFor: items[index]) == true {
            delay = configuration.optionsDwell
            action = { menu in
                guard menu.items.indices.contains(index) else { return }
                menu.delegate?.radialMenu(menu, didRequestOptionsFor: menu.items[index], anchor: menu.frame(forSlot: slot))
            }
        } else {
            return
        }
        dwell = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.highlightedSlot == slot, !self.isDismissing else { return }
            action(self)
        }
    }

    private func cancelDwell() {
        dwell?.cancel()
        dwell = nil
    }

    // MARK: Activation

    /// Activates the highlighted segment (Return / click). Pager flips the page.
    @discardableResult
    public func activateHighlighted() -> Bool {
        guard let slot = highlightedSlot else { return false }
        return activate(slot: slot)
    }

    @discardableResult
    func activate(slot: Int) -> Bool {
        guard radialLayout.slots.indices.contains(slot) else { return false }
        let target = radialLayout.slots[slot]
        if target.isPager {
            showPage(radialLayout.page + 1, animated: true)
            setHighlightedSlot(radialLayout.slots.firstIndex(where: \.isPager), animated: false)
            return true
        }
        guard let index = target.itemIndex, items[index].isEnabled else {
            NSSound.beep()
            return false
        }
        delegate?.radialMenu(self, didActivate: items[index])
        return true
    }

    func cancel() {
        delegate?.radialMenuDidCancel(self)
    }

    // MARK: Motion

    /// Resets transforms/opacities left by a previous close so the view can be shown again.
    public func prepareForDisplay() {
        isDismissing = false
        lastPointer = nil
        let all = nodes.flatMap(\.movingLayers) + hubNode.movingLayers + (dropZoneNode?.movingLayers ?? [])
        LayerAnimation.withoutActions {
            for l in all + [shadowView.root, overlayView.root, maskRoot] {
                l.removeAllAnimations()
                l.opacity = 1
            }
            for l in [shadowView.root, overlayView.root, maskRoot] { l.transform = CATransform3DIdentity }
        }
        setHighlightedSlot(nil, animated: false)
    }

    /// Segments fan out of the hub with a short stagger (< 180 ms total).
    /// Reduce Motion: a plain crossfade.
    public func playOpenAnimation() {
        prepareForDisplay()
        let segments = nodes.map(\.movingLayers) + [dropZoneNode?.movingLayers ?? []]
        if resolvedAppearance.reduceMotion {
            let fade = LayerAnimation.basic(configuration.crossfadeDuration, LayerAnimation.easeInOut)
            for l in [shadowView.root, overlayView.root, maskRoot] { l.animate("opacity", from: Float(0), animation: fade) }
            return
        }
        let timing = configuration.openTiming(segmentCount: max(1, nodes.count))
        let hubIn = LayerAnimation.basic(min(0.1, configuration.openDuration))
        for l in hubNode.movingLayers {
            l.animate("transform", from: NSValue(caTransform3D: CATransform3DMakeScale(0.72, 0.72, 1)), animation: hubIn)
            l.animate("opacity", from: Float(0), animation: hubIn)
        }
        let grow = LayerAnimation.basic(timing.segment)
        let fade = LayerAnimation.basic(timing.segment * 0.7)
        for (i, group) in segments.enumerated() {
            let delay = Double(i) * timing.stagger
            for l in group {
                l.animate("transform", from: NSValue(caTransform3D: CATransform3DMakeScale(0.55, 0.55, 1)), animation: grow, delay: delay)
                l.animate("opacity", from: Float(0), animation: fade, delay: delay)
            }
        }
    }

    /// Collapses toward `point` (view coordinates; nil = the hub) and fades out.
    public func playCloseAnimation(toward point: NSPoint? = nil, completion: (@MainActor () -> Void)? = nil) {
        isDismissing = true
        cancelDwell()
        let roots = [shadowView.root, overlayView.root, maskRoot]
        let duration = configuration.closeDuration
        CATransaction.begin()
        CATransaction.setCompletionBlock { completion?() }
        let fade = LayerAnimation.basic(duration, LayerAnimation.easeIn)
        for l in roots { l.set("opacity", to: Float(0), animation: fade) }
        if !resolvedAppearance.reduceMotion {
            let target = point ?? wheelCenter
            let t = CATransform3D.scale(0.35, about: target, in: canvas)
            for l in roots { l.set("transform", to: NSValue(caTransform3D: t), animation: fade) }
        }
        CATransaction.commit()
    }

    /// Drop landed: the segment pulses, then the wheel dissolves toward the drop point.
    public func playDropConfirmation(at point: NSPoint? = nil, completion: (@MainActor () -> Void)? = nil) {
        isDismissing = true
        cancelDwell()
        if let slot = highlightedSlot, nodes.indices.contains(slot) {
            nodes[slot].pulse(palette: palette, duration: configuration.dropConfirmDuration)
        } else {
            hubNode.pulse(palette: palette)
        }
        let wait = UInt64(configuration.dropConfirmDuration * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: wait)
            guard let self else { return }
            let roots = [self.shadowView.root, self.overlayView.root, self.maskRoot]
            CATransaction.begin()
            CATransaction.setCompletionBlock { completion?() }
            let fade = LayerAnimation.basic(self.configuration.closeDuration, LayerAnimation.easeIn)
            for l in roots { l.set("opacity", to: Float(0), animation: fade) }
            if !self.resolvedAppearance.reduceMotion {
                let t = CATransform3D.scale(0.92, about: point ?? self.wheelCenter, in: self.canvas)
                for l in roots { l.set("transform", to: NSValue(caTransform3D: t), animation: fade) }
            }
            CATransaction.commit()
        }
    }

    // MARK: Hit testing

    /// Only the painted disc is ours; everything else passes through.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let local = superview.map { convert(point, from: $0) } ?? point
        let r = (items.isEmpty ? configuration.innerRing.outer : radialLayout.outerRadius) + configuration.outerTolerance
        return hypot(local.x - wheelCenter.x, local.y - wheelCenter.y) <= r ? self : nil
    }

    // MARK: Drop zone

    func setDropZoneTargeted(_ on: Bool) {
        guard let node = dropZoneNode, on != dropZoneTargeted else { return }
        dropZoneTargeted = on
        node.setTargeted(on, palette: palette, config: configuration, center: wheelCenter,
                         reduceMotion: resolvedAppearance.reduceMotion, bounds: canvas)
        applyPill(animated: true)
    }

    var isShowingDropZone: Bool { items.isEmpty && dropZone != nil }

    // MARK: Accessibility

    private func rebuildAccessibility() {
        segmentElements = radialLayout.slots.indices.map { RadialSegmentElement(menu: self, slot: $0) }
        setAccessibilityChildren(segmentElements)
    }

    func accessibilityItem(forSlot slot: Int) -> RadialItem? {
        guard radialLayout.slots.indices.contains(slot) else { return nil }
        return item(for: radialLayout.slots[slot])
    }

    var accessibilitySelectedSlot: Int? { highlightedSlot }

    /// Posts a VoiceOver announcement (wheel switches, page flips).
    public func announce(_ text: String) {
        guard !text.isEmpty else { return }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: text,
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }

    public override func accessibilityHelp() -> String? { strings.menuHint }

    // MARK: Snapshot support

    var snapshotLayers: [CALayer] { [shadowView.root, overlayView.root] }
    var hitTestLayerForTesting: CAShapeLayer? { hitLayer }
}

/// A view whose layer tree we own (layer-hosting), so AppKit never touches sublayers.
@MainActor
final class LayerHostView: NSView {
    let root = CALayer()

    init() {
        super.init(frame: .zero)
        root.actions = SegmentNode.noActions
        layer = root
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
