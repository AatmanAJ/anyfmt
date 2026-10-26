import Foundation
import os
import AnyfmtCore

/// Makes the one URLSession the cloud stack uses. Injectable so tests can
/// register recording URLProtocols and count sessions.
protocol CloudSessionFactory: Sendable {
    func makeSession(delegate: URLSessionDelegate) -> URLSession
}

/// Ephemeral: no cookies, no disk cache, credentials in memory only.
struct CloudDefaultSessionFactory: CloudSessionFactory {
    var configure: @Sendable (URLSessionConfiguration) -> Void = { _ in }

    func makeSession(delegate: URLSessionDelegate) -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.urlCache = nil
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.timeoutIntervalForRequest = CloudConfig.requestTimeout
        c.waitsForConnectivity = false
        c.httpAdditionalHeaders = ["User-Agent": CloudConfig.userAgent, "Accept": "application/json"]
        configure(c)
        return URLSession(configuration: c, delegate: delegate, delegateQueue: nil)
    }
}

struct CloudRequest: Sendable {
    var method: String
    /// Path below the server URL, e.g. "/v1/me".
    var path: String
    var query: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data?
    var access: CloudAccess = .authenticated

    static func json<T: Encodable>(_ method: String, _ path: String, _ value: T, headers: [String: String] = [:]) throws -> CloudRequest {
        var h = headers
        h["Content-Type"] = "application/json"
        return CloudRequest(method: method, path: path, headers: h, body: try CloudCoding.encoder().encode(value))
    }

