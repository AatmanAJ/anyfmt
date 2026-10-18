import XCTest
import HaloCore
@testable import HaloApp

/// Browser sign-in with PKCE against the mock server, token refresh,
/// sign-out, server URL handling.
@MainActor
final class CloudAuthTests: MockServerTestCase {
    func testSignInViaSimulatedCallbackLoadsEntitlements() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        let s = f.services

        s.session.signIn()
        guard let authorize = f.browser.opened.current.first,
              let comps = URLComponents(url: authorize, resolvingAgainstBaseURL: false) else { return XCTFail("browser not opened") }
        let q = Dictionary(uniqueKeysWithValues: (comps.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(comps.path, "/v1/auth/authorize")
        XCTAssertEqual(q["response_type"], "code")
        XCTAssertEqual(q["client_id"], "\(Brand.slug)-mac")
        XCTAssertEqual(q["redirect_uri"], "\(Brand.urlScheme)://auth/callback")
        XCTAssertEqual(q["code_challenge_method"], "S256")
        XCTAssertEqual(q["code_challenge"]?.count, 43)
        XCTAssertGreaterThanOrEqual(q["state"]?.count ?? 0, 16)
        XCTAssertNil(q["email"], "no personal data in the URL")
        // Opening the browser is not a request from the app.
        let before = try await mock.requestCount()
        XCTAssertEqual(before, 0)
        s.session.refreshFromState()
        XCTAssertEqual(s.session.status, .waitingForBrowser)

        // The browser follows the magic link; macOS hands the callback to the app delegate.
        let callback = try await f.browserCallbackURL(for: authorize)
        XCTAssertTrue(s.handleCallback(callback))
        try await waitUntil("signed in") { s.state.snapshot.account != nil }

        let snap = s.state.snapshot
        XCTAssertTrue(snap.isSignedIn)
        XCTAssertNil(snap.pendingSignIn)
        XCTAssertEqual(snap.account?.email, "aj@example.com")
        XCTAssertEqual(s.entitlements.plan, .pro)
        XCTAssertTrue(s.entitlements.can(.cloudJobs))
        XCTAssertTrue(s.entitlements.can(.transcription))
        XCTAssertFalse(s.entitlements.can(.shareLinkCustomDomain), "custom domains are Team-only")
        XCTAssertNotNil(try f.secrets.read(account: CloudServerAddress.accountKey(for: mock.baseURL)), "tokens in the store")

        s.session.refreshFromState()
        XCTAssertEqual(s.session.status, .signedIn)
        XCTAssertEqual(s.session.plan, .pro)
        XCTAssertEqual(s.session.email, "aj@example.com")

        // The authorize page was the (simulated) browser; the app itself sent exactly two requests.
        let paths = try await mock.requests().compactMap { $0["path"] as? String }
        XCTAssertEqual(paths, ["/v1/auth/authorize", "/v1/auth/token", "/v1/me"])
        let appRequests = try await mock.requests().filter { ($0["userAgent"] as? String ?? "").hasSuffix("(macOS)") }
        XCTAssertEqual(appRequests.compactMap { $0["path"] as? String }, ["/v1/auth/token", "/v1/me"])
    }

    func testFreePlanEntitlements() async throws {
        try await mock.setUser(plan: "free")
        let f = try fixture()
        let account = try await f.signIn()
        let e = account.entitlements
        XCTAssertTrue(e.isSignedIn)
        XCTAssertEqual(e.plan, .free)
        XCTAssertTrue(e.can(.shareLink))
        for feature in [CloudFeature.cloudJobs, .sync, .inbox, .transcription, .upscale, .backgroundRemovalHQ, .shareLinkCustomDomain] {
            XCTAssertFalse(e.can(feature), "\(feature)")
        }
        XCTAssertEqual(e.remainingShareLinks, 5)
        XCTAssertEqual(e.quotas.shareLinkMaxExpiryHours, 72)
        XCTAssertNotNil(e.usageLine)
    }

    func testTeamPlanGetsCustomDomains() async throws {
        try await mock.setUser(plan: "team", customDomains: ["files.example.com"])
        let f = try fixture()
        let e = try await f.signIn().entitlements
        XCTAssertEqual(e.plan, .team)
        XCTAssertTrue(e.can(.shareLinkCustomDomain))
        XCTAssertEqual(e.customDomains, ["files.example.com"])
        XCTAssertNil(e.remainingShareLinks, "unlimited")
    }

    func testCallbackWithWrongStateIsRejectedWithoutARequest() async throws {
        let f = try fixture()
        f.services.session.signIn()
        guard let authorize = f.browser.opened.current.first else { return XCTFail() }
        let real = try await f.browserCallbackURL(for: authorize)
        var comps = try XCTUnwrap(URLComponents(url: real, resolvingAgainstBaseURL: false))
        comps.queryItems = comps.queryItems?.map { $0.name == "state" ? URLQueryItem(name: "state", value: "forged-state-value-123") : $0 }
        let forged = try XCTUnwrap(comps.url)
        try await mock.clearRequests()
        do {
            _ = try await f.services.auth.completeSignIn(callbackURL: forged)
            XCTFail("forged state accepted")
        } catch CloudError.signInFailed {}
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0, "no token exchange for a forged callback")
        XCTAssertFalse(f.state.snapshot.isSignedIn)
        // The real one still works.
        _ = try await f.services.auth.completeSignIn(callbackURL: real)
        XCTAssertTrue(f.state.snapshot.isSignedIn)
    }

