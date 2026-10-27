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
    /// Up to three presets shown as chips outside `item` when it's locked or dwelled on.
    func radialMenu(_ menu: RadialMenuView, presetsFor item: RadialItem) -> [RadialPreset]
    /// A drop with its intent: run, configure first (tune lip or ⌥), or a preset chip.
    /// The default forwards `.item` (and anything unhandled) to `radialMenu(_:didDrop:on:)`.
    func radialMenu(_ menu: RadialMenuView, didDrop info: NSDraggingInfo, on item: RadialItem, target: RadialDropTarget) -> Bool
    /// The lock was set or cleared (⌥ tap mid-drag, Space in keyboard mode).
    func radialMenu(_ menu: RadialMenuView, didChangeLock locked: Bool)
    /// ⌥-Return in keyboard mode: configure the highlighted item before running it.
    func radialMenu(_ menu: RadialMenuView, didRequestTuneFor item: RadialItem)
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
    func radialMenu(_ menu: RadialMenuView, presetsFor item: RadialItem) -> [RadialPreset] { [] }
    func radialMenu(_ menu: RadialMenuView, didDrop info: NSDraggingInfo, on item: RadialItem, target: RadialDropTarget) -> Bool {
        radialMenu(menu, didDrop: info, on: item)
    }
    func radialMenu(_ menu: RadialMenuView, didChangeLock locked: Bool) {}
    func radialMenu(_ menu: RadialMenuView, didRequestTuneFor item: RadialItem) {
        radialMenu(menu, didRequestOptionsFor: item, anchor: .zero)
    }
}

/// A saved set of options shown as a chip outside a segment.
public struct RadialPreset: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// Where a drop lands, by intent.
public enum RadialDropTarget: Equatable, Sendable {
    /// The segment body: run with the remembered settings.
    case item(String)
    /// The tune lip, or ⌥ held at the drop: configure first.
    case tune(String)
    /// A preset chip.
    case preset(item: String, preset: String)

    public var itemID: String {
        switch self {
        case .item(let id), .tune(let id): id
        case .preset(let id, _): id
        }
    }
}

/// Text the menu draws itself. Hosts pass localised versions.
public struct RadialMenuStrings: Equatable, Sendable {
    public var morePages: String = "More"
    public var morePagesHint: String = "Shows the next page of options"
    public var pageFormat: String = "Page %d of %d"
    public var menuHint: String = "Arrow keys move, Return chooses, Escape cancels, Tab switches wheels"
    /// Hub pill over the tune lip, e.g. "GIF · Options".
    public var tuneFormat: String = "%@ · Options"
    /// Hub pill while locked, e.g. "GIF · Locked".
    public var lockedFormat: String = "%@ · Locked"
    /// Spoken when the lock changes.
    public var lockedAnnouncement: String = "%@ locked. Drop anywhere on the wheel."
    public var unlockedAnnouncement: String = "Unlocked"
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
    /// Whether the drag over the view would be accepted if released now: the
    /// last answer given to AppKit by `draggingEntered`/`draggingUpdated`.
    /// AppKit only delivers a drop when that answer wasn't empty, so a host that
    /// sees the mouse button go up can tell whether a drop is still coming.
    public internal(set) var acceptsCurrentDrop = false

    /// Centre of the wheel in view coordinates.
    public var wheelCenter: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    /// Radius of what's drawn now (for edge push-in).
    public var wheelRadius: CGFloat {
        (items.isEmpty ? configuration.innerRing.outer : radialLayout.outerRadius) + configuration.hoverLift
    }

    /// Locked: pointer movement can't change the selection, and a drop anywhere
    /// on the wheel (hub included) lands on it. Cleared when the items change.
    public internal(set) var isLocked = false
    /// Where a drop released now would land (nil = nowhere). Updated during drags.
    public internal(set) var dropTarget: RadialDropTarget?
    /// Held at the drop, this asks for `.tune` instead of `.item` (nil disables).
    /// Hosts that bind ⌥ as a trigger key set it to nil and rely on the lip.
    public var tuneModifier: NSEvent.ModifierFlags? = .option

    // Aiming state (RadialMenuView+Aim.swift)
    var pendingSwitch: (slot: Int, since: TimeInterval)?
    var switchTask: Task<Void, Never>?
    var isInLip = false
    var chipNodes: [ChipNode] = []
    var chipsSlot: Int?
    var hoveredChip: Int?
    let lockLayer = CAShapeLayer()
    let lipLayer = CAShapeLayer()

    // Layer trees
    private let shadowView = LayerHostView()
    let overlayView = LayerHostView()
    private var materialView: NSVisualEffectView?
    private let maskRoot = CALayer()
    private let hitLayer = CAShapeLayer()
    /// A painted surface's track: one soft disc the segments and hub sit on, so the wheel reads
    /// as one object rather than loose pieces.
    private let trackLayer = CAShapeLayer()
    private(set) var nodes: [SegmentNode] = []
    private var hubNode: HubNode
    private var dropZoneNode: DropZoneNode?
    private(set) var palette: RadialPalette