    static func form(_ path: String, _ fields: [String: String], access: CloudAccess) -> CloudRequest {
        var c = URLComponents()
        c.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        // URLComponents leaves "+" alone; a form body must encode it.
        let body = (c.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
        return CloudRequest(method: "POST", path: path, headers: ["Content-Type": "application/x-www-form-urlencoded"],
                            body: Data(body.utf8), access: access)
    }
}

struct CloudResponse: Sendable {
    let data: Data
    let http: HTTPURLResponse
    var status: Int { http.statusCode }
    func header(_ name: String) -> String? { http.value(forHTTPHeaderField: name) }
    var requestID: String? { header("X-Request-Id") }
    var isSuccess: Bool { (200..<300).contains(status) }
}

/// The only code in the app that sends HTTP requests (see `send`).
///
/// - Every request passes `CloudNetworkGate` first; signed out, nothing but
///   the user-initiated health check and a pending sign-in's code exchange
///   gets through, and the URLSession isn't even created until a request
///   is allowed.
/// - Bearer tokens are attached only for the configured server's origin.
/// - A 401 triggers one refresh (single-flight) and one retry.
/// - Every request is logged (method, path, status, time, request id);
///   never headers, bodies, query strings or tokens.
actor CloudAPIClient {
    private let state: CloudState
    private let vault: CloudCredentialVault
    private let factory: any CloudSessionFactory
    private let logObserver: (@Sendable (String) -> Void)?
    private var session: URLSession?
    private var refreshTask: Task<CloudCredentials, Error>?
    private let logger = Log.cloud

    init(state: CloudState, vault: CloudCredentialVault, factory: any CloudSessionFactory = CloudDefaultSessionFactory(),
         logObserver: (@Sendable (String) -> Void)? = nil) {
        self.state = state
        self.vault = vault
        self.factory = factory
        self.logObserver = logObserver
    }

    /// True once a request has been allowed through the gate (tests assert it stays false signed out).
    var hasSession: Bool { session != nil }

    private func urlSession() -> URLSession {
        if let session { return session }
        let s = factory.makeSession(delegate: CloudTaskDelegate())
        session = s
        return s
    }

    // MARK: Core

    /// Sends `request` for `trigger`. The single choke point.
    func send(_ request: CloudRequest, trigger: CloudTrigger, server overrideServer: URL? = nil,
              uploadProgress: (@Sendable (Int64) -> Void)? = nil) async throws -> CloudResponse {
        var retried = false
        while true {
            let snap = state.snapshot
            try CloudNetworkGate.check(trigger, request.access, snap)
            let server = overrideServer ?? snap.server
            var urlRequest = try makeURLRequest(request, server: server)
            var usedToken: String?
            if request.access == .authenticated {
                let creds = try await validCredentials(server: server)
                urlRequest.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
                usedToken = creds.accessToken
            }
            let response = try await transport(urlRequest, upload: uploadProgress)
            if response.status == 401, let usedToken, !retried {
                retried = true
                _ = try await validCredentials(server: server, rejecting: usedToken)
                continue
            }
            if response.status == 401, usedToken != nil {
                // Refreshed and still refused: the server ended this session.
                signOutLocally(server: server)
                throw CloudError.sessionExpired
            }
            return response
        }
    }

    /// Downloads `url` into `destination` (a path inside a temp directory we own).
    func download(_ url: URL, to destination: URL, trigger: CloudTrigger,
                  progress: (@Sendable (Int64, Int64) -> Void)? = nil) async throws {
        let snap = state.snapshot
        try CloudNetworkGate.check(trigger, .signedDownload, snap)
        var request = URLRequest(url: url, timeoutInterval: CloudConfig.requestTimeout)
        if CloudServerAddress.origin(of: url) == CloudServerAddress.origin(of: snap.server) {
            let creds = try await validCredentials(server: snap.server)
            request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        }
        let session = urlSession()
        let path = Self.loggablePath(url)
        let started = ContinuousClock.now
        emit("→ GET \(path) [\(trigger)]")
        let delegate = CloudDownloadDelegate(destination: destination, progress: progress)
        let task = session.downloadTask(with: request)
        task.delegate = delegate
        let http: HTTPURLResponse
        do {
            http = try await withTaskCancellationHandler {
                try await delegate.run(task)
            } onCancel: {
                task.cancel()
            }
        } catch {
            emit("✗ GET \(path) \(Self.describe(error))")
            throw Self.map(error, host: url.host ?? "")
        }
        emit("← \(http.statusCode) GET \(path) \(Self.ms(since: started))ms req=\(http.value(forHTTPHeaderField: "X-Request-Id") ?? "-")")
        guard (200..<300).contains(http.statusCode) else {
            let body = (try? Data(contentsOf: destination)) ?? Data()
            try? FileManager.default.removeItem(at: destination)
            throw Self.error(from: CloudResponse(data: body, http: http))
        }
    }

    private func makeURLRequest(_ r: CloudRequest, server: URL) throws -> URLRequest {
        guard var comps = URLComponents(url: server, resolvingAgainstBaseURL: false) else {
            throw CloudError.invalidResponse("bad server URL")
        }
        comps.path = (comps.path.hasSuffix("/") ? String(comps.path.dropLast()) : comps.path) + r.path
        if !r.query.isEmpty { comps.queryItems = r.query }
        guard let url = comps.url else { throw CloudError.invalidResponse("bad path \(r.path)") }
        var req = URLRequest(url: url, timeoutInterval: CloudConfig.requestTimeout)
        req.httpMethod = r.method
        for (k, v) in r.headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = r.body
        return req
    }

    private func transport(_ request: URLRequest, upload: (@Sendable (Int64) -> Void)?) async throws -> CloudResponse {
        let session = urlSession()
        let method = request.httpMethod ?? "GET"
        let path = request.url.map(Self.loggablePath) ?? "?"
        let started = ContinuousClock.now
        emit("→ \(method) \(path)")
        do {
            let data: Data
            let response: URLResponse
            if let upload, let body = request.httpBody {
                var r = request
                r.httpBody = nil
                (data, response) = try await session.upload(for: r, from: body, delegate: CloudUploadProgressDelegate(onSent: upload))
            } else {
                (data, response) = try await session.data(for: request)
            }
            guard let http = response as? HTTPURLResponse else { throw CloudError.invalidResponse("not HTTP") }
            emit("← \(http.statusCode) \(method) \(path) \(Self.ms(since: started))ms req=\(http.value(forHTTPHeaderField: "X-Request-Id") ?? "-")")
            return CloudResponse(data: data, http: http)
        } catch {
            emit("✗ \(method) \(path) \(Self.describe(error))")
            throw Self.map(error, host: request.url?.host ?? "")
        }
    }

    private func emit(_ line: String) {
        logger.info("\(line, privacy: .public)")
        logObserver?(line)
    }

    /// Path only: never the query string (signed URLs and codes live there).
    static func loggablePath(_ url: URL) -> String {
        let host = url.host ?? ""
        let port = url.port.map { ":\($0)" } ?? ""
        return "\(host)\(port)\(url.path)"
    }

    private static func ms(since start: ContinuousClock.Instant) -> Int {
        let d = ContinuousClock.now - start
        return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
    }

    private static func describe(_ error: Error) -> String {
        if let u = error as? URLError { return "URLError \(u.code.rawValue)" }
        if error is CancellationError { return "cancelled" }
        return String(describing: type(of: error))
    }

    static func map(_ error: Error, host: String) -> Error {
        if error is CancellationError { return error }
        if let e = error as? CloudError { return e }
        guard let u = error as? URLError else { return error }
        switch u.code {
        case .cancelled: return CancellationError()
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff: return CloudError.offline
        // A dropped connection mid-transfer: uploads resume from the server's offset.
        case .networkConnectionLost: return CloudError.connectionLost
        // DNS, refused, timed out, TLS trust, ATS…: all "couldn't reach the server" to a person.
        default: return CloudError.serverUnreachable(host)
        }
    }

    // MARK: Tokens

    /// A non-expired access token, refreshing (once, shared by concurrent callers) if needed.
    /// `rejecting`: the token a 401 just refused; refresh unless someone already replaced it.
    private func validCredentials(server: URL, rejecting: String? = nil) async throws -> CloudCredentials {
        guard let creds = state.snapshot.credentials else { throw CloudError.signedOut }
        let mustRefresh = rejecting.map { $0 == creds.accessToken } ?? creds.needsRefresh()
        if !mustRefresh { return creds }
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await self.performRefresh(creds, server: server) }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh(_ creds: CloudCredentials, server: URL) async throws -> CloudCredentials {
        let req = CloudRequest.form("/v1/auth/token", [
            "grant_type": "refresh_token",
            "refresh_token": creds.refreshToken,
            "client_id": CloudConfig.clientID,
        ], access: .authenticated)
        let response = try await transport(try makeURLRequest(req, server: server), upload: nil)
        if response.status == 400 || response.status == 401 {
            // invalid_grant: revoked, expired or reused. The account is gone from this Mac.
            signOutLocally(server: server)
            throw CloudError.sessionExpired
        }
        guard response.isSuccess else { throw Self.error(from: response) }
        let token = try CloudCoding.decoder().decode(CloudTokenResponse.self, from: response.data)
        let fresh = CloudCredentials(token)
        try vault.save(fresh, for: server)
        state.update { if CloudServerAddress.isSame($0.server, server) { $0.credentials = fresh } }
        emit("token refreshed")
        return fresh
    }

    private func signOutLocally(server: URL) {
        vault.remove(for: server)
        state.update {
            guard CloudServerAddress.isSame($0.server, server) else { return }
            $0.credentials = nil
            $0.lastError = CloudError.sessionExpired.errorDescription
        }
    }

    // MARK: Errors

    static func error(from r: CloudResponse) -> CloudError {
        let body = try? CloudCoding.decoder().decode(CloudErrorBody.self, from: r.data)
        let code = body?.error.code
        let message = body?.error.message
        let rid = body?.error.requestId ?? r.requestID
        switch (r.status, code) {
        case (401, _): return .sessionExpired
        case (402, _):
            let resets = body?.error.details?["resetsAt"]?.stringValue.flatMap { try? Date($0, strategy: .iso8601) }
            return .quotaExceeded(message: message ?? String(localized: "You’ve reached this month’s limit."), resetsAt: resets)
        case (403, "feature_not_in_plan"):
            if let f = body?.error.details?["feature"]?.stringValue.flatMap(CloudFeature.init(rawValue:)) { return .notEntitled(f) }
            return .server(status: 403, code: code, message: message, requestID: rid)
        case (404, _), (410, _): return .notFound
        case (413, _):
            return .payloadTooLarge(maxBytes: body?.error.details?["maxBytes"]?.numberValue.map { Int64($0) })
        case (422, "checksum_mismatch"): return .checksumMismatch
        case (429, _), (503, "server_busy"):
            return .rateLimited(retryAfter: r.header("Retry-After").flatMap(TimeInterval.init))
        default: return .server(status: r.status, code: code, message: message, requestID: rid)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, _ r: CloudResponse) throws -> T {
        guard r.isSuccess else { throw Self.error(from: r) }
        do { return try CloudCoding.decoder().decode(T.self, from: r.data) } catch {
            throw CloudError.invalidResponse("\(T.self): \(error)")
        }
    }
}

extension CloudServerAddress {
    static func isSame(_ a: URL, _ b: URL) -> Bool { accountKey(for: a) == accountKey(for: b) }
}

// MARK: - Typed endpoints (Server/openapi.yaml)

extension CloudAPIClient {
    func health(server: URL) async throws -> CloudHealth {
        let r = try await send(CloudRequest(method: "GET", path: "/v1/health", access: .probe), trigger: .user, server: server)
        return try decode(CloudHealth.self, r)
    }

    func exchange(code: String, verifier: String, server: URL, deviceName: String) async throws -> CloudCredentials {
        let req = CloudRequest.form("/v1/auth/token", [
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": CloudConfig.redirectURI,
            "client_id": CloudConfig.clientID,
            "device_name": deviceName,
        ], access: .codeExchange)
        let r = try await send(req, trigger: .signIn, server: server)
        if r.status == 400 {
            let oauth = try? CloudCoding.decoder().decode(CloudOAuthError.self, from: r.data)
            throw CloudError.signInFailed(oauth?.errorDescription ?? String(localized: "That sign-in link has expired. Try again."))
        }
        return CloudCredentials(try decode(CloudTokenResponse.self, r))
    }

    func revoke(refreshToken: String, server: URL) async throws {
        let req = CloudRequest.form("/v1/auth/revoke", [
            "token": refreshToken, "token_type_hint": "refresh_token", "client_id": CloudConfig.clientID,
        ], access: .revocation)
        _ = try await send(req, trigger: .user, server: server)
    }

    func me(trigger: CloudTrigger) async throws -> CloudAccountDTO {
        try decode(CloudAccountDTO.self, try await send(CloudRequest(method: "GET", path: "/v1/me"), trigger: trigger))
    }

    func devices() async throws -> [CloudDevice] {
        try decode(CloudPage<CloudDevice>.self, try await send(CloudRequest(method: "GET", path: "/v1/devices"), trigger: .user)).items
    }

    // Uploads

    func createUpload(_ body: CloudUploadCreate, trigger: CloudTrigger) async throws -> CloudUpload {
        try decode(CloudUpload.self, try await send(try .json("POST", "/v1/uploads", body), trigger: trigger))
    }

    /// Committed offset (`HEAD`), or nil if the upload is gone.
    func uploadOffset(_ id: String, trigger: CloudTrigger) async throws -> Int64? {
        let r = try await send(CloudRequest(method: "HEAD", path: "/v1/uploads/\(id)"), trigger: trigger)
        if r.status == 404 || r.status == 410 { return nil }
        guard r.isSuccess, let s = r.header("Upload-Offset"), let off = Int64(s) else { throw Self.error(from: r) }
        return off
    }

    func upload(_ id: String, trigger: CloudTrigger) async throws -> CloudUpload? {
        let r = try await send(CloudRequest(method: "GET", path: "/v1/uploads/\(id)"), trigger: trigger)
        if r.status == 404 || r.status == 410 { return nil }
        return try decode(CloudUpload.self, r)
    }

    enum ChunkResult: Sendable, Equatable {
        case committed(offset: Int64)
        /// 409 offset_mismatch: continue from the server's offset.
        case mismatch(offset: Int64)
        case gone
    }

    func putChunk(_ id: String, data: Data, offset: Int64, total: Int64, trigger: CloudTrigger,
                  progress: (@Sendable (Int64) -> Void)?) async throws -> ChunkResult {
        let last = offset + Int64(data.count) - 1
        let req = CloudRequest(method: "PUT", path: "/v1/uploads/\(id)", headers: [
            "Content-Type": "application/octet-stream",
            "Content-Range": "bytes \(offset)-\(last)/\(total)",
            "Upload-Offset": String(offset),
        ], body: data)
        let r = try await send(req, trigger: trigger, uploadProgress: progress ?? { _ in })
        switch r.status {
        case 200..<300:
            if let s = r.header("Upload-Offset"), let off = Int64(s) { return .committed(offset: off) }
            return .committed(offset: try decode(CloudUpload.self, r).offset)
        case 409:
            let body = try? CloudCoding.decoder().decode(CloudErrorBody.self, from: r.data)
            if let off = body?.offset ?? r.header("Upload-Offset").flatMap(Int64.init) { return .mismatch(offset: off) }
            throw Self.error(from: r)
        case 404, 410: return .gone
        default: throw Self.error(from: r)
        }
    }

    func completeUpload(_ id: String, sha256: String, trigger: CloudTrigger) async throws -> CloudUpload {
        struct Body: Encodable { let sha256: String }
        return try decode(CloudUpload.self, try await send(try .json("POST", "/v1/uploads/\(id)/complete", Body(sha256: sha256)), trigger: trigger))
    }

    func abortUpload(_ id: String, trigger: CloudTrigger) async throws {
        _ = try await send(CloudRequest(method: "DELETE", path: "/v1/uploads/\(id)"), trigger: trigger)
    }

    // Share links

    func createLink(_ body: CloudShareLinkCreate) async throws -> CloudShareLink {
        try decode(CloudShareLink.self, try await send(try .json("POST", "/v1/links", body), trigger: .user))
    }

    func links() async throws -> [CloudShareLink] {
        try decode(CloudPage<CloudShareLink>.self, try await send(CloudRequest(method: "GET", path: "/v1/links"), trigger: .user)).items
    }

    func revokeLink(_ id: String) async throws {
        let r = try await send(CloudRequest(method: "DELETE", path: "/v1/links/\(id)"), trigger: .user)
        guard r.isSuccess else { throw Self.error(from: r) }
    }

    func linkStats(_ id: String) async throws -> CloudShareLinkStats {
        try decode(CloudShareLinkStats.self, try await send(CloudRequest(method: "GET", path: "/v1/links/\(id)/stats"), trigger: .user))
    }

    // Jobs

    func createJob(_ body: CloudJobCreate) async throws -> CloudJobDTO {
        try decode(CloudJobDTO.self, try await send(try .json("POST", "/v1/jobs", body), trigger: .user))
    }

    func job(_ id: String) async throws -> CloudJobDTO {
        try decode(CloudJobDTO.self, try await send(CloudRequest(method: "GET", path: "/v1/jobs/\(id)"), trigger: .user))
    }

    func cancelJob(_ id: String) async throws {
        let r = try await send(CloudRequest(method: "POST", path: "/v1/jobs/\(id)/cancel"), trigger: .user)
        guard r.isSuccess else { throw Self.error(from: r) }
    }

    // Sync

    func syncIndex() async throws -> [CloudSyncDocumentHead] {
        try decode(CloudPage<CloudSyncDocumentHead>.self, try await send(CloudRequest(method: "GET", path: "/v1/sync/documents"), trigger: .sync)).items
    }

    func syncDocument(_ namespace: String) async throws -> CloudSyncDocument? {
        let r = try await send(CloudRequest(method: "GET", path: "/v1/sync/documents/\(namespace)"), trigger: .sync)
        if r.status == 404 { return nil }
        return try decode(CloudSyncDocument.self, r)
    }

    /// Conditional write: `baseVersion` nil means "create; must not exist".
    func putSyncDocument(_ namespace: String, data: CloudJSON, baseVersion: Int?, deviceName: String?) async throws -> CloudSyncWriteResult {
        let precondition = baseVersion.map { ["If-Match": "\"\($0)\""] } ?? ["If-None-Match": "*"]
        let req = try CloudRequest.json("PUT", "/v1/sync/documents/\(namespace)", CloudSyncWrite(data: data, deviceName: deviceName), headers: precondition)
        let r = try await send(req, trigger: .sync)
        if r.status == 409 || r.status == 412 {
            let body = try? CloudCoding.decoder().decode(CloudSyncConflictBody.self, from: r.data)
            return .conflict(current: body?.current)
        }
        return .stored(try decode(CloudSyncDocument.self, r))
    }

    // Inbox

    func inbox() async throws -> [CloudInboxItem] {
        let req = CloudRequest(method: "GET", path: "/v1/inbox", query: [URLQueryItem(name: "status", value: "pending")])
        return try decode(CloudPage<CloudInboxItem>.self, try await send(req, trigger: .inbox)).items
    }

    func ackInbox(_ id: String, sha256: String) async throws {
        struct Body: Encodable { let sha256: String }
        let r = try await send(try .json("POST", "/v1/inbox/\(id)/ack", Body(sha256: sha256)), trigger: .inbox)
        guard r.isSuccess else { throw Self.error(from: r) }
    }
}

// MARK: - URLSession delegates

/// Session-level delegate: on a redirect to another origin, strip our bearer
/// token; refuse redirects to plain http off this Mac.
class CloudTaskDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        guard let new = request.url else { completionHandler(nil); return }
        if new.scheme?.lowercased() == "http", !CloudServerAddress.isLoopback(new.host ?? "") {
            completionHandler(nil)
            return
        }
        var r = request
        if let old = task.originalRequest?.url, CloudServerAddress.origin(of: old) != CloudServerAddress.origin(of: new) {
            r.setValue(nil, forHTTPHeaderField: "Authorization")
        }
        completionHandler(r)
    }
}