    func testDeniedCallbackEndsTheAttempt() async throws {
        let f = try fixture()
        f.services.session.signIn()
        let pending = try XCTUnwrap(f.state.snapshot.pendingSignIn)
        let denied = try XCTUnwrap(URL(string: "\(Brand.urlScheme)://auth/callback?error=access_denied&state=\(pending.state)"))
        do { _ = try await f.services.auth.completeSignIn(callbackURL: denied); XCTFail() } catch CloudError.signInFailed {}
        XCTAssertNil(f.state.snapshot.pendingSignIn)
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testCodeTypedFromAnotherDevice() async throws {
        let f = try fixture()
        f.services.session.signIn()
        guard let authorize = f.browser.opened.current.first else { return XCTFail() }
        let callback = try await f.browserCallbackURL(for: authorize)
        let code = try XCTUnwrap(URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "code" }?.value)
        let account = try await f.services.auth.completeSignIn(code: "  \(code)\n")
        XCTAssertEqual(account.email, "aj@example.com")
    }

    func testAuthorizationCodeIsSingleUse() async throws {
        let f = try fixture()
        f.services.session.signIn()
        guard let authorize = f.browser.opened.current.first else { return XCTFail() }
        let callback = try await f.browserCallbackURL(for: authorize)
        _ = try await f.services.auth.completeSignIn(callbackURL: callback)
        // Replaying the same callback later: there's no pending sign-in, so nothing is sent.
        await XCTAssertThrowsAsync(try await f.services.auth.completeSignIn(callbackURL: callback))
    }

    func testExpiredAccessTokenRefreshesOnceAndRetries() async throws {
        let f = try fixture()
        try await f.signIn()
        let before = try XCTUnwrap(f.state.snapshot.credentials)
        try await mock.call("POST", "/__mock/expire-tokens")
        try await mock.clearRequests()

        _ = try await f.services.client.me(trigger: .user)

        let log = try await mock.requests().map { "\($0["method"] ?? "") \($0["path"] ?? "") \($0["status"] ?? "")" }
        XCTAssertEqual(log, ["GET /v1/me 401", "POST /v1/auth/token 200", "GET /v1/me 200"])
        let after = try XCTUnwrap(f.state.snapshot.credentials)
        XCTAssertNotEqual(before.accessToken, after.accessToken)
        XCTAssertNotEqual(before.refreshToken, after.refreshToken, "refresh tokens rotate")
        let stored = try XCTUnwrap(f.services.vault.load(for: mock.baseURL))
        XCTAssertEqual(stored, after, "rotated tokens persisted")
    }

