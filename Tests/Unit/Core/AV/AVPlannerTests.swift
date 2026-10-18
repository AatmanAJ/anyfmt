import XCTest
@testable import HaloCore

/// Codec selection, stream-copy detection, geometry and metadata, with
/// synthetic inputs (no ffmpeg needed).
final class AVPlannerTests: XCTestCase {
    private let input = URL(fileURLWithPath: "/tmp/in.src")
    private let output = URL(fileURLWithPath: "/tmp/out/out.dst")

    private func ctx(_ metadata: MetadataPolicy = .keep) -> AVConversionPlanner.Context {
        .init(input: input, output: output, scratchDirectory: URL(fileURLWithPath: "/tmp/out"), metadata: metadata)
    }

    private func video(_ codec: String = "h264", _ w: Int = 1920, _ h: Int = 1080, rotation: Int = 0, fps: Double = 30,
                       pix: String = "yuv420p", depth: Int = 8) -> AVInputFacts.Video {
        .init(index: 0, codec: codec, width: w, height: h, rotation: rotation, frameRate: fps, nominalFrameRate: fps, pixelFormat: pix, bitDepth: depth)
    }

    private func facts(_ v: AVInputFacts.Video? = nil, audio: [AVInputFacts.Audio] = [],
                       subs: [AVInputFacts.Stream] = [], cover: AVInputFacts.Stream? = nil,
                       tags: [String: String] = [:], streamTags: [Int: [String: String]] = [:]) -> AVInputFacts {
        AVInputFacts(duration: 10, video: v, audio: audio, subtitles: subs, coverArt: cover, formatTags: tags, streamTags: streamTags)
    }

    private func aac(_ index: Int = 1, br: Int? = 128_000, ch: Int = 2) -> AVInputFacts.Audio {
        .init(index: index, codec: "aac", sampleRate: 44100, channels: ch, bitRate: br, isDefault: true)
    }

    private func plan(_ f: AVInputFacts, _ from: FormatID, _ to: FormatID, _ opts: [String: OptionValue] = [:],
                      metadata: MetadataPolicy = .keep) throws -> AVConversionPlan {
        let schema = AVRoutes.rows.first { $0.from == from && $0.to == to }?.schema ?? .none
        return try AVConversionPlanner.plan(f, from: from, to: to, options: schema.defaults.merging(OptionValues(opts)), context: ctx(metadata))
    }

    private func args(_ p: AVConversionPlan, pass: Int = 0) -> String { p.passes[pass].arguments.joined(separator: " ") }

    // MARK: Stream copy

    func testRemuxCopiesLegalStreams() throws {
        let p = try plan(facts(video(), audio: [aac()]), Formats.mp4, Formats.mkv)
        XCTAssertEqual(p.video, .copy)
        XCTAssertEqual(p.audio, [.copy])
        XCTAssertTrue(p.isStreamCopy)
        XCTAssertTrue(args(p).contains("-c:v copy"))
        XCTAssertTrue(p.fallback.isEmpty, "nothing hardware-specific, no fallback")
    }

    func testMKVToMP4CopiesVideoReencodesOpus() throws {
        let opus = AVInputFacts.Audio(index: 1, codec: "opus", sampleRate: 48000, channels: 2)
        let p = try plan(facts(video(), audio: [opus]), Formats.mkv, Formats.mp4)
        XCTAssertEqual(p.video, .copy)
        XCTAssertEqual(p.audio, [.encode("aac_at")])
        XCTAssertTrue(args(p).contains("-c:a:0 aac_at -b:a:0 192k"))
        XCTAssertTrue(args(p).contains("-movflags +faststart"))
        XCTAssertEqual(p.fallback.first?.audio, [.encode("aac")], "AudioToolbox fallback is ffmpeg's aac")
    }

    func testHEVCCopyIntoQuickTimeGetsHvc1Tag() throws {
        let p = try plan(facts(video("hevc"), audio: [aac()]), Formats.mkv, Formats.mp4)
        XCTAssertEqual(p.video, .copy)
        XCTAssertTrue(args(p).contains("-c:v copy -tag:v hvc1"))
    }

