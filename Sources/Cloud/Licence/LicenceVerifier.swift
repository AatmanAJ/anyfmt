import CryptoKit
import Foundation
import AnyfmtCore

/// Public halves of the licence signing keys, by key id. Only public keys
/// live in the repo; private keys stay in the issuer's Keychain
/// (docs/LICENCE_KEYS.md). To rotate: add the new kid here, issue with it,
/// and keep the old entry until every key it signed has expired (or remove
/// it to revoke that whole batch).
enum LicenceTrustedKeys {
    /// kid → raw 32-byte Ed25519 public key, base64.
    static let all: [String: String] = [
        "kid-2026-1": "QmCa03CZYES+EJ/j5ql66S86f4csCFg9B8gPDvbR9dA=",
    ]
}

/// The outcome of checking a pasted or stored key.
enum LicenceVerification: Sendable, Equatable {
    case valid(Licence)
    case expired(Licence)
    case notYetValid(Licence)
    case unknownKey(String)
    case badSignature
    case malformed(String)

    /// The signed contents, when the signature checked out (even if out of date).
    var licence: Licence? {
        switch self {
        case .valid(let l), .expired(let l), .notYetValid(let l): l
        case .unknownKey, .badSignature, .malformed: nil
        }
    }

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    /// One sentence for the person who pasted it. Never blames them, never upsells.
    var message: String {
        switch self {
        case .valid(let l):
            if let exp = l.expiresAt {
                let date = exp.formatted(date: .abbreviated, time: .omitted)
                return String(localized: "\(l.plan.displayName) licence, valid until \(date).")
            }
            return String(localized: "\(l.plan.displayName) licence, no expiry.")
        case .expired(let l):
            let date = (l.expiresAt ?? l.issuedAt).formatted(date: .abbreviated, time: .omitted)
            return String(localized: "This licence expired on \(date).")
        case .notYetValid(let l):
            let date = l.issuedAt.formatted(date: .abbreviated, time: .omitted)
            return String(localized: "This licence starts on \(date). Check your Mac’s date and time.")
        case .unknownKey:
            return String(localized: "This licence was signed with a key this version of \(Brand.name) doesn’t know. Updating may help.")
        case .badSignature:
            return String(localized: "This licence key doesn’t check out. Copy it again from your receipt, the whole thing.")
        case .malformed:
            return String(localized: "That doesn’t look like a licence key. It starts with ANYFMT1-.")
        }
    }
}

/// Checks licence keys offline against `LicenceTrustedKeys`.
struct LicenceVerifier: Sendable {
    /// kid → raw public key bytes.
    let trustedKeys: [String: Data]
    /// Tolerance for a Mac clock that's a little behind the issuer's.
    var clockSkew: TimeInterval = 5 * 60

    init(trustedKeys: [String: Data], clockSkew: TimeInterval = 5 * 60) {
        self.trustedKeys = trustedKeys
        self.clockSkew = clockSkew
    }

    init(publicKeys: [String: Curve25519.Signing.PublicKey], clockSkew: TimeInterval = 5 * 60) {
        self.init(trustedKeys: publicKeys.mapValues(\.rawRepresentation), clockSkew: clockSkew)
    }

    /// The keys this build ships with.
    static let shipped = LicenceVerifier(trustedKeys: LicenceTrustedKeys.all.compactMapValues { Data(base64Encoded: $0) })

    func verify(_ key: String, now: Date = Date()) -> LicenceVerification {
        let parts: LicenceKey.Parts
        do { parts = try LicenceKey.decode(key) } catch {
            return .malformed(String(describing: error))
        }
        let licence: Licence
        do { licence = try JSONDecoder().decode(Licence.self, from: parts.payload) } catch {
            return .malformed("payload: \(error)")
        }
        // The kid is read before the signature is checked; that's fine, it only picks the key.
        guard let raw = trustedKeys[licence.keyID], let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else {
            return .unknownKey(licence.keyID)
        }
        guard publicKey.isValidSignature(parts.signature, for: parts.payload) else { return .badSignature }
        if licence.issuedAt.timeIntervalSince(now) > clockSkew { return .notYetValid(licence) }
        if let exp = licence.expiresAt, now >= exp { return .expired(licence) }
        return .valid(licence)
    }
}
