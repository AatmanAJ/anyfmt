import AppKit
import AnyfmtCore

/// The expanded shelf: every item as a cell (thumbnail + name), in the order
/// they arrived. Drag a cell to drag that one item; hover shows its ✕.
@MainActor
final class ShelfGridView: NSView {
    static let cellSize = NSSize(width: 84, height: 96)
    static let gap: CGFloat = 6
    static let maxVisibleRows = 3

    var thumbnails: ShelfThumbnailProviding = QuickLookThumbnails.shared
    var onCommand: ((ShelfCommand) -> Void)?
    var renderScale: CGFloat?
    var menuProvider: ((ShelfItem) -> NSMenu)?

    private(set) var items: [ShelfItem] = []
    private(set) var columns = 3
    private var cells: [UUID: ShelfGridCell] = [:]

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    static func columns(for count: Int) -> Int { count <= 2 ? 2 : 3 }

    static func rows(for count: Int, columns: Int) -> Int {
        max(1, Int((Double(count) / Double(columns)).rounded(.up)))
    }

    /// Size of the whole grid (the scroll view's document).
    static func contentSize(count: Int, columns: Int) -> NSSize {
        let rows = rows(for: count, columns: columns)
        return NSSize(width: CGFloat(columns) * cellSize.width + CGFloat(columns - 1) * gap,
                      height: CGFloat(rows) * cellSize.height + CGFloat(rows - 1) * gap)
    }

    /// Size of the visible area (at most `maxVisibleRows` rows; the rest scroll).
    static func visibleSize(count: Int, columns: Int) -> NSSize {
        let rows = min(rows(for: count, columns: columns), maxVisibleRows)
        return NSSize(width: CGFloat(columns) * cellSize.width + CGFloat(columns - 1) * gap,
                      height: CGFloat(rows) * cellSize.height + CGFloat(rows - 1) * gap)
    }

    func frame(forIndex i: Int) -> NSRect {
        let row = i / columns, col = i % columns
        return NSRect(x: CGFloat(col) * (Self.cellSize.width + Self.gap),
                      y: CGFloat(row) * (Self.cellSize.height + Self.gap),
                      width: Self.cellSize.width, height: Self.cellSize.height)
    }

    func apply(items newItems: [ShelfItem], change: ShelfChange?, animated: Bool) {
        items = newItems
        columns = Self.columns(for: newItems.count)
        setFrameSize(Self.contentSize(count: newItems.count, columns: columns))
        let motion = animated && !ActionStyle.reduceMotion
        let ids = Set(newItems.map(\.id))
        let added = Set((change?.added ?? []).map(\.id))

        for (id, cell) in cells where !ids.contains(id) {
            cells[id] = nil
            if animated {
                cell.animateOut(motion: motion) { [weak cell] in cell?.removeFromSuperview() }
            } else {
                cell.removeFromSuperview()
            }
        }
        for (i, item) in newItems.enumerated() {
            let target = frame(forIndex: i)
            if let cell = cells[item.id] {
                cell.update(item: item)
                if motion && cell.frame != target {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = DesignTokens.Curve.glide.duration
                        ctx.timingFunction = ActionStyle.curve(DesignTokens.Curve.glide)
                        ctx.allowsImplicitAnimation = true
                        cell.animator().frame = target
                    }
                } else {
                    cell.frame = target
                }
            } else {
                let cell = ShelfGridCell(item: item, thumbnails: thumbnails, scale: renderScale)
                cell.onCommand = { [weak self] in self?.onCommand?($0) }
                cell.menuProvider = { [weak self] item in self?.menuProvider?(item) }
                cell.frame = target
                addSubview(cell)
                cells[item.id] = cell
                if animated && (added.contains(item.id) || change == nil) {
                    cell.animateIn(motion: motion, delay: change == nil ? Double(i) * 0.018 : 0)
                }
            }
        }
        setAccessibilityChildren(newItems.compactMap { cells[$0.id] })
    }

    func cell(for id: UUID) -> ShelfGridCell? { cells[id] }
}

/// One cell of the grid.
@MainActor
final class ShelfGridCell: NSView, NSDraggingSource {
    private(set) var item: ShelfItem
    var onCommand: ((ShelfCommand) -> Void)?
    var menuProvider: ((ShelfItem) -> NSMenu?)?

