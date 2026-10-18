import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import HaloCore

/// Metadata edge cases per container: WebP chunks, animated GIF, MP4 location,
/// AVIF, grey images, and the strip-private policy.
final class ContainerMetadataTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws { dir = try G1.tempDir(name) }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testWebPStripDropsEXIFAndXMPChunksLosslessly() async throws {
        // Hand-built extended WebP: VP8X + a VP8L payload copied from a real encode + EXIF + XMP chunks.
        try XCTSkipUnless(G1.ffmpeg.isAvailable)
        let png = try G1.write(G1.photo(width: 32, height: 24), to: dir.appendingPathComponent("s.png"), type: .png)
        let plain = dir.appendingPathComponent("plain.webp")
        try await G1.ffmpeg.run(["-i", png.path, "-c:v", "libwebp", "-lossless", "1", plain.path])
        let base = [UInt8](try Data(contentsOf: plain))
        // Extract the image chunk (after "RIFF....WEBP").
        let image = Array(base[12...])
        func chunk(_ fourcc: String, _ payload: [UInt8]) -> [UInt8] {
            var c = Array(fourcc.utf8)
            let n = UInt32(payload.count)
            c += [UInt8(n & 0xFF), UInt8((n >> 8) & 0xFF), UInt8((n >> 16) & 0xFF), UInt8(n >> 24)]
            c += payload
            if payload.count % 2 == 1 { c.append(0) }
            return c
        }
        let w = 31, h = 23 // canvas minus one
        let vp8x = chunk("VP8X", [0x08 | 0x04, 0, 0, 0, UInt8(w & 0xFF), UInt8(w >> 8), 0, UInt8(h & 0xFF), UInt8(h >> 8), 0])
        let body = vp8x + image + chunk("EXIF", Array("SECRET-EXIF-PAYLOAD".utf8)) + chunk("XMP ", Array("<x:xmpmeta>SECRET</x:xmpmeta>".utf8))
        let size = UInt32(body.count + 4)
        let file = Array("RIFF".utf8) + [UInt8(size & 0xFF), UInt8((size >> 8) & 0xFF), UInt8((size >> 16) & 0xFF), UInt8(size >> 24)] + Array("WEBP".utf8) + body
        let input = dir.appendingPathComponent("meta.webp")
        try Data(file).write(to: input)

