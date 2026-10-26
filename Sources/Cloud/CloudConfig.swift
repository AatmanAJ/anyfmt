import Foundation
import AnyfmtCore

/// Constants for the cloud client (BUILD.md §9b).
///
/// Everything here is local configuration. Nothing in this file talks to a
/// server; see `CloudAPIClient` for the single network choke point.
enum CloudConfig {
    /// The hosted server the app points at until the user changes Settings ›
    /// Account › Server URL.
    ///
    /// BLOCKER (docs/lanes/I-cloud.md): a placeholder on the reserved
    /// `.invalid` TLD so it can never resolve. AJ replaces this one constant
    /// when the hosted server exists.
    static let defaultServer = staticURL("https://cloud.example.invalid")

    /// OAuth client id the server registers for the Mac app.
    static var clientID: String { "\(Brand.slug)-mac" }
    /// Where the browser hands the authorization code back. The app target
    /// already declares `Brand.urlScheme` in CFBundleURLTypes.
    static var redirectURI: String { "\(Brand.urlScheme)://auth/callback" }
    static var keychainService: String { "\(Brand.bundleID).cloud" }

    /// Upload chunk size. The server may ask for smaller chunks (`maxChunkSize`).
    static let uploadChunkSize = 8 * 1024 * 1024
    static let inboxDefaultIntervalMinutes = 5
    static let syncDebounce: Duration = .seconds(2)
    static let requestTimeout: TimeInterval = 60
    /// A browser sign-in the user started but never finished stops being
    /// redeemable after this long.
    static let pendingSignInLifetime: TimeInterval = 15 * 60
    /// Refresh the access token this long before it expires.
    static let accessTokenLeeway: TimeInterval = 30

    static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "\(Brand.name)/\(version) (macOS)"
    }

    static func staticURL(_ literal: StaticString) -> URL {
        guard let url = URL(string: "\(literal)") else { preconditionFailure("invalid URL literal \(literal)") }
        return url
    }
}

/// Server URL parsing and identity (`origin`, keychain account).
enum CloudServerAddress {
    enum Problem: Error, Equatable, Sendable {
        case empty
        case malformed
        /// Plain http is only allowed for this Mac (localhost), e.g. a self-host dev box or the mock.
        case insecure
        case hasQueryOrFragment

        var message: String {
            switch self {
            case .empty: String(localized: "Enter a server address.")
            case .malformed: String(localized: "That doesn’t look like a server address.")
            case .insecure: String(localized: "Use an https:// address. Plain http only works for servers on this Mac.")
            case .hasQueryOrFragment: String(localized: "Remove the ? or # part of the address.")
            }
        }
    }

    /// Normalises user input: adds https:// when no scheme is given, drops a
    /// trailing slash, keeps a path prefix (reverse proxies like /anyfmt).
    static func parse(_ text: String) -> Result<URL, Problem> {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return .failure(.empty) }
        if !s.contains("://") { s = "https://" + s }
        guard var comps = URLComponents(string: s), let scheme = comps.scheme?.lowercased(),
              let host = comps.host, !host.isEmpty else { return .failure(.malformed) }
        guard comps.query == nil, comps.fragment == nil else { return .failure(.hasQueryOrFragment) }
        guard comps.user == nil, comps.password == nil else { return .failure(.malformed) }
        switch scheme {
        case "https": break
        case "http": guard isLoopback(host) else { return .failure(.insecure) }
        default: return .failure(.malformed)
        }
        comps.scheme = scheme
        comps.host = host.lowercased()
        while comps.path.hasSuffix("/") { comps.path.removeLast() }
        guard let url = comps.url else { return .failure(.malformed) }
        return .success(url)
    }

    static func isLoopback(_ host: String) -> Bool {
        let h = host.lowercased()
        return h == "localhost" || h == "127.0.0.1" || h == "::1" || h == "[::1]" || h.hasSuffix(".localhost")
    }

    /// scheme://host:port. Bearer tokens are only ever sent to this origin.
    static func origin(of url: URL) -> String {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let port = url.port ?? (scheme == "https" ? 443 : scheme == "http" ? 80 : 0)
        return "\(scheme)://\(host):\(port)"
    }

    /// Keychain account (and preference key) for a server: host, port and path prefix.
    static func accountKey(for server: URL) -> String {
        var key = server.host?.lowercased() ?? "server"
        if let port = server.port { key += ":\(port)" }
        let path = server.path
        if !path.isEmpty, path != "/" { key += path }
        return key
    }

    /// What the UI calls the server: "cloud.example.invalid", "127.0.0.1:8787".
    static func displayName(for server: URL) -> String {
        accountKey(for: server)
    }

    static func isDefault(_ server: URL) -> Bool {
        accountKey(for: server) == accountKey(for: CloudConfig.defaultServer)
    }
}

/// A small lock box. The cloud stack shares a little mutable state between
/// the main actor (UI) and background tasks (uploads, polling).
final class CloudLocked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }

    var current: Value { withLock { $0 } }
}
