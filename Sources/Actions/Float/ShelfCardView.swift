import AppKit
import UniformTypeIdentifiers
import AnyfmtCore

/// The shelf itself: card chrome plus the pile (collapsed), the grid
/// (expanded) or a drop hint (empty). Also the drop target, the window-drag
/// handle and the context menu.
@MainActor
final class ShelfCardView: ActionCardView {
    enum Mode: Equatable { case empty, collapsed, expanded }

    static let collapsedSize = NSSize(width: 176, height: 200)
    static let padding = DesignTokens.Component.Shelf.padding
    static let headerHeight = DesignTokens.Component.Shelf.headerHeight

    static func size(mode: Mode, count: Int) -> NSSize {
        switch mode {
        case .empty, .collapsed:
            return collapsedSize
        case .expanded:
            let cols = ShelfGridView.columns(for: count)
            let grid = ShelfGridView.visibleSize(count: count, columns: cols)
            return NSSize(width: max(collapsedSize.width, grid.width + 2 * padding),
                          height: headerHeight + grid.height + padding)
        }
    }

    var onCommand: ((ShelfCommand) -> Void)?
    /// Asks the window to resize for a mode change.
    var onModeChange: ((Mode) -> Void)?
    /// Ends a window drag (the controller snaps and saves the position).
    var onWindowDragEnded: (() -> Void)?

    // Starts as .collapsed so the first apply(items: []) runs setMode(.empty) and sets visibility.
    private(set) var mode: Mode = .collapsed
    private(set) var items: [ShelfItem] = []
    private var expandedByHover = false

    let stackView = ShelfStackView()
    let gridView = ShelfGridView()
    private let scrollView = NSScrollView()
    private let titleLabel = PassiveLabel(size: DesignTokens.Component.Shelf.titleSize, weight: .bold)
    private let subtitleLabel = PassiveLabel(size: DesignTokens.Component.Shelf.detailSize, weight: .medium, color: ActionStyle.mist)
    private let closeButton = RoundSymbolButton(symbol: "xmark", label: String(localized: "Clear Shelf"))
    private let menuButton = RoundSymbolButton(symbol: "ellipsis", label: String(localized: "More"))
    private let collapseButton = RoundSymbolButton(symbol: "chevron.up", label: String(localized: "Collapse"), pointSize: 9)
    private let emptyView = ShelfEmptyView()
    private var tracking: NSTrackingArea?
    private var hoverTimer: Timer?
    private var collapseTimer: Timer?
    private(set) var isHovered = false

    /// Offscreen renders: show the hover controls without a pointer.
    var forceControlsVisible = false { didSet { updateControls(animated: false) } }

    init() {
        super.init(cornerRadius: DesignTokens.Component.Shelf.cornerRadius)
        stackView.onCommand = { [weak self] in self?.onCommand?($0) }
        stackView.onClick = { [weak self] in self?.stackClicked() }
        gridView.onCommand = { [weak self] in self?.onCommand?($0) }
        gridView.menuProvider = { [weak self] item in self?.itemMenu(for: item) ?? NSMenu() }

        scrollView.documentView = gridView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        scrollView.contentView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        // Left-aligned, like every other surface.
        titleLabel.alignment = .left
        subtitleLabel.alignment = .left
        titleLabel.lineBreakMode = .byTruncatingMiddle
        for v in [emptyView, stackView, titleLabel, subtitleLabel, scrollView] as [NSView] { contentView.addSubview(v) }
        for b in [closeButton, menuButton, collapseButton] {
            b.target = self
            contentView.addSubview(b)
        }
        closeButton.action = #selector(closeTapped)
        menuButton.action = #selector(menuTapped(_:))
        collapseButton.action = #selector(collapseTapped)

        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        apply(items: [], change: nil, animated: false)
        updateControls(animated: false)
    }

    // MARK: State

