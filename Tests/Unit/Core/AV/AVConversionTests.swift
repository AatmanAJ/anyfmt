import XCTest
import ImageIO
@testable import AnyfmtCore

/// Real conversions on tiny generated media (2 s, 320×240): a representative
/// subset of every row family. Each output is probed: duration within ±0.1 s
/// of the source, expected codecs and stream counts.
final class AVConversionTests: XCTestCase {
    private struct Expect {
        var video: String?
        var audio: String?
        var audioStreams: Int?
        var size: (Int, Int)?
        var duration: Double? = 2.0
    }

    @discardableResult
    private func check(_ fixture: String, to: FormatID, options: [String: OptionValue] = [:], engine: any ConversionEngine = FFmpegAVEngine(),
                       _ e: Expect, file: StaticString = #filePath, line: UInt = #line) async throws -> (URL, AVInputFacts) {
        let input = try LaneE.fixture(fixture, file: file, line: line)
        let out = try await LaneE.convert(input, to: to, engine: engine, options: options)
        XCTAssertEqual(out.pathExtension, Formats.extension(for: to), file: file, line: line)
        let f = try await LaneE.probe(out)
        let label = "\(fixture) → \(to)"
        if let d = e.duration {
            XCTAssertEqual(f.duration ?? -1, d, accuracy: 0.1, "duration \(label)", file: file, line: line)
        }
        XCTAssertEqual(f.video?.codec, e.video, "video codec \(label)", file: file, line: line)
        XCTAssertEqual(f.primaryAudio?.codec, e.audio, "audio codec \(label)", file: file, line: line)
        XCTAssertEqual(f.audio.count, e.audioStreams ?? (e.audio == nil ? 0 : 1), "audio streams \(label)", file: file, line: line)
        if let (w, h) = e.size, let v = f.video {
            XCTAssertEqual(v.displayWidth, w, "width \(label)", file: file, line: line)
            XCTAssertEqual(v.displayHeight, h, "height \(label)", file: file, line: line)
        }
        return (out, f)
    }

    // MARK: Audio → audio (every input and every output at least once)

    func testAudioToAudio() async throws {
        try await check("sample.mp3", to: Formats.m4a, Expect(audio: "aac"))
        try await check("sample.m4a", to: Formats.mp3, Expect(audio: "mp3"))
        try await check("sample.wav", to: Formats.flac, Expect(audio: "flac"))
        try await check("sample.flac", to: Formats.wav, Expect(audio: "pcm_s24le")) // bit depth "keep": the 24-bit source stays 24-bit
        try await check("sample.ogg", to: Formats.opus, Expect(audio: "opus"))
        try await check("sample.opus", to: Formats.ogg, Expect(audio: "vorbis"))
        try await check("sample.aiff", to: Formats.caf, Expect(audio: "alac"))
        try await check("sample.caf", to: Formats.aiff, Expect(audio: "pcm_s16be"))
        try await check("sample.wma", to: Formats.mp3, Expect(audio: "mp3"))
        try await check("sample.wma", to: Formats.wav, Expect(audio: "pcm_s16le"))
        try await check("sample.m4a", to: Formats.opus, Expect(audio: "opus"))
        try await check("sample.flac", to: Formats.m4a, Expect(audio: "aac"))
    }

