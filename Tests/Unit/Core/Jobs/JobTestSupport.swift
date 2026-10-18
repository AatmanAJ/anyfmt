import XCTest
@testable import HaloCore

/// Engine whose behaviour is a closure, so each test says exactly what a hop does.
struct ScriptedEngine: ConversionEngine {
    let id: EngineID
    let body: @Sendable (ConversionRequest, EngineContext) async throws -> ConversionOutput

    init(_ id: EngineID, body: @escaping @Sendable (ConversionRequest, EngineContext) async throws -> ConversionOutput = ScriptedEngine.writeOutput) {
        self.id = id
        self.body = body
    }

    func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        try await body(request, context)
    }

    /// Writes `<baseName>.<target ext>` containing the input names.
    @Sendable static func writeOutput(_ request: ConversionRequest, _ context: EngineContext) async throws -> ConversionOutput {
        let out = request.defaultOutputURL
        let text = request.inputs.map(\.lastPathComponent).joined(separator: "\n")
        try Data(text.utf8).write(to: out)
        context.progress(1)
        return ConversionOutput(out)
    }

    /// Sleeps cooperatively in small steps, reporting progress (Task.sleep throws on cancel).
    static func sleepy(_ id: EngineID, seconds: Double, steps: Int = 20) -> ScriptedEngine {
        ScriptedEngine(id) { request, context in
            for i in 1...steps {
                try await Task.sleep(nanoseconds: UInt64(seconds / Double(steps) * 1_000_000_000))
                context.progress(Double(i) / Double(steps))
            }
            return try await writeOutput(request, context)
        }
    }
}

/// Thread-safe box for values engines report back to the test.
final class Box<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ value: T) { self.value = value }
    var get: T { lock.withLock { value } }
    func set(_ v: T) { lock.withLock { value = v } }
    func mutate(_ body: (inout T) -> Void) { lock.withLock { body(&value) } }
}

/// Counts how many fake jobs of each class run at once, and in what order they start.
final class ConcurrencyProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var current: [ResourceClass: Int] = [:]
    private var peaks: [ResourceClass: Int] = [:]
    private var order: [ResourceClass: [String]] = [:]

    func enter(_ resource: ResourceClass, _ name: String) {
        lock.withLock {
            current[resource, default: 0] += 1
            peaks[resource] = max(peaks[resource] ?? 0, current[resource] ?? 0)
            order[resource, default: []].append(name)
        }
    }

    func leave(_ resource: ResourceClass) { lock.withLock { current[resource, default: 0] -= 1 } }
    func peak(_ r: ResourceClass) -> Int { lock.withLock { peaks[r] ?? 0 } }
    func starts(_ r: ResourceClass) -> [String] { lock.withLock { order[r] ?? [] } }
    var anyStarted: [String] { lock.withLock { order.values.flatMap { $0 } } }
}

/// A queue-level fake: sleeps cooperatively for `duration`, reporting progress.
final class FakeJob: Job, @unchecked Sendable {
    let id = UUID()
    let title: String
    let inputs: [URL] = []
    let resourceClass: ResourceClass
    let progress = Progress.discreteProgress(totalUnitCount: 100)
    let duration: TimeInterval
    let probe: ConcurrencyProbe
    let failure: Error?

    init(_ title: String, _ resource: ResourceClass, duration: TimeInterval = 0.15, probe: ConcurrencyProbe, failure: Error? = nil) {
        self.title = title
        self.resourceClass = resource
        self.duration = duration
        self.probe = probe
        self.failure = failure
    }

    func run(context: JobContext) async throws -> [URL] {
        probe.enter(resourceClass, title)
        defer { probe.leave(resourceClass) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: context.tempDirectory.path), "scratch exists while running")
        for i in 1...10 {
            try await Task.sleep(nanoseconds: UInt64(duration / 10 * 1_000_000_000))
            progress.completedUnitCount = Int64(i * 10)
        }
        if let failure { throw failure }
        return []
    }
}

/// Fresh temp folders per test, removed in tearDown.
class JobsTestCase: XCTestCase {
    var root: URL!
    var scratch: JobScratch!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("halo-jobs-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        scratch = JobScratch(root: root.appendingPathComponent("scratch", isDirectory: true))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// A user folder with files of these names (contents = the name).
    @discardableResult
    func makeFiles(_ names: [String], in folder: String = "user") throws -> [URL] {
        let dir = root.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try names.map { name in
            let u = dir.appendingPathComponent(name)
            if name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
                try Data("inside".utf8).write(to: u.appendingPathComponent("inside.txt"))
            } else {
                try Data(name.utf8).write(to: u)
            }
            return u
        }
    }

    func contents(_ url: URL) -> String { (try? String(contentsOf: url, encoding: .utf8)) ?? "<unreadable>" }

    func scratchIsEmpty() -> Bool {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: scratch.root.path)) ?? []
        return items.isEmpty
    }

    /// Polls (on the main actor) until `condition` holds or `timeout` passes.
    @MainActor
    func eventually(_ what: String, timeout: TimeInterval = 10, _ condition: @escaping @MainActor () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { XCTFail("timed out waiting for \(what)"); return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    func waitIdle(_ queue: JobQueue, timeout: TimeInterval = 10) async {
        await eventually("queue idle", timeout: timeout) { queue.isIdle }
    }
}

func directRoute(_ from: FormatID, _ to: FormatID, _ engine: EngineID, arity: Arity = .perFile,
                 schema: OptionsSchema = .none) -> Route {
    Route([Capability(from, to, engine, schema: schema, arity: arity)])
}