    func apply(items newItems: [ShelfItem], change: ShelfChange?, animated: Bool) {
        let wasEmpty = items.isEmpty
        items = newItems
        var newMode = mode
        if newItems.isEmpty { newMode = .empty }
        else if mode == .empty { newMode = .collapsed }
        else if mode == .expanded && newItems.count < 2 { newMode = .collapsed }
        stackView.apply(items: newItems, change: change, animated: animated)
        gridView.apply(items: newItems, change: change, animated: animated && mode == .expanded)
        if newItems.isEmpty && !wasEmpty && animated {
            // Emptied while showing: the shelf is about to dismiss itself, so
            // keep the current look while the last items fall out and it fades.
            // (Settle into the empty state later in case it stays up.)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.items.isEmpty else { return }
                    self.updateLabels()
                    self.setMode(.empty, animated: false)
                }
            }
            updateAccessibilityLabel()
            return
        }
        updateLabels()
        if newMode != mode {
            setMode(newMode, animated: animated)
        } else if mode == .expanded {
            onModeChange?(mode) // grid size may have changed
            needsLayout = true
        }
        updateAccessibilityLabel()
    }

    func setMode(_ newMode: Mode, animated: Bool) {
        guard newMode != mode else { return }
        mode = newMode
        if newMode == .expanded {
            gridView.apply(items: items, change: nil, animated: animated)
        }
        onModeChange?(newMode)
        needsLayout = true
        layoutSubtreeIfNeeded()
        let show: [NSView], hide: [NSView]
        switch newMode {
        case .empty: show = [emptyView, titleLabel]; hide = [stackView, subtitleLabel, scrollView]
        case .collapsed: show = [stackView, titleLabel, subtitleLabel]; hide = [emptyView, scrollView]
        case .expanded: show = [scrollView, titleLabel]; hide = [emptyView, stackView, subtitleLabel]
        }
        let duration = animated ? ActionStyle.duration(DesignTokens.Curve.glide) : 0
        for v in show { v.isHidden = false }
        if duration > 0 {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = ActionStyle.curve(DesignTokens.Curve.glide)
                for v in show { v.animator().alphaValue = 1 }
                for v in hide { v.animator().alphaValue = 0 }
            }, completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    for v in hide where v.alphaValue == 0 { v.isHidden = true }
                    self.updateAccessibilityLabel()
                }
            })
        } else {
            for v in show { v.alphaValue = 1 }
            for v in hide { v.alphaValue = 0; v.isHidden = true }
        }
        updateControls(animated: animated)
    }

    private func stackClicked() {
        guard items.count >= 2 else { return }
        expandedByHover = false
        setMode(.expanded, animated: true)
        // A click focuses the shelf (as clicking any window would) so Esc
        // collapses it. The panel is non-activating: the app stays in the background.
        window?.makeKey()
        window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, mode == .expanded { // Escape
            expandedByHover = false
            setMode(.collapsed, animated: true)
        } else {
            super.keyDown(with: event)
        }
    }

    @objc private func collapseTapped() {
        expandedByHover = false
        setMode(.collapsed, animated: true)
    }

    @objc private func closeTapped() { onCommand?(.clear) }

    @objc private func menuTapped(_ sender: NSButton) {
        let menu = shelfMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: sender.bounds.minX, y: sender.bounds.minY - 4), in: sender)
    }

    override func cancelOperation(_ sender: Any?) {
        if mode == .expanded { setMode(.collapsed, animated: true) }
    }

    /// Offscreen renders: the state while files are dragged over the shelf.
    func showDropTarget() {
        isHighlighted = true
        emptyView.isHighlighted = true
    }

    // MARK: Labels

    private func updateLabels() {
        switch items.count {
        case 0:
            titleLabel.stringValue = String(localized: "Float Shelf")
            subtitleLabel.stringValue = ""
        case 1:
            titleLabel.stringValue = items[0].name
            subtitleLabel.stringValue = ShelfSummary.detail(for: items[0].url)
        default:
            // "5 items" with the count in the display face.
            titleLabel.attributedStringValue = ActionStyle.countTitle(
                items.count, noun: String(localized: "items", comment: "Follows the item count on the Float shelf: “5 items”"),
                color: ActionStyle.ink)
            titleLabel.setAccessibilityLabel(String(localized: "\(items.count) items"))
            subtitleLabel.stringValue = ShelfSummary.kinds(for: items.map(\.url))
        }
    }

    private func updateAccessibilityLabel() {
        let count = items.count
        let base = String(localized: "Float shelf")
        switch count {
        case 0: setAccessibilityLabel(String(localized: "\(base), empty. Drop files here."))
        case 1: setAccessibilityLabel(String(localized: "\(base), 1 item"))
        default: setAccessibilityLabel(String(localized: "\(base), \(count) items"))
        }
    }

    // MARK: Layout

    override func layout() {
        super.layout()
        let b = bounds
        let p = Self.padding
        let d = DesignTokens.Component.Shelf.controlDiameter
        let countLine: CGFloat = 30 // fits the display-face count
        closeButton.frame = NSRect(x: 10, y: b.height - 30, width: d, height: d)
        menuButton.frame = NSRect(x: b.width - 30, y: b.height - 30, width: d, height: d)
        collapseButton.frame = NSRect(x: b.width - 54, y: b.height - 30, width: d, height: d)
        switch mode {
        case .empty, .collapsed:
            emptyView.frame = NSRect(x: 12, y: 12, width: b.width - 24, height: b.height - 12 - 40)
            stackView.frame = NSRect(x: 0, y: 58, width: b.width, height: b.height - 58 - 26)
            titleLabel.frame = mode == .empty
                ? NSRect(x: 38, y: b.height - 30, width: b.width - 76, height: 18)
                : NSRect(x: p, y: 24, width: b.width - 2 * p, height: items.count >= 2 ? countLine : 18)
            subtitleLabel.frame = NSRect(x: p, y: 10, width: b.width - 2 * p, height: 14)
        case .expanded:
            titleLabel.frame = NSRect(x: 38, y: b.height - 36, width: b.width - 38 - 62, height: countLine)
            let gridSize = ShelfGridView.visibleSize(count: items.count, columns: ShelfGridView.columns(for: items.count))
            let x = ((b.width - gridSize.width) / 2).rounded()
            scrollView.frame = NSRect(x: x, y: p, width: gridSize.width, height: max(0, b.height - Self.headerHeight - p))
            stackView.frame = NSRect(x: 0, y: 58, width: b.width, height: Self.collapsedSize.height - 58 - 26)
        }
    }

    // MARK: Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        collapseTimer?.invalidate()
        updateControls(animated: true)
        onCommand?(.hovered)
        // Resting on the pile peeks at the grid; pressing first (to drag) doesn't.
        if mode == .collapsed && items.count >= 2 {
            hoverTimer?.invalidate()
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.hoverIntentFired() }
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        hoverTimer?.invalidate()
        updateControls(animated: true)
        if mode == .expanded && expandedByHover {
            collapseTimer?.invalidate()
            collapseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.isHovered, self.expandedByHover else { return }
                    self.expandedByHover = false
                    self.setMode(.collapsed, animated: true)
                }
            }
        }
    }

    private func hoverIntentFired() {
        guard isHovered, mode == .collapsed, items.count >= 2, NSEvent.pressedMouseButtons == 0 else { return }
        let local = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        guard stackView.frame.contains(local) else { return }
        expandedByHover = true
        setMode(.expanded, animated: true)
    }

    private func updateControls(animated: Bool) {
        let visible = isHovered || forceControlsVisible || NSWorkspace.shared.isVoiceOverEnabled
        let close: CGFloat = visible ? 1 : 0
        let more: CGFloat = (visible && mode != .empty) ? 1 : 0
        let collapse: CGFloat = mode == .expanded ? 1 : 0
        let apply = {
            self.closeButton.alphaValue = close
            self.menuButton.alphaValue = more
            self.collapseButton.alphaValue = collapse
        }
        menuButton.isHidden = mode == .empty
        collapseButton.isHidden = mode != .expanded
        closeButton.setAccessibilityLabel(mode == .empty ? String(localized: "Close Shelf") : String(localized: "Clear Shelf"))
        closeButton.toolTip = closeButton.accessibilityLabel()
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = ActionStyle.duration(DesignTokens.Curve.snap)
                ctx.timingFunction = ActionStyle.curve(DesignTokens.Curve.snap)
                self.closeButton.animator().alphaValue = close
                self.menuButton.animator().alphaValue = more
                self.collapseButton.animator().alphaValue = collapse
            }
        } else {
            apply()
        }
    }

    // MARK: Moving the window by the card

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let start = NSEvent.mouseLocation
        let origin = window.frame.origin
        var moved = false
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
            let p = NSEvent.mouseLocation
            let dx = p.x - start.x, dy = p.y - start.y
            if !moved && hypot(dx, dy) < 2 { continue }
            moved = true
            window.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
        }
        if moved {
            onWindowDragEnded?()
        } else if event.clickCount == 2, mode == .expanded {
            setMode(.collapsed, animated: true)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    // MARK: Menus

    override func menu(for event: NSEvent) -> NSMenu? {
        items.isEmpty ? nil : shelfMenu()
    }

    func shelfMenu() -> NSMenu {
        let menu = NSMenu()
        let all = items.count
        menu.addItem(item(String(localized: "Reveal in Finder")) { $0.onCommand?(.reveal(nil)) })
        menu.addItem(item(all == 1 ? String(localized: "Copy") : String(localized: "Copy \(all) Items")) { $0.onCommand?(.copy(nil)) })
        menu.addItem(item(all == 1 ? String(localized: "Copy Path") : String(localized: "Copy Paths")) { $0.onCommand?(.copyPaths(nil)) })
        menu.addItem(item(all == 1 ? String(localized: "AirDrop…") : String(localized: "AirDrop All…")) { $0.onCommand?(.airDrop(nil)) })
        menu.addItem(.separator())
        if all >= 2 {
            if mode == .expanded {
                menu.addItem(item(String(localized: "Collapse")) { $0.setMode(.collapsed, animated: true) })
            } else {
                menu.addItem(item(String(localized: "Show All")) { $0.setMode(.expanded, animated: true) })
            }
        }
        menu.addItem(item(String(localized: "Clear Shelf")) { $0.onCommand?(.clear) })
        return menu
    }

    func itemMenu(for shelfItem: ShelfItem) -> NSMenu {
        let id: Set<UUID> = [shelfItem.id]
        let menu = NSMenu()
        menu.addItem(item(String(localized: "Open")) { $0.onCommand?(.open(id)) })
        menu.addItem(item(String(localized: "Reveal in Finder")) { $0.onCommand?(.reveal(id)) })
        menu.addItem(item(String(localized: "Copy")) { $0.onCommand?(.copy(id)) })
        menu.addItem(item(String(localized: "Copy Path")) { $0.onCommand?(.copyPaths(id)) })
        menu.addItem(item(String(localized: "AirDrop…")) { $0.onCommand?(.airDrop(id)) })
        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Remove from Shelf")) { $0.onCommand?(.remove(id)) })
        return menu
    }

    private func item(_ title: String, _ handler: @escaping @MainActor (ShelfCardView) -> Void) -> NSMenuItem {
        let mi = ClosureMenuItem(title: title, handler: { [weak self] in if let self { handler(self) } })
        return mi
    }

    // MARK: Drop target

    private func isOwnDrag(_ info: NSDraggingInfo) -> Bool {
        info.draggingSource is ShelfStackView || info.draggingSource is ShelfGridCell
    }

    private static func hasFiles(_ pb: NSPasteboard) -> Bool {
        if pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) { return true }
        let promiseTypes = Set(NSFilePromiseReceiver.readableDraggedTypes)
        return (pb.types ?? []).contains { promiseTypes.contains($0.rawValue) }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !isOwnDrag(sender), Self.hasFiles(sender.draggingPasteboard) else { return [] }
        isHighlighted = true
        emptyView.isHighlighted = true
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !isOwnDrag(sender), Self.hasFiles(sender.draggingPasteboard) else { return [] }
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        emptyView.isHighlighted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !isOwnDrag(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isHighlighted = false
        emptyView.isHighlighted = false
        let pb = sender.draggingPasteboard
        let urls = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        let promises = urls.isEmpty ? ((pb.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver]) ?? []) : []
        guard !urls.isEmpty || !promises.isEmpty else { return false }
        onCommand?(.receive(urls: urls, promises: promises, at: NSEvent.mouseLocation))
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isHighlighted = false
        emptyView.isHighlighted = false
    }
}

