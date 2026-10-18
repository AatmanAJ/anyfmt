import CryptoKit
import XCTest
import HaloCore
@testable import HaloApp

/// LicenceStore with a fake keychain and an injected clock, and how an
/// active licence shows up in the cloud entitlements (and what it never does).
final class LicenceStoreTests: XCTestCase {
    /// Real now (whole seconds): `CloudSnapshot.entitlements` reads the wall clock.
    private let start = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
    private var clock: CloudLocked<Date>!
    private var secrets: MemorySecretStore!
    private var signer: Curve25519.Signing.PrivateKey!
    private var verifier: LicenceVerifier!

    override func setUp() {
        super.setUp()
        clock = CloudLocked(start)
        secrets = MemorySecretStore()
        signer = Curve25519.Signing.PrivateKey()
        verifier = LicenceVerifier(publicKeys: ["kid-test-1": signer.publicKey])
    }

    private func makeStore() -> LicenceStore {
        let clock = self.clock!
        return LicenceStore(secrets: secrets, verifier: verifier, now: { clock.current })
    }

    private func key(plan: Plan = .pro, seats: Int = 3, days: Double? = 30, issuedAt: Date? = nil) throws -> (String, Licence) {
        let iat = issuedAt ?? start.addingTimeInterval(-60)
        let l = Licence(keyID: "kid-test-1", licenceID: "L-STORE", plan: plan, seats: seats, issuedAt: iat,
                        expiresAt: days.map { iat.addingTimeInterval($0 * 86_400) })
        return (try LicenceKey.issue(l, signingKey: signer), l)
    }

    private func signedInSnapshot(plan: Plan, features: Set<CloudFeature>) -> CloudSnapshot {
        let ent = CloudEntitlements(isSignedIn: true, plan: plan, features: features, quotas: .none, customDomains: [])
        return CloudSnapshot(server: CloudConfig.defaultServer,
                             credentials: CloudCredentials(accessToken: "a", refreshToken: "r", accessTokenExpiresAt: start),
                             account: CloudAccount(userID: "u", email: "e@example.com", name: nil, entitlements: ent),
                             syncEnabled: false, inboxEnabled: false, pendingSignIn: nil)
    }

    // MARK: Store

    func testRoundTripThroughFakeKeychain() throws {
        let store = makeStore()
        XCTAssertNil(store.current)
        XCTAssertNil(store.status)
        XCTAssertNil(store.entitlements)

        let (k, l) = try key()
        let messy = k.lowercased().replacingOccurrences(of: "-", with: " ")
        XCTAssertEqual(try store.activate(messy), l)
        XCTAssertEqual(store.active, l)
        XCTAssertEqual(store.storedKey, k, "stored in canonical spelling")
        XCTAssertEqual(secrets.items.current[LicenceStore.keychainAccount], Data(k.utf8))

        // A fresh store (next launch) reads it back.
        let reopened = makeStore()
        XCTAssertEqual(reopened.active, l)
        XCTAssertEqual(reopened.entitlements?.seats, 3)

        try reopened.deactivate()
        XCTAssertNil(reopened.current)
        XCTAssertNil(secrets.items.current[LicenceStore.keychainAccount])
        XCTAssertNil(makeStore().current)
        XCTAssertNoThrow(try reopened.deactivate(), "deactivating twice is fine")
    }

    func testActivateRejectsBadKeysAndKeepsTheOldOne() throws {
        let store = makeStore()
        let (good, l) = try key()
        try store.activate(good)

        let (expired, _) = try key(days: 1, issuedAt: start.addingTimeInterval(-10 * 86_400))
        XCTAssertThrowsError(try store.activate(expired)) { error in
            guard let e = error as? LicenceActivationError, case .expired = e.verification else { return XCTFail("\(error)") }
            XCTAssertFalse(e.message.isEmpty)
        }
        XCTAssertThrowsError(try store.activate("HALO1-NOPE"))
        let other = try LicenceKey.issue(l, signingKey: Curve25519.Signing.PrivateKey())
        XCTAssertThrowsError(try store.activate(other)) { error in
            XCTAssertEqual((error as? LicenceActivationError)?.verification, .badSignature)
        }
        XCTAssertEqual(store.active, l, "a refused key never replaces the stored one")
    }

    func testExpiredLicenceStaysStoredButContributesNothing() throws {
        let store = makeStore()
        let (k, l) = try key(days: 30)
        try store.activate(k)
        XCTAssertTrue(store.entitlements?.isActive(at: clock.current) ?? false)

        clock.withLock { $0 = start.addingTimeInterval(31 * 86_400) }
        XCTAssertEqual(store.status, .expired(l))
        XCTAssertEqual(store.current, l, "still stored and readable")
        XCTAssertNil(store.active)
        XCTAssertNotNil(store.storedKey)
        XCTAssertEqual(CloudEntitlements.signedOut.merging(store.entitlements, now: clock.current), .signedOut)
    }

