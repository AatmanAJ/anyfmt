import XCTest
@testable import AnyfmtCore

/// Metadata policies on real files, through both engines.
final class AVMetadataTests: XCTestCase {
    private func keys(_ url: URL) async throws -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in try await LaneE.formatTags(url) { out[k.lowercased()] = v }
        let json = try await LaneE.probeJSON(url)
        for s in (json["streams"] as? [[String: Any]]) ?? [] {
            for (k, v) in (s["tags"] as? [String: String]) ?? [:] { out["stream." + k.lowercased()] = v }
        }
        return out
    }

    /// Private keys left in ffprobe's view (container or stream level, any case).
    private func privateKeys(_ tags: [String: String]) -> [String] {
        tags.keys.filter { $0.contains("location") || $0.hasSuffix("make") || $0.hasSuffix("model") || $0.hasSuffix("software") }.sorted()
    }

    /// Private items left in Apple's view.
    private func applePrivate(_ md: [String: String]) -> [String] {
        md.keys.filter { $0.lowercased().contains("location") || $0.contains("%A9xyz") || $0.contains("loci")
            || $0.hasSuffix("make") || $0.contains("%A9mak") || $0.hasSuffix("model") || $0.contains("%A9mod") }.sorted()
    }

    func testFFmpegKeepStripPrivateStripAll() async throws {
        for fixture in ["edge-location.mp4", "edge-location.mov"] {
            let src = try LaneE.fixture(fixture)
            let keep = try await keys(try await LaneE.convert(src, to: Formats.mkv))
            XCTAssertNotNil(keep["location"], "\(fixture): keep keeps location: \(keep)")
            XCTAssertEqual(keep["title"], "Private trip")
            XCTAssertNil(keep["major_brand"], "\(fixture): ftyp pseudo-tags never become Matroska tags")

            let priv = try await keys(try await LaneE.convert(src, to: Formats.mkv, metadata: .stripPrivate))
            XCTAssertEqual(privateKeys(priv), [], "\(fixture): \(priv)")
            XCTAssertEqual(priv["title"], "Private trip", "non-private tags stay")

            let webm = try await keys(try await LaneE.convert(src, to: Formats.webm, metadata: .stripPrivate))
            XCTAssertEqual(privateKeys(webm), [], "re-encode path too: \(webm)")

            let all = try await keys(try await LaneE.convert(src, to: Formats.mkv, metadata: .stripAll))
            XCTAssertNil(all["title"])
            XCTAssertNil(all["creation_time"])
            XCTAssertEqual(privateKeys(all), [])
            XCTAssertTrue(all["encoder"] == nil || all["encoder"] == "Lavf", "at most the bare muxer name: \(all)")
        }
    }

    /// iPhone clips keep metadata as QuickTime `mdta` keys. ffmpeg translates the
    /// useful ones into standard tags Apple apps read.
    func testIPhoneMetadataThroughFFmpeg() async throws {
        let src = try await LaneE.makeAppleMetadataMovie()
        let mkv = try await keys(try await LaneE.convert(src, to: Formats.mkv))
        XCTAssertEqual(mkv["title"], "Private trip", "\(mkv)")
        XCTAssertEqual(mkv["location"], "+37.3349-122.0090+010.000/")
        XCTAssertEqual(mkv["creation_time"]?.hasPrefix("2024-05-01T10:00:00"), true, "capture time, in UTC: \(mkv)")

        let privMKV = try await keys(try await LaneE.convert(src, to: Formats.mkv, metadata: .stripPrivate))
        XCTAssertEqual(privateKeys(privMKV), [], "\(privMKV)")
        XCTAssertEqual(privMKV["title"], "Private trip")
        XCTAssertEqual(privMKV["creation_time"]?.hasPrefix("2024-05-01T10:00:00"), true)

        // A resolution change sends mov → mp4 through ffmpeg; Apple's reader still sees the essentials.
        let opts: [String: OptionValue] = [OptionKey.resolution: .string("120")]
        let mp4 = try await LaneE.convert(src, to: Formats.mp4, engine: AVFoundationEngine(), options: opts)
        let apple = try await LaneE.appleMetadata(mp4)
        XCTAssertEqual(apple["itsk/%A9nam"], "Private trip", "\(apple)")
        XCTAssertEqual(apple["creationDate"], "2024-05-01T10:00:00Z")
        let privMP4 = try await LaneE.convert(src, to: Formats.mp4, engine: AVFoundationEngine(), options: opts, metadata: .stripPrivate)
        let privApple = try await LaneE.appleMetadata(privMP4)
        let privProbe = try await keys(privMP4)
        XCTAssertEqual(applePrivate(privApple), [], "\(privApple)")
        XCTAssertEqual(privateKeys(privProbe), [], "\(privProbe)")
        XCTAssertEqual(privApple["itsk/%A9nam"], "Private trip")
    }

    /// The reason AVFoundation owns MOV ⇄ MP4: passthrough carries iPhone metadata.
    func testAVFoundationPassthroughPolicies() async throws {
        let src = try await LaneE.makeAppleMetadataMovie()
        let keepMP4 = try await LaneE.convert(src, to: Formats.mp4, engine: AVFoundationEngine())
        let apple = try await LaneE.appleMetadata(keepMP4)
        XCTAssertEqual(apple["creationDate"], "2024-05-01T10:00:00Z", "\(apple)")
        XCTAssertFalse(applePrivate(apple).isEmpty, "keep carries the location: \(apple)")
        let keepProbe = try await keys(keepMP4)
        XCTAssertNotNil(keepProbe["location"], "ffprobe sees it too: \(keepProbe)")

        let keepM4V = try await LaneE.appleMetadata(try await LaneE.convert(src, to: Formats.m4v, engine: AVFoundationEngine()))
        XCTAssertFalse(keepM4V.isEmpty)

        let priv = try await LaneE.convert(src, to: Formats.mp4, engine: AVFoundationEngine(), metadata: .stripPrivate)
        let privApple = try await LaneE.appleMetadata(priv)
        XCTAssertEqual(applePrivate(privApple), [], "\(privApple)")
        let privProbe = try await keys(priv)
        XCTAssertEqual(privateKeys(privProbe), [], "\(privProbe)")
        XCTAssertEqual(privApple["creationDate"], "2024-05-01T10:00:00Z", "the capture date isn't private")

        let all = try await LaneE.convert(src, to: Formats.m4v, engine: AVFoundationEngine(), metadata: .stripAll)
        let allApple = try await LaneE.appleMetadata(all)
        XCTAssertEqual(applePrivate(allApple), [], "\(allApple)")
        XCTAssertNil(allApple["itsk/%A9nam"])
        XCTAssertNotEqual(allApple["creationDate"], "2024-05-01T10:00:00Z", "stripAll drops the capture date too")
    }

    func testAudioTagsAndCoverStripAll() async throws {
        let src = try LaneE.fixture("edge-cover.mp3")
        let out = try await LaneE.convert(src, to: Formats.flac, metadata: .stripAll)
        let tags = try await keys(out)
        XCTAssertNil(tags["title"])
        XCTAssertNil(tags["artist"])
        let facts = try await LaneE.probe(out)
        XCTAssertNil(facts.coverArt, "stripAll drops album art")
        let priv = try await LaneE.probe(try await LaneE.convert(src, to: Formats.m4a, metadata: .stripPrivate))
        XCTAssertNotNil(priv.coverArt, "album art isn't private")
    }
}