        let out = try await G1.run(ToolIDs.stripMetadata, inputs: [input], in: dir)
        let data = try Data(contentsOf: out[0])
        XCTAssertNil(data.range(of: Data("SECRET".utf8)))
        XCTAssertEqual(data[12..<16], Data("VP8X".utf8))
        XCTAssertEqual(data[20] & 0x0C, 0, "EXIF/XMP flags cleared")
        XCTAssertNotNil(data.range(of: Data(image.prefix(64))), "image data untouched")
        let riff = UInt32(data[4]) | UInt32(data[5]) << 8 | UInt32(data[6]) << 16 | UInt32(data[7]) << 24
        XCTAssertEqual(Int(riff), data.count - 8)
    }

    func testAnimatedGIFStripKeepsFrames() async throws {
        let url = dir.appendingPathComponent("anim.gif")
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 3, nil))
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary)
        for i in 0..<3 {
            CGImageDestinationAddImage(dest, G1.solid(width: 20, height: 20, r: UInt8(80 * i), g: 100, b: 200),
                                       [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 0.2]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let out = try await G1.run(ToolIDs.stripMetadata, inputs: [url], in: dir)
        let src = try XCTUnwrap(CGImageSourceCreateWithURL(out[0] as CFURL, nil))
        XCTAssertEqual(CGImageSourceGetCount(src), 3)
        let delay = ((CGImageSourceCopyPropertiesAtIndex(src, 1, nil) as? [String: Any])?[kCGImagePropertyGIFDictionary as String] as? [String: Any])?[kCGImagePropertyGIFDelayTime as String] as? Double
        XCTAssertEqual(delay ?? 0, 0.2, accuracy: 0.01)
    }

    private func makeMP4() async throws -> URL {
        try XCTSkipUnless(G1.ffmpeg.isAvailable, "bundled ffmpeg not found")
        let raw = dir.appendingPathComponent("frames.rgb")
        var bytes = [UInt8](repeating: 0, count: 64 * 48 * 3 * 25)
        for i in bytes.indices { bytes[i] = UInt8((i / 3) % 251) }
        try Data(bytes).write(to: raw)
        let wav = dir.appendingPathComponent("a.wav")
        try G1.writeWAV(to: wav)
        let mp4 = dir.appendingPathComponent("clip.mp4")
        try await G1.ffmpeg.run(["-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "64x48", "-r", "25", "-i", raw.path, "-i", wav.path,
                                 "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest",
                                 "-metadata", "title=Holiday", "-metadata", "location=+46.4523+008.0213/", mp4.path])
        return mp4
    }

    func testMP4EditAndStripLocation() async throws {
        let mp4 = try await makeMP4()
        let snap = try await MetadataReader.read(mp4, locator: G1.locator)
        XCTAssertEqual(snap.value("title"), "Holiday")
        XCTAssertEqual(snap.value("tag.location"), "+46.4523+008.0213/")
        XCTAssertNotNil(snap.value("media.video"))

        let edited = try await G1.run(ToolIDs.editMetadata, inputs: [mp4],
                                      options: OptionValues(["fields": .string(MetadataChanges.encode(["title": "Trip", "artist": "Sam"]))]), in: dir)
        let after = try await MetadataReader.read(edited[0], locator: G1.locator)
        XCTAssertEqual(after.value("title"), "Trip")
        XCTAssertEqual(after.value("artist"), "Sam")

        let stripped = try await G1.run(ToolIDs.stripMetadata, inputs: [mp4], in: dir)
        let probe = try await G1.ffmpeg.probe(stripped[0])
        let tags = probe.format?.tags ?? [:]
        XCTAssertNil(tags["title"])
        XCTAssertNil(tags["location"])
        XCTAssertFalse(tags.keys.contains { $0.lowercased().contains("location") })
        XCTAssertTrue(probe.hasVideo && probe.hasAudio)
        XCTAssertEqual(probe.duration ?? 0, 1, accuracy: 0.15)
    }

    func testAVIFCompressAndStrip() async throws {
        try XCTSkipUnless(ImageFormats.canWrite(Formats.avif))
        let input = try G1.write(G1.photo(width: 320, height: 240), to: dir.appendingPathComponent("p.avif"),
                                 type: try XCTUnwrap(UTType("public.avif")), quality: 0.95,
                                 properties: [kCGImagePropertyGPSDictionary as String: [kCGImagePropertyGPSLatitude as String: 10.0,
                                                                                        kCGImagePropertyGPSLatitudeRef as String: "N"]])
        let small = try await G1.run(ToolIDs.compressImage, inputs: [input], options: OptionValues([OptionKey.quality: .int(30)]), in: dir)
        XCTAssertEqual(small[0].pathExtension, "avif")
        XCTAssertLessThan(G1.fileSize(small[0]), G1.fileSize(input))
        let clean = try await G1.run(ToolIDs.stripMetadata, inputs: [input], in: dir)
        XCTAssertNil(G1.properties(clean[0])[kCGImagePropertyGPSDictionary as String])
    }

    func testFFmpegAVIFFallbackEncodes() async throws {
        try XCTSkipUnless(G1.ffmpeg.isAvailable)
        var encoder = ImageEncoder(context: G1.context, scratch: dir.appendingPathComponent(".scratch"))
        encoder.forceFFmpegAVIF = true
        let hi = try await encoder.encode(G1.photo(width: 160, height: 120), as: Formats.avif, quality: 0.9, properties: [:])
        let lo = try await encoder.encode(G1.photo(width: 160, height: 120), as: Formats.avif, quality: 0.2, properties: [:])
        XCTAssertLessThan(lo.count, hi.count, "quality maps to CRF")
        let url = dir.appendingPathComponent("ff.avif")
        try hi.write(to: url)
        let img = try G1.decode(url)
        XCTAssertEqual(img.width, 160)
        XCTAssertEqual(img.height, 120)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent(".scratch").path)) ?? []
        XCTAssertEqual(leftovers, [], "temporary PNG and AVIF are cleaned up")
    }

    func testGreyJPEGWithOrientationDecodesToRGB() throws {
        let ctx = try XCTUnwrap(CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue))
        ctx.setFillColor(gray: 0.25, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        ctx.setFillColor(gray: 0.9, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 20))
        let url = try G1.write(try XCTUnwrap(ctx.makeImage()), to: dir.appendingPathComponent("g.jpg"), type: .jpeg,
                               properties: [kCGImagePropertyOrientation as String: 6])
        let d = try ImageSupport.decode(url)
        XCTAssertEqual(d.width, 20); XCTAssertEqual(d.height, 40)
        XCTAssertEqual(d.image.colorSpace?.model, .rgb)
        // Rotated 90° clockwise: the bright left stripe is now along the top.
        let p = G1.pixel(G1.pixels(d.image), width: 20, x: 10, y: 2)
        XCTAssertGreaterThan(p.r, 200)
    }

    func testStripPrivateKeepsDescriptiveFields() {
        let source: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFMake as String: "Cam", kCGImagePropertyTIFFCopyright as String: "© Me",
                                                       kCGImagePropertyTIFFOrientation as String: 6],
            kCGImagePropertyGPSDictionary as String: [kCGImagePropertyGPSLatitude as String: 1.0],
            kCGImagePropertyIPTCDictionary as String: [kCGImagePropertyIPTCObjectName as String: "T", kCGImagePropertyIPTCCity as String: "Paris"],
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifDateTimeOriginal as String: "2020:01:01 00:00:00",
                                                       kCGImagePropertyExifBodySerialNumber as String: "123"],
        ]
        let p = MetadataFilter.properties(source, policy: .stripPrivate, for: Formats.jpg)
        let tiff = p[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        XCTAssertNil(tiff?[kCGImagePropertyTIFFMake as String])
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFCopyright as String] as? String, "© Me")
        XCTAssertNil(tiff?[kCGImagePropertyTIFFOrientation as String], "pixels are upright; no stale orientation")
        XCTAssertNil(p[kCGImagePropertyGPSDictionary as String])
        let iptc = p[kCGImagePropertyIPTCDictionary as String] as? [String: Any]
        XCTAssertEqual(iptc?[kCGImagePropertyIPTCObjectName as String] as? String, "T")
        XCTAssertNil(iptc?[kCGImagePropertyIPTCCity as String])
        let exif = p[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertNotNil(exif?[kCGImagePropertyExifDateTimeOriginal as String])
        XCTAssertNil(exif?[kCGImagePropertyExifBodySerialNumber as String])
        XCTAssertEqual(p[kCGImagePropertyOrientation as String] as? Int, 1)
        XCTAssertTrue(MetadataFilter.properties(source, policy: .stripAll, for: Formats.jpg).isEmpty)
    }
}
