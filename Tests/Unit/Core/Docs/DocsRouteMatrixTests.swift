import AppKit
import PDFKit
import XCTest
@testable import AnyfmtCore

/// Lane-local matrix: every shipped lane F route (direct rows and the multi-hop
/// routes the router derives from them) runs on its fixture and the output is
/// opened and checked. Pack/opt-in rows are excluded (not shipped by default).
final class DocsRouteMatrixTests: XCTestCase {
    static let laneRows = DocsRoutes.rows + ArchiveRoutes.rows

    static var shippedTable: CapabilityTable {
        CapabilityTable(laneRows.filter { !$0.flags.contains(.needsPack) && !$0.flags.contains(.optIn) })
            .available(in: EngineRegistry(DocsEngines.all + ArchiveEngines.all))
    }

    func testLaneTableIsHealthy() {
        let registry = EngineRegistry(DocsEngines.all + ArchiveEngines.all)
        XCTAssertEqual(CapabilityTable(Self.laneRows).integrityIssues(registry: registry), [])
        // Pack/opt-in rows never leak into the default, unflagged table.
        for r in Self.laneRows where r.engine == EngineIDs.officePack || r.engine == EngineIDs.pandocPack { XCTAssertTrue(r.flags.contains(.needsPack), "\(r)") }
    }

    /// Fixture for a format (PDF comes from lane D in the full build; make one here).
    static func fixture(_ f: FormatID) async throws -> URL? {
        let dir = try DocsFixtures.directory()
        if f == Formats.folder { return dir.appendingPathComponent("sample-folder") }
        let url = dir.appendingPathComponent("sample").appendingPathExtension(Formats.extension(for: f))
        if f == Formats.pdf, !FileManager.default.fileExists(atPath: url.path) {
            _ = try await WebKitPDFEngine().convert(ConversionRequest(inputs: [dir.appendingPathComponent("sample.html")], from: Formats.html, to: Formats.pdf,
                                                                      options: .init(), outputDirectory: dir, baseName: "sample", metadata: .keep), context: EngineContext())
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func testEveryShippedRouteProducesAValidFile() async throws {
        let router = Router(table: Self.shippedTable)
        let inputs = Array(Set(Self.shippedTable.rows.map(\.from))).sorted()
        var failures: [String] = []
        var count = 0, direct = 0
        var timings: [(String, Double)] = []
        var multiHop: [String] = []
        for from in inputs {
            guard let input = try await Self.fixture(from) else { failures.append("no fixture for \(from)"); continue }
            for (to, route) in router.allRoutes(from: from).sorted(by: { $0.key < $1.key }) {
                count += 1
                if route.isDirect { direct += 1 } else { multiHop.append(route.description) }
                let work = try tempDir("m")
                let t0 = Date()
                do {
                    let out = try await RouteExecutor(registry: EngineRegistry(DocsEngines.all + ArchiveEngines.all)).execute(
                        route, inputs: [input], options: .init(), baseName: "sample", metadata: .keep, workDirectory: work, context: EngineContext())
                    if let problem = Self.validate(out, as: to, route: route) { failures.append("\(route): \(problem)") }
                } catch {
                    failures.append("\(route): \(error)")
                }
                timings.append(("\(from)→\(to)", Date().timeIntervalSince(t0)))
                try? FileManager.default.removeItem(at: work)
            }
        }
        let slow = timings.sorted { $0.1 > $1.1 }.prefix(5).map { "\($0.0) \(String(format: "%.2f", $0.1))s" }
        let summary = "lane F routes: \(count) (\(direct) direct), failures: \(failures.count); slowest: \(slow.joined(separator: ", "))"
        let report = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-laneF-matrix.txt")
        try? (summary + "\n" + failures.joined(separator: "\n") + "\n--- multi-hop\n" + multiHop.joined(separator: "\n"))
            .write(to: report, atomically: true, encoding: .utf8)
        XCTAssertEqual(failures, [], summary)
        XCTAssertGreaterThan(count, 150, summary)
    }

    /// Opens the output the way a user's app would and checks it has content.
    static func validate(_ files: [URL], as format: FormatID, route: Route) -> String? {
        guard let first = files.first else { return "no output" }
        let isMulti = route.hops.last?.flags.contains(.multiOutput) ?? false
        if files.count > 1 && !isMulti { return "unexpected \(files.count) files" }
        for f in files where !FileManager.default.fileExists(atPath: f.path) { return "missing \(f.lastPathComponent)" }
        do {
            switch format {
            case Formats.docx:
                let d = try DOCXReader.read(first)
                if d.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "empty docx" }
                _ = try NSAttributedString(url: first, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
            case Formats.odt:
                let z = try ZipReader(url: first)
                if z.entries.first?.path != "mimetype" { return "mimetype not first" }
                if try ODTReader.read(first).text.isEmpty { return "empty odt" }
            case Formats.md, Formats.txt, Formats.html, Formats.csv, Formats.tsv, Formats.json:
                let s = try String(contentsOf: first, encoding: .utf8)
                if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "empty text" }
                if format == Formats.json { _ = try JSONValue.parse(Data(s.utf8)) }
                if format == Formats.html, (try? XMLTree.parseHTML(s)) == nil { return "html unparsable" }
            case Formats.rtf, Formats.rtfd:
                let s = try NSAttributedString(url: first, options: [:], documentAttributes: nil)
                if s.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "empty rich text" }
            case Formats.epub:
                let z = try ZipReader(url: first)
                if z.entries.first?.path != "mimetype" || z.entries.first?.method != 0 { return "bad OCF mimetype" }
                let pkg = try EPUBReader.package(z)
                for id in pkg.spine where pkg.manifest[id] == nil { return "spine/manifest mismatch" }
                for (_, item) in pkg.manifest where !z.contains(item.href) { return "missing \(item.href)" }
                if try EPUBReader.read(first).text.isEmpty { return "empty epub" }
            case Formats.pdf:
                guard let doc = PDFDocument(url: first), doc.pageCount > 0 else { return "pdf unreadable" }
                // Every lane F source has text, so a blank render is a failure.
                if (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).count < 5 { return "pdf has no text" }
            case Formats.pptx:
                let z = try ZipReader(url: first)
                if try XMLTree.parse(z.data("ppt/presentation.xml")).all("sldId").isEmpty { return "no slides" }
            case Formats.xlsx:
                if try XLSXReader.read(ZipReader(url: first)).sheets.isEmpty { return "no sheets" }
            case Formats.ods:
                if try ODSReader.read(ZipReader(url: first)).sheets.isEmpty { return "no sheets" }
            case Formats.png, Formats.jpg:
                for f in files where ImageSupport.pixelInfo(try Data(contentsOf: f)) == nil { return "undecodable \(f.lastPathComponent)" }
            case Formats.zip, Formats.tar, Formats.gz, Formats.sevenZip:
                let p = Process()
                p.executableURL = ArchiveEngine.bsdtar
                p.arguments = ["-tf", first.path]
                p.standardOutput = FileHandle.nullDevice
                p.standardError = FileHandle.nullDevice
                try p.run(); p.waitUntilExit()
                if p.terminationStatus != 0 { return "archive unreadable" }
            case Formats.folder:
                if try FileManager.default.contentsOfDirectory(atPath: first.path).isEmpty { return "empty folder" }
            default:
                return "no validator for \(format)"
            }
        } catch {
            return "validation threw \(error)"
        }
        return nil
    }
}
