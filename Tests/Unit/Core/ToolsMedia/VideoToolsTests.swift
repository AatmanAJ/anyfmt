import XCTest
import ImageIO
@testable import HaloCore

/// Tools 12–18 end to end with the bundled ffmpeg.
final class VideoToolsTests: XCTestCase {
    private let frame = 1.0 / 30

    private func info(_ u: URL) async throws -> MediaInfo { try await MediaInfo.load(u, locator: TestEngines.locator) }

    private func frameCount(_ u: URL) async throws -> Int {
        try await KeyframeIndex.load(try await info(u), locator: TestEngines.locator).packets.count
    }

    // MARK: 12 Trim

    func testTrimLosslessIsKeyframeAlignedCopy() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        // 1.2–2.6 snaps out to the enclosing keyframes 1.0 and 3.0.
        let (out, _) = try await runTool(TrimVideoRunner(), [clip], ["range": .string("1.2-2.6"), "lossless": .bool(true)])
        let u = try XCTUnwrap(out.files.first)
        XCTAssertEqual(u.pathExtension, "mp4")
        let i = try await info(u)
        XCTAssertEqual(i.video?.codec, "h264")
        let frames = try await frameCount(u)
        XCTAssertEqual(frames, 60, "two whole GOPs, no frames from the next one")
        XCTAssertEqual(i.duration, 2.0, accuracy: 0.03)
        XCTAssertTrue(i.hasAudio)
        // Stream copy: same bitstream parameters as the source.
        let src = try await info(clip)
        XCTAssertEqual(i.video?.extradataHash, src.video?.extradataHash)
    }

    func testTrimReencodeIsFrameAccurate() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (out, _) = try await runTool(TrimVideoRunner(), [clip], ["range": .string("1.2-2.6"), "lossless": .bool(false)])
        let u = try XCTUnwrap(out.files.first)
        let frames = try await frameCount(u)
        XCTAssertEqual(Double(frames) * frame, 1.4, accuracy: frame + 1e-6, "±1 frame")
    }

    func testTrimLongGOPFallsBackToReencode() async throws {
        let clip = try await MediaFixtures.url("longgop.mp4")
        let (out, _) = try await runTool(TrimVideoRunner(), [clip], ["range": .string("2-3"), "lossless": .bool(true)])
        let u = try XCTUnwrap(out.files.first)
        let frames = try await frameCount(u)
        XCTAssertEqual(Double(frames) * frame, 1.0, accuracy: frame + 1e-6)
    }

    func testTrimRejectsMissingRange() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        do {
            _ = try await runTool(TrimVideoRunner(), [clip], ["range": .string("")])
            XCTFail("expected invalid option")
        } catch let e as ConversionError {
            guard case .invalidOption = e else { return XCTFail("\(e)") }
        }
    }

    // MARK: 13 Crop

    func testCropProducesEvenDimensionsAndKeepsAudio() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (out, _) = try await runTool(CropVideoRunner(), [clip], ["rect": .string("0.25,0.25,0.5,0.5")])
        let i = try await info(try XCTUnwrap(out.files.first))
        XCTAssertEqual(i.video?.width, 160)
        XCTAssertEqual(i.video?.height, 120)
        XCTAssertEqual(i.audio?.codec, "aac")
        XCTAssertEqual(i.duration, 4, accuracy: 0.1)
    }

    // MARK: 14 Speed

    func testSpeedChangesDuration() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (fast, _) = try await runTool(SpeedVideoRunner(), [clip], ["factor": .string("2"), "keepPitch": .bool(true)])
        let f = try await info(try XCTUnwrap(fast.files.first))
        XCTAssertEqual(f.duration, 2, accuracy: 0.1)
        XCTAssertEqual(f.video?.frameRate ?? 0, 30, accuracy: 0.5)
        let (slow, _) = try await runTool(SpeedVideoRunner(), [clip], ["factor": .string("0.5"), "keepPitch": .bool(false)])
        let slowDuration = try await info(try XCTUnwrap(slow.files.first)).duration
        XCTAssertEqual(slowDuration, 8, accuracy: 0.15)
    }

    func testSpeedWithoutAudioTrack() async throws {
        let clip = try await MediaFixtures.url("silent.mp4")
        let (out, _) = try await runTool(SpeedVideoRunner(), [clip], ["factor": .string("4")])
        let i = try await info(try XCTUnwrap(out.files.first))
        XCTAssertFalse(i.hasAudio)
        XCTAssertEqual(i.duration, 0.5, accuracy: 0.1)
    }

    // MARK: 15 Split

    func testSplitEverySecondLossless() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (out, _) = try await runTool(SplitVideoRunner(), [clip], ["mode": .string("every"), "every": .int(1)], base: "clip-part")
        XCTAssertEqual(out.files.map(\.lastPathComponent), ["clip-part-001.mp4", "clip-part-002.mp4", "clip-part-003.mp4", "clip-part-004.mp4"])
        for f in out.files {
            let n = try await frameCount(f)
            XCTAssertEqual(n, 30, f.lastPathComponent)
        }
    }

    func testSplitAtTimesReencodesFrameExact() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (out, _) = try await runTool(SplitVideoRunner(), [clip], ["mode": .string("at"), "at": .string("1.5, 2.5"), "lossless": .bool(true)])
        XCTAssertEqual(out.files.count, 3)
        var frames: [Int] = []
        for f in out.files { frames.append(try await frameCount(f)) }
        XCTAssertEqual(frames, [45, 30, 45])
    }

    // MARK: 16 Join

    func testJoinMatchingClipsLosslessly() async throws {
        let a = try await MediaFixtures.url("clip.mp4"), b = try await MediaFixtures.url("clip2.mp4")
        let verdict = JoinPlanner.verdict([try await info(a), try await info(b)])
        XCTAssertTrue(verdict.lossless, verdict.reasons.joined())
        let (out, _) = try await runTool(JoinVideoRunner(), [a, b], [:])
        let u = try XCTUnwrap(out.files.first)
        let i = try await info(u)
        XCTAssertEqual(u.pathExtension, "mp4")
        XCTAssertEqual(i.duration, 6, accuracy: 0.1)
        let frames = try await frameCount(u)
        XCTAssertEqual(frames, 180)
        let sourceHash = try await info(a).video?.extradataHash
        XCTAssertEqual(i.video?.extradataHash, sourceHash, "stream copy")
    }

    func testJoinMismatchedClipsReencodesWithLetterbox() async throws {
        let a = try await MediaFixtures.url("clip.mp4"), w = try await MediaFixtures.url("wide.mov")
        let verdict = JoinPlanner.verdict([try await info(a), try await info(w)])
        XCTAssertFalse(verdict.lossless)
        XCTAssertFalse(verdict.reasons.isEmpty)
        // "order" puts the wide clip first.
        let (out, _) = try await runTool(JoinVideoRunner(), [a, w], ["order": .string("2,1")])
        let u = try XCTUnwrap(out.files.first)
        let i = try await info(u)
        XCTAssertEqual(u.pathExtension, "mp4")
        XCTAssertEqual(i.video?.codec, "h264")
        XCTAssertEqual(i.video?.width, 640)
        XCTAssertEqual(i.video?.height, 360)
        XCTAssertEqual(i.audio?.codec, "aac", "silence is added for the clip without sound")
        XCTAssertEqual(i.duration, 6, accuracy: 0.15)
    }

    // MARK: 17 Snapshot

    func testSnapshotFramesAtTimes() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (out, _) = try await runTool(SnapshotVideoRunner(), [clip], ["times": .string("0.5, 3.2"), "format": .string("jpg")])
        XCTAssertEqual(out.files.map(\.pathExtension), ["jpg", "jpg"])
        for f in out.files {
            let src = try XCTUnwrap(CGImageSourceCreateWithURL(f as CFURL, nil))
            let img = try XCTUnwrap(CGImageSourceCreateImageAtIndex(src, 0, nil))
            XCTAssertEqual(img.width, 320)
            XCTAssertEqual(img.height, 240)
        }
        let (mid, _) = try await runTool(SnapshotVideoRunner(), [clip], [:])
        XCTAssertEqual(mid.files.map(\.lastPathComponent), ["out.png"])
    }

    func testSnapshotFrameStartMath() {
        XCTAssertEqual(SnapshotVideoRunner.frameStart(at: 1.0, frameDuration: frame), 1.0, accuracy: 1e-9)
        XCTAssertEqual(SnapshotVideoRunner.frameStart(at: 1.02, frameDuration: frame), 1.0, accuracy: 1e-9)
        XCTAssertEqual(SnapshotVideoRunner.frameStart(at: 1.0 + frame, frameDuration: frame), 1.0 + frame, accuracy: 1e-9)
    }

    // MARK: 18 Compress

    func testCompressToTargetSizeWithinTenPercent() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let target = 120_000
        let (out, _) = try await runTool(CompressVideoRunner(), [clip], [OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(target)])
        let size = Double(MediaRun.fileSize(try XCTUnwrap(out.files.first)))
        XCTAssertEqual(size, Double(target), accuracy: Double(target) * 0.10, "got \(Int(size)) bytes")
    }

    func testCompressPresetIsSmallerAndScales() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (out, _) = try await runTool(CompressVideoRunner(), [clip], [OptionKey.videoQuality: .string("small"), OptionKey.resolution: .string("180")])
        let u = try XCTUnwrap(out.files.first)
        XCTAssertLessThan(MediaRun.fileSize(u), MediaRun.fileSize(clip))
        let i = try await info(u)
        XCTAssertEqual(i.video?.height, 180)
        XCTAssertEqual(i.video?.width, 240)
    }

    func testCompressTargetLargerThanFileIsAHumanError() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        do {
            _ = try await runTool(CompressVideoRunner(), [clip], [OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(50_000_000)])
            XCTFail("expected an error")
        } catch let e as ConversionError {
            XCTAssertTrue(e.errorDescription?.contains("already smaller") ?? false, e.errorDescription ?? "")
        }
    }

    // MARK: Metadata policy

    func testStripAllRemovesTitle() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let dir = try makeOutputDirectory()
        let titled = dir.appendingPathComponent("titled.mp4")
        try await TestEngines.ffmpeg(["-i", clip.path, "-c", "copy", "-metadata", "title=Secret", "-metadata", "location=+51.5000-000.1200/", titled.path])
        let (kept, _) = try await runTool(TrimVideoRunner(), [titled], ["range": .string("1-3")], metadata: .keep)
        let keptTitle = try await info(try XCTUnwrap(kept.files.first)).tags["title"]
        XCTAssertEqual(keptTitle, "Secret")
        let (priv, _) = try await runTool(TrimVideoRunner(), [titled], ["range": .string("1-3")], metadata: .stripPrivate)
        let p = try await info(try XCTUnwrap(priv.files.first))
        XCTAssertEqual(p.tags["title"], "Secret")
        XCTAssertNil(p.tags["location"])
        let (none, _) = try await runTool(TrimVideoRunner(), [titled], ["range": .string("1-3")], metadata: .stripAll)
        let strippedTitle = try await info(try XCTUnwrap(none.files.first)).tags["title"]
        XCTAssertNil(strippedTitle)
    }
}