    func testQualityOptionsAndCopy() throws {
        let f = facts(video(), audio: [aac()])
        XCTAssertEqual(try plan(f, Formats.mp4, Formats.mkv, [OptionKey.videoQuality: .string("high")]).video, .copy, "copy is the highest quality")
        XCTAssertEqual(try plan(f, Formats.mp4, Formats.mkv, [OptionKey.videoQuality: .string("small")]).video, .encode("h264_videotoolbox"))
    }

    func testResizeFpsAndCodecForceEncode() throws {
        let f = facts(video(), audio: [aac()])
        let resized = try plan(f, Formats.mp4, Formats.mkv, [OptionKey.resolution: .string("720")])
        XCTAssertEqual(resized.video, .encode("h264_videotoolbox"))
        XCTAssertTrue(args(resized).contains("-vf scale=1280:720,format=yuv420p"))
        XCTAssertEqual(resized.audio, [.copy], "audio is copied even when video re-encodes")

        let fps = try plan(f, Formats.mp4, Formats.mkv, [OptionKey.fps: .string("24")])
        XCTAssertTrue(args(fps).contains("-vf fps=24,format=yuv420p"))

        XCTAssertEqual(try plan(f, Formats.mp4, Formats.mkv, [OptionKey.fps: .string("60")]).video, .copy, "never raises the frame rate")
        XCTAssertEqual(try plan(f, Formats.mp4, Formats.mkv, [OptionKey.resolution: .string("2160")]).video, .copy, "never upscales")
        XCTAssertEqual(try plan(f, Formats.mp4, Formats.mkv, [OptionKey.resolution: .string("1080")]).video, .copy, "already 1080p")

        let hevc = try plan(f, Formats.mp4, Formats.mkv, [OptionKey.videoCodec: .string("hevc")])
        XCTAssertEqual(hevc.video, .encode("hevc_videotoolbox"))
        XCTAssertFalse(args(hevc).contains("hvc1"), "hvc1 tag only for QuickTime containers")
    }

    // MARK: Codec per container

    func testDefaultEncodersPerContainer() throws {
        let vp9 = facts(video("vp9"), audio: [AVInputFacts.Audio(index: 1, codec: "opus", sampleRate: 48000)])
        XCTAssertEqual(try plan(vp9, Formats.webm, Formats.mp4).video, .encode("h264_videotoolbox"))
        XCTAssertEqual(try plan(vp9, Formats.webm, Formats.mov).video, .encode("h264_videotoolbox"))
        XCTAssertEqual(try plan(vp9, Formats.webm, Formats.m4v).video, .encode("h264_videotoolbox"))
        XCTAssertEqual(try plan(vp9, Formats.webm, Formats.mkv).video, .copy)

        let h264 = facts(video(), audio: [aac()])
        let webm = try plan(h264, Formats.mp4, Formats.webm)
        XCTAssertEqual(webm.video, .encode("libvpx-vp9"))
        XCTAssertEqual(webm.audio, [.encode("libopus")])
        XCTAssertTrue(args(webm).contains("-crf 32 -b:v 0 -deadline good -cpu-used 4 -row-mt 1"))
        XCTAssertTrue(args(webm).contains("-ar:a:0 48000"))

        let avi = try plan(h264, Formats.mp4, Formats.avi)
        XCTAssertEqual(avi.video, .encode("mpeg4"))
        XCTAssertEqual(avi.audio, [.encode("libmp3lame")])
        XCTAssertTrue(args(avi).contains("-q:v 4 -tag:v XVID"))

        let wmv = try plan(h264, Formats.mp4, Formats.wmv)
        XCTAssertEqual(wmv.video, .encode("wmv2"))
        XCTAssertEqual(wmv.audio, [.encode("wmav2")])
        XCTAssertTrue(args(wmv).hasSuffix("-f asf /tmp/out/out.dst"))
    }

