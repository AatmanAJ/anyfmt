import XCTest
import AnyfmtCore
@testable import AnyfmtApp

/// The real login Keychain, under a throwaway service name that's deleted afterwards.
final class KeychainStoreTests: XCTestCase {
    private var store: KeychainStore!

    override func setUp() {
        super.setUp()
        store = KeychainStore(service: "\(Brand.bundleID).cloud.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? store.deleteAll()
        XCTAssertEqual(try? store.accounts(), [], "test items cleaned up")
        super.tearDown()
    }

    func testDefaultServiceName() {
        XCTAssertEqual(KeychainStore().service, "\(Brand.bundleID).cloud")
    }

    func testReadWriteUpdateDelete() throws {
        XCTAssertNil(try store.read(account: "cloud.example.invalid"))
        try store.write(Data("one".utf8), account: "cloud.example.invalid")
        XCTAssertEqual(try store.read(account: "cloud.example.invalid"), Data("one".utf8))
        try store.write(Data("two".utf8), account: "cloud.example.invalid")
        XCTAssertEqual(try store.read(account: "cloud.example.invalid"), Data("two".utf8), "updated in place")
        try store.write(Data("self".utf8), account: "127.0.0.1:8787")
        XCTAssertEqual(try store.accounts(), ["127.0.0.1:8787", "cloud.example.invalid"], "one item per server")
        try store.delete(account: "cloud.example.invalid")
        XCTAssertNil(try store.read(account: "cloud.example.invalid"))
        XCTAssertNoThrow(try store.delete(account: "cloud.example.invalid"), "deleting twice is fine")
        XCTAssertEqual(try store.accounts(), ["127.0.0.1:8787"])
    }

    func testVaultRoundTripsCredentialsPerServer() throws {
        let vault = CloudCredentialVault(store: store)
        let a = try XCTUnwrap(URL(string: "https://cloud.example.invalid"))
        let b = try XCTUnwrap(URL(string: "http://127.0.0.1:9999"))
        let creds = CloudCredentials(accessToken: "at", refreshToken: "rt", accessTokenExpiresAt: Date(timeIntervalSince1970: 2_000_000_000), deviceID: "dev")
        try vault.save(creds, for: a)
        XCTAssertEqual(vault.load(for: a), creds)
        XCTAssertNil(vault.load(for: b))
        vault.remove(for: a)
        XCTAssertNil(vault.load(for: a))
    }
}

/// The `Entitlements` contract as the wheel and Settings read it.
final class CloudEntitlementsTests: XCTestCase {
    func testSignedOutCanNothing() {
        let e = CloudEntitlements.signedOut
        XCTAssertFalse(e.isSignedIn)
        XCTAssertEqual(e.plan, .free)
        for f in CloudFeature.allCases { XCTAssertFalse(e.can(f), "\(f)") }
        XCTAssertNil(e.usageLine)
        let asProtocol: any Entitlements = e
        XCTAssertFalse(asProtocol.can(.shareLink))
    }

    func testFromServerPayloadIgnoresUnknowns() {
        let dto = CloudEntitlementsDTO(plan: "enterprise-2030", features: ["shareLink", "teleport", "sync"],
                                       quotas: CloudQuotas(shareLinksPerMonth: 10, shareLinksUsed: 4), customDomains: ["a.com"])
        let e = CloudEntitlements(dto)
        XCTAssertTrue(e.isSignedIn)
        XCTAssertEqual(e.plan, .free, "unknown plans read as free")
        XCTAssertEqual(e.features, [.shareLink, .sync])
        XCTAssertEqual(e.customDomains, [], "no custom domains without the feature")
        XCTAssertEqual(e.remainingShareLinks, 6)
        XCTAssertEqual(e.recordingShareLink().remainingShareLinks, 5)
    }

    func testSnapshotEntitlementsFollowSignIn() {
        var s = CloudSnapshot(server: CloudConfig.defaultServer, credentials: nil,
                              account: CloudAccount(userID: "u", email: "e", name: nil,
                                                    entitlements: CloudEntitlements(isSignedIn: true, plan: .pro, features: [.sync], quotas: .none, customDomains: [])),
                              syncEnabled: false, inboxEnabled: false, pendingSignIn: nil)
        XCTAssertEqual(s.entitlements, .signedOut, "a cached account without tokens is signed out")
        s.credentials = CloudCredentials(accessToken: "a", refreshToken: "r", accessTokenExpiresAt: Date())
        XCTAssertEqual(s.entitlements.plan, .pro)
        XCTAssertTrue(s.entitlements.can(.sync))
    }

    func testDefaultServerIsThePlaceholder() {
        XCTAssertEqual(CloudConfig.defaultServer.absoluteString, "https://cloud.example.invalid")
        XCTAssertTrue(CloudServerAddress.isDefault(CloudConfig.defaultServer))
        XCTAssertEqual(CloudConfig.redirectURI, "\(Brand.urlScheme)://auth/callback")
        XCTAssertTrue(CloudAuth.isCallback(URL(string: "\(Brand.urlScheme)://auth/callback?code=1")!))
        XCTAssertFalse(CloudAuth.isCallback(URL(string: "\(Brand.urlScheme)://other/callback")!))
        XCTAssertFalse(CloudAuth.isCallback(URL(string: "https://auth/callback")!))
    }

    func testErrorsAreHuman() {
        let errors: [CloudError] = [.signedOut, .offline, .serverUnreachable("x.com"), .connectionLost, .sessionExpired,
                                    .notEntitled(.transcription), .quotaExceeded(message: "Used up.", resetsAt: nil),
                                    .rateLimited(retryAfter: 3), .payloadTooLarge(maxBytes: 1_000_000), .notFound,
                                    .checksumMismatch, .jobFailed(""), .fileUnreadable("a.mov"), .invalidResponse("x"),
                                    .server(status: 500, code: "internal", message: nil, requestID: "req_1")]
        for e in errors {
            let text = e.errorDescription ?? ""
            XCTAssertFalse(text.isEmpty, "\(e)")
            XCTAssertFalse(text.contains("HTTP"), "no jargon in \(text)")
            XCTAssertFalse(e.technicalDetails.isEmpty)
        }
        XCTAssertTrue(CloudError.server(status: 500, code: "internal", message: nil, requestID: "req_1").technicalDetails.contains("req_1"))
        XCTAssertTrue(CloudError.connectionLost.isTransient)
        XCTAssertFalse(CloudError.notFound.isTransient)
    }

    func testEntitlementsAreOnlyConsultedInsideCloud() throws {
        // Mirrors scripts/check-entitlements.sh so `make test` and Xcode agree.
        let root = MockCloudServerPaths.repoRoot
        let script = root.appendingPathComponent("scripts/check-entitlements.sh")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script.path]
        p.currentDirectoryURL = root
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out
        try p.run()
        p.waitUntilExit()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(p.terminationStatus, 0, text)
    }
}

enum MockCloudServerPaths {
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
}