    func testAudioOptionsAreHonoured() async throws {
        let (_, mono) = try await check("sample.wav", to: Formats.mp3,
                                        options: [OptionKey.channels: .string("mono"), OptionKey.bitrate: .string("96"), OptionKey.sampleRate: .string("48000")],
                                        Expect(audio: "mp3"))
        XCTAssertEqual(mono.primaryAudio?.channels, 1)
        XCTAssertEqual(mono.primaryAudio?.sampleRate, 48000)
        XCTAssertEqual(Double(mono.primaryAudio?.bitRate ?? 0), 96_000, accuracy: 4_000)

        for to in [Formats.opus, Formats.m4a, Formats.mp3, Formats.ogg] {
            let (_, f) = try await check("sample.wav", to: to, options: [OptionKey.channels: .string("mono"), OptionKey.bitrate: .string("320")],
                                         Expect(audio: AVCodecTables.canonicalAudioCodec(to)))
            XCTAssertEqual(f.primaryAudio?.channels, 1, "\(to) at the highest bitrate, mono")
        }
        let (_, hi) = try await check("edge-24bit.flac", to: Formats.wav, options: [OptionKey.bitDepth: .string("24")], Expect(audio: "pcm_s24le"))
        XCTAssertEqual(hi.primaryAudio?.sampleRate, 96000)
        try await check("edge-24bit.flac", to: Formats.aiff, Expect(audio: "pcm_s24be")) // default keeps 24-bit
        try await check("edge-24bit.flac", to: Formats.aiff, options: [OptionKey.bitDepth: .string("16")], Expect(audio: "pcm_s16be"))
        let (_, caf24) = try await check("edge-24bit.flac", to: Formats.caf, options: [OptionKey.bitDepth: .string("24")], Expect(audio: "alac"))
        XCTAssertEqual(caf24.primaryAudio?.bitDepth, 24)
        let (_, wav16) = try await check("edge-24bit.flac", to: Formats.wav, options: [OptionKey.bitDepth: .string("16")], Expect(audio: "pcm_s16le"))
        XCTAssertEqual(wav16.primaryAudio?.bitDepth, 16)

        // 96 kHz sources into formats that top out at 48 kHz.
        let (_, mp3) = try await check("edge-24bit.flac", to: Formats.mp3, Expect(audio: "mp3"))
        XCTAssertLessThanOrEqual(mp3.primaryAudio?.sampleRate ?? 0, 48000)
        try await check("edge-24bit.flac", to: Formats.m4a, Expect(audio: "aac"))
        let (_, opus) = try await check("edge-24bit.flac", to: Formats.opus, Expect(audio: "opus"))
        XCTAssertEqual(opus.primaryAudio?.sampleRate, 48000)

        let (_, stereo) = try await check("edge-surround.wav", to: Formats.mp3, Expect(audio: "mp3", duration: 1.0))
        XCTAssertEqual(stereo.primaryAudio?.channels, 2, "5.1 downmixes for MP3")
        let (_, six) = try await check("edge-surround.wav", to: Formats.flac, Expect(audio: "flac", duration: 1.0))
        XCTAssertEqual(six.primaryAudio?.channels, 6)
        let (_, m4a6) = try await check("edge-surround.wav", to: Formats.m4a, Expect(audio: "aac", duration: 1.0))
        XCTAssertEqual(m4a6.primaryAudio?.channels, 6)
    }

    func testCoverArtKeptForMP3M4AFLAC() async throws {
        for to in [Formats.m4a, Formats.flac] {
            let (_, f) = try await check("edge-cover.mp3", to: to, Expect(audio: to == Formats.m4a ? "aac" : "flac"))
            XCTAssertEqual(f.coverArt?.codec, "png", "\(to)")
            XCTAssertNil(f.video)
        }
        let (flac, _) = try await check("edge-cover.mp3", to: Formats.flac, Expect(audio: "flac"))
        let (_, back) = try await check(flac.lastPathComponent, in: flac.deletingLastPathComponent(), to: Formats.mp3)
        XCTAssertEqual(back.coverArt?.codec, "png", "FLAC → MP3 keeps it too")
        let (_, ogg) = try await check("edge-cover.mp3", to: Formats.ogg, Expect(audio: "vorbis"))
        XCTAssertNil(ogg.coverArt)
        let tags = try await LaneE.formatTags(try await LaneE.convert(try LaneE.fixture("edge-cover.mp3"), to: Formats.m4a))
        XCTAssertEqual(tags["title"], "Covered")
        XCTAssertEqual(tags["artist"], "anyfmt")
    }

    private func check(_ name: String, in dir: URL, to: FormatID) async throws -> (URL, AVInputFacts) {
        let out = try await LaneE.convert(dir.appendingPathComponent(name), to: to)
        return (out, try await LaneE.probe(out))
    }

