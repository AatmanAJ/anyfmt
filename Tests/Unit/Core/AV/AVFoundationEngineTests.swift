import XCTest
@testable import AnyfmtCore

final class AVFoundationEngineTests: XCTestCase {
    private func request(_ to: FormatID, _ opts: [String: OptionValue] = [:]) -> ConversionRequest {
        ConversionRequest(inputs: [URL(fileURLWithPath: "/tmp/x.mov")], from: Formats.mov, to: to,
                          options: StandardSchemas.video.defaults.merging(OptionValues(opts)),
                          outputDirectory: URL(fileURLWithPath: "/tmp"), baseName: "x", metadata: .keep)
    }

    func testDecisions() {
        typealias E = AVFoundationEngine
        XCTAssertEqual(E.decide(request(Formats.mp4), ffmpegAvailable: true), .passthrough)
        XCTAssertEqual(E.decide(request(Formats.mp4, [OptionKey.videoQuality: .string("high")]), ffmpegAvailable: true), .passthrough)
        XCTAssertEqual(E.decide(request(Formats.mp4, [OptionKey.hardware: .bool(false)]), ffmpegAvailable: true), .passthrough)
        XCTAssertEqual(E.decide(request(Formats.mp4, [OptionKey.resolution: .string("720")]), ffmpegAvailable: true), .delegate("resolution"))
        XCTAssertEqual(E.decide(request(Formats.mp4, [OptionKey.fps: .string("24")]), ffmpegAvailable: true), .delegate("frame rate"))
        XCTAssertEqual(E.decide(request(Formats.mp4, [OptionKey.videoQuality: .string("small")]), ffmpegAvailable: true), .delegate("small file"))
        XCTAssertEqual(E.decide(request(Formats.mp4, [OptionKey.audio: .string("remove")]), ffmpegAvailable: true), .delegate("remove audio"))
        XCTAssertEqual(E.decide(request(Formats.m4a), ffmpegAvailable: true), .delegate("m4a options"))
        XCTAssertEqual(E.decide(request(Formats.m4a), ffmpegAvailable: false), .appleM4A)
        XCTAssertEqual(E.decide(request(Formats.mp4, [OptionKey.resolution: .string("720")]), ffmpegAvailable: false),
                       .reencode("AVAssetExportPreset1280x720"))
        XCTAssertEqual(E.reencodePreset(OptionValues([OptionKey.videoQuality: .string("small")])), "AVAssetExportPresetMediumQuality")
        let stripAll = ConversionRequest(inputs: [URL(fileURLWithPath: "/tmp/x.mov")], from: Formats.mov, to: Formats.mp4,
                                         options: StandardSchemas.video.defaults, outputDirectory: URL(fileURLWithPath: "/tmp"),
                                         baseName: "x", metadata: .stripAll)
        XCTAssertEqual(E.decide(stripAll, ffmpegAvailable: true), .delegate("strip all metadata"))
        XCTAssertEqual(E.decide(stripAll, ffmpegAvailable: false), .passthrough, "best effort without ffmpeg")
    }

