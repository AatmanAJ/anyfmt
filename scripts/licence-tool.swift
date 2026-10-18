#!/usr/bin/env swift
// Issues and checks Halo licence keys. See docs/LICENCE_KEYS.md.
//
//   swift scripts/licence-tool.swift issue --plan pro --seats 1 --days 365 [--kid kid-2026-1]
//         [--email buyer@example.com] [--lid L-ABC] [--perpetual] [--issued-at <unix seconds>]
//   swift scripts/licence-tool.swift verify <key>
//   swift scripts/licence-tool.swift keygen --kid kid-2027-1
//
// The private key is read from the login Keychain (service
// dev.aiwithaj.halo.licence-signing, account = kid) through /usr/bin/security,
// or from $HALO_LICENCE_SIGNING_KEY (base64 raw key) when set. Public keys are
// read from Sources/Cloud/Licence/LicenceVerifier.swift, so there is one table.
//
// The format code below mirrors Sources/Cloud/Licence/LicenceKey.swift (a
// script can't import the app module); the golden key in
// Tests/Unit/App/Cloud/LicenceKeyTests.swift keeps them in step.

import CryptoKit
import Foundation

let signingService = "dev.aiwithaj.halo.licence-signing"
let defaultKid = "kid-2026-1"
let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("licence-tool: \(message)\n".utf8))
    exit(code)
}

// MARK: Base32 (Crockford, no padding)

func base32Encode(_ data: Data) -> String {
    var out = "", buffer: UInt32 = 0, bits = 0
    for byte in data {
        buffer = ((buffer << 8) | UInt32(byte)) & 0x1FFF
        bits += 8
        while bits >= 5 { bits -= 5; out.append(alphabet[Int((buffer >> UInt32(bits)) & 0x1F)]) }
    }
    if bits > 0 { out.append(alphabet[Int((buffer << UInt32(5 - bits)) & 0x1F)]) }
    return out
}

func base32Decode(_ text: String) -> Data? {
    var table: [Character: UInt32] = [:]
    for (i, c) in alphabet.enumerated() { table[c] = UInt32(i) }
    table["O"] = 0; table["I"] = 1; table["L"] = 1
    var out = Data(), buffer: UInt32 = 0, bits = 0
    for ch in text.uppercased() {
        guard let v = table[ch] else { return nil }
        buffer = (buffer << 5) | v
        bits += 5
        if bits >= 8 { bits -= 8; out.append(UInt8((buffer >> UInt32(bits)) & 0xFF)) }
        buffer &= (1 << UInt32(bits)) - 1
    }
    return bits < 5 && buffer == 0 ? out : nil
}

// MARK: Key container

func encodeKey(payload: Data, signature: Data) -> String {
    var blob = Data([UInt8(payload.count >> 8), UInt8(payload.count & 0xFF)])
    blob.append(payload)
    blob.append(signature)
    let body = Array(base32Encode(blob))
    let groups = stride(from: 0, to: body.count, by: 5).map { String(body[$0..<min($0 + 5, body.count)]) }
    return (["HALO1"] + groups).joined(separator: "-")
}

func decodeKey(_ key: String) -> (payload: Data, signature: Data)? {
    let compact = String(key.filter { !$0.isWhitespace && $0 != "-" }).uppercased()
    guard compact.hasPrefix("HALO1"), let blob = base32Decode(String(compact.dropFirst(5))), blob.count >= 2 else { return nil }
    let b = [UInt8](blob)
    let length = Int(b[0]) << 8 | Int(b[1])
    guard length > 0, b.count == 2 + length + 64 else { return nil }
    return (Data(b[2..<(2 + length)]), Data(b[(2 + length)...]))
}

/// Same bytes as `Licence.canonicalPayload()`: sorted keys, compact, exp always present.
func canonicalPayload(kid: String, lid: String, plan: String, seats: Int, iat: Int64, exp: Int64?, emailHint: String?) -> Data {
    func q(_ s: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try! encoder.encode(s), as: UTF8.self)
    }
    var fields: [String] = []
    if let emailHint { fields.append("\"eh\":\(q(emailHint))") }
    fields.append("\"exp\":\(exp.map(String.init) ?? "null")")
    fields.append("\"iat\":\(iat)")
    fields.append("\"kid\":\(q(kid))")
    fields.append("\"lid\":\(q(lid))")
    fields.append("\"plan\":\(q(plan))")
    fields.append("\"seats\":\(seats)")
    fields.append("\"v\":1")
    return Data("{\(fields.joined(separator: ","))}".utf8)
}

