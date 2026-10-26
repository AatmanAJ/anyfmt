import AppKit
import AnyfmtCore
import RadialMenu
import UniformTypeIdentifiers

/// Owns the overlay panel and turns wheel interactions into selections.
///
/// Three ways in:
/// - **Drag** (`show`): DragSense saw a Finder drag + a modifier tap. The panel
///   never takes focus; Finder keeps the drag. Modifier taps call `switchKind`.
/// - **Selection** (`showForSelection`): Return on a Finder selection or the
///   Services item. The panel becomes key: arrows, Return, Escape, Tab, 1–9.
/// - **Drop ring** (`showDropRing`): the global-hotkey fallback (D-004). An empty
///   ring accepts files dragged onto it, then becomes the convert wheel in place.
@MainActor
public final class WheelController: NSObject {
    public enum Mode: Equatable, Sendable { case drag, selection, dropRing }

    public var preferences: WheelPreferences
    public var provider: WheelContentProvider
    public let cloud: CloudSegments

    /// The user chose something. `dropPoint` is in global screen coordinates
    /// (where the progress window should appear).
    public var onSelect: ((WheelSelection, [URL], [NSFilePromiseReceiver], CGPoint) -> Void)?
    /// Escape, a drop in the hub, a click outside in keyboard mode.
    public var onCancel: (() -> Void)?
    /// A drop on the tune lip, with ⌥ held, or ⌥-Return: configure this target
    /// first. The wheel has closed; the host opens the options panel.
    public var onTune: ((RouteTarget, [URL], [NSFilePromiseReceiver], CGPoint) -> Void)?
    /// Presets shown as chips (and "Last used").
    public var presetStore: PresetStore = .shared
    /// Chip id for the last options used with a format.
    public static let lastUsedPresetID = "anyfmt.last-used"
    /// Timing hook: called when the window server reports the panel visible.
    public var markVisible: (() -> Void)?
    /// The visible wheel changed (including fallbacks to Actions).
    public var onKindChange: ((WheelKind) -> Void)?
    /// Options chosen in the popover, per target format. Sticky for the session;
    /// the host may persist and restore it.
    public var rememberedOptions: [FormatID: OptionValues] = [:]

    public private(set) var kind: WheelKind?
    public private(set) var mode: Mode = .drag
    public private(set) var input = WheelInput()
    public private(set) var entries: [WheelEntry] = []
    public var isVisible: Bool { panel.isVisible }
    /// Settings › General › Haptics.
    public var hapticsEnabled: Bool {
        get { menuView.hapticsEnabled }
        set { menuView.hapticsEnabled = newValue }
    }

    let panel: RadialMenuPanel
    var menuView: RadialMenuView { panel.menuView }
    private let options = WheelOptionsPopover()
    private var promises: [NSFilePromiseReceiver] = []
    private var thumbnailTask: Task<Void, Never>?
    private var dropRingTimeout: Task<Void, Never>?
    private var resignObserver: NSObjectProtocol?
    private var idleText = ""
    private var activatedApp = false

