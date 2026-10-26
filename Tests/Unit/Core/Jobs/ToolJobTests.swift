import XCTest
@testable import AnyfmtCore

private struct FakeToolRunner: ToolRunner {
    let id: ToolID
    var resourceClass: ResourceClass = .cpu
    let calls: Box<[[String]]>

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        calls.mutate { $0.append(request.inputs.map(\.lastPathComponent)) }
        let ext = request.inputs[0].pathExtension.isEmpty ? "png" : request.inputs[0].pathExtension
        let out = request.outputDirectory.appendingPathComponent(request.baseName).appendingPathExtension(ext)
        try Data(request.inputs.map(\.lastPathComponent).joined(separator: "+").utf8).write(to: out)
        context.progress(1)
        return ConversionOutput(out)
    }
}

final class ToolJobTests: JobsTestCase {
    func testPlacesWithSuffixAndNoDatePreservation() async throws {
        let input = try makeFiles(["photo.jpg", "photo-compressed.jpg"])[0]
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000_000)], ofItemAtPath: input.path)
        let calls = Box<[[String]]>([])
        let registry = ToolRegistry([FakeToolRunner(id: ToolIDs.compressImage, calls: calls)])
        let job = ToolJob(tool: ToolIDs.compressImage, inputs: [input], registry: registry)
        XCTAssertEqual(job.title, "photo.jpg → Compress")
        XCTAssertEqual(job.activityTitle, "Compressing")
        XCTAssertEqual(job.completedTitle, "Compressed")
        XCTAssertEqual(job.options, ToolSchemas.compress.defaults, "tool defaults are filled in")
        let out = try await JobRunner.run(job, policy: .default, scratch: scratch)
        XCTAssertEqual(out.map(\.lastPathComponent), ["photo-compressed 2.jpg"], "suffix + never overwrite")
        let m = try FileManager.default.attributesOfItem(atPath: out[0].path)[.modificationDate] as? Date
        XCTAssertGreaterThan(m?.timeIntervalSince1970 ?? 0, Date().timeIntervalSince1970 - 60, "tools don't copy source dates")
        XCTAssertTrue(scratchIsEmpty())
    }

    func testPerFileLoopsAndBatchSplits() async throws {
        let files = try makeFiles(["a.png", "b.png"])
        let calls = Box<[[String]]>([])
        let registry = ToolRegistry([FakeToolRunner(id: ToolIDs.resizeImage, calls: calls)])
        let one = ToolJob(tool: ToolIDs.resizeImage, inputs: files, registry: registry)
        XCTAssertEqual(one.title, "2 files → Resize")
        let out = try await JobRunner.run(one, policy: .default, scratch: scratch)
        XCTAssertEqual(out.map(\.lastPathComponent), ["a-resized.png", "b-resized.png"])
        XCTAssertEqual(calls.get, [["a.png"], ["b.png"]])
        XCTAssertEqual(ToolJob.batch(tool: ToolIDs.resizeImage, inputs: files, registry: registry).count, 2)
    }

    func testCombineToolRunsOnceWithAllInputs() async throws {
        let files = try makeFiles(["a.png", "b.png", "c.png"])
        let calls = Box<[[String]]>([])
        let registry = ToolRegistry([FakeToolRunner(id: ToolIDs.collage, calls: calls)])
        let jobs = ToolJob.batch(tool: ToolIDs.collage, inputs: files, registry: registry)
        XCTAssertEqual(jobs.count, 1)
        let out = try await JobRunner.run(jobs[0], policy: .default, scratch: scratch)
        XCTAssertEqual(calls.get, [["a.png", "b.png", "c.png"]])
        XCTAssertEqual(out.map(\.lastPathComponent), ["a-collage.png"])
        XCTAssertEqual(contents(out[0]), "a.png+b.png+c.png")

        let tooFew = ToolJob(tool: ToolIDs.collage, inputs: [files[0]], registry: registry)
        do {
            _ = try await JobRunner.run(tooFew, policy: .default, scratch: scratch)
            XCTFail("collage needs two")
        } catch {
            XCTAssertEqual(JobFailure.from(error).message, "This tool needs at least 2 files.")
        }
    }

    func testMissingRunnerIsAHumanError() async throws {
        let input = try makeFiles(["a.png"])[0]
        let job = ToolJob(tool: ToolIDs.redactImage, inputs: [input], registry: ToolRegistry([]))
        do {
            _ = try await JobRunner.run(job, policy: .default, scratch: scratch)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(JobFailure.from(error).message, "This tool isn’t available in this build of \(Brand.name).")
        }
    }

    func testResourceClassComesFromRunner() {
        let calls = Box<[[String]]>([])
        let registry = ToolRegistry([FakeToolRunner(id: ToolIDs.compressVideo, resourceClass: .videoToolbox, calls: calls)])
        XCTAssertEqual(ToolJob(tool: ToolIDs.compressVideo, inputs: [], registry: registry).resourceClass, .videoToolbox)
        XCTAssertEqual(ToolJob(tool: ToolIDs.trimVideo, inputs: [], registry: registry).resourceClass, .cpu)
    }
}
