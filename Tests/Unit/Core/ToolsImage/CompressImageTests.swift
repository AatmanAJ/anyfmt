import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import HaloCore

final class CompressImageTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws { dir = try G1.tempDir(name) }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func jpeg(_ w: Int = 800, _ h: Int = 600, quality: Double = 0.95) throws -> URL {
        try G1.write(G1.photo(width: w, height: h), to: dir.appendingPathComponent("photo.jpg"), type: .jpeg, quality: quality)
    }

    func testRegistryShipsAllThirteenImageTools() {
        let ids = Set(ImageToolRunners.all.map(\.id))
        let expected: Set<ToolID> = [
            ToolIDs.compressImage, ToolIDs.resizeImage, ToolIDs.cropImage, ToolIDs.adjustImage, ToolIDs.annotateImage,
            ToolIDs.redactImage, ToolIDs.removeBackground, ToolIDs.addBackground, ToolIDs.collage, ToolIDs.imagesToPDF,
            ToolIDs.readCodes, ToolIDs.editMetadata, ToolIDs.stripMetadata,
        ]
        XCTAssertEqual(ids, expected)
        XCTAssertEqual(ImageToolRunners.all.count, 13)
        for id in expected {
            XCTAssertNotNil(ToolCatalog.spec(id), "\(id) missing from ToolCatalog")
            XCTAssertNotNil(ToolRegistry.default[id], "\(id) missing from ToolRegistry.default")
            XCTAssertNil(ToolCatalog.spec(id)?.cloudFeature, "local tools never consult entitlements")
        }
    }

    func testQualityModeShrinksJPEG() async throws {
        let input = try jpeg()
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input], options: OptionValues([OptionKey.quality: .int(40)]), in: dir)
        XCTAssertEqual(out.first?.pathExtension, "jpg")
        XCTAssertLessThan(G1.fileSize(out[0]), G1.fileSize(input))
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 800)
        XCTAssertEqual(img.height, 600)
    }

    func testTargetSizeJPEGWithinTolerance() async throws {
        let input = try jpeg(1200, 900)
        let original = G1.fileSize(input)
        let target = original / 3
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input],
                                   options: OptionValues([OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(target)]), in: dir)
        let size = G1.fileSize(out[0])
        XCTAssertLessThanOrEqual(size, target, "must not exceed the target")
        XCTAssertGreaterThan(Double(size), Double(target) * 0.8, "should use most of the budget (got \(size) for \(target))")
        XCTAssertEqual(try G1.decode(out[0]).width, 1200, "quality alone was enough; no downscale")
    }

    func testTinyTargetDownscales() async throws {
        let input = try jpeg(1200, 900)
        let target = 6_000
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input],
                                   options: OptionValues([OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(target)]), in: dir)
        XCTAssertLessThanOrEqual(G1.fileSize(out[0]), target)
        let img = try G1.decode(out[0])
        XCTAssertLessThan(img.width, 1200)
        XCTAssertEqual(Double(img.width) / Double(img.height), 4.0 / 3.0, accuracy: 0.02, "aspect kept")
    }

    func testPercentageMode() async throws {
        let input = try jpeg()
        let original = G1.fileSize(input)
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input],
                                   options: OptionValues([OptionKey.sizeMode: .string("percent"), OptionKey.percent: .int(25)]), in: dir)
        let size = G1.fileSize(out[0])
        XCTAssertLessThanOrEqual(size, original / 4 + 1)
        XCTAssertGreaterThan(Double(size), Double(original) * 0.25 * 0.75)
    }

    func testHEICTargetSize() async throws {
        let input = try G1.write(G1.photo(width: 900, height: 700), to: dir.appendingPathComponent("p.heic"), type: .heic, quality: 0.95)
        let target = G1.fileSize(input) / 2
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input],
                                   options: OptionValues([OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(target)]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "heic")
        XCTAssertLessThanOrEqual(G1.fileSize(out[0]), target)
    }

    func testWebPUsesBundledEncoder() async throws {
        try XCTSkipUnless(G1.ffmpeg.isAvailable, "bundled ffmpeg not found")
        // WebP input made by the bundled encoder itself.
        let png = try G1.write(G1.photo(width: 640, height: 480), to: dir.appendingPathComponent("src.png"), type: .png)
        let webp = dir.appendingPathComponent("p.webp")
        try await G1.ffmpeg.run(["-i", png.path, "-c:v", "libwebp", "-quality", "95", webp.path])
        let target = G1.fileSize(webp) / 2
        let out = try await G1.run(ToolIDs.compressImage, inputs: [webp],
                                   options: OptionValues([OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(target)]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "webp")
        XCTAssertLessThanOrEqual(G1.fileSize(out[0]), target)
        XCTAssertEqual(try G1.decode(out[0]).width, 640)
    }

    func testPNGQuantisesWithAlphaIntact() async throws {
        let input = try G1.write(G1.photo(width: 400, height: 300, alpha: true), to: dir.appendingPathComponent("a.png"), type: .png)
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input], options: OptionValues([OptionKey.quality: .int(70)]), in: dir)
        XCTAssertEqual(out[0].pathExtension, "png")
        XCTAssertLessThan(G1.fileSize(out[0]), G1.fileSize(input))
        let img = try G1.decode(out[0])
        XCTAssertEqual(img.width, 400)
        let props = G1.properties(out[0])
        XCTAssertEqual(props[kCGImagePropertyHasAlpha as String] as? Bool, true)
        // Alpha gradient survives (left opaque, right translucent).
        let px = G1.pixels(img)
        XCTAssertGreaterThan(G1.pixel(px, width: 400, x: 2, y: 150).a, 240)
        XCTAssertLessThan(G1.pixel(px, width: 400, x: 397, y: 150).a, 110)
    }

    func testPNGTargetSize() async throws {
        let input = try G1.write(G1.photo(width: 500, height: 400), to: dir.appendingPathComponent("b.png"), type: .png)
        let target = G1.fileSize(input) / 3
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input],
                                   options: OptionValues([OptionKey.sizeMode: .string("size"), OptionKey.targetSize: .int(target)]), in: dir)
        XCTAssertLessThanOrEqual(G1.fileSize(out[0]), target)
        XCTAssertNotNil(try? G1.decode(out[0]))
    }

    func testFewColourPNGIsLosslessPalette() throws {
        // Four flat colours: the quantiser must keep them exactly.
        var px = [UInt8](repeating: 255, count: 64 * 64 * 4)
        for y in 0..<64 { for x in 0..<64 {
            let i = (y * 64 + x) * 4
            let c: [UInt8] = x < 32 ? (y < 32 ? [255, 0, 0, 255] : [0, 255, 0, 128]) : (y < 32 ? [0, 0, 255, 255] : [0, 0, 0, 0])
            px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2]; px[i + 3] = c[3]
        } }
        let q = PaletteQuantizer(maxColors: 256).quantize(pixels: px, width: 64, height: 64)
        XCTAssertTrue(q.exact)
        XCTAssertEqual(q.palette.count, 4)
        let data = try XCTUnwrap(PalettePNGWriter.write(q, colorSpace: G1.srgb, dpi: 144, metadataChunks: []))
        let url = dir.appendingPathComponent("pal.png")
        try data.write(to: url)
        let back = G1.pixels(try G1.decode(url))
        XCTAssertEqual(G1.pixel(back, width: 64, x: 5, y: 5).r, 255)
        XCTAssertEqual(G1.pixel(back, width: 64, x: 5, y: 40).a, 128)
        XCTAssertEqual(G1.pixel(back, width: 64, x: 40, y: 40).a, 0)
        XCTAssertEqual((G1.properties(url)[kCGImagePropertyDPIWidth as String] as? NSNumber)?.intValue, 144)
        XCTAssertEqual((G1.properties(url)[kCGImagePropertyDepth as String] as? NSNumber)?.intValue, 2, "4 colours pack to 2 bits")
    }

    func testQuantiserLimitsPalette() {
        let px = G1.pixels(G1.photo(width: 120, height: 90))
        let q = PaletteQuantizer(maxColors: 32).quantize(pixels: px, width: 120, height: 90)
        XCTAssertFalse(q.exact)
        XCTAssertLessThanOrEqual(q.palette.count, 32)
        XCTAssertEqual(q.indices.count, 120 * 90)
        XCTAssertTrue(q.indices.allSatisfy { Int($0) < q.palette.count })
    }

    func testNeverLargerThanOriginal() async throws {
        let input = try jpeg(400, 300, quality: 0.3)
        let out = try await G1.run(ToolIDs.compressImage, inputs: [input], options: OptionValues([OptionKey.quality: .int(95)]), in: dir)
        XCTAssertLessThanOrEqual(G1.fileSize(out[0]), G1.fileSize(input))
    }

    func testMetadataPolicyHonoured() async throws {
        let props: [String: Any] = [kCGImagePropertyGPSDictionary as String: [kCGImagePropertyGPSLatitude as String: 12.5,
                                                                               kCGImagePropertyGPSLatitudeRef as String: "N"],
                                    kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFMake as String: "TestCam"]]
        let input = try G1.write(G1.photo(width: 400, height: 300), to: dir.appendingPathComponent("gps.jpg"), type: .jpeg, quality: 0.95,
                                 properties: props)
        let kept = try await G1.run(ToolIDs.compressImage, inputs: [input], options: OptionValues([OptionKey.quality: .int(50)]), metadata: .keep, in: dir)
        XCTAssertNotNil(G1.properties(kept[0])[kCGImagePropertyGPSDictionary as String])
        let priv = try await G1.run(ToolIDs.compressImage, inputs: [input], options: OptionValues([OptionKey.quality: .int(50)]), metadata: .stripPrivate, in: dir)
        XCTAssertNil(G1.properties(priv[0])[kCGImagePropertyGPSDictionary as String])
        XCTAssertNil((G1.properties(priv[0])[kCGImagePropertyTIFFDictionary as String] as? [String: Any])?[kCGImagePropertyTIFFMake as String])
        let none = try await G1.run(ToolIDs.compressImage, inputs: [input], options: OptionValues([OptionKey.quality: .int(50)]), metadata: .stripAll, in: dir)
        XCTAssertNil(G1.properties(none[0])[kCGImagePropertyGPSDictionary as String])
    }
}
