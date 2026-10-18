import XCTest
import PDFKit
import CoreText
@testable import HaloCore

final class PDFKitEngineTests: XCTestCase {
    typealias S = ImageTestSupport
    let engine = PDFKitEngine()

    /// A4 pages with a line of text each; optional image-only (scanned) page.
    private func makePDF(_ dir: URL, pages: Int, name: String = "doc.pdf", rotateSecond: Bool = false, scanned: Bool = false) throws -> URL {
        let url = dir.appendingPathComponent(name)
        var box = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let ctx = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        let font = CTFontCreateWithName("Helvetica" as CFString, 40, nil)
        for i in 1...pages {
            ctx.beginPDFPage(nil)
            if scanned {
                let words = S.image(1000, 200, alpha: false) { c in
                    c.setFillColor(S.color(1, 1, 1)); c.fill(CGRect(x: 0, y: 0, width: 1000, height: 200))
                    let s = NSAttributedString(string: "Scanned hello", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 96, nil)])
                    c.textPosition = CGPoint(x: 40, y: 60)
                    CTLineDraw(CTLineCreateWithAttributedString(s), c)
                }
                ctx.draw(words, in: CGRect(x: 40, y: 400, width: 500, height: 100))
            } else {
                let s = NSAttributedString(string: "Page \(i) text", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                ctx.textPosition = CGPoint(x: 72, y: 700)
                CTLineDraw(CTLineCreateWithAttributedString(s), ctx)
            }
            ctx.endPDFPage()
        }
        ctx.closePDF()
        if rotateSecond, let doc = PDFDocument(url: url), let p = doc.page(at: 1) {
            p.rotation = 90
            XCTAssertTrue(doc.write(to: url))
        }
        return url
    }

    // MARK: Page ranges

    func testPageRangeParser() throws {
        XCTAssertEqual(try PageRange.parse("", pageCount: 4), [1, 2, 3, 4])
        XCTAssertEqual(try PageRange.parse("1-3,5", pageCount: 9), [1, 2, 3, 5])
        XCTAssertEqual(try PageRange.parse(" 5, 1 - 2 ,2", pageCount: 9), [1, 2, 5])
        XCTAssertEqual(try PageRange.parse("7-", pageCount: 9), [7, 8, 9])
        XCTAssertEqual(try PageRange.parse("-2", pageCount: 9), [1, 2])
        XCTAssertEqual(try PageRange.parse("3-100", pageCount: 4), [3, 4], "clamped to the last page")
        XCTAssertEqual(try PageRange.parse("10", pageCount: 4), [], "past the end")
        XCTAssertEqual(try PageRange.parse("all", pageCount: 2), [1, 2])
        XCTAssertThrowsError(try PageRange.parse("0", pageCount: 4))
        XCTAssertThrowsError(try PageRange.parse("3-1", pageCount: 4))
        XCTAssertThrowsError(try PageRange.parse("a-b", pageCount: 4))
        XCTAssertThrowsError(try PageRange.parse("1-2-3", pageCount: 4))
    }

    // MARK: Rendering

    func testDPIControlsPixelSize() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 1)
        for (dpi, w, h) in [(72, 595, 842), (150, 1240, 1754), (300, 2480, 3508)] {
            let out = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.png, options: [OptionKey.dpi: .string(String(dpi))],
                                          in: dir.appendingPathComponent("\(dpi)"))
            XCTAssertEqual(out.count, 1)
            XCTAssertEqual(out[0].lastPathComponent, "out.png", "one-page PDFs keep the plain name")
            let img = try XCTUnwrap(S.decode(out[0]))
            XCTAssertEqual(img.width, w, accuracy: 1); XCTAssertEqual(img.height, h, accuracy: 1)
            XCTAssertEqual(S.properties(out[0])["DPIWidth"] as? Double ?? 0, Double(dpi), accuracy: 0.5)
        }
    }

    func testAllPagesAndRangesProduceNumberedFiles() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 3)
        let all = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.jpg, options: [OptionKey.dpi: .string("72")], in: dir.appendingPathComponent("all"))
        XCTAssertEqual(all.map(\.lastPathComponent), ["out-001.jpg", "out-002.jpg", "out-003.jpg"])
        let some = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.png, options: [OptionKey.dpi: .string("72"), OptionKey.pages: .string("1,3")],
                                       in: dir.appendingPathComponent("some"))
        XCTAssertEqual(some.map(\.lastPathComponent), ["out-001.png", "out-003.png"])
        for u in all + some { XCTAssertNotNil(S.decode(u)) }
    }

    func testJPGPagesHaveWhiteBackground() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 1)
        let out = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.jpg, options: [OptionKey.dpi: .string("72")])
        S.assertColor(S.pixel(try XCTUnwrap(S.decode(out[0])), 10, 10), [255, 255, 255, 255], tolerance: 3)
    }

    func testRotatedPageRendersLandscape() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 2, rotateSecond: true)
        let out = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.png, options: [OptionKey.dpi: .string("72"), OptionKey.pages: .string("2")])
        let img = try XCTUnwrap(S.decode(out[0]))
        XCTAssertGreaterThan(img.width, img.height)
    }

    func testEveryPageImageTargetDecodes() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 2)
        for to in PDFKitEngine.imageOutputs {
            guard engine.isAvailable(Capability(Formats.pdf, to, engine.id)) || (to == Formats.webp && S.hasFFmpeg) else { continue }
            let out = try await S.convert(engine, pdf, from: Formats.pdf, to: to, options: [OptionKey.dpi: .string("72")],
                                          in: dir.appendingPathComponent(to.rawValue))
            XCTAssertEqual(out.count, 2, "\(to)")
            for u in out {
                XCTAssertEqual(u.pathExtension, Formats.extension(for: to))
                XCTAssertEqual(S.decode(u)?.width ?? 0, 595, accuracy: 1, "\(to)")
            }
        }
    }

    func testInvalidPageRangeIsAHumanError() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 2)
        for bad in ["0", "5", "x"] {
            do {
                _ = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.png, options: [OptionKey.pages: .string(bad)],
                                        in: dir.appendingPathComponent("bad\(bad)"))
                XCTFail("\(bad) should fail")
            } catch ConversionError.invalidOption {}
        }
    }

    // MARK: Text

    func testPDFToTextSeparatesPagesWithFormFeeds() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 3)
        let out = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.txt)
        let text = try String(contentsOf: out[0], encoding: .utf8)
        let pages = text.components(separatedBy: "\u{0C}")
        XCTAssertEqual(pages.count, 3)
        for (i, p) in pages.enumerated() { XCTAssertTrue(p.contains("Page \(i + 1) text"), "page \(i + 1): \(p)") }
    }

    func testScannedPageIsReadWithOCR() async throws {
        let dir = try S.tempDir()
        let pdf = try makePDF(dir, pages: 1, scanned: true)
        XCTAssertTrue((PDFDocument(url: pdf)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "no text layer")
        let out = try await S.convert(engine, pdf, from: Formats.pdf, to: Formats.txt)
        let text = try String(contentsOf: out[0], encoding: .utf8)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("scanned hello"), "OCR got: \(text)")
    }

    func testPasswordProtectedPDFExplainsItself() async throws {
        let dir = try S.tempDir()
        let plain = try makePDF(dir, pages: 1)
        let locked = dir.appendingPathComponent("locked.pdf")
        let doc = try XCTUnwrap(PDFDocument(url: plain))
        XCTAssertTrue(doc.write(to: locked, withOptions: [.userPasswordOption: "secret", .ownerPasswordOption: "owner"]))
        do {
            _ = try await S.convert(engine, locked, from: Formats.pdf, to: Formats.png)
            XCTFail("expected an error")
        } catch let e as ConversionError {
            XCTAssertTrue(e.errorDescription?.contains("password") ?? false, e.errorDescription ?? "")
        }
    }
}
