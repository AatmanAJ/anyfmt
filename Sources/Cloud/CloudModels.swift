import Foundation
import CryptoKit
import HaloCore

// Wire types for Server/openapi.yaml. Field names match the contract
// (camelCase), except the OAuth token response, which is RFC 6749 snake_case.

/// Arbitrary JSON, used for sync documents the server stores opaquely.
enum CloudJSON: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([CloudJSON])
    case object([String: CloudJSON])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([CloudJSON].self) { self = .array(a) }
        else if let o = try? c.decode([String: CloudJSON].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "not JSON") }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(CloudJSON.self, from: data)
    }

    /// Key-sorted serialisation, so equal documents hash equally whatever their key order.
    func canonicalData() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try e.encode(self)
    }

    func canonicalHash() -> String {
        let data = (try? canonicalData()) ?? Data()
        return CloudHash.hex(SHA256.hash(data: data))
    }

    var stringValue: String? { if case .string(let s) = self { s } else { nil } }
    var numberValue: Double? { if case .number(let n) = self { n } else { nil } }
    subscript(key: String) -> CloudJSON? { if case .object(let o) = self { o[key] } else { nil } }
}

enum CloudHash {
    static func hex<D: Digest>(_ digest: D) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Streams a file through SHA-256 in 4 MiB reads.
    static func sha256(of file: URL, progress: (@Sendable (Double) -> Void)? = nil) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let total = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Double.init) ?? 0
        var hasher = SHA256()
        var done = 0.0
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount: 4 * 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
            done += Double(chunk.count)
            if total > 0 { progress?(done / total) }
        }
        return hex(hasher.finalize())
    }
}

// MARK: - Meta + auth

struct CloudHealth: Decodable, Sendable, Equatable {
    let status: String
    let api: String
    let name: String?
    let version: String?
    let selfHosted: Bool?
    let capabilities: [String]?
}

struct CloudTokenResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let deviceID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case deviceID = "device_id"
    }
}

struct CloudOAuthError: Decodable, Sendable {
    let error: String
    let errorDescription: String?
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

/// Tokens for one server. Stored only in the Keychain; never logged
/// (`description` is redacted).
struct CloudCredentials: Codable, Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    var accessToken: String
    var refreshToken: String
    var accessTokenExpiresAt: Date
    var deviceID: String?

    init(_ response: CloudTokenResponse, now: Date = Date()) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken
        accessTokenExpiresAt = now.addingTimeInterval(TimeInterval(max(0, response.expiresIn)))
        deviceID = response.deviceID
    }

    init(accessToken: String, refreshToken: String, accessTokenExpiresAt: Date, deviceID: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.deviceID = deviceID
    }

    func needsRefresh(now: Date = Date()) -> Bool {
        accessTokenExpiresAt.timeIntervalSince(now) < CloudConfig.accessTokenLeeway
    }

    var description: String { "CloudCredentials(redacted)" }
    var debugDescription: String { description }
}

// MARK: - Account

struct CloudUserDTO: Codable, Sendable, Equatable {
    let id: String
    let email: String
    let name: String?
    let teamName: String?
}

struct CloudQuotas: Codable, Sendable, Equatable {
    var shareLinksPerMonth: Int?
    var shareLinksUsed: Int?
    var shareLinkMaxExpiryHours: Int?
    var shareLinkMaxDownloads: Int?
    var maxUploadBytes: Int64?
    var storageBytes: Int64?
    var storageUsedBytes: Int64?
    var cloudJobMinutesPerMonth: Int?
    var cloudJobMinutesUsed: Double?
    var pollIntervalSeconds: Int?
    var periodResetsAt: Date?

    static let none = CloudQuotas()
}

struct CloudEntitlementsDTO: Codable, Sendable, Equatable {
    let plan: String
    let features: [String]
    let quotas: CloudQuotas
    let customDomains: [String]?
}

struct CloudAccountDTO: Codable, Sendable, Equatable {
    let user: CloudUserDTO
    let entitlements: CloudEntitlementsDTO
}

struct CloudDevice: Decodable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let createdAt: Date
    let lastSeenAt: Date
    let current: Bool
}

// MARK: - Uploads

struct CloudUploadCreate: Encodable, Sendable {
    let filename: String
    let size: Int64
    let contentType: String
    let sha256: String
    let purpose: String
}

struct CloudUpload: Decodable, Sendable, Equatable {
    let id: String
    let filename: String?
    let size: Int64
    let offset: Int64
    let status: String
    let maxChunkSize: Int64
    let sha256: String?
    let expiresAt: Date?

    var isComplete: Bool { status == "complete" }
}

// MARK: - Share links

struct CloudShareLinkCreate: Encodable, Sendable {
    let uploadIds: [String]
    let title: String?
    let expiresInHours: Int?
    let password: String?
    let maxDownloads: Int?
    let customDomain: String?

    // Explicit nulls matter: `expiresInHours: null` means "never".
    enum CodingKeys: String, CodingKey { case uploadIds, title, expiresInHours, password, maxDownloads, customDomain }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uploadIds, forKey: .uploadIds)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encode(expiresInHours, forKey: .expiresInHours)
        try c.encodeIfPresent(password, forKey: .password)
        try c.encode(maxDownloads, forKey: .maxDownloads)
        try c.encodeIfPresent(customDomain, forKey: .customDomain)
    }
}

struct CloudShareLink: Decodable, Sendable, Equatable, Identifiable {
    struct File: Decodable, Sendable, Equatable {
        let name: String
        let size: Int64
    }