    func testConcurrentRequestsShareOneRefresh() async throws {
        let f = try fixture()
        try await f.signIn()
        try await mock.call("POST", "/__mock/expire-tokens")
        try await mock.clearRequests()
        let client = f.services.client
        async let a = client.me(trigger: .user)
        async let b = client.me(trigger: .user)
        async let c = client.me(trigger: .user)
        _ = try await (a, b, c)
        let refreshes = try await mock.requestCount("POST", prefix: "/v1/auth/token")
        XCTAssertEqual(refreshes, 1)
    }

    func testRevokedSessionSignsOutLocally() async throws {
        let f = try fixture()
        try await f.signIn()
        // Another device signed this one out: the refresh token is gone server-side.
        let creds = try XCTUnwrap(f.state.snapshot.credentials)
        var req = URLRequest(url: mock.baseURL.appendingPathComponent("/v1/auth/revoke"))
        req.httpMethod = "POST"
        req.httpBody = Data("token=\(creds.refreshToken)".utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        _ = try await URLSession(configuration: .ephemeral).data(for: req)

        do { _ = try await f.services.client.me(trigger: .user); XCTFail() } catch CloudError.sessionExpired {}
        XCTAssertFalse(f.state.snapshot.isSignedIn)
        XCTAssertNil(f.services.vault.load(for: mock.baseURL))
        XCTAssertEqual(f.state.snapshot.lastError, CloudError.sessionExpired.errorDescription)
    }

    func testSignOutClearsKeychainAndRevokes() async throws {
        let keychain = KeychainStore(service: "\(Brand.bundleID).cloud.tests.\(UUID().uuidString)")
        defer { try? keychain.deleteAll() }
        let f = try fixture(secrets: keychain)
        try await f.signIn()
        let account = CloudServerAddress.accountKey(for: mock.baseURL)
        XCTAssertEqual(try keychain.accounts(), [account])
        XCTAssertNotNil(try keychain.read(account: account))
        try await mock.clearRequests()

        await f.services.session.signOut()

        XCTAssertEqual(try keychain.accounts(), [], "keychain item removed")
        XCTAssertFalse(f.state.snapshot.isSignedIn)
        XCTAssertNil(f.services.preferences.cachedAccount(for: mock.baseURL))
        let paths = try await mock.requests().compactMap { $0["path"] as? String }
        XCTAssertEqual(paths, ["/v1/auth/revoke"])
        let server = try await mock.call("GET", "/__mock/state") as? [String: Any]
        XCTAssertEqual(server?["refreshTokens"] as? Int, 0, "refresh token revoked on the server")
        // Signed out again: a second sign-out makes no request.
        try await mock.clearRequests()
        await f.services.session.signOut()
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testSignInSurvivesRelaunch() async throws {
        let keychain = KeychainStore(service: "\(Brand.bundleID).cloud.tests.\(UUID().uuidString)")
        defer { try? keychain.deleteAll() }
        let f = try fixture(secrets: keychain)
        try await f.signIn()
        try await mock.clearRequests()
        // A new CloudServices on the same defaults + keychain = the next launch.
        var env = CloudServices.Environment()
        env.secrets = keychain
        env.defaults = try XCTUnwrap(UserDefaults(suiteName: f.defaultsSuite))
        env.consent = ScriptedConsent()
        env.ledgerDirectory = nil
        let relaunched = CloudServices(environment: env)
        XCTAssertTrue(relaunched.state.snapshot.isSignedIn)
        XCTAssertEqual(relaunched.entitlements.plan, .pro, "cached plan, no request at launch")
        let count = try await mock.requestCount()
        XCTAssertEqual(count, 0)
    }

    func testLogsNeverContainSecrets() async throws {
        let f = try fixture()
        try await f.signIn()
        try await mock.call("POST", "/__mock/expire-tokens")
        _ = try await f.services.client.me(trigger: .user)
        let creds = try XCTUnwrap(f.state.snapshot.credentials)
        let lines = f.logLines.current
        XCTAssertFalse(lines.isEmpty)
        for line in lines {
            XCTAssertFalse(line.contains(creds.accessToken))
            XCTAssertFalse(line.contains(creds.refreshToken))
            XCTAssertFalse(line.contains("Bearer"))
            XCTAssertFalse(line.contains("code="))
            XCTAssertFalse(line.contains("?"), "query strings are never logged: \(line)")
        }
        XCTAssertEqual(String(describing: creds), "CloudCredentials(redacted)")
    }

    // MARK: Server URL

    func testValidateServerAgainstMock() async throws {
        let f = try fixture()
        await f.services.session.validateServer(mock.baseURL.absoluteString)
        XCTAssertEqual(f.services.session.serverCheck, .ok(name: "Halo Mock"))
        await f.services.session.validateServer("http://example.com")
        guard case .failed = f.services.session.serverCheck else { return XCTFail("plain http to another host must be refused") }
        await f.services.session.validateServer("")
        guard case .failed = f.services.session.serverCheck else { return XCTFail() }
    }

    func testChangingServerKeepsSignInsPerServer() async throws {
        let f = try fixture()
        try await f.signIn()
        let s = f.services.session
        XCTAssertTrue(s.setServer("https://halo.example.org"))
        XCTAssertFalse(f.state.snapshot.isSignedIn, "no account on the new server")
        XCTAssertEqual(f.services.preferences.serverURL.absoluteString, "https://halo.example.org")
        XCTAssertTrue(s.setServer(mock.baseURL.absoluteString))
        XCTAssertTrue(f.state.snapshot.isSignedIn, "back on the mock: still signed in there")
        s.resetServerToDefault()
        XCTAssertTrue(CloudServerAddress.isDefault(f.state.snapshot.server))
        XCTAssertFalse(s.setServer("ftp://nope"))
    }

    func testServerAddressParsing() {
        func parse(_ s: String) -> String? { try? CloudServerAddress.parse(s).get().absoluteString }
        XCTAssertEqual(parse("cloud.example.com"), "https://cloud.example.com")
        XCTAssertEqual(parse(" https://Cloud.Example.com/ "), "https://cloud.example.com")
        XCTAssertEqual(parse("https://example.com/halo/"), "https://example.com/halo")
        XCTAssertEqual(parse("http://localhost:8787"), "http://localhost:8787")
        XCTAssertEqual(parse("http://127.0.0.1:9"), "http://127.0.0.1:9")
        XCTAssertNil(parse("http://example.com"), "plain http off this Mac")
        XCTAssertNil(parse("https://example.com/?a=1"))
        XCTAssertNil(parse("https://user:pw@example.com"))
        XCTAssertNil(parse(""))
        XCTAssertEqual(CloudServerAddress.accountKey(for: URL(string: "https://example.com:8443/halo")!), "example.com:8443/halo")
        XCTAssertEqual(CloudServerAddress.origin(of: URL(string: "https://example.com/x")!), "https://example.com:443")
        XCTAssertNotEqual(CloudServerAddress.origin(of: URL(string: "http://localhost:5/")!),
                          CloudServerAddress.origin(of: URL(string: "http://127.0.0.1:5/")!))
    }

    func testPKCE() {
        let v = CloudPKCE.makeVerifier()
        XCTAssertEqual(v.count, 43)
        XCTAssertNil(v.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
        // RFC 7636 appendix B test vector.
        XCTAssertEqual(CloudPKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        XCTAssertNotEqual(CloudPKCE.makeVerifier(), CloudPKCE.makeVerifier())
        XCTAssertTrue(CloudAuth.constantTimeEquals("abc", "abc"))
        XCTAssertFalse(CloudAuth.constantTimeEquals("abc", "abd"))
        XCTAssertFalse(CloudAuth.constantTimeEquals("abc", "abcd"))
    }
}
