import XCTest
@testable import HaloCore

/// Pure logic: option parsing, cut planning, encoder choice. No engines needed.
final class MediaPlanningTests: XCTestCase {
    func testTimeParsing() {
        XCTAssertEqual(MediaTimes.seconds("12.5"), 12.5)
        XCTAssertEqual(MediaTimes.seconds("1:02.25"), 62.25)
        XCTAssertEqual(MediaTimes.seconds("1:00:03"), 3603)
        XCTAssertNil(MediaTimes.seconds("abc"))
        XCTAssertNil(MediaTimes.seconds("-1"))
        XCTAssertEqual(MediaTimes.range("1.5-9.25"), 1.5...9.25)
        XCTAssertEqual(MediaTimes.range("0:01-0:02.5"), 1...2.5)
        XCTAssertNil(MediaTimes.range("5-2"))
        XCTAssertNil(MediaTimes.range(""))
        XCTAssertEqual(MediaTimes.ranges("3-4; 1-2;1.5-2.5"), [1...2.5, 3...4])
        XCTAssertEqual(MediaTimes.list("3, 1.5,3"), [1.5, 3])
        XCTAssertEqual(MediaTimes.format(1.5...9.25), "1.5-9.25")
        XCTAssertEqual(MediaTimes.format(2.0), "2")
        XCTAssertEqual(MediaTimes.timecode(62.256), "1:02.26")
        XCTAssertEqual(MediaTimes.timecode(3723.5, fraction: 1), "1:02:03.5")
    }

    private let keys = KeyframeIndex(keyframes: [0, 1, 2, 3], packets: (0..<120).map { Double($0) / 30 })

    func testTrimPlanSnapsToEnclosingKeyframes() {
        let p = TrimPlanner.cut(requested: 1.2...2.6, duration: 4, frameDuration: 1.0 / 30, keyframes: keys, lossless: true)
        XCTAssertEqual(p, .copy(start: 1, end: 3, toEnd: false))
        let exact = TrimPlanner.cut(requested: 1...3, duration: 4, frameDuration: 1.0 / 30, keyframes: keys, lossless: true)
        XCTAssertEqual(exact, .copy(start: 1, end: 3, toEnd: false))
        let toEnd = TrimPlanner.cut(requested: 2.0...3.9, duration: 4, frameDuration: 1.0 / 30, keyframes: keys, lossless: true)
        XCTAssertEqual(toEnd, .copy(start: 2, end: 4, toEnd: true))
    }

    func testTrimPlanUsesTheNearSideWhenTheEnclosingKeyframeIsFar() {
        // 2 s GOP offset by 0.37 s, as hardware encoders often produce.
        let k = KeyframeIndex(keyframes: [0, 2.37, 4.37, 6.37, 8.37, 10.37], packets: [])
        let fd = 1.0 / 30
        let p = TrimPlanner.cut(requested: 4.2...7.9, duration: 12, frameDuration: fd, keyframes: k, lossless: true)
        XCTAssertEqual(p, .copy(start: 4.37, end: 8.37, toEnd: false), "0.17 s late beats 1.83 s early")
        let q = TrimPlanner.cut(requested: 3...9.9, duration: 12, frameDuration: fd, keyframes: k, lossless: true)
        XCTAssertEqual(q, .copy(start: 2.37, end: 10.37, toEnd: false))
        let r = TrimPlanner.cut(requested: 3...7.0, duration: 12, frameDuration: fd, keyframes: k, lossless: true)
        XCTAssertEqual(r, .copy(start: 2.37, end: 6.37, toEnd: false), "out falls back to the keyframe before it")
    }

    func testTrimPlanFallsBackWhenKeyframesAreFar() {
        let sparse = KeyframeIndex(keyframes: [0], packets: [])
        let p = TrimPlanner.cut(requested: 2.5...3, duration: 10, frameDuration: 1.0 / 30, keyframes: sparse, lossless: true)
        XCTAssertFalse(p.isLossless)
        XCTAssertEqual(p.start, 2.5, accuracy: 1.0 / 60)
        let off = TrimPlanner.cut(requested: 1...3, duration: 4, frameDuration: 1.0 / 30, keyframes: keys, lossless: false)
        XCTAssertEqual(off, .reencode(start: 1, end: 3, reason: .losslessOff))
    }

