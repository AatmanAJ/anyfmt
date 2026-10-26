import Foundation
import AnyfmtCore

/// Composition root for the cloud client. The app creates one
/// (`CloudServices.shared`); tests build their own with an `Environment`
/// pointing at the mock server, a test Keychain service and recording
/// URL protocols.
///
/// Creating it makes **no** network request and no URLSession: the session
/// is created lazily by `CloudAPIClient` on the first request the gate allows.
@MainActor
final class CloudServices {
    struct Environment {
        var secrets: any CloudSecretStore = KeychainStore()
        var defaults: UserDefaults = .standard
        var sessionFactory: any CloudSessionFactory = CloudDefaultSessionFactory()
        var browser: any CloudBrowserOpening = CloudWorkspaceBrowser()
        var consent: (any CloudUploadConsent)?
        var pasteboard: any CloudPasteboardWriting = CloudSystemPasteboard()
        var ledgerDirectory: URL? = CloudUploadLedger.defaultDirectory
        var chunkSize = CloudConfig.uploadChunkSize
        var retry = CloudRetryPolicy.standard
        var syncDebounce = CloudConfig.syncDebounce
        var syncPolicy: [SyncNamespace: SyncSide] = [:]
        var inboxInterval: Duration?
        var jobPollInterval: Duration = .milliseconds(500)
        var logObserver: (@Sendable (String) -> Void)?

        static var live: Environment { Environment() }
    }

    static let shared = CloudServices(environment: .live)

    let state: CloudState
    let preferences: CloudPreferences
    let vault: CloudCredentialVault
    let client: CloudAPIClient
    let auth: CloudAuth
    let uploader: CloudUploader
    let notice: CloudUploadNoticeGate
    let shareLinks: ShareLinkService
    let sync: SyncEngine
    let inbox: InboxService
    let session: CloudSession
    private let jobPollInterval: Duration

    init(environment env: Environment) {
        preferences = CloudPreferences(defaults: env.defaults)
        vault = CloudCredentialVault(store: env.secrets)
        let server = preferences.serverURL
        let creds = vault.load(for: server)
        state = CloudState(CloudSnapshot(
            server: server,
            credentials: creds,
            account: creds == nil ? nil : preferences.cachedAccount(for: server),
            syncEnabled: preferences.syncEnabled,
            inboxEnabled: preferences.inboxEnabled,
            pendingSignIn: nil))
        client = CloudAPIClient(state: state, vault: vault, factory: env.sessionFactory, logObserver: env.logObserver)
        auth = CloudAuth(state: state, client: client, vault: vault, preferences: preferences, browser: env.browser)
        uploader = CloudUploader(client: client, state: state, ledger: CloudUploadLedger(directory: env.ledgerDirectory),
                                 chunkSize: env.chunkSize, retry: env.retry)
        notice = CloudUploadNoticeGate(preferences: preferences, consent: env.consent ?? CloudPanelConsent())
        shareLinks = ShareLinkService(state: state, client: client, auth: auth, uploader: uploader, notice: notice,
                                      pasteboard: env.pasteboard)
        sync = SyncEngine(state: state, client: client, preferences: preferences, policy: env.syncPolicy, debounce: env.syncDebounce)
        inbox = InboxService(state: state, client: client, preferences: preferences, interval: env.inboxInterval)
        session = CloudSession(state: state, preferences: preferences, vault: vault, client: client, auth: auth,
                               sync: sync, inbox: inbox)
        jobPollInterval = env.jobPollInterval
        observeSignInTransitions()
    }

    /// Entitlements for the wheel's cloud segments (Sources/Wheel/CloudSegments.swift).
    var entitlements: CloudEntitlements { state.snapshot.entitlements }

    /// For `NSApplicationDelegate.application(_:open:)`.
    @discardableResult
    func handleCallback(_ url: URL) -> Bool { auth.handleCallback(url) }

    /// The app's local data for sync (`SettingsSyncSource`, set by CloudIntegration.start).
    func setSyncSource(_ source: (any SyncDocumentSource)?) {
        let sync = self.sync
        Task { await sync.setSource(source) }
    }

    /// Local data in `namespace` changed: push it after the debounce (no-op while sync is inactive).
    func noteLocalChange(_ namespace: SyncNamespace) {
        let sync = self.sync
        Task { await sync.noteLocalChange(namespace) }
    }

    /// A job for the normal queue + progress window.
    func makeCloudJob(input: URL, operation: CloudJobOperation) -> CloudJob {
        CloudJob(input: input, operation: operation, dependencies: CloudJobDependencies(
            state: state, client: client, uploader: uploader, notice: notice, minimumPollInterval: jobPollInterval))
    }

    /// Sign-in → pull (if sync is on) and start the inbox (if on). Sign-out → stop both.
    private func observeSignInTransitions() {
        let wasSignedIn = CloudLocked(state.snapshot.isSignedIn && state.snapshot.account != nil)
        let sync = self.sync, inbox = self.inbox
        state.observe { snap in
            let ready = snap.isSignedIn && snap.account != nil
            let changed = wasSignedIn.withLock { old -> Bool in
                defer { old = ready }
                return old != ready
            }
            Task {
                if changed, ready {
                    if snap.syncEnabled { try? await sync.syncNow() }
                } else if changed {
                    await sync.reset()
                }
                await inbox.refreshSchedule()
            }
        }
        if wasSignedIn.current {
            Task { await inbox.refreshSchedule() }
        }
    }
}
