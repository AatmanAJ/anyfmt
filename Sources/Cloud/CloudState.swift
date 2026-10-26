import Foundation
import AnyfmtCore

/// A browser sign-in the user started: the PKCE verifier and CSRF state we
/// must see again in the callback. Lives in memory only.
struct CloudPendingSignIn: Sendable, Equatable {
    let server: URL
    let state: String
    let verifier: String
    let startedAt: Date

    func isExpired(now: Date = Date()) -> Bool {
        now.timeIntervalSince(startedAt) > CloudConfig.pendingSignInLifetime
    }
}

/// Everything the network gate needs to decide, in one Sendable value.
struct CloudSnapshot: Sendable, Equatable {
    var server: URL
    var credentials: CloudCredentials?
    var account: CloudAccount?
    var syncEnabled: Bool
    var inboxEnabled: Bool
    var pendingSignIn: CloudPendingSignIn?
    var signingIn = false
    /// Last human error from a background step (e.g. finishing sign-in), for the UI.
    var lastError: String?
    /// The stored offline licence (`LicenceStore.connect(to:)`), active or not;
    /// `entitlements` folds it in only while it's in date.
    var licence: LicenceEntitlements? = nil

    var isSignedIn: Bool { credentials != nil }

    var entitlements: CloudEntitlements {
        let base: CloudEntitlements = isSignedIn
            ? account?.entitlements ?? CloudEntitlements(isSignedIn: true, plan: .free, features: [], quotas: .none, customDomains: [])
            : .signedOut
        return base.merging(licence)
    }
}

/// Thread-safe shared state for the whole cloud stack. The main-actor
/// `CloudSession` mirrors it for SwiftUI; background services read it.
final class CloudState: Sendable {
    private let box: CloudLocked<CloudSnapshot>
    private let observers = CloudLocked<[UUID: @Sendable (CloudSnapshot) -> Void]>([:])

    init(_ initial: CloudSnapshot) {
        box = CloudLocked(initial)
    }

    var snapshot: CloudSnapshot { box.current }

    /// Mutates under the lock, then notifies observers (outside the lock) if anything changed.
    func update(_ body: (inout CloudSnapshot) -> Void) {
        let (before, after) = box.withLock { s -> (CloudSnapshot, CloudSnapshot) in
            let old = s
            body(&s)
            return (old, s)
        }
        guard before != after else { return }
        for o in observers.current.values { o(after) }
    }

    @discardableResult
    func observe(_ block: @escaping @Sendable (CloudSnapshot) -> Void) -> UUID {
        let id = UUID()
        observers.withLock { $0[id] = block }
        return id
    }

    func removeObserver(_ id: UUID) {
        observers.withLock { $0[id] = nil }
    }
}

/// Persisted, non-secret cloud preferences (UserDefaults). Tokens never go here.
final class CloudPreferences: @unchecked Sendable {
    // UserDefaults is thread-safe; @unchecked because older SDKs don't mark it Sendable.
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let server = "cloud.serverURL"
        static let syncEnabled = "cloud.syncEnabled"
        static let inboxEnabled = "cloud.inboxEnabled"
        static let inboxFolder = "cloud.inboxFolder"
        static let inboxInterval = "cloud.inboxIntervalMinutes"
        static let noticeServers = "cloud.uploadNotice.acknowledged"
        static func account(_ server: URL) -> String { "cloud.account.\(CloudServerAddress.accountKey(for: server))" }
        static func sync(_ scope: String) -> String { "cloud.sync.state.\(scope)" }
        static func delivered(_ scope: String) -> String { "cloud.inbox.delivered.\(scope)" }
    }

    var serverURL: URL {
        get {
            guard let s = defaults.string(forKey: Key.server), case .success(let url) = CloudServerAddress.parse(s) else {
                return CloudConfig.defaultServer
            }
            return url
        }
        set {
            if CloudServerAddress.isDefault(newValue) { defaults.removeObject(forKey: Key.server) }
            else { defaults.set(newValue.absoluteString, forKey: Key.server) }
        }
    }

    /// Off until the user turns it on.
    var syncEnabled: Bool {
        get { defaults.bool(forKey: Key.syncEnabled) }
        set { defaults.set(newValue, forKey: Key.syncEnabled) }
    }

    /// Off until the user turns it on.
    var inboxEnabled: Bool {
        get { defaults.bool(forKey: Key.inboxEnabled) }
        set { defaults.set(newValue, forKey: Key.inboxEnabled) }
    }

    var inboxFolder: URL {
        get {
            if let path = defaults.string(forKey: Key.inboxFolder), !path.isEmpty { return URL(fileURLWithPath: path, isDirectory: true) }
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        }
        set { defaults.set(newValue.path, forKey: Key.inboxFolder) }
    }

    var inboxIntervalMinutes: Int {
        get {
            let v = defaults.integer(forKey: Key.inboxInterval)
            return v > 0 ? v : CloudConfig.inboxDefaultIntervalMinutes
        }
        set { defaults.set(max(1, newValue), forKey: Key.inboxInterval) }
    }

    func hasAcknowledgedUploadNotice(for server: URL) -> Bool {
        (defaults.stringArray(forKey: Key.noticeServers) ?? []).contains(CloudServerAddress.accountKey(for: server))
    }

    func acknowledgeUploadNotice(for server: URL) {
        var list = defaults.stringArray(forKey: Key.noticeServers) ?? []
        let key = CloudServerAddress.accountKey(for: server)
        guard !list.contains(key) else { return }
        list.append(key)
        defaults.set(list, forKey: Key.noticeServers)
    }

    func cachedAccount(for server: URL) -> CloudAccount? {
        guard let data = defaults.data(forKey: Key.account(server)) else { return nil }
        return try? JSONDecoder().decode(CloudAccount.self, from: data)
    }

    func setCachedAccount(_ account: CloudAccount?, for server: URL) {
        if let account, let data = try? JSONEncoder().encode(account) {
            defaults.set(data, forKey: Key.account(server))
        } else {
            defaults.removeObject(forKey: Key.account(server))
        }
    }

    func syncState(scope: String) -> [String: CloudSyncBase] {
        guard let data = defaults.data(forKey: Key.sync(scope)) else { return [:] }
        return (try? JSONDecoder().decode([String: CloudSyncBase].self, from: data)) ?? [:]
    }

    func setSyncState(_ state: [String: CloudSyncBase], scope: String) {
        if state.isEmpty { defaults.removeObject(forKey: Key.sync(scope)); return }
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Key.sync(scope)) }
    }

    func deliveredInboxItems(scope: String) -> [String] {
        defaults.stringArray(forKey: Key.delivered(scope)) ?? []
    }

    func setDeliveredInboxItems(_ ids: [String], scope: String) {
        defaults.set(Array(ids.suffix(500)), forKey: Key.delivered(scope))
    }
}

/// What this Mac last agreed with the server about one sync document.
struct CloudSyncBase: Codable, Sendable, Equatable {
    var version: Int
    var hash: String
}
