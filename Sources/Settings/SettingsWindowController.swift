import AppKit
import SwiftUI
import AnyfmtCore

/// The Settings window: an AppKit window with a `.preference` toolbar (one
/// selectable item per pane), SwiftUI panes inside. No SwiftUI `Settings`
/// scene and no private selectors, so it behaves the same on macOS 13–27.
///
/// Single instance: always go through `SettingsWindowController.show(_:)`.
@MainActor
final class SettingsWindowController: NSWindowController, NSToolbarDelegate, NSWindowDelegate {
    /// Wired by the app delegate before the first `show`.
    static var hooks = SettingsHooks()
    private static var instance: SettingsWindowController?

    /// Opens Settings (creating it once), on `pane` or the last pane used.
    static func show(_ pane: SettingsPane? = nil) {
        let controller = instance ?? SettingsWindowController(model: SettingsModel(hooks: hooks))
        instance = controller
        controller.present(pane)
    }

    static var isVisible: Bool { instance?.window?.isVisible ?? false }

    let model: SettingsModel
    private(set) var pane: SettingsPane
    private var hosts: [SettingsPane: NSHostingController<AnyView>] = [:]
    private var sizeObservation: NSKeyValueObservation?
    private let container = NSView()
    /// Snapshot renders (docs/screens) set this before the first pane loads.
    var isSnapshot = false

    init(model: SettingsModel, pane: SettingsPane? = nil) {
        self.model = model
        self.pane = pane ?? model.lastPane
        let window = AnyfmtWindow(contentRect: NSRect(x: 0, y: 0, width: self.pane.width, height: 400),
                                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true)
        window.title = self.pane.title
        window.toolbarStyle = .preference
        // Near-black in dark (the hero), white in light: the token window surface.
        window.backgroundColor = .anyfmt(DesignTokens.Semantic.windowBackground)
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = container
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenNone)
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        super.init(window: window)
        window.delegate = self

        let toolbar = NSToolbar(identifier: "\(Brand.slug).settings")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func present(_ requested: SettingsPane?) {
        select(requested ?? pane, animate: window?.isVisible ?? false)
        guard let window else { return }
        if !window.isVisible { window.center() }
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Panes

    func select(_ newPane: SettingsPane, animate: Bool) {
        guard let window else { return }
        let changed = newPane != pane || container.subviews.isEmpty
        pane = newPane
        model.lastPane = newPane
        window.title = newPane.title
        window.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(newPane.rawValue)
        guard changed else { return }

        let host = hostingController(for: newPane)
        let old = container.subviews
        host.view.frame = container.bounds
        host.view.autoresizingMask = [.width, .height]
        container.addSubview(host.view)

        sizeObservation = host.observe(\.preferredContentSize, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, self.pane == newPane, self.window?.isVisible == true else { return }
                self.resize(to: self.contentSize(for: newPane), animate: true)
            }
        }

        let target = contentSize(for: newPane)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animate && !reduceMotion {
            host.view.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.allowsImplicitAnimation = true
                old.forEach { $0.animator().alphaValue = 0 }
                host.view.animator().alphaValue = 1
                resize(to: target, animate: true)
            } completionHandler: {
                MainActor.assumeIsolated { old.forEach { $0.removeFromSuperview(); $0.alphaValue = 1 } }
            }
        } else {
            old.forEach { $0.removeFromSuperview() }
            resize(to: target, animate: false)
        }
        window.recalculateKeyViewLoop()
    }

    private func hostingController(for pane: SettingsPane) -> NSHostingController<AnyView> {
        if let h = hosts[pane] { return h }
        let root = AnyView(
            SettingsPaneRoot(pane: pane, model: model)
                .snapshotActiveAppearance()
                .environment(\.isSnapshot, isSnapshot)
        )
        let h = NSHostingController(rootView: root)
        h.sizingOptions = [.preferredContentSize]
        hosts[pane] = h
        return h
    }

    /// Fixed panes use their fixed size; others fit their content, capped to the screen.
    private func contentSize(for pane: SettingsPane) -> NSSize {
        if let h = pane.fixedHeight { return NSSize(width: pane.width, height: h) }
        let host = hostingController(for: pane)
        var height = host.preferredContentSize.height
        if height < 50 { height = host.view.fittingSize.height }
        let screen = window?.screen ?? NSScreen.main
        let titleAndToolbar = (window?.frame.height ?? 0) - (window?.contentLayoutRect.height ?? 0)
        let maxHeight = (screen?.visibleFrame.height ?? 900) - max(titleAndToolbar, 80) - 40
        return NSSize(width: pane.width, height: min(max(height, 200), maxHeight).rounded())
    }

    /// Keeps the top-left corner fixed, like every Mac preferences window.
    private func resize(to content: NSSize, animate: Bool) {
        guard let window else { return }
        let newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
        var frame = window.frame
        frame.origin.y += frame.height - newFrame.height
        frame.size = newFrame.size
        guard frame != window.frame else { return }
        if animate {
            window.animator().setFrame(frame, display: true)
        } else {
            window.setFrame(frame, display: true)
        }
    }

    // MARK: NSToolbarDelegate

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map { NSToolbarItem.Identifier($0.rawValue) }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = SettingsPane(rawValue: id.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = pane.title
        item.paletteLabel = pane.title
        item.toolTip = pane.title
        item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        item.isBordered = false
        return item
    }

    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let pane = SettingsPane(rawValue: sender.itemIdentifier.rawValue) else { return }
        select(pane, animate: true)
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Take the pane out of the window so its onDisappear runs (tap-test
        // monitor, permission polling). `present` puts it back.
        sizeObservation = nil
        container.subviews.forEach { $0.removeFromSuperview() }
        model.loginItem.refresh()
    }
}

/// Root of one pane: fixed width, anyfmt's cobalt switch style. Menus, focus
/// rings and list selection keep the person's own system accent, as every
/// Mac Settings window does; anyfmt's own controls (switches, sliders, pills)
/// carry the cobalt.
private struct SettingsPaneRoot: View {
    let pane: SettingsPane
    let model: SettingsModel

    var body: some View {
        content
            .toggleStyle(AnyfmtSwitchStyle())
            .scrollContentBackground(.hidden)
            .background(Color.anyfmtWindow)
            .frame(width: pane.width)
            .frame(height: pane.fixedHeight)
    }

    @ViewBuilder private var content: some View {
        switch pane {
        case .general: GeneralPane(model: model)
        case .keys: KeysPane(model: model)
        case .output: OutputPane(model: model)
        case .formats: FormatsPane(model: model)
        case .engines: EnginesPane(model: model)
        case .account: AccountPane(model: model)
        case .advanced: AdvancedPane(model: model)
        }
    }
}