    func testSplitPlan() {
        let fd = 1.0 / 30
        let cuts = SplitPlan.requestedCuts(mode: "every", every: 1, at: [], duration: 4, minimumSegment: 0.1)
        XCTAssertEqual(cuts, [1, 2, 3])
        let p = SplitPlan.make(cuts: cuts, duration: 4, frameDuration: fd, keyframes: keys, preferLossless: true)
        XCTAssertTrue(p.lossless)
        XCTAssertEqual(p.segmentCount, 4)
        let off = SplitPlan.make(cuts: [1.5], duration: 4, frameDuration: fd, keyframes: keys, preferLossless: true)
        XCTAssertFalse(off.lossless, "a keyframe 0.5 s late is too far for a 1.5 s part")
        XCTAssertEqual(SplitPlan.requestedCuts(mode: "at", every: 0, at: [0, 2, 5], duration: 4, minimumSegment: 0.1), [2])
    }

    func testAtempoChainStaysInRange() {
        for f in [0.25, 0.5, 0.75, 1.25, 1.5, 2, 4] {
            let chain = SpeedVideoRunner.atempoChain(f)
            XCTAssertEqual(chain.reduce(1, *), f, accuracy: 1e-9)
            XCTAssertTrue(chain.allSatisfy { (0.5...2.0).contains($0) }, "\(f) → \(chain)")
        }
    }

    func testCropMathIsEvenAndInside() {
        guard let r = PixelCrop.parse("0.1,0.2,0.5,0.333") else { return XCTFail("parse") }
        let c = PixelCrop.make(r, frameWidth: 321, frameHeight: 241)
        XCTAssertEqual(c.width % 2, 0)
        XCTAssertEqual(c.height % 2, 0)
        XCTAssertEqual(c.x % 2, 0)
        XCTAssertLessThanOrEqual(c.x + c.width, 321)
        XCTAssertLessThanOrEqual(c.y + c.height, 241)
        XCTAssertNil(PixelCrop.parse("0,0,0,1"))
        XCTAssertNil(PixelCrop.parse("1,2"))
    }

    func testPDFOrderParsing() {
        XCTAssertEqual(PDFPageRef.parse("", pageCounts: [2, 1]),
                       [PDFPageRef(input: 0, page: 0), PDFPageRef(input: 0, page: 1), PDFPageRef(input: 1, page: 0)])
        XCTAssertEqual(PDFPageRef.parse("1:3,1:1:90,2:1:-90", pageCounts: [3, 1]),
                       [PDFPageRef(input: 0, page: 2), PDFPageRef(input: 0, page: 0, rotation: 90), PDFPageRef(input: 1, page: 0, rotation: 270)])
        XCTAssertEqual(PDFPageRef.parse("1:3-1", pageCounts: [3])?.map(\.page), [2, 1, 0])
        XCTAssertNil(PDFPageRef.parse("1:4", pageCounts: [3]))
        XCTAssertNil(PDFPageRef.parse("3:1", pageCounts: [3]))
        XCTAssertNil(PDFPageRef.parse("1:1:45", pageCounts: [3]))
        let refs = [PDFPageRef(input: 1, page: 0, rotation: 180), PDFPageRef(input: 0, page: 4)]
        XCTAssertEqual(PDFPageRef.parse(PDFPageRef.format(refs), pageCounts: [5, 1]), refs)
    }

    func testEncoderChoiceKeepsContainerFamily() {
        let hevc = MediaInfo.Video(index: 0, codec: "hevc", width: 1920, height: 1080, rotation: 0, frameRate: 30, pixelFormat: "yuv420p10le",
                                   profile: "Main 10", bitRate: 10_000_000, extradataHash: nil, sampleAspect: 1)
        let a = MediaEncoders.video(container: .mov, source: hevc, quality: .balanced)
        XCTAssertEqual(a.first?.label, "hevc_videotoolbox")
        XCTAssertTrue(a.first?.args.contains("main10") ?? false)
        XCTAssertTrue(a.first?.args.contains("hvc1") ?? false)
        XCTAssertEqual(a.last?.label, "libx265")
        XCTAssertEqual(MediaEncoders.video(container: .webm, source: hevc, quality: .balanced).map(\.label), ["libvpx-vp9"])
        XCTAssertEqual(MediaEncoders.twoPassVideo(container: .mp4, source: hevc, bitRate: 1_000_000).label, "libx264")
        XCTAssertEqual(MediaEncoders.audio(container: .webm, source: nil).dropFirst().first, "libopus")
        XCTAssertEqual(MediaEncoders.audio(container: .aiff, source: nil)[1], "pcm_s16be")
    }

