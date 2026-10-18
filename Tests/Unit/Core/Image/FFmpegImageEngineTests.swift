import XCTest
import ImageIO
@testable import HaloCore

final class FFmpegImageEngineTests: XCTestCase {
    typealias S = ImageTestSupport
    let engine = FFmpegImageEngine()

    override func setUpWithError() throws {
        guard S.hasFFmpeg else { throw XCTSkip("bundled ffmpeg not found (set HALO_ENGINES_DIR)") }
    }

    func testStillWebPKeepsSizeAlphaAndProfile() async throws {
        let dir = try S.tempDir()
        let p3 = S.image(64, 48, space: S.p3) { ctx in
            ctx.setFillColor(S.color(1, 0, 0, space: S.p3)); ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
            ctx.setFillColor(S.color(0, 0, 1, 0.5, space: S.p3)); ctx.fill(CGRect(x: 32, y: 0, width: 32, height: 48))
        }
        let src = S.write(p3, to: dir.appendingPathComponent("p3.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.webp)
        XCTAssertEqual(out[0].pathExtension, "webp")
        let img = try XCTUnwrap(S.decode(out[0]))
        XCTAssertEqual([img.width, img.height], [64, 48])
        XCTAssertEqual(img.colorSpace?.name as String?, CGColorSpace.displayP3 as String, "ICCP chunk embedded")
        XCTAssertEqual(S.pixel(img, 48, 24)[3], 128, accuracy: 8, "half alpha kept")
        S.assertColor(S.pixel(img, 8, 24), S.pixel(p3, 8, 24), tolerance: 14, "colour survives")
        let container = try XCTUnwrap(WebPContainer(try Data(contentsOf: out[0])))
        XCTAssertEqual(container.chunks.first?.fourCC, "VP8X")
        XCTAssertTrue(container.chunks.contains { $0.fourCC == "ICCP" })
    }

    func testWebPOrientationAndMaxDimension() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.leftRedRightBlue(80, 40), to: dir.appendingPathComponent("o.jpg"), uti: "public.jpeg",
                          properties: [kCGImagePropertyOrientation: 6])
        let out = try await S.convert(engine, src, from: Formats.jpg, to: Formats.webp, options: [OptionKey.maxDimension: .int(40)])
        let img = try XCTUnwrap(S.decode(out[0]))
        XCTAssertEqual([img.width, img.height], [20, 40])
        S.assertColor(S.pixel(img, 10, 4), [255, 0, 0, 255], tolerance: 50, "red on top after rotation")
    }