    public init(provider: WheelContentProvider, cloud: CloudSegments = CloudSegments(),
                preferences: WheelPreferences = .standard) {
        self.provider = provider
        self.cloud = cloud
        self.preferences = preferences
        panel = RadialMenuPanel(configuration: WheelTheme.configuration, style: WheelTheme.style)
        super.init()
        menuView.strings = WheelTheme.strings
        menuView.delegate = self
        panel.onVisible = { [weak self] in self?.markVisible?() }
        options.draggedTypes = panel.draggedTypes
        options.onApply = { [weak self] target, values in self?.applyOptions(target: target, values: values) }
        options.onDrop = { [weak self] info in self?.dropOnOptions(info) ?? false }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panelResignedKey() }
        }
    }

    /// Convenience for the app: live router, default cloud gate.
    public override convenience init() {
        self.init(provider: .live())
    }

    // MARK: Showing

    /// Pays the panel's one-time window-server/Core Animation setup up front (call at launch).
    public func prewarm() {
        // Both segment styles: format labels with a "via" line (Convert) and
        // glyphs (Tools, Actions), so neither first wheel lays out text cold.
        let labels = (0..<8).map {
            RadialItem(id: "prewarm.\($0)", title: "WEBP", symbolName: "photo",
                       subtitle: $0 == 0 ? "via PNG" : nil, prominence: .title)
        }
        menuView.setItems(labels, animated: false)
        panel.prewarm()
        // First-use costs a show would otherwise pay on the main thread: the
        // file icon and size formatter behind the hub, and every format glyph.
        if let file = Bundle.main.executableURL { _ = WheelHub.immediate(for: WheelInput(urls: [file])) }
        for glyph in Set(Formats.all.map(\.glyph) + FileKind.allCases.map(\.glyph)) {
            _ = WheelContentProvider.symbol(glyph)
        }
        menuView.setItems(WheelContentProvider.items(for: provider.entries(for: WheelInput(), kind: .actions, preferences: preferences),
                                                     cloud: cloud), animated: false)
        panel.prewarm()
    }

    /// Mid-drag entry point. `point` is the pointer in global coordinates.
    public func show(kind: WheelKind, urls: [URL], promisedTypes: [UTType] = [], at point: CGPoint) {
        prepareForNewSession(mode: .drag)
        present(kind: kind, input: WheelInput(urls: urls, promisedTypes: promisedTypes), at: point)
    }

    /// Keyboard entry point (Return on a Finder selection, Services). The panel becomes key.
    public func showForSelection(urls: [URL], at point: CGPoint, kind: WheelKind = .convert) {
        prepareForNewSession(mode: .selection)
        panel.allowsKeyboard = true
        activateApp()
        present(kind: kind, input: WheelInput(urls: urls), at: point)
        menuView.highlightItem(at: entries.isEmpty ? nil : 0, animated: false)
    }

    /// Hotkey fallback: an empty ring at `point` that accepts files dragged onto it.
    public func showDropRing(at point: CGPoint) {
        prepareForNewSession(mode: .dropRing)
        input = WheelInput()
        entries = []
        kind = nil
        menuView.menuTitle = String(localized: "Drop files to convert", comment: "Accessibility name of the empty drop ring")
        menuView.setItems([], animated: false)
        menuView.hub = RadialHubContent()
        menuView.dropZone = RadialDropZone(title: String(localized: "Drop files", comment: "Hub text of the empty drop ring"),
                                           image: RadialItem.symbol("arrow.down.to.line"))
        panel.allowsKeyboard = true
        activateApp()
        panel.show(at: point)
        menuView.announce(menuView.menuTitle)
        // Nobody brought files: fade away rather than linger.
        dropRingTimeout = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled, let self, self.mode == .dropRing, self.input.isEmpty, self.isVisible else { return }
            self.cancel()
        }
    }

    /// Mid-drag wheel switch (Shift ↔ Command ↔ Control, Tab). Morphs in place.
    public func switchKind(_ newKind: WheelKind) {
        guard isVisible, !input.isEmpty else { return }
        let resolved = provider.resolve(input, kind: newKind, preferences: preferences)
        options.close()
        idleText = resolved.note ?? WheelHub.idleText(for: input)
        var hub = menuView.hub
        hub.idleText = idleText
        menuView.hub = hub
        if resolved.kind != kind || resolved.entries != entries {
            kind = resolved.kind
            entries = resolved.entries
            menuView.menuTitle = resolved.kind.title
            menuView.setItems(WheelContentProvider.items(for: entries, cloud: cloud), animated: true)
            panel.position(animated: true)
            onKindChange?(resolved.kind)
        }
        if mode != .drag { menuView.highlightItem(at: entries.isEmpty ? nil : 0, animated: false) }
        menuView.announce(resolved.note.map { "\($0). \(resolved.kind.title)" } ?? resolved.kind.title)
    }

    /// Hides the wheel (collapsing toward the pointer).
    public func hide(animated: Bool = true) {
        options.close()
        thumbnailTask?.cancel()
        dropRingTimeout?.cancel()
        panel.dismiss(toward: NSEvent.mouseLocation, animated: animated)
        endSession()
    }

    /// Commits the highlighted segment as if it were dropped on (hosts that detect
    /// the drop themselves). Does nothing if nothing is highlighted.
    public func confirmDrop() {
        guard let item = menuView.highlightedItem, let entry = entry(for: item.id) else { return }
        commit(entry, urls: input.urls, promises: promises, at: NSEvent.mouseLocation)
    }

    /// ⌥ tapped mid-drag: lock the highlighted segment so drift can't change it (or unlock).
    public func toggleLock() {
        guard mode == .drag, isVisible else { return }
        menuView.toggleLock()
    }

    /// DragSense saw the button go up at `point`. A release on a segment (or
    /// the options popover) waits: AppKit delivers that drop a beat after the
    /// button goes up, and hiding the panel first would lose it. Anywhere else
    /// (the hub, a gap, another app) no drop is coming, so the wheel hides.
    /// Returns true when the wheel is waiting for the drop.
    @discardableResult
    public func dragDidEnd(at point: CGPoint) -> Bool {
        guard mode == .drag, isVisible, kind != nil else { return false }
        if expectsDrop(at: point) { return true }
        hide(animated: true)
        return false
    }

    /// The drag ended without a drop on the wheel (DragSense gave up waiting,
    /// or Escape in Finder).
    public func dragDidEnd() {
        guard mode == .drag, isVisible, kind != nil else { return }
        hide(animated: true)
    }

    /// Whether AppKit will deliver a drop released at `point` (global
    /// coordinates): the wheel last told it the drop would be accepted, or the
    /// pointer is over the options popover, which takes any drop.
    func expectsDrop(at point: CGPoint) -> Bool {
        if let window = options.window, window.isVisible, window.frame.contains(point) { return true }
        return menuView.acceptsCurrentDrop
    }

    // MARK: Internals

    private func prepareForNewSession(mode newMode: Mode) {
        options.close()
        thumbnailTask?.cancel()
        dropRingTimeout?.cancel()
        promises = []
        mode = newMode
        panel.allowsKeyboard = newMode != .drag
        menuView.dropZone = nil
    }

    private func endSession() {
        kind = nil
        input = WheelInput()
        entries = []
        promises = []
        panel.allowsKeyboard = false
        mode = .drag
    }

    private func present(kind requested: WheelKind, input newInput: WheelInput, at point: CGPoint) {
        input = newInput
        let resolved = provider.resolve(newInput, kind: requested, preferences: preferences)
        kind = resolved.kind
        entries = resolved.entries
        idleText = resolved.note ?? WheelHub.idleText(for: newInput)
        menuView.menuTitle = resolved.kind.title
        var hub = WheelHub.immediate(for: newInput)
        hub.idleText = idleText
        menuView.hub = hub
        menuView.setItems(WheelContentProvider.items(for: entries, cloud: cloud), animated: false)
        panel.show(at: point)
        if let note = resolved.note { menuView.announce("\(note). \(resolved.kind.title)") }
        onKindChange?(resolved.kind)
        loadThumbnail()
    }

    private func loadThumbnail() {
        thumbnailTask?.cancel()
        guard let url = input.urls.first, Formats.detect(url) != Formats.folder else { return }
        let side = WheelTheme.configuration.thumbnailSize
        let scale = panel.backingScaleFactor
        thumbnailTask = Task { @MainActor [weak self] in
            guard let image = await WheelHub.thumbnail(for: url, side: side, scale: scale) else { return }
            guard !Task.isCancelled, let self, self.input.urls.first == url, self.isVisible else { return }
            var hub = self.menuView.hub
            hub.image = image
            self.menuView.hub = hub
        }
    }

    func entry(for itemID: String) -> WheelEntry? {
        entries.first { $0.id == itemID }
    }

    /// Runs a selection: Pro gate, confirmation animation, then `onSelect`.
    private func commit(_ entry: WheelEntry, urls: [URL], promises: [NSFilePromiseReceiver], at point: CGPoint,
                        options chosen: OptionValues? = nil) {
        if cloud.intercept(entry) {
            hide(animated: true)
            return
        }
        let selection: WheelSelection
        switch entry {
        case .convert(let target): selection = .convert(target, options: chosen ?? rememberedOptions[target.format])
        case .tool(let tool): selection = .tool(tool)
        case .action(let action): selection = .action(action)
        }
        options.close()
        thumbnailTask?.cancel()
        let handler = onSelect
        panel.confirmDrop(at: point)
        endSession()
        handler?(selection, urls, promises, point)
    }

    private func applyOptions(target: RouteTarget, values: OptionValues) {
        rememberedOptions[target.format] = values
        guard let entry = entry(for: WheelEntry.convert(target).id) else { return }
        commit(entry, urls: input.urls, promises: promises, at: panel.wheelCenterOnScreen, options: values)
    }

    /// Files dropped on the options popover mid-drag: keep them and let the user adjust.
    private func dropOnOptions(_ info: NSDraggingInfo) -> Bool {
        let (urls, received) = WheelController.files(from: info)
        if !urls.isEmpty { input = WheelInput(urls: urls) }
        promises = received
        mode = .selection
        panel.allowsKeyboard = true
        activateApp()
        options.makeInteractive()
        return true
    }

    private func panelResignedKey() {
        guard mode == .selection, isVisible else { return }
        // Focus moving to our own options popover is fine; anything else cancels.
        Task { @MainActor [weak self] in
            guard let self, self.isVisible, self.mode == .selection else { return }
            let key = NSApp.keyWindow
            if key === self.panel || (key != nil && key === self.options.window) { return }
            self.cancel()
        }
    }

    private func cancel() {
        let wasKeyboard = mode != .drag
        hide(animated: true)
        if wasKeyboard && activatedApp {
            activatedApp = false
            NSApp.deactivate() // hand focus back to Finder
        }
        onCancel?()
    }

    private func activateApp() {
        activatedApp = true
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    static func files(from info: NSDraggingInfo) -> ([URL], [NSFilePromiseReceiver]) {
        let pb = info.draggingPasteboard
        let urls = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        // Real files win; promises only when nothing on disk was offered (Mail, Photos).
        let promises = urls.isEmpty ? ((pb.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil)
            as? [NSFilePromiseReceiver]) ?? []) : []
        return (urls, promises)
    }

    private func screenPoint(_ info: NSDraggingInfo) -> CGPoint {
        panel.convertPoint(toScreen: info.draggingLocation)
    }

    private func optionsEdge(forItemID id: String) -> NSRectEdge {
        guard let index = menuView.items.firstIndex(where: { $0.id == id }),
              let slot = menuView.radialLayout.slotIndex(forItem: index) else { return .maxX }
        return WheelOptionsPopover.edge(forClockAngle: menuView.radialLayout.slots[slot].midAngle)
    }
}