    func testMovKeepsHEVCAndProResWhenReencoding() throws {
        let opts: [String: OptionValue] = [OptionKey.resolution: .string("720")]
        XCTAssertEqual(try plan(facts(video("hevc"), audio: [aac()]), Formats.mp4, Formats.mov, opts).video, .encode("hevc_videotoolbox"))
        XCTAssertEqual(try plan(facts(video("hevc"), audio: [aac()]), Formats.mkv, Formats.mp4, opts).video, .encode("h264_videotoolbox"),
                       "mp4 re-encodes to H.264 for compatibility")
        let prores = try plan(facts(video("prores", pix: "yuv422p10le", depth: 10)), Formats.mkv, Formats.mov, opts)
        XCTAssertEqual(prores.video, .encode("prores_videotoolbox"))
        XCTAssertTrue(args(prores).contains("-profile:v standard"))
        XCTAssertEqual(prores.fallback.first?.video, .encode("prores_ks"))
        XCTAssertEqual(try plan(facts(video("prores")), Formats.mov, Formats.mp4).video, .encode("h264_videotoolbox"), "ProRes isn't legal in mp4")
        XCTAssertEqual(try plan(facts(video("prores")), Formats.mov, Formats.mkv).video, .copy)
    }

    func testTenBitHEVCStaysTenBit() throws {
        let p = try plan(facts(video("hevc", pix: "yuv420p10le", depth: 10)), Formats.mkv, Formats.mov, [OptionKey.resolution: .string("720")])
        XCTAssertTrue(args(p).contains("format=p010le"))
        XCTAssertTrue(args(p).contains("-profile:v main10 -tag:v hvc1"))
        XCTAssertTrue(args(p.fallback[0]).contains("libx265"))
        XCTAssertTrue(args(p.fallback[0]).contains("format=yuv420p10le"))
    }

    func testHardwareToggleAndPresetValues() throws {
        let f = facts(video("vp9"))
        for (preset, q, crf) in [("high", 75, 18), ("balanced", 58, 23), ("small", 45, 28)] {
            let hw = try plan(f, Formats.webm, Formats.mp4, [OptionKey.videoQuality: .string(preset)])
            XCTAssertTrue(args(hw).contains("-c:v h264_videotoolbox -q:v \(q) -profile:v high"), preset)
            XCTAssertTrue(hw.usesVideoToolbox)
            XCTAssertTrue(args(hw.fallback[0]).contains("-c:v libx264 -preset medium -crf \(crf)"), preset)
            let sw = try plan(f, Formats.webm, Formats.mp4, [OptionKey.videoQuality: .string(preset), OptionKey.hardware: .bool(false)])
            XCTAssertTrue(args(sw).contains("-crf \(crf)"))
            XCTAssertFalse(sw.usesVideoToolbox)
            XCTAssertTrue(sw.fallback.isEmpty)
        }
    }

    func testExplicitCodecOnlyWhenLegal() throws {
        let f = facts(video("vp9"))
        XCTAssertEqual(try plan(f, Formats.webm, Formats.mp4, [OptionKey.videoCodec: .string("hevc")]).video, .encode("hevc_videotoolbox"))
        XCTAssertEqual(try plan(f, Formats.webm, Formats.mp4, [OptionKey.videoCodec: .string("vp9")]).video, .encode("h264_videotoolbox"))
        XCTAssertEqual(try plan(f, Formats.webm, Formats.mkv, [OptionKey.videoCodec: .string("av1")]).video, .encode("libaom-av1"))
    }

    // MARK: Geometry

    func testTargetSizes() {
        typealias P = AVConversionPlanner
        XCTAssertTrue(P.targetSize(width: 1920, height: 1080, maxShortEdge: 720) == (1280, 720))
        XCTAssertTrue(P.targetSize(width: 1080, height: 1920, maxShortEdge: 720) == (720, 1280), "portrait: short edge")
        XCTAssertTrue(P.targetSize(width: 3840, height: 2160, maxShortEdge: 480) == (854, 480))
        XCTAssertTrue(P.targetSize(width: 321, height: 241, maxShortEdge: nil) == (320, 240), "odd → even")
        XCTAssertTrue(P.targetSize(width: 640, height: 360, maxShortEdge: 1080) == (640, 360), "never upscales")
        XCTAssertTrue(P.targetSize(width: 1, height: 1, maxShortEdge: nil) == (2, 2))
    }

    func testRotationUsesDisplaySize() throws {
        let p = try plan(facts(video(rotation: 90)), Formats.mp4, Formats.webm, [OptionKey.resolution: .string("720")])
        XCTAssertTrue(args(p).contains("scale=720:1280"), args(p))
        XCTAssertEqual(try plan(facts(video(rotation: 90)), Formats.mp4, Formats.mkv).video, .copy, "rotation survives a copy")
    }

