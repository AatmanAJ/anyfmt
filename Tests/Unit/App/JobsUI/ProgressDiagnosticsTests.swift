import XCTest
@testable import HaloApp
@testable import HaloCore

/// "Copy details": versions, the route, the engine's exit line and stderr tail,
/// with the home folder written as ~.
final class ProgressDiagnosticsTests: XCTestCase {
    private let engines = [
        EngineInfo(name: "FFmpeg", version: "9.0.2", licence: "GPL", location: "`Contents/Helpers/ffmpeg`", licenceFolder: nil),
        EngineInfo(name: "x264", version: "stable", licence: "GPL", location: "statically inside libavcodec", licenceFolder: nil),
        EngineInfo(name: "resvg", version: "0.48.1", licence: "MIT", location: "`Contents/Helpers/resvg`", licenceFolder: nil),
    ]

    func testAddsEngineVersionsAndRedactsHome() {
        let raw = """
        Halo 2.0 (200) · macOS 14.6.1 · arm64
        Job: clip.mov → MP4
        Inputs: clip.mov (mov)
        Error: unreadable /Users/sam/Movies/clip.mov: moov atom not found
        url file:///Users/sam/My%20Movies/a.mov and /Users/samantha/keep.mov
        """
        let out = ProgressDiagnostics.report(raw, home: "/Users/sam", engines: engines)
        let lines = out.components(separatedBy: "\n")
        XCTAssertEqual(lines[1], "Engines: FFmpeg 9.0.2 · resvg 0.48.1", "shipped binaries, next to the app version")
        XCTAssertTrue(out.contains("unreadable ~/Movies/clip.mov"))
        XCTAssertTrue(out.contains("file://~/My%20Movies/a.mov"))
        XCTAssertTrue(out.contains("/Users/samantha/keep.mov"), "only whole path components are redacted")
        XCTAssertFalse(out.contains("/Users/sam/"))
    }

    func testKeepsTheStderrTail() {
        let stderr = (1...100).map { "line \($0)" }.joined(separator: "\n")
        let raw = "Halo · macOS\nError: ffmpeg exited 1\n\(stderr)"
        let out = ProgressDiagnostics.report(raw, home: "/Users/nobody", engines: [])
        XCTAssertTrue(out.contains("ffmpeg exited 1"), "the engine's exit line stays")
        XCTAssertTrue(out.contains("line 100"))
        XCTAssertTrue(out.contains("line 61"))
        XCTAssertFalse(out.contains("line 60\n"))
        XCTAssertTrue(out.contains("[… 60 earlier stderr lines]"))
    }

    func testFinishedNumeral() {
        let sizes = FileSizes { $0.lastPathComponent == "a.mov" ? 6_300_000 : 2_400_000 }
        let a = URL(fileURLWithPath: "/tmp/a.mov"), b = URL(fileURLWithPath: "/tmp/b.gif")
        let smaller = ResultFigure(inputs: [a], outputs: [b], started: nil, finished: nil, sizes: sizes, files: nil)
        XCTAssertEqual(smaller.numeral, "\u{2212}62%")
        XCTAssertEqual(smaller.spoken, "62% smaller")
        let t0 = Date()
        let timed = ResultFigure(inputs: [a], outputs: [b], started: t0, finished: t0.addingTimeInterval(42), sizes: .none, files: nil)
        XCTAssertEqual(timed.numeral, "42 s")
        XCTAssertNil(timed.sizes)
    }
}
