import AppKit
import XCTest
@testable import HaloCore

/// Writers produce valid files that our readers *and* AppKit's importers read back
/// with structure intact; readers handle the generated fixtures.
final class DocumentFormatTests: XCTestCase {
    private func write(_ doc: DocModel, _ format: FormatID) async throws -> URL {
        let url = try tempDir("w").appendingPathComponent("doc").appendingPathExtension(Formats.extension(for: format))
        try await DocumentIO.write(doc, format: format, to: url, options: OptionValues([OptionKey.pageSize: .string("a4")]))
        return url
    }

    // MARK: DOCX

    func testDOCXWriterPackageIsWellFormed() async throws {
        let url = try await write(richDoc(), Formats.docx)
        let zip = try ZipReader(url: url)
        for part in ["[Content_Types].xml", "_rels/.rels", "word/document.xml", "word/styles.xml", "word/numbering.xml",
                     "word/_rels/document.xml.rels", "docProps/core.xml", "word/media/image1.png"] {
            XCTAssertTrue(zip.contains(part), part)
            if part.hasSuffix(".xml") || part.hasSuffix(".rels") { XCTAssertNoThrow(try XMLTree.parse(zip.data(part)), part) }
        }
        let rels = try zip.text("word/_rels/document.xml.rels")
        XCTAssertTrue(rels.contains("https://example.org/") && rels.contains("TargetMode=\"External\""))
        XCTAssertTrue(try zip.text("word/document.xml").contains("<w:tblHeader/>"))
    }

    func testDOCXRoundTripThroughOurReader() async throws {
        let url = try await write(richDoc(), Formats.docx)
        let back = try DOCXReader.read(url)
        XCTAssertEqual(back.metadata.title, "Rich Doc")
        XCTAssertEqual(back.metadata.author, "Tester")
        XCTAssertEqual(back.headings().map(\.0), [1, 2, 2])
        XCTAssertEqual(back.headings().map(\.1), ["Main Title", "Lists", "Table"])
        let lists = back.lists()
        XCTAssertEqual(lists.count, 2)
        XCTAssertFalse(lists[0].ordered)
        XCTAssertEqual(lists[0].items.count, 2)
        guard case .list(let nested)? = lists[0].items[1].blocks.last else { return XCTFail("nested list") }
        XCTAssertTrue(nested.ordered)
        XCTAssertEqual(lists[1].start, 3)
        let t = try XCTUnwrap(back.firstTable())
        XCTAssertEqual(t.rows.count, 3)
        XCTAssertTrue(t.rows[0].isHeader)
        XCTAssertEqual(back.allImages.count, 1)
        XCTAssertEqual(back.allImages.first.flatMap { $0.width }.map { Int($0.rounded()) }, 60)
        guard case .paragraph(let p) = back.blocks[1] else { return XCTFail("paragraph") }
        XCTAssertTrue(p.contains(.link(url: "https://example.org/", [.text("link")])))
        XCTAssertTrue(p.contains(.strong([.text("bold")])))
        XCTAssertTrue(p.contains(.emphasis([.text("italic")])))
        XCTAssertTrue(p.contains(.code("code()")))
        XCTAssertTrue(back.blocks.contains { if case .codeBlock = $0 { return true }; return false })
        XCTAssertTrue(back.blocks.contains { if case .blockquote = $0 { return true }; return false })
    }

