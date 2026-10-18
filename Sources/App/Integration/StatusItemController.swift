import AppKit
import HaloCore

/// The menu bar item: our template glyph and a short, native menu (BUILD.md §9).
/// Order: the wheel, the shelf and recent conversions first; Settings, the
/// account, updates and About next; Quit last. Every item carries a template
/// SF Symbol so the column lines up. Holding ⌥ while opening reveals the
/// hidden Wheel Gallery and Welcome items.
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

        // What you came for first: the wheel, the shelf, what you just made.
        add(String(localized: "Open Wheel for Finder Selection"), #selector(openWheel), key: "", symbol: "circle.circle")
        add(actions.isFloatVisible() ? String(localized: "Hide Float Shelf") : String(localized: "Show Float Shelf"),
            #selector(toggleFloat), key: "", symbol: "tray")
        menu.addItem(recentsItem())

        menu.addItem(.separator())
        add(String(localized: "Settings…"), #selector(openSettings), key: ",", symbol: "gearshape")
        add(String(localized: "Pro Licence & Account…", comment: "Menu bar item opening Settings › Account"),
            #selector(openActivation), key: "", symbol: "person.crop.circle")
        if actions.checkForUpdates != nil && actions.canCheckForUpdates() {
            add(String(localized: "Check for Updates…"), #selector(checkUpdates), key: "", symbol: "arrow.down.circle")
        }
        add(String(localized: "About \(Brand.name)"), #selector(openAbout), key: "", symbol: "info.circle")
        if optionHeld {
            menu.addItem(.separator())
            add(String(localized: "Wheel Gallery"), #selector(openGallery), key: "", symbol: "square.grid.2x2")
            add(String(localized: "Show Welcome…"), #selector(openOnboarding), key: "", symbol: "hand.wave")
        }
        menu.addItem(.separator())
        add(String(localized: "Quit \(Brand.name)"), #selector(NSApplication.terminate(_:)), key: "q", symbol: "power", target: NSApp)
    }

    /// Recent Conversions ▸ newest first, each with its file's icon; choosing one shows it in Finder.
    private func recentsItem() -> NSMenuItem {
        let recentsItem = NSMenuItem(title: String(localized: "Recent Conversions"), action: nil, keyEquivalent: "")
        recentsItem.image = symbol("clock.arrow.circlepath")
        let sub = NSMenu()
        let recents = actions.recents()
        if recents.isEmpty {
            let none = NSMenuItem(title: String(localized: "Nothing converted yet"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        } else {
            sub.addItem(sectionHeader(String(localized: "Show in Finder")))
            for (i, r) in recents.prefix(10).enumerated() {
                let mi = NSMenuItem(title: r.title, action: #selector(revealRecent(_:)), keyEquivalent: "")
                mi.target = self
                mi.tag = i
                mi.toolTip = r.urls.map { ($0.path as NSString).abbreviatingWithTildeInPath }.joined(separator: "\n")
                if let first = r.urls.first { mi.image = icon(for: first) }
                sub.addItem(mi)
            }
        }
        recentsItem.submenu = sub
        return recentsItem
    }

    /// A disabled label item (macOS 14 has `NSMenuItem.sectionHeader`; this works on 13 too).
    private func sectionHeader(_ title: String) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        mi.isEnabled = false
        return mi
    }

    @discardableResult
    private func add(_ title: String, _ action: Selector, key: String, symbol name: String? = nil,
                     target: AnyObject? = nil) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
        mi.target = target ?? self
        if let name { mi.image = symbol(name) }
        menu.addItem(mi)
        return mi
    }

    /// A menu-sized template symbol: the menu tints it, so it follows the
    /// appearance, the selection highlight and Increased Contrast.
    private func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(scale: .medium))
        image?.isTemplate = true
        return image
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
