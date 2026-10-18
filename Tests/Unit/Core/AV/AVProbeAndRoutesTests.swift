import XCTest
@testable import HaloCore

final class AVProbeTests: XCTestCase {
    func testDecodesRotationCoverDepthAndBitrate() throws {
        let json = """
        {"streams":[
          {"index":0,"codec_type":"video","codec_name":"h264","width":1920,"height":1080,"pix_fmt":"yuv420p",
           "r_frame_rate":"30/1","avg_frame_rate":"20/1","bits_per_raw_sample":"8",
           "side_data_list":[{"side_data_type":"Display Matrix","displaymatrix":"...","rotation":-90}],
           "disposition":{"default":1,"attached_pic":0},"tags":{"location":"+1+2/"}},
          {"index":1,"codec_type":"audio","codec_name":"flac","sample_rate":"96000","channels":2,"sample_fmt":"s32",
           "bits_per_raw_sample":"24","disposition":{"default":0}},
          {"index":2,"codec_type":"audio","codec_name":"aac","sample_rate":"48000","channels":6,"sample_fmt":"fltp",
           "bit_rate":"384000","disposition":{"default":1}},
          {"index":3,"codec_type":"video","codec_name":"mjpeg","width":600,"height":600,"disposition":{"attached_pic":1}},
          {"index":4,"codec_type":"subtitle","codec_name":"subrip"},
          {"index":5,"codec_type":"data","codec_name":"bin_data"}
        ],"format":{"duration":"12.5","tags":{"title":"T"}}}
        """
        let f = try AVProbe.facts(fromJSON: Data(json.utf8), url: URL(fileURLWithPath: "/x.mkv"))
        XCTAssertEqual(f.duration, 12.5)
        XCTAssertEqual(f.video?.rotation, 270)
        XCTAssertEqual(f.video?.displayWidth, 1080)
        XCTAssertEqual(f.video?.displayHeight, 1920)
        XCTAssertEqual(f.video?.isVariableFrameRate, true)
        XCTAssertEqual(f.audio.map(\.codec), ["flac", "aac"])
        XCTAssertEqual(f.audio[0].bitDepth, 24)
        XCTAssertNil(f.audio[1].bitDepth, "lossy sources have no integer depth")
        XCTAssertEqual(f.audio[1].bitRate, 384_000)
        XCTAssertEqual(f.primaryAudio?.index, 2, "the default track wins")
        XCTAssertEqual(f.coverArt, .init(index: 3, codec: "mjpeg"))
        XCTAssertEqual(f.subtitles, [.init(index: 4, codec: "subrip")])
        XCTAssertEqual(f.formatTags["title"], "T")
        XCTAssertEqual(f.streamTags[0]?["location"], "+1+2/")
    }

    func testLenientOnOddFieldTypes() throws {
        let json = #"{"streams":[{"index":0,"codec_type":"audio","codec_name":"pcm_s24le","sample_rate":"44100","channels":2,"disposition":{"default":"yes"},"bit_rate":12}],"format":{}}"#
        let f = try AVProbe.facts(fromJSON: Data(json.utf8), url: URL(fileURLWithPath: "/x.wav"))
        XCTAssertEqual(f.audio.first?.bitDepth, 24)
        XCTAssertNil(f.audio.first?.bitRate)
    }

    func testHelpers() {
        XCTAssertEqual(AVProbe.rate("30000/1001") ?? 0, 29.97, accuracy: 0.01)
        XCTAssertNil(AVProbe.rate("0/0"))
        XCTAssertEqual([0, 90, -90, 180, -180, 270, 360, 450, 89.6].map(AVProbe.normalise), [0, 90, 270, 180, 180, 270, 0, 90, 90])
        XCTAssertEqual(AVProbe.audioDepth(codec: "pcm_s16be", sampleFormat: "s16", raw: nil, coded: nil), 16)
        XCTAssertEqual(AVProbe.audioDepth(codec: "alac", sampleFormat: "s32p", raw: nil, coded: nil), 24)
        XCTAssertEqual(AVProbe.audioDepth(codec: "flac", sampleFormat: "s16", raw: nil, coded: nil), 16)
        XCTAssertNil(AVProbe.audioDepth(codec: "mp3", sampleFormat: "fltp", raw: nil, coded: nil))
    }

