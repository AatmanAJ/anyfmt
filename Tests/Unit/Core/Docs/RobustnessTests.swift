import PDFKit
import XCTest
@testable import HaloCore

/// Hostile and big inputs: readers must throw or degrade, never trap; big files stay fast.
final class RobustnessTests: XCTestCase {
    /// Deterministic corruption so failures are reproducible.
    struct LCG {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state >> 33 }
    }

    static func variants(_ data: Data, seed: UInt64) -> [Data] {
        var rng = LCG(state: seed)
        var flipped = data
        if !flipped.isEmpty { for _ in 0..<max(1, data.count / 200) { flipped[Int(rng.next() % UInt64(data.count))] ^= UInt8(truncatingIfNeeded: rng.next()) } }
        var garbage = Data(count: 4096)
        for k in 0..<garbage.count { garbage[k] = UInt8(truncatingIfNeeded: rng.next()) }
        return [Data(), data.prefix(data.count / 2), data.prefix(data.count - min(22, data.count)), flipped, garbage]
    }

    func testCorruptDocumentsNeverTrap() async throws {
        let formats: [(String, FormatID)] = [
            ("sample.docx", Formats.docx), ("sample.odt", Formats.odt), ("sample.epub", Formats.epub), ("sample.md", Formats.md),
            ("sample.html", Formats.html), ("sample.rtf", Formats.rtf), ("sample.doc", Formats.doc), ("sample.webarchive", Formats.webarchive),
            ("sample.textclipping", Formats.textClipping), ("sample.txt", Formats.txt),
        ]
        var seed: UInt64 = 1
        for (name, format) in formats {
            let original = try Data(contentsOf: try DocsFixtures.url(name))
            for v in Self.variants(original, seed: seed) {
                seed += 1
                let url = try tempDir("bad").appendingPathComponent("bad").appendingPathExtension(Formats.extension(for: format))
                try v.write(to: url)
                _ = try? DocumentIO.read(url, format: format)   // throwing is fine, trapping is not
            }
        }
    }

    func testCorruptSheetsAndPackagesNeverTrap() throws {
        var seed: UInt64 = 100
        for (name, format) in [("sample.xlsx", Formats.xlsx), ("sample.xls", Formats.xls), ("sample.ods", Formats.ods), ("sample.csv", Formats.csv), ("sample.json", Formats.json), ("sample.tsv", Formats.tsv)] {
            let original = try Data(contentsOf: try DocsFixtures.url(name))
            for v in Self.variants(original, seed: seed) {
                seed += 1
                let url = try tempDir("bad").appendingPathComponent("bad").appendingPathExtension(format.rawValue)
                try v.write(to: url)
                _ = try? SheetIO.read(url, format: format)
            }
        }
        for name in ["sample.pptx", "sample.docx", "sample.epub"] {
            for v in Self.variants(try Data(contentsOf: try DocsFixtures.url(name)), seed: seed) {
                seed += 1
                if let z = try? ZipReader(data: v) { for e in z.entries { _ = try? z.data(for: e) } }
                _ = try? XMLTree.parse(v)
                _ = try? JSONValue.parse(v)
                _ = MarkdownReader.parse(String(decoding: v, as: UTF8.self))
            }
        }
        // Pathological markdown: deep nesting and unbalanced delimiters.
        _ = MarkdownReader.parse(String(repeating: "> - ", count: 300) + "x")
        _ = MarkdownReader.parse(String(repeating: "*_~`[(", count: 2000))
        _ = MarkdownReader.parse(String(repeating: "[a](", count: 1000))
        // Hostile ODS repeat counts.
        let ods = #"<office:document-content xmlns:office="o" xmlns:table="t" xmlns:text="x"><office:body><office:spreadsheet><table:table table:name="S"><table:table-row table:number-rows-repeated="-5"><table:table-cell table:number-columns-repeated="-9" office:value-type="float" office:value="1"/></table:table-row></table:table></office:spreadsheet></office:body></office:document-content>"#
        var w = ZipWriter()
        try w.add("content.xml", ods)
        _ = try ODSReader.read(ZipReader(data: try w.finish()))
    }

    func testCorruptPDFNeverTraps() async throws {
        let pdf = try await PDFRouteTests.longPDF()
        var seed: UInt64 = 900
        for v in Self.variants(try Data(contentsOf: pdf), seed: seed) {
            seed += 1
            let url = try tempDir("bad").appendingPathComponent("bad.pdf")
            try v.write(to: url)
            _ = try? PDFDocReader.read(url)
            _ = try? PDFTableExtractor.workbook(url)
        }
    }

    /// The job queue runs several conversions at once: WebKit renders serialise, AppKit text work runs in parallel.
    func testConcurrentConversionsAreSafe() async throws {
        let jobs: [(String, FormatID, FormatID, any ConversionEngine)] = [
            ("sample.md", Formats.md, Formats.pdf, WebKitPDFEngine()), ("sample.docx", Formats.docx, Formats.pdf, WebKitPDFEngine()),
            ("sample.html", Formats.html, Formats.pdf, WebKitPDFEngine()), ("sample.xlsx", Formats.xlsx, Formats.pdf, SheetsEngine()),
            ("sample.md", Formats.md, Formats.rtf, AttributedTextEngine()), ("sample.docx", Formats.docx, Formats.rtfd, AttributedTextEngine()),
            ("sample.rtf", Formats.rtf, Formats.docx, OOXMLEngine()), ("sample.epub", Formats.epub, Formats.docx, OOXMLEngine()),
            ("sample.pptx", Formats.pptx, Formats.pdf, QuickLookEngine()), ("sample.doc", Formats.doc, Formats.md, MarkdownEngine()),
        ]
        let inputs = try jobs.map { try DocsFixtures.url($0.0) }
        let results = try await withThrowingTaskGroup(of: (Int, URL).self) { group -> [Int: URL] in
            for round in 0..<2 {
                for (k, job) in jobs.enumerated() {
                    let input = inputs[k]
                    group.addTask {
                        let out = try await runEngine(job.3, input, from: job.1, to: job.2, baseName: "c\(round)-\(k)")
                        return (k, out[0])
                    }
                }
            }
            var d: [Int: URL] = [:]
            for try await (k, url) in group { d[k] = url }
            return d
        }
        XCTAssertEqual(results.count, jobs.count)
        for (k, url) in results where jobs[k].2 == Formats.pdf {
            XCTAssertGreaterThan(PDFKitPageCount(url), 0, "\(jobs[k].0) → pdf")
        }
    }

    func testLargeCSVToXLSXIsFast() throws {
        var csv = "id,name,amount,date,flag\n"
        csv.reserveCapacity(10_000_000)
        for i in 0..<200_000 { csv += "\(i),Name \(i % 977),\(Double(i) * 1.25),2024-\(String(format: "%02d", i % 12 + 1))-15,\(i % 2 == 0 ? "TRUE" : "FALSE")\n" }
        let t0 = Date()
        let sheet = CSVReader.read(Data(csv.utf8))
        let parse = Date().timeIntervalSince(t0)
        XCTAssertEqual(sheet.rows.count, 200_001)
        XCTAssertEqual(sheet.rows[10], [.number(9), .string("Name 9"), .number(11.25), Cell.isoDate("2024-10-15")!, .bool(false)])
        let t1 = Date()
        let data = try XLSXWriter().write(Workbook(sheets: [sheet]))
        let write = Date().timeIntervalSince(t1)
        XCTAssertLessThan(parse + write, 20, "200k rows: parse \(parse)s, write \(write)s")
        let t2 = Date()
        let back = try XLSXReader.read(ZipReader(data: data))
        XCTAssertEqual(back.sheets[0].rows.count, 200_001)
        print("PERF csv parse \(parse)s xlsx write \(write)s xlsx read \(Date().timeIntervalSince(t2))s")
    }

    func testLongPDFReconstructionIsFast() async throws {
        var blocks: [DocBlock] = []
        for s in 1...40 {
            blocks.append(.heading(level: 2, [.text("Chapter \(s)")]))
            for p in 1...8 { blocks.append(.paragraph([.text("Paragraph \(p) of chapter \(s) has enough words to wrap across a couple of lines on an A4 page so the reader has real work to do.")])) }
        }
        let url = try tempDir("big").appendingPathComponent("big.pdf")
        try await DocumentIO.write(DocModel(blocks: blocks), format: Formats.pdf, to: url, options: .init())
        let pages = PDFDocument(url: url)?.pageCount ?? 0
        XCTAssertGreaterThan(pages, 15)
        let t0 = Date()
        let model = try PDFDocReader.read(url)
        let elapsed = Date().timeIntervalSince(t0)
        XCTAssertEqual(model.headings().count, 40)
        XCTAssertLessThan(elapsed / Double(pages), 0.5, "\(pages) pages in \(elapsed)s")
    }
}