/// Cancelling a job must stop the child process at once and leave nothing behind.
final class AVCancellationTests: XCTestCase {
    private func ffmpegProcesses(touching dir: URL) async throws -> [String] {
        let r = try await ProcessRunner.run(URL(fileURLWithPath: "/bin/ps"), ["-axww", "-o", "pid=,command="])
        return r.stdoutString.split(separator: "\n").map(String.init).filter { $0.contains(dir.path) && $0.contains("ffmpeg") }
    }

    func testCancelKillsFFmpegWithoutOrphans() async throws {
        let clip = try await LaneE.makeClip(seconds: 20, size: "1280x720")
        let outDir = try LaneE.tempDirectory()
        let started = ProgressRecorder()
        let req = ConversionRequest(inputs: [clip], from: Formats.mov, to: Formats.webm, options: StandardSchemas.video.defaults,
                                    outputDirectory: outDir, baseName: "out", metadata: .keep)
        let ctx = EngineContext(progress: ProgressSink { started.add($0) }, locator: LaneE.locator)
        let task = Task { try await FFmpegAVEngine().convert(req, context: ctx) }

        // Wait until ffmpeg is really encoding.
        let deadline = Date().addingTimeInterval(15)
        var running: [String] = []
        while Date() < deadline {
            running = try await ffmpegProcesses(touching: outDir)
            if !running.isEmpty && !started.values.isEmpty { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertFalse(running.isEmpty, "ffmpeg should be running")
        let t0 = Date()
        task.cancel()
        let result = await task.result
        XCTAssertThrowsError(try result.get()) { XCTAssertTrue($0 is CancellationError, "\($0)") }
        XCTAssertLessThan(Date().timeIntervalSince(t0), 3, "SIGTERM, then SIGKILL after 2 s at most")

        var left = try await ffmpegProcesses(touching: outDir)
        for _ in 0..<30 where !left.isEmpty {
            try await Task.sleep(nanoseconds: 100_000_000)
            left = try await ffmpegProcesses(touching: outDir)
        }
        XCTAssertEqual(left, [], "no orphan ffmpeg")
        XCTAssertFalse(FileManager.default.fileExists(atPath: req.defaultOutputURL.path), "partial output removed")
        XCTAssertLessThan(started.values.max() ?? 1, 1, "never reported done")
    }

    func testCancelAVFoundationExport() async throws {
        // No ffmpeg in this context, and a resize, so AVFoundation re-encodes itself (slow enough to cancel).
        let clip = try await LaneE.makeClip(seconds: 30, size: "1920x1080")
        let req = ConversionRequest(inputs: [clip], from: Formats.mov, to: Formats.mp4,
                                    options: StandardSchemas.video.defaults.merging(OptionValues([OptionKey.resolution: .string("720")])),
                                    outputDirectory: try LaneE.tempDirectory(), baseName: "out", metadata: .keep)
        let ctx = EngineContext(locator: EngineLocator(helperDirectories: []))
        let task = Task { try await AVFoundationEngine().convert(req, context: ctx) }
        try await Task.sleep(nanoseconds: 400_000_000)
        task.cancel()
        let result = await task.result
        switch result {
        case .success: XCTFail("finished before cancel; make the clip longer")
        case .failure(let e): XCTAssertTrue(e is CancellationError, "\(e)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: req.defaultOutputURL.path))
    }
}