    func testCAFWithAACCopiesIntoM4A() async throws {
        let src = try LaneE.fixture("edge-aac.caf")
        let planned = try await FFmpegAVEngine().plan(for: ConversionRequest(
            inputs: [src], from: Formats.caf, to: Formats.m4a, options: StandardSchemas.audioLossy.defaults,
            outputDirectory: try LaneE.tempDirectory(), baseName: "out", metadata: .keep), locator: LaneE.locator)
        XCTAssertEqual(planned.plan.audio, [.copy])
        try await check("edge-aac.caf", to: Formats.m4a, Expect(audio: "aac"))
    }

    // MARK: Video → video (every input and every output at least once)

    func testVideoToVideo() async throws {
        try await check("sample.mp4", to: Formats.mkv, Expect(video: "h264", audio: "aac", size: (320, 240)))
        try await check("sample.mkv", to: Formats.mp4, Expect(video: "h264", audio: "aac", size: (320, 240)))
        try await check("sample.webm", to: Formats.mp4, Expect(video: "h264", audio: "aac", size: (320, 240)))
        try await check("sample.mov", to: Formats.webm, Expect(video: "vp9", audio: "opus", size: (320, 240)))
        try await check("sample.avi", to: Formats.mov, Expect(video: "h264", audio: "mp3", size: (320, 240)))
        try await check("sample.wmv", to: Formats.mp4, Expect(video: "h264", audio: "aac", size: (320, 240)))
        try await check("sample.mp4", to: Formats.avi, Expect(video: "mpeg4", audio: "mp3", size: (320, 240)))
        try await check("sample.mkv", to: Formats.wmv, Expect(video: "wmv2", audio: "wmav2", size: (320, 240)))
        try await check("sample.m4v", to: Formats.mkv, Expect(video: "h264", audio: "aac"))
        try await check("sample.webm", to: Formats.m4v, Expect(video: "h264", audio: "aac"))
        try await check("sample.wmv", to: Formats.webm, Expect(video: "vp9", audio: "opus"))
        try await check("sample.avi", to: Formats.mkv, Expect(video: "mpeg4", audio: "mp3"))
    }

    func testRemuxKeepsBitstreamAndTagsHEVC() async throws {
        let (out, _) = try await check("edge-hevc.mov", to: Formats.mkv, Expect(video: "hevc", audio: "aac"))
        let (mp4, _) = try await check(out.lastPathComponent, in: out.deletingLastPathComponent(), to: Formats.mp4)
        let json = try await LaneE.probeJSON(mp4)
        let tag = ((json["streams"] as? [[String: Any]])?.first { $0["codec_type"] as? String == "video" })?["codec_tag_string"] as? String
        XCTAssertEqual(tag, "hvc1", "QuickTime needs hvc1")
    }

    func testVideoOptions() async throws {
        let small: [String: OptionValue] = [OptionKey.resolution: .string("120")]
        try await check("sample.mp4", to: Formats.mkv, options: small, Expect(video: "h264", audio: "aac", size: (160, 120)))
        let (_, fps) = try await check("sample.mp4", to: Formats.mkv, options: [OptionKey.fps: .string("15")], Expect(video: "h264", audio: "aac"))
        XCTAssertEqual(fps.video?.frameRate ?? 0, 15, accuracy: 0.5)
        try await check("sample.mp4", to: Formats.mkv, options: [OptionKey.audio: .string("remove")], Expect(video: "h264", audio: nil))
        try await check("sample.mkv", to: Formats.mp4, options: [OptionKey.hardware: .bool(false), OptionKey.videoQuality: .string("small")],
                        Expect(video: "h264", audio: "aac"))
        try await check("sample.webm", to: Formats.mov, options: [OptionKey.videoQuality: .string("high")], Expect(video: "h264", audio: "aac"))
    }

