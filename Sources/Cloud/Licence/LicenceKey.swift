import CryptoKit
import Foundation
import AnyfmtCore

/// What a licence key says, once its signature checks out.
///
/// A licence only ever feeds the cloud entitlements gate (BUILD.md §9b). It
/// never unlocks, limits or changes anything that runs on the Mac.
/// See docs/LICENCE_KEYS.md.
struct Licence: Sendable, Equatable, Codable {
    /// Payload format version. Only 1 exists.
    static let currentVersion = 1

    let version: Int
    /// Which signing key issued it (`LicenceTrustedKeys`).
    let keyID: String
    /// Our id for the sale, for support and server-side revocation.
    let licenceID: String
    /// `.pro` or `.team`; a key never says `.free`.
    let plan: Plan
    let seats: Int
    let issuedAt: Date
    /// nil = perpetual.
    let expiresAt: Date?
    /// `Licence.emailHint(for:)` of the buyer's address, never the address itself.
    let emailHint: String?

    init(keyID: String, licenceID: String, plan: Plan, seats: Int, issuedAt: Date, expiresAt: Date?,
         emailHint: String? = nil, version: Int = Licence.currentVersion) {
        self.version = version
        self.keyID = keyID
        self.licenceID = licenceID
        self.plan = plan
        self.seats = seats
        // Whole seconds: that's all the payload carries.
        self.issuedAt = Date(timeIntervalSince1970: issuedAt.timeIntervalSince1970.rounded(.down))
        self.expiresAt = expiresAt.map { Date(timeIntervalSince1970: $0.timeIntervalSince1970.rounded(.down)) }
        self.emailHint = emailHint
    }

    var isPerpetual: Bool { expiresAt == nil }

    /// The first 8 bytes of SHA-256 over the trimmed, lowercased address, as hex.
    /// Enough to answer "is this the key I bought with x@y?" without carrying the address.
    static func emailHint(for email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SHA256.hash(data: Data(normalized.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    func matches(email: String) -> Bool {
        guard let emailHint else { return false }
        return emailHint == Self.emailHint(for: email)
    }
}

// MARK: - Payload JSON

extension Licence {
    /// Short keys keep the pasted string short. `exp` is always present
    /// (null = perpetual); `eh` only when there is a hint.
    private enum CodingKeys: String, CodingKey {
        case version = "v", keyID = "kid", licenceID = "lid", plan, seats
        case issuedAt = "iat", expiresAt = "exp", emailHint = "eh"
    }

    static let maxSeats = 100_000
    private static let maxFieldLength = 64

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(keyID, forKey: .keyID)
        try c.encode(licenceID, forKey: .licenceID)
        try c.encode(plan.rawValue, forKey: .plan)
        try c.encode(seats, forKey: .seats)
        try c.encode(Int64(issuedAt.timeIntervalSince1970), forKey: .issuedAt)
        if let expiresAt { try c.encode(Int64(expiresAt.timeIntervalSince1970), forKey: .expiresAt) }
        else { try c.encodeNil(forKey: .expiresAt) }
        try c.encodeIfPresent(emailHint, forKey: .emailHint)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func bad(_ key: CodingKeys, _ why: String) -> DecodingError {
            .dataCorruptedError(forKey: key, in: c, debugDescription: why)
        }
        version = try c.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else { throw bad(.version, "unsupported version \(version)") }
        keyID = try c.decode(String.self, forKey: .keyID)
        licenceID = try c.decode(String.self, forKey: .licenceID)
        for (key, value) in [(CodingKeys.keyID, keyID), (.licenceID, licenceID)] {
            guard !value.isEmpty, value.count <= Self.maxFieldLength else { throw bad(key, "bad length") }
        }
        let planName = try c.decode(String.self, forKey: .plan)
        guard let plan = Plan(rawValue: planName), plan != .free else { throw bad(.plan, "unknown plan \(planName)") }
        self.plan = plan
        seats = try c.decode(Int.self, forKey: .seats)
        guard (1...Self.maxSeats).contains(seats) else { throw bad(.seats, "seats out of range") }
        issuedAt = Date(timeIntervalSince1970: TimeInterval(try c.decode(Int64.self, forKey: .issuedAt)))
        expiresAt = try c.decodeIfPresent(Int64.self, forKey: .expiresAt).map { Date(timeIntervalSince1970: TimeInterval($0)) }
        if let expiresAt, expiresAt <= issuedAt { throw bad(.expiresAt, "expires before it was issued") }
        emailHint = try c.decodeIfPresent(String.self, forKey: .emailHint)
        if let emailHint, emailHint.isEmpty || emailHint.count > Self.maxFieldLength { throw bad(.emailHint, "bad length") }
    }

    /// The exact bytes that get signed: compact JSON with sorted keys.
    func canonicalPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

// MARK: - Key string

/// Why a string isn't a licence key at all (before any signature check).
enum LicenceFormatError: Error, Equatable, Sendable {
    case missingPrefix
    case badSymbols
    case badLength
    case badPayload(String)
}

/// The pasted form: `ANYFMT1-` + Crockford base32 of
/// `UInt16 big-endian payload length || payload JSON || 64-byte Ed25519 signature`,
/// in groups of five. Parsing ignores dashes, whitespace and case.
enum LicenceKey {
    static let prefix = "ANYFMT1"
    /// Keys issued before the rename to anyfmt. Same payload and signature, older prefix.
    static let legacyPrefixes = ["HALO1"]
    static let signatureLength = 64
    static let groupSize = 5
    /// Generous; real payloads are ~150 bytes.
    static let maxPayloadLength = 1024

    /// Raw parts of a key, signature not yet checked.
    struct Parts: Sendable, Equatable {
        let payload: Data
        let signature: Data
    }

    static func encode(payload: Data, signature: Data) -> String {
        precondition(payload.count <= maxPayloadLength && signature.count == signatureLength)
        var blob = Data([UInt8(payload.count >> 8), UInt8(payload.count & 0xFF)])
        blob.append(payload)
        blob.append(signature)
        let body = LicenceBase32.encode(blob)
        var groups: [Substring] = []
        var rest = Substring(body)
        while !rest.isEmpty {
            groups.append(rest.prefix(groupSize))
            rest = rest.dropFirst(groupSize)
        }
        return ([Substring(prefix)] + groups).joined(separator: "-")
    }

    static func decode(_ string: String) throws(LicenceFormatError) -> Parts {
        let compact = String(string.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0) && $0 != "-"
        }).uppercased()
        guard let used = ([prefix] + legacyPrefixes).first(where: { compact.hasPrefix($0) }) else { throw .missingPrefix }
        guard let blob = LicenceBase32.decode(compact.dropFirst(used.count)) else { throw .badSymbols }
        guard blob.count >= 2 else { throw .badLength }
        let bytes = [UInt8](blob)
        let length = Int(bytes[0]) << 8 | Int(bytes[1])
        guard length > 0, length <= maxPayloadLength, bytes.count == 2 + length + signatureLength else { throw .badLength }
        return Parts(payload: Data(bytes[2..<(2 + length)]), signature: Data(bytes[(2 + length)...]))
    }

    /// Signs `licence` (issuing side: tests and scripts/licence-tool.swift).
    static func issue(_ licence: Licence, signingKey: Curve25519.Signing.PrivateKey) throws -> String {
        let payload = try licence.canonicalPayload()
        let signature = try signingKey.signature(for: payload)
        return encode(payload: payload, signature: signature)
    }
}
