import XCTest
import AnyfmtCore
@testable import AnyfmtApp

/// "Local is sacred": signed out, every public cloud entry point makes zero
/// requests, and the URLSession isn't even created. Verified with a
/// recording URLProtocol on the injected configuration, a second one
/// registered globally, and a session-counting factory.
@MainActor
final class CloudGateTests: XCTestCase {
    private var fixture: CloudFixture!
    private var factory: RecordingSessionFactory!

    override func setUp() async throws {
        try await super.setUp()
        recordedInjected.withLock { $0 = [] }
        recordedGlobal.withLock { $0 = [] }
        URLProtocol.registerClass(GlobalRecordingURLProtocol.self)
        factory = RecordingSessionFactory()
        // A real-looking server that must never be contacted.
        fixture = try CloudFixture.make(server: URL(string: "https://cloud.example.invalid"), factory: factory)
    }

    override func tearDown() async throws {
        URLProtocol.unregisterClass(GlobalRecordingURLProtocol.self)
        fixture.tearDown()
        try await super.tearDown()
    }

    private func assertNoRequests(file: StaticString = #filePath, line: UInt = #line) async {
        // Give any stray background Task a chance to misbehave first.
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(recordedInjected.current, [], "requests through the injected session", file: file, line: line)
        XCTAssertEqual(recordedGlobal.current, [], "requests through any other session", file: file, line: line)
        XCTAssertEqual(factory.made.current, 0, "a URLSession was created", file: file, line: line)
        let hasSession = await fixture.services.client.hasSession
        XCTAssertFalse(hasSession, "client created a session", file: file, line: line)
    }

    func testSignedOutEveryEntryPointMakesZeroRequests() async throws {
        let s = fixture.services
        let file = try fixture.makeFile("clip.mov", bytes: 4096)
        XCTAssertFalse(s.state.snapshot.isSignedIn)

        // Settings › Account
        await s.session.refreshAccount()
        await s.session.syncNow()
        await s.session.checkInboxNow()
        s.session.setSyncEnabled(true)
        s.session.setInboxEnabled(true)
        await s.session.signOut()
        // A callback with no sign-in in progress: recognised, never redeemed.
        XCTAssertTrue(s.session.handleCallback(URL(string: "anyfmt://auth/callback?code=abc&state=xyz")!))
        XCTAssertFalse(s.handleCallback(URL(string: "https://example.com/other")!))
        await XCTAssertThrowsAsync(try await s.auth.completeSignIn(callbackURL: URL(string: "anyfmt://auth/callback?code=abc&state=xyz")!))
        await XCTAssertThrowsAsync(try await s.auth.completeSignIn(code: "abc"))
        await XCTAssertThrowsAsync(try await s.auth.refreshAccount())

        // Share links, uploads, cloud jobs
        await XCTAssertThrowsAsync(try await s.shareLinks.share(files: [file], options: ShareLinkOptions()))
        await XCTAssertThrowsAsync(try await s.shareLinks.links())
        await XCTAssertThrowsAsync(try await s.uploader.upload(file, purpose: .share))
        for op in [CloudJobOperation.convert(target: Formats.mp4, options: OptionValues([OptionKey.cloud: .bool(true)])),
                   .transcribe(), .upscale(), .removeBackgroundHQ] {
            let job = s.makeCloudJob(input: file, operation: op)
            await XCTAssertThrowsAsync(try await job.run(context: try fixture.jobContext()))
        }

        // Sync + inbox, even with their toggles on
        let source = MemorySyncSource()
        source.set(.favourites, ["items": ["png"]])
        await s.sync.setSource(source)
        try await s.sync.syncNow()
        await s.sync.noteLocalChange(.favourites)
        await s.sync.flush()
        let placed = try await s.inbox.checkNow()
        XCTAssertEqual(placed, [])
        await s.inbox.refreshSchedule()
        let polling = await s.inbox.isPolling
        XCTAssertFalse(polling)

        // The client itself refuses
        let c = s.client
        await XCTAssertThrowsAsync(try await c.me(trigger: .user))
        await XCTAssertThrowsAsync(try await c.links())
        await XCTAssertThrowsAsync(try await c.syncIndex())
        await XCTAssertThrowsAsync(try await c.inbox())
        await XCTAssertThrowsAsync(try await c.createJob(CloudJobCreate(uploadId: "u", operation: CloudJobOperationDTO(.upscale()), clientReference: nil)))
        await XCTAssertThrowsAsync(try await c.download(URL(string: "https://cloud.example.invalid/v1/files/x")!, to: fixture.directory.appendingPathComponent("x"), trigger: .user))

        // "Sign in…" opens the browser and nothing else.
        s.session.signIn()
        XCTAssertEqual(fixture.browser.opened.current.count, 1)
        s.session.cancelSignIn()

        XCTAssertEqual(s.entitlements, .signedOut)
        for f in CloudFeature.allCases { XCTAssertFalse(s.entitlements.can(f), "\(f)") }
        await assertNoRequests()
    }

