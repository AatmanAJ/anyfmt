import XCTest
import AnyfmtCore
@testable import AnyfmtApp

final class BundledEnginesTests: XCTestCase {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// The embedded copy must match Engines/VERSIONS.md row for row.
    func testEmbeddedTableMatchesVersionsFile() throws {
        let text = try String(contentsOf: repoRoot.appendingPathComponent("Engines/VERSIONS.md"), encoding: .utf8)
        let fileRows = Set(text.split(separator: "\n").map(String.init).filter {
            $0.hasPrefix("| ") && !$0.hasPrefix("| Component") && !$0.hasPrefix("|---")
        })
        let embedded = Set(BundledEngines.versionsTable.split(separator: "\n").map(String.init))
        XCTAssertEqual(embedded, fileRows, "Update BundledEngines.versionsTable from Engines/VERSIONS.md")
    }

    func testParse() throws {
        let engines = BundledEngines.parse(BundledEngines.versionsTable, licences: nil)
        XCTAssertEqual(engines.count, 13)
        let ffmpeg = try XCTUnwrap(engines.first { $0.name == "FFmpeg" })
        XCTAssertEqual(ffmpeg.version, "9.0.2")
        XCTAssertEqual(ffmpeg.licence, "GPL-2.0-or-later", "notes in parentheses are dropped")
        XCTAssertEqual(engines.first { $0.name == "x264" }?.version, "stable b35605a")
        XCTAssertEqual(engines.first { $0.name.hasPrefix("libaom") }?.shortName, "libaom")
        XCTAssertNil(ffmpeg.licenceFolder)
    }

    /// Licence folders are matched against the repo's LICENSES layout (the bundle copies it).
    func testLicenceFoldersResolveForEveryEngine() {
        let engines = BundledEngines.parse(BundledEngines.versionsTable, licences: repoRoot.appendingPathComponent("LICENSES"))
        for e in engines {
            XCTAssertNotNil(e.licenceFolder, "no LICENSES folder for \(e.name)")
        }
        XCTAssertEqual(engines.first { $0.name == "Sparkle" }?.licenceFolder?.lastPathComponent, "Sparkle-2.10.0")
    }
}

@MainActor
final class DiagnosticsTests: XCTestCase {
    func testReportHasVersionsEnginesAndNoPaths() throws {
        let (s, cleanup) = try makeSettings()
        defer { cleanup() }
        s.setOutputFolder(FileManager.default.homeDirectoryForCurrentUser)
        s.formatDefaults = [Formats.png: OptionValues(["imagePath": .string("/Users/someone/Pictures/bg.png")])]
        let info = AppInfo(version: "1.2", build: "34", bundleID: Brand.bundleID, updateHost: nil, helpersURL: nil)
        let report = Diagnostics.report(settings: s, info: info, engines: BundledEngines.all, packs: [])
        XCTAssertTrue(report.contains("\(Brand.name) 1.2 (34)"))
        XCTAssertTrue(report.contains("macOS"))
        XCTAssertTrue(report.contains("FFmpeg 9.0.2"))
        XCTAssertTrue(report.contains("\"output.location\" : \"custom folder\""))
        XCTAssertFalse(report.contains(FileManager.default.homeDirectoryForCurrentUser.path))
        XCTAssertFalse(report.contains("/Users/"))
        XCTAssertTrue(report.contains("<path>"))
    }

    func testRedact() {
        XCTAssertEqual(Diagnostics.redact("{name}"), "{name}")
        XCTAssertEqual(Diagnostics.redact("/Volumes/Disk/x"), "<path>")
        XCTAssertEqual(Diagnostics.redact("~/Desktop"), "<path>")
    }

    func testConcurrencyAutomaticIsPerformanceCoresMinusOne() {
        XCTAssertEqual(ConcurrencyInfo.automatic, max(1, ConcurrencyInfo.performanceCores - 1))
        XCTAssertGreaterThanOrEqual(ConcurrencyInfo.maximum, ConcurrencyInfo.automatic)
    }

    func testLogCommandUsesSubsystem() {
        XCTAssertTrue(LogsInfo.command(bundleID: "dev.example.app").contains("subsystem == \"dev.example.app\""))
        XCTAssertTrue(LogsInfo.folder.path.hasSuffix("Library/Logs/\(Brand.name)"))
    }

    func testPlaceholderFeedHostIsHidden() {
        let line = AppInfo(version: "1", build: "1", bundleID: "x", updateHost: nil, helpersURL: nil).updateLine
        XCTAssertFalse(line.contains(".invalid"))
        let real = AppInfo(version: "1", build: "1", bundleID: "x", updateHost: "updates.example.org", helpersURL: nil).updateLine
        XCTAssertTrue(real.contains("updates.example.org"))
    }
}
