import XCTest
@testable import AnyfmtCore

final class BatchConversionTests: JobsTestCase {
    private let e: EngineID = "fake"
    private var registry: EngineRegistry { EngineRegistry([ScriptedEngine(e)]) }

    func testSkipsFilesAlreadyInTargetFormat() throws {
        let files = try makeFiles(["a.jpg", "b.heic", "c.png", "d.jpg", "e.unknownext"])
        let target = RouteTarget(format: "jpg", routes: ["heic": directRoute("heic", "jpg", e), "png": directRoute("png", "jpg", e)])
        let batch = BatchConversion(files: files, target: target, registry: registry)
        XCTAssertFalse(batch.isCombine)
        XCTAssertEqual(batch.jobs.map { $0.inputs[0].lastPathComponent }, ["b.heic", "c.png"])
        XCTAssertEqual(batch.skipped.map(\.lastPathComponent), ["a.jpg", "d.jpg"])
        XCTAssertEqual(batch.unsupported.map(\.lastPathComponent), ["e.unknownext"])
        XCTAssertEqual(batch.skippedNote, "2 already JPG · 1 can’t be converted")
        XCTAssertEqual(batch.fileCount, 5)
        XCTAssertEqual(batch.activityTitle, "Converting 2 files to JPG")
        XCTAssertEqual(batch.completedTitle, "Converted 2 files to JPG")
        XCTAssertTrue(batch.jobs.allSatisfy { $0.route?.isDirect == true })
    }

    func testPlansWithRouterWhenGivenAFormat() throws {
        let files = try makeFiles(["a.heic", "b.jpg"])
        let router = Router(table: CapabilityTable([Capability("heic", "png", e, flags: .lossless), Capability("png", "jpg", e)]))
        let batch = BatchConversion(files: files, to: "jpg", router: router, registry: registry)
        XCTAssertEqual(batch.jobs.count, 1)
        XCTAssertEqual(batch.jobs[0].route?.hops.count, 2, "heic → png → jpg")
        XCTAssertEqual(batch.skippedNote, "1 already JPG")
        XCTAssertEqual(batch.activityTitle, "Converting to JPG")
    }

    @MainActor
    func testBatchRunsThroughQueueAndPlacesEveryFile() async throws {
        let files = try makeFiles(["a.png", "b.png", "c.png", "keep.jpg"])
        let target = RouteTarget(format: "jpg", routes: ["png": directRoute("png", "jpg", e)])
        let batch = BatchConversion(files: files, target: target, registry: registry)
        let queue = JobQueue(limits: ConcurrencyLimits(cpu: 2), scratch: scratch)
        let id = queue.submit(batch)
        XCTAssertEqual(queue.batch(id)?.note, "1 already JPG")
        XCTAssertEqual(queue.batch(id)?.fileCount, 4)
        await waitIdle(queue)
        let outputs = queue.records(inBatch: id).flatMap(\.outputs).map(\.lastPathComponent).sorted()
        XCTAssertEqual(outputs, ["a.jpg", "b.jpg", "c.jpg"])
        XCTAssertEqual(contents(files[3]), "keep.jpg", "skipped file untouched")
    }

    func testCombineRouteMakesOneJobWithEveryItem() async throws {
        let files = try makeFiles(["Photos/", "Docs/", "old.zip", "weird.qqq"])
        let target = RouteTarget(format: "zip", routes: ["folder": directRoute("folder", "zip", e, arity: .combine)])
        let batch = BatchConversion(files: files, target: target, registry: registry)
        XCTAssertTrue(batch.isCombine)
        XCTAssertEqual(batch.jobs.count, 1)
        XCTAssertEqual(batch.jobs[0].inputs.map(\.lastPathComponent), ["Photos", "Docs", "old.zip"],
                       "an existing zip goes into the new archive")
        XCTAssertEqual(batch.unsupported.map(\.lastPathComponent), ["weird.qqq"])
        XCTAssertTrue(batch.skipped.isEmpty)
        XCTAssertEqual(batch.activityTitle, "Compressing to ZIP")
        let out = try await JobRunner.run(batch.jobs[0], policy: .default, scratch: scratch)
        XCTAssertEqual(out.map(\.lastPathComponent), ["Archive.zip"])
    }

    func testCombineIntoSameFormatOnlyStillArchives() throws {
        let files = try makeFiles(["one/"])
        let target = RouteTarget(format: "zip", routes: ["folder": directRoute("folder", "zip", e, arity: .combine)])
        let batch = BatchConversion(files: files, target: target, registry: registry)
        XCTAssertEqual(batch.jobs.first?.title, "one → ZIP")
        XCTAssertEqual(batch.title, "one → ZIP")
    }
}
