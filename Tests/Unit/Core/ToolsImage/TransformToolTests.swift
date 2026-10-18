import XCTest
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import HaloCore

final class TransformToolTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws { dir = try G1.tempDir(name) }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func png(_ img: CGImage, _ name: String = "in.png", properties: [String: Any] = [:]) throws -> URL {
        try G1.write(img, to: dir.appendingPathComponent(name), type: .png, properties: properties)
    }

    // MARK: Resize

    func testResizePercent() async throws {
        let input = try png(G1.photo(width: 400, height: 300))
        let out = try await G1.run(ToolIDs.resizeImage, inputs: [input],
                                   options: OptionValues(["mode": .string("percent"), OptionKey.percent: .int(25)]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 100)
        XCTAssertEqual(img.height, 75)
    }

    func testResizeExactWidthKeepsAspect() async throws {
        let input = try png(G1.photo(width: 400, height: 300))
        let out = try await G1.run(ToolIDs.resizeImage, inputs: [input],
                                   options: OptionValues(["mode": .string("pixels"), "width": .int(1000), "height": .int(0)]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 1000)
        XCTAssertEqual(img.height, 750)
    }

    func testResizeExactBothDimensions() async throws {
        let input = try png(G1.photo(width: 400, height: 300))
        let out = try await G1.run(ToolIDs.resizeImage, inputs: [input],
                                   options: OptionValues(["mode": .string("pixels"), "width": .int(123), "height": .int(77)]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 123)
        XCTAssertEqual(img.height, 77)
    }

    func testResizePresetNeverUpscales() {
        let o = OptionValues(["mode": .string("preset"), "preset": .string("1920")])
        XCTAssertEqual(ResizePlan.targetSize(for: CGSize(width: 4032, height: 3024), options: o), CGSize(width: 1920, height: 1440))
        XCTAssertEqual(ResizePlan.targetSize(for: CGSize(width: 800, height: 600), options: o), CGSize(width: 800, height: 600))
        XCTAssertEqual(ResizePlan.targetSize(for: CGSize(width: 3024, height: 4032), options: o), CGSize(width: 1440, height: 1920))
    }

    func testResizeKeepsFlatColourAndEdges() async throws {
        // Lanczos with clamped edges: a flat image stays flat right to the border.
        let input = try png(G1.solid(width: 300, height: 200, r: 200, g: 40, b: 90))
        let out = try await G1.run(ToolIDs.resizeImage, inputs: [input],
                                   options: OptionValues(["mode": .string("percent"), OptionKey.percent: .int(30)]), in: dir)
        let img = try G1.decode(out[0])
        let px = G1.pixels(img)
        for (x, y) in [(0, 0), (img.width - 1, img.height - 1), (img.width / 2, img.height / 2)] {
            let p = G1.pixel(px, width: img.width, x: x, y: y)
            XCTAssertEqual(p.r, 200, accuracy: 2); XCTAssertEqual(p.g, 40, accuracy: 2); XCTAssertEqual(p.b, 90, accuracy: 2)
        }
    }

    // MARK: Crop

    func testCropRect() async throws {
        let input = try png(G1.photo(width: 400, height: 300))
        let out = try await G1.run(ToolIDs.cropImage, inputs: [input],
                                   options: OptionValues(["rect": .string("0.25,0.1,0.5,0.5")]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 200)
        XCTAssertEqual(img.height, 150)
        // Top-left of the crop equals source pixel (100, 30).
        let src = G1.pixels(G1.photo(width: 400, height: 300))
        let got = G1.pixels(img)
        XCTAssertEqual(G1.pixel(got, width: 200, x: 0, y: 0).r, G1.pixel(src, width: 400, x: 100, y: 30).r, accuracy: 1)
        XCTAssertEqual(G1.pixel(got, width: 200, x: 0, y: 0).g, G1.pixel(src, width: 400, x: 100, y: 30).g, accuracy: 1)
    }

    func testCropAspectPreset() async throws {
        let input = try png(G1.photo(width: 400, height: 300))
        let out = try await G1.run(ToolIDs.cropImage, inputs: [input],
                                   options: OptionValues(["rect": .string("0,0,1,1"), "aspect": .string("1:1")]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 300)
        XCTAssertEqual(img.height, 300)
    }

    func testCropRespectsEXIFOrientation() async throws {
        // Stored 400×300 with orientation 6 (rotate 90° CW) → upright 300×400.
        let input = try G1.write(G1.photo(width: 400, height: 300), to: dir.appendingPathComponent("o.jpg"), type: .jpeg,
                                 properties: [kCGImagePropertyOrientation as String: 6])
        let out = try await G1.run(ToolIDs.cropImage, inputs: [input], options: OptionValues(["rect": .string("0,0,1,0.5")]), in: dir)
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 300)
        XCTAssertEqual(img.height, 200)
        XCTAssertEqual((G1.properties(out[0])[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue ?? 1, 1)
    }

    func testOrientedDecodeMatchesThumbnailTransform() throws {
        for o in 1...8 {
            let url = try G1.write(G1.photo(width: 60, height: 40, seed: UInt64(o)), to: dir.appendingPathComponent("o\(o).png"), type: .png,
                                   properties: [kCGImagePropertyOrientation as String: o])
            let mine = try ImageSupport.decode(url).image
            let reference = try XCTUnwrap(ImageSupport.thumbnail(url, maxPixelSize: 60))
            XCTAssertEqual(mine.width, reference.width, "orientation \(o)")
            XCTAssertEqual(mine.height, reference.height, "orientation \(o)")
            let a = G1.pixels(mine), b = G1.pixels(reference)
            for (x, y) in [(1, 1), (mine.width - 2, 1), (1, mine.height - 2), (mine.width / 2, mine.height / 3)] {
                XCTAssertEqual(G1.pixel(a, width: mine.width, x: x, y: y).r, G1.pixel(b, width: mine.width, x: x, y: y).r, accuracy: 3, "o\(o) @\(x),\(y)")
                XCTAssertEqual(G1.pixel(a, width: mine.width, x: x, y: y).b, G1.pixel(b, width: mine.width, x: x, y: y).b, accuracy: 3, "o\(o) @\(x),\(y)")
            }
        }
    }

    func testOrientationTransformMatchesDecoder() throws {
        // The PDF path draws raw images through a transform; it must agree with the decoder.
        for o in 1...8 {
            let raw = G1.photo(width: 50, height: 30, seed: UInt64(o + 10))
            let orientation = try XCTUnwrap(CGImagePropertyOrientation(rawValue: UInt32(o)))
            let expected = try ImageSupport.oriented(raw, orientation)
            let w = expected.width, h = expected.height
            let ctx = try XCTUnwrap(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: G1.srgb,
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.interpolationQuality = .none
            OrientationTransform.draw(raw, orientation: orientation, in: CGRect(x: 0, y: 0, width: w, height: h), context: ctx)
            let drawn = try XCTUnwrap(ctx.makeImage())
            let a = G1.pixels(expected), b = G1.pixels(drawn)
            for (x, y) in [(0, 0), (w - 1, 0), (0, h - 1), (w / 3, h / 2)] {
                XCTAssertEqual(G1.pixel(a, width: w, x: x, y: y).r, G1.pixel(b, width: w, x: x, y: y).r, accuracy: 2, "o\(o) @\(x),\(y)")
                XCTAssertEqual(G1.pixel(a, width: w, x: x, y: y).g, G1.pixel(b, width: w, x: x, y: y).g, accuracy: 2, "o\(o) @\(x),\(y)")
            }
        }
    }

    // MARK: Adjust

    func testAdjustDirections() async throws {
        let base = G1.photo(width: 160, height: 120)
        let input = try png(base)
        let before = G1.meanRGB(base)

        let bright = try await G1.run(ToolIDs.adjustImage, inputs: [input], options: OptionValues(["exposure": .double(1)]), in: dir)
        let b = G1.meanRGB(try G1.decode(bright[0]))
        XCTAssertGreaterThan(b.r + b.g + b.b, (before.r + before.g + before.b) * 1.2, "exposure +1 brightens")

        let grey = try await G1.run(ToolIDs.adjustImage, inputs: [input], options: OptionValues(["saturation": .double(0)]), in: dir)
        let gp = G1.pixels(try G1.decode(grey[0]))
        let p = G1.pixel(gp, width: 160, x: 120, y: 30)
        XCTAssertEqual(p.r, p.g, accuracy: 3)
        XCTAssertEqual(p.g, p.b, accuracy: 3)

        let warm = try await G1.run(ToolIDs.adjustImage, inputs: [input], options: OptionValues(["warmth": .double(0.8)]), in: dir)
        let w = G1.meanRGB(try G1.decode(warm[0]))
        XCTAssertGreaterThan(w.r / w.b, before.r / before.b * 1.05, "warmth shifts toward red/yellow")

        let cool = try await G1.run(ToolIDs.adjustImage, inputs: [input], options: OptionValues(["warmth": .double(-0.8)]), in: dir)
        let c = G1.meanRGB(try G1.decode(cool[0]))
        XCTAssertLessThan(c.r / c.b, before.r / before.b * 0.95)

        let flat = try await G1.run(ToolIDs.adjustImage, inputs: [input], options: OptionValues(["contrast": .double(0.6)]), in: dir)
        let fp = G1.pixels(try G1.decode(flat[0])), bp = G1.pixels(base)
        let spreadAfter = abs(G1.pixel(fp, width: 160, x: 155, y: 5).r - G1.pixel(fp, width: 160, x: 3, y: 5).r)
        let spreadBefore = abs(G1.pixel(bp, width: 160, x: 155, y: 5).r - G1.pixel(bp, width: 160, x: 3, y: 5).r)
        XCTAssertLessThan(spreadAfter, spreadBefore, "lower contrast narrows the range")
    }

    func testContrastAndSaturationDontCrushShadows() async throws {
        // Dark navy: in linear light a contrast pivot would push R and G to zero.
        let input = try png(G1.solid(width: 32, height: 32, r: 46, g: 51, b: 115), "navy.png")
        let out = try await G1.run(ToolIDs.adjustImage, inputs: [input],
                                   options: OptionValues(["contrast": .double(1.12), "saturation": .double(1.25)]), in: dir)
        let p = G1.pixel(G1.pixels(try G1.decode(out[0])), width: 32, x: 16, y: 16)
        XCTAssertGreaterThan(p.r, 20); XCTAssertGreaterThan(p.g, 20)
        XCTAssertEqual(p.b, 115, accuracy: 25)
    }

    func testAdjustOptionsRoundTrip() {
        let a = ImageAdjustments(exposure: 0.5, contrast: 1.2, saturation: 0.3, warmth: -0.4)
        XCTAssertEqual(ImageAdjustments(options: a.options), a)
        XCTAssertTrue(ImageAdjustments(options: ToolSchemas.adjust.defaults).isNeutral)
    }

    func testDisplayP3ProfileSurvives() async throws {
        // A P3-tagged PNG keeps its colour space through a pixel tool.
        let p3 = try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        let src = G1.photo(width: 64, height: 64)
        let ctx = try XCTUnwrap(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0, space: p3,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        let input = try png(try XCTUnwrap(ctx.makeImage()), "p3.png")
        let out = try await G1.run(ToolIDs.adjustImage, inputs: [input], options: OptionValues(["exposure": .double(0.3)]), in: dir)
        let profile = G1.properties(out[0])[kCGImagePropertyProfileName as String] as? String
        XCTAssertEqual(profile, "Display P3")
    }
}