    private let thumbnails: ShelfThumbnailProviding
    private let renderScale: CGFloat?
    private let print = ShelfPrintLayer()
    private let hoverLayer = CALayer()
    // Two single-line labels: each draws exactly what a single-line cell measures.
    private let line1 = PassiveLabel(size: DesignTokens.Component.Shelf.cellLabelSize, weight: .medium)
    private let line2 = PassiveLabel(size: DesignTokens.Component.Shelf.cellLabelSize, weight: .medium)
    private let removeButton: RoundSymbolButton
    private var tracking: NSTrackingArea?
    private var mouseDown: NSEvent?
    private(set) var isHovered = false { didSet { updateHover() } }
    static let thumbSide: CGFloat = 56
    static let labelFont = ActionStyle.font(DesignTokens.Component.Shelf.cellLabelSize, .medium)
    static let labelWidth = ShelfGridView.cellSize.width - 6

    /// Text budget per line: the label width less the text cell's insets
    /// (measured: AppKit reserves ~4 pt more than `cellSize` reports, so
    /// budget 8 pt and never trigger AppKit's own truncation).
    static let labelTextWidth = labelWidth - 8

    static func labelText(_ name: String) -> String {
        ShelfNameLayout.lines(for: name, font: labelFont, width: labelTextWidth)
    }

    /// Shows the hover state in offscreen renders.
    var forceHover = false { didSet { updateHover() } }

