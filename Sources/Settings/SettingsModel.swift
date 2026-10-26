import AppKit
import SwiftUI
import AnyfmtCore

/// The panes of the Settings window, in toolbar order.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, keys, output, formats, engines, account, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General", comment: "Settings pane")
        case .keys: String(localized: "Keys", comment: "Settings pane")
        case .output: String(localized: "Output", comment: "Settings pane")
        case .formats: String(localized: "Formats", comment: "Settings pane")
        case .engines: String(localized: "Engines", comment: "Settings pane")
        case .account: String(localized: "Account", comment: "Settings pane")
        case .advanced: String(localized: "Advanced", comment: "Settings pane")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .keys: "keyboard"
        case .output: "tray.and.arrow.down"
        case .formats: "circle.hexagongrid"
        case .engines: "shippingbox"
        case .account: "person.crop.circle"
        case .advanced: "slider.horizontal.3"
        }
    }

    /// Content width. Height follows the content, except for fixed panes.
    var width: CGFloat {
        switch self {
        case .formats: 780
        default: 620
        }
    }

    /// Panes with long lists scroll inside a fixed height.
    var fixedHeight: CGFloat? {
        switch self {
        case .formats: 560
        default: nil
        }
    }
}

/// Everything the panes read and write. One per Settings window.
@MainActor
final class SettingsModel: ObservableObject {
    let settings: AppSettings
    let hooks: SettingsHooks
    let loginItem: LaunchAtLogin
    let coach: PermissionsCoach
    let info: AppInfo
    /// Formats pane: Formats or Tools list (kept while the window lives).
    @Published var formatsTab: FormatsPane.Tab = .formats

    init(settings: AppSettings = .shared, hooks: SettingsHooks = SettingsHooks(),
         loginItem: LaunchAtLogin = .shared, coach: PermissionsCoach = .shared, info: AppInfo = .main) {
        self.settings = settings
        self.hooks = hooks
        self.loginItem = loginItem
        self.coach = coach
        self.info = info
    }

    /// Router over the engines available right now (rows may be empty until
    /// the engine lanes are merged; the Formats pane copes).
    private(set) lazy var router: Router = Router.live()

    var triggers: TriggerAssignment {
        TriggerAssignment(convert: TriggerKey.parse(settings.convertKey, fallback: .shift),
                          tools: TriggerKey.parse(settings.toolsKey, fallback: .command),
                          actions: TriggerKey.parse(settings.actionsKey, fallback: .control))
    }

    /// Assigns a key to a wheel; the wheel that had it takes the old key.
    func assign(_ key: TriggerKey, to role: TriggerRole) {
        var t = triggers
        t.assign(key, to: role)
        apply(t)
    }

    func apply(_ t: TriggerAssignment) {
        if settings.convertKey != t[.convert].rawValue { settings.convertKey = t[.convert].rawValue }
        if settings.toolsKey != t[.tools].rawValue { settings.toolsKey = t[.tools].rawValue }
        if settings.actionsKey != t[.actions].rawValue { settings.actionsKey = t[.actions].rawValue }
        hooks.onTriggerKeysChanged?()
    }

    func resetAll() {
        settings.resetAll()
        hooks.onTriggerKeysChanged?()
        hooks.onUpdateChecksChanged?(settings.updateChecksEnabled)
        hooks.onFinderShortcutChanged?(settings.finderShortcutEnabled)
    }

    // MARK: UI state (not a user setting; see docs/contract-changes/P-ui.md)

    private static let lastPaneKey = "ui.settings.lastPane"

    var lastPane: SettingsPane {
        get { SettingsPane(rawValue: settings.defaults.string(forKey: Self.lastPaneKey) ?? "") ?? .general }
        set { settings.defaults.set(newValue.rawValue, forKey: Self.lastPaneKey) }
    }
}

/// Version strings and bundle facts, injectable for screenshots and tests.
struct AppInfo: Sendable {
    var version: String
    var build: String
    var bundleID: String
    /// Host of the Sparkle feed, shown in the honest one-liner.
    var updateHost: String?
    var helpersURL: URL?

    static var main: AppInfo {
        let b = Bundle.main
        let feed = (b.object(forInfoDictionaryKey: "SUFeedURL") as? String).flatMap(URL.init(string:))
        // A placeholder feed (".invalid") isn't a real host; say "the update server" instead.
        let host = feed?.host.flatMap { $0.hasSuffix(".invalid") ? nil : $0 }
        return AppInfo(version: b.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0",
                       build: b.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
                       bundleID: b.bundleIdentifier ?? Brand.bundleID,
                       updateHost: host,
                       helpersURL: b.bundleURL.appendingPathComponent("Contents/Helpers", isDirectory: true))
    }

    /// "Checks updates.example.com daily. Nothing else is sent."
    var updateLine: String {
        let host = updateHost ?? String(localized: "the \(Brand.name) update server")
        return String(localized: "Checks \(host) daily. Nothing else is sent.")
    }
}
