import XCTest
@testable import AnyfmtCore

/// Router memoisation (lane C owns Router internals) and executor step cleanup.
final class RouterMemoTests: JobsTestCase {
    private let a: EngineID = "a", b: EngineID = "b"

    private var table: CapabilityTable {
        CapabilityTable([
            Capability("heic", "png", a, flags: .lossless), Capability("heic", "jpg", a),
            Capability("png", "jpg", a), Capability("png", "webp", b, priority: 50), Capability("jpg", "webp", a),
            Capability("png", "tiff", a, flags: .lossless), Capability("tiff", "bmp", a), Capability("pdf", "png", a, flags: .multiOutput),
            Capability("md", "html", a), Capability("html", "docx", a), Capability("docx", "odt", a), Capability("odt", "rtf", a),
            Capability("mov", "mp4", a), Capability("mp4", "gif", a), Capability("gif", "png", a),
            Capability("folder", "zip", a, arity: .combine), Capability("zip", "folder", a),
        ])
    }

    func testMemoisedRoutesMatchUncachedSearch() {
        let router = Router(table: table)
        let starts = Set(table.rows.map(\.from)).sorted()
        for s in starts {
            let first = router.allRoutes(from: s)
            XCTAssertEqual(first, router.computeAllRoutes(from: s), "memo == search for \(s)")
            XCTAssertEqual(router.allRoutes(from: s), first, "second call identical for \(s)")
        }
        XCTAssertEqual(router.memoizedStartCount, starts.count)
        // Derived APIs see the same answers.
        XCTAssertEqual(router.route(from: "heic", to: "bmp")?.hops.map(\.to), ["png", "tiff", "bmp"])
        XCTAssertNil(router.route(from: "mov", to: "png"), "time-based → still only directly")
        XCTAssertEqual(router.commonTargets(for: ["heic", "png"]).map(\.format), Router(table: table).commonTargets(for: ["heic", "png"]).map(\.format))
        XCTAssertEqual(router.optionCount(), Router(table: table).optionCount())
    }

    func testCachedRouterReusedUntilTableChanges() {
        let first = Router.cached(for: table)
        _ = first.allRoutes(from: "heic")
        let again = Router.cached(for: table)
        XCTAssertEqual(again.memoizedStartCount, 1, "same rows → same warm router")

        var rows = table.rows
        rows.append(Capability("bmp", "heic", a))
        let changed = Router.cached(for: CapabilityTable(rows))
        XCTAssertEqual(changed.memoizedStartCount, 0, "new rows → fresh router")
        XCTAssertNotNil(changed.route(from: "bmp", to: "heic"))
        XCTAssertNil(first.route(from: "bmp", to: "heic"), "old router unaffected")

        let removed = Router.cached(for: CapabilityTable(table.rows.filter { $0.engine != b }))
        XCTAssertEqual(removed.route(from: "png", to: "webp")?.hops.map(\.to), ["jpg", "webp"], "rows from a vanished engine are gone")
    }

