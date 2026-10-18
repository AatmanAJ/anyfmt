import Foundation
import HaloCore

/// The documents the Mac syncs. Raw values are the server namespaces.
enum SyncNamespace: String, CaseIterable, Sendable, Codable {
    case favourites
    case wheelOrder = "wheel-order"
    case presets
    case recipes
    case settings

    var title: String {
        switch self {
        case .favourites: String(localized: "Favourites")
        case .wheelOrder: String(localized: "Wheel order")
        case .presets: String(localized: "Presets")
        case .recipes: String(localized: "Recipes")
        case .settings: String(localized: "Settings")
        }
    }
}

/// The app side of sync. The Settings lane implements this with the real
/// favourites, wheel order, presets, recipes and settings, each as JSON.
protocol SyncDocumentSource: Sendable {
    /// Current local JSON for `namespace`, or nil when there's nothing to sync yet.
    func localDocument(_ namespace: SyncNamespace) async -> Data?
    /// Replace the local data for `namespace` with `data` (JSON from another Mac).
    func applyRemoteDocument(_ data: Data, to namespace: SyncNamespace) async throws
}

enum SyncSide: String, Sendable, Codable {
    /// The copy on the server (written by another Mac).
    case server
    /// This Mac's copy.
    case local
}

/// A conflict the engine resolved by policy, surfaced so the user can flip it.
struct SyncConflictNotice: Identifiable, Sendable, Equatable {
    let id: UUID
    let namespace: SyncNamespace
    let kept: SyncSide
    /// The version that was *not* kept, so "Use the other one" is one click.
    let otherVersion: Data
    let otherDevice: String?
    let date: Date

    var message: String {
        let device = otherDevice ?? String(localized: "another Mac")
        switch kept {
        case .server:
            return String(localized: "\(namespace.title) changed here and on \(device). Kept the version from \(device).")
        case .local:
            return String(localized: "\(namespace.title) changed here and on \(device). Kept this Mac’s version.")
        }
    }
}

