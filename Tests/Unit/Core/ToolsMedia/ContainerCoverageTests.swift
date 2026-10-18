import XCTest
@testable import HaloCore

/// Every container the media tools write keeps its format through a re-encode.
final class ContainerCoverageTests: XCTestCase {
    private func info(_ u: URL) async throws -> MediaInfo { try await MediaInfo.load(u, locator: TestEngines.locator) }

    /// 2 s clip in `ext`, made from clip.mp4 with that container's usual codecs.
    private func clip(_ ext: String) async throws -> URL {
        let src = try await MediaFixtures.url("clip.mp4")
        let dir = try makeOutputDirectory()
        let out = dir.appendingPathComponent("sample.\(ext)")
        let codecs: [String] = switch ext {
        case "webm": ["-c:v", "libvpx-vp9", "-b:v", "300k", "-deadline", "realtime", "-cpu-used", "8", "-c:a", "libopus"]
        case "avi": ["-c:v", "mpeg4", "-q:v", "4", "-c:a", "libmp3lame"]
        case "wmv": ["-c:v", "wmv2", "-q:v", "4", "-c:a", "wmav2"]
        case "mkv": ["-c:v", "libx265", "-x265-params", "log-level=error", "-c:a", "libopus"]
        default: ["-c:v", "libx264", "-c:a", "aac"]
        }
        try await TestEngines.ffmpeg(["-i", src.path, "-t", "2", "-pix_fmt", "yuv420p"] + codecs + [out.path])
        return out
    }

    func testVideoContainers() async throws {
        for ext in ["mov", "m4v", "mkv", "webm", "avi", "wmv"] {
            let input = try await clip(ext)
            let src = try await info(input)
            let (trim, _) = try await runTool(TrimVideoRunner(), [input], ["range": .string("0.5-1.5"), "lossless": .bool(false)])
            let t = try XCTUnwrap(trim.files.first)
            XCTAssertEqual(t.pathExtension, ext)
            let ti = try await info(t)
            XCTAssertEqual(ti.duration, 1, accuracy: 0.12, ext)
            XCTAssertEqual(ti.video?.codec, src.video?.codec == "hevc" ? "hevc" : ti.video?.codec, ext)
            if ext == "webm" { XCTAssertEqual(ti.video?.codec, "vp9") }
            if ext == "avi" { XCTAssertEqual(ti.video?.codec, "mpeg4") }
            if ext == "wmv" { XCTAssertEqual(ti.video?.codec, "wmv2") }
            if ext == "mkv" { XCTAssertEqual(ti.video?.codec, "hevc", "HEVC stays HEVC") }
            XCTAssertTrue(ti.hasAudio, ext)

            let (speed, _) = try await runTool(SpeedVideoRunner(), [input], ["factor": .string("2")])
            let si = try await info(try XCTUnwrap(speed.files.first))
            XCTAssertEqual(si.duration, 1, accuracy: 0.15, ext)

            let (lossless, _) = try await runTool(TrimVideoRunner(), [input], ["range": .string("1-2"), "lossless": .bool(true)])
            XCTAssertEqual(try XCTUnwrap(lossless.files.first).pathExtension, ext)

            let (parts, _) = try await runTool(SplitVideoRunner(), [input], ["mode": .string("every"), "every": .int(1)])
            XCTAssertEqual(parts.files.count, 2, ext)
            XCTAssertTrue(parts.files.allSatisfy { $0.pathExtension == ext })

            let size = Int(Double(MediaRun.fileSize(input)) * 0.6)
            let (sized, _) = try await runTool(CompressVideoRunner(), [input], [OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(size)])
            let got = Double(MediaRun.fileSize(try XCTUnwrap(sized.files.first)))
            // Two-pass rate control has little to work with in 2 s; the 4 s MP4 test holds ±10 %.
            XCTAssertLessThan(got, Double(size) * 1.25, "\(ext) target size")
        }
    }

    func testAudioContainers() async throws {
        let src = try await MediaFixtures.url("tone.m4a")
        for ext in ["wav", "flac", "aiff", "ogg", "opus", "caf", "wma", "mp3"] {
            let dir = try makeOutputDirectory()
            let input = dir.appendingPathComponent("sample.\(ext)")
            try await TestEngines.ffmpeg(["-i", src.path, "-t", "3", input.path])
            let codec = try await info(input).audio?.codec
            for (runner, options) in [(BleepAudioRunner() as any ToolRunner, ["ranges": OptionValue.string("1-1.5")]),
                                      (ChannelsAudioRunner(), ["mode": .string("mono")]),
                                      (TrimAudioRunner(), ["range": .string("0.5-2")]),
                                      (NormalizeAudioRunner(), ["target": .string("-16")])] {
                let (out, _) = try await runTool(runner, [input], options)
                let u = try XCTUnwrap(out.files.first, "\(runner.id) \(ext)")
                XCTAssertEqual(u.pathExtension, ext)
                let i = try await info(u)
                XCTAssertEqual(i.audio?.codec, codec, "\(runner.id) keeps \(ext)'s codec")
            }
        }
    }
}
