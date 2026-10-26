import XCTest
@testable import AnyfmtCore

/// A fake engine so router tests don't depend on lanes.
private struct FakeEngine: ConversionEngine {
    let id: EngineID
    func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let out = request.defaultOutputURL
        try Data("x".utf8).write(to: out)
        return ConversionOutput(out)
    }
}

final class RouterTests: XCTestCase {
    private let a: EngineID = "a", b: EngineID = "b"

    private func router(_ rows: [Capability]) -> Router { Router(table: CapabilityTable(rows)) }

    func testDirectRouteWins() {
        let r = router([
            Capability("heic", "jpg", a, priority: 100),
            Capability("heic", "png", a, flags: .lossless),
            Capability("png", "jpg", a),
        ])
        XCTAssertEqual(r.route(from: "heic", to: "jpg")?.hops.count, 1)
    }

    func testHigherPriorityRowChosenForSamePair() {
        let r = router([
            Capability("png", "webp", a, priority: 50),
            Capability("png", "webp", b, priority: 100),
        ])
        XCTAssertEqual(r.route(from: "png", to: "webp")?.hops.first?.engine, b)
    }

    func testMultiHopUpToThree() {
        let r = router([
            Capability("md", "html", a), Capability("html", "docx", a),
            Capability("docx", "odt", a), Capability("odt", "rtf", a),
        ])
        XCTAssertEqual(r.route(from: "md", to: "odt")?.hops.count, 3)
        XCTAssertNil(r.route(from: "md", to: "rtf"), "4 hops must be rejected")
    }

    func testStillNeverRoutesIntoVideoExceptDirectly() {
        let r = router([
            Capability("png", "gif", a),
            Capability("gif", "mp4", a), // direct row from GIF is fine
        ])
        XCTAssertNotNil(r.route(from: "gif", to: "mp4"))
        XCTAssertNil(r.route(from: "png", to: "mp4"), "PNG→GIF→MP4 must never be planned")
    }

    func testVideoNeverRoutesIntoStillExceptDirectly() {
        let r = router([Capability("mp4", "gif", a), Capability("gif", "png", a)])
        XCTAssertNotNil(r.route(from: "mp4", to: "gif"))
        XCTAssertNil(r.route(from: "mp4", to: "png"))
    }

    func testMultiOutputOnlyLast() {
        let r = router([Capability("pdf", "png", a, flags: .multiOutput), Capability("png", "jpg", a)])
        XCTAssertNotNil(r.route(from: "pdf", to: "png"))
        XCTAssertNil(r.route(from: "pdf", to: "jpg"))
    }

    func testLosslessIntermediatePreferred() {
        let r = router([
            Capability("heic", "jpg", a), Capability("jpg", "bmp", a),
            Capability("heic", "png", a, flags: .lossless), Capability("png", "bmp", a),
        ])
        XCTAssertEqual(r.route(from: "heic", to: "bmp")?.hops.first?.to, "png")
    }

    func testCommonTargetsIntersectAndSkipSameFormat() {
        let r = router([
            Capability("jpg", "png", a), Capability("jpg", "webp", a),
            Capability("heic", "png", a), Capability("heic", "jpg", a),
        ])
        let all = r.commonTargets(for: ["jpg", "heic"])
        let targets = all.map(\.format)
        XCTAssertTrue(targets.contains("png"))
        XCTAssertEqual(all.first { $0.format == "webp" }?.isMultiHop, true, "heic reaches webp only via jpg")
        let lone = Router(table: CapabilityTable([Capability("jpg", "webp", a), Capability("heic", "png", a)]))
        XCTAssertFalse(lone.commonTargets(for: ["jpg", "heic"]).map(\.format).contains("webp"), "heic can't make webp")
        XCTAssertTrue(targets.contains("jpg"), "jpg files are skipped, heic converts")
        let jpgTarget = r.commonTargets(for: ["jpg", "heic"]).first { $0.format == "jpg" }
        XCTAssertEqual(jpgTarget?.routes.keys.sorted(), ["heic"])
    }

    func testIntegrityFindsDuplicatesAndOrphans() {
        let table = CapabilityTable([Capability("png", "jpg", a), Capability("png", "jpg", a), Capability("png", "nope", a)])
        let issues = table.integrityIssues(registry: EngineRegistry([FakeEngine(id: a), FakeEngine(id: b)]))
        XCTAssertTrue(issues.contains { $0.contains("duplicate") })
        XCTAssertTrue(issues.contains { $0.contains("unknown target") })
        XCTAssertTrue(issues.contains { $0.contains("orphan engine b") })
    }

    func testExecutorRunsHops() async throws {
        let registry = EngineRegistry([FakeEngine(id: a)])
        let route = Route([Capability("md", "html", a), Capability("html", "docx", a)])
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let input = dir.appendingPathComponent("in.md")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("# hi".utf8).write(to: input)
        let out = try await RouteExecutor(registry: registry).execute(
            route, inputs: [input], options: .init(), baseName: "in", metadata: .keep,
            workDirectory: dir.appendingPathComponent("work"), context: EngineContext())
        XCTAssertEqual(out.first?.pathExtension, "docx")
    }

    func testDefaultTableIsHealthy() {
        let issues = CapabilityTable.default.integrityIssues(registry: .default)
        XCTAssertEqual(issues, [], issues.joined(separator: "\n"))
    }
}

final class RouteVisibilityTests: XCTestCase {
    private let e: EngineID = "e"

    func testCrossFamilyMultiHopIsHiddenButPDFAndSameFamilyShow() {
        let r = Router(table: CapabilityTable([
            Capability("jpg", "pdf", e), Capability("pdf", "docx", e),
            Capability("svg", "png", e), Capability("png", "jpg", e),
            Capability("md", "html", e), Capability("html", "pdf", e),
            Capability("jpg", "txt", e, flags: [.terminalOnly, .hiddenByDefault]),
        ]))
        XCTAssertEqual(r.route(from: "jpg", to: "pdf")?.isShownByDefault, true, "direct")
        XCTAssertEqual(r.route(from: "jpg", to: "docx")?.isShownByDefault, false, "photo → DOCX via PDF is opt-in")
        XCTAssertEqual(r.route(from: "svg", to: "jpg")?.isShownByDefault, true, "vector and raster are one family")
        XCTAssertEqual(r.route(from: "md", to: "pdf")?.isShownByDefault, true, "anything → PDF shows")
        XCTAssertEqual(r.route(from: "jpg", to: "txt")?.isShownByDefault, false, "hidden row")
    }
}
