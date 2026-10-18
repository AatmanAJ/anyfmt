import XCTest
import PDFKit
@testable import HaloCore

/// Tools 25–26 end to end with PDFKit.
final class PDFToolsTests: XCTestCase {
    private func doc(_ u: URL) throws -> PDFDocument { try XCTUnwrap(PDFDocument(url: u)) }

    func testMergeReorderRotateDelete() async throws {
        let a = try await MediaFixtures.url("pages.pdf"), b = try await MediaFixtures.url("extra.pdf")
        // Page 3 of A, page 1 of A rotated, page 2 of B. A's page 2 and B's page 1 are deleted.
        let (out, _) = try await runTool(OrganizePDFRunner(), [a, b], ["order": .string("1:3,1:1:90,2:2")])
        let d = try doc(try XCTUnwrap(out.files.first))
        XCTAssertEqual(d.pageCount, 3)
        XCTAssertTrue(d.page(at: 0)?.string?.contains("Halo fixture page 3") ?? false)
        XCTAssertTrue(d.page(at: 1)?.string?.contains("Halo fixture page 1") ?? false, "text stays text")
        XCTAssertEqual(d.page(at: 1)?.rotation, 90)
        XCTAssertTrue(d.page(at: 2)?.string?.contains("Extra page 2") ?? false)
        // Bookmarks: one entry per input, A's kept chapters nested.
        let root = try XCTUnwrap(d.outlineRoot)
        XCTAssertEqual(root.numberOfChildren, 2)
        XCTAssertEqual(root.child(at: 0)?.label, "pages")
        XCTAssertEqual(root.child(at: 0)?.numberOfChildren, 2, "chapter 2's page was deleted")
    }

    func testMergeAllWhenOrderEmpty() async throws {
        let a = try await MediaFixtures.url("pages.pdf"), b = try await MediaFixtures.url("extra.pdf")
        let (out, _) = try await runTool(OrganizePDFRunner(), [a, b], [:])
        XCTAssertEqual(try doc(try XCTUnwrap(out.files.first)).pageCount, 5)
    }

    func testSingleInputKeepsOutline() async throws {
        let a = try await MediaFixtures.url("pages.pdf")
        let (out, _) = try await runTool(OrganizePDFRunner(), [a], ["order": .string("1:2,1:1")])
        let d = try doc(try XCTUnwrap(out.files.first))
        XCTAssertEqual(d.outlineRoot?.numberOfChildren, 2)
        XCTAssertEqual(d.outlineRoot?.child(at: 0)?.label, "Chapter 1")
        XCTAssertEqual(d.outlineRoot?.child(at: 0)?.destination?.page.map { d.index(for: $0) }, 1)
    }

    func testSplitIntoSinglePages() async throws {
        let a = try await MediaFixtures.url("pages.pdf")
        let (out, _) = try await runTool(OrganizePDFRunner(), [a], ["split": .bool(true), "order": .string("1:3-1")], base: "pages-organized")
        XCTAssertEqual(out.files.map(\.lastPathComponent), ["pages-organized-001.pdf", "pages-organized-002.pdf", "pages-organized-003.pdf"])
        XCTAssertTrue(try doc(out.files[0]).string?.contains("page 3") ?? false)
        XCTAssertEqual(try doc(out.files[2]).pageCount, 1)
    }

    func testBadOrderIsRejected() async throws {
        let a = try await MediaFixtures.url("pages.pdf")
        do {
            _ = try await runTool(OrganizePDFRunner(), [a], ["order": .string("1:9")])
            XCTFail("expected invalid option")
        } catch let e as ConversionError {
            guard case .invalidOption = e else { return XCTFail("\(e)") }
        }
    }

    func testMetadataPolicy() async throws {
        let a = try await MediaFixtures.url("pages.pdf")
        let dir = try makeOutputDirectory()
        let authored = dir.appendingPathComponent("authored.pdf")
        let d = try doc(a)
        d.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Report", PDFDocumentAttribute.authorAttribute: "Jo"]
        XCTAssertTrue(d.write(to: authored))
        let (priv, _) = try await runTool(OrganizePDFRunner(), [authored], [:], metadata: .stripPrivate)
        let p = try doc(try XCTUnwrap(priv.files.first)).documentAttributes ?? [:]
        XCTAssertEqual(p[PDFDocumentAttribute.titleAttribute] as? String, "Report")
        XCTAssertNil(p[PDFDocumentAttribute.authorAttribute])
    }

    func testCompressShrinksImagesKeepsText() async throws {
        let a = try await MediaFixtures.url("pages.pdf")
        let (out, _) = try await runTool(CompressPDFRunner(), [a], [OptionKey.quality: .int(60), OptionKey.dpi: .string("150")])
        let u = try XCTUnwrap(out.files.first)
        let before = MediaRun.fileSize(a), after = MediaRun.fileSize(u)
        XCTAssertLessThan(Double(after), Double(before) * 0.25, "\(before) → \(after)")
        let d = try doc(u)
        XCTAssertEqual(d.pageCount, 3)
        XCTAssertTrue(d.string?.contains("Halo fixture page 2 searchable text") ?? false, "text is still vector text")
        XCTAssertEqual(d.outlineRoot?.numberOfChildren, 3, "bookmarks survive")
    }

    func testCompressTargetSize() async throws {
        let a = try await MediaFixtures.url("pages.pdf")
        let target = 400_000
        let (out, _) = try await runTool(CompressPDFRunner(), [a], [OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(target)])
        let size = MediaRun.fileSize(try XCTUnwrap(out.files.first))
        XCTAssertLessThanOrEqual(size, Int64(target))
        XCTAssertGreaterThan(size, Int64(target) / 8, "picks the gentlest setting that fits, not the harshest")
    }

    func testCompressTextOnlyPDFExplainsItself() async throws {
        let t = try await MediaFixtures.url("text.pdf")
        do {
            _ = try await runTool(CompressPDFRunner(), [t], [:])
            XCTFail("expected a human error")
        } catch let e as ConversionError {
            XCTAssertTrue(e.errorDescription?.contains("already compact") ?? false, e.errorDescription ?? "")
        }
    }
}