    func testPassthroughRemuxBetweenQuickTimeContainers() async throws {
        for (fixture, to) in [("sample.mov", Formats.mp4), ("sample.mp4", Formats.m4v), ("sample.m4v", Formats.mov), ("sample.mp4", Formats.mov)] {
            let src = try LaneE.fixture(fixture)
            let out = try await LaneE.convert(src, to: to, engine: AVFoundationEngine())
            let f = try await LaneE.probe(out)
            XCTAssertEqual(f.video?.codec, "h264", fixture)
            XCTAssertEqual(f.primaryAudio?.codec, "aac", fixture)
            XCTAssertEqual(f.duration ?? 0, 2.0, accuracy: 0.1, fixture)
            XCTAssertEqual(f.video?.width, 320)
            // Passthrough copies samples: the bitstream size is unchanged.
            let srcSize = (try FileManager.default.attributesOfItem(atPath: src.path)[.size] as? Int) ?? 0
            let outSize = (try FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
            XCTAssertEqual(Double(outSize), Double(srcSize), accuracy: Double(srcSize) * 0.05, "\(fixture) → \(to)")
        }
    }

    func testPassthroughKeepsHEVC() async throws {
        let out = try await LaneE.convert(try LaneE.fixture("edge-hevc.mov"), to: Formats.mp4, engine: AVFoundationEngine())
        let json = try await LaneE.probeJSON(out)
        let video = (json["streams"] as? [[String: Any]])?.first { $0["codec_type"] as? String == "video" }
        XCTAssertEqual(video?["codec_name"] as? String, "hevc")
        XCTAssertEqual(video?["codec_tag_string"] as? String, "hvc1")
    }

    func testOptionsThatNeedReencodeGoToFFmpeg() async throws {
        let out = try await LaneE.convert(try LaneE.fixture("sample.mov"), to: Formats.mp4, engine: AVFoundationEngine(),
                                          options: [OptionKey.resolution: .string("120")])
        let f = try await LaneE.probe(out)
        XCTAssertEqual(f.video?.width, 160)
        XCTAssertEqual(f.video?.height, 120)
    }

    func testIncompatibleSourceFallsBackToFFmpeg() async throws {
        // ProRes can't be passed through into MP4; ffmpeg re-encodes it to H.264.
        let dir = try LaneE.tempDirectory()
        let prores = dir.appendingPathComponent("prores.mov")
        try await LaneE.ffmpeg(["-i", try LaneE.fixture("sample.mov").path, "-c:v", "prores_ks", "-profile:v", "lt", "-c:a", "pcm_s16le", prores.path])
        let out = try await LaneE.convert(prores, to: Formats.mp4, engine: AVFoundationEngine())
        let f = try await LaneE.probe(out)
        XCTAssertEqual(f.video?.codec, "h264")
        XCTAssertEqual(f.primaryAudio?.codec, "aac")
        XCTAssertEqual(f.duration ?? 0, 2.0, accuracy: 0.1)
    }

    func testWithoutFFmpegItStillWorks() async throws {
        let noFFmpeg = EngineContext(locator: EngineLocator(helperDirectories: []))
        let m4a = try await LaneE.convert(try LaneE.fixture("sample.mp3"), to: Formats.m4a, engine: AVFoundationEngine(), context: noFFmpeg)
        let audio = try await LaneE.probe(m4a)
        XCTAssertEqual(audio.primaryAudio?.codec, "aac")
        XCTAssertEqual(audio.duration ?? 0, 2.0, accuracy: 0.1)
        for fixture in ["sample.wav", "sample.flac", "sample.mp4"] {
            let out = try await LaneE.convert(try LaneE.fixture(fixture), to: Formats.m4a, engine: AVFoundationEngine(), context: noFFmpeg)
            let probed = try await LaneE.probe(out)
            XCTAssertEqual(probed.primaryAudio?.codec, "aac", fixture)
            XCTAssertNil(probed.video, "\(fixture): M4A export drops video")
        }
        let resized = try await LaneE.convert(try LaneE.fixture("sample.mov"), to: Formats.mp4, engine: AVFoundationEngine(),
                                              options: [OptionKey.resolution: .string("480")], context: noFFmpeg)
        let resizedFacts = try await LaneE.probe(resized)
        XCTAssertEqual(resizedFacts.video?.codec, "h264")
    }

    func testUnreadableInput() async throws {
        let dir = try LaneE.tempDirectory()
        let bad = dir.appendingPathComponent("bad.mov")
        try Data("nope".utf8).write(to: bad)
        do {
            _ = try await LaneE.convert(bad, to: Formats.mp4, engine: AVFoundationEngine(), context: EngineContext(locator: EngineLocator(helperDirectories: [])))
            XCTFail("expected an error")
        } catch is ConversionError {}
    }
}