    func testRealFixturesProbe() async throws {
        let rotated = try await LaneE.probe(try LaneE.fixture("edge-rotated.mp4"))
        XCTAssertEqual(rotated.video?.rotation, 90)
        let cover = try await LaneE.probe(try LaneE.fixture("edge-cover.mp3"))
        XCTAssertEqual(cover.coverArt?.codec, "png")
        XCTAssertNil(cover.video)
        let flac = try await LaneE.probe(try LaneE.fixture("edge-24bit.flac"))
        XCTAssertEqual(flac.primaryAudio?.bitDepth, 24)
        let vfr = try await LaneE.probe(try LaneE.fixture("edge-vfr.mp4"))
        XCTAssertEqual(vfr.video?.isVariableFrameRate, true)
        let wma = try await LaneE.probe(try LaneE.fixture("sample.wma"))
        XCTAssertEqual(wma.primaryAudio?.codec, "wmav2")
    }
}

final class FFmpegProgressParserTests: XCTestCase {
    func testFractionsFromOutTime() {
        let rec = ProgressRecorder()
        let p = FFmpegProgressParser(duration: 2, sink: ProgressSink { rec.add($0) })
        for line in ["frame=10", "out_time_us=500000", "out_time_ms=1000000", "out_time=00:00:01.000000",
                     "out_time_us=900000", "speed=2x", "out_time_us=N/A", "garbage", "progress=continue", "out_time_us=1500000", "progress=end"] {
            p.feed(line)
        }
        XCTAssertEqual(rec.values, [0.25, 0.5, 0.75], "monotonic: the 0.45 regression is dropped; `end` isn't completion")
        XCTAssertEqual(p.lastFraction, 0.75)
    }

    /// ffmpeg prints `progress=end` even when it's killed on cancel, so the parser
    /// never reports completion; `FFmpeg.run` does that after a successful exit.
    func testCapsBelowOneAndIgnoresEnd() {
        let rec = ProgressRecorder()
        let p = FFmpegProgressParser(duration: 1, sink: ProgressSink { rec.add($0) })
        p.feed("out_time_us=5000000")
        XCTAssertEqual(rec.values, [0.999])
        p.feed("progress=end")
        XCTAssertEqual(rec.values, [0.999])
    }

    func testNoDurationReportsNothing() {
        let rec = ProgressRecorder()
        let p = FFmpegProgressParser(duration: nil, sink: ProgressSink { rec.add($0) })
        p.feed("out_time_us=5000000")
        p.feed("progress=end")
        XCTAssertEqual(rec.values, [])
    }

    func testScaledSinkMapsPasses() {
        let rec = ProgressRecorder()
        let sink = ProgressSink { rec.add($0) }
        sink.scaled(0.35...1)(0.5)
        sink.scaled(0...0.35)(1)
        XCTAssertEqual(rec.values[0], 0.675, accuracy: 1e-9)
        XCTAssertEqual(rec.values[1], 0.35, accuracy: 1e-9)
    }
}

final class AVRoutesTests: XCTestCase {
    func testRowCountsAndFamilies() {
        let ff = AVRoutes.rows.filter { $0.engine == EngineIDs.ffmpeg }
        let avf = AVRoutes.rows.filter { $0.engine == EngineIDs.avFoundation }
        XCTAssertEqual(ff.count, 64 + 42 + 7 + 56 + 4, "audio⇄audio, video⇄video, →gif, extraction, gif→")
        XCTAssertEqual(avf.count, 6 + 8)
        XCTAssertEqual(Set(AVRoutes.rows.map { "\($0.from)>\($0.to)@\($0.engine)" }).count, AVRoutes.rows.count, "no duplicates")
        XCTAssertFalse(AVRoutes.rows.contains { $0.from == $0.to })
        XCTAssertFalse(ff.contains { $0.from == Formats.wma && $0.to == Formats.wma })
        XCTAssertFalse(ff.contains { $0.to == Formats.wma }, "WMA is input only")
    }

    func testFlagsSchemasAndPriorities() {
        for r in AVRoutes.rows {
            switch r.to {
            case Formats.wav, Formats.flac, Formats.aiff, Formats.caf:
                XCTAssertTrue(r.flags.contains(.lossless), "\(r)")
                XCTAssertEqual(r.schema, StandardSchemas.audioLossless, "\(r)")
            case Formats.mp3, Formats.m4a, Formats.ogg, Formats.opus:
                XCTAssertFalse(r.flags.contains(.lossless), "\(r)")
                XCTAssertEqual(r.schema, StandardSchemas.audioLossy, "\(r)")
            case Formats.gif:
                XCTAssertEqual(r.schema, StandardSchemas.gif)
            default:
                XCTAssertEqual(r.schema, StandardSchemas.video, "\(r)")
            }
            switch r.engine {
            case EngineIDs.ffmpeg: XCTAssertEqual(r.priority, 90)
            case EngineIDs.avFoundation: XCTAssertTrue(r.priority == 110 || r.priority == 40, "\(r)")
            default: XCTFail("\(r)")
            }
        }
    }

