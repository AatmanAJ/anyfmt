import AppKit
import AnyfmtCore

/// The Move action's destination picker: a compact card at the drop point
/// listing recent destinations, plus "Choose Folder…" (a standard open panel).
///
/// Keyboard: ↑/↓ choose, Return moves, 1–8 jump to a recent folder, ⌘O opens
/// the folder picker, Escape (or clicking elsewhere) cancels.
@MainActor
final class MoveChooser {
    /// Recent folders that make sense for these items: not where they already
    /// all are, and not inside any of them (a folder can't go into itself).
    static func candidates(recents: [URL], items: [URL]) -> [URL] {
        let parents = Set(items.map { FileMover.canonicalFolder($0.deletingLastPathComponent()) })
        let folders = items.filter(FileMover.isRealDirectory).map(FileMover.canonicalItem)
        return recents.filter { recent in
            let path = FileMover.canonicalFolder(recent)
            if parents.count == 1, parents.contains(path) { return false }
            return !folders.contains { path == $0 || path.hasPrefix($0 + "/") }
        }
    }

    /// Shows the chooser near `point` and returns the chosen folder, or nil if cancelled.
    static func chooseDestination(for items: [URL], recents: [URL], near point: CGPoint) async -> URL? {
        let options = candidates(recents: recents, items: items)
        guard !options.isEmpty else {
            return await openPanel(for: items)
        }
        let chooser = MoveChooserController(items: items, folders: options, near: point)
        switch await chooser.run() {
        case .folder(let url): return url
        case .chooseOther: return await openPanel(for: items)
        case .cancelled: return nil
        }
    }

    /// The standard folder picker. Activates the app (an agent's modal panel
    /// needs it) and hands focus back afterwards.
    static func openPanel(for items: [URL]) async -> URL? {
        let previous = NSWorkspace.shared.frontmostApplication
        AirDropSender.activateApp()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Move Here")
        panel.message = MoveChooserView.title(for: items)
        if let first = items.first { panel.directoryURL = first.deletingLastPathComponent() }
        let response = await withCheckedContinuation { (c: CheckedContinuation<NSApplication.ModalResponse, Never>) in
            panel.begin { c.resume(returning: $0) }
        }
        if let previous, previous.processIdentifier != ProcessInfo.processInfo.processIdentifier, !previous.isTerminated {
            AirDropSender.activate(previous)
        }
        return response == .OK ? panel.url : nil
    }
}

enum MoveChoice: Equatable {
    case folder(URL)
    case chooseOther
    case cancelled
}

/// Owns the chooser panel for one run.
@MainActor
final class MoveChooserController: NSObject, NSWindowDelegate {
    private let panel: MoveChooserPanel
    private let view: MoveChooserView
    private var continuation: CheckedContinuation<MoveChoice, Never>?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?

    init(items: [URL], folders: [URL], near point: CGPoint) {
        view = MoveChooserView(items: items, folders: folders)
        panel = MoveChooserPanel(view: view)
        super.init()
        panel.delegate = self
        let size = view.preferredSize
        let margin = ActionStyle.shadowMargin
        // Top-left at the pointer, like a context menu, kept on screen.
        var card = CGRect(x: point.x - 18, y: point.y - size.height + 12, width: size.width, height: size.height)
        card = ShelfWindowPresenter.clamp(card, to: ShelfWindowPresenter.screen(containing: point)?.visibleFrame)
        panel.setFrame(card.insetBy(dx: -margin, dy: -margin), display: false)
        view.onChoice = { [weak self] in self?.finish($0) }
    }

    func run() async -> MoveChoice {
        await withCheckedContinuation { c in
            continuation = c
            panel.orderFrontRegardless()
            panel.makeKey()
            view.animateIn()
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.finish(.cancelled) }
            }
            localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                MainActor.assumeIsolated {
                    if let self, event.window !== self.panel { self.finish(.cancelled) }
                }
                return event
            }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        finish(.cancelled)
    }

    private func finish(_ choice: MoveChoice) {
        guard let c = continuation else { return }
        continuation = nil
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        if let m = localClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
        localClickMonitor = nil
        view.animateOut { [panel] in panel.orderOut(nil) }
        c.resume(returning: choice)
    }
}

