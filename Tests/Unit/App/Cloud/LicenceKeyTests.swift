import CryptoKit
import XCTest
import HaloCore
@testable import HaloApp

/// Licence key format and verification, with a throwaway key pair made per
/// test (never the shipped kid), plus one golden key from scripts/licence-tool.swift.
final class LicenceKeyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let kid = "kid-test-1"
    private var signer: Curve25519.Signing.PrivateKey!
    private var verifier: LicenceVerifier!

    override func setUp() {
        super.setUp()
        signer = Curve25519.Signing.PrivateKey()
        verifier = LicenceVerifier(publicKeys: [kid: signer.publicKey])
    }

    private func licence(plan: Plan = .pro, seats: Int = 1, issuedDaysAgo: Double = 1, expiresInDays: Double? = 364,
                         kid: String? = nil, email: String? = nil) -> Licence {
        Licence(keyID: kid ?? self.kid, licenceID: "L-TEST", plan: plan, seats: seats,
                issuedAt: now.addingTimeInterval(-issuedDaysAgo * 86_400),
                expiresAt: expiresInDays.map { now.addingTimeInterval($0 * 86_400) },
                emailHint: email.map(Licence.emailHint(for:)))
    }

    private func issue(_ l: Licence) throws -> String { try LicenceKey.issue(l, signingKey: signer) }

    // MARK: Results

    func testValid() throws {
        let l = licence(plan: .team, seats: 7, email: "Buyer@Example.com ")
        let result = verifier.verify(try issue(l), now: now)
        XCTAssertEqual(result, .valid(l))
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.licence?.seats, 7)
        XCTAssertTrue(l.matches(email: "buyer@example.com"))
        XCTAssertFalse(l.matches(email: "someone@else.com"))
        XCTAssertFalse(result.message.isEmpty)
    }

    func testPerpetual() throws {
        let l = licence(expiresInDays: nil)
        XCTAssertTrue(l.isPerpetual)
        XCTAssertEqual(verifier.verify(try issue(l), now: now.addingTimeInterval(86_400 * 365 * 50)), .valid(l))
        XCTAssertTrue(String(decoding: try l.canonicalPayload(), as: UTF8.self).contains("\"exp\":null"))
    }

    func testExpired() throws {
        let l = licence(issuedDaysAgo: 400, expiresInDays: -35)
        let result = verifier.verify(try issue(l), now: now)
        XCTAssertEqual(result, .expired(l))
        XCTAssertEqual(result.licence, l, "signature checked out, so the contents are still readable")
        XCTAssertFalse(result.isValid)
    }

    func testExpiresExactlyAtExp() throws {
        let l = licence(expiresInDays: 0)
        XCTAssertEqual(verifier.verify(try issue(l), now: now), .expired(l))
        XCTAssertEqual(verifier.verify(try issue(l), now: now.addingTimeInterval(-1)), .valid(l))
    }

    func testNotYetValid() throws {
        let l = licence(issuedDaysAgo: -2)
        XCTAssertEqual(verifier.verify(try issue(l), now: now), .notYetValid(l))
        // A clock a minute behind the issuer's is tolerated.
        let soon = Licence(keyID: kid, licenceID: "L", plan: .pro, seats: 1, issuedAt: now.addingTimeInterval(60), expiresAt: nil)
        XCTAssertEqual(verifier.verify(try issue(soon), now: now), .valid(soon))
    }

    func testUnknownKey() throws {
        let l = licence(kid: "kid-retired")
        XCTAssertEqual(verifier.verify(try issue(l), now: now), .unknownKey("kid-retired"))
        // A different key pair claiming our kid fails the signature instead.
        let impostor = Curve25519.Signing.PrivateKey()
        XCTAssertEqual(verifier.verify(try LicenceKey.issue(licence(), signingKey: impostor), now: now), .badSignature)
        // The shipped table doesn't trust the test key.
        XCTAssertEqual(LicenceVerifier.shipped.verify(try issue(licence()), now: now), .unknownKey(kid))
    }

    func testTamperedPayloadByte() throws {
        let parts = try LicenceKey.decode(try issue(licence(plan: .pro, seats: 1)))
        // Swap "seats":1 for "seats":9 — still valid JSON, still parses.
        let text = String(decoding: parts.payload, as: UTF8.self).replacingOccurrences(of: "\"seats\":1", with: "\"seats\":9")
        let forged = LicenceKey.encode(payload: Data(text.utf8), signature: parts.signature)
        XCTAssertEqual(verifier.verify(forged, now: now), .badSignature)

        // Every single-byte flip anywhere in the payload is caught (bad JSON or bad signature).
        for i in parts.payload.indices {
            var p = parts.payload
            p[i] ^= 0x01
            let r = verifier.verify(LicenceKey.encode(payload: p, signature: parts.signature), now: now)
            XCTAssertFalse(r.isValid, "byte \(i)")
        }
    }

    func testTamperedSignature() throws {
        let parts = try LicenceKey.decode(try issue(licence()))
        for i in [0, 31, 63] {
            var s = parts.signature
            s[i] ^= 0x80
            XCTAssertEqual(verifier.verify(LicenceKey.encode(payload: parts.payload, signature: s), now: now), .badSignature)
        }
    }

    func testTruncatedAndGarbage() throws {
        let key = try issue(licence())
        for cut in [1, 5, 20, key.count / 2, key.count - 7] {
            guard case .malformed = verifier.verify(String(key.dropLast(cut)), now: now) else { return XCTFail("cut \(cut)") }
        }
        for junk in ["", "HALO1-", "HALO2-ABCDE", "not a key", "HALO1-UUUUU", key + "0", String(key.dropFirst(6))] {
            guard case .malformed = verifier.verify(junk, now: now) else { return XCTFail("accepted \(junk)") }
        }
        // Signed, but the payload isn't a licence (plan free, v2, zero seats).
        for json in [#"{"exp":null,"iat":1,"kid":"kid-test-1","lid":"L","plan":"free","seats":1,"v":1}"#,
                     #"{"exp":null,"iat":1,"kid":"kid-test-1","lid":"L","plan":"pro","seats":1,"v":2}"#,
                     #"{"exp":null,"iat":1,"kid":"kid-test-1","lid":"L","plan":"pro","seats":0,"v":1}"#] {
            let payload = Data(json.utf8)
            let key = LicenceKey.encode(payload: payload, signature: try signer.signature(for: payload))
            guard case .malformed = verifier.verify(key, now: now) else { return XCTFail("accepted \(json)") }
        }
    }

    func testLowercaseDashesSpacesAndAliases() throws {
        let l = licence()
        let key = try issue(l)
        XCTAssertTrue(key.hasPrefix("HALO1-"))
        XCTAssertTrue(key.split(separator: "-").dropFirst().dropLast().allSatisfy { $0.count == 5 }, "groups of five")
        let messy = "  " + key.lowercased().replacingOccurrences(of: "-", with: " - ").replacingOccurrences(of: "q", with: "Q") + "\n"
        XCTAssertEqual(verifier.verify(messy, now: now), .valid(l))
        let noDashes = key.replacingOccurrences(of: "-", with: "")
        XCTAssertEqual(verifier.verify(noDashes, now: now), .valid(l))
        // Crockford aliases: O reads as 0, I/L as 1.
        let body = key.dropFirst("HALO1-".count).replacingOccurrences(of: "0", with: "O").replacingOccurrences(of: "1", with: "l")
        let aliased = "halo1-" + body
        XCTAssertEqual(verifier.verify(aliased, now: now), .valid(l))
    }

    func testBase32RoundTrip() {
        for n in 0..<40 {
            let data = Data((0..<n).map { _ in UInt8.random(in: 0...255) })
            XCTAssertEqual(LicenceBase32.decode(LicenceBase32.encode(data)), data, "length \(n)")
        }
        XCTAssertEqual(LicenceBase32.encode(Data("f".utf8)), "CR")
        XCTAssertNil(LicenceBase32.decode("CS"), "non-zero padding bits rejected")
        XCTAssertNil(LicenceBase32.decode("C"), "impossible length")
    }

    func testMessagesAreHuman() throws {
        let cases: [LicenceVerification] = [.valid(licence()), .valid(licence(expiresInDays: nil)), .expired(licence()),
                                            .notYetValid(licence()), .unknownKey("k"), .badSignature, .malformed("x")]
        for c in cases {
            XCTAssertFalse(c.message.isEmpty)
            XCTAssertFalse(c.message.contains("Error"), c.message)
        }
        XCTAssertNotEqual(LicenceVerification.badSignature.message, LicenceVerification.malformed("").message)
    }

    // MARK: Shipped key + tool

    /// Issued with `swift scripts/licence-tool.swift issue --plan team --seats 5 --perpetual
    /// --lid L-GOLDEN-1 --issued-at 1790000000` against the shipped kid-2026-1. Keeps the
    /// script's encoder and the app's decoder in step.
    static let goldenShippedKey = """
    HALO1-01GQP-8K5F1-R24EK-EENP6-RB12D-5GQ88-HT64V-KJC1G-60R30-C1G5G-H6PTB-448X2-4TV9C-GPK4C-1J6RP-K28HC-49P6J-\
    S1278-H4RBA-79X64-8HAE5-MRJ4B-12E1P-62VH2-78H78-SB1DM-H2R8K-KCNGQ-8WS27-8TJR8-KP48X-32ZF2-DSF62-GQ8R0-RA1FF-\
    AFH8X-7KKHT-3E45C-8CZAD-AJ9YC-BQY6D-JXG0A-N43DD-2ZXY1-JVCBF-05G1B-BC02Q-VKSMA-HVM1J-499S0-0XN86-H58HG-2
    """

    func testGoldenKeyFromToolVerifiesWithShippedKey() throws {
        XCTAssertEqual(LicenceTrustedKeys.all["kid-2026-1"].flatMap { Data(base64Encoded: $0) }?.count, 32,
                       "shipped kid is a 32-byte Ed25519 public key")
        let result = LicenceVerifier.shipped.verify(Self.goldenShippedKey, now: now)
        guard case .valid(let l) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(l.keyID, "kid-2026-1")
        XCTAssertEqual(l.licenceID, "L-GOLDEN-1")
        XCTAssertEqual(l.plan, .team)
        XCTAssertEqual(l.seats, 5)
        XCTAssertNil(l.expiresAt)
        XCTAssertEqual(l.issuedAt, Date(timeIntervalSince1970: 1_790_000_000))
        // The tool and the app produce the same canonical bytes.
        XCTAssertEqual(try l.canonicalPayload(), try LicenceKey.decode(Self.goldenShippedKey).payload)
        // Re-encoding the parts gives back the tool's exact spelling.
        let parts = try LicenceKey.decode(Self.goldenShippedKey)
        XCTAssertEqual(LicenceKey.encode(payload: parts.payload, signature: parts.signature),
                       Self.goldenShippedKey.replacingOccurrences(of: "\n", with: ""))
    }

    @MainActor func testNoPrivateKeyMaterialInSources() throws {
        // Only base64 public keys ship; a raw private key would be a 32-byte
        // seed too, so check the table length and that nothing looks like a PEM/seed dump.
        let root = MockCloudServer.repoRoot.appendingPathComponent("Sources/Cloud/Licence")
        for name in try FileManager.default.contentsOfDirectory(atPath: root.path) {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            XCTAssertFalse(text.contains("PRIVATE KEY"), name)
            XCTAssertFalse(text.contains("PrivateKey(rawRepresentation"), name)
        }
        XCTAssertEqual(LicenceTrustedKeys.all.count, 1)
    }
}