    init(item: ShelfItem, thumbnails: ShelfThumbnailProviding, scale: CGFloat?) {
        self.item = item
        self.thumbnails = thumbnails
        self.renderScale = scale
        removeButton = RoundSymbolButton(symbol: "xmark", label: "", diameter: DesignTokens.Component.Shelf.badgeDiameter,
                                         pointSize: DesignTokens.Component.Shelf.badgeGlyph, style: .badge)
        super.init(frame: NSRect(origin: .zero, size: ShelfGridView.cellSize))
        wantsLayer = true
        layer?.masksToBounds = false
        hoverLayer.cornerRadius = DesignTokens.Shape.tile
        hoverLayer.cornerCurve = .continuous
        hoverLayer.opacity = 0
        hoverLayer.actions = ShelfPrintLayer.noActions
        layer?.addSublayer(hoverLayer)
        layer?.addSublayer(print)


        removeButton.target = self
        removeButton.action = #selector(removeTapped)
        removeButton.alphaValue = 0
        for l in [line1, line2] { l.alignment = .center; addSubview(l) }
        addSubview(removeButton)

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityRoleDescription(String(localized: "file"))
        update(item: item)
        loadThumbnail()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var scale: CGFloat { renderScale ?? window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2 }

    func update(item: ShelfItem) {
        let urlChanged = item.url != self.item.url
        self.item = item
        let lines = Self.labelText(item.name).components(separatedBy: "\n")
        line1.stringValue = lines.first ?? ""
        line2.stringValue = lines.count > 1 ? lines[1] : ""
        toolTip = item.url.path
        needsLayout = true
        removeButton.setAccessibilityLabel(String(localized: "Remove “\(item.name)” from Shelf"))
        removeButton.toolTip = String(localized: "Remove from Shelf")
        setAccessibilityLabel(item.name)
        let id = item.id
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: String(localized: "Remove from Shelf")) { [weak self] in
                self?.onCommand?(.remove([id])); return true
            },
            NSAccessibilityCustomAction(name: String(localized: "Reveal in Finder")) { [weak self] in
                self?.onCommand?(.reveal([id])); return true
            },
            NSAccessibilityCustomAction(name: String(localized: "Copy")) { [weak self] in
                self?.onCommand?(.copy([id])); return true
            },
        ])
        if urlChanged { loadThumbnail() }
    }

    private func loadThumbnail() {
        let side = Self.thumbSide
        let t = thumbnails.thumbnail(for: item.url, side: side, scale: scale) { [weak self] better in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.print.configure(better, side: side, scale: self.scale, appearance: self.effectiveAppearance)
            CATransaction.commit()
            self.needsLayout = true
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        print.configure(t, side: side, scale: scale, appearance: effectiveAppearance)
        CATransaction.commit()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hoverLayer.frame = bounds
        hoverLayer.backgroundColor = ActionStyle.cg(ActionStyle.hoverFill, in: effectiveAppearance)
        // Bottom-left origin: thumbnail centred in the top part, name underneath.
        print.position = CGPoint(x: bounds.midX, y: bounds.height - 6 - Self.thumbSide / 2)
        CATransaction.commit()
        let twoLines = !line2.stringValue.isEmpty
        line1.frame = NSRect(x: 3, y: twoLines ? 17 : 15, width: Self.labelWidth, height: 15)
        line2.frame = NSRect(x: 3, y: 3, width: Self.labelWidth, height: 15)
        let thumbFrame = print.frame
        removeButton.frame = NSRect(x: max(1, thumbFrame.minX - 7), y: min(bounds.height - 19, thumbFrame.maxY - 11),
                                    width: 18, height: 18)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        loadThumbnail()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        loadThumbnail()
    }

    // MARK: Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    private func updateHover() {
        let on = isHovered || forceHover
        let duration = (forceHover || window == nil) ? 0 : ActionStyle.duration(DesignTokens.Curve.snap)
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        hoverLayer.opacity = on ? 1 : 0
        CATransaction.commit()
        if duration == 0 {
            removeButton.alphaValue = on ? 1 : 0
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = duration
                removeButton.animator().alphaValue = on ? 1 : 0
            }
        }
    }

    @objc private func removeTapped() { onCommand?(.remove([item.id])) }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        mouseDown = event
        if event.clickCount == 2 {
            onCommand?(.open([item.id]))
            mouseDown = nil
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDown else { return }
        let a = down.locationInWindow, b = event.locationInWindow
        guard hypot(b.x - a.x, b.y - a.y) > 3 else { return }
        mouseDown = nil
        let pb = NSPasteboardItem()
        pb.setString(item.url.absoluteString, forType: .fileURL)
        let d = NSDraggingItem(pasteboardWriter: pb)
        d.setDraggingFrame(print.frame, contents: print.image ?? NSWorkspace.shared.icon(forFile: item.url.path))
        let session = beginDraggingSession(with: [d], event: down, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        alphaValue = 0.4
    }

    override func mouseUp(with event: NSEvent) { mouseDown = nil }

    override func menu(for event: NSEvent) -> NSMenu? { menuProvider?(item) }

    nonisolated func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link, .generic] : [.copy]
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        MainActor.assumeIsolated {
            let keep = NSEvent.modifierFlags.contains(.option)
            alphaValue = 1
            onCommand?(.dragEnded([item.id], operation: operation, keepOnShelf: keep))
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onCommand?(.open([item.id]))
        return true
    }

    // MARK: Animation

    func animateIn(motion: Bool, delay: Double) {
        guard let layer else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = DesignTokens.Motion.crossfade
        fade.beginTime = CACurrentMediaTime() + delay
        fade.fillMode = .backwards
        layer.add(fade, forKey: "in")
        guard motion else { return }
        // Scale about the cell's centre (layer-backed views anchor at the origin).
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        var from = CATransform3DMakeTranslation(c.x, c.y, 0)
        from = CATransform3DScale(from, 0.7, 0.7, 1)
        from = CATransform3DTranslate(from, -c.x, -c.y, 0)
        let spring = ActionStyle.spring("transform", response: 0.36, damping: 0.68)
        spring.fromValue = NSValue(caTransform3D: from)
        spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        spring.beginTime = fade.beginTime
        spring.fillMode = .backwards
        layer.add(spring, forKey: "pop")
    }

    func animateOut(motion: Bool, completion: @escaping @MainActor () -> Void) {
        guard let layer else { completion(); return }
        CATransaction.begin()
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { completion() } }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = DesignTokens.Curve.exit.duration + 0.06
        fade.timingFunction = ActionStyle.curve(DesignTokens.Curve.exit)
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        layer.add(fade, forKey: "out")
        if motion {
            let c = CGPoint(x: bounds.midX, y: bounds.midY)
            var to = CATransform3DMakeTranslation(c.x, c.y - 10, 0)
            to = CATransform3DScale(to, 0.82, 0.82, 1)
            to = CATransform3DTranslate(to, -c.x, -c.y, 0)
            let shrink = CABasicAnimation(keyPath: "transform")
            shrink.toValue = NSValue(caTransform3D: to)
            shrink.duration = DesignTokens.Curve.exit.duration + 0.06
            shrink.timingFunction = ActionStyle.curve(DesignTokens.Curve.exit)
            shrink.fillMode = .forwards
            shrink.isRemovedOnCompletion = false
            layer.add(shrink, forKey: "shrink")
        }
        CATransaction.commit()
    }
}
