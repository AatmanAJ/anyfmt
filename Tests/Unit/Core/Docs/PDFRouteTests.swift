import PDFKit
import XCTest
@testable import AnyfmtCore

/// WebKit HTML → PDF pagination, and PDF → DOCX/PPTX/XLSX reconstruction.
final class PDFRouteTests: XCTestCase {
    /// A long document (headings, lists, a table, an image) rendered by our own WebKit path.
    static func longPDF() async throws -> URL {
        var blocks: [DocBlock] = [.heading(level: 1, [.text("Annual Report")]),
                                  .paragraph([.text("This report summarises the year in plain language.")])]
        for s in 1...6 {
            blocks.append(.heading(level: 2, [.text("Section \(s)")]))
            for p in 1...6 {
                blocks.append(.paragraph([.text("Paragraph \(p) of section \(s). "), .strong([.text("Important")]),
                                          .text(" words keep their weight while the rest of this sentence continues for long enough to wrap onto a second line of text.")]))
            }
            if s == 2 {
                blocks.append(.list(DocList(ordered: false, items: [DocListItem([.paragraph([.text("First bullet point")])]),
                                                                       DocListItem([.paragraph([.text("Second bullet point")])])])))
            }
        }
        blocks.append(.image(DocImage(data: samplePNG(width: 300, height: 200), mime: "image/png", alt: "Chart")))
        let url = try tempDir("pdf").appendingPathComponent("long.pdf")
        try await DocumentIO.write(DocModel(metadata: DocMetadata(title: "Annual Report"), blocks: blocks), format: Formats.pdf, to: url,
                                   options: OptionValues([OptionKey.pageSize: .string("a4")]))
        return url
    }

    func testWebKitPaginatesLongDocuments() async throws {
        let url = try await Self.longPDF()
        let doc = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThan(doc.pageCount, 1, "long documents must paginate, not become one tall page")
        let size = doc.page(at: 0)!.bounds(for: .mediaBox).size
        XCTAssertEqual(size.width, 595.28, accuracy: 1, "A4 width")
        XCTAssertEqual(size.height, 841.89, accuracy: 1, "A4 height")
        XCTAssertTrue(doc.string?.contains("Section 6") ?? false)
        // Letter paper too.
        let letter = try tempDir("pdf").appendingPathComponent("l.pdf")
        try await DocumentIO.write(DocModel(blocks: [.paragraph([.text("hi")])]), format: Formats.pdf, to: letter, options: OptionValues([OptionKey.pageSize: .string("letter")]))
        XCTAssertEqual(PDFDocument(url: letter)?.page(at: 0)?.bounds(for: .mediaBox).width ?? 0, 612, accuracy: 1)
    }

    func testPageBreaksAndRemoteImagesInPrint() async throws {
        let doc = DocModel(blocks: [.paragraph([.text("one")]), .pageBreak, .paragraph([.text("two")]),
                                    .image(DocImage(data: nil, mime: "", alt: "remote", source: "https://example.invalid/x.png"))])
        let html = HTMLWriter(flavor: .print).document(doc)
        XCTAssertFalse(html.contains("example.invalid"), "print HTML never references remote content")
        let url = try tempDir("pdf").appendingPathComponent("b.pdf")
        try await DocumentIO.write(doc, format: Formats.pdf, to: url, options: .init())
        XCTAssertEqual(PDFDocument(url: url)?.pageCount, 2, "CSS page break honoured")
    }

    func testPDFToDocxRecoversHeadingsListsAndImages() async throws {
        let pdf = try await Self.longPDF()
        let model = try PDFDocReader.read(pdf)
        let heads = model.headings()
        XCTAssertEqual(heads.first?.1, "Annual Report")
        XCTAssertEqual(heads.first?.0, 1)
        XCTAssertTrue(heads.contains { $0.1 == "Section 3" && $0.0 == 2 }, "\(heads)")
        XCTAssertEqual(heads.filter { $0.0 == 2 }.count, 6)
        XCTAssertTrue(model.lists().contains { $0.items.count == 2 }, "bullets become a list")
        XCTAssertEqual(model.allImages.count, 1, "embedded image extracted")
        // Paragraphs are joined lines, not one block per line.
        let paras = model.blocks.compactMap { b -> String? in if case .paragraph(let i) = b { return i.plainText }; return nil }
        XCTAssertTrue(paras.contains { $0.hasPrefix("Paragraph 1 of section 1.") && $0.hasSuffix("second line of text.") }, "\(paras.prefix(3))")
        XCTAssertTrue(model.blocks.contains { if case .paragraph(let i) = $0 { return i.contains(.strong([.text("Important")])) }; return false })
        // Full engine route to DOCX.
        let out = try await runEngine(OOXMLEngine(), pdf, from: Formats.pdf, to: Formats.docx)
        let back = try DOCXReader.read(out[0])
        XCTAssertEqual(back.headings().first?.1, "Annual Report")
    }

