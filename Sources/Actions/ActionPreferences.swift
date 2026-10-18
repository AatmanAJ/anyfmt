import Foundation
import CoreGraphics
import HaloCore

/// Preferences for the Control-wheel actions, stored in `UserDefaults`.
/// Inject a suite (`UserDefaults(suiteName:)`) in tests.
///
/// Stored keys (all under `actions.`):
/// - `actions.terminal.bundleID`: the terminal the Terminal action opens.
/// - `actions.move.recentFolders`: Move destinations, most recent first, max 8.
/// - `actions.float.origin`: where the user last left the Float shelf.
@MainActor
public final class ActionPreferences: ObservableObject {
    public static let shared = ActionPreferences()

    public static let maxRecentFolders = 8
    public static let defaultTerminalBundleID = TerminalApp.terminal.bundleID

    enum Key {
        static let terminal = "actions.terminal.bundleID"
        static let recentFolders = "actions.move.recentFolders"
        static let shelfOrigin = "actions.float.origin"
    }

    private let defaults: UserDefaults
    private let isDirectory: (URL) -> Bool

    /// - Parameters:
    ///   - defaults: backing store.
    ///   - isDirectory: decides whether a recent folder still exists (injectable for tests).
    public init(defaults: UserDefaults = .standard,
                isDirectory: @escaping (URL) -> Bool = ActionPreferences.directoryExists) {
        self.defaults = defaults
        self.isDirectory = isDirectory
        self.terminalBundleID = defaults.string(forKey: Key.terminal) ?? Self.defaultTerminalBundleID
    }

    // MARK: Terminal

    /// Bundle identifier of the terminal to open. Defaults to Terminal.app.
    @Published public var terminalBundleID: String {
        didSet { defaults.set(terminalBundleID, forKey: Key.terminal) }
    }

    // MARK: Recent Move destinations

    /// Most recent first, at most `maxRecentFolders`, only folders that still
    /// exist. Reading prunes missing folders from the stored list.
    public var recentFolders: [URL] {
        let stored = storedRecentPaths
        let alive = stored.filter { isDirectory(URL(fileURLWithPath: $0, isDirectory: true)) }
        if alive.count != stored.count {
            defaults.set(alive, forKey: Key.recentFolders)
        }
        return alive.prefix(Self.maxRecentFolders).map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Records `folder` as the most recent destination (moving it to the front
    /// if it was already listed) and trims the list to `maxRecentFolders`.
    public func noteRecentFolder(_ folder: URL) {
        let path = Self.normalizedPath(folder)
        var list = storedRecentPaths.filter { !Self.samePath($0, path) }
        list.insert(path, at: 0)
        objectWillChange.send()
        defaults.set(Array(list.prefix(Self.maxRecentFolders)), forKey: Key.recentFolders)
    }

    public func removeRecentFolder(_ folder: URL) {
        let path = Self.normalizedPath(folder)
        objectWillChange.send()
        defaults.set(storedRecentPaths.filter { !Self.samePath($0, path) }, forKey: Key.recentFolders)
    }

    public func clearRecentFolders() {
        objectWillChange.send()
        defaults.removeObject(forKey: Key.recentFolders)
    }

    private var storedRecentPaths: [String] {
        defaults.stringArray(forKey: Key.recentFolders) ?? []
    }

    // MARK: Float shelf position

    /// Bottom-left of the shelf card in screen coordinates, if the user has
    /// ever moved it. Nothing else about the shelf persists across launches.
    public var shelfOrigin: CGPoint? {
        get {
            guard let a = defaults.array(forKey: Key.shelfOrigin) as? [Double], a.count == 2 else { return nil }
            return CGPoint(x: a[0], y: a[1])
        }
        set {
            if let p = newValue {
                defaults.set([Double(p.x), Double(p.y)], forKey: Key.shelfOrigin)
            } else {
                defaults.removeObject(forKey: Key.shelfOrigin)
            }
        }
    }

    // MARK: Helpers

    nonisolated public static func directoryExists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    nonisolated static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    /// Same folder, even when one path goes through a symlink (`/tmp` vs `/private/tmp`).
    nonisolated static func samePath(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let ra = URL(fileURLWithPath: a).resolvingSymlinksInPath().path
        let rb = URL(fileURLWithPath: b).resolvingSymlinksInPath().path
        return ra == rb
    }
}