// MARK: - RadialMenuViewDelegate

extension WheelController: RadialMenuViewDelegate {
    public func radialMenu(_ menu: RadialMenuView, didHighlight item: RadialItem?) {
        // Moving to another segment closes its options; leaving the wheel (toward the popover) doesn't.
        if let item, options.isShown, options.itemID != item.id, mode == .drag { options.close() }
    }

    public func radialMenu(_ menu: RadialMenuView, didActivate item: RadialItem) {
        guard let entry = entry(for: item.id) else { return }
        commit(entry, urls: input.urls, promises: promises, at: panel.wheelCenterOnScreen)
    }

    public func radialMenu(_ menu: RadialMenuView, didDrop info: NSDraggingInfo, on item: RadialItem) -> Bool {
        guard let entry = entry(for: item.id) else { return false }
        if CloudSegments.isCloud(entry), cloud.intercept(entry) {
            // Nothing happens to the file: the drop is refused and the explainer shows.
            hide(animated: true)
            return false
        }
        let (urls, received) = WheelController.files(from: info)
        commit(entry, urls: urls.isEmpty ? input.urls : urls, promises: received, at: screenPoint(info))
        return true
    }

    public func radialMenu(_ menu: RadialMenuView, didDropOnEmptyRing info: NSDraggingInfo) -> Bool {
        let (urls, received) = WheelController.files(from: info)
        let types = received.flatMap { $0.fileTypes.compactMap { UTType($0) } }
        guard !urls.isEmpty || !types.isEmpty else { return false }
        dropRingTimeout?.cancel()
        promises = received
        let newInput = WheelInput(urls: urls, promisedTypes: urls.isEmpty ? types : [])
        // Become the convert wheel in place, then take keys so arrows/Return work.
        Task { @MainActor [weak self] in
            guard let self, self.mode == .dropRing else { return }
            self.input = newInput
            let resolved = self.provider.resolve(newInput, kind: .convert, preferences: self.preferences)
            self.kind = resolved.kind
            self.entries = resolved.entries
            self.idleText = resolved.note ?? WheelHub.idleText(for: newInput)
            var hub = WheelHub.immediate(for: newInput)
            hub.idleText = self.idleText
            self.menuView.dropZone = nil
            self.menuView.hub = hub
            self.menuView.menuTitle = resolved.kind.title
            self.menuView.setItems(WheelContentProvider.items(for: self.entries, cloud: self.cloud), animated: false)
            self.menuView.playOpenAnimation()
            self.panel.position(animated: true)
            self.activateApp()
            self.panel.makeKeyAndOrderFront(nil)
            self.panel.makeFirstResponder(self.menuView)
            self.menuView.highlightItem(at: self.entries.isEmpty ? nil : 0, animated: false)
            self.menuView.announce(resolved.kind.title)
            self.onKindChange?(resolved.kind)
            self.loadThumbnail()
        }
        return true
    }