    /// An image-only "scan": text rasterised into a bitmap that fills the page.
    static func scannedPDF() throws -> URL {
        let w = 1190, h = 1684  // A4 at 144 dpi
        let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        cg.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
        func draw(_ s: String, _ size: CGFloat, _ y: CGFloat, bold: Bool = false) {
            let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
            (s as NSString).draw(at: NSPoint(x: 140, y: y), withAttributes: [.font: font, .foregroundColor: NSColor.black])
        }
        draw("Scanned Report", 56, CGFloat(h) - 260, bold: true)
        draw("The quarterly numbers improved across every region this year.", 26, CGFloat(h) - 420)
        draw("Shipping times fell while customer satisfaction kept rising.", 26, CGFloat(h) - 520)
        NSGraphicsContext.restoreGraphicsState()
        let url = try tempDir("scan").appendingPathComponent("scan.pdf")
        var box = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        ctx.beginPDFPage(nil)
        ctx.draw(cg.makeImage()!, in: box)
        ctx.endPDFPage()
        ctx.closePDF()
        return url
    }

    func testScannedPDFIsRecognisedWithVision() throws {
        let pdf = try Self.scannedPDF()
        XCTAssertEqual(PDFDocument(url: pdf)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", "", "fixture has no text layer")
        let model = try PDFDocReader.read(pdf)
        XCTAssertEqual(model.headings().first?.1, "Scanned Report", "\(model.blocks)")
        XCTAssertTrue(model.text.contains("quarterly numbers improved"), model.text)
        XCTAssertTrue(model.allImages.isEmpty, "the page scan itself isn't kept as a figure")
    }

    func testPDFToPPTXMakesOneSlidePerPage() async throws {
        let pdf = try await Self.longPDF()
        let pages = PDFDocument(url: pdf)!.pageCount
        let out = try await runEngine(OOXMLEngine(), pdf, from: Formats.pdf, to: Formats.pptx)
        let zip = try ZipReader(url: out[0])
        let pres = try XMLTree.parse(zip.data("ppt/presentation.xml"))
        XCTAssertEqual(pres.all("sldId").count, pages)
        let sz = try XCTUnwrap(pres.first("sldSz"))
        let ratio = Double(sz["cx"]!)! / Double(sz["cy"]!)!
        XCTAssertEqual(ratio, 595.28 / 841.89, accuracy: 0.01, "slide follows the page aspect")
        for k in 1...pages {
            XCTAssertTrue(zip.contains("ppt/slides/slide\(k).xml"))
            XCTAssertTrue(zip.contains("ppt/media/image\(k).jpeg"))
            XCTAssertNoThrow(try XMLTree.parse(zip.data("ppt/slides/slide\(k).xml")))
        }
        for part in ["ppt/slideMasters/slideMaster1.xml", "ppt/slideLayouts/slideLayout1.xml", "ppt/theme/theme1.xml", "[Content_Types].xml"] {
            XCTAssertNoThrow(try XMLTree.parse(zip.data(part)), part)
        }
    }

    func testPDFTableExtractionIsUsable() async throws {
        let rows: [[String]] = [["Region", "Q1", "Q2", "Total"], ["North", "1,200", "1,350", "2,550"], ["South", "980", "1,010", "1,990"],
                                ["East", "1,500", "1,620", "3,120"], ["West", "720", "800", "1,520"]]
        let table = DocTable(rows: rows.enumerated().map { k, r in DocTableRow(r.map { DocTableCell(inlines: [.text($0)]) }, isHeader: k == 0) })
        let doc = DocModel(blocks: [.heading(level: 1, [.text("Sales")]), .paragraph([.text("Figures by region.")]), .table(table)])
        let pdf = try tempDir("tbl").appendingPathComponent("t.pdf")
        try await DocumentIO.write(doc, format: Formats.pdf, to: pdf, options: .init())
        let wb = try PDFTableExtractor.workbook(pdf)
        let grid = wb.sheets[0].rows.filter { $0.count >= 4 }
        XCTAssertEqual(grid.count, 5, "\(wb.sheets[0].rows)")
        guard grid.count == 5 else { return }
        XCTAssertEqual(grid[0].map(\.text), ["Region", "Q1", "Q2", "Total"])
        XCTAssertEqual(grid[1], [.string("North"), .number(1200), .number(1350), .number(2550)])
        XCTAssertEqual(grid[4][3], .number(1520))
        XCTAssertEqual(wb.sheets[0].rows.first?.first?.text, "Sales", "text outside the table is kept as rows")
        // PDF → document reconstruction gets a real table too (cells keep their original text).
        let model = try PDFDocReader.read(pdf)
        XCTAssertEqual(model.headings().first?.1, "Sales")
        let t = try XCTUnwrap(model.firstTable(), "\(model.blocks)")
        XCTAssertEqual(t.rows.count, 5)
        XCTAssertEqual(t.columnCount, 4)
        XCTAssertTrue(t.rows[0].isHeader)
        XCTAssertEqual(t.rows[1].cells.map { $0.blocks.map(\.plainText).joined() }, ["North", "1,200", "1,350", "2,550"])
        XCTAssertFalse(model.text.contains("Region North"), "cell text isn't duplicated as paragraphs")
        XCTAssertTrue(model.blocks.contains(.paragraph([.text("Figures by region.")])))
    }
}
