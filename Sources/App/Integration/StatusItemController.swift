import AppKit
import HaloCore

/// The menu bar item: our template glyph and a short menu (BUILD.md §9).
/// Holding ⌥ while opening reveals the hidden Wheel Gallery item.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    struct Recent { let title: String; let urls: [URL] }

    struct Actions {
        var openWheelForSelection: () -> Void = {}
        var recents: () -> [Recent] = { [] }
        var reveal: ([URL]) -> Void = { NSWorkspace.shared.activateFileViewerSelecting($0) }
        var toggleFloat: () -> Void = {}
        var isFloatVisible: () -> Bool = { false }
        var openSettings: () -> Void = {}
        /// Settings › Account (licence key / sign-in). Optional; never nags.
        var openActivation: () -> Void = {}
        var checkForUpdates: (() -> Void)?
        var canCheckForUpdates: () -> Bool = { false }
        var openAbout: () -> Void = {}
        var openGallery: () -> Void = {}
        var openOnboarding: () -> Void = {}
    }

    private let item: NSStatusItem
    private let menu = NSMenu()
    var actions: Actions

    init(actions: Actions) {
        self.actions = actions
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = item.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
            button.setAccessibilityLabel(Brand.name)
            button.toolTip = Brand.name
        }
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let optionHeld = NSEvent.modifierFlags.contains(.option)

        add(String(localized: "Open Wheel for Finder Selection"), #selector(openWheel), key: "")

        let recentsItem = NSMenuItem(title: String(localized: "Recent Conversions"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let recents = actions.recents()
        if recents.isEmpty {
            let none = NSMenuItem(title: String(localized: "Nothing yet"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        } else {
            for (i, r) in recents.prefix(10).enumerated() {
                let mi = NSMenuItem(title: r.title, action: #selector(revealRecent(_:)), keyEquivalent: "")
                mi.target = self
                mi.tag = i
                mi.toolTip = r.urls.map(\.path).joined(separator: "\n")
                if let first = r.urls.first { mi.image = icon(for: first) }
                sub.addItem(mi)
            }
        }
        recentsItem.submenu = sub
        menu.addItem(recentsItem)

        let floatItem = add(actions.isFloatVisible() ? String(localized: "Hide Float Shelf") : String(localized: "Show Float Shelf"), #selector(toggleFloat), key: "")
        floatItem.image = NSImage(systemSymbolName: "tray.and.arrow.up", accessibilityDescription: nil)

        menu.addItem(.separator())
        add(String(localized: "Settings…"), #selector(openSettings), key: ",")
        add(String(localized: "Pro Licence & Account…", comment: "Menu bar item opening Settings › Account"), #selector(openActivation), key: "")
        if actions.checkForUpdates != nil && actions.canCheckForUpdates() {
            add(String(localized: "Check for Updates…"), #selector(checkUpdates), key: "")
        }
        add(String(localized: "About \(Brand.name)"), #selector(openAbout), key: "")
        if optionHeld {
            menu.addItem(.separator())
            add(String(localized: "Wheel Gallery"), #selector(openGallery), key: "")
            add(String(localized: "Show Welcome…"), #selector(openOnboarding), key: "")
        }
        menu.addItem(.separator())
        add(String(localized: "Quit \(Brand.name)"), #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, key: String, target: AnyObject? = nil) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = target ?? self
        menu.addItem(mi)
        return mi
    }

    private func icon(for url: URL) -> NSImage {
        let i = NSWorkspace.shared.icon(forFile: url.path)
        i.size = NSSize(width: 16, height: 16)
        return i
    }

    @objc private func openWheel() { actions.openWheelForSelection() }
    @objc private func toggleFloat() { actions.toggleFloat() }
    @objc private func openSettings() { actions.openSettings() }
    @objc private func openActivation() { actions.openActivation() }
    @objc private func checkUpdates() { actions.checkForUpdates?() }
    @objc private func openAbout() { actions.openAbout() }
    @objc private func openGallery() { actions.openGallery() }
    @objc private func openOnboarding() { actions.openOnboarding() }
    @objc private func revealRecent(_ sender: NSMenuItem) {
        let recents = actions.recents()
        guard recents.indices.contains(sender.tag) else { return }
        actions.reveal(recents[sender.tag].urls)
    }
}
