import XCTest
@testable import HaloCore

/// Independent consumer check: Apple's own Office Quick Look generator (the one
/// Finder uses) must render what our DOCX / XLSX / PPTX writers produce.
final class OfficeInteropTests: XCTestCase {
    private func preview(_ file: URL) async throws -> String {
        let dir = try tempDir("qlv")
        let url = try await QuickLookEngine.preview(file, into: dir)
        return TextDecoding.decode(try Data(contentsOf: url))
    }

    override func setUp() async throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: QuickLookEngine.qlmanage.path), "qlmanage not available")
    }

    func testQuickLookRendersOurDOCX() async throws {
        let url = try tempDir("ql").appendingPathComponent("rich.docx")
        try await DocumentIO.write(richDoc(), format: Formats.docx, to: url, options: .init())
        let html = try await preview(url)
        XCTAssertTrue(html.contains("Main Title"))
        XCTAssertTrue(html.contains("<table"), "table rendered")
        XCTAssertTrue(html.contains("<img"), "image rendered")
        XCTAssertTrue(html.contains("Beta one"), "nested list item rendered")
    }

    func testQuickLookRendersOurXLSX() async throws {
        let wb = try SheetIO.read(try DocsFixtures.url("sample.json"), format: Formats.json)
        let url = try tempDir("ql").appendingPathComponent("t.xlsx")
        try XLSXWriter().write(wb).write(to: url)
        let html = try await preview(url)
        XCTAssertTrue(html.contains("Helsinki"))
        XCTAssertTrue(html.contains("Grace"))
        XCTAssertTrue(html.contains("2023-05-01"), "date cell shown with our ISO format")
    }

    /// Keeps the BIFF8 fixture writer honest: Apple's Office generator must accept it.
    func testQuickLookAcceptsTheXLSFixture() async throws {
        let html = try await preview(try DocsFixtures.url("sample.xls"))
        XCTAssertTrue(html.contains("Attachment") || html.contains("from formula"), "Quick Look rendered the workbook")
        let dir = try tempDir("qlx")
        let url = try await QuickLookEngine.preview(try DocsFixtures.url("sample.xls"), into: dir)
        let all = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "html" }.map { TextDecoding.decode((try? Data(contentsOf: $0)) ?? Data()) }.joined()
        XCTAssertTrue(all.contains("from formula"))
        XCTAssertTrue(all.contains("2024-03-16"), "custom date format applied")
    }

    func testQuickLookRendersOurPPTX() async throws {
        let pdf = try await PDFRouteTests.longPDF()
        let out = try await runEngine(OOXMLEngine(), pdf, from: Formats.pdf, to: Formats.pptx)
        let html = try await preview(out[0])
        let slides = html.components(separatedBy: "class=\"slide\"").count - 1
        XCTAssertEqual(slides, PDFKitPageCount(pdf), "every slide renders")
        XCTAssertTrue(html.contains("<img"), "page pictures render")
    }
}