/// Syncs namespaced JSON documents with conditional writes (Server/openapi.yaml › sync).
///
/// Runs only while signed in, entitled **and** the user turned sync on
/// (off by default). Pull on sign-in and on demand; push on change,
/// debounced. A conflict (both sides changed since the last agreed version)
/// is resolved by a per-document policy (default: keep the server's copy)
/// and surfaced as a `SyncConflictNotice` with the other version kept for
/// one-click reversal.
actor SyncEngine {
    private let state: CloudState
    private let client: CloudAPIClient
    private let preferences: CloudPreferences
    private let policy: [SyncNamespace: SyncSide]
    private let debounce: Duration
    private let deviceName: String
    private var source: (any SyncDocumentSource)?
    private var pending: [SyncNamespace: Task<Void, Never>] = [:]
    private var observer: (@Sendable ([SyncConflictNotice], Date?) -> Void)?

    private(set) var notices: [SyncConflictNotice] = []
    private(set) var lastSyncedAt: Date?
    private(set) var lastError: String?

    init(state: CloudState, client: CloudAPIClient, preferences: CloudPreferences,
         policy: [SyncNamespace: SyncSide] = [:], debounce: Duration = CloudConfig.syncDebounce,
         deviceName: String = CloudAuth.deviceName()) {
        self.state = state
        self.client = client
        self.preferences = preferences
        self.policy = policy
        self.debounce = debounce
        self.deviceName = deviceName
    }

    func setSource(_ source: (any SyncDocumentSource)?) { self.source = source }

    func setObserver(_ observer: (@Sendable ([SyncConflictNotice], Date?) -> Void)?) { self.observer = observer }

    /// Signed in + entitled + turned on + something to sync with.
    var isActive: Bool {
        let s = state.snapshot
        return s.isSignedIn && s.syncEnabled && s.entitlements.can(.sync) && source != nil
    }

    private var scope: String? {
        let s = state.snapshot
        guard let user = s.account?.userID else { return nil }
        return "\(CloudServerAddress.accountKey(for: s.server))|\(user)"
    }

    // MARK: Public

    /// Pull everything, then push anything changed here. No-op (zero requests) when inactive.
    func syncNow() async throws {
        guard isActive, let source else { return }
        do {
            let heads = try await client.syncIndex()
            for ns in SyncNamespace.allCases {
                try await reconcile(ns, head: heads.first { $0.namespace == ns.rawValue }, source: source)
            }
            lastSyncedAt = Date()
            lastError = nil
            notify()
        } catch {
            lastError = (error as? CloudError)?.errorDescription ?? error.localizedDescription
            notify()
            throw error
        }
    }

    /// Call when local data changes; pushes after the debounce interval.
    func noteLocalChange(_ namespace: SyncNamespace) {
        guard isActive else { return }
        pending[namespace]?.cancel()
        let delay = debounce
        pending[namespace] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.pushIfChanged(namespace)
        }
    }

    /// Waits for debounced pushes (tests, app termination).
    func flush() async {
        let tasks = Array(pending.values)
        for t in tasks { await t.value }
    }

    /// Switch a resolved conflict to the other version.
    func resolve(_ id: UUID, keep side: SyncSide) async throws {
        guard let notice = notices.first(where: { $0.id == id }) else { return }
        guard side != notice.kept else { dismiss(id); return }
        guard isActive, let source, let scope else { throw CloudError.notAllowed("sync is off") }
        let json = try CloudJSON(data: notice.otherVersion)
        try await source.applyRemoteDocument(try json.canonicalData(), to: notice.namespace)
        let base = preferences.syncState(scope: scope)[notice.namespace.rawValue]
        try await write(notice.namespace, json, baseVersion: base?.version, source: source, allowConflictHandling: false)
        dismiss(id)
    }

    func dismiss(_ id: UUID) {
        notices.removeAll { $0.id == id }
        notify()
    }

    /// Sign-out / sync turned off: stop pending pushes, clear notices.
    func reset() {
        for t in pending.values { t.cancel() }
        pending = [:]
        notices = []
        lastError = nil
        notify()
    }

    // MARK: Internals

    private func notify() {
        observer?(notices, lastSyncedAt)
    }

    private func pushIfChanged(_ ns: SyncNamespace) async {
        pending[ns] = nil
        guard isActive, let source, let scope else { return }
        do {
            guard let data = await source.localDocument(ns) else { return }
            let json = try CloudJSON(data: data)
            if let base = preferences.syncState(scope: scope)[ns.rawValue] {
                guard json.canonicalHash() != base.hash else { return }
                try await write(ns, json, baseVersion: base.version, source: source, allowConflictHandling: true)
            } else {
                // Never synced this one here: pull first so we don't clobber another Mac.
                let remote = try await client.syncDocument(ns.rawValue)
                try await reconcile(ns, remote: remote, source: source)
            }
            lastSyncedAt = Date()
            notify()
        } catch {
            lastError = (error as? CloudError)?.errorDescription ?? error.localizedDescription
            Log.cloud.error("sync push failed for \(ns.rawValue, privacy: .public)")
            notify()
        }
    }

    private func reconcile(_ ns: SyncNamespace, head: CloudSyncDocumentHead?, source: any SyncDocumentSource) async throws {
        guard let scope else { return }
        let base = preferences.syncState(scope: scope)[ns.rawValue]
        if head == nil {
            try await reconcile(ns, remote: nil, source: source)
            return
        }
        if let base, let head, head.version == base.version {
            // Server unchanged since we last agreed: push if we changed.
            guard let data = await source.localDocument(ns), let json = try? CloudJSON(data: data) else { return }
            if json.canonicalHash() != base.hash {
                try await write(ns, json, baseVersion: base.version, source: source, allowConflictHandling: true)
            }
            return
        }
        try await reconcile(ns, remote: try await client.syncDocument(ns.rawValue), source: source)
    }

    /// Three-way decision between local, remote and the last agreed base.
    private func reconcile(_ ns: SyncNamespace, remote: CloudSyncDocument?, source: any SyncDocumentSource) async throws {
        guard let scope else { return }
        let base = preferences.syncState(scope: scope)[ns.rawValue]
        let localData = await source.localDocument(ns)
        let local = localData.flatMap { try? CloudJSON(data: $0) }
        let localHash = local?.canonicalHash()

        guard let remote else {
            if let local { try await write(ns, local, baseVersion: nil, source: source, allowConflictHandling: true) }
            return
        }
        let remoteHash = remote.data.canonicalHash()
        if localHash == remoteHash {
            setBase(ns, CloudSyncBase(version: remote.version, hash: remoteHash))
        } else if local == nil || (base != nil && localHash == base?.hash) {
            // Only the server changed: take it.
            try await source.applyRemoteDocument(try remote.data.canonicalData(), to: ns)
            setBase(ns, CloudSyncBase(version: remote.version, hash: remoteHash))
        } else if let local {
            try await conflict(ns, local: local, remote: remote, source: source)
        }
    }

    private func write(_ ns: SyncNamespace, _ json: CloudJSON, baseVersion: Int?, source: any SyncDocumentSource,
                       allowConflictHandling: Bool, depth: Int = 0) async throws {
        // Another Mac writing in a tight loop shouldn't keep us here forever.
        guard depth < 3 else { throw CloudError.server(status: 409, code: "version_conflict", message: nil, requestID: nil) }
        switch try await client.putSyncDocument(ns.rawValue, data: json, baseVersion: baseVersion, deviceName: deviceName) {
        case .stored(let doc):
            setBase(ns, CloudSyncBase(version: doc.version, hash: json.canonicalHash()))
        case .conflict(let current):
            guard let current else {
                // Deleted elsewhere: recreate once.
                if baseVersion != nil {
                    try await write(ns, json, baseVersion: nil, source: source, allowConflictHandling: false, depth: depth + 1)
                }
                return
            }
            if current.data.canonicalHash() == json.canonicalHash() {
                setBase(ns, CloudSyncBase(version: current.version, hash: json.canonicalHash()))
            } else if allowConflictHandling {
                try await conflict(ns, local: json, remote: current, source: source)
            } else {
                try await write(ns, json, baseVersion: current.version, source: source, allowConflictHandling: false, depth: depth + 1)
            }
        }
    }

    private func conflict(_ ns: SyncNamespace, local: CloudJSON, remote: CloudSyncDocument, source: any SyncDocumentSource) async throws {
        let side = policy[ns] ?? .server
        let notice: SyncConflictNotice
        switch side {
        case .server:
            try await source.applyRemoteDocument(try remote.data.canonicalData(), to: ns)
            setBase(ns, CloudSyncBase(version: remote.version, hash: remote.data.canonicalHash()))
            notice = SyncConflictNotice(id: UUID(), namespace: ns, kept: .server, otherVersion: try local.canonicalData(),
                                        otherDevice: remote.updatedBy, date: Date())
        case .local:
            try await write(ns, local, baseVersion: remote.version, source: source, allowConflictHandling: false)
            notice = SyncConflictNotice(id: UUID(), namespace: ns, kept: .local, otherVersion: try remote.data.canonicalData(),
                                        otherDevice: remote.updatedBy, date: Date())
        }
        notices.removeAll { $0.namespace == ns }
        notices.append(notice)
        Log.cloud.info("sync conflict on \(ns.rawValue, privacy: .public), kept \(side.rawValue, privacy: .public)")
        notify()
    }

    private func setBase(_ ns: SyncNamespace, _ base: CloudSyncBase) {
        guard let scope else { return }
        var all = preferences.syncState(scope: scope)
        all[ns.rawValue] = base
        preferences.setSyncState(all, scope: scope)
    }
}
