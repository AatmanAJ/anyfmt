import Foundation
import Combine
import HaloCore

/// Main-actor mirror of the cloud state for SwiftUI (Settings › Account,
/// the explainer, share-link options). Every method that talks to a server
/// is a direct response to the user pressing something.
@MainActor
final class CloudSession: ObservableObject {
    enum Status: Equatable, Sendable {
        case signedOut
        /// The sign-in page is open in the browser; waiting for the callback.
        case waitingForBrowser
        case signingIn
        case signedIn
    }

    enum ServerCheck: Equatable, Sendable {
        case idle
        case checking
        case ok(name: String)
        case failed(String)
    }

    @Published private(set) var serverURL: URL
    @Published private(set) var status: Status = .signedOut
    @Published private(set) var email: String?
    @Published private(set) var plan: Plan = .free
    @Published private(set) var entitlements: CloudEntitlements = .signedOut
    @Published var lastError: String?
    @Published private(set) var syncEnabled: Bool
    @Published private(set) var inboxEnabled: Bool
    @Published private(set) var inboxFolder: URL
    @Published private(set) var serverCheck: ServerCheck = .idle
    @Published private(set) var syncNotices: [SyncConflictNotice] = []
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastInboxCheck: Date?
    @Published private(set) var isRefreshing = false

    private let state: CloudState
    private let preferences: CloudPreferences
    private let vault: CloudCredentialVault
    private let client: CloudAPIClient
    private let auth: CloudAuth
    private let sync: SyncEngine
    private let inbox: InboxService
    private var observation: UUID?
    private var mirroredStateError: String?

    init(state: CloudState, preferences: CloudPreferences, vault: CloudCredentialVault, client: CloudAPIClient,
         auth: CloudAuth, sync: SyncEngine, inbox: InboxService) {
        self.state = state
        self.preferences = preferences
        self.vault = vault
        self.client = client
        self.auth = auth
        self.sync = sync
        self.inbox = inbox
        let snap = state.snapshot
        serverURL = snap.server
        syncEnabled = snap.syncEnabled
        inboxEnabled = snap.inboxEnabled
        inboxFolder = preferences.inboxFolder
        apply(snap)
        observation = state.observe { [weak self] _ in
            Task { @MainActor in self?.refreshFromState() }
        }
        let syncObserver: @Sendable ([SyncConflictNotice], Date?) -> Void = { [weak self] notices, synced in
            Task { @MainActor in
                self?.syncNotices = notices
                self?.lastSyncedAt = synced
            }
        }
        let inboxObserver: @Sendable (Date?, [URL]) -> Void = { [weak self] checked, _ in
            Task { @MainActor in self?.lastInboxCheck = checked }
        }
        Task {
            await sync.setObserver(syncObserver)
            await inbox.setObserver(inboxObserver)
        }
    }

    /// Re-reads the shared state (always the latest, so out-of-order hops can't regress the UI).
    func refreshFromState() { apply(state.snapshot) }

    private func apply(_ s: CloudSnapshot) {
        if serverURL != s.server { serverURL = s.server }
        let newStatus: Status
        if s.signingIn { newStatus = .signingIn }
        else if s.isSignedIn { newStatus = .signedIn }
        else if s.pendingSignIn != nil { newStatus = .waitingForBrowser }
        else { newStatus = .signedOut }
        if status != newStatus { status = newStatus }
        let mail = s.isSignedIn ? s.account?.email : nil
        if email != mail { email = mail }
        let e = s.entitlements
        if entitlements != e { entitlements = e }
        if plan != e.plan { plan = e.plan }
        if syncEnabled != s.syncEnabled { syncEnabled = s.syncEnabled }
        if inboxEnabled != s.inboxEnabled { inboxEnabled = s.inboxEnabled }
        // Background steps (finishing sign-in, a revoked session) report through the
        // shared state; mirror changes so a fixed problem also clears in the UI.
        if s.lastError != mirroredStateError {
            mirroredStateError = s.lastError
            lastError = s.lastError
        }
    }

    var isSignedIn: Bool { status == .signedIn }
    var inboxIntervalMinutes: Int { preferences.inboxIntervalMinutes }
    var serverDisplayName: String { CloudServerAddress.displayName(for: serverURL) }
    var isDefaultServer: Bool { CloudServerAddress.isDefault(serverURL) }