    func testEdgeVideos() async throws {
        try await check("edge-odd.mkv", to: Formats.mp4, Expect(video: "h264", audio: nil, size: (320, 240)))
        try await check("edge-rotated.mp4", to: Formats.webm, Expect(video: "vp9", audio: "opus", size: (240, 320)))
        let (_, copied) = try await check("edge-rotated.mp4", to: Formats.mkv, Expect(video: "h264", audio: "aac", size: (240, 320)))
        XCTAssertEqual(copied.video?.rotation, 90, "a remux keeps the display matrix")
        try await check("edge-noaudio.mp4", to: Formats.webm, Expect(video: "vp9", audio: nil))
        try await check("edge-vfr.mp4", to: Formats.avi, Expect(video: "mpeg4", audio: "mp3"))
        try await check("edge-vfr.mp4", to: Formats.webm, Expect(video: "vp9", audio: "opus"))
    }

    func testSubtitleTracksFollowTheVideo() async throws {
        let (_, mp4) = try await check("edge-subs.mkv", to: Formats.mp4, Expect(video: "h264", audio: "aac"))
        XCTAssertEqual(mp4.subtitles.map(\.codec), ["mov_text"])
        let (_, webm) = try await check("edge-subs.mkv", to: Formats.webm, Expect(video: "vp9", audio: "opus"))
        XCTAssertEqual(webm.subtitles.map(\.codec), ["webvtt"])
        let (_, avi) = try await check("edge-subs.mkv", to: Formats.avi, Expect(video: "mpeg4", audio: "mp3"))
        XCTAssertEqual(avi.subtitles, [])
    }

    // MARK: Video → GIF and GIF → video