    func testRouterPicksTheRightEngine() {
        let router = Router(table: CapabilityTable(AVRoutes.rows))
        XCTAssertEqual(router.route(from: Formats.mov, to: Formats.mp4)?.hops.first?.engine, EngineIDs.avFoundation)
        XCTAssertEqual(router.route(from: Formats.mp4, to: Formats.m4v)?.hops.first?.engine, EngineIDs.avFoundation)
        XCTAssertEqual(router.route(from: Formats.mp4, to: Formats.mkv)?.hops.first?.engine, EngineIDs.ffmpeg)
        XCTAssertEqual(router.route(from: Formats.mp3, to: Formats.m4a)?.hops.first?.engine, EngineIDs.ffmpeg, "AVFoundation M4A is only a fallback")
        XCTAssertEqual(router.route(from: Formats.mp4, to: Formats.caf)?.isDirect, true)
        XCTAssertEqual(router.route(from: Formats.gif, to: Formats.mp4)?.isDirect, true)
        XCTAssertNil(router.route(from: Formats.gif, to: Formats.mp3), "no still → audio chain")
        XCTAssertNil(router.route(from: Formats.gif, to: Formats.avi), "GIF reaches four containers directly, nothing via them")
        XCTAssertEqual(router.optionCount(), 173, "plus 4 subtitle options = 177 for lane E")

        let noFFmpeg = Router(table: CapabilityTable(AVRoutes.rows.filter { $0.engine == EngineIDs.avFoundation }))
        XCTAssertEqual(noFFmpeg.route(from: Formats.mp3, to: Formats.m4a)?.hops.first?.engine, EngineIDs.avFoundation)
    }

    func testEnginesAvailability() throws {
        let locator = try LaneE.requireEngines()
        let ff = FFmpegAVEngine(locator: locator)
        XCTAssertTrue(AVRoutes.rows.filter { $0.engine == EngineIDs.ffmpeg }.allSatisfy(ff.isAvailable))
        XCTAssertFalse(FFmpegAVEngine(locator: EngineLocator(helperDirectories: [])).isAvailable(AVRoutes.rows[0]))
        let avf = AVFoundationEngine()
        XCTAssertTrue(AVRoutes.rows.filter { $0.engine == EngineIDs.avFoundation }.allSatisfy(avf.isAvailable))
        XCTAssertFalse(avf.isAvailable(Capability(Formats.mkv, Formats.mp4, EngineIDs.avFoundation)), "AVFoundation can't read MKV")
        XCTAssertFalse(avf.isAvailable(Capability(Formats.mp4, Formats.webm, EngineIDs.avFoundation)))
        XCTAssertEqual(Set(AVEngines.all.map(\.id)), [EngineIDs.ffmpeg, EngineIDs.avFoundation])
    }

    func testResourceClass() {
        let video = Capability(Formats.mkv, Formats.mp4, EngineIDs.ffmpeg)
        XCTAssertEqual(AVRoutes.resourceClass(for: video, options: StandardSchemas.video.defaults), .videoToolbox)
        XCTAssertEqual(AVRoutes.resourceClass(for: video, options: OptionValues([OptionKey.hardware: .bool(false)])), .cpu)
        XCTAssertEqual(AVRoutes.resourceClass(for: Capability(Formats.wav, Formats.mp3, EngineIDs.ffmpeg), options: .init()), .cpu)
    }

    /// LANE_RULES: every input format we ship has a `sample.<ext>` fixture.
    func testEveryInputFormatHasAFixture() throws {
        let dir = try LaneE.fixtures()
        let inputs = Set(AVRoutes.rows.map(\.from) + SubtitleRoutes.rows.map(\.from)).subtracting([Formats.gif]) // sample.gif is lane D's
        for f in inputs.sorted() {
            let name = "sample.\(Formats.extension(for: f))"
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path), name)
            XCTAssertEqual(Formats.detect(dir.appendingPathComponent(name)), f, name)
        }
    }
}