@MainActor
final class MoveChooserPanel: NSPanel {
    init(view: MoveChooserView) {
        super.init(contentRect: NSRect(origin: .zero, size: view.preferredSize),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        let root = NSView()
        root.wantsLayer = true
        contentView = root
        view.autoresizingMask = [.width, .height]
        root.addSubview(view)
        view.frame = root.bounds.insetBy(dx: ActionStyle.shadowMargin, dy: ActionStyle.shadowMargin)
    }

    override var canBecomeKey: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        contentView?.subviews.first?.frame = (contentView?.bounds ?? .zero)
            .insetBy(dx: ActionStyle.shadowMargin, dy: ActionStyle.shadowMargin)
    }
}

/// The chooser card's content.
@MainActor
final class MoveChooserView: ActionCardView {
    static let width = DesignTokens.Component.MoveChooser.width
    static let rowHeight = DesignTokens.Component.MoveChooser.rowHeight
    static let headerHeight = DesignTokens.Component.MoveChooser.headerHeight
    static let padding = DesignTokens.Component.MoveChooser.padding

    var onChoice: ((MoveChoice) -> Void)?
    private let header = PassiveLabel(size: DesignTokens.Component.MoveChooser.headerSize, weight: .bold, color: ActionStyle.mist)
    private var rows: [MoveChooserRow] = []
    private let separator = CALayer()
    private(set) var selectedIndex = 0 { didSet { updateSelection() } }

    let folders: [URL]

    static func title(for items: [URL]) -> String {
        items.count == 1
            ? String(localized: "Move “\(items[0].lastPathComponent)” to")
            : String(localized: "Move \(items.count) items to")
    }

    convenience init(items: [URL], folders: [URL]) {
        self.init(items: items, destinations: folders.map(MoveDestination.init(folder:)))
    }

    init(items: [URL], destinations: [MoveDestination]) {
        let shown = Array(destinations.prefix(ActionPreferences.maxRecentFolders))
        self.folders = shown.map(\.url)
        super.init(cornerRadius: DesignTokens.Shape.tile)
        header.stringValue = Self.title(for: items)
        contentView.addSubview(header)
        for (i, destination) in shown.enumerated() {
            let folder = destination.url
            let row = MoveChooserRow(destination: destination, index: i)
            row.onHover = { [weak self] in self?.selectedIndex = i }
            row.onClick = { [weak self] in self?.onChoice?(.folder(folder)) }
            rows.append(row)
            contentView.addSubview(row)
        }
        let other = MoveChooserRow(chooseOtherAt: self.folders.count)
        other.onHover = { [weak self] in self?.selectedIndex = self?.folders.count ?? 0 }
        other.onClick = { [weak self] in self?.onChoice?(.chooseOther) }
        rows.append(other)
        contentView.addSubview(other)
        separator.actions = ["frame": NSNull(), "backgroundColor": NSNull(), "position": NSNull(), "bounds": NSNull()]
        contentView.layer?.addSublayer(separator)
        setAccessibilityElement(true)
        setAccessibilityRole(.list)
        setAccessibilityLabel(Self.title(for: items))
        setAccessibilityChildren(rows)
        updateSelection()
    }

