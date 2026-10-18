import XCTest
import ImageIO
import CoreGraphics
@testable import HaloCore

/// Shared helpers for lane D tests: tiny generated images, conversions through an
/// engine with an explicit locator, and pixel/metadata readers.
enum ImageTestSupport {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    static let p3 = CGColorSpace(name: CGColorSpace.displayP3)!

    /// Bundled engines: HALO_ENGINES_DIR, else walk up from this file to a checkout's Engines/dist.
    static let enginesDir: URL? = {
        if let d = ProcessInfo.processInfo.environment["HALO_ENGINES_DIR"], !d.isEmpty {
            let u = URL(fileURLWithPath: d)
            if FileManager.default.isExecutableFile(atPath: u.appendingPathComponent("Helpers/ffmpeg").path) { return u }
        }
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            let candidate = dir.appendingPathComponent("Engines/dist")
            if FileManager.default.isExecutableFile(atPath: candidate.appendingPathComponent("Helpers/ffmpeg").path) { return candidate }
            dir.deleteLastPathComponent()
        }
        return nil
    }()

    static let locator: EngineLocator = {
        guard let enginesDir else { return EngineLocator(helperDirectories: []) }
        // Engines' isAvailable reads EngineLocator.shared; point it at the bundled engines
        // before anything touches it (it is initialised lazily on first use).
        setenv("HALO_ENGINES_DIR", enginesDir.path, 0)
        return EngineLocator(helperDirectories: [enginesDir.appendingPathComponent("Helpers")])
    }()

    static var context: EngineContext { EngineContext(locator: locator) }
    static var hasFFmpeg: Bool { locator.ffmpeg != nil }
    static var hasResvg: Bool { locator.resvg != nil }

    static var repoRoot: URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { dir.deleteLastPathComponent() } // Image → Core → Unit → Tests
        return dir.deletingLastPathComponent()
    }

    static func tempDir(_ name: String = #function) throws -> URL {
        let safe = name.filter { $0.isLetter || $0.isNumber }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("halo-imgtests-\(safe)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: Making images

    /// `width`×`height` image; `draw` paints with CG's bottom-left origin.
    static func image(_ width: Int, _ height: Int, space: CGColorSpace = sRGB, alpha: Bool = true, bits: Int = 8,
                      draw: (CGContext) -> Void) -> CGImage {
        var info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        if bits == 16 { info |= CGBitmapInfo.byteOrder16Little.rawValue }
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: bits, bytesPerRow: 0, space: space, bitmapInfo: info)!
        draw(ctx)
        return ctx.makeImage()!
    }

    static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1, space: CGColorSpace = sRGB) -> CGColor {
        CGColor(colorSpace: space, components: [r, g, b, a])!
    }

    static func solid(_ width: Int, _ height: Int, _ c: CGColor, space: CGColorSpace = sRGB, alpha: Bool = true) -> CGImage {
        image(width, height, space: space, alpha: alpha) { ctx in
            ctx.setFillColor(c)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    /// Left half red, right half blue (stored pixels).
    static func leftRedRightBlue(_ width: Int = 40, _ height: Int = 20) -> CGImage {
        image(width, height, alpha: false) { ctx in
            ctx.setFillColor(color(1, 0, 0)); ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            ctx.setFillColor(color(0, 0, 1)); ctx.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        }
    }

    /// Deterministic noise so lossy encoders have something to work on.
    static func noise(_ width: Int, _ height: Int, seed: UInt64 = 42) -> CGImage {
        var state = seed
        return image(width, height, alpha: false) { ctx in
            for y in stride(from: 0, to: height, by: 4) {
                for x in stride(from: 0, to: width, by: 4) {
                    state = state &* 6364136223846793005 &+ 1442695040888963407
                    let v = CGFloat((state >> 33) & 0xFF) / 255
                    ctx.setFillColor(color(v, CGFloat(x) / CGFloat(width), CGFloat(y) / CGFloat(height)))
                    ctx.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }

    @discardableResult
    static func write(_ images: [CGImage], to url: URL, uti: String, properties: [CFString: Any] = [:],
                      frameProperties: [[CFString: Any]]? = nil, container: [CFString: Any]? = nil) -> URL {
        let dest = CGImageDestinationCreateWithURL(url as CFURL, uti as CFString, images.count, nil)!
        if let container { CGImageDestinationSetProperties(dest, container as CFDictionary) }
        for (i, img) in images.enumerated() {
            let props = frameProperties?[i] ?? properties
            CGImageDestinationAddImage(dest, img, props as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(dest), "encode \(url.lastPathComponent)")
        return url
    }

    @discardableResult
    static func write(_ image: CGImage, to url: URL, uti: String, properties: [CFString: Any] = [:]) -> URL {
        write([image], to: url, uti: uti, properties: properties)
    }

    /// Five-frame animated GIF, frame i is solid colour i, delays 0.1…0.5 s.
    static func animatedGIF(at url: URL, size: Int = 32) -> URL {
        let colors = [color(1, 0, 0), color(0, 1, 0), color(0, 0, 1), color(1, 1, 0), color(1, 0, 1)]
        let frames = colors.map { solid(size, size, $0) }
        let props = (0..<5).map { i in [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1 * Double(i + 1)]] as [CFString: Any] }
        return write(frames, to: url, uti: "com.compuserve.gif", frameProperties: props,
                     container: [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]])
    }

    // MARK: Converting

    static func convert(_ engine: any ConversionEngine, _ input: URL, from: FormatID, to: FormatID,
                        options: [String: OptionValue] = [:], metadata: MetadataPolicy = .keep,
                        baseName: String = "out", in dir: URL? = nil) async throws -> [URL] {
        let outDir = try dir ?? tempDir("out")
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let request = ConversionRequest(inputs: [input], from: from, to: to, options: OptionValues(options),
                                        outputDirectory: outDir, baseName: baseName, metadata: metadata)
        return try await engine.convert(request, context: context).files
    }

    // MARK: Reading

    static func source(_ url: URL) -> CGImageSource? { CGImageSourceCreateWithURL(url as CFURL, nil) }

    static func decode(_ url: URL, index: Int = 0) -> CGImage? {
        source(url).flatMap { CGImageSourceCreateImageAtIndex($0, index, nil) }
    }

    static func properties(_ url: URL, index: Int = 0) -> [String: Any] {
        guard let s = source(url) else { return [:] }
        return (CGImageSourceCopyPropertiesAtIndex(s, index, nil) as? [String: Any]) ?? [:]
    }

    static func count(_ url: URL) -> Int { source(url).map(CGImageSourceGetCount) ?? 0 }

    /// RGBA 0–255 of pixel (x, y), top-left origin, converted to sRGB.
    static func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [Int] {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: sRGB,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
        return [Int(p[0]), Int(p[1]), Int(p[2]), Int(p[3])]
    }

    static func assertColor(_ px: [Int], _ expected: [Int], tolerance: Int = 12, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let ok = zip(px, expected).allSatisfy { abs($0 - $1) <= tolerance }
        XCTAssertTrue(ok, "pixel \(px) ≠ \(expected) ±\(tolerance) \(message)", file: file, line: line)
    }

    static func fileSize(_ url: URL) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.intValue ?? 0
    }

    /// ffprobe frame count for animations: the longest video stream. (Animated AVIF
    /// exposes two: the still primary item, then the image sequence track.)
    static func probeFrameCount(_ url: URL) throws -> Int {
        guard let ffprobe = locator.ffprobe else { throw XCTSkip("ffprobe not bundled") }
        let p = Process()
        p.executableURL = ffprobe
        p.arguments = ["-v", "error", "-count_frames", "-select_streams", "v", "-show_entries", "stream=nb_read_frames", "-of", "csv=p=0", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        p.waitUntilExit()
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return text.split(whereSeparator: \.isNewline).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.max() ?? -1
    }
}
