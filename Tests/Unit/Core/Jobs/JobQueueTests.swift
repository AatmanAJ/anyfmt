import Combine
import XCTest
@testable import AnyfmtCore

final class JobQueueTests: JobsTestCase {
    private let limits = ConcurrencyLimits(cpu: 2, videoToolbox: 1, io: 3, network: 2)

    @MainActor
    func testConcurrencyLimitsHonouredPerClassAndFIFO() async {
        let probe = ConcurrencyProbe()
        let queue = JobQueue(limits: limits, scratch: scratch)
        let cpu = (1...6).map { FakeJob("cpu\($0)", .cpu, probe: probe) }
        let vt = (1...3).map { FakeJob("vt\($0)", .videoToolbox, probe: probe) }
        let io = (1...5).map { FakeJob("io\($0)", .io, duration: 0.1, probe: probe) }
        let net = (1...3).map { FakeJob("net\($0)", .network, duration: 0.1, probe: probe) }
        // Interleave classes so one class's queue can't hide another's limit.
        for i in 0..<6 {
            if i < cpu.count { queue.submit(cpu[i]) }
            if i < vt.count { queue.submit(vt[i]) }
            if i < io.count { queue.submit(io[i]) }
            if i < net.count { queue.submit(net[i]) }
        }
        XCTAssertEqual(queue.runningCount(for: .cpu), 2)
        XCTAssertEqual(queue.runningCount(for: .videoToolbox), 1)
        XCTAssertEqual(queue.runningCount(for: .io), 3)
        XCTAssertEqual(queue.runningCount(for: .network), 2)
        await waitIdle(queue)

        XCTAssertEqual(probe.peak(.cpu), 2)
        XCTAssertEqual(probe.peak(.videoToolbox), 1)
        XCTAssertEqual(probe.peak(.io), 3)
        XCTAssertEqual(probe.peak(.network), 2)
        // FIFO within a class: the queue starts them in submission order (the
        // probe's own order can interleave when two detached tasks start together).
        for group in [cpu, vt, io, net] {
            let starts = group.compactMap { queue.record($0.id)?.startedAt }
            XCTAssertEqual(starts.count, group.count)
            XCTAssertEqual(starts, starts.sorted(), "FIFO within \(group[0].resourceClass)")
        }
        XCTAssertEqual(probe.starts(.videoToolbox), vt.map(\.title), "limit 1 → strictly sequential")
        XCTAssertTrue(queue.records.allSatisfy(\.didSucceed))
        XCTAssertTrue(scratchIsEmpty(), "every scratch folder removed")
    }

    func testSystemLimitsFollowPerformanceCores() {
        let p = ConcurrencyLimits.performanceCoreCount()
        XCTAssertGreaterThanOrEqual(p, 1)
        XCTAssertEqual(ConcurrencyLimits.system.cpu, max(1, p - 1))
        XCTAssertEqual(ConcurrencyLimits.system.videoToolbox, 1)
        XCTAssertEqual(ConcurrencyLimits.system.io, 4)
        XCTAssertEqual(ConcurrencyLimits.system.network, 2)
        XCTAssertEqual(ConcurrencyLimits(cpu: 0).cpu, 1, "never below one")
    }

    @MainActor
    func testProgressAndETAArePublished() async {
        let probe = ConcurrencyProbe()
        let queue = JobQueue(limits: limits, scratch: scratch)
        let job = FakeJob("slow", .cpu, duration: 1.6, probe: probe)
        queue.submit(job)
        await eventually("progress") { (queue.record(job.id)?.fraction ?? 0) >= 0.5 }
        XCTAssertEqual(queue.record(job.id)?.state, .running)
        XCTAssertNotNil(queue.record(job.id)?.startedAt)
        await eventually("eta") { queue.record(job.id)?.eta != nil }
        if let eta = queue.record(job.id)?.eta { XCTAssertLessThan(eta, 5) }
        await waitIdle(queue)
        let rec = queue.record(job.id)
        XCTAssertEqual(rec?.fraction, 1)
        XCTAssertNil(rec?.eta)
        XCTAssertNotNil(rec?.finishedAt)
    }