/// Drop hint for an empty shelf (opened from the menu bar): a dashed zone
/// with the tray glyph top-left and the words bottom-left. Highlighted (cobalt
/// dash and glyph) while files are over it.
@MainActor
final class ShelfEmptyView: NSView {
    private let dash = CAShapeLayer()
    private let glyph = NSImageView()
    private let title = PassiveLabel(size: DesignTokens.Component.Shelf.titleSize, weight: .bold)
    private let hint = PassiveLabel(size: DesignTokens.Component.Shelf.detailSize, weight: .medium, color: ActionStyle.mist)

    var isHighlighted = false {
        didSet {
            title.stringValue = isHighlighted ? String(localized: "Drop to add") : String(localized: "Drop files here")
            needsLayout = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let t = DesignTokens.Component.Shelf.self
        dash.fillColor = nil
        dash.lineWidth = t.dropLineWidth
        dash.lineDashPattern = t.dropDash.map { NSNumber(value: Double($0)) }
        dash.actions = ["path": NSNull(), "strokeColor": NSNull()]
        layer?.addSublayer(dash)
        let config = NSImage.SymbolConfiguration(pointSize: t.emptyGlyph, weight: .semibold)
        glyph.image = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        glyph.imageAlignment = .alignBottomLeft
        title.stringValue = String(localized: "Drop files here")
        hint.stringValue = String(localized: "Files stay in place.")
        for v in [glyph, title, hint] as [NSView] { addSubview(v) }
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let b = bounds
        let r = DesignTokens.Shape.tile
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dash.frame = b
        dash.path = CGPath(roundedRect: b.insetBy(dx: 0.75, dy: 0.75), cornerWidth: r, cornerHeight: r, transform: nil)
        dash.strokeColor = ActionStyle.cg(isHighlighted ? ActionStyle.accentText : ActionStyle.mist, in: effectiveAppearance)
        CATransaction.commit()
        glyph.contentTintColor = ActionStyle.accentText
        let inset: CGFloat = 14
        glyph.frame = NSRect(x: inset, y: b.height - inset - 30, width: 40, height: 30)
        title.frame = NSRect(x: inset, y: inset + 16, width: b.width - 2 * inset, height: 18)
        hint.frame = NSRect(x: inset, y: inset, width: b.width - 2 * inset, height: 14)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }
}

/// An NSMenuItem that runs a closure.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}

/// One-line descriptions under the shelf title.
enum ShelfSummary {
    /// "PNG image · 2.4 MB", "Folder".
    static func detail(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey, .fileSizeKey, .isDirectoryKey, .isPackageKey])
        let kind = values?.localizedTypeDescription ?? ""
        if values?.isDirectory == true && values?.isPackage != true { return kind }
        guard let size = values?.fileSize else { return kind }
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        return kind.isEmpty ? sizeText : "\(kind) · \(sizeText)"
    }

    enum Category: CaseIterable { case image, video, audio, pdf, folder, document }

    static func category(of url: URL) -> Category {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey, .isPackageKey])
        if values?.isDirectory == true && values?.isPackage != true { return .folder }
        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        guard let type else { return .document }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .pdf) { return .pdf }
        return .document
    }

    /// "3 images", "2 images, 1 folder", "1 video, 2 PDFs, 1 file";
    /// four or more kinds: the two biggest groups and "+N more".
    static func kinds(for urls: [URL]) -> String {
        var counts: [Category: Int] = [:]
        for u in urls { counts[category(of: u), default: 0] += 1 }
        let present = Category.allCases.compactMap { c in counts[c].map { (c, $0) } }
        if present.count <= 3 {
            return present.map { phrase($0.0, $0.1) }.joined(separator: ", ")
        }
        let top = present.enumerated().sorted { ($0.element.1, -$0.offset) > ($1.element.1, -$1.offset) }.prefix(2).map(\.element)
        let shown = top.reduce(0) { $0 + $1.1 }
        let lead = top.map { phrase($0.0, $0.1) }.joined(separator: ", ")
        return String(localized: "\(lead), +\(urls.count - shown) more")
    }

    private static func phrase(_ c: Category, _ n: Int) -> String {
        switch (c, n == 1) {
        case (.image, true): String(localized: "1 image")
        case (.image, false): String(localized: "\(n) images")
        case (.video, true): String(localized: "1 video")
        case (.video, false): String(localized: "\(n) videos")
        case (.audio, true): String(localized: "1 audio file")
        case (.audio, false): String(localized: "\(n) audio files")
        case (.pdf, true): String(localized: "1 PDF")
        case (.pdf, false): String(localized: "\(n) PDFs")
        case (.folder, true): String(localized: "1 folder")
        case (.folder, false): String(localized: "\(n) folders")
        case (.document, true): String(localized: "1 file")
        case (.document, false): String(localized: "\(n) files")
        }
    }
}
