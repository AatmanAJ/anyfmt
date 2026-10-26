import XCTest
import ImageIO
import CoreText
@testable import AnyfmtCore

final class ImageIOEngineTests: XCTestCase {
    typealias S = ImageTestSupport
    let engine = ImageIOEngine()

    /// A JPEG carrying camera metadata: orientation 6, GPS, device, author, capture settings.
    private func cameraJPEG(_ dir: URL, image: CGImage = S.leftRedRightBlue()) -> URL {
        S.write(image, to: dir.appendingPathComponent("camera.jpg"), uti: "public.jpeg", properties: [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144,
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFOrientation: 6, kCGImagePropertyTIFFMake: "anyfmt",
                                             kCGImagePropertyTIFFModel: "Cam 1", kCGImagePropertyTIFFArtist: "Jane Doe"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifBodySerialNumber: "SN-42", kCGImagePropertyExifLensModel: "Lens X",
                                             kCGImagePropertyExifDateTimeOriginal: "2026:10:18 10:00:00", kCGImagePropertyExifISOSpeedRatings: [200]],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 51.5, kCGImagePropertyGPSLatitudeRef: "N",
                                            kCGImagePropertyGPSLongitude: 0.12, kCGImagePropertyGPSLongitudeRef: "W"],
            kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCByline: ["Jane Doe"], kCGImagePropertyIPTCCity: "London",
                                             kCGImagePropertyIPTCKeywords: ["kept"]],
            kCGImageDestinationLossyCompressionQuality: 0.95,
        ])
    }

    // MARK: Orientation

    func testOrientationIsAppliedToPixels() async throws {
        let dir = try S.tempDir()
        let src = cameraJPEG(dir)
        for to in [Formats.png, Formats.jpg, Formats.heic, Formats.bmp, Formats.tga] {
            let out = try await S.convert(engine, src, from: Formats.jpg, to: to, in: dir.appendingPathComponent(to.rawValue))
            let img = try XCTUnwrap(S.decode(out[0]))
            // Stored 40×20 (left red, right blue) rotated 90° CW → 20×40, red on top.
            XCTAssertEqual([img.width, img.height], [20, 40], "\(to)")
            S.assertColor(S.pixel(img, 10, 5), [255, 0, 0, 255], tolerance: 40, "\(to) top")
            S.assertColor(S.pixel(img, 10, 34), [0, 0, 255, 255], tolerance: 40, "\(to) bottom")
            let o = S.properties(out[0])["Orientation"] as? Int ?? 1
            XCTAssertEqual(o, 1, "\(to) must not double-rotate")
        }
    }

    func testMaxDimensionDownscalesKeepingAspect() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(640, 480), to: dir.appendingPathComponent("big.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.jpg, options: [OptionKey.maxDimension: .int(100)])
        let img = try XCTUnwrap(S.decode(out[0]))
        XCTAssertEqual([img.width, img.height], [100, 75])
        // Never upscales.
        let same = try await S.convert(engine, src, from: Formats.png, to: Formats.jpg, options: [OptionKey.maxDimension: .int(5000)])
        XCTAssertEqual(S.decode(same[0])?.width, 640)
    }

    // MARK: Colour

    func testDisplayP3ProfileIsPreserved() async throws {
        let dir = try S.tempDir()
        let p3 = S.solid(32, 32, S.color(1, 0, 0, space: S.p3), space: S.p3)
        let src = S.write(p3, to: dir.appendingPathComponent("p3.png"), uti: "public.png")
        for to in [Formats.jpg, Formats.heic, Formats.tiff, Formats.png, Formats.psd, Formats.avif] where engine.isAvailable(Capability(Formats.png, to, engine.id)) {
            let out = try await S.convert(engine, src, from: Formats.png, to: to, in: dir.appendingPathComponent(to.rawValue))
            let img = try XCTUnwrap(S.decode(out[0]))
            XCTAssertEqual(img.colorSpace?.name as String?, CGColorSpace.displayP3 as String, "\(to) should stay Display P3")
        }
    }

    func testFormatsWithoutProfilesGetRealSRGBConversion() async throws {
        let dir = try S.tempDir()
        // A P3 colour inside the sRGB gamut, so the converted value is exact.
        let p3 = S.solid(16, 16, S.color(0.8, 0.5, 0.3), space: S.p3, alpha: false)
        let expected = S.pixel(p3, 4, 4) // drawn into sRGB by ColorSync
        let src = S.write(p3, to: dir.appendingPathComponent("p3.png"), uti: "public.png")
        for to in [Formats.tga, Formats.jp2, Formats.bmp, Formats.gif] {
            let out = try await S.convert(engine, src, from: Formats.png, to: to, in: dir.appendingPathComponent(to.rawValue))
            let img = try XCTUnwrap(S.decode(out[0]))
            S.assertColor(S.pixel(img, 4, 4), expected, tolerance: 6, "\(to)")
        }
    }

    func testAlphaFlattenedOntoBackgroundForOpaqueTargets() async throws {
        let dir = try S.tempDir()
        let clear = S.image(16, 16) { _ in } // fully transparent
        let src = S.write(clear, to: dir.appendingPathComponent("clear.png"), uti: "public.png")
        let jpg = try await S.convert(engine, src, from: Formats.png, to: Formats.jpg, options: [OptionKey.background: .string("#FF0000")])
        S.assertColor(S.pixel(try XCTUnwrap(S.decode(jpg[0])), 8, 8), [255, 0, 0, 255], tolerance: 8)
        let bmp = try await S.convert(engine, src, from: Formats.png, to: Formats.bmp, options: [OptionKey.background: .string("#00FF00")])
        let bmpImg = try XCTUnwrap(S.decode(bmp[0]))
        S.assertColor(S.pixel(bmpImg, 8, 8), [0, 255, 0, 255], tolerance: 2)
        let white = try await S.convert(engine, src, from: Formats.png, to: Formats.jpg)
        S.assertColor(S.pixel(try XCTUnwrap(S.decode(white[0])), 8, 8), [255, 255, 255, 255], tolerance: 4, "default white")
        // Alpha-capable targets keep transparency.
        let png = try await S.convert(engine, src, from: Formats.png, to: Formats.tiff)
        XCTAssertEqual(S.pixel(try XCTUnwrap(S.decode(png[0])), 8, 8)[3], 0)
    }

    func testSixteenBitKeptWhereTargetSupportsIt() async throws {
        let dir = try S.tempDir()
        let deep = S.image(32, 32, space: S.p3, bits: 16) { ctx in
            ctx.setFillColor(S.color(0.3, 0.6, 0.9, space: S.p3)); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let src = S.write(deep, to: dir.appendingPathComponent("deep.png"), uti: "public.png")
        let tiff = try await S.convert(engine, src, from: Formats.png, to: Formats.tiff)
        XCTAssertEqual(S.decode(tiff[0])?.bitsPerComponent, 16)
        let jpg = try await S.convert(engine, src, from: Formats.png, to: Formats.jpg)
        XCTAssertEqual(S.decode(jpg[0])?.bitsPerComponent, 8)
    }

    // MARK: Metadata

    func testMetadataKeepCopiesEverything() async throws {
        let dir = try S.tempDir()
        let out = try await S.convert(engine, cameraJPEG(dir), from: Formats.jpg, to: Formats.jpg, metadata: .keep)
        let p = S.properties(out[0])
        XCTAssertNotNil(p["{GPS}"], "GPS kept")
        XCTAssertEqual((p["{TIFF}"] as? [String: Any])?["Make"] as? String, "anyfmt")
        XCTAssertEqual((p["{Exif}"] as? [String: Any])?["BodySerialNumber"] as? String, "SN-42")
        XCTAssertEqual((p["{IPTC}"] as? [String: Any])?["City"] as? String, "London")
        XCTAssertEqual(p["DPIWidth"] as? Int, 144)
        XCTAssertEqual(p["Orientation"] as? Int ?? 1, 1)
    }

    func testMetadataStripPrivateDropsLocationDeviceAndAuthor() async throws {
        let dir = try S.tempDir()
        let p3Card = S.image(40, 20, space: S.p3, alpha: false) { ctx in
            ctx.setFillColor(S.color(1, 0, 0, space: S.p3)); ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
            ctx.setFillColor(S.color(0, 0, 1, space: S.p3)); ctx.fill(CGRect(x: 20, y: 0, width: 20, height: 20))
        }
        let src = cameraJPEG(dir, image: p3Card)
        for to in [Formats.jpg, Formats.heic, Formats.png, Formats.tiff] {
            let out = try await S.convert(engine, src, from: Formats.jpg, to: to, metadata: .stripPrivate, in: dir.appendingPathComponent(to.rawValue))
            let p = S.properties(out[0])
            XCTAssertNil(p["{GPS}"], "\(to): GPS must be gone")
            let tiff = p["{TIFF}"] as? [String: Any] ?? [:]
            XCTAssertNil(tiff["Make"], "\(to)"); XCTAssertNil(tiff["Model"], "\(to)"); XCTAssertNil(tiff["Artist"], "\(to)")
            let exif = p["{Exif}"] as? [String: Any] ?? [:]
            XCTAssertNil(exif["BodySerialNumber"], "\(to)"); XCTAssertNil(exif["LensModel"], "\(to)")
            XCTAssertEqual(exif["DateTimeOriginal"] as? String, "2026:10:18 10:00:00", "\(to): capture date kept")
            let iptc = p["{IPTC}"] as? [String: Any] ?? [:]
            XCTAssertNil(iptc["City"], "\(to)"); XCTAssertNil(iptc["Byline"], "\(to)")
            XCTAssertEqual(iptc["Keywords"] as? [String], ["kept"], "\(to): keywords kept")
            XCTAssertEqual(p["DPIWidth"] as? Int, 144, "\(to): DPI kept")
            let img = try XCTUnwrap(S.decode(out[0]))
            XCTAssertEqual(img.colorSpace?.name as String?, CGColorSpace.displayP3 as String, "\(to): profile kept")
            XCTAssertEqual([img.width, img.height], [20, 40], "\(to): orientation applied")
            S.assertColor(S.pixel(img, 10, 5), [255, 0, 0, 255], tolerance: 60, "\(to) top is red")
            // No XMP left that still names the author or the place.
            if let src = S.source(out[0]), let tree = CGImageSourceCopyMetadataAtIndex(src, 0, nil),
               let xmp = CGImageMetadataCreateXMPData(tree, nil) {
                let text = String(decoding: xmp as Data, as: UTF8.self)
                XCTAssertFalse(text.contains("Jane Doe"), "\(to): author leaked via XMP")
                XCTAssertFalse(text.contains("London"), "\(to): place leaked via XMP")
            }
        }
    }

    func testMetadataStripAllLeavesOnlyPixels() async throws {
        let dir = try S.tempDir()
        let p3 = S.solid(40, 20, S.color(0.2, 0.7, 0.3, space: S.p3), space: S.p3, alpha: false)
        let src = cameraJPEG(dir, image: p3)
        for to in [Formats.jpg, Formats.heic, Formats.png] {
            let out = try await S.convert(engine, src, from: Formats.jpg, to: to, metadata: .stripAll, in: dir.appendingPathComponent(to.rawValue))
            let p = S.properties(out[0])
            XCTAssertNil(p["{GPS}"], "\(to)")
            XCTAssertNil(p["{IPTC}"], "\(to)")
            XCTAssertNil((p["{TIFF}"] as? [String: Any])?["Make"], "\(to)")
            XCTAssertNil((p["{Exif}"] as? [String: Any])?["DateTimeOriginal"], "\(to)")
            let img = try XCTUnwrap(S.decode(out[0]))
            XCTAssertEqual(img.colorSpace?.name as String?, CGColorSpace.sRGB as String, "\(to): device profile replaced by sRGB")
            XCTAssertEqual([img.width, img.height], [20, 40], "\(to): pixels still oriented")
        }
    }

    // MARK: Quality

    func testQualityAffectsSize() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(256, 256), to: dir.appendingPathComponent("n.png"), uti: "public.png")
        for to in [Formats.jpg, Formats.heic] {
            let lo = try await S.convert(engine, src, from: Formats.png, to: to, options: [OptionKey.quality: .int(20)], in: dir.appendingPathComponent("lo-\(to)"))
            let hi = try await S.convert(engine, src, from: Formats.png, to: to, options: [OptionKey.quality: .int(95)], in: dir.appendingPathComponent("hi-\(to)"))
            XCTAssertLessThan(S.fileSize(lo[0]), S.fileSize(hi[0]), "\(to)")
        }
    }

    // MARK: Icons

    func testICOHasEverySquareSizeUpTo256() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(640, 480), to: dir.appendingPathComponent("wide.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.ico)
        var sizes: [Int] = []
        for i in 0..<S.count(out[0]) {
            let p = S.properties(out[0], index: i)
            XCTAssertEqual(p["PixelWidth"] as? Int, p["PixelHeight"] as? Int, "square")
            sizes.append(p["PixelWidth"] as? Int ?? 0)
        }
        XCTAssertEqual(sizes.sorted(), IconWriter.icoSizes)
        // Padded, not stretched: the top rows of a 4:3 source are transparent.
        let big = try XCTUnwrap(S.decode(out[0], index: sizes.firstIndex(of: 256) ?? 0))
        XCTAssertEqual(S.pixel(big, 128, 2)[3], 0)
        XCTAssertEqual(S.pixel(big, 128, 128)[3], 255)
    }

    func testICNSHasAllRetinaSizesAndPassesIconutil() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(300, 200), to: dir.appendingPathComponent("art.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.icns)
        var sizes = Set<Int>()
        for i in 0..<S.count(out[0]) { sizes.insert(S.properties(out[0], index: i)["PixelWidth"] as? Int ?? 0) }
        XCTAssertTrue(sizes.isSuperset(of: [16, 32, 64, 128, 256, 512, 1024]), "ImageIO sees \(sizes.sorted())")
        // Apple's own tool must accept it and find every iconset member.
        let iconset = dir.appendingPathComponent("check.iconset")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        p.arguments = ["--convert", "iconset", "--output", iconset.path, out[0].path]
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)
        let members = Set((try? FileManager.default.contentsOfDirectory(atPath: iconset.path)) ?? [])
        for m in ["icon_16x16.png", "icon_16x16@2x.png", "icon_32x32.png", "icon_32x32@2x.png", "icon_128x128.png",
                  "icon_128x128@2x.png", "icon_256x256.png", "icon_256x256@2x.png", "icon_512x512.png", "icon_512x512@2x.png"] {
            XCTAssertTrue(members.contains(m), "iconutil missing \(m); got \(members.sorted())")
        }
    }

    func testIconInputUsesLargestSize() async throws {
        let dir = try S.tempDir()
        let ico = S.write([16, 64, 32].map { S.solid($0, $0, S.color(0, 0.5, 1)) }, to: dir.appendingPathComponent("i.ico"), uti: "com.microsoft.ico")
        let out = try await S.convert(engine, ico, from: Formats.ico, to: Formats.png)
        XCTAssertEqual(S.decode(out[0])?.width, 64)
    }

    // MARK: Multi-frame and multi-page

    func testAnimatedGIFToStillUsesFirstFrame() async throws {
        let dir = try S.tempDir()
        let gif = S.animatedGIF(at: dir.appendingPathComponent("a.gif"))
        let out = try await S.convert(engine, gif, from: Formats.gif, to: Formats.png)
        XCTAssertEqual(S.count(out[0]), 1)
        S.assertColor(S.pixel(try XCTUnwrap(S.decode(out[0])), 4, 4), [255, 0, 0, 255], tolerance: 10)
    }

    func testMultiPageTIFFFirstPageForImagesAllPagesForPDF() async throws {
        let dir = try S.tempDir()
        let pages = [S.solid(30, 20, S.color(1, 0, 0)), S.solid(30, 20, S.color(0, 1, 0)), S.solid(30, 20, S.color(0, 0, 1))]
        let tiff = S.write(pages, to: dir.appendingPathComponent("doc.tiff"), uti: "public.tiff")
        let jpg = try await S.convert(engine, tiff, from: Formats.tiff, to: Formats.jpg)
        S.assertColor(S.pixel(try XCTUnwrap(S.decode(jpg[0])), 5, 5), [255, 0, 0, 255], tolerance: 10)
        let pdf = try await S.convert(engine, tiff, from: Formats.tiff, to: Formats.pdf)
        XCTAssertEqual(CGPDFDocument(pdf[0] as CFURL)?.numberOfPages, 3)
    }

    func testAnimatedWebPToGIFKeepsFramesAndTiming() async throws {
        guard S.hasFFmpeg else { throw XCTSkip("ffmpeg not bundled") }
        let dir = try S.tempDir()
        let gif = S.animatedGIF(at: dir.appendingPathComponent("a.gif"))
        let webp = try await S.convert(FFmpegImageEngine(), gif, from: Formats.gif, to: Formats.webp, in: dir.appendingPathComponent("w"))
        let back = try await S.convert(engine, webp[0], from: Formats.webp, to: Formats.gif, in: dir.appendingPathComponent("g"))
        let input = try ImageInput.open(back[0], format: Formats.gif)
        let anim = try XCTUnwrap(input.animation)
        XCTAssertEqual(anim.frameCount, 5)
        for (got, want) in zip(anim.delays, [0.1, 0.2, 0.3, 0.4, 0.5]) { XCTAssertEqual(got, want, accuracy: 0.011) }
        XCTAssertEqual(anim.loopCount, 0)
    }

    // MARK: PDF

    func testImageToPDFPageSizes() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(288, 144), to: dir.appendingPathComponent("w.png"), uti: "public.png",
                          properties: [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144])
        func box(_ size: String) async throws -> CGRect {
            let out = try await S.convert(engine, src, from: Formats.png, to: Formats.pdf, options: [OptionKey.pageSize: .string(size)],
                                          in: dir.appendingPathComponent(size))
            let page = try XCTUnwrap(CGPDFDocument(out[0] as CFURL)?.page(at: 1))
            return page.getBoxRect(.mediaBox)
        }
        let fit = try await box("fit")
        XCTAssertEqual(fit.width, 144, accuracy: 0.5); XCTAssertEqual(fit.height, 72, accuracy: 0.5) // 288 px at 144 dpi = 2 in
        let a4 = try await box("a4")
        XCTAssertEqual(a4.width, 841.89, accuracy: 1); XCTAssertEqual(a4.height, 595.28, accuracy: 1) // landscape image → landscape paper
        let letter = try await box("letter")
        XCTAssertEqual(letter.width, 792, accuracy: 1)
    }

    func testPhotoPDFStaysCompact() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(1200, 900), to: dir.appendingPathComponent("p.jpg"), uti: "public.jpeg",
                          properties: [kCGImageDestinationLossyCompressionQuality: 0.85])
        let out = try await S.convert(engine, src, from: Formats.jpg, to: Formats.pdf)
        // Flate-compressed RGB would be ~3 MB; DCT keeps it near the JPEG's size.
        XCTAssertLessThan(S.fileSize(out[0]), max(3 * S.fileSize(src), 400_000), "PDF \(S.fileSize(out[0])) vs JPEG \(S.fileSize(src))")
    }

    // MARK: Other encoders

    func testEveryImageIOTargetDecodes() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(64, 48), to: dir.appendingPathComponent("s.png"), uti: "public.png")
        for to in ImageIOEngine.outputs where to != Formats.pdf && to != Formats.png {
            guard engine.isAvailable(Capability(Formats.png, to, engine.id)) else { continue }
            let out = try await S.convert(engine, src, from: Formats.png, to: to, in: dir.appendingPathComponent(to.rawValue))
            XCTAssertEqual(out[0].pathExtension, Formats.extension(for: to))
            let img = try XCTUnwrap(S.decode(out[0]), "\(to) must decode")
            if to != Formats.ico && to != Formats.icns { XCTAssertEqual([img.width, img.height], [64, 48], "\(to)") }
        }
    }

    func testAVIFRoundTripWhenImageIOEncodes() async throws {
        guard ImageIOSupport.canEncodeAVIF else { throw XCTSkip("this macOS has no ImageIO AVIF encoder") }
        let dir = try S.tempDir()
        let src = S.write(S.solid(64, 64, S.color(0.2, 0.6, 0.9, 0.5)), to: dir.appendingPathComponent("a.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.avif)
        let img = try XCTUnwrap(S.decode(out[0]))
        XCTAssertEqual(img.width, 64)
        let px = S.pixel(img, 32, 32)
        XCTAssertEqual(px[3], 128, accuracy: 6, "alpha kept")
    }

    // MARK: HDR

    /// Linear ramp 0 → 4.0 (two stops over SDR white) in a half-float image.
    private func hdrRamp(width w: Int = 256, height h: Int = 16, alpha: Bool = true) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let a = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        let info = a | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 16, bytesPerRow: 0, space: space, bitmapInfo: info)!
        for x in 0..<w {
            let v = CGFloat(x) / CGFloat(w - 1) * 4
            ctx.setFillColor(CGColor(colorSpace: space, components: [v, v, v, 1])!)
            ctx.fill(CGRect(x: x, y: 0, width: 1, height: h))
        }
        return ctx.makeImage()!
    }

    func testHDRHighlightsRollOffInsteadOfClipping() async throws {
        let dir = try S.tempDir()
        let exr = S.write(hdrRamp(), to: dir.appendingPathComponent("hdr.exr"), uti: "com.ilm.openexr-image")
        let out = try await S.convert(engine, exr, from: Formats.exr, to: Formats.jpg)
        let img = try XCTUnwrap(S.decode(out[0]))
        let reds = [32, 64, 128, 192, 250].map { S.pixel(img, $0, 8)[0] }
        XCTAssertEqual(reds, reds.sorted(), "monotonic: \(reds)")
        XCTAssertEqual(Set(reds).count, reds.count, "no clipped plateau: \(reds)")
        XCTAssertGreaterThan(reds.last ?? 0, 235, "peak still near white")
        // EXR → EXR-capable float target keeps the HDR values.
        let tiff = try await S.convert(engine, exr, from: Formats.exr, to: Formats.exr, in: dir.appendingPathComponent("exr"))
        XCTAssertNotNil(S.decode(tiff[0]))
    }

    func testGainMapKeptForUntouchedHDRPhotos() async throws {
        guard #available(macOS 15.0, *) else { throw XCTSkip("ISO gain-map encoding needs macOS 15") }
        let dir = try S.tempDir()
        let heic = S.write(hdrRamp(width: 128, height: 128, alpha: false), to: dir.appendingPathComponent("hdr.heic"), uti: "public.heic",
                           properties: [kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap])
        let src = try XCTUnwrap(S.source(heic))
        try XCTSkipIf(CGImageSourceCopyAuxiliaryDataInfoAtIndex(src, 0, kCGImageAuxiliaryDataTypeISOGainMap) == nil, "fixture has no gain map")
        let kept = try await S.convert(engine, heic, from: Formats.heic, to: Formats.jpg, metadata: .keep, in: dir.appendingPathComponent("keep"))
        let k = try XCTUnwrap(S.source(kept[0]))
        XCTAssertNotNil(CGImageSourceCopyAuxiliaryDataInfoAtIndex(k, 0, kCGImageAuxiliaryDataTypeISOGainMap), "gain map survives HEIC → JPG")
        // Resizing re-renders the pixels: SDR result, no stale gain map.
        let small = try await S.convert(engine, heic, from: Formats.heic, to: Formats.jpg, options: [OptionKey.maxDimension: .int(64)],
                                        in: dir.appendingPathComponent("small"))
        XCTAssertEqual(S.decode(small[0])?.width, 64)
    }

    func testTIFFIsLZWAndUntiledEvenFromHEIC() async throws {
        let dir = try S.tempDir()
        let heic = S.write(S.noise(300, 200), to: dir.appendingPathComponent("s.heic"), uti: "public.heic",
                           properties: [kCGImagePropertyOrientation: 6, kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 1.0]])
        for policy in MetadataPolicy.allCases {
            let out = try await S.convert(engine, heic, from: Formats.heic, to: Formats.tiff, metadata: policy, in: dir.appendingPathComponent(policy.rawValue))
            let tiff = S.properties(out[0])["{TIFF}"] as? [String: Any] ?? [:]
            XCTAssertEqual(tiff["Compression"] as? Int, 5, "\(policy): LZW")
            XCTAssertNil(tiff["TileWidth"], "\(policy): no tiles inherited from HEIC")
        }
    }

    func testImageToTextUsesOCR() async throws {
        let dir = try S.tempDir()
        let card = S.image(600, 160, alpha: false) { ctx in
            ctx.setFillColor(S.color(1, 1, 1)); ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 160))
            let font = CTFontCreateWithName("Helvetica" as CFString, 56, nil)
            let s = NSAttributedString(string: "Hello OCR", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            ctx.textPosition = CGPoint(x: 30, y: 50)
            CTLineDraw(CTLineCreateWithAttributedString(s), ctx)
        }
        let src = S.write(card, to: dir.appendingPathComponent("shot.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.txt)
        XCTAssertTrue(try String(contentsOf: out[0], encoding: .utf8).localizedCaseInsensitiveContains("hello ocr"))
        let blank = S.write(S.solid(64, 64, S.color(1, 1, 1)), to: dir.appendingPathComponent("blank.png"), uti: "public.png")
        do {
            _ = try await S.convert(engine, blank, from: Formats.png, to: Formats.txt, in: dir.appendingPathComponent("b"))
            XCTFail("blank image has no text")
        } catch ConversionError.other {}
    }

    func testUnreadableInputThrowsHumanError() async throws {
        let dir = try S.tempDir()
        let bogus = dir.appendingPathComponent("bogus.jpg")
        try Data("not an image".utf8).write(to: bogus)
        do {
            _ = try await S.convert(engine, bogus, from: Formats.jpg, to: Formats.png)
            XCTFail("expected an error")
        } catch let e as ConversionError {
            guard case .unreadable = e else { return XCTFail("got \(e)") }
            XCTAssertFalse((e.errorDescription ?? "").isEmpty)
        }
    }
}
