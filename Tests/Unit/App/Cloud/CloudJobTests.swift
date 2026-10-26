import XCTest
import AnyfmtCore
@testable import AnyfmtApp

/// Cloud jobs end to end: upload → job → poll → download → placed beside
/// the original (never overwriting), progress phases, cancel.
@MainActor
final class CloudJobTests: MockServerTestCase {
    /// Records every `fractionCompleted` the progress window would see.
    private final class ProgressRecorder: NSObject, @unchecked Sendable {
        let values = CloudLocked<[Double]>([])
        private var observation: NSKeyValueObservation?
        init(_ progress: Progress) {
            super.init()
            observation = progress.observe(\.fractionCompleted, options: [.new]) { [values] p, _ in
                values.withLock { $0.append(p.fractionCompleted) }
            }
        }
    }

    func testCloudConversionPlacesResultBesideOriginalWithoutOverwriting() async throws {
        try await mock.setUser(plan: "pro")
        try await mock.reset(["jobPolls": 4])
        try await mock.setUser(plan: "pro")
        let f = try fixture(chunkSize: 64 * 1024)
        try await f.signIn()
        let input = try f.makeFile("clip.mov", bytes: 300_000)
        let original = try Data(contentsOf: input)
        // Something already has the obvious name: the result must not touch it.
        let existing = input.deletingLastPathComponent().appendingPathComponent("clip.mp4")
        try Data("keep me".utf8).write(to: existing)

        let job = f.services.makeCloudJob(input: input, operation: .convert(
            target: Formats.mp4, options: OptionValues([OptionKey.cloud: .bool(true), OptionKey.videoQuality: .string("balanced")])))
        XCTAssertEqual(job.resourceClass, .network)
        XCTAssertEqual(job.inputs, [input])
        XCTAssertTrue(job.title.contains("clip.mov"))
        let recorder = ProgressRecorder(job.progress)

        let outputs = try await job.run(context: try f.jobContext())

        let out = try XCTUnwrap(outputs.first)
        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(out.lastPathComponent, "clip 2.mp4")
        XCTAssertEqual(out.deletingLastPathComponent().standardizedFileURL, input.deletingLastPathComponent().standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: out), original, "mock echoes the input")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "keep me")
        XCTAssertEqual(try Data(contentsOf: input), original, "original untouched")

        // Progress: monotonic, visits all three phases, ends at 100 %.
        let values = recorder.values.current
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(job.progress.fractionCompleted, 1, accuracy: 0.0001)
        XCTAssertTrue(values.contains { $0 > 0 && $0 <= 0.45 }, "upload phase: \(values)")
        XCTAssertTrue(values.contains { $0 > 0.45 && $0 < 0.9 }, "processing phase: \(values)")
        XCTAssertTrue(values.contains { $0 > 0.9 && $0 <= 1 }, "download phase: \(values)")

        // The job sent the operation without the client-only `cloud` switch, and
        // the signed download URL (another origin) never got our token.
        let jobs = try await mock.items("/__mock/jobs")
        let op = try XCTUnwrap(jobs.first?["operation"] as? [String: Any])
        XCTAssertEqual(op["type"] as? String, "convert")
        XCTAssertEqual(op["target"] as? String, "mp4")
        XCTAssertNil((op["options"] as? [String: Any])?["cloud"])
        let downloads = try await mock.requests().filter { ($0["path"] as? String ?? "").hasPrefix("/v1/files/") }
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads.first?["hasAuth"] as? Bool, false)
        XCTAssertEqual(downloads.first?["host"] as? String, "localhost:\(mock.port)")
    }

    func testTranscribeProducesSubtitlesBesideOriginal() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        try await f.signIn()
        let input = try f.makeFile("talk.m4a", bytes: 5000)
        let srt = f.services.makeCloudJob(input: input, operation: .transcribe(to: Formats.srt))
        let srtOutputs = try await srt.run(context: try f.jobContext())
        let out = try XCTUnwrap(srtOutputs.first)
        XCTAssertEqual(out.lastPathComponent, "talk-transcript.srt")
        let text = try String(contentsOf: out, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("1\n00:00:00,000 --> "))

        let vtt = f.services.makeCloudJob(input: input, operation: .transcribe(to: Formats.vtt))
        let vttOutputs = try await vtt.run(context: try f.jobContext())
        let out2 = try XCTUnwrap(vttOutputs.first)
        XCTAssertEqual(out2.lastPathComponent, "talk-transcript.vtt")
        XCTAssertTrue(try String(contentsOf: out2, encoding: .utf8).hasPrefix("WEBVTT"))
    }

    func testUpscaleAndHQBackgroundRemoval() async throws {
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        try await f.signIn()
        let input = try f.makeFile("photo.jpg", bytes: 2000)
        let up = try await f.services.makeCloudJob(input: input, operation: .upscale(scale: 4)).run(context: try f.jobContext())
        XCTAssertEqual(up.map(\.lastPathComponent), ["photo-upscaled.png"])
        let cut = try await f.services.makeCloudJob(input: input, operation: .removeBackgroundHQ).run(context: try f.jobContext())
        XCTAssertEqual(cut.map(\.lastPathComponent), ["photo-cutout-hq.png"])
    }

    func testCancelStopsServerJobAndLocalWork() async throws {
        try await mock.reset(["jobPolls": 100_000])
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        try await f.signIn()
        let input = try f.makeFile("long.mov", bytes: 10_000)
        let job = f.services.makeCloudJob(input: input, operation: .convert(target: Formats.mp4, options: OptionValues()))
        let context = try f.jobContext()
        let task = Task { try await job.run(context: context) }
        try await waitUntil("job running on the server") {
            let jobs = try await self.mock.items("/__mock/jobs")
            return (jobs.first?["polls"] as? Int ?? 0) >= 2
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("not cancelled") } catch is CancellationError {}
        try await waitUntil("server job cancelled") {
            let jobs = try await self.mock.items("/__mock/jobs")
            return jobs.first?["status"] as? String == "cancelled" && jobs.first?["cancelRequested"] as? Bool == true
        }
        let siblings = try FileManager.default.contentsOfDirectory(atPath: input.deletingLastPathComponent().path)
        XCTAssertEqual(siblings, ["long.mov"], "nothing placed")
        XCTAssertLessThan(job.progress.fractionCompleted, 0.9)
    }

    func testServerFailureIsAHumanError() async throws {
        try await mock.reset(["failJobs": true])
        try await mock.setUser(plan: "pro")
        let f = try fixture()
        try await f.signIn()
        let input = try f.makeFile("x.mov", bytes: 100)
        do {
            _ = try await f.services.makeCloudJob(input: input, operation: .convert(target: Formats.webm, options: OptionValues()))
                .run(context: try f.jobContext())
            XCTFail()
        } catch let e as CloudError {
            guard case .jobFailed(let message) = e else { return XCTFail("\(e)") }
            XCTAssertEqual(message, "The cloud worker couldn’t process this file.")
            XCTAssertFalse(e.technicalDetails.isEmpty)
        }
    }

    func testPhaseMapping() {
        XCTAssertEqual(CloudJobPhases.map(0, into: CloudJobPhases.upload), 0)
        XCTAssertEqual(CloudJobPhases.map(1, into: CloudJobPhases.upload), 0.45)
        XCTAssertEqual(CloudJobPhases.map(0.5, into: CloudJobPhases.processing), 0.675, accuracy: 1e-9)
        XCTAssertEqual(CloudJobPhases.map(2, into: CloudJobPhases.download), 1)
        XCTAssertEqual(CloudJobOperation.transcribe().feature, .transcription)
        XCTAssertEqual(CloudJobOperation.upscale().feature, .upscale)
        XCTAssertEqual(CloudJobOperation.removeBackgroundHQ.feature, .backgroundRemovalHQ)
        XCTAssertEqual(CloudJobOperation.convert(target: Formats.mp4, options: OptionValues()).feature, .cloudJobs)
        XCTAssertTrue(CloudJobOperation.wantsCloud(OptionValues([OptionKey.cloud: .bool(true)])))
        XCTAssertFalse(CloudJobOperation.wantsCloud(StandardSchemas.video.defaults))
    }

    func testEveryProToolInTheCatalogueHasACloudJob() {
        let pro = ToolCatalog.all.filter { $0.cloudFeature != nil }
        XCTAssertEqual(Set(pro.map(\.id)), [ToolIDs.transcribe, ToolIDs.upscale, ToolIDs.removeBackgroundHQ])
        for spec in pro {
            let op = CloudJobOperation.forTool(spec.id)
            XCTAssertNotNil(op, "\(spec.id)")
            XCTAssertEqual(op?.feature, spec.cloudFeature)
        }
        XCTAssertNil(CloudJobOperation.forTool(ToolIDs.compressImage), "local tools never become cloud jobs")
        XCTAssertEqual(CloudJobOperation.forTool(ToolIDs.transcribe, options: OptionValues(["format": .string("vtt")]))?.target, Formats.vtt)
        XCTAssertEqual(CloudJobOperation.forTool(ToolIDs.transcribe)?.target, Formats.srt)
        guard case .tool(_, _, let options)? = CloudJobOperation.forTool(ToolIDs.upscale) else { return XCTFail() }
        XCTAssertEqual(options["scale"], .int(2))
    }
}