    func testOddDimensionsScaleToEvenOnEncode() throws {
        let p = try plan(facts(video("ffv1", 321, 241)), Formats.mkv, Formats.mp4)
        XCTAssertTrue(args(p).contains("-vf scale=320:240,format=yuv420p"))
    }

    // MARK: Streams

    func testRemoveAudioAndMultipleTracks() throws {
        let two = facts(video(), audio: [aac(1), AVInputFacts.Audio(index: 2, codec: "flac", sampleRate: 48000, channels: 6)])
        let p = try plan(two, Formats.mkv, Formats.mp4)
        XCTAssertEqual(p.audio, [.copy, .encode("aac_at")])
        XCTAssertTrue(args(p).contains("-map 0:1 -c:a:0 copy -map 0:2 -c:a:1 aac_at -b:a:1 384k"))
        let silent = try plan(two, Formats.mkv, Formats.mp4, [OptionKey.audio: .string("remove")])
        XCTAssertEqual(silent.audio, [])
        XCTAssertFalse(args(silent).contains("0:1"))
    }

    func testSubtitleMapping() throws {
        let f = facts(video(), audio: [aac()], subs: [.init(index: 2, codec: "subrip"), .init(index: 3, codec: "hdmv_pgs_subtitle")])
        XCTAssertEqual(try plan(f, Formats.mkv, Formats.mp4).subtitles, [.encode("mov_text")])
        XCTAssertEqual(try plan(f, Formats.mkv, Formats.webm).subtitles, [.encode("webvtt")])
        XCTAssertEqual(try plan(f, Formats.mp4, Formats.mkv).subtitles, [.copy, .copy])
        XCTAssertEqual(try plan(f, Formats.mkv, Formats.avi).subtitles, [])
        XCTAssertEqual(try plan(facts(video(), subs: [.init(index: 1, codec: "mov_text")]), Formats.mp4, Formats.mkv).subtitles, [.encode("srt")])
    }

    func testNoAudioSourceToVideoIsFine() throws {
        let p = try plan(facts(video()), Formats.mp4, Formats.webm)
        XCTAssertEqual(p.audio, [])
    }

    // MARK: Audio targets

    func testAudioEncodersAndOptions() throws {
        let mp3 = AVInputFacts.Audio(index: 0, codec: "mp3", sampleRate: 44100, channels: 2, bitRate: 128_000)
        let m4a = try plan(facts(audio: [mp3]), Formats.mp3, Formats.m4a, [OptionKey.bitrate: .string("192")])
        XCTAssertTrue(args(m4a).contains("-c:a aac_at -b:a 192k"))
        XCTAssertTrue(args(m4a).contains("-vn"))
        XCTAssertTrue(args(m4a).hasSuffix("-f ipod /tmp/out/out.dst"))
        XCTAssertTrue(args(m4a.fallback[0]).contains("-c:a aac -b:a 192k"))

        let ogg = try plan(facts(audio: [mp3]), Formats.mp3, Formats.ogg, [OptionKey.bitrate: .string("128")])
        XCTAssertTrue(args(ogg).contains("-c:a libvorbis -q:a 4"))
        let opus = try plan(facts(audio: [mp3]), Formats.mp3, Formats.opus, [OptionKey.sampleRate: .string("44100")])
        XCTAssertTrue(args(opus).contains("-c:a libopus -b:a 256k -vbr on -ar 48000"), "Opus is always 48 kHz")
        let monoOpus = try plan(facts(audio: [mp3]), Formats.mp3, Formats.opus, [OptionKey.bitrate: .string("320"), OptionKey.channels: .string("mono")])
        XCTAssertTrue(args(monoOpus).contains("-b:a 256k"), "libopus caps at 256 kbps per channel")
        let mono = try plan(facts(audio: [mp3]), Formats.mp3, Formats.flac, [OptionKey.channels: .string("mono"), OptionKey.sampleRate: .string("48000")])
        XCTAssertTrue(args(mono).contains("-ar 48000 -ac 1"))
        let lame = try plan(facts(audio: [aac()]), Formats.m4a, Formats.mp3)
        XCTAssertTrue(args(lame).contains("-c:a libmp3lame -b:a 256k"))
        XCTAssertTrue(args(lame).contains("-id3v2_version 3"))
    }

