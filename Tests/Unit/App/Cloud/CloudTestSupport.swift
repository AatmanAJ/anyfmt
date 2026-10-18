import XCTest
import HaloCore
@testable import HaloApp

// Shared scaffolding for the cloud tests: the Node mock server, request
// recorders, and in-memory stand-ins for the Keychain, browser, pasteboard
// and upload notice.

// MARK: - Mock server process

/// Runs `node Tests/Mock/server.mjs --port 0` for a test class.
@MainActor
final class MockCloudServer {
    let process: Process
    let port: Int
    let baseURL: URL
    private let stdin: Pipe
    private let control: URLSession

    static var repoRoot: URL {
        // Tests/Unit/App/Cloud/CloudTestSupport.swift → repo root
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static func findNode() -> URL? {
        let env = ProcessInfo.processInfo.environment
        var candidates: [String] = []
        if let explicit = env["NODE_BINARY"] { candidates.append(explicit) }
        candidates += ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"]
        candidates += (env["PATH"] ?? "").split(separator: ":").map { "\($0)/node" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: "\(home)/.nvm/versions/node") {
            candidates += versions.sorted().reversed().map { "\(home)/.nvm/versions/node/\($0)/bin/node" }
        }
        return candidates.lazy.map(URL.init(fileURLWithPath:)).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func launch() throws -> MockCloudServer {
        guard let node = findNode() else { throw XCTSkip("Node.js not found; set NODE_BINARY to run the cloud tests") }
        let script = repoRoot.appendingPathComponent("Tests/Mock/server.mjs")
        guard FileManager.default.fileExists(atPath: script.path) else { throw XCTSkip("mock server missing at \(script.path)") }
        let process = Process()
        process.executableURL = node
        process.arguments = [script.path, "--port", "0", "--quiet", "--watch-stdin"]
        let out = Pipe(), input = Pipe()
        process.standardOutput = out
        process.standardInput = input
        process.standardError = FileHandle.nullDevice
        try process.run()

        // Read "LISTENING <port>" with a timeout.
        let found = CloudLocked<Int?>(nil)
        let ready = DispatchSemaphore(value: 0)
        let buffer = CloudLocked("")
        out.fileHandleForReading.readabilityHandler = { h in
            let chunk = String(decoding: h.availableData, as: UTF8.self)
            let text = buffer.withLock { $0 += chunk; return $0 }
            if let line = text.split(separator: "\n").first(where: { $0.hasPrefix("LISTENING ") }),
               let p = Int(line.dropFirst("LISTENING ".count)) {
                if found.withLock({ old -> Bool in defer { old = p }; return old == nil }) { ready.signal() }
            }
        }
        guard ready.wait(timeout: .now() + 15) == .success, let port = found.current else {
            process.terminate()
            throw XCTSkip("mock server didn't start")
        }
        out.fileHandleForReading.readabilityHandler = nil
        return MockCloudServer(process: process, port: port, stdin: input)
    }

    private init(process: Process, port: Int, stdin: Pipe) {
        self.process = process
        self.port = port
        self.stdin = stdin
        self.baseURL = URL(string: "http://127.0.0.1:\(port)") ?? URL(fileURLWithPath: "/")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []
        self.control = URLSession(configuration: config)
    }

    func stop() {
        process.terminate()
        process.waitUntilExit()
    }

    // MARK: Control endpoints (/__mock/…)

    @discardableResult
    func call(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> Any {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await control.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw NSError(domain: "mock", code: status, userInfo: [NSLocalizedDescriptionKey: String(decoding: data, as: UTF8.self)])
        }
        if data.isEmpty { return [String: Any]() }
        return try JSONSerialization.jsonObject(with: data)
    }

    func items(_ path: String) async throws -> [[String: Any]] {
        let obj = try await call("GET", path)
        return ((obj as? [String: Any])?["items"] as? [[String: Any]]) ?? []
    }

    func reset(_ config: [String: Any] = [:]) async throws {
        var merged: [String: Any] = ["pollAfterMs": 10, "jobPolls": 3]
        merged.merge(config) { _, new in new }
        try await call("POST", "/__mock/reset", ["config": merged])
    }

    func configure(_ config: [String: Any]) async throws { try await call("POST", "/__mock/config", config) }

    func setUser(_ email: String = "aj@example.com", plan: String, customDomains: [String] = [], linksUsed: Int? = nil) async throws {
        var body: [String: Any] = ["email": email, "plan": plan, "customDomains": customDomains]
        if let linksUsed { body["linksUsed"] = linksUsed }
        try await call("POST", "/__mock/users", body)
        try await configure(["nextEmail": email, "nextPlan": plan])
    }

    func addFault(method: String, pathPrefix: String, skip: Int = 0, times: Int = 1, mode: String,
                  status: Int? = nil, keepBytes: Int? = nil) async throws {
        var body: [String: Any] = ["method": method, "pathPrefix": pathPrefix, "skip": skip, "times": times, "mode": mode]
        if let status { body["status"] = status }
        if let keepBytes { body["keepBytes"] = keepBytes }
        try await call("POST", "/__mock/faults", body)
    }

    func clearFaults() async throws { try await call("DELETE", "/__mock/faults") }

    /// The API request log (control calls excluded).
    func requests() async throws -> [[String: Any]] { try await items("/__mock/requests") }
    func clearRequests() async throws { try await call("DELETE", "/__mock/requests") }

    func requestCount(_ method: String? = nil, prefix: String? = nil) async throws -> Int {
        try await requests().filter { r in
            (method == nil || r["method"] as? String == method) && (prefix == nil || (r["path"] as? String ?? "").hasPrefix(prefix ?? ""))
        }.count
    }
}

// MARK: - Recorders

/// Records every request it sees and fails it, so nothing leaves the machine.
class RecordingURLProtocol: URLProtocol {
    class var log: CloudLocked<[String]> { recordedInjected }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.log.withLock { $0.append("\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "?")") }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

let recordedInjected = CloudLocked<[String]>([])
let recordedGlobal = CloudLocked<[String]>([])

/// Registered globally with `URLProtocol.registerClass` as a belt-and-braces check.
final class GlobalRecordingURLProtocol: RecordingURLProtocol {
    override class var log: CloudLocked<[String]> { recordedGlobal }
}

/// Session factory that counts sessions and installs the recording protocol.
final class RecordingSessionFactory: CloudSessionFactory {
    let made = CloudLocked(0)

    func makeSession(delegate: URLSessionDelegate) -> URLSession {
        made.withLock { $0 += 1 }
        return CloudDefaultSessionFactory(configure: { $0.protocolClasses = [RecordingURLProtocol.self] })
            .makeSession(delegate: delegate)
    }
}

final class CountingSessionFactory: CloudSessionFactory {
    let made = CloudLocked(0)
    func makeSession(delegate: URLSessionDelegate) -> URLSession {
        made.withLock { $0 += 1 }
        return CloudDefaultSessionFactory().makeSession(delegate: delegate)
    }
}

// MARK: - Fakes

final class MemorySecretStore: CloudSecretStore {
    let items = CloudLocked<[String: Data]>([:])
    func read(account: String) throws -> Data? { items.withLock { $0[account] } }
    func write(_ data: Data, account: String) throws { items.withLock { $0[account] = data } }
    func delete(account: String) throws { items.withLock { $0[account] = nil } }
}

final class CapturingBrowser: CloudBrowserOpening {
    let opened = CloudLocked<[URL]>([])
    @MainActor func open(_ url: URL) { opened.withLock { $0.append(url) } }
}

final class ScriptedConsent: CloudUploadConsent {
    let answer: Bool
    let asked = CloudLocked<[String]>([])
    init(answer: Bool = true) { self.answer = answer }
    @MainActor func confirmUpload(to serverName: String, fileCount: Int) async -> Bool {
        asked.withLock { $0.append(serverName) }
        return answer
    }
}

final class CapturingPasteboard: CloudPasteboardWriting {
    let copied = CloudLocked<[URL]>([])
    @MainActor func copy(_ url: URL) { copied.withLock { $0.append(url) } }
}

final class MemorySyncSource: SyncDocumentSource {
    let docs = CloudLocked<[SyncNamespace: Data]>([:])
    let applied = CloudLocked<[SyncNamespace]>([])

    func set(_ ns: SyncNamespace, _ json: Any) {
        let data = (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
        docs.withLock { $0[ns] = data }
    }

    func json(_ ns: SyncNamespace) -> Any? {
        docs.current[ns].flatMap { try? JSONSerialization.jsonObject(with: $0) }
    }

    func localDocument(_ namespace: SyncNamespace) async -> Data? { docs.current[namespace] }

    func applyRemoteDocument(_ data: Data, to namespace: SyncNamespace) async throws {
        docs.withLock { $0[namespace] = data }
        applied.withLock { $0.append(namespace) }
    }
}

// MARK: - Fixture

/// A CloudServices wired for tests, plus the bits tests poke at.
@MainActor
struct CloudFixture {
    let services: CloudServices
    let secrets: any CloudSecretStore
    let browser: CapturingBrowser
    let consent: ScriptedConsent
    let pasteboard: CapturingPasteboard
    let defaultsSuite: String
    let directory: URL
    let logLines: CloudLocked<[String]>

    static func make(server: URL?, secrets: (any CloudSecretStore)? = nil, factory: (any CloudSessionFactory)? = nil,
                     consent: ScriptedConsent = ScriptedConsent(), chunkSize: Int = 64 * 1024,
                     syncPolicy: [SyncNamespace: SyncSide] = [:], inboxInterval: Duration? = .milliseconds(50)) throws -> CloudFixture {
        let suite = "\(Brand.bundleID).tests.cloud.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { throw XCTSkip("no defaults suite") }
        if let server { defaults.set(server.absoluteString, forKey: "cloud.serverURL") }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("halo-cloud-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = secrets ?? MemorySecretStore()
        let browser = CapturingBrowser()
        let pasteboard = CapturingPasteboard()
        let lines = CloudLocked<[String]>([])
        var env = CloudServices.Environment()
        env.secrets = store
        env.defaults = defaults
        env.sessionFactory = factory ?? CloudDefaultSessionFactory()
        env.browser = browser
        env.consent = consent
        env.pasteboard = pasteboard
        env.ledgerDirectory = dir.appendingPathComponent("ledger", isDirectory: true)
        env.chunkSize = chunkSize
        env.retry = CloudRetryPolicy(maxAttempts: 4, baseDelay: .milliseconds(10), maxDelay: .milliseconds(50))
        env.syncDebounce = .milliseconds(30)
        env.syncPolicy = syncPolicy
        env.inboxInterval = inboxInterval
        env.jobPollInterval = .milliseconds(5)
        env.logObserver = { line in lines.withLock { $0.append(line) } }
        return CloudFixture(services: CloudServices(environment: env), secrets: store, browser: browser, consent: consent,
                            pasteboard: pasteboard, defaultsSuite: suite, directory: dir, logLines: lines)
    }

    func tearDown() {
        UserDefaults().removePersistentDomain(forName: defaultsSuite)
        try? FileManager.default.removeItem(at: directory)
    }

    var state: CloudState { services.state }

    /// Writes `bytes` random bytes (or `text`) to a new file in the fixture dir.
    func makeFile(_ name: String, bytes: Int = 0, text: String? = nil, in sub: String = "files") throws -> URL {
        let folder = directory.appendingPathComponent(sub, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        var data = Data(text.map { Array($0.utf8) } ?? [])
        if text == nil {
            var rng = SystemRandomNumberGenerator()
            data = Data((0..<bytes).map { _ in UInt8.random(in: 0...255, using: &rng) })
        }
        try data.write(to: url)
        return url
    }

    /// Acts as the browser: follows the authorize page to the redirect, returns the callback URL.
    func browserCallbackURL(for authorizeURL: URL) async throws -> URL {
        let delegate = NoRedirects()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (_, response) = try await session.data(from: authorizeURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 302,
              let location = http.value(forHTTPHeaderField: "Location"), let url = URL(string: location) else {
            throw NSError(domain: "browser", code: 1, userInfo: [NSLocalizedDescriptionKey: "authorize didn't redirect"])
        }
        return url
    }

    /// Full sign-in: "Sign in" → simulated browser → callback → account.
    @discardableResult
    func signIn() async throws -> CloudAccount {
        services.session.signIn()
        guard let authorize = browser.opened.current.last else { throw NSError(domain: "browser", code: 2) }
        let callback = try await browserCallbackURL(for: authorize)
        return try await services.auth.completeSignIn(callbackURL: callback)
    }

    /// Pretends we're signed in without a server (for gate tests).
    func fakeSignIn(plan: Plan = .pro, features: Set<CloudFeature> = Set(CloudFeature.allCases)) {
        let creds = CloudCredentials(accessToken: "at_fake", refreshToken: "rt_fake", accessTokenExpiresAt: Date().addingTimeInterval(3600))
        let account = CloudAccount(userID: "usr_fake", email: "fake@example.com", name: nil,
                                   entitlements: CloudEntitlements(isSignedIn: true, plan: plan, features: features, quotas: .none, customDomains: []))
        state.update { $0.credentials = creds; $0.account = account }
    }

    func jobContext() throws -> JobContext {
        let tmp = directory.appendingPathComponent("job-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return JobContext(tempDirectory: tmp, policy: .default, engine: EngineContext())
    }
}

final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Polls `condition` on the main actor until true or the timeout passes.
@MainActor
func waitUntil(timeout: TimeInterval = 5, _ message: String = "condition", _ condition: () async throws -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if try await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("timed out waiting for \(message)")
}

/// Base class: one mock server per test class, fresh state per test.
@MainActor
class MockServerTestCase: XCTestCase {
    nonisolated(unsafe) static var servers: [ObjectIdentifier: MockCloudServer] = [:]
    var mock: MockCloudServer!
    var fixtures: [CloudFixture] = []

    override func setUp() async throws {
        try await super.setUp()
        let key = ObjectIdentifier(type(of: self))
        if let existing = Self.servers[key] {
            mock = existing
        } else {
            mock = try MockCloudServer.launch()
            Self.servers[key] = mock
        }
        try await mock.reset()
    }

    override func tearDown() async throws {
        for f in fixtures { f.tearDown() }
        fixtures = []
        try await super.tearDown()
    }

    override class func tearDown() {
        let key = ObjectIdentifier(self)
        if let server = servers[key] {
            MainActor.assumeIsolated { server.stop() }
            servers[key] = nil
        }
        super.tearDown()
    }

    func fixture(secrets: (any CloudSecretStore)? = nil, consent: ScriptedConsent = ScriptedConsent(), chunkSize: Int = 64 * 1024,
                 syncPolicy: [SyncNamespace: SyncSide] = [:], inboxInterval: Duration? = .milliseconds(50)) throws -> CloudFixture {
        let f = try CloudFixture.make(server: mock.baseURL, secrets: secrets, consent: consent, chunkSize: chunkSize,
                                      syncPolicy: syncPolicy, inboxInterval: inboxInterval)
        fixtures.append(f)
        return f
    }
}
