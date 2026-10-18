import AppKit
import CryptoKit
import Security
import SystemConfiguration
import HaloCore

/// RFC 7636 helpers.
enum CloudPKCE {
    static func randomURLSafe(bytes: Int = 32) -> String {
        var data = Data(count: bytes)
        let status = data.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, bytes, base)
        }
        if status != errSecSuccess {
            // SecRandomCopyBytes doesn't fail in practice; the system CSPRNG is the fallback.
            var rng = SystemRandomNumberGenerator()
            data = Data((0..<bytes).map { _ in UInt8.random(in: 0...255, using: &rng) })
        }
        return base64URL(data)
    }

    /// 43-character verifier from 32 random bytes.
    static func makeVerifier() -> String { randomURLSafe(bytes: 32) }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Opens the sign-in page. Injectable so tests act as the browser.
protocol CloudBrowserOpening: Sendable {
    @MainActor func open(_ url: URL)
}

struct CloudWorkspaceBrowser: CloudBrowserOpening {
    @MainActor func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

/// Browser sign-in: OAuth 2.0 authorization code + PKCE, returning to the
/// app through `<scheme>://auth/callback`. See docs/lanes/I-cloud.md for why
/// this beats passkeys / Sign in with Apple for an app that must work with
/// any self-hosted server.
final class CloudAuth: Sendable {
    private let state: CloudState
    private let client: CloudAPIClient
    private let vault: CloudCredentialVault
    private let preferences: CloudPreferences
    private let browser: any CloudBrowserOpening

    init(state: CloudState, client: CloudAPIClient, vault: CloudCredentialVault, preferences: CloudPreferences,
         browser: any CloudBrowserOpening = CloudWorkspaceBrowser()) {
        self.state = state
        self.client = client
        self.vault = vault
        self.preferences = preferences
        self.browser = browser
    }

    /// Creates a fresh PKCE pair + state and returns the page to open. No request is made.
    func prepareAuthorization() -> URL? {
        let server = state.snapshot.server
        let pending = CloudPendingSignIn(server: server, state: CloudPKCE.randomURLSafe(bytes: 24),
                                         verifier: CloudPKCE.makeVerifier(), startedAt: Date())
        guard var comps = URLComponents(url: server, resolvingAgainstBaseURL: false) else { return nil }
        comps.path += "/v1/auth/authorize"
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: CloudConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: CloudConfig.redirectURI),
            URLQueryItem(name: "code_challenge", value: CloudPKCE.challenge(for: pending.verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: pending.state),
        ]
        guard let url = comps.url else { return nil }
        state.update {
            $0.pendingSignIn = pending
            $0.lastError = nil
        }
        return url
    }

    /// "Sign in…": opens the server's sign-in page in the default browser.
    @MainActor
    @discardableResult
    func start() -> URL? {
        guard let url = prepareAuthorization() else {
            state.update { $0.lastError = CloudError.signInFailed("").errorDescription }
            return nil
        }
        Log.cloud.info("opening browser sign-in for \(CloudServerAddress.displayName(for: self.state.snapshot.server), privacy: .public)")
        browser.open(url)
        return url
    }

    func cancelPendingSignIn() {
        state.update { $0.pendingSignIn = nil; $0.signingIn = false }
    }

    /// True for `<scheme>://auth/callback…`.
    static func isCallback(_ url: URL) -> Bool {
        url.scheme?.lowercased() == Brand.urlScheme.lowercased() && url.host?.lowercased() == "auth" && url.path == "/callback"
    }

    /// For the app delegate's `application(_:open:)`. Returns true if the URL
    /// was ours; finishing sign-in continues in the background and lands in
    /// `CloudState` (signed in, or `lastError`).
    @discardableResult
    func handleCallback(_ url: URL) -> Bool {
        guard Self.isCallback(url) else { return false }
        Task {
            do { _ = try await self.completeSignIn(callbackURL: url) } catch {
                let message = (error as? CloudError)?.errorDescription ?? error.localizedDescription
                self.state.update { $0.lastError = message; $0.signingIn = false }
            }
        }
        return true
    }