final class CloudUploadProgressDelegate: CloudTaskDelegate, @unchecked Sendable {
    private let onSent: @Sendable (Int64) -> Void
    init(onSent: @escaping @Sendable (Int64) -> Void) { self.onSent = onSent }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        onSent(totalBytesSent)
    }
}

/// Download task delegate: reports bytes, moves the file into place inside
/// the callback (the system deletes it afterwards), resumes the awaiting task.
final class CloudDownloadDelegate: CloudTaskDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let progress: (@Sendable (Int64, Int64) -> Void)?
    private let box = CloudLocked<(continuation: CheckedContinuation<HTTPURLResponse, Error>?, moveError: Error?)>((nil, nil))

    init(destination: URL, progress: (@Sendable (Int64, Int64) -> Void)?) {
        self.destination = destination
        self.progress = progress
    }

    func run(_ task: URLSessionDownloadTask) async throws -> HTTPURLResponse {
        try await withCheckedThrowingContinuation { c in
            box.withLock { $0.continuation = c }
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress?(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            box.withLock { $0.moveError = error }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (c, moveError) = box.withLock { s -> (CheckedContinuation<HTTPURLResponse, Error>?, Error?) in
            let c = s.continuation
            s.continuation = nil
            return (c, s.moveError)
        }
        if let error { c?.resume(throwing: error) }
        else if let moveError { c?.resume(throwing: moveError) }
        else if let http = task.response as? HTTPURLResponse { c?.resume(returning: http) }
        else { c?.resume(throwing: CloudError.invalidResponse("download without HTTP response")) }
    }
}