    /// Cancel a running conversion whose engine runs a real child process, and a queued one.
    @MainActor
    func testCancelRunningAndQueued() async throws {
        let pid = Box<Int32>(0)
        let wrote = Box<URL?>(nil)
        let engine = ScriptedEngine(EngineIDs.ffmpeg) { request, _ in
            // Leave something in the scratch folder to prove it's cleaned up.
            let partial = request.outputDirectory.appendingPathComponent("partial.tmp")
            try Data("half".utf8).write(to: partial)
            wrote.set(partial)
            _ = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/sh"), ["-c", "echo $$; exec /bin/sleep 30"],
                                            onStdoutLine: { line in if let p = Int32(line) { pid.set(p) } })
            return ConversionOutput(request.defaultOutputURL)
        }
        let input = try makeFiles(["clip.mov"])[0]
        let running = ConversionJob(inputs: [input], route: directRoute("mov", "mp4", EngineIDs.ffmpeg),
                                    registry: EngineRegistry([engine]))
        let probe = ConcurrencyProbe()
        // Same class as the running encode, so it waits behind it.
        let queued = FakeJob("queued", .videoToolbox, probe: probe)
        let queue = JobQueue(limits: ConcurrencyLimits(cpu: 1), scratch: scratch)
        var finished: [UUID] = []
        queue.onJobFinished = { finished.append($0.id) }
        queue.submit(running)
        queue.submit(queued)
        XCTAssertEqual(running.resourceClass, .videoToolbox, "mov→mp4 counts as a hardware encode")