    func testDOCXOpensInAppKitWithStructure() async throws {
        let url = try await write(richDoc(), Formats.docx)
        let s = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.officeOpenXML], documentAttributes: nil)
        XCTAssertTrue(s.string.contains("Main Title"))
        var hasLink = false, hasTable = false, hasList = false, bigHeading = false
        s.enumerateAttributes(in: NSRange(location: 0, length: s.length)) { a, r, _ in
            if a[.link] != nil { hasLink = true }
            if let p = a[.paragraphStyle] as? NSParagraphStyle {
                if p.textBlocks.contains(where: { $0 is NSTextTableBlock }) { hasTable = true }
                if !p.textLists.isEmpty { hasList = true }
            }
            if (s.string as NSString).substring(with: r).contains("Main Title"), let f = a[.font] as? NSFont, f.pointSize >= 18 { bigHeading = true }
        }
        // AppKit's DOCX importer drops hyperlinks in every form (w:hyperlink, fldSimple, complex fields;
        // verified with textutil on macOS 27), so links are checked with our reader above instead.
        _ = hasLink
        XCTAssertTrue(hasTable, "table survives AppKit import")
        XCTAssertTrue(hasList, "list survives AppKit import")
        XCTAssertTrue(bigHeading, "Heading 1 style renders large")
    }

    func testDOCXFixtureAndTextutilHeuristics() throws {
        let doc = try DOCXReader.read(try DocsFixtures.url("sample.docx"))
        XCTAssertEqual(doc.metadata.title, "Halo Sample Document")
        XCTAssertEqual(doc.headings().map(\.1), ["Halo Sample Document", "Lists", "Table", "After the break"])
        XCTAssertEqual(doc.lists().count, 2)
        XCTAssertTrue(doc.lists()[1].ordered)
        XCTAssertEqual(doc.firstTable()?.rows.count, 3)
        XCTAssertEqual(doc.allImages.count, 1)
        XCTAssertTrue(doc.blocks.contains(.pageBreak))
        XCTAssertTrue(doc.text.contains("struck"))
        // textutil writes headings as big bold runs and bullets as "\t•\t" text: both recovered.
        let tu = try DOCXReader.read(try DocsFixtures.url("edge-textutil.docx"))
        XCTAssertTrue(tu.headings().contains { $0.1 == "Halo HTML Sample" }, "\(tu.headings())")
        XCTAssertFalse(tu.lists().isEmpty, "marker-text bullets become a list")
        XCTAssertFalse(tu.text.contains("•\t"))
    }

    // MARK: ODT

    func testODTRoundTripAndPackageRules() async throws {
        let url = try await write(richDoc(), Formats.odt)
        let zip = try ZipReader(url: url)
        XCTAssertEqual(zip.entries.first?.path, "mimetype")
        XCTAssertEqual(zip.entries.first?.method, 0)
        XCTAssertEqual(try zip.text("mimetype"), "application/vnd.oasis.opendocument.text")
        for p in ["content.xml", "styles.xml", "meta.xml", "META-INF/manifest.xml"] { XCTAssertNoThrow(try XMLTree.parse(zip.data(p)), p) }
        let back = try ODTReader.read(url)
        XCTAssertEqual(back.metadata.title, "Rich Doc")
        XCTAssertEqual(back.headings().map(\.1), ["Main Title", "Lists", "Table"])
        XCTAssertEqual(back.lists().count, 2)
        XCTAssertEqual(back.lists()[1].start, 3)
        XCTAssertTrue(back.lists()[1].ordered)
        XCTAssertEqual(back.firstTable()?.rows.first?.isHeader, true)
        XCTAssertEqual(back.allImages.count, 1)
        // AppKit reads our ODT too.
        let s = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.openDocument], documentAttributes: nil)
        XCTAssertTrue(s.string.contains("Quoted words."))
    }

    func testODTFixtureFromTextutil() throws {
        let doc = try ODTReader.read(try DocsFixtures.url("sample.odt"))
        XCTAssertTrue(doc.text.contains("Ünïcødé café"))
        XCTAssertNotNil(doc.firstTable())
        XCTAssertFalse(doc.lists().isEmpty)
    }

    // MARK: HTML, RTF, RTFD, DOC, web archive, clipping

    func testHTMLReaderMapsSemantics() throws {
        let doc = try DocumentIO.read(try DocsFixtures.url("sample.html"), format: Formats.html)
        XCTAssertEqual(doc.metadata.title, "Halo HTML Sample")
        XCTAssertEqual(doc.metadata.author, "Halo Fixtures")
        XCTAssertEqual(doc.metadata.language, "en")
        XCTAssertEqual(doc.headings().map(\.0), [1, 2, 2])
        XCTAssertEqual(doc.lists().count, 2)
        XCTAssertEqual(doc.firstTable()?.rows.count, 3)
        XCTAssertEqual(doc.allImages.first?.data != nil, true)
        XCTAssertTrue(doc.blocks.contains { if case .codeBlock = $0 { return true }; return false })
        XCTAssertTrue(doc.blocks.contains { if case .blockquote = $0 { return true }; return false })
        // Malformed HTML still parses; scripts never leak into text.
        let messy = HTMLReader.read("<p>one<p>two <b>bold<script>alert(1)</script></b><ul><li>x</ul>", baseURL: nil)
        XCTAssertEqual(messy.text.contains("alert"), false)
        XCTAssertTrue(messy.text.contains("two"))
    }

    func testHTMLWriterIsStandaloneAndSafe() throws {
        var doc = richDoc()
        doc.blocks.append(.paragraph([.link(url: "javascript:alert(1)", [.text("bad")])]))
        let html = HTMLWriter(flavor: .web).document(doc)
        XCTAssertTrue(html.contains("data:image/png;base64,"))
        XCTAssertFalse(html.contains("javascript:"))
        XCTAssertTrue(html.contains("prefers-color-scheme: dark"))
        let back = HTMLReader.read(html, baseURL: nil)
        XCTAssertEqual(back.headings().map(\.1), ["Main Title", "Lists", "Table"])
        XCTAssertEqual(back.firstTable()?.rows.first?.isHeader, true)
        XCTAssertEqual(back.allImages.count, 1)
    }

    func testRTFAndRTFDThroughAppKit() async throws {
        let rtf = try await write(richDoc(), Formats.rtf)
        let back = try AttributedReader.read(rtf, format: Formats.rtf)
        XCTAssertEqual(back.headings().first?.1, "Main Title")
        XCTAssertEqual(back.lists().count, 2, "\(back.blocks)")
        XCTAssertNotNil(back.firstTable())
        XCTAssertTrue(back.blocks.contains { if case .paragraph(let i) = $0 { return i.contains(.link(url: "https://example.org/", [.text("link")])) }; return false })
        let rtfd = try await write(richDoc(), Formats.rtfd)
        XCTAssertTrue(FileManager.default.fileExists(atPath: rtfd.appendingPathComponent("TXT.rtf").path))
        let backD = try AttributedReader.read(rtfd, format: Formats.rtfd)
        XCTAssertEqual(backD.allImages.count, 1, "RTFD keeps the image")
    }

    func testFixturesFromTextutilAndPlists() throws {
        let doc = try AttributedReader.read(try DocsFixtures.url("sample.doc"), format: Formats.doc)
        XCTAssertTrue(doc.text.contains("Banana"))
        XCTAssertNotNil(doc.firstTable())
        let rtfd = try AttributedReader.read(try DocsFixtures.url("sample.rtfd"), format: Formats.rtfd)
        XCTAssertEqual(rtfd.allImages.count, 1)
        XCTAssertFalse(rtfd.lists().isEmpty)
        let web = try WebArchiveReader.read(try DocsFixtures.url("sample.webarchive"))
        XCTAssertEqual(web.headings().first?.1, "Halo HTML Sample")
        XCTAssertNotNil(web.firstTable())
        let clip = try TextClippingReader.read(try DocsFixtures.url("sample.textclipping"))
        XCTAssertTrue(clip.text.contains("Clipped text with"))
        XCTAssertTrue(clip.blocks.contains { if case .paragraph(let i) = $0 { return i.contains { if case .strong = $0 { return true }; return false } }; return false }, "RTF flavour preferred")
    }

    // MARK: EPUB

    func testEPUBWriterStructure() async throws {
        var doc = richDoc()
        doc.blocks += [.heading(level: 1, [.text("Second Chapter")]), .heading(level: 2, [.text("Part A")]), .paragraph([.text("More.")])]
        let url = try await write(doc, Formats.epub)
        try Self.validateEPUB(url, expectChapters: 2)
        let back = try EPUBReader.read(url)
        XCTAssertEqual(back.metadata.title, "Rich Doc")
        XCTAssertEqual(back.metadata.language, "en")
        XCTAssertEqual(back.headings().map(\.1), ["Main Title", "Lists", "Table", "Second Chapter", "Part A"])
        XCTAssertEqual(back.allImages.count, 1)
        XCTAssertNotNil(back.firstTable())
    }

    /// OCF/OPF structural checks (what epubcheck would flag first).
    static func validateEPUB(_ url: URL, expectChapters: Int? = nil) throws {
        let zip = try ZipReader(url: url)
        XCTAssertEqual(zip.entries.first?.path, "mimetype")
        XCTAssertEqual(zip.entries.first?.method, 0, "mimetype must be stored")
        XCTAssertEqual(try zip.text("mimetype"), "application/epub+zip")
        let pkg = try EPUBReader.package(zip)
        for (_, item) in pkg.manifest {
            XCTAssertTrue(zip.contains(item.href), "manifest item missing: \(item.href)")
            if item.mediaType == "application/xhtml+xml" { XCTAssertNoThrow(try XMLTree.parse(zip.data(item.href)), item.href) }
        }
        for id in pkg.spine { XCTAssertNotNil(pkg.manifest[id], "spine idref \(id) not in manifest") }
        XCTAssertTrue(pkg.manifest.values.contains { $0.properties.contains("nav") }, "EPUB 3 needs a nav document")
        XCTAssertNotNil(pkg.title)
        if let n = expectChapters { XCTAssertEqual(pkg.spine.count, n) }
        let opf = try XMLTree.parse(zip.data(pkg.opfPath))
        XCTAssertEqual(opf["version"], "3.0")
        XCTAssertNotNil(opf.first("identifier"))
        XCTAssertTrue(opf.all("meta").contains { $0["property"] == "dcterms:modified" })
        XCTAssertEqual(opf.first("spine")?["toc"], "ncx")
    }

    func testEPUBFixtureReadsInSpineOrder() throws {
        let doc = try EPUBReader.read(try DocsFixtures.url("sample.epub"))
        XCTAssertEqual(doc.metadata.title, "Halo Sample Book")
        XCTAssertEqual(doc.metadata.author, "Halo Fixtures")
        XCTAssertEqual(doc.headings().map(\.1), ["Chapter One", "Chapter Two"], "nav (linear=no) is skipped")
        XCTAssertEqual(doc.allImages.count, 1)
        XCTAssertNotNil(doc.firstTable())
        XCTAssertTrue(doc.blocks.contains(.pageBreak))
    }

    func testTXTWriterUsesBulletsAndTabs() {
        let txt = PlainTextWriter().write(richDoc())
        XCTAssertTrue(txt.contains("• Alpha"))
        XCTAssertTrue(txt.contains("3. Third"))
        XCTAssertTrue(txt.contains("Ada\t10"))
        XCTAssertTrue(txt.contains("link <https://example.org/>"))
        XCTAssertFalse(txt.contains("**"))
    }
}
