import XCTest
@testable import HaloCore

/// BUILD.md §10: "1 minute 1080p MOV → MP4: report time, must use hardware
/// encode where faster". Slow, so opt-in:
///
///     TEST_RUNNER_HALO_PERF=1 xcodebuild … test -only-testing:CoreTests/AVPerfTests
///
/// Prints one line per path; numbers are recorded in docs/lanes/E-av.md.
final class AVPerfTests: XCTestCase {
    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["HALO_PERF"] == "1" || env["TEST_RUNNER_HALO_PERF"] == "1" else { throw XCTSkip("set HALO_PERF=1 to run") }
    }

    private struct Result {
        let label: String
        let seconds: Double
        let megabytes: Double
        let ssim: Double?
    }

    private func ssim(_ out: URL, against src: URL) async throws -> Double? {
        guard let exe = LaneE.locator.ffmpeg else { return nil }
        let r = try await ProcessRunner.run(exe, ["-hide_banner", "-nostdin", "-i", out.path, "-i", src.path,
                                                  "-lavfi", "[0:v][1:v]ssim", "-f", "null", "-"])
        guard let range = r.stderr.range(of: "All:", options: .backwards) else { return nil }
        return Double(r.stderr[range.upperBound...].prefix { $0.isNumber || $0 == "." })
    }

    private func size(_ url: URL) -> Double {
        Double((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0) / 1_048_576
    }

    func testOneMinute1080pMOVToMP4() async throws {
        _ = try LaneE.requireEngines()
        let src = try await LaneE.makeClip(seconds: 60, size: "1920x1080")
        let facts = try await LaneE.probe(src)
        XCTAssertEqual(facts.duration ?? 0, 60, accuracy: 0.2)
        var results: [Result] = []

        func timed(_ label: String, _ body: () async throws -> URL) async throws {
            let t0 = Date()
            let out = try await body()
            let dt = Date().timeIntervalSince(t0)
            let s = label.contains("copy") || label.contains("passthrough") ? nil : try await ssim(out, against: src)
            results.append(Result(label: label, seconds: dt, megabytes: size(out), ssim: s))
        }

        // (a) Stream copy: the shipped route (AVFoundation passthrough) and ffmpeg's remux.
        try await timed("passthrough (AVFoundation, shipped route)") {
            try await LaneE.convert(src, to: Formats.mp4, engine: AVFoundationEngine())
        }
        try await timed("stream copy (ffmpeg)") {
            try await LaneE.convert(src, to: Formats.mp4, engine: FFmpegAVEngine())
        }

        // (b)/(c) Forced re-encode at each preset: pretend the source codec can't be copied.
        var forced = facts
        forced.video?.codec = "forced-reencode"
        for preset in ["balanced", "high", "small"] {
            for hardware in [true, false] {
                let dir = try LaneE.tempDirectory()
                let ctx = AVConversionPlanner.Context(input: src, output: dir.appendingPathComponent("out.mp4"),
                                                      scratchDirectory: dir, metadata: .keep)
                let opts = StandardSchemas.video.defaults.merging(OptionValues([OptionKey.videoQuality: .string(preset),
                                                                                OptionKey.hardware: .bool(hardware)]))
                let plan = try AVConversionPlanner.plan(forced, from: Formats.mov, to: Formats.mp4, options: opts, context: ctx)
                XCTAssertEqual(plan.usesVideoToolbox, hardware)
                try await timed("\(preset) \(plan.video?.encoder ?? "?")") {
                    try await FFmpegAVEngine().run(plan, context: LaneE.context, duration: facts.duration)
                    return plan.output
                }
            }
        }

        var lines = ["60 s 1920×1080 30 fps H.264 MOV (\(String(format: "%.1f", size(src))) MB) → MP4, \(ProcessInfo.processInfo.processorCount) cores"]
        for r in results {
            lines.append(r.label.padding(toLength: 44, withPad: " ", startingAt: 0)
                         + String(format: "%6.2f s  %6.1f MB  ", r.seconds, r.megabytes)
                         + (r.ssim.map { String(format: "SSIM %.5f", $0) } ?? ""))
        }
        let report = lines.joined(separator: "\n")
        print(report)
        try report.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("halo-laneE-perf.txt"), atomically: true, encoding: .utf8)

        // The default (hardware on) must be the faster encoder at the balanced preset.
        let vt = results.first { $0.label == "balanced h264_videotoolbox" }
        let x264 = results.first { $0.label == "balanced libx264" }
        if let vt, let x264 { XCTAssertLessThan(vt.seconds, x264.seconds, "VideoToolbox should be faster") }
        XCTAssertLessThan(results[0].seconds, 2, "a remux of a minute of 1080p takes well under 2 s")
    }
}