    func testStoredKeyFromAnUntrustedKidContributesNothing() throws {
        let (k, _) = try key()
        try secrets.write(Data(k.utf8), account: LicenceStore.keychainAccount)
        let store = LicenceStore(secrets: secrets, verifier: LicenceVerifier(trustedKeys: [:]), now: { Date(timeIntervalSince1970: 1_800_000_000) })
        XCTAssertEqual(store.status, .unknownKey("kid-test-1"))
        XCTAssertNil(store.entitlements)
    }

    func testObserversHearActivateAndDeactivate() throws {
        let store = makeStore()
        let seen = CloudLocked<[Plan?]>([])
        let id = store.observe { s in seen.withLock { $0.append(s.active?.plan) } }
        try store.activate(try key(plan: .team).0)
        try store.deactivate()
        try store.deactivate()
        XCTAssertEqual(seen.current, [.team, nil], "no callback for a no-op deactivate")
        store.removeObserver(id)
        try store.activate(try key().0)
        XCTAssertEqual(seen.current.count, 2)
    }

    // MARK: Entitlements

    func testSignedOutLicenceRaisesPlanOnly() throws {
        let store = makeStore()
        let state = CloudState(CloudSnapshot(server: CloudConfig.defaultServer, credentials: nil, account: nil,
                                             syncEnabled: false, inboxEnabled: false, pendingSignIn: nil))
        store.connect(to: state)
        XCTAssertEqual(state.snapshot.entitlements, .signedOut, "off: nothing stored")

        try store.activate(try key(plan: .pro, seats: 4).0)
        let e = state.snapshot.entitlements
        XCTAssertEqual(e.plan, .pro)
        XCTAssertEqual(e.licenceSeats, 4)
        XCTAssertFalse(e.isSignedIn, "a licence never signs you in")
        XCTAssertTrue(e.features.isEmpty)
        for f in CloudFeature.allCases { XCTAssertFalse(e.can(f), "\(f) needs the server") }
        XCTAssertEqual(e.quotas, .none)
        XCTAssertNil(e.usageLine)

        try store.deactivate()
        XCTAssertEqual(state.snapshot.entitlements, .signedOut, "off again")
    }

    func testSignedInKeepsServerFeaturesAndTakesTheBetterPlan() throws {
        let store = makeStore()
        let state = CloudState(signedInSnapshot(plan: .free, features: [.shareLink]))
        store.connect(to: state)
        try store.activate(try key(plan: .team, seats: 10).0)
        var e = state.snapshot.entitlements
        XCTAssertEqual(e.plan, .team)
        XCTAssertEqual(e.features, [.shareLink], "features are the server's, unchanged")
        XCTAssertTrue(e.can(.shareLink))
        XCTAssertFalse(e.can(.cloudJobs))
        XCTAssertEqual(e.licenceSeats, 10)

        // The server's better plan is never lowered by a lesser licence.
        let team = CloudEntitlements(isSignedIn: true, plan: .team, features: [], quotas: .none, customDomains: [])
        e = team.merging(LicenceEntitlements(try key(plan: .pro).1), now: start)
        XCTAssertEqual(e.plan, .team)
    }

    func testContributionFollowsTheClock() throws {
        let (_, l) = try key(days: 2)
        let lic = LicenceEntitlements(l, clockSkew: 300)
        let base = CloudEntitlements.signedOut
        XCTAssertEqual(base.merging(lic, now: start).plan, .pro, "on")
        XCTAssertEqual(base.merging(lic, now: start.addingTimeInterval(3 * 86_400)), base, "off after expiry")
        XCTAssertEqual(base.merging(lic, now: l.issuedAt.addingTimeInterval(-600)), base, "off before it starts")
        XCTAssertEqual(base.merging(nil, now: start), base)
    }

    func testCachedAccountStillDecodesWithoutLicenceField() throws {
        let ent = CloudEntitlements(isSignedIn: true, plan: .pro, features: [.sync], quotas: .none, customDomains: [])
        let account = CloudAccount(userID: "u", email: "e", name: nil, entitlements: ent)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(account)) as! [String: Any]
        var e = json["entitlements"] as! [String: Any]
        e["licence"] = nil
        json["entitlements"] = e
        let decoded = try JSONDecoder().decode(CloudAccount.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded, account)
    }

    // MARK: Policy

    @MainActor func testEntitlementCheckStillPasses() throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["scripts/check-entitlements.sh"]
        p.currentDirectoryURL = MockCloudServer.repoRoot
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out
        try p.run()
        p.waitUntilExit()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        XCTAssertEqual(p.terminationStatus, 0, text)
    }
}