    func testSurroundToMP3Downmixes() throws {
        let surround = AVInputFacts.Audio(index: 0, codec: "pcm_s16le", sampleRate: 48000, channels: 6, bitDepth: 16)
        XCTAssertTrue(args(try plan(facts(audio: [surround]), Formats.wav, Formats.mp3)).contains("-ac 2"))
        XCTAssertFalse(args(try plan(facts(audio: [surround]), Formats.wav, Formats.flac)).contains("-ac"))
    }

    func testBitDepthAndDither() throws {
        let hi = AVInputFacts.Audio(index: 0, codec: "flac", sampleRate: 96000, channels: 2, bitDepth: 24)
        let wav16 = try plan(facts(audio: [hi]), Formats.flac, Formats.wav, [OptionKey.bitDepth: .string("16")])
        XCTAssertTrue(args(wav16).contains("-c:a pcm_s16le -af aresample=dither_method=triangular"), "24 → 16 is dithered")
        let kept = try plan(facts(audio: [hi]), Formats.flac, Formats.wav)
        XCTAssertTrue(args(kept).contains("-c:a pcm_s24le"), "the default keeps the source bit depth")
        let wav24 = try plan(facts(audio: [hi]), Formats.flac, Formats.wav, [OptionKey.bitDepth: .string("24")])
        XCTAssertTrue(args(wav24).contains("-c:a pcm_s24le"))
        XCTAssertFalse(args(wav24).contains("dither"))
        let keep = try plan(facts(audio: [hi]), Formats.flac, Formats.aiff, [OptionKey.bitDepth: .string("keep")])
        XCTAssertTrue(args(keep).contains("-c:a pcm_s24be"), "proposed 'keep' value preserves 24-bit")
        let caf = try plan(facts(audio: [hi]), Formats.flac, Formats.caf, [OptionKey.bitDepth: .string("24")])
        XCTAssertTrue(args(caf).contains("-c:a alac -sample_fmt s32p -bits_per_raw_sample 24"))
        let flac16 = AVInputFacts.Audio(index: 0, codec: "pcm_s16le", sampleRate: 44100, channels: 2, bitDepth: 16)
        let f16 = try plan(facts(audio: [flac16]), Formats.wav, Formats.flac)
        XCTAssertTrue(args(f16).contains("-c:a flac -compression_level 5 -sample_fmt s16"))
        XCTAssertFalse(args(f16).contains("dither"), "16 → 16 needs no dither")
    }

    func testAudioStreamCopyRules() throws {
        let movie = facts(video(), audio: [aac(br: 128_000)])
        XCTAssertEqual(try plan(movie, Formats.mp4, Formats.m4a).audio, [.copy], "AAC → M4A extraction is a copy")
        XCTAssertEqual(try plan(facts(video(), audio: [aac(br: 320_000)]), Formats.mp4, Formats.m4a).audio, [.encode("aac_at")],
                       "a 320 kbps source is shrunk to the requested 256")
        XCTAssertEqual(try plan(movie, Formats.mp4, Formats.m4a, [OptionKey.channels: .string("mono")]).audio, [.encode("aac_at")])
        let opus = AVInputFacts.Audio(index: 1, codec: "opus", sampleRate: 48000, channels: 2, bitRate: nil)
        XCTAssertEqual(try plan(facts(video("vp9"), audio: [opus]), Formats.webm, Formats.opus).audio, [.copy])
        XCTAssertEqual(try plan(facts(video("vp9"), audio: [opus]), Formats.webm, Formats.ogg).audio, [.encode("libvorbis")], ".ogg means Vorbis")
        let flac = AVInputFacts.Audio(index: 1, codec: "flac", sampleRate: 48000, channels: 2, bitDepth: 16)
        XCTAssertEqual(try plan(facts(video(), audio: [flac]), Formats.mkv, Formats.flac).audio, [.copy])
        XCTAssertEqual(try plan(facts(video(), audio: [flac]), Formats.mkv, Formats.flac, [OptionKey.bitDepth: .string("24")]).audio, [.encode("flac")])
        let pcm = AVInputFacts.Audio(index: 1, codec: "pcm_s16le", sampleRate: 48000, channels: 2, bitDepth: 16)
        XCTAssertEqual(try plan(facts(video(), audio: [pcm]), Formats.mov, Formats.wav).audio, [.copy])
        XCTAssertEqual(try plan(facts(video(), audio: [pcm]), Formats.mov, Formats.aiff).audio, [.encode("pcm_s16be")])
    }