    func testVideoToGIF() async throws {
        let (gif, f) = try await check("sample.mp4", to: Formats.gif, Expect(video: "gif", audio: nil, size: (320, 240), duration: nil))
        XCTAssertEqual(f.duration ?? 0, 2.0, accuracy: 0.15)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: gif.deletingLastPathComponent().path)
        XCTAssertEqual(leftovers, ["out.gif"], "palette scratch file removed")
        try await check("sample.webm", to: Formats.gif, options: [OptionKey.gifWidth: .string("160"), OptionKey.fps: .string("10")],
                        Expect(video: "gif", audio: nil, size: (160, 120), duration: nil))
        try await check("edge-rotated.mp4", to: Formats.gif, Expect(video: "gif", audio: nil, size: (240, 320), duration: nil))
    }

    func testGIFOptionsOnARealConversion() async throws {
        let opts: [String: OptionValue] = [OptionKey.gifWidth: .string("160"), OptionKey.fps: .string("10")]
        let expect = Expect(video: "gif", audio: nil, size: (160, 120), duration: nil)
        let (forever, _) = try await check("sample.mp4", to: Formats.gif, options: opts, expect)
        let (once, _) = try await check("sample.mp4", to: Formats.gif, options: opts.merging([OptionKey.gifLoop: .string("once")]) { $1 }, expect)
        let netscape = Data("NETSCAPE2.0".utf8)
        XCTAssertNotNil(try Data(contentsOf: forever).range(of: netscape), "forever writes the loop block")
        XCTAssertNil(try Data(contentsOf: once).range(of: netscape), "play once writes no loop block")

        let (few, _) = try await check("sample.mp4", to: Formats.gif, options: opts.merging([OptionKey.gifColors: .string("32")]) { $1 }, expect)
        XCTAssertLessThanOrEqual(try Self.distinctColours(firstFrameOf: few), 32)
        XCTAssertGreaterThan(try Self.distinctColours(firstFrameOf: forever), 32)
        XCTAssertLessThan(try Data(contentsOf: few).count, try Data(contentsOf: forever).count, "fewer colours, smaller file")

        let (flat, _) = try await check("sample.mp4", to: Formats.gif, options: opts.merging([OptionKey.gifDither: .bool(false)]) { $1 }, expect)
        XCTAssertNotEqual(try Data(contentsOf: flat), try Data(contentsOf: forever), "dither off changes the pixels")
    }

    private static func distinctColours(firstFrameOf url: URL) throws -> Int {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw ConversionError.other("unreadable gif", detail: url.path)
        }
        let w = image.width, h = image.height
        var pixels = [UInt32](repeating: 0, count: w * h)
        let ok = pixels.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        XCTAssertTrue(ok)
        return Set(pixels).count
    }

    func testGIFToVideo() async throws {
        // sample.gif belongs to lane D; make our own from the video fixture.
        let dir = try LaneE.tempDirectory()
        let gif = dir.appendingPathComponent("anim.gif")
        try await LaneE.ffmpeg(["-i", try LaneE.fixture("sample.mp4").path, "-vf", "fps=10,scale=99:-1", "-loop", "0", gif.path])
        for (to, codec) in [(Formats.mp4, "h264"), (Formats.mov, "h264"), (Formats.webm, "vp9"), (Formats.mkv, "h264")] {
            let out = try await LaneE.convert(gif, to: to, from: Formats.gif)
            let f = try await LaneE.probe(out)
            XCTAssertEqual(f.video?.codec, codec, "\(to)")
            XCTAssertEqual(f.video?.width, 98, "even width")
            XCTAssertEqual(f.duration ?? 0, 2.0, accuracy: 0.15, "\(to)")
            XCTAssertTrue(f.audio.isEmpty)
        }
    }

    // MARK: Video → audio extraction

    func testAudioExtraction() async throws {
        try await check("sample.mp4", to: Formats.m4a, Expect(audio: "aac"))
        try await check("sample.mkv", to: Formats.mp3, Expect(audio: "mp3"))
        try await check("sample.webm", to: Formats.opus, Expect(audio: "opus"))
        try await check("sample.avi", to: Formats.mp3, Expect(audio: "mp3"))
        try await check("sample.wmv", to: Formats.wav, Expect(audio: "pcm_s16le"))
        try await check("sample.mov", to: Formats.flac, Expect(audio: "flac"))
        try await check("sample.m4v", to: Formats.caf, Expect(audio: "alac"))
        try await check("sample.webm", to: Formats.ogg, Expect(audio: "vorbis"))
        try await check("sample.mp4", to: Formats.aiff, Expect(audio: "pcm_s16be"))
    }

    func testExtractingFromSilentVideoFailsClearly() async throws {
        do {
            _ = try await LaneE.convert(try LaneE.fixture("edge-noaudio.mp4"), to: Formats.mp3)
            XCTFail("expected an error")
        } catch let e as ConversionError {
            guard case .other(let message, _) = e else { return XCTFail("\(e)") }
            XCTAssertFalse(message.isEmpty)
        }
    }

    func testUnreadableInputIsReported() async throws {
        let dir = try LaneE.tempDirectory()
        let bad = dir.appendingPathComponent("bad.mp4")
        try Data("not a movie".utf8).write(to: bad)
        do {
            _ = try await LaneE.convert(bad, to: Formats.mkv)
            XCTFail("expected an error")
        } catch let e as ConversionError {
            guard case .unreadable = e else { return XCTFail("\(e)") }
        }
    }

    // MARK: Progress

    func testProgressIsLiveMonotonicAndEnds() async throws {
        let sink = ProgressRecorder()
        let input = try await LaneE.makeClip(seconds: 4, size: "640x480")
        let req = ConversionRequest(inputs: [input], from: Formats.mov, to: Formats.webm, options: StandardSchemas.video.defaults,
                                    outputDirectory: try LaneE.tempDirectory(), baseName: "out", metadata: .keep)
        _ = try await FFmpegAVEngine().convert(req, context: EngineContext(progress: ProgressSink { sink.add($0) }, locator: LaneE.locator))
        let values = sink.values
        XCTAssertGreaterThan(values.count, 2)
        XCTAssertEqual(values.last, 1)
        XCTAssertTrue(values.contains { $0 > 0 && $0 < 1 }, "intermediate values arrive while ffmpeg runs: \(values)")
        XCTAssertEqual(values, values.sorted(), "monotonic")
    }
}

/// Thread-safe collector for progress callbacks.
final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Double] = []
    func add(_ v: Double) { lock.withLock { stored.append(v) } }
    var values: [Double] { lock.withLock { stored } }
}