    /// Validates the callback against the pending sign-in, then exchanges the code.
    func completeSignIn(callbackURL url: URL) async throws -> CloudAccount {
        guard Self.isCallback(url), let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CloudError.signInFailed("")
        }
        let items = Dictionary(comps.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { a, _ in a })
        guard let pending = state.snapshot.pendingSignIn, !pending.isExpired() else {
            // A stale or foreign callback. Nothing to redeem it with, so no request.
            throw CloudError.signInFailed(String(localized: "This sign-in link is from an earlier attempt. Start again from Settings."))
        }
        guard let returned = items["state"], Self.constantTimeEquals(returned, pending.state) else {
            throw CloudError.signInFailed(String(localized: "This sign-in link didn’t match. Start again from Settings."))
        }
        if let err = items["error"], !err.isEmpty {
            cancelPendingSignIn()
            throw CloudError.signInFailed(err == "access_denied" ? String(localized: "Sign-in was cancelled.") : "")
        }
        guard let code = items["code"], !code.isEmpty else { throw CloudError.signInFailed("") }
        return try await redeem(code: code, pending: pending)
    }

    /// For a link opened on another device: the page shows the code, the user types it here.
    func completeSignIn(code: String) async throws -> CloudAccount {
        guard let pending = state.snapshot.pendingSignIn, !pending.isExpired() else {
            throw CloudError.signInFailed(String(localized: "Start signing in again, then enter the new code."))
        }
        return try await redeem(code: code.trimmingCharacters(in: .whitespacesAndNewlines), pending: pending)
    }

    private func redeem(code: String, pending: CloudPendingSignIn) async throws -> CloudAccount {
        state.update { $0.signingIn = true }
        do {
            let creds = try await client.exchange(code: code, verifier: pending.verifier, server: pending.server,
                                                  deviceName: Self.deviceName())
            try vault.save(creds, for: pending.server)
            state.update {
                $0.credentials = creds
                $0.pendingSignIn = nil
            }
            let account = CloudAccount(try await client.me(trigger: .signIn))
            preferences.setCachedAccount(account, for: pending.server)
            state.update {
                $0.account = account
                $0.signingIn = false
                $0.lastError = nil
            }
            Log.cloud.info("signed in (plan \(account.entitlements.plan.rawValue, privacy: .public))")
            return account
        } catch {
            state.update { $0.signingIn = false }
            throw error
        }
    }

    /// Fetches `/v1/me` for the signed-in user (an explicit refresh or the start of a cloud action).
    @discardableResult
    func refreshAccount(trigger: CloudTrigger = .user) async throws -> CloudAccount {
        let server = state.snapshot.server
        let account = CloudAccount(try await client.me(trigger: trigger))
        preferences.setCachedAccount(account, for: server)
        state.update { if CloudServerAddress.isSame($0.server, server) { $0.account = account } }
        return account
    }

    /// Clears the Keychain item and local state first (instant), then asks
    /// the server to revoke the refresh token. Signed out already → no request.
    func signOut() async {
        let snap = state.snapshot
        let server = snap.server
        vault.remove(for: server)
        preferences.setCachedAccount(nil, for: server)
        state.update {
            $0.credentials = nil
            $0.account = nil
            $0.pendingSignIn = nil
            $0.signingIn = false
            $0.lastError = nil
        }
        guard let creds = snap.credentials else { return }
        do { try await client.revoke(refreshToken: creds.refreshToken, server: server) } catch {
            Log.cloud.info("revoke didn't reach the server; the token expires on its own")
        }
    }

    static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in x.indices { diff |= x[i] ^ y[i] }
        return diff == 0
    }

    /// Shown only in the account's device list.
    static func deviceName() -> String {
        (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? "Mac"
    }
}