        await eventually("child process started") { pid.get > 0 }
        let jobDir = scratch.directory(for: running.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: jobDir.path))
        XCTAssertEqual(kill(pid.get, 0), 0, "child alive before cancel")

        queue.cancel(queued.id)
        XCTAssertEqual(queue.record(queued.id)?.state, .cancelled, "queued job cancels immediately")

        let started = Date()
        queue.cancel(running.id)
        XCTAssertEqual(queue.record(running.id)?.cancelRequested, true)
        await waitIdle(queue)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5, "SIGTERM, not a 30 s wait")
        XCTAssertEqual(queue.record(running.id)?.state, .cancelled)
        XCTAssertNil(queue.record(running.id)?.errorMessage, "cancel isn't an error")
        XCTAssertFalse(FileManager.default.fileExists(atPath: jobDir.path), "temp dir removed on cancel")
        XCTAssertFalse(FileManager.default.fileExists(atPath: wrote.get?.path ?? "/nonexistent-x"))
        errno = 0
        XCTAssertEqual(kill(pid.get, 0), -1, "child process gone")
        XCTAssertEqual(errno, ESRCH)
        XCTAssertTrue(probe.anyStarted.isEmpty, "the queued job never ran")
        XCTAssertEqual(Set(finished), [running.id, queued.id], "hook fires for cancelled jobs too")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: input.deletingLastPathComponent().path), ["clip.mov"],
                       "nothing placed beside the original")
    }

    @MainActor
    func testCancelAllAndBatchCancel() async {
        let probe = ConcurrencyProbe()
        let queue = JobQueue(limits: ConcurrencyLimits(cpu: 1), scratch: scratch)
        let jobs = (1...4).map { FakeJob("j\($0)", .cpu, duration: 5, probe: probe) }
        let batch = queue.submitBatch(jobs, title: "4 files")
        XCTAssertEqual(queue.runningCount, 1)
        queue.cancel(batch)
        await waitIdle(queue)
        XCTAssertTrue(queue.records(inBatch: batch).allSatisfy(\.wasCancelled))
        XCTAssertTrue(probe.starts(.cpu).allSatisfy { $0 == "j1" }, "cancelling the batch doesn't start the rest")

        let more = (1...3).map { FakeJob("m\($0)", .cpu, duration: 5, probe: probe) }
        more.forEach { queue.submit($0) }
        queue.cancelAll()
        await waitIdle(queue)
        XCTAssertTrue(more.allSatisfy { queue.record($0.id)?.wasCancelled == true })
        XCTAssertTrue(scratchIsEmpty())
    }

    @MainActor
    func testFailureGivesHumanMessageAndDetails() async throws {
        let engine = ScriptedEngine("ffmpeg") { _, _ in
            throw ConversionError.engineFailed("ffmpeg", status: 1, detail: "moov atom not found")
        }
        let input = try makeFiles(["broken.mov"])[0]
        let job = ConversionJob(inputs: [input], route: directRoute("mov", "mp4", "ffmpeg"), registry: EngineRegistry([engine]))
        let queue = JobQueue(limits: limits, scratch: scratch)
        queue.submit(job)
        let rec = await queue.waitForJob(job.id)
        guard case .failed(let message, let details)? = rec?.state else { return XCTFail("expected failure, got \(String(describing: rec?.state))") }
        XCTAssertEqual(message, "The conversion stopped unexpectedly. The original file is untouched.")
        XCTAssertEqual(rec?.errorMessage, message)
        XCTAssertEqual(rec?.errorDetails, details)
        XCTAssertEqual(rec?.failedTitle, "Couldn’t convert to MP4")
        for needle in ["ffmpeg exited 1", "moov atom not found", "Route: mov → mp4(ffmpeg)", Brand.name, "macOS", "broken.mov → MP4"] {
            XCTAssertTrue(details.contains(needle), "details should contain “\(needle)”:\n\(details)")
        }
        XCTAssertFalse(details.contains(root.path), "no full paths in bug reports")
        XCTAssertTrue(scratchIsEmpty(), "temp dir removed on failure")
        XCTAssertEqual(contents(input), "broken.mov", "original untouched")
    }

    @MainActor
    func testRetryRunsAgainWithFreshPolicy() async throws {
        let attempts = Box(0)
        let engine = ScriptedEngine("flaky") { request, context in
            attempts.mutate { $0 += 1 }
            if attempts.get == 1 { throw ConversionError.engineFailed("flaky", status: 9, detail: "first time unlucky") }
            return try await ScriptedEngine.writeOutput(request, context)
        }
        let input = try makeFiles(["song.wav"])[0]
        let elsewhere = root.appendingPathComponent("chosen", isDirectory: true)
        var policy = OutputPolicy.default
        let queue = JobQueue(limits: limits, scratch: scratch, policyProvider: { policy })
        let job = ConversionJob(inputs: [input], route: directRoute("wav", "mp3", "flaky"), registry: EngineRegistry([engine]))
        queue.submit(job)
        let first = await queue.waitForJob(job.id)
        XCTAssertEqual(first?.didFail, true)
        XCTAssertFalse(queue.retry(UUID()), "unknown id")

        policy.location = .folder(elsewhere)
        XCTAssertTrue(queue.retry(job.id))
        XCTAssertEqual(queue.record(job.id)?.attempt, 2)
        let second = await queue.waitForJob(job.id)
        XCTAssertEqual(second?.didSucceed, true)
        XCTAssertNil(second?.errorMessage)
        XCTAssertEqual(second?.outputs.map(\.lastPathComponent), ["song.mp3"])
        XCTAssertEqual(second?.outputs.first?.deletingLastPathComponent().lastPathComponent, "chosen", "retry uses the current policy")
        XCTAssertFalse(queue.retry(job.id), "succeeded jobs are never re-run")
    }

    @MainActor
    func testBatchAggregatesAndFinishHook() async {
        let probe = ConcurrencyProbe()
        let queue = JobQueue(limits: limits, scratch: scratch)
        var batchDone: (JobBatch, BatchProgress)?
        queue.onBatchFinished = { batchDone = ($0, $1) }
        let jobs: [any Job] = [
            FakeJob("a", .cpu, probe: probe),
            FakeJob("b", .cpu, probe: probe, failure: ConversionError.outputMissing("b")),
            FakeJob("c", .cpu, probe: probe),
        ]
        let id = queue.submitBatch(jobs, title: "3 files → JPG", note: "1 already JPG", fileCount: 4)
        XCTAssertEqual(queue.batch(id)?.fileCount, 4)
        await waitIdle(queue)
        let progress = BatchProgress(queue.records(inBatch: id))
        XCTAssertEqual(progress.total, 3)
        XCTAssertEqual(progress.succeeded, 2)
        XCTAssertEqual(progress.failed, 1)
        XCTAssertEqual(progress.fraction, 1)
        XCTAssertEqual(batchDone?.0.id, id)
        XCTAssertEqual(batchDone?.1.failed, 1)
        XCTAssertEqual(queue.batch(id)?.fraction, 1)

        XCTAssertTrue(queue.retry(id), "batch retry re-runs only the failed job")
        XCTAssertEqual(queue.records(inBatch: id).filter(\.isQueued).count + queue.records(inBatch: id).filter(\.isRunning).count, 1)
        await waitIdle(queue)

        queue.clearFinished()
        XCTAssertTrue(queue.records.isEmpty)
        XCTAssertTrue(queue.batches.isEmpty)
    }

    @MainActor
    func testIdleQueueStopsPolling() async throws {
        let probe = ConcurrencyProbe()
        let queue = JobQueue(limits: limits, scratch: scratch)
        queue.submit(FakeJob("x", .cpu, duration: 0.05, probe: probe))
        await waitIdle(queue)
        // No running jobs → no further record publications.
        var publications = 0
        let sub = queue.$records.dropFirst().sink { _ in publications += 1 }
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(publications, 0)
        sub.cancel()
    }

    func testFailureMapping() {
        XCTAssertTrue(JobFailure.from(CancellationError()).isCancellation)
        XCTAssertTrue(JobFailure.from(ConversionError.cancelled).isCancellation)
        let missing = JobFailure.from(CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: "/x/gone.png"]))
        XCTAssertEqual(missing.message, "“gone.png” couldn’t be found. It may have been moved or deleted.")
        let space = JobFailure.from(CocoaError(.fileWriteOutOfSpace))
        XCTAssertTrue(space.message.contains("disk space"))
        struct Odd: Error {}
        let odd = JobFailure.from(Odd())
        XCTAssertEqual(odd.message, "Something went wrong. The original file is untouched.")
        XCTAssertTrue(odd.details.contains("Odd"))
    }
}