    func testCoverArtTravelsOnlyWhereItFits() throws {
        let f = facts(audio: [AVInputFacts.Audio(index: 0, codec: "mp3", sampleRate: 44100, channels: 2, bitRate: 128_000)],
                      cover: .init(index: 1, codec: "png"))
        for to in [Formats.m4a, Formats.flac] {
            let p = try plan(f, Formats.mp3, to)
            XCTAssertEqual(p.coverArt, .copy, "\(to)")
            XCTAssertTrue(args(p).contains("-map 0:1 -c:v copy -disposition:v:0 attached_pic"))
        }
        XCTAssertNil(try plan(f, Formats.mp3, Formats.ogg).coverArt)
        XCTAssertNil(try plan(f, Formats.mp3, Formats.m4a, metadata: .stripAll).coverArt)
        let bmp = facts(audio: f.audio, cover: .init(index: 1, codec: "bmp"))
        XCTAssertEqual(try plan(bmp, Formats.flac, Formats.mp3).coverArt, .encode("png"))
    }

    func testNoAudioToExtractThrows() {
        XCTAssertThrowsError(try plan(facts(video()), Formats.mp4, Formats.mp3)) { error in
            guard case ConversionError.other = error else { return XCTFail("\(error)") }
        }
    }

    // MARK: GIF

    func testGIFPlanIsTwoPassWithPalette() throws {
        let p = try plan(facts(video("h264", 1920, 1080, fps: 30)), Formats.mp4, Formats.gif)
        XCTAssertEqual(p.passes.count, 2)
        XCTAssertEqual(p.passes.map(\.weight).reduce(0, +), 1, accuracy: 1e-9)
        XCTAssertEqual(p.scratch.count, 1)
        let palette = p.scratch[0].path
        XCTAssertTrue(args(p, pass: 0).contains("fps=15,scale=640:-1:flags=lanczos,palettegen=stats_mode=diff"))
        XCTAssertTrue(args(p, pass: 0).hasSuffix(palette))
        XCTAssertTrue(args(p, pass: 1).contains("-i \(palette)"))
        XCTAssertTrue(args(p, pass: 1).contains("paletteuse=dither=sierra2_4a:diff_mode=rectangle"))
        XCTAssertTrue(args(p, pass: 1).contains("-loop 0 -f gif"))

        let small = try plan(facts(video("h264", 320, 240, fps: 10)), Formats.mp4, Formats.gif, [OptionKey.gifWidth: .string("960"), OptionKey.fps: .string("24")])
        XCTAssertTrue(args(small, pass: 0).contains("fps=10,scale=320:-1"), "never upscales or raises fps")
        let keep = try plan(facts(video("h264", 1280, 720, rotation: 90)), Formats.mp4, Formats.gif, [OptionKey.gifWidth: .string("0")])
        XCTAssertTrue(args(keep, pass: 0).contains("scale=720:-1"), "keep = display width")
    }