    let id: String
    let url: URL
    let title: String?
    let createdAt: Date
    let expiresAt: Date?
    let maxDownloads: Int?
    let downloads: Int
    let hasPassword: Bool
    let customDomain: String?
    let revoked: Bool?
    let files: [File]
}

struct CloudShareLinkStats: Decodable, Sendable, Equatable {
    let linkId: String
    let views: Int
    let downloads: Int
    let lastDownloadAt: Date?
}

struct CloudPage<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let nextCursor: String?
}

// MARK: - Jobs

/// What a cloud job does. Mirrors `JobOperation` in the contract.
enum CloudJobOperation: Sendable, Equatable {
    /// Heavy conversion (the video options schema's `cloud` toggle).
    case convert(target: FormatID, options: OptionValues)
    /// A Pro tool: `ToolIDs.transcribe`, `.upscale`, `.removeBackgroundHQ`.
    case tool(ToolID, target: FormatID?, options: OptionValues)

    var feature: CloudFeature {
        switch self {
        case .convert: return .cloudJobs
        case .tool(let tool, _, _):
            return ToolCatalog.spec(tool)?.cloudFeature ?? .cloudJobs
        }
    }

    var target: FormatID? {
        switch self {
        case .convert(let t, _): t
        case .tool(_, let t, _): t
        }
    }
}

struct CloudJobOperationDTO: Codable, Sendable, Equatable {
    let type: String
    let target: String?
    let tool: String?
    let options: [String: CloudJSON]?

    init(_ op: CloudJobOperation) {
        func json(_ values: OptionValues) -> [String: CloudJSON] {
            // `cloud` is the client's own "run this in the cloud" switch, not an engine option.
            values.values.filter { $0.key != OptionKey.cloud }.mapValues { v in
                switch v {
                case .bool(let b): .bool(b)
                case .int(let i): .number(Double(i))
                case .double(let d): .number(d)
                case .string(let s): .string(s)
                }
            }
        }
        switch op {
        case .convert(let target, let options):
            type = "convert"; self.target = target.rawValue; tool = nil; self.options = json(options)
        case .tool(let id, let target, let options):
            type = "tool"; tool = id.rawValue; self.target = target?.rawValue; self.options = json(options)
        }
    }
}

struct CloudJobCreate: Encodable, Sendable {
    let uploadId: String
    let operation: CloudJobOperationDTO
    let clientReference: String?
}

struct CloudJobDTO: Decodable, Sendable, Equatable {
    enum Status: String, Decodable, Sendable {
        case queued, running, succeeded, failed, cancelled
        case unknown
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Status(rawValue: raw) ?? .unknown
        }
        var isTerminal: Bool { self == .succeeded || self == .failed || self == .cancelled }
    }

    struct Result: Decodable, Sendable, Equatable {
        let name: String
        let size: Int64
        let sha256: String
        let contentType: String?
        let downloadUrl: URL
    }

    struct Failure: Decodable, Sendable, Equatable {
        let code: String?
        let message: String?
    }

    let id: String
    let status: Status
    let progress: Double
    let stage: String?
    let pollAfterMs: Int?
    let results: [Result]?
    let error: Failure?
}

// MARK: - Sync

struct CloudSyncDocumentHead: Decodable, Sendable, Equatable {
    let namespace: String
    let version: Int
    let updatedAt: Date
    let updatedBy: String?
}

struct CloudSyncDocument: Decodable, Sendable, Equatable {
    let namespace: String
    let version: Int
    let updatedAt: Date
    let updatedBy: String?
    let data: CloudJSON
}

struct CloudSyncWrite: Encodable, Sendable {
    let data: CloudJSON
    let deviceName: String?
}

/// Result of a conditional PUT.
enum CloudSyncWriteResult: Sendable, Equatable {
    case stored(CloudSyncDocument)
    /// `409 version_conflict`; `current` is the server copy (nil if it was deleted).
    case conflict(current: CloudSyncDocument?)
}

struct CloudSyncConflictBody: Decodable, Sendable {
    let current: CloudSyncDocument?
}

// MARK: - Inbox

struct CloudInboxItem: Decodable, Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let size: Int64
    let sha256: String
    let contentType: String?
    let source: String?
    let note: String?
    let status: String
    let createdAt: Date
    let downloadUrl: URL
}

// MARK: - Errors

struct CloudErrorBody: Decodable, Sendable {
    struct Inner: Decodable, Sendable {
        let code: String
        let message: String?
        let requestId: String?
        let details: CloudJSON?
    }
    let error: Inner
    let offset: Int64?
}

// MARK: - Coding

enum CloudCoding {
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = try? Date(s, strategy: .iso8601) { return date }
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "bad date \(s)")
        }
        return d
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }
}

/// Safe local file names for names that came from a server.
enum CloudFileName {
    /// Takes the last path component, drops leading dots (no hidden files),
    /// control characters and characters macOS doesn't allow.
    static func sanitize(_ name: String, fallback: String = "Untitled") -> String {
        let last = name.split(whereSeparator: { $0 == "/" || $0 == "\\" || $0 == ":" }).last.map(String.init) ?? ""
        var s = String(last.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
        while s.hasPrefix(".") { s.removeFirst() }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > 200 { s = String(s.prefix(200)) }
        return s.isEmpty ? fallback : s
    }

    /// Splits a sanitised name into (base, extension) for `OutputNamer.place`.
    static func split(_ name: String) -> (base: String, ext: String) {
        let url = URL(fileURLWithPath: name)
        let lower = name.lowercased()
        if lower.hasSuffix(".tar.gz") {
            return (String(name.dropLast(7)), "tar.gz")
        }
        let ext = url.pathExtension
        let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        return (base.isEmpty ? name : base, base.isEmpty ? "" : ext)
    }
}