    // MARK: Account

    /// "Sign in…": opens the browser. No request from the app.
    func signIn() {
        lastError = nil
        auth.start()
    }

    func cancelSignIn() {
        auth.cancelPendingSignIn()
    }

    /// For the app delegate: `application(_:open:)` → `handleCallback(url)`.
    @discardableResult
    func handleCallback(_ url: URL) -> Bool {
        auth.handleCallback(url)
    }

    /// Code typed by the user when the magic link was opened on another device.
    func completeSignIn(code: String) async {
        do { _ = try await auth.completeSignIn(code: code) } catch { report(error) }
    }

    func signOut() async {
        await sync.reset()
        await inbox.stop()
        await auth.signOut()
        syncNotices = []
        lastError = nil
    }

    /// The small refresh button beside the usage line.
    func refreshAccount() async {
        guard isSignedIn else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do { try await auth.refreshAccount(trigger: .user) } catch { report(error) }
    }

    // MARK: Server

    /// The "Validate" button: `GET /v1/health` on the typed address. User-initiated only.
    func validateServer(_ text: String) async {
        switch CloudServerAddress.parse(text) {
        case .failure(let problem):
            serverCheck = .failed(problem.message)
        case .success(let url):
            serverCheck = .checking
            do {
                let health = try await client.health(server: url)
                guard health.api == "1" else {
                    serverCheck = .failed(String(localized: "That server speaks a different version of the \(Brand.name) API."))
                    return
                }
                serverCheck = .ok(name: health.name ?? CloudServerAddress.displayName(for: url))
            } catch {
                serverCheck = .failed((error as? CloudError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    /// Saves a new server address. Sign-ins are per server, so this shows
    /// whatever account is stored for the new one (often: signed out).
    @discardableResult
    func setServer(_ text: String) -> Bool {
        guard case .success(let url) = CloudServerAddress.parse(text) else {
            if case .failure(let p) = CloudServerAddress.parse(text) { serverCheck = .failed(p.message) }
            return false
        }
        switchServer(to: url)
        return true
    }

    func resetServerToDefault() {
        switchServer(to: CloudConfig.defaultServer)
    }

    private func switchServer(to url: URL) {
        guard !CloudServerAddress.isSame(url, state.snapshot.server) else { return }
        preferences.serverURL = url
        let creds = vault.load(for: url)
        let account = creds == nil ? nil : preferences.cachedAccount(for: url)
        state.update {
            $0.server = url
            $0.credentials = creds
            $0.account = account
            $0.pendingSignIn = nil
            $0.signingIn = false
            $0.lastError = nil
        }
        serverCheck = .idle
        let sync = self.sync, inbox = self.inbox
        Task {
            await sync.reset()
            await inbox.refreshSchedule()
        }
    }

    // MARK: Sync + inbox

    func setSyncEnabled(_ on: Bool) {
        preferences.syncEnabled = on
        state.update { $0.syncEnabled = on }
        let sync = self.sync
        Task { [weak self] in
            if on {
                do { try await sync.syncNow() } catch { self?.report(error) }
            } else {
                await sync.reset()
            }
        }
    }

    func syncNow() async {
        do { try await sync.syncNow() } catch { report(error) }
    }

    func resolveSyncNotice(_ notice: SyncConflictNotice, keep side: SyncSide) async {
        do { try await sync.resolve(notice.id, keep: side) } catch { report(error) }
    }

    func dismissSyncNotice(_ notice: SyncConflictNotice) async {
        await sync.dismiss(notice.id)
    }

    func setInboxEnabled(_ on: Bool) {
        preferences.inboxEnabled = on
        state.update { $0.inboxEnabled = on }
        let inbox = self.inbox
        Task { await inbox.refreshSchedule() }
    }

    func setInboxFolder(_ url: URL) {
        preferences.inboxFolder = url
        inboxFolder = url
    }

    func checkInboxNow() async {
        do { try await inbox.checkNow() } catch { report(error) }
    }

    private func report(_ error: Error) {
        if error is CancellationError { return }
        lastError = (error as? CloudError)?.errorDescription ?? error.localizedDescription
    }
}