    func testGIFOptionsChangeTheArguments() throws {
        let f = facts(video("h264", 640, 480, fps: 30))
        let base = try plan(f, Formats.mp4, Formats.gif)
        XCTAssertTrue(args(base, pass: 0).contains("palettegen=stats_mode=diff:max_colors=256"))
        XCTAssertTrue(args(base, pass: 1).contains("paletteuse=dither=sierra2_4a:"))
        XCTAssertTrue(args(base, pass: 1).contains("-loop 0 -f gif"), "forever by default")

        let once = try plan(f, Formats.mp4, Formats.gif, [OptionKey.gifLoop: .string("once")])
        XCTAssertTrue(args(once, pass: 1).contains("-loop -1 -f gif"), "-1 = play once in ffmpeg's GIF muxer")
        XCTAssertEqual(args(once, pass: 0).replacingOccurrences(of: #"\.palette-[^ ]+"#, with: "", options: .regularExpression),
                       args(base, pass: 0).replacingOccurrences(of: #"\.palette-[^ ]+"#, with: "", options: .regularExpression),
                       "loop only touches the muxer")

        for n in ["128", "64", "32"] {
            let p = try plan(f, Formats.mp4, Formats.gif, [OptionKey.gifColors: .string(n)])
            XCTAssertTrue(args(p, pass: 0).contains("palettegen=stats_mode=diff:max_colors=\(n)"), n)
        }
        let flat = try plan(f, Formats.mp4, Formats.gif, [OptionKey.gifDither: .bool(false)])
        XCTAssertTrue(args(flat, pass: 1).contains("paletteuse=dither=none:diff_mode=rectangle"))
        XCTAssertFalse(args(flat, pass: 1).contains("sierra2_4a"))

        let silly = try plan(f, Formats.mp4, Formats.gif, [OptionKey.gifColors: .string("1")])
        XCTAssertTrue(args(silly, pass: 0).contains("max_colors=4"), "clamped to palettegen's minimum")
    }

    func testGIFInputToVideoEncodes() throws {
        let gif = facts(video("gif", 99, 75, fps: 10, pix: "bgra"))
        let mp4 = try plan(gif, Formats.gif, Formats.mp4)
        XCTAssertEqual(mp4.video, .encode("h264_videotoolbox"))
        XCTAssertTrue(args(mp4).contains("scale=98:74,format=yuv420p"))
        XCTAssertEqual(try plan(gif, Formats.gif, Formats.webm).video, .encode("libvpx-vp9"))
    }

    // MARK: Metadata

    func testMetadataPolicies() throws {
        let tags = ["title": "Trip", "location": "+37.3-122.0/", "location-eng": "+37.3-122.0/",
                    "com.apple.quicktime.location.ISO6709": "+37.3-122.0+010/", "com.apple.quicktime.make": "Apple",
                    "com.apple.quicktime.model": "iPhone", "com.apple.quicktime.creationdate": "2024-05-01T12:00:00+0200",
                    "major_brand": "qt  ", "creation_time": "2024-05-01T10:00:00Z"]
        let f = facts(video(), audio: [aac()], tags: tags, streamTags: [0: ["handler_name": "Core Media Video", "location": "x"]])

        let keep = try plan(f, Formats.mkv, Formats.mp4).passes[0].arguments
        let keepText = keep.joined(separator: " ")
        XCTAssertTrue(keepText.contains("-map_metadata 0"))
        XCTAssertTrue(keepText.contains("-metadata major_brand="), "pseudo-tags are never written back")
        XCTAssertTrue(keep.contains("make=Apple") && keep.contains("model=iPhone"), "Apple keys become standard tags")
        XCTAssertTrue(keep.contains("date=2024-05-01T12:00:00+0200"))
        XCTAssertTrue(keep.contains("creation_time=2024-05-01T10:00:00Z"), "capture time in UTC")
        XCTAssertFalse(keep.contains("title=Trip"), "an existing standard tag wins")
        XCTAssertFalse(keepText.contains("location="), "standard location already present")
        XCTAssertFalse(keepText.contains("use_metadata_tags"), "AVFoundation can't read ffmpeg's mdta output")
        XCTAssertTrue(keepText.contains("-movflags +faststart"))

        let priv = try plan(f, Formats.mkv, Formats.mp4, metadata: .stripPrivate).passes[0].arguments
        let privText = priv.joined(separator: " ")
        for k in ["location", "location-eng", "com.apple.quicktime.location.ISO6709", "com.apple.quicktime.make", "com.apple.quicktime.model"] {
            XCTAssertTrue(priv.contains("\(k)="), k)
        }
        XCTAssertTrue(privText.contains("-metadata:s:v:0 location="), "stream-level tags too")
        XCTAssertFalse(priv.contains("make=Apple"), "private keys are not translated")
        XCTAssertTrue(priv.contains("creation_time=2024-05-01T10:00:00Z"), "dates aren't private")
        XCTAssertFalse(privText.contains("title="))

        let all = args(try plan(f, Formats.mkv, Formats.mp4, metadata: .stripAll))
        XCTAssertTrue(all.contains("-map_metadata -1 -map_chapters -1 -fflags +bitexact"))
        XCTAssertFalse(all.contains("make="))
    }

    func testAppleTagTranslation() {
        let tags = ["com.apple.quicktime.title": "T", "com.apple.quicktime.creationdate": "2024-12-31T23:30:00-0100",
                    "com.apple.quicktime.location.ISO6709": "+1+2/", "com.apple.quicktime.make": "Apple"]
        let keep = Dictionary(uniqueKeysWithValues: AVConversionPlanner.appleTagTranslations(tags, includePrivate: true))
        XCTAssertEqual(keep, ["title": "T", "date": "2024-12-31T23:30:00-0100", "creation_time": "2025-01-01T00:30:00Z",
                              "location": "+1+2/", "make": "Apple"])
        let priv = Dictionary(uniqueKeysWithValues: AVConversionPlanner.appleTagTranslations(tags, includePrivate: false))
        XCTAssertEqual(Set(priv.keys), ["title", "date", "creation_time"])
        XCTAssertEqual(AVConversionPlanner.utcTimestamp("2024-05-01T10:00:00.250Z"), "2024-05-01T10:00:00Z")
        XCTAssertEqual(AVConversionPlanner.utcTimestamp("2024-05-01T10:00:00+02:00"), "2024-05-01T08:00:00Z")
        XCTAssertNil(AVConversionPlanner.utcTimestamp("May 1st"))
    }

    func testPrivateTagPredicate() {
        for k in ["location", "location-eng", "LOCATION", "com.apple.quicktime.location.ISO6709", "make", "model", "software",
                  "com.apple.quicktime.make", "com.apple.quicktime.software", "com.android.version", "author", "gps_info", "©xyz"] {
            XCTAssertTrue(AVConversionPlanner.isPrivateTag(k), k)
        }
        for k in ["title", "artist", "album", "date", "creation_time", "comment", "encoder", "handler_name", "language", "copyright"] {
            XCTAssertFalse(AVConversionPlanner.isPrivateTag(k), k)
        }
    }

    // MARK: Options and errors

    func testOptionParsingFromSchemaStrings() {
        let v = AVVideoOptions(StandardSchemas.video.defaults)
        XCTAssertEqual(v.quality, .balanced)
        XCTAssertNil(v.maxShortEdge)
        XCTAssertNil(v.fps)
        XCTAssertTrue(v.hardware)
        XCTAssertFalse(v.removeAudio)
        XCTAssertNil(v.codec)
        let a = AVAudioOptions(StandardSchemas.audioLossy.defaults)
        XCTAssertEqual(a.bitrate, 256)
        XCTAssertNil(a.sampleRate)
        XCTAssertNil(a.channels)
        XCTAssertNil(AVAudioOptions(StandardSchemas.audioLossless.defaults).bitDepth, "lossless default keeps the source depth")
        XCTAssertNil(AVAudioOptions(OptionValues([OptionKey.bitDepth: .string("keep")])).bitDepth)
        XCTAssertEqual(AVQualityPreset(option: "nonsense"), .balanced)
    }

    func testVorbisQualityMapping() {
        XCTAssertEqual([96, 128, 192, 256, 320].map(AVDefaultAudio.vorbisQuality(kbps:)), [2, 4, 6, 8, 9])
    }

    func testEncoderStartupFailureDetection() {
        XCTAssertTrue(FFmpegAVEngine.isEncoderStartupFailure(.engineFailed("ffmpeg", status: 1, detail: "[h264_videotoolbox] Error: cannot create compression session")))
        XCTAssertTrue(FFmpegAVEngine.isEncoderStartupFailure(.engineFailed("ffmpeg", status: 1, detail: "Error while opening encoder for output stream")))
        XCTAssertFalse(FFmpegAVEngine.isEncoderStartupFailure(.engineFailed("ffmpeg", status: 1, detail: "Invalid data found when processing input")))
        XCTAssertFalse(FFmpegAVEngine.isEncoderStartupFailure(.cancelled))
    }

    func testUnsupportedTargetThrows() {
        XCTAssertThrowsError(try plan(facts(video()), Formats.mp4, Formats.png))
    }
}
