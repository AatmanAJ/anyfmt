import XCTest
@testable import AnyfmtCore

/// Opt-in timings on a 1-minute 1080p30 clip (TEST_RUNNER_HALO_MEDIA_PERF=1).
/// Numbers go into docs/lanes/G2-media-tools.md.
final class MediaPerfTests: XCTestCase {
    func testTimings() async throws {
        guard ProcessInfo.processInfo.environment["ANYFMT_MEDIA_PERF"] != nil else { throw XCTSkip("set TEST_RUNNER_HALO_MEDIA_PERF=1") }
        let dir = try makeOutputDirectory()
        let clip = dir.appendingPathComponent("minute.mp4")
        try await TestEngines.ffmpeg(["-filter_complex", "testsrc2=size=1920x1080:rate=30:duration=60[v];sine=frequency=440:sample_rate=48000:duration=60[a]",
                                      "-map", "[v]", "-map", "[a]", "-c:v", "h264_videotoolbox", "-b:v", "8M", "-g", "60",
                                      "-c:a", "aac", "-ac", "2", clip.path])
        let size = MediaRun.fileSize(clip)
        var lines: [String] = ["source 60 s 1080p30 H.264 \(size / 1_000_000) MB"]
        func time(_ label: String, _ runner: any ToolRunner, _ options: [String: OptionValue], inputs: [URL]? = nil) async throws {
            let t0 = Date()
            let (out, _) = try await runTool(runner, inputs ?? [clip], options)
            let s = Date().timeIntervalSince(t0)
            let bytes = out.files.map(MediaRun.fileSize).reduce(0, +)
            lines.append(String(format: "%@: %.2f s, %d file(s), %.1f MB", label, s, out.files.count, Double(bytes) / 1_000_000))
        }
        try await time("trim 10–50 s lossless (keyframe-snapped)", TrimVideoRunner(), ["range": .string("10-50"), "lossless": .bool(true)])
        try await time("trim 10.5–49.5 s re-encode (VT)", TrimVideoRunner(), ["range": .string("10.5-49.5"), "lossless": .bool(false)])
        try await time("crop half (VT)", CropVideoRunner(), ["rect": .string("0.25,0.25,0.5,0.5")])
        try await time("speed 2× (VT)", SpeedVideoRunner(), ["factor": .string("2")])
        try await time("split every 10 s lossless", SplitVideoRunner(), ["mode": .string("every"), "every": .int(10)])
        try await time("snapshot 3 frames", SnapshotVideoRunner(), ["times": .string("5,30,55")])
        try await time("compress balanced (VT)", CompressVideoRunner(), [OptionKey.videoQuality: .string("balanced")])
        try await time("compress to 20 MB (x264 2-pass)", CompressVideoRunner(), [OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(20_000_000)])
        try await time("normalize −16 LUFS", NormalizeAudioRunner(), ["target": .string("-16")])
        try await time("join 2× lossless", JoinVideoRunner(), [:], inputs: [clip, clip])
        let pdf = try await MediaFixtures.url("pages.pdf")
        try await time("compress PDF 150 DPI 60 %", CompressPDFRunner(), [:], inputs: [pdf])
        print("MEDIA PERF\n" + lines.joined(separator: "\n"))
    }
}
