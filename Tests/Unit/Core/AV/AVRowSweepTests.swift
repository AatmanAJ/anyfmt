import XCTest
@testable import AnyfmtCore

/// Every lane E row (187), run by its own engine on its `sample.*` fixture,
/// output probed: streams present, duration within 0.15 s. About 12 s on an
/// M5 Max. The Phase 4 matrix runner does the same for the shipped best rows.
final class AVRowSweepTests: XCTestCase {
    func testEveryRowPassesOnItsFixture() async throws {
        let fixtures = try LaneE.fixtures()
        let gif = try LaneE.tempDirectory().appendingPathComponent("sample.gif")
        try await LaneE.ffmpeg(["-i", fixtures.appendingPathComponent("sample.mp4").path, "-vf", "fps=10", "-loop", "0", gif.path])
        let engines: [EngineID: any ConversionEngine] = [EngineIDs.ffmpeg: FFmpegAVEngine(), EngineIDs.avFoundation: AVFoundationEngine()]

        var failures: [String] = []
        var report: [String] = []
        let t0 = Date()
        for row in AVRoutes.rows {
            let input = row.from == Formats.gif ? gif : fixtures.appendingPathComponent("sample.\(Formats.extension(for: row.from))")
            guard let engine = engines[row.engine] else { failures.append("\(row): no engine"); continue }
            let start = Date()
            do {
                let out = try await LaneE.convert(input, to: row.to, engine: engine, from: row.from, schema: row.schema)
                let f = try await LaneE.probe(out)
                let videoTarget = AVCodecTables.videoContainers.contains(row.to) || row.to == Formats.gif
                var problems: [String] = []
                if videoTarget && f.video == nil { problems.append("no video") }
                if AVCodecTables.audioContainers.contains(row.to) && f.primaryAudio == nil { problems.append("no audio") }
                if row.to != Formats.gif && row.from != Formats.gif, abs((f.duration ?? 0) - 2.0) > 0.15 {
                    problems.append("duration \(f.duration ?? -1)")
                }
                if !problems.isEmpty { failures.append("\(row): \(problems.joined(separator: ", "))") }
                report.append(String(format: "%@ %.2fs %@", row.description, Date().timeIntervalSince(start),
                                     [f.video?.codec, f.primaryAudio?.codec].compactMap { $0 }.joined(separator: "+")))
            } catch {
                failures.append("\(row): \(error)")
            }
        }
        let summary = "rows: \(AVRoutes.rows.count), failures: \(failures.count), total \(String(format: "%.1f", Date().timeIntervalSince(t0))) s"
        print(([summary] + report).joined(separator: "\n"))
        XCTAssertEqual(failures, [], failures.joined(separator: "\n"))
    }
}