func emailHint(_ email: String) -> String {
    let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return SHA256.hash(data: Data(normalized.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
}

// MARK: Keys

func run(_ path: String, _ args: [String]) -> (status: Int32, out: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { fail("couldn't run \(path): \(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
}

func privateKey(kid: String) -> Curve25519.Signing.PrivateKey {
    let b64: String
    if let env = ProcessInfo.processInfo.environment["HALO_LICENCE_SIGNING_KEY"], !env.isEmpty {
        b64 = env
    } else {
        let r = run("/usr/bin/security", ["find-generic-password", "-s", signingService, "-a", kid, "-w"])
        guard r.status == 0 else { fail("no signing key for \(kid) in the login Keychain (service \(signingService)). See docs/LICENCE_KEYS.md.") }
        b64 = r.out
    }
    guard let raw = Data(base64Encoded: b64), let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
        fail("the signing key for \(kid) isn't a base64 raw Ed25519 key")
    }
    return key
}

func trustedPublicKeys() -> [String: Data] {
    let script = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let candidates = [
        script.deletingLastPathComponent().appendingPathComponent("../Sources/Cloud/Licence/LicenceVerifier.swift"),
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/Cloud/Licence/LicenceVerifier.swift"),
    ]
    guard let source = candidates.lazy.compactMap({ try? String(contentsOf: $0, encoding: .utf8) }).first else {
        fail("can't find Sources/Cloud/Licence/LicenceVerifier.swift; run from the repo root")
    }
    let regex = try! NSRegularExpression(pattern: #""(kid-[A-Za-z0-9-]+)"\s*:\s*"([A-Za-z0-9+/=]+)""#)
    var keys: [String: Data] = [:]
    for m in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
        let kid = String(source[Range(m.range(at: 1), in: source)!])
        if let raw = Data(base64Encoded: String(source[Range(m.range(at: 2), in: source)!])) { keys[kid] = raw }
    }
    return keys
}

// MARK: Commands

func options(_ args: ArraySlice<String>) -> [String: String] {
    var out: [String: String] = [:]
    var it = args.makeIterator()
    while let a = it.next() {
        guard a.hasPrefix("--") else { fail("unexpected argument \(a)") }
        let name = String(a.dropFirst(2))
        if name == "perpetual" { out[name] = "1"; continue }
        guard let v = it.next() else { fail("--\(name) needs a value") }
        out[name] = v
    }
    return out
}

func issue(_ args: ArraySlice<String>) {
    let o = options(args)
    let plan = o["plan"] ?? "pro"
    guard plan == "pro" || plan == "team" else { fail("--plan is pro or team") }
    guard let seats = Int(o["seats"] ?? "1"), seats >= 1 else { fail("--seats is a positive number") }
    let kid = o["kid"] ?? defaultKid
    var iat = Int64(Date().timeIntervalSince1970)
    if let given = o["issued-at"] {
        guard let v = Int64(given) else { fail("--issued-at is unix seconds") }
        iat = v
    }
    var exp: Int64?
    if o["perpetual"] == nil {
        guard let days = Int(o["days"] ?? "365"), days >= 1 else { fail("--days is a positive number") }
        exp = iat + Int64(days) * 86_400
    }
    var rng = SystemRandomNumberGenerator()
    let lid = o["lid"] ?? "L-" + String((0..<10).map { _ in alphabet[Int(rng.next() % 32)] })
    let payload = canonicalPayload(kid: kid, lid: lid, plan: plan, seats: seats, iat: iat, exp: exp,
                                   emailHint: o["email"].map(emailHint))
    let key = privateKey(kid: kid)
    guard let sig = try? key.signature(for: payload) else { fail("signing failed") }
    print(encodeKey(payload: payload, signature: sig))
}

func verify(_ args: ArraySlice<String>) {
    guard !args.isEmpty else { fail("verify <key>") }
    let text = args.joined(separator: "")
    guard let parts = decodeKey(text) else { print("malformed"); exit(2) }
    guard let json = try? JSONSerialization.jsonObject(with: parts.payload) as? [String: Any],
          let kid = json["kid"] as? String else { print("malformed"); exit(2) }
    guard let raw = trustedPublicKeys()[kid], let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else {
        print("unknownKey \(kid)"); exit(3)
    }
    guard pub.isValidSignature(parts.signature, for: parts.payload) else { print("badSignature"); exit(4) }
    let now = Date().timeIntervalSince1970
    let iat = (json["iat"] as? NSNumber)?.doubleValue ?? 0
    let exp = (json["exp"] as? NSNumber)?.doubleValue
    let state = iat - now > 300 ? "notYetValid" : (exp.map { now >= $0 } ?? false) ? "expired" : "valid"
    print(state)
    print(String(decoding: parts.payload, as: UTF8.self))
    exit(state == "valid" ? 0 : 5)
}

func keygen(_ args: ArraySlice<String>) {
    let o = options(args)
    guard let kid = o["kid"], kid.hasPrefix("kid-") else { fail("keygen --kid kid-YYYY-N") }
    let key = Curve25519.Signing.PrivateKey()
    let r = run("/usr/bin/security", ["add-generic-password", "-s", signingService, "-a", kid,
                                      "-l", "Halo licence signing key (\(kid))",
                                      "-w", key.rawRepresentation.base64EncodedString()])
    guard r.status == 0 else { fail("couldn't store the key (does \(kid) already exist?)") }
    print("Stored the private key for \(kid) in the login Keychain (service \(signingService)).")
    print("Add this line to LicenceTrustedKeys.all in Sources/Cloud/Licence/LicenceVerifier.swift:")
    print("        \"\(kid)\": \"\(key.publicKey.rawRepresentation.base64EncodedString())\",")
}

let argv = CommandLine.arguments.dropFirst()
switch argv.first {
case "issue": issue(argv.dropFirst())
case "verify": verify(argv.dropFirst())
case "keygen": keygen(argv.dropFirst())
default:
    fail("usage: licence-tool.swift issue --plan pro|team --seats N --days N [--kid K] [--email E] [--perpetual] | verify <key> | keygen --kid K", code: 64)
}