    // Interaction state
    private(set) var highlightedSlot: Int?
    var lastPointer: CGPoint?
    private var dwell: Task<Void, Never>?
    private var dropZoneTargeted = false
    var scrollAccumulatorValue: CGFloat = 0
    private var segmentElements: [RadialSegmentElement] = []
    private var renderScale: CGFloat = 2
    private(set) var isDismissing = false

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
        if materialMode == .live && style.surface == nil {
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
        trackLayer.actions = SegmentNode.noActions
        shadowView.content.addSublayer(trackLayer)
        shadowView.content.addSublayer(hitLayer)
        hubNode.install(shadowRoot: shadowView.content, maskRoot: liveMaskRoot, overlayRoot: overlayView.content)
        installAimLayers()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        refreshAppearance()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityDisplayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var liveMaskRoot: CALayer? { materialView != nil ? maskRoot : nil }
    /// Vibrancy is drawn (live mode, no painted surface, transparency allowed).
    private var usesLiveMaterial: Bool { materialView != nil && !resolvedAppearance.reduceTransparency }

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
            if hapticsEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
            soundHandler?(.page)
            announce(String(format: strings.pageFormat, radialLayout.page + 1, radialLayout.pageCount))
        }
    }

    private var requestedPage = 0

    /// Haptic ticks on segment and page changes (the host's Settings switch).
    public var hapticsEnabled = true

    /// Moments the host may give a sound to. The package plays nothing itself.
    public enum Sound: Sendable { case open, tick, page, activate, cancel }
    /// Called on each `Sound` moment; nil keeps the wheel silent.
    public var soundHandler: ((Sound) -> Void)?

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
        let scale = renderScale, palette = palette, style = style, config = configuration
        let highlight: (() -> CGImage?)? = enabled ? {
            ContentRenderer.segmentImage(item: item, ring: slot.ring, size: size, scale: scale, state: .highlighted,
                                         palette: palette, style: style, config: config)
        } : nil
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
        resetAim()
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
                node.applyPalette(palette, liveMaterial: usesLiveMaterial)
                node.install(shadowRoot: shadowView.content, maskRoot: liveMaskRoot, overlayRoot: overlayView.content)
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
        for v in [shadowView, overlayView] { v.content.add(fade, forKey: "crossfade") }
        maskRoot.add(fade, forKey: "crossfade")
        rebuild(animation: nil)
    }

    private func updateDropZone() {
        if items.isEmpty, let zone = dropZone {
            let node = dropZoneNode ?? {
                let n = DropZoneNode(canvas: canvas, scale: renderScale)
                n.install(shadowRoot: shadowView.content, maskRoot: liveMaskRoot, overlayRoot: overlayView.content)
                dropZoneNode = n
                return n
            }()
            node.layout(zone: zone, center: wheelCenter, config: configuration, palette: palette,
                        liveMaterial: usesLiveMaterial, scale: renderScale)
        } else if let node = dropZoneNode {
            node.removeFromTrees()
            dropZoneNode = nil
            dropZoneTargeted = false
        }
    }

    func updateHitArea() {
        let base = (items.isEmpty ? configuration.innerRing.outer : radialLayout.outerRadius) + configuration.outerTolerance
        // While chips show, the band out to them is painted too, so the drag can't
        // fall through to the window below on its way to a chip.
        let r = chipNodes.isEmpty ? base : max(base, chipReach + 6)
        let c = wheelCenter
        LayerAnimation.withoutActions {
            hitLayer.frame = canvas
            hitLayer.path = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2), transform: nil)
            hitLayer.fillColor = palette.hitFill
            let painted = style.surface != nil
            trackLayer.isHidden = !painted
            if painted {
                let t = base - configuration.outerTolerance + configuration.trackPadding
                let disc = CGPath(ellipseIn: CGRect(x: c.x - t, y: c.y - t, width: t * 2, height: t * 2), transform: nil)
                trackLayer.frame = canvas
                trackLayer.path = disc
                trackLayer.fillColor = palette.material
                trackLayer.strokeColor = palette.rim
                trackLayer.lineWidth = palette.rimWidth
                trackLayer.shadowPath = disc
                trackLayer.shadowColor = palette.shadowColor
                trackLayer.shadowOpacity = palette.shadowOpacity * 1.4
                trackLayer.shadowRadius = 22
                trackLayer.shadowOffset = CGSize(width: 0, height: -10)
            }
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
        let live = materialView != nil && !appearance.reduceTransparency
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

    /// Behind-window vibrancy for the transparent overlay panel; within-window
    /// when the wheel sits inside an ordinary window (onboarding demo, gallery).
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let vfx = materialView, let window else { return }
        vfx.blendingMode = window.isOpaque ? .withinWindow : .behindWindow
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
        LayerAnimation.withoutActions {
            maskRoot.frame = bounds
            shadowView.content.frame = bounds
            overlayView.content.frame = bounds
        }
    }

    // MARK: Hub

    private func applyHub(animated: Bool) {
        hubNode.setThumbnail(hub, config: configuration, palette: palette, center: wheelCenter, scale: renderScale,
                             animated: animated)
        applyPill(animated: animated)
    }

    func applyPill(animated: Bool) {
        if items.isEmpty, let zone = dropZone {
            hubNode.setPill(zone.title, highlighted: dropZoneTargeted, config: configuration, palette: palette,
                            scale: renderScale, animated: animated)
            return
        }
        if let slot = highlightedSlot {
            let item = item(for: radialLayout.slots[slot])
            var title = style.uppercaseTitleProminence && item.prominence == .title ? item.title.localizedUppercase : item.title
            if let chip = hoveredChip, chipNodes.indices.contains(chip) {
                title = chipNodes[chip].preset.title
            } else if isInLip {
                title = String(format: strings.tuneFormat, title)
            } else if isLocked {
                title = String(format: strings.lockedFormat, title)
            }
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
        if let guardPoint = movementGuard {
            // The wheel was pushed in from a screen edge, so the pointer may start
            // over a segment. Nothing is selected until it actually moves.
            if hypot(point.x - guardPoint.x, point.y - guardPoint.y) < Self.movementGuardDistance {
                setHighlightedSlot(nil, animated: animated)
                return
            }
            movementGuard = nil
        }
        aimHover(at: point, animated: animated)
    }

    func clearHover() {
        lastPointer = nil
        guard !isLocked else { return }
        cancelPendingSwitch()
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
                if hapticsEnabled { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now) }
                soundHandler?(.tick)
            }
        }
        if chipsSlot != nil && chipsSlot != highlightedSlot { hideChips() }
        setLip(false)
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
        } else if let index = target.itemIndex, configuration.presetBand > 0, items[index].isEnabled,
                  !(delegate?.radialMenu(self, presetsFor: items[index]) ?? []).isEmpty {
            delay = configuration.presetDwell
            action = { menu in menu.showChips(forSlot: slot) }
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

    func cancelDwell() {
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
        soundHandler?(.activate)
        delegate?.radialMenu(self, didActivate: items[index])
        return true
    }

    func cancel() {
        soundHandler?(.cancel)
        delegate?.radialMenuDidCancel(self)
    }

    // MARK: Motion

    /// Where the pointer was when the wheel appeared off-centre (view coordinates).
    /// Hover stays off until the pointer moves away from it, so a wheel pushed in
    /// from a screen edge never selects (or receives a drop on) a segment by accident.
    public var movementGuard: NSPoint?
    static let movementGuardDistance: CGFloat = 8

    /// Resets transforms/opacities left by a previous close so the view can be shown again.
    public func prepareForDisplay() {
        isDismissing = false
        lastPointer = nil
        acceptsCurrentDrop = false
        resetAim()
        let all = nodes.flatMap(\.movingLayers) + hubNode.movingLayers + (dropZoneNode?.movingLayers ?? [])
        LayerAnimation.withoutActions {
            for l in all + [shadowView.content, overlayView.content, maskRoot] {
                l.removeAllAnimations()
                l.opacity = 1
            }
            for l in [shadowView.content, overlayView.content, maskRoot] { l.transform = CATransform3DIdentity }
        }
        setHighlightedSlot(nil, animated: false)
    }

    /// Segments fan out of the hub with a short stagger (< 180 ms total).
    /// Reduce Motion: a plain crossfade.
    public func playOpenAnimation() {
        prepareForDisplay()
        soundHandler?(.open)
        let segments = nodes.map(\.movingLayers) + [dropZoneNode?.movingLayers ?? []]
        if resolvedAppearance.reduceMotion {
            let fade = LayerAnimation.basic(configuration.crossfadeDuration, LayerAnimation.easeInOut)
            for l in [shadowView.content, overlayView.content, maskRoot] { l.animate("opacity", from: Float(0), animation: fade) }
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
        let roots = [shadowView.content, overlayView.content, maskRoot]
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
            let roots = [self.shadowView.content, self.overlayView.content, self.maskRoot]
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
/// Everything lives in `content`, a plain canvas-sized layer with a centred
/// anchor: AppKit gives a view's own layer a (0, 0) anchor, which would make
/// collapse transforms pivot around the corner.
@MainActor
final class LayerHostView: NSView {
    let root = CALayer()
    let content = CALayer()

    init() {
        super.init(frame: .zero)
        root.actions = SegmentNode.noActions
        content.actions = SegmentNode.noActions
        root.addSublayer(content)
        layer = root
        wantsLayer = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        LayerAnimation.withoutActions { content.frame = CGRect(origin: .zero, size: newSize) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