    public func radialMenu(_ menu: RadialMenuView, presetsFor item: RadialItem) -> [RadialPreset] {
        guard mode == .drag, case .convert(let target)? = entry(for: item.id), !target.schema.specs.isEmpty else { return [] }
        var chips = presetStore.presets(for: target.format).prefix(2).map { RadialPreset(id: $0.id, title: $0.title) }
        if presetStore.lastUsed(for: target.format) != nil {
            chips.append(RadialPreset(id: Self.lastUsedPresetID,
                                      title: String(localized: "Last used", comment: "Preset chip: the options used most recently for this format")))
        }
        return chips
    }

    public func radialMenu(_ menu: RadialMenuView, didDrop info: NSDraggingInfo, on item: RadialItem,
                           target dropTarget: RadialDropTarget) -> Bool {
        guard let entry = entry(for: item.id), case .convert(let target) = entry else {
            return radialMenu(menu, didDrop: info, on: item)
        }
        switch dropTarget {
        case .item:
            return radialMenu(menu, didDrop: info, on: item)
        case .preset(_, let presetID):
            guard let values = presetValues(presetID, format: target.format) else { return radialMenu(menu, didDrop: info, on: item) }
            let (urls, received) = WheelController.files(from: info)
            presetStore.recordLastUsed(values, for: target.format)
            commit(entry, urls: urls.isEmpty ? input.urls : urls, promises: received, at: screenPoint(info), options: values)
            return true
        case .tune:
            let (urls, received) = WheelController.files(from: info)
            tune(target, urls: urls.isEmpty ? input.urls : urls, promises: received, at: screenPoint(info), confirm: true)
            return true
        }
    }

