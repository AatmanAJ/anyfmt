import Foundation
import HaloCore

/// Files sent from a phone or browser land in a folder on this Mac.
///
/// Polls only while signed in, entitled **and** the user turned the inbox
/// on (off by default); every `inboxIntervalMinutes` (default 5, never
/// faster than the server's `pollIntervalSeconds`). Each item is downloaded
/// to a temp file, verified against its SHA-256, moved into the folder under
/// a collision-safe name (`name 2.ext`), then acknowledged. Disabled → no
/// requests, no UI.
actor InboxService {
    private let state: CloudState
    private let client: CloudAPIClient
    private let preferences: CloudPreferences
    private let intervalOverride: Duration?
    private var loop: Task<Void, Never>?
    private var loopID: UUID?
    private var observer: (@Sendable (Date?, [URL]) -> Void)?

    private(set) var lastCheck: Date?
    private(set) var lastDelivered: [URL] = []
    private(set) var lastError: String?

    init(state: CloudState, client: CloudAPIClient, preferences: CloudPreferences, interval: Duration? = nil) {
        self.state = state
        self.client = client
        self.preferences = preferences
        self.intervalOverride = interval
    }

    func setObserver(_ observer: (@Sendable (Date?, [URL]) -> Void)?) { self.observer = observer }

    var isEligible: Bool {
        let s = state.snapshot
        return s.isSignedIn && s.inboxEnabled && s.entitlements.can(.inbox)
    }

    var isPolling: Bool { loop != nil }

    var interval: Duration {
        if let intervalOverride { return intervalOverride }
        let minutes = preferences.inboxIntervalMinutes
        let floor = state.snapshot.entitlements.quotas.pollIntervalSeconds ?? 0
        return .seconds(max(minutes * 60, floor))
    }

    /// Starts or stops the poller to match the current state. Call on any change.
    func refreshSchedule() {
        if isEligible { start() } else { stop() }
    }

    func start() {
        guard loop == nil, isEligible else { return }
        let id = UUID()
        loopID = id
        loop = Task { [weak self] in await self?.runLoop(id) }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        loopID = nil
    }

    private func runLoop(_ id: UUID) async {
        while !Task.isCancelled {
            guard isEligible else { break }
            _ = try? await checkNow()
            try? await Task.sleep(for: interval)
        }
        // Only clear our own handle; a newer loop may have replaced it.
        if loopID == id {
            loop = nil
            loopID = nil
        }
    }

    /// Downloads pending items now ("Check now", and each poll). Returns the files placed.
    @discardableResult
    func checkNow() async throws -> [URL] {
        guard isEligible else { return [] }
        let folder = preferences.inboxFolder
        var placed: [URL] = []
        do {
            let items = try await client.inbox()
            guard let scope = scope else { return [] }
            var delivered = preferences.deliveredInboxItems(scope: scope)
            if !items.isEmpty { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
            for item in items {
                try Task.checkCancellation()
                if delivered.contains(item.id) {
                    // Saved last time but the ack didn't arrive: ack again, never save twice.
                    try? await client.ackInbox(item.id, sha256: item.sha256)
                    continue
                }
                guard let out = try await save(item, into: folder) else { continue }
                placed.append(out)
                delivered.append(item.id)
                preferences.setDeliveredInboxItems(delivered, scope: scope)
                do { try await client.ackInbox(item.id, sha256: item.sha256) } catch {
                    Log.cloud.info("inbox ack will be retried next check")
                }
            }
            lastError = nil
        } catch {
            lastError = (error as? CloudError)?.errorDescription ?? error.localizedDescription
            lastCheck = Date()
            observer?(lastCheck, placed)
            throw error
        }
        lastCheck = Date()
        lastDelivered = placed
        if !placed.isEmpty { Log.cloud.info("inbox delivered \(placed.count) file(s)") }
        observer?(lastCheck, placed)
        return placed
    }

    private var scope: String? {
        let s = state.snapshot
        guard let user = s.account?.userID else { return nil }
        return "\(CloudServerAddress.accountKey(for: s.server))|\(user)"
    }

    private func save(_ item: CloudInboxItem, into folder: URL) async throws -> URL? {
        let name = CloudFileName.sanitize(item.name, fallback: String(localized: "Inbox item"))
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Brand.slug)-inbox-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let temp = staging.appendingPathComponent(name)
        try await client.download(item.downloadUrl, to: temp, trigger: .inbox)
        guard try CloudHash.sha256(of: temp) == item.sha256.lowercased() else {
            Log.cloud.error("inbox item failed its checksum; will retry")
            return nil
        }
        let (base, ext) = CloudFileName.split(name)
        return try OutputNamer.place(temp, in: folder, base: base, ext: ext)
    }
}