    func testWebPLosslessAndQuality() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(200, 200), to: dir.appendingPathComponent("n.png"), uti: "public.png")
        let lo = try await S.convert(engine, src, from: Formats.png, to: Formats.webp, options: [OptionKey.quality: .int(10)], in: dir.appendingPathComponent("lo"))
        let hi = try await S.convert(engine, src, from: Formats.png, to: Formats.webp, options: [OptionKey.quality: .int(95)], in: dir.appendingPathComponent("hi"))
        let ll = try await S.convert(engine, src, from: Formats.png, to: Formats.webp, options: [OptionKey.lossless: .bool(true)], in: dir.appendingPathComponent("ll"))
        XCTAssertLessThan(S.fileSize(lo[0]), S.fileSize(hi[0]))
        // Lossless must reproduce the pixels exactly.
        let original = try XCTUnwrap(S.decode(src)), decoded = try XCTUnwrap(S.decode(ll[0]))
        for (x, y) in [(3, 3), (101, 57), (199, 199)] { XCTAssertEqual(S.pixel(decoded, x, y), S.pixel(original, x, y)) }
        XCTAssertTrue(try XCTUnwrap(WebPContainer(try Data(contentsOf: ll[0]))).chunks.contains { $0.fourCC == "VP8L" })
    }

    func testWebPMetadataFollowsPolicy() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(32, 32), to: dir.appendingPathComponent("gps.jpg"), uti: "public.jpeg", properties: [
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 48.85, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Halo"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:18 09:00:00"],
        ])
        let keep = try await S.convert(engine, src, from: Formats.jpg, to: Formats.webp, metadata: .keep, in: dir.appendingPathComponent("keep"))
        let priv = try await S.convert(engine, src, from: Formats.jpg, to: Formats.webp, metadata: .stripPrivate, in: dir.appendingPathComponent("priv"))
        let none = try await S.convert(engine, src, from: Formats.jpg, to: Formats.webp, metadata: .stripAll, in: dir.appendingPathComponent("none"))
        let pk = S.properties(keep[0]), pp = S.properties(priv[0]), pn = S.properties(none[0])
        XCTAssertNotNil(pk["{GPS}"], "keep: GPS in EXIF chunk")
        XCTAssertEqual((pk["{TIFF}"] as? [String: Any])?["Make"] as? String, "Halo")
        XCTAssertNil(pp["{GPS}"], "stripPrivate: no GPS")
        XCTAssertNil((pp["{TIFF}"] as? [String: Any])?["Make"])
        XCTAssertEqual((pp["{Exif}"] as? [String: Any])?["DateTimeOriginal"] as? String, "2026:10:18 09:00:00")
        XCTAssertNil(pn["{GPS}"]); XCTAssertNil(pn["{Exif}"].flatMap { ($0 as? [String: Any])?["DateTimeOriginal"] })
        let chunks = try XCTUnwrap(WebPContainer(try Data(contentsOf: none[0]))).chunks.map(\.fourCC)
        XCTAssertFalse(chunks.contains("EXIF")); XCTAssertFalse(chunks.contains("XMP "))
    }

    func testAnimatedGIFToAnimatedWebPKeepsExactTiming() async throws {
        let dir = try S.tempDir()
        let gif = S.animatedGIF(at: dir.appendingPathComponent("a.gif"))
        let out = try await S.convert(engine, gif, from: Formats.gif, to: Formats.webp)
        XCTAssertEqual(try S.probeFrameCount(out[0]), 5, "ffprobe frame count")
        let container = try XCTUnwrap(WebPContainer(try Data(contentsOf: out[0])))
        XCTAssertEqual(container.frameDurations, [100, 200, 300, 400, 500])
        let input = try ImageInput.open(out[0], format: Formats.webp)
        XCTAssertEqual(input.animation?.frameCount, 5)
        XCTAssertEqual(input.animation?.loopCount, 0)
    }

    func testDuplicateFramesStillTimeCorrectly() async throws {
        let dir = try S.tempDir()
        // Frames 2 and 3 identical: libwebp merges them, total time must still be 0.1+0.2+0.3+0.4.
        let red = S.solid(16, 16, S.color(1, 0, 0)), green = S.solid(16, 16, S.color(0, 1, 0)), blue = S.solid(16, 16, S.color(0, 0, 1))
        let props = [0.1, 0.2, 0.3, 0.4].map { [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: $0]] as [CFString: Any] }
        let gif = S.write([red, green, green, blue], to: dir.appendingPathComponent("d.gif"), uti: "com.compuserve.gif", frameProperties: props,
                          container: [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 3]])
        let out = try await S.convert(engine, gif, from: Formats.gif, to: Formats.webp)
        let c = try XCTUnwrap(WebPContainer(try Data(contentsOf: out[0])))
        XCTAssertEqual(c.frameDurations.reduce(0, +), 1000)
        XCTAssertEqual(try ImageInput.open(out[0], format: Formats.webp).animation?.loopCount, 3)
    }

    func testAVIFFallbackStillWithAlpha() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.solid(64, 64, S.color(0.9, 0.3, 0.1, 0.5)), to: dir.appendingPathComponent("a.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.avif)
        let img = try XCTUnwrap(S.decode(out[0]), "ImageIO must read ffmpeg's AVIF")
        XCTAssertEqual([img.width, img.height], [64, 64])
        let px = S.pixel(img, 32, 32)
        XCTAssertEqual(px[3], 128, accuracy: 10, "alpha plane present")
        // Opaque round trip keeps colour (sRGB tags honoured).
        let opaque = S.write(S.solid(64, 64, S.color(0.9, 0.3, 0.1), alpha: false), to: dir.appendingPathComponent("o.png"), uti: "public.png")
        let o = try await S.convert(engine, opaque, from: Formats.png, to: Formats.avif, in: dir.appendingPathComponent("o"))
        S.assertColor(S.pixel(try XCTUnwrap(S.decode(o[0])), 32, 32), [230, 77, 26, 255], tolerance: 10)
    }

    func testAnimatedGIFToAnimatedAVIF() async throws {
        let dir = try S.tempDir()
        let gif = S.animatedGIF(at: dir.appendingPathComponent("a.gif"))
        let out = try await S.convert(engine, gif, from: Formats.gif, to: Formats.avif)
        XCTAssertEqual(try S.probeFrameCount(out[0]), 5)
        // ImageIO's own AVIF path delegates animated GIFs here too.
        let viaImageIO = try await S.convert(ImageIOEngine(), gif, from: Formats.gif, to: Formats.avif, in: dir.appendingPathComponent("io"))
        XCTAssertEqual(try S.probeFrameCount(viaImageIO[0]), 5)
    }

    func testStillGIFUsesOptimalPaletteAndKeepsTransparency() async throws {
        let dir = try S.tempDir()
        let ramp = S.image(256, 8) { ctx in
            for x in 0..<256 {
                ctx.setFillColor(S.color(CGFloat(x) / 255, CGFloat(x) / 255, CGFloat(x) / 255))
                ctx.fill(CGRect(x: x, y: 2, width: 1, height: 6))
            }
            ctx.clear(CGRect(x: 0, y: 0, width: 256, height: 2)) // bottom two rows transparent
        }
        let src = S.write(ramp, to: dir.appendingPathComponent("ramp.png"), uti: "public.png")
        let out = try await S.convert(engine, src, from: Formats.png, to: Formats.gif)
        let img = try XCTUnwrap(S.decode(out[0]))
        let levels = Set((0..<256).map { S.pixel(img, $0, 2)[0] })
        XCTAssertGreaterThan(levels.count, 150, "a grey ramp keeps most of its 256 levels (got \(levels.count))")
        XCTAssertEqual(S.pixel(img, 100, 7)[3], 0, "transparent rows stay transparent")
    }

    func testAnimatedWebPToGIFKeepsExactTiming() async throws {
        let dir = try S.tempDir()
        let gif = S.animatedGIF(at: dir.appendingPathComponent("a.gif"))
        let webp = try await S.convert(engine, gif, from: Formats.gif, to: Formats.webp, in: dir.appendingPathComponent("w"))
        let back = try await S.convert(engine, webp[0], from: Formats.webp, to: Formats.gif, in: dir.appendingPathComponent("g"))
        XCTAssertEqual(GIFTiming.delays(try Data(contentsOf: back[0])), [10, 20, 30, 40, 50])
        let anim = try XCTUnwrap(try ImageInput.open(back[0], format: Formats.gif).animation)
        XCTAssertEqual(anim.frameCount, 5)
        XCTAssertEqual(anim.loopCount, 0)
        S.assertColor(S.pixel(try XCTUnwrap(S.decode(back[0], index: 2)), 16, 16), [0, 0, 255, 255], tolerance: 16, "frame 3 is blue")
    }

    func testAPNGWithDuplicateFramesToGIFKeepsEveryDelay() async throws {
        let dir = try S.tempDir()
        let red = S.solid(16, 16, S.color(1, 0, 0)), green = S.solid(16, 16, S.color(0, 1, 0)), blue = S.solid(16, 16, S.color(0, 0, 1))
        let props = [0.1, 0.2, 0.3, 0.4].map { [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: $0]] as [CFString: Any] }
        let apng = S.write([red, green, green, blue], to: dir.appendingPathComponent("a.png"), uti: "public.png", frameProperties: props,
                           container: [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]])
        let out = try await S.convert(engine, apng, from: Formats.png, to: Formats.gif)
        let anim = try XCTUnwrap(try ImageInput.open(out[0], format: Formats.gif).animation)
        XCTAssertEqual(anim.delays.reduce(0, +), 1.0, accuracy: 0.02, "total time kept: \(anim.delays)")
        XCTAssertEqual(anim.frameCount, 4)
    }

    func testGIFTimingRejectsMismatchedFrames() throws {
        let dir = try S.tempDir()
        let data = try Data(contentsOf: S.animatedGIF(at: dir.appendingPathComponent("a.gif")))
        XCTAssertEqual(GIFTiming.frameCount(data), 5)
        XCTAssertNil(GIFTiming.apply(data, delays: [0.1, 0.2], loopCount: 0))
        let patched = try XCTUnwrap(GIFTiming.apply(data, delays: [1, 1, 1, 1, 2], loopCount: 7))
        XCTAssertEqual(GIFTiming.delays(patched), [100, 100, 100, 100, 200])
        XCTAssertNil(GIFTiming.frameCount(Data("GIF89a".utf8)))
    }

    func testWorkFolderIsCleanedUp() async throws {
        let dir = try S.tempDir()
        let src = S.write(S.noise(16, 16), to: dir.appendingPathComponent("s.png"), uti: "public.png")
        let outDir = dir.appendingPathComponent("o")
        _ = try await S.convert(engine, src, from: Formats.png, to: Formats.webp, in: outDir)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outDir.path), ["out.webp"])
    }
}
