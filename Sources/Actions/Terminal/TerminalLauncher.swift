import AppKit

/// A terminal app the Terminal action can open, and how to open it at a folder.
/// None of these needs Automation permission (research/PLATFORM_RESEARCH.md §H).
public struct TerminalApp: Hashable, Sendable, Identifiable {
    public enum Launch: Hashable, Sendable {
        /// `NSWorkspace.open([folder], withApplicationAt:)`: the app opens a
        /// shell in that folder (Terminal, iTerm2, Ghostty all declare `public.directory`).
        case openFolder
        /// A URI the app handles, e.g. `warp://action/new_window?path=…`.
        case newWindowURI(scheme: String)
    }

    public let bundleID: String
    /// Product names are proper nouns and are not localised.
    public let name: String
    public let launch: Launch
    public var id: String { bundleID }

    public init(bundleID: String, name: String, launch: Launch) {
        self.bundleID = bundleID
        self.name = name
        self.launch = launch
    }

    /// New window at the folder.
    public static let terminal = TerminalApp(bundleID: "com.apple.Terminal", name: "Terminal", launch: .openFolder)
    /// New session at the folder (window or tab per iTerm2's own preference).
    public static let iTerm2 = TerminalApp(bundleID: "com.googlecode.iterm2", name: "iTerm2", launch: .openFolder)
    /// New **tab** in the front window by default (window if none is open).
    /// There's no public, permission-free way to force a window: Ghostty's
    /// `macos-dock-drop-behavior = new-window` setting makes it a window.
    public static let ghostty = TerminalApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty", launch: .openFolder)
    /// Warp ignores folder opens from NSWorkspace, so use its URI scheme.
    public static let warp = TerminalApp(bundleID: "dev.warp.Warp-Stable", name: "Warp", launch: .newWindowURI(scheme: "warp"))

    /// In the order the picker lists them.
    public static let known: [TerminalApp] = [.terminal, .iTerm2, .ghostty, .warp]

    public static func known(bundleID: String) -> TerminalApp? {
        known.first { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }
    }
}

public struct InstalledTerminal: Hashable, Sendable, Identifiable {
    public let app: TerminalApp
    public let appURL: URL
    public var id: String { app.bundleID }
}

/// What the Terminal action will do, computed without side effects so it can be tested.
public enum TerminalLaunchPlan: Equatable, Sendable {
    case openFolder(URL, withApplicationAt: URL)
    case openURL(URL, withApplicationAt: URL)
}

public enum TerminalLauncher {
    public typealias AppLookup = @MainActor (String) -> URL?

    /// The real lookup: Launch Services by bundle id.
    @MainActor
    public static func systemLookup(_ bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// Known terminals that are installed, in picker order.
    @MainActor
    public static func installed(lookup: AppLookup) -> [InstalledTerminal] {
        TerminalApp.known.compactMap { app in
            lookup(app.bundleID).map { InstalledTerminal(app: app, appURL: $0) }
        }
    }

    /// The chosen terminal if it's installed, else Terminal.app, else nil.
    @MainActor
    public static func resolve(preferred bundleID: String, lookup: AppLookup) -> InstalledTerminal? {
        let installed = installed(lookup: lookup)
        if let match = installed.first(where: { $0.app.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }) {
            return match
        }
        return installed.first { $0.app == .terminal }
    }

    /// The folder to open for these items:
    /// - one folder → that folder; one file (or package such as an .app) → its parent;
    /// - several items → the deepest folder containing all of them (for a
    ///   Finder selection that's the folder you're looking at); if they share
    ///   nothing but the root (different disks), the first item's folder.
    public static func workingFolder(for items: [URL], isFolder: (URL) -> Bool = TerminalLauncher.isPlainFolder) -> URL? {
        let folders = items.map { item -> URL in
            let u = item.standardizedFileURL
            return isFolder(u) ? u : u.deletingLastPathComponent()
        }
        guard let first = folders.first else { return nil }
        var common = first.pathComponents
        for folder in folders.dropFirst() {
            let comps = folder.pathComponents
            var n = 0
            while n < common.count, n < comps.count, common[n] == comps[n] { n += 1 }
            common = Array(common.prefix(n))
        }
        guard common.count > 1 else { return first }
        return URL(fileURLWithPath: NSString.path(withComponents: common), isDirectory: true)
    }

    /// `warp://action/new_window?path=/Users/me/My%20Folder`. Everything but
    /// unreserved characters and `/` is percent-encoded (spaces, `&`, `#`, `+`,
    /// `?`, `%`, Unicode as UTF-8), so the query can't be cut short or misread.
    public static func newWindowURL(scheme: String, folder: URL) -> URL? {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~/")
        guard let encoded = PathFormatter.posixPath(folder).addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "\(scheme)://action/new_window?path=\(encoded)")
    }

    public static func launchPlan(for terminal: InstalledTerminal, folder: URL) -> TerminalLaunchPlan? {
        switch terminal.app.launch {
        case .openFolder:
            return .openFolder(folder, withApplicationAt: terminal.appURL)
        case .newWindowURI(let scheme):
            return newWindowURL(scheme: scheme, folder: folder).map { .openURL($0, withApplicationAt: terminal.appURL) }
        }
    }

    /// Carries out a plan with Launch Services. Opens the terminal in front.
    @MainActor
    public static func execute(_ plan: TerminalLaunchPlan) async throws {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.promptsUserIfNeeded = false
        switch plan {
        case .openFolder(let folder, let app), .openURL(let folder, let app):
            _ = try await NSWorkspace.shared.open([folder], withApplicationAt: app, configuration: config)
        }
    }

    /// A directory that isn't a package (an .app or .rtfd counts as a file).
    public static func isPlainFolder(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else { return false }
        return (values.isDirectory ?? false) && !(values.isPackage ?? false)
    }
}
