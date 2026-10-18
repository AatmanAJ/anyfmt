import XCTest
import CoreGraphics
import CoreImage
import ImageIO
import PDFKit
import UniformTypeIdentifiers
@testable import HaloCore

final class DrawingToolTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws { dir = try G1.tempDir(name) }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func png(_ img: CGImage, _ name: String = "in.png") throws -> URL {
        try G1.write(img, to: dir.appendingPathComponent(name), type: .png)
    }

    // MARK: Annotate

    func testAnnotationsJSONRoundTrip() {
        let list = [
            Annotation(kind: .arrow, points: [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.7, y: 0.6)], color: "#FF0000", width: 0.01),
            Annotation(kind: .text, points: [CGPoint(x: 0.2, y: 0.2)], color: "#FFFFFF", text: "Hello\nworld", fontSize: 0.08),
            Annotation(kind: .freehand, points: (0..<10).map { CGPoint(x: Double($0) / 10, y: 0.5) }),
        ]
        let json = Annotation.encodeList(list)
        XCTAssertEqual(Annotation.decodeList(json), list)
        // Hand-written JSON without ids decodes too.
        let hand = Annotation.decodeList(##"[{"kind":"box","points":[[0.1,0.1],[0.5,0.5]],"color":"#00FF00","width":0.02}]"##)
        XCTAssertEqual(hand.first?.kind, .box)
        XCTAssertEqual(hand.first?.points.count, 2)
        XCTAssertEqual(Annotation.decodeList("not json"), [])
    }

    func testAnnotateDrawsAtFullResolution() async throws {
        let input = try png(G1.solid(width: 400, height: 300, r: 255, g: 255, b: 255))
        let list = [
            Annotation(kind: .box, points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.4, y: 0.4)], color: "#0000FF", width: 0.02),
            Annotation(kind: .arrow, points: [CGPoint(x: 0.5, y: 0.8), CGPoint(x: 0.9, y: 0.8)], color: "#FF0000", width: 0.03),
            Annotation(kind: .highlight, points: [CGPoint(x: 0.6, y: 0.1), CGPoint(x: 0.9, y: 0.3)], color: "#FFFF00"),
            Annotation(kind: .text, points: [CGPoint(x: 0.1, y: 0.6)], color: "#000000", text: "WWW", fontSize: 0.12),
        ]
        let out = try await G1.run(ToolIDs.annotateImage, inputs: [input],
                                   options: OptionValues(["annotations": .string(Annotation.encodeList(list))]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 400)
        let px = G1.pixels(img)
        // Box edge at x = 0.1·400 = 40, y between 30 and 120 → blue.
        let edge = G1.pixel(px, width: 400, x: 40, y: 75)
        XCTAssertGreaterThan(edge.b, 200); XCTAssertLessThan(edge.r, 80)
        // Inside the box stays white.
        XCTAssertEqual(G1.pixel(px, width: 400, x: 100, y: 75).r, 255, accuracy: 2)
        // Arrow shaft along y = 240.
        let shaft = G1.pixel(px, width: 400, x: 260, y: 240)
        XCTAssertGreaterThan(shaft.r, 200); XCTAssertLessThan(shaft.g, 80)
        // Highlight multiplies white → yellow-ish (blue channel drops, red stays).
        let hl = G1.pixel(px, width: 400, x: 300, y: 60)
        XCTAssertGreaterThan(hl.r, 230); XCTAssertLessThan(hl.b, 200)
        // Text left dark pixels in its box.
        var dark = 0
        for y in 185...225 { for x in 45...140 where G1.pixel(px, width: 400, x: x, y: y).r < 100 { dark += 1 } }
        XCTAssertGreaterThan(dark, 200)
    }

    func testHitTestFindsTopmost() {
        let a = Annotation(kind: .box, points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.5, y: 0.5)])
        let b = Annotation(kind: .ellipse, points: [CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.6, y: 0.6)])
        let size = CGSize(width: 1000, height: 800)
        XCTAssertEqual(AnnotationRenderer.hitTest([a, b], at: CGPoint(x: 0.4, y: 0.4), imageSize: size)?.id, b.id)
        XCTAssertEqual(AnnotationRenderer.hitTest([a, b], at: CGPoint(x: 0.15, y: 0.15), imageSize: size)?.id, a.id)
        XCTAssertNil(AnnotationRenderer.hitTest([a, b], at: CGPoint(x: 0.9, y: 0.9), imageSize: size))
    }

    // MARK: Redact

    private func assertRedacted(_ style: String) async throws {
        let w = 240, h = 180
        let source = G1.noise(width: w, height: h)
        let input = try png(source, "noise-\(style).png")
        let region = CGRect(x: 0.25, y: 0.3, width: 0.4, height: 0.35)
        let out = try await G1.run(ToolIDs.redactImage, inputs: [input],
                                   options: OptionValues(["style": .string(style), "regions": .string(Redactor.format([region]))]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "png")
        let before = G1.pixels(source), after = G1.pixels(try G1.decode(out[0]))
        let r = Redactor.pixelRect(region, width: w, height: h)
        var same = 0, total = 0
        for y in r.y0..<r.y1 { for x in r.x0..<r.x1 {
            let a = G1.pixel(before, width: w, x: x, y: y), b = G1.pixel(after, width: w, x: x, y: y)
            if a.r == b.r && a.g == b.g && a.b == b.b { same += 1 }
            total += 1
        } }
        XCTAssertEqual(same, 0, "\(style): \(same) of \(total) pixels kept their original value")
        // Outside the region nothing changed (PNG is lossless).
        for (x, y) in [(2, 2), (w - 3, h - 3), (r.x0 - 2, r.y0), (r.x1 + 1, r.y1 - 1)] {
            let a = G1.pixel(before, width: w, x: x, y: y), b = G1.pixel(after, width: w, x: x, y: y)
            XCTAssertEqual(a.r, b.r); XCTAssertEqual(a.g, b.g); XCTAssertEqual(a.b, b.b)
        }
    }

    func testRedactPixelate() async throws { try await assertRedacted("pixelate") }
    func testRedactBlur() async throws { try await assertRedacted("blur") }
    func testRedactSolid() async throws { try await assertRedacted("solid") }

    func testPixelateBlocksAreLarge() throws {
        let img = G1.noise(width: 300, height: 100)
        let region = CGRect(x: 0, y: 0, width: 1, height: 0.3) // a 300×30 text line
        let out = try Redactor.apply(img, regions: [region], style: .pixelate)
        let px = G1.pixels(out)
        // Blocks are at least 12 px, and a 30 px line is at most two blocks tall.
        let first = G1.pixel(px, width: 300, x: 0, y: 0)
        let inside = G1.pixel(px, width: 300, x: 11, y: 11)
        XCTAssertEqual(first.r, inside.r); XCTAssertEqual(first.g, inside.g)
        var colours = Set<Int>()
        for y in 0..<30 { for x in 0..<300 { let p = G1.pixel(px, width: 300, x: x, y: y); colours.insert(p.r << 16 | p.g << 8 | p.b) } }
        XCTAssertLessThanOrEqual(colours.count, 2 * 25, "few, large blocks")
        XCTAssertGreaterThanOrEqual(Redactor.blockSize(regionWidth: 300, regionHeight: 30, imageWidth: 300, imageHeight: 100), 12)
    }

    func testRedactWithoutRegionsFails() async throws {
        let input = try png(G1.photo())
        do {
            _ = try await G1.run(ToolIDs.redactImage, inputs: [input], in: dir)
            XCTFail("expected an error")
        } catch let e as ConversionError {
            XCTAssertFalse((e.errorDescription ?? "").isEmpty)
        }
    }

    // MARK: Backgrounds

    func testAddBackgroundPadsCanvas() async throws {
        let input = try png(G1.photo(width: 300, height: 200))
        let opts = OptionValues(["fill": .string("solid"), "color1": .string("#00FF00"), "padding": .int(10),
                                 "cornerRadius": .int(10), "shadow": .bool(false)])
        let out = try await G1.run(ToolIDs.addBackground, inputs: [input], options: opts, in: dir)
        let img = try G1.decode(out[0])
        // padding = 10 % of the longest edge (300) = 30 px per side.
        XCTAssertEqual(img.width, 360)
        XCTAssertEqual(img.height, 260)
        let px = G1.pixels(img)
        let corner = G1.pixel(px, width: 360, x: 3, y: 3)
        XCTAssertEqual(corner.g, 255, accuracy: 2); XCTAssertLessThan(corner.r, 5)
        // The subject's rounded corner shows background; its centre shows the photo.
        let roundedCorner = G1.pixel(px, width: 360, x: 31, y: 31)
        XCTAssertGreaterThan(roundedCorner.g, 240)
        let centre = G1.pixel(px, width: 360, x: 180, y: 130)
        let srcCentre = G1.pixel(G1.pixels(G1.photo(width: 300, height: 200)), width: 300, x: 150, y: 100)
        XCTAssertEqual(centre.r, srcCentre.r, accuracy: 3)
        XCTAssertEqual(BackgroundComposer.canvasSize(for: CGSize(width: 300, height: 200), style: BackdropStyle(options: opts)),
                       CGSize(width: 360, height: 260))
    }

    func testAddBackgroundGradientAndShadow() async throws {
        let input = try png(G1.photo(width: 200, height: 200))
        let out = try await G1.run(ToolIDs.addBackground, inputs: [input],
                                   options: OptionValues(["fill": .string("gradient"), "color1": .string("#FF0000"), "color2": .string("#0000FF"),
                                                          "angle": .double(90), "padding": .int(20)]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 280)
        let px = G1.pixels(img)
        let left = G1.pixel(px, width: 280, x: 2, y: 140), right = G1.pixel(px, width: 280, x: 277, y: 140)
        XCTAssertGreaterThan(left.r, right.r)
        XCTAssertGreaterThan(right.b, left.b)
    }

    func testRemoveBackgroundProducesAlpha() async throws {
        guard #available(macOS 14.0, *) else { throw XCTSkip("foreground masks need macOS 14") }
        // A bold subject on a plain backdrop.
        let w = 512, h = 512
        let ctx = try XCTUnwrap(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: G1.srgb,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        ctx.setFillColor(CGColor(srgbRed: 0.85, green: 0.86, blue: 0.88, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(srgbRed: 0.9, green: 0.2, blue: 0.1, alpha: 1)); ctx.fillEllipse(in: CGRect(x: 140, y: 120, width: 240, height: 280))
        ctx.setFillColor(CGColor(srgbRed: 0.1, green: 0.3, blue: 0.8, alpha: 1)); ctx.fill(CGRect(x: 220, y: 60, width: 80, height: 120))
        let input = try png(try XCTUnwrap(ctx.makeImage()), "subject.png")
        let out: [URL]
        do {
            out = try await G1.run(ToolIDs.removeBackground, inputs: [input], in: dir)
        } catch let e as ConversionError {
            throw XCTSkip("Vision found no subject in the synthetic image: \(e.technicalDetails)")
        }
        XCTAssertEqual(out[0].pathExtension, "png")
        XCTAssertEqual(G1.properties(out[0])[kCGImagePropertyHasAlpha as String] as? Bool, true)
        let px = G1.pixels(try G1.decode(out[0]))
        XCTAssertLessThan(G1.pixel(px, width: w, x: 10, y: 10).a, 30, "backdrop removed")
        XCTAssertGreaterThan(G1.pixel(px, width: w, x: 256, y: 250).a, 220, "subject kept")
    }

    func testPersonFallbackExplainsMacOS14() throws {
        // No person in a flat image: the macOS 13 path must explain itself.
        let img = G1.solid(width: 256, height: 256, r: 120, g: 160, b: 200)
        XCTAssertThrowsError(try SubjectMasker.cutout(img, method: .personOnly)) { error in
            guard let e = error as? ConversionError else { return XCTFail("wrong error type") }
            XCTAssertTrue((e.errorDescription ?? "").contains("macOS 14"), e.errorDescription ?? "")
        }
    }

    // MARK: Collage

    func testCollageLayouts() {
        let aspects: [CGFloat] = [1.5, 1, 0.75, 1.5, 2]
        let style = { (layout: String) in CollageStyle(options: OptionValues(["layout": .string(layout), "gap": .int(10), "width": .int(1000)])) }
        for name in ["grid", "row", "column"] {
            let l = CollageLayout.make(aspects: aspects, style: style(name))
            XCTAssertEqual(l.canvas.width, 1000, name)
            XCTAssertEqual(l.frames.count, 5)
            for (i, f) in l.frames.enumerated() {
                XCTAssertEqual(f.width / f.height, aspects[i], accuracy: 0.03, "\(name) frame \(i) must not crop")
                XCTAssertGreaterThanOrEqual(f.minX, 10); XCTAssertLessThanOrEqual(f.maxX, 990)
                for (j, g) in l.frames.enumerated() where j != i {
                    XCTAssertFalse(f.insetBy(dx: 1, dy: 1).intersects(g), "\(name) frames \(i),\(j) overlap")
                }
            }
        }
        let row = CollageLayout.make(aspects: aspects, style: style("row"))
        XCTAssertEqual(Set(row.frames.map { $0.minY }).count, 1, "one row")
        let grid = CollageLayout.make(aspects: aspects, style: style("grid"))
        XCTAssertGreaterThan(Set(grid.frames.map { $0.minY }).count, 1, "grid uses several rows")
    }

    func testCollageRunner() async throws {
        let a = try png(G1.photo(width: 300, height: 200, seed: 1), "a.png")
        let b = try png(G1.photo(width: 200, height: 300, seed: 2), "b.png")
        let c = try G1.write(G1.photo(width: 400, height: 300, seed: 3), to: dir.appendingPathComponent("c.jpg"), type: .jpeg)
        let out = try await G1.run(ToolIDs.collage, inputs: [a, b, c],
                                   options: OptionValues(["width": .int(1200), "gap": .int(20), "color1": .string("#FF00FF")]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(out[0].pathExtension, "png", "first input decides the format")
        XCTAssertEqual(img.width, 1200)
        let layout = CollageLayout.make(aspects: [1.5, 2.0 / 3.0, 4.0 / 3.0],
                                        style: CollageStyle(options: OptionValues(["width": .int(1200), "gap": .int(20)])))
        XCTAssertEqual(CGFloat(img.height), layout.canvas.height)
        let corner = G1.pixel(G1.pixels(img), width: 1200, x: 5, y: 5)
        XCTAssertEqual(corner.r, 255, accuracy: 2); XCTAssertEqual(corner.g, 0, accuracy: 2)
    }

    func testOrderOption() {
        XCTAssertEqual(OrderOption.apply("3,1", to: ["a", "b", "c"]), ["c", "a"])
        XCTAssertEqual(OrderOption.apply("", to: ["a", "b"]), ["a", "b"])
        XCTAssertEqual(OrderOption.apply("9,0,x", to: ["a", "b"]), ["a", "b"])
        XCTAssertEqual(OrderOption.apply("2,2,1", to: ["a", "b"]), ["b", "a"])
        XCTAssertEqual(OrderOption.format([2, 0, 1]), "3,1,2")
    }

    // MARK: Images → PDF

    func testImagesToPDFPagesOrderAndPassthrough() async throws {
        let wide = try G1.write(G1.photo(width: 600, height: 300, seed: 4), to: dir.appendingPathComponent("wide.jpg"), type: .jpeg, quality: 0.8)
        let tall = try png(G1.photo(width: 200, height: 400, seed: 5), "tall.png")
        let rotated = try G1.write(G1.photo(width: 400, height: 300, seed: 6), to: dir.appendingPathComponent("rot.jpg"), type: .jpeg,
                                   properties: [kCGImagePropertyOrientation as String: 6])
        let out = try await G1.run(ToolIDs.imagesToPDF, inputs: [wide, tall, rotated],
                                   options: OptionValues(["order": .string("2,1,3")]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "pdf")
        let doc = try XCTUnwrap(PDFDocument(url: out[0]))
        XCTAssertEqual(doc.pageCount, 3)
        let sizes = (0..<3).compactMap { doc.page(at: $0)?.bounds(for: .mediaBox).size }
        XCTAssertEqual(sizes[0], CGSize(width: 200, height: 400), "tall first (order 2,1,3)")
        XCTAssertEqual(sizes[1], CGSize(width: 600, height: 300))
        XCTAssertEqual(sizes[2], CGSize(width: 300, height: 400), "EXIF 6 page is upright portrait")
        let data = try Data(contentsOf: out[0])
        XCTAssertNotNil(data.range(of: Data("DCTDecode".utf8)), "JPEG data embedded as-is")
    }

    func testHEICPagesAreEmbeddedAsJPEG() async throws {
        let heic = try G1.write(G1.photo(width: 800, height: 600), to: dir.appendingPathComponent("p.heic"), type: .heic, quality: 0.8)
        let out = try await G1.run(ToolIDs.imagesToPDF, inputs: [heic], in: dir)
        let data = try Data(contentsOf: out[0])
        XCTAssertNotNil(data.range(of: Data("DCTDecode".utf8)), "HEIC re-encoded as JPEG, not raw pixels")
        XCTAssertLessThan(data.count, 800 * 600, "far smaller than uncompressed pixels")
    }

    func testImagesToPDFPaperSizes() async throws {
        let wide = try G1.write(G1.photo(width: 3000, height: 2000), to: dir.appendingPathComponent("w.jpg"), type: .jpeg)
        let out = try await G1.run(ToolIDs.imagesToPDF, inputs: [wide], options: OptionValues([OptionKey.pageSize: .string("a4")]), in: dir)
        let page = try XCTUnwrap(PDFDocument(url: out[0])?.page(at: 0))
        let box = page.bounds(for: .mediaBox)
        XCTAssertEqual(box.width, PDFPagePlan.a4.height, accuracy: 0.5, "landscape image → landscape A4")
        XCTAssertEqual(box.height, PDFPagePlan.a4.width, accuracy: 0.5)
        let plan = PDFPagePlan.page(for: CGSize(width: 3000, height: 2000), dpi: 72, pageSize: "letter")
        XCTAssertEqual(plan.media.size, CGSize(width: 792, height: 612))
        XCTAssertEqual(plan.frame.width / plan.frame.height, 1.5, accuracy: 0.001)
        XCTAssertTrue(plan.media.insetBy(dx: PDFPagePlan.margin - 0.01, dy: PDFPagePlan.margin - 0.01).contains(plan.frame))
    }

    // MARK: Codes

    func testReadsGeneratedQRCode() async throws {
        let payload = "https://example.com/halo?x=1"
        let qr = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator", parameters: ["inputMessage": Data(payload.utf8), "inputCorrectionLevel": "M"])?.outputImage)
        let big = qr.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        // Quiet zone: composite over white with a margin.
        let canvas = CIImage(color: .white).cropped(to: big.extent.insetBy(dx: -60, dy: -60))
        let composed = big.composited(over: canvas)
        let cg = try XCTUnwrap(CIContext().createCGImage(composed, from: composed.extent))
        let input = try png(cg, "qr.png")
        let out = try await G1.run(ToolIDs.readCodes, inputs: [input], in: dir)
        XCTAssertEqual(out[0].pathExtension, "txt")
        let results = CodeReader.parse(fileAt: out[0])
        XCTAssertEqual(results.first?.payload, payload)
        XCTAssertEqual(results.first?.symbology, "QR")
        XCTAssertEqual(results.first?.link?.absoluteString, payload)
    }

    func testNoCodeIsAHumanError() async throws {
        let input = try png(G1.photo())
        do {
            _ = try await G1.run(ToolIDs.readCodes, inputs: [input], in: dir)
            XCTFail("expected no-code error")
        } catch let e as ConversionError {
            XCTAssertTrue((e.errorDescription ?? "").contains("No QR code"))
        }
    }

    func testCodeTextRoundTrip() {
        let results = [
            CodeReadResult(payload: "plain", symbology: "QR"),
            CodeReadResult(payload: "[bracket]\n\\back\nline\n", symbology: "DataMatrix"),
            CodeReadResult(payload: "4006381333931", symbology: "EAN13"),
        ]
        let text = CodeReader.text(for: results)
        XCTAssertEqual(CodeReader.parse(text), results)
        XCTAssertTrue(text.contains("[EAN-13 · EAN13]"))
        XCTAssertNil(CodeReadResult(payload: "not a link", symbology: "QR").link)
        XCTAssertNil(CodeReadResult(payload: "javascript:alert(1)", symbology: "QR").link)
        XCTAssertNotNil(CodeReadResult(payload: "mailto:a@b.c", symbology: "QR").link)
    }
}