    func testLiveIsCheapToCallRepeatedly() {
        _ = Router.live().allRoutes(from: "heic")
        let start = Date()
        for _ in 0..<500 { _ = Router.live().commonTargets(for: ["heic", "png", "mov"]) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
        XCTAssertGreaterThan(Router.live().memoizedStartCount, 0, "live() hands back the warm router")
    }

    /// A wheel show never waits for the availability re-check: an expired
    /// snapshot answers at once and refreshes in the background.
    func testExpiredAvailabilityAnswersAtOnceAndRefreshes() async throws {
        let cache = LiveAvailability(ttl: 0)
        let first = cache.table(registry: .default)
        let stamp = try XCTUnwrap(cache.snapshotTime)
        XCTAssertEqual(cache.table(registry: .default).rows, first.rows, "stale answer, same rows")
        for _ in 0..<400 where cache.snapshotTime == stamp { try await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertNotEqual(cache.snapshotTime, stamp, "refreshed in the background")
        cache.invalidate()
        XCTAssertNil(cache.snapshotTime)
        XCTAssertEqual(cache.table(registry: .default).rows, first.rows, "after invalidate the next call re-checks itself")
    }

    /// Launch warms every start format so the first drag of a format isn't cold.
    func testWarmLiveFillsTheMemo() {
        Router.invalidateLive()
        let start = Date()
        Router.warmLive()
        let elapsed = Date().timeIntervalSince(start)
        let router = Router.live()
        print(String(format: "PERF router warmLive rows=%d starts=%d %.1f ms", router.table.rows.count,
                     router.memoizedStartCount, elapsed * 1000))
        XCTAssertEqual(router.memoizedStartCount, Set(router.table.rows.map(\.from)).count)
    }

    /// A table shaped like the shipped one (~400 rows over ~45 formats) to
    /// measure what memoisation buys a drag: wheel content = commonTargets.
    func testMemoisationPerformanceOnRealisticTable() {
        let images: [FormatID] = ["jpg", "png", "heic", "webp", "avif", "tiff", "gif", "bmp", "heif", "jp2", "psd", "ico"]
        let audio: [FormatID] = ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "caf"]
        let video: [FormatID] = ["mp4", "mov", "mkv", "webm", "avi", "wmv", "m4v"]
        let docs: [FormatID] = ["docx", "odt", "md", "txt", "rtf", "html", "epub", "pages"]
        var rows = Capability.grid(images, images, a, flags: .lossless)
            + Capability.grid(audio, audio, a) + Capability.grid(video, video, b)
            + Capability.grid(video, ["mp3", "m4a", "gif"], b) + Capability.grid(docs, docs, a)
        rows += images.map { Capability($0, "pdf", a) } + ["png", "jpg", "txt", "docx"].map { Capability("pdf", FormatID($0), a, flags: .multiOutput) }
        rows += docs.map { Capability($0, "pdf", a) }
        let table = CapabilityTable(rows)
        let inputs: [FormatID] = ["heic", "png", "mov"]

        let iterations = 200
        var start = Date()
        for _ in 0..<iterations { _ = Router(table: table).commonTargets(for: inputs) }
        let cold = Date().timeIntervalSince(start) / Double(iterations)

        _ = Router.cached(for: table).commonTargets(for: inputs)
        start = Date()
        for _ in 0..<iterations { _ = Router.cached(for: table).commonTargets(for: inputs) }
        let warm = Date().timeIntervalSince(start) / Double(iterations)

        print(String(format: "PERF router rows=%d cold commonTargets=%.3f ms warm (memoised)=%.3f ms speedup=%.0fx",
                     rows.count, cold * 1000, warm * 1000, cold / max(warm, 1e-9)))
        XCTAssertLessThan(warm, cold, "memoised lookups beat recomputing")
        XCTAssertEqual(Router.cached(for: table).commonTargets(for: inputs).map(\.format),
                       Router(table: table).commonTargets(for: inputs).map(\.format))
    }

    func testMemoIsThreadSafe() async {
        let router = Router(table: table)
        let starts = Set(table.rows.map(\.from)).sorted()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<64 {
                let s = starts[i % starts.count]
                group.addTask { XCTAssertEqual(router.allRoutes(from: s), router.computeAllRoutes(from: s)) }
            }
        }
    }

    func testExecutorDeletesIntermediateStepsAsItGoes() async throws {
        let observed = Box<[String: Bool]>([:])
        let work = root.appendingPathComponent("work", isDirectory: true)
        let engine = ScriptedEngine(a) { request, context in
            // While hop N runs, record which earlier step folders still exist.
            for n in 1...3 {
                let dir = work.appendingPathComponent("step\(n)")
                observed.mutate { $0["\(request.to)@step\(n)"] = FileManager.default.fileExists(atPath: dir.path) }
            }
            return try await ScriptedEngine.writeOutput(request, context)
        }
        let input = try makeFiles(["notes.md"])[0]
        let route = Route([Capability("md", "html", a), Capability("html", "docx", a), Capability("docx", "odt", a)])
        let out = try await RouteExecutor(registry: EngineRegistry([engine])).execute(
            route, inputs: [input], options: OptionValues(), baseName: "notes", metadata: .keep,
            workDirectory: work, context: EngineContext())
        XCTAssertEqual(out.map(\.lastPathComponent), ["notes.odt"])
        XCTAssertEqual(observed.get["odt@step1"], false, "step1 deleted once step2 had consumed it")
        XCTAssertEqual(observed.get["odt@step2"], true, "step2 is hop 3's input")
        XCTAssertFalse(FileManager.default.fileExists(atPath: work.appendingPathComponent("step2").path), "step2 deleted after hop 3")
        XCTAssertTrue(FileManager.default.fileExists(atPath: out[0].path), "final output kept")
        XCTAssertTrue(FileManager.default.fileExists(atPath: input.path), "user input never touched")
    }

    func testExecutorKeepsStepWhenEngineHandsItBack() async throws {
        // A pass-through engine returning its input: the folder holding it must survive.
        let passthrough = ScriptedEngine(b) { request, _ in ConversionOutput(request.inputs) }
        let route = Route([Capability("md", "html", a), Capability("html", "docx", b)])
        let input = try makeFiles(["x.md"])[0]
        let out = try await RouteExecutor(registry: EngineRegistry([ScriptedEngine(a), passthrough])).execute(
            route, inputs: [input], options: OptionValues(), baseName: "x", metadata: .keep,
            workDirectory: root.appendingPathComponent("w2"), context: EngineContext())
        XCTAssertTrue(FileManager.default.fileExists(atPath: out[0].path))
    }
}
