import XCTest
import ImageIO
import PDFKit
@testable import AnyfmtCore

/// Lane D's own mini-matrix: generates the lane fixtures with images.sh, runs every
/// available image route (direct rows and router hops from SVG) and validates each
/// output by opening it.
final class ImageRouteSweepTests: XCTestCase {
    typealias S = ImageTestSupport

    private func generateFixtures() throws -> URL {
        guard let engines = S.enginesDir else { throw XCTSkip("bundled engines not found") }
        let out = try S.tempDir("fixtures")
        let script = S.repoRoot.appendingPathComponent("Tests/Fixtures/lanes/images.sh")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script.path]
        var env = ProcessInfo.processInfo.environment
        env["OUT"] = out.path
        env["FFMPEG"] = engines.appendingPathComponent("Helpers/ffmpeg").path
        env["FFPROBE"] = engines.appendingPathComponent("Helpers/ffprobe").path
        env["RESVG"] = engines.appendingPathComponent("Helpers/resvg").path
        p.environment = env
        let err = Pipe()
        p.standardError = err
        let started = Date()
        try p.run()
        p.waitUntilExit()
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(p.terminationStatus, 0, String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
        XCTAssertLessThan(elapsed, 30, "fixture contract: < 30 s per lane")
        print("lane D fixtures: \(String(format: "%.1f", elapsed)) s")
        return out
    }

    func testEveryImageRouteOnFixtures() async throws {
        let locator = S.locator
        let fixtures = try generateFixtures()
        // Every input format we ship has its fixture.
        for f in ImageRoutes.rasterInputs + [Formats.svg, Formats.pdf] {
            let url = fixtures.appendingPathComponent("sample.\(Formats.extension(for: f))")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "missing fixture for \(f)")
        }
        let registry = EngineRegistry(ImageEngines.all)
        func available(_ c: Capability) -> Bool {
            switch c.engine {
            case EngineIDs.ffmpegImage: locator.ffmpeg != nil && ImageIOSupport.canDecode(format: c.from)
            case EngineIDs.resvg: locator.resvg != nil
            default: registry.isAvailable(c)
            }
        }
        let table = CapabilityTable(ImageRoutes.rows.filter(available))
        let router = Router(table: table)
        // Each row once (so the ffmpeg AVIF fallback runs even where ImageIO wins), plus SVG hops.
        var jobs: [(String, Route)] = table.rows.map { ("\($0.from)→\($0.to) [\($0.engine)]", Route([$0])) }
        for (to, route) in router.allRoutes(from: Formats.svg) where !route.isDirect {
            jobs.append(("svg→\(to) via \(route.hops.map { $0.to.rawValue }.joined(separator: "→"))", route))
        }
        let executor = RouteExecutor(registry: registry)
        var failures: [String] = []
        var report: [String] = []
        let work = try S.tempDir("sweep")
        for (i, (name, route)) in jobs.enumerated() {
            let input = fixtures.appendingPathComponent("sample.\(Formats.extension(for: route.from))")
            let started = Date()
            do {
                let outs = try await executor.execute(route, inputs: [input], options: OptionValues(), baseName: "sample",
                                                      metadata: .keep, workDirectory: work.appendingPathComponent("\(i)"), context: S.context)
                let ms = Date().timeIntervalSince(started) * 1000
                if let problem = validate(outs, route: route) { failures.append("\(name): \(problem)") }
                report.append(String(format: "%@\t%.0f ms\t%d B", name, ms, outs.reduce(0) { $0 + S.fileSize($1) }))
            } catch {
                failures.append("\(name): \(error)")
            }
        }
        print("lane D sweep: \(jobs.count) routes, \(failures.count) failed")
        print(report.joined(separator: "\n"))
        XCTAssertEqual(failures, [], failures.joined(separator: "\n"))
    }

    private func validate(_ outs: [URL], route: Route) -> String? {
        guard !outs.isEmpty else { return "no output" }
        let to = route.to
        if route.from == Formats.pdf && to != Formats.txt && outs.count != 3 { return "expected 3 pages, got \(outs.count)" }
        for u in outs {
            guard u.pathExtension == Formats.extension(for: to) else { return "wrong extension \(u.lastPathComponent)" }
            switch to {
            case Formats.pdf:
                guard let doc = PDFDocument(url: u), doc.pageCount >= 1 else { return "PDF does not open" }
                if route.from == Formats.tiff && doc.pageCount != 2 { return "TIFF pages \(doc.pageCount) ≠ 2" }
            case Formats.txt:
                guard let t = try? String(contentsOf: u, encoding: .utf8) else { return "text unreadable" }
                if route.from == Formats.pdf && !t.contains("anyfmt fixture page 1") { return "PDF text missing" }
                if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "OCR text empty" }
            default:
                guard let src = S.source(u), CGImageSourceGetCount(src) > 0, let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
                      img.width > 0, img.height > 0 else { return "image does not decode" }
                if to == Formats.ico || to == Formats.icns, CGImageSourceGetCount(src) < 5 { return "icon has \(CGImageSourceGetCount(src)) sizes" }
                if route.from == Formats.gif && (to == Formats.webp || to == Formats.avif),
                   let frames = try? S.probeFrameCount(u), frames != 5 { return "animation lost: \(frames) frames" }
            }
        }
        return nil
    }
}