    func testSignedOutUserFlowsCreateNoSession() async throws {
        let s = fixture.services
        let file = try fixture.makeFile("a.png", bytes: 100)
        await s.session.refreshAccount()
        await s.session.signOut()
        await XCTAssertThrowsAsync(try await s.shareLinks.share(files: [file], options: ShareLinkOptions()))
        let job = s.makeCloudJob(input: file, operation: .upscale())
        await XCTAssertThrowsAsync(try await job.run(context: try fixture.jobContext()))
        try await s.sync.syncNow()
        _ = try await s.inbox.checkNow()
        await assertNoRequests()
    }

    func testSignedInButSyncAndInboxOffMakeZeroRequests() async throws {
        fixture.fakeSignIn()
        let s = fixture.services
        let source = MemorySyncSource()
        source.set(.settings, ["a": 1])
        await s.sync.setSource(source)
        XCTAssertFalse(s.state.snapshot.syncEnabled)
        XCTAssertFalse(s.state.snapshot.inboxEnabled)
        try await s.sync.syncNow()
        await s.sync.noteLocalChange(.settings)
        await s.sync.flush()
        _ = try await s.inbox.checkNow()
        await s.inbox.refreshSchedule()
        // The gate is the backstop even if a service forgot to check.
        await XCTAssertThrowsAsync(try await s.client.syncIndex())
        await XCTAssertThrowsAsync(try await s.client.inbox())
        await assertNoRequests()
    }

    func testRecorderSeesAllowedRequests() async throws {
        // Control: proves the recorder would catch a request if one were made.
        fixture.fakeSignIn()
        await XCTAssertThrowsAsync(try await fixture.services.client.me(trigger: .user))
        XCTAssertEqual(recordedInjected.current.count, 1)
        XCTAssertTrue(recordedInjected.current[0].hasSuffix("/v1/me"))
        XCTAssertEqual(factory.made.current, 1)
    }

    func testValidateButtonIsTheOnlySignedOutRequest() async throws {
        await fixture.services.session.validateServer("https://cloud.example.invalid")
        XCTAssertEqual(recordedInjected.current, ["GET https://cloud.example.invalid/v1/health"])
        guard case .failed = fixture.services.session.serverCheck else { return XCTFail("expected failure") }
    }

    func testGateRules() throws {
        var s = CloudSnapshot(server: CloudConfig.defaultServer, credentials: nil, account: nil,
                              syncEnabled: true, inboxEnabled: true, pendingSignIn: nil)
        XCTAssertThrowsError(try CloudNetworkGate.check(.user, .authenticated, s))
        XCTAssertThrowsError(try CloudNetworkGate.check(.signIn, .codeExchange, s), "no pending sign-in")
        XCTAssertNoThrow(try CloudNetworkGate.check(.user, .probe, s))
        XCTAssertThrowsError(try CloudNetworkGate.check(.sync, .probe, s))
        XCTAssertThrowsError(try CloudNetworkGate.check(.inbox, .revocation, s))
        s.pendingSignIn = CloudPendingSignIn(server: s.server, state: "s", verifier: "v", startedAt: Date())
        XCTAssertNoThrow(try CloudNetworkGate.check(.signIn, .codeExchange, s))
        XCTAssertThrowsError(try CloudNetworkGate.check(.user, .codeExchange, s))
        s.pendingSignIn = CloudPendingSignIn(server: s.server, state: "s", verifier: "v", startedAt: Date().addingTimeInterval(-3600))
        XCTAssertThrowsError(try CloudNetworkGate.check(.signIn, .codeExchange, s), "expired sign-in")
        s.credentials = CloudCredentials(accessToken: "a", refreshToken: "r", accessTokenExpiresAt: Date())
        XCTAssertNoThrow(try CloudNetworkGate.check(.user, .authenticated, s))
        XCTAssertNoThrow(try CloudNetworkGate.check(.sync, .authenticated, s))
        s.syncEnabled = false
        s.inboxEnabled = false
        XCTAssertThrowsError(try CloudNetworkGate.check(.sync, .authenticated, s))
        XCTAssertThrowsError(try CloudNetworkGate.check(.inbox, .signedDownload, s))
        XCTAssertNoThrow(try CloudNetworkGate.check(.user, .signedDownload, s))
    }

    /// Static backstop: inside Sources/Cloud only CloudAPIClient.swift may touch URLSession.
    func testOnlyTheAPIClientTouchesURLSession() throws {
        let dir = MockCloudServer.repoRoot.appendingPathComponent("Sources/Cloud")
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return XCTFail("no Sources/Cloud") }
        var offenders: [String] = []
        var scanned = 0
        for case let url as URL in e where url.pathExtension == "swift" {
            scanned += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            let touches = ["URLSession(", "URLSession.shared", ".dataTask(", "NSURLConnection", "CFNetwork"].contains { text.contains($0) }
            if touches && url.lastPathComponent != "CloudAPIClient.swift" { offenders.append(url.lastPathComponent) }
        }
        XCTAssertGreaterThan(scanned, 10)
        XCTAssertEqual(offenders, [])
    }
}

@MainActor
func XCTAssertThrowsAsync<T>(_ expression: @autoclosure () async throws -> T, _ message: String = "",
                             file: StaticString = #filePath, line: UInt = #line) async {
    do {
        _ = try await expression()
        XCTFail("expected an error \(message)", file: file, line: line)
    } catch {}
}