    func testPrivateMetadataStripping() {
        let info = MediaInfo(url: URL(fileURLWithPath: "/x.mov"), duration: 1, startTime: 0, formatName: "mov", bitRate: nil, size: nil,
                             videos: [], audios: [], subtitleCount: 0,
                             tags: ["title": "Holiday", "location": "+51.5-000.1/", "com.apple.quicktime.model": "iPhone", "artist": "Me"])
        let args = MediaEncoders.metadata(.stripPrivate, info: info)
        XCTAssertTrue(args.contains("location="))
        XCTAssertTrue(args.contains("com.apple.quicktime.model="))
        XCTAssertFalse(args.contains("title="))
        XCTAssertFalse(args.contains("artist="))
        XCTAssertEqual(Array(MediaEncoders.metadata(.stripAll, info: info).prefix(2)), ["-map_metadata", "-1"])
    }

    func testBleepExpressionAndChannelFilters() {
        let e = BleepAudioRunner.expression(ranges: [1...2], tone: true)
        XCTAssertTrue(e.contains("sin(2*PI*1000*t)"))
        XCTAssertTrue(BleepAudioRunner.expression(ranges: [1...2], tone: false).hasPrefix("val(ch)*(1-"))
        XCTAssertNoThrow(try ChannelsAudioRunner.filter(mode: "mono", channels: 2).get())
        XCTAssertThrowsError(try ChannelsAudioRunner.filter(mode: "mono", channels: 1).get())
        XCTAssertThrowsError(try ChannelsAudioRunner.filter(mode: "swap", channels: 1).get())
    }

    func testTargetSizeBudget() {
        let b = CompressVideoRunner.budget(targetBytes: 10_000_000, duration: 60, hasAudio: true)
        XCTAssertEqual(b.audioKbps, 128)
        XCTAssertEqual(CompressVideoRunner.budget(targetBytes: 3_000_000, duration: 60, hasAudio: true).audioKbps, 96)
        XCTAssertEqual(CompressVideoRunner.budget(targetBytes: 1_000_000, duration: 60, hasAudio: true).audioKbps, 48)
        XCTAssertEqual(Double(b.videoBps + b.audioKbps * 1000), 10_000_000 * 8 / 60 * 0.97, accuracy: 100_000)
        XCTAssertEqual(CompressVideoRunner.budget(targetBytes: 1_000_000, duration: 10, hasAudio: false).audioKbps, 0)
    }

    func testLoudnormReportParsing() {
        let log = """
        [Parsed_loudnorm_0 @ 0x1]
        {
        \t"input_i" : "-21.81",
        \t"input_tp" : "-20.77",
        \t"input_lra" : "0.00",
        \t"input_thresh" : "-31.81",
        \t"target_offset" : "0.01"
        }
        [out#0/null @ 0x2] video:0KiB
        """
        let m = LoudnessMeasurement.parse(log)
        XCTAssertEqual(m?.integrated, -21.81)
        XCTAssertEqual(m?.offset, 0.01)
    }

    func testRegistryHasAllThirteen() {
        let ids = Set(MediaToolRunners.all.map(\.id))
        XCTAssertEqual(ids, [ToolIDs.trimVideo, ToolIDs.cropVideo, ToolIDs.speedVideo, ToolIDs.splitVideo, ToolIDs.joinVideo,
                             ToolIDs.snapshotVideo, ToolIDs.compressVideo, ToolIDs.trimAudio, ToolIDs.normalizeAudio,
                             ToolIDs.bleepAudio, ToolIDs.channelsAudio, ToolIDs.organizePDF, ToolIDs.compressPDF])
        for id in ids { XCTAssertNotNil(ToolRegistry.default[id], "\(id) not in the default registry") }
    }
}