    var preferredSize: NSSize {
        NSSize(width: Self.width,
               height: Self.headerHeight + CGFloat(rows.count) * Self.rowHeight + 9 + Self.padding + 3)
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func layout() {
        super.layout()
        let b = bounds
        let p = Self.padding
        header.frame = NSRect(x: 18, y: b.height - 25, width: b.width - 36, height: 14)
        var y = b.height - Self.headerHeight
        for (i, row) in rows.enumerated() {
            if i == folders.count {
                y -= 9 // separator before "Choose Folder…"
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                separator.frame = CGRect(x: 18, y: y + 4, width: b.width - 36, height: 1)
                separator.backgroundColor = ActionStyle.cg(ActionStyle.color(DesignTokens.Semantic.hairline), in: effectiveAppearance)
                CATransaction.commit()
            }
            y -= Self.rowHeight
            row.frame = NSRect(x: p, y: y, width: b.width - 2 * p, height: Self.rowHeight)
        }
        separator.isHidden = folders.isEmpty
    }

    private func updateSelection() {
        for (i, row) in rows.enumerated() { row.isSelected = i == selectedIndex }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 125: selectedIndex = min(selectedIndex + 1, rows.count - 1)         // ↓
        case 126: selectedIndex = max(selectedIndex - 1, 0)                      // ↑
        case 36, 76: choose(selectedIndex)                                       // Return, Enter
        case 53: onChoice?(.cancelled)                                           // Escape
        default:
            if flags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "o" {
                onChoice?(.chooseOther)
            } else if flags.isEmpty || flags == .numericPad,
                      let c = event.charactersIgnoringModifiers, let n = Int(c), n >= 1, n <= folders.count {
                choose(n - 1)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override func cancelOperation(_ sender: Any?) { onChoice?(.cancelled) }

    private func choose(_ index: Int) {
        if index < folders.count { onChoice?(.folder(folders[index])) } else { onChoice?(.chooseOther) }
    }

    // MARK: Motion

    func animateIn() {
        guard let layer else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = ActionStyle.duration(DesignTokens.Curve.glide)
        fade.timingFunction = ActionStyle.curve(DesignTokens.Curve.glide)
        layer.add(fade, forKey: "in")
        guard !ActionStyle.reduceMotion else { return }
        // Glides out of its top-left corner, where the pointer is.
        let grow = CABasicAnimation(keyPath: "transform")
        grow.fromValue = NSValue(caTransform3D: ShelfWindowPresenter.scale(0.94, about: CGPoint(x: 18, y: bounds.height - 12)))
        grow.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        grow.duration = DesignTokens.Curve.glide.duration
        grow.timingFunction = ActionStyle.curve(DesignTokens.Curve.glide)
        layer.add(grow, forKey: "grow")
    }

    func animateOut(completion: @escaping @MainActor () -> Void) {
        guard let layer else { completion(); return }
        CATransaction.begin()
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { completion() } }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = ActionStyle.duration(DesignTokens.Curve.exit)
        fade.timingFunction = ActionStyle.curve(DesignTokens.Curve.exit)
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        layer.add(fade, forKey: "out")
        CATransaction.commit()
    }
}

/// What a destination row shows.
@MainActor
struct MoveDestination {
    let url: URL
    let name: String
    /// Where the folder is: "Home", "~/Projects", "Backup Disk".
    let detail: String
    let icon: NSImage

    init(url: URL, name: String, detail: String, icon: NSImage) {
        self.url = url
        self.name = name
        self.detail = detail
        self.icon = icon
    }

    init(folder: URL) {
        self.init(url: folder,
                  name: FileManager.default.displayName(atPath: folder.path),
                  detail: Self.location(of: folder),
                  icon: NSWorkspace.shared.icon(forFile: folder.path))
    }

    /// The parent folder, home-relative ("~/Code"); the home folder itself
    /// reads "Home", and a volume's root reads as the volume's name.
    static func location(of folder: URL) -> String {
        let parent = folder.standardizedFileURL.deletingLastPathComponent()
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
        if parent.path == home.path { return String(localized: "Home") }
        let components = parent.pathComponents
        if components.count == 3, components[1] == "Volumes" { return components[2] }
        if parent.path == "/" { return FileManager.default.displayName(atPath: "/") }
        return (parent.path as NSString).abbreviatingWithTildeInPath
    }
}

/// One destination row: folder icon, name, where it is, and its number key.
@MainActor
final class MoveChooserRow: NSView {
    var onHover: (() -> Void)?
    var onClick: (() -> Void)?
    var isSelected = false { didSet { if isSelected != oldValue { needsLayout = true; updateColors() } } }

    private let highlight = CALayer()
    private let icon = NSImageView()
    private let name = PassiveLabel(size: DesignTokens.Component.MoveChooser.nameSize, weight: .bold)
    private let detail = PassiveLabel(size: DesignTokens.Component.MoveChooser.detailSize, weight: .medium, color: ActionStyle.mist)
    private let key = PassiveLabel(size: DesignTokens.Component.MoveChooser.detailSize, weight: .bold, color: ActionStyle.mist)
    private var tracking: NSTrackingArea?

    init(destination: MoveDestination, index: Int) {
        super.init(frame: .zero)
        setUp()
        let image = destination.icon
        image.size = NSSize(width: DesignTokens.Component.MoveChooser.iconSize, height: DesignTokens.Component.MoveChooser.iconSize)
        icon.image = image
        name.stringValue = destination.name
        detail.stringValue = destination.detail
        key.stringValue = "\(index + 1)"
        setAccessibilityLabel(name.stringValue)
        setAccessibilityHelp(String(localized: "In \(detail.stringValue)"))
    }

    init(chooseOtherAt index: Int) {
        super.init(frame: .zero)
        setUp()
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        icon.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        icon.contentTintColor = ActionStyle.accentText
        name.stringValue = String(localized: "Choose Folder…")
        key.stringValue = "⌘O"
        setAccessibilityLabel(name.stringValue)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func setUp() {
        wantsLayer = true
        // The selected row is a cobalt pill (the direction's two radii: tile and pill).
        highlight.cornerCurve = .continuous
        highlight.actions = ["frame": NSNull(), "position": NSNull(), "bounds": NSNull()]
        highlight.opacity = 0
        layer?.addSublayer(highlight)
        icon.imageScaling = .scaleProportionallyUpOrDown
        key.alignment = .right
        for v in [icon, name, detail, key] as [NSView] { addSubview(v) }
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let b = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.frame = b
        highlight.cornerRadius = b.height / 2
        highlight.backgroundColor = ActionStyle.selection.cgColor
        CATransaction.commit()
        let side = DesignTokens.Component.MoveChooser.iconSize
        icon.frame = NSRect(x: 12, y: (b.height - side) / 2, width: side, height: side)
        let textX: CGFloat = 44
        let keyWidth: CGFloat = 30
        let textWidth = b.width - textX - keyWidth - 10
        if detail.stringValue.isEmpty {
            name.frame = NSRect(x: textX, y: (b.height - 17) / 2, width: textWidth, height: 17)
        } else {
            name.frame = NSRect(x: textX, y: b.height / 2 - 1, width: textWidth, height: 17)
            detail.frame = NSRect(x: textX, y: b.height / 2 - 15, width: textWidth, height: 14)
        }
        key.frame = NSRect(x: b.width - keyWidth - 14, y: (b.height - 14) / 2, width: keyWidth, height: 14)
    }

    private func updateColors() {
        highlight.opacity = isSelected ? 1 : 0
        // White on cobalt is 5.0:1; the dimmer whites failed AA at caption size, so all text goes white.
        name.textColor = isSelected ? ActionStyle.onSelection : ActionStyle.ink
        detail.textColor = isSelected ? ActionStyle.onSelection : ActionStyle.mist
        key.textColor = isSelected ? ActionStyle.onSelection : ActionStyle.mist
        if name.stringValue == String(localized: "Choose Folder…") {
            icon.contentTintColor = isSelected ? ActionStyle.onSelection : ActionStyle.accentText
        }
        setAccessibilitySelected(isSelected)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) { onHover?() }
    override func mouseMoved(with event: NSEvent) { if !isSelected { onHover?() } }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}