    public func radialMenu(_ menu: RadialMenuView, didRequestTuneFor item: RadialItem) {
        guard case .convert(let target)? = entry(for: item.id) else { return }
        tune(target, urls: input.urls, promises: promises, at: panel.wheelCenterOnScreen, confirm: false)
    }

    /// Values for a chip: a stored preset, or the last options used.
    func presetValues(_ id: String, format: FormatID) -> OptionValues? {
        if id == Self.lastUsedPresetID { return presetStore.lastUsed(for: format) }
        return presetStore.presets(for: format).first { $0.id == id }?.values
    }

    private func tune(_ target: RouteTarget, urls: [URL], promises received: [NSFilePromiseReceiver], at point: CGPoint, confirm: Bool) {
        let handler = onTune
        options.close()
        thumbnailTask?.cancel()
        if confirm {
            panel.confirmDrop(at: point)
            endSession()
        } else {
            hide(animated: true)
        }
        handler?(target, urls, received, point)
    }

    public func radialMenuDidCancel(_ menu: RadialMenuView) {
        cancel()
    }

    public func radialMenu(_ menu: RadialMenuView, didRequestNextMenu forward: Bool) {
        guard let kind else { return }
        switchKind(forward ? kind.next : kind.previous)
    }

    public func radialMenu(_ menu: RadialMenuView, hasOptionsFor item: RadialItem) -> Bool {
        guard case .convert(let target)? = entry(for: item.id) else { return false }
        return !target.schema.specs.isEmpty
    }

    public func radialMenu(_ menu: RadialMenuView, didRequestOptionsFor item: RadialItem, anchor: NSRect) {
        guard case .convert(let target)? = entry(for: item.id) else { return }
        if options.isShown && options.itemID == item.id { return }
        let values = rememberedOptions[target.format] ?? target.schema.defaults
        options.show(target: target, itemID: item.id, values: values, interactive: mode != .drag, cloud: cloud,
                     relativeTo: anchor, of: menu, edge: optionsEdge(forItemID: item.id))
    }
}
