import XCTest
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers
@testable import HaloCore

/// Shared fixtures for lane G1 tests: generated images, a temp workspace, and
/// a runner harness. Nothing is read from disk except what the tests write.
enum G1 {
    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Bundled engines: $HALO_ENGINES_DIR, else walk up from this file to a checkout's Engines/dist.
    static let locator: EngineLocator = {
        var dirs: [URL] = []
        if let d = ProcessInfo.processInfo.environment["HALO_ENGINES_DIR"], !d.isEmpty {
            dirs.append(URL(fileURLWithPath: d).appendingPathComponent("Helpers"))
        }
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<10 {
            let c = dir.appendingPathComponent("Engines/dist/Helpers")
            if FileManager.default.fileExists(atPath: c.appendingPathComponent("ffmpeg").path) { dirs.append(c) }
            dir.deleteLastPathComponent()
        }
        return EngineLocator(helperDirectories: dirs + EngineLocator.shared.helperDirectories)
    }()

    static var context: EngineContext { EngineContext(locator: locator) }

    static func tempDir(_ name: String = #function) throws -> URL {
        let safe = name.replacingOccurrences(of: "()", with: "")
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("halo-g1-\(safe)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    // MARK: Images

    /// Deterministic "photo-like" image: smooth gradients plus mild noise.
    static func photo(width: Int = 320, height: Int = 240, alpha: Bool = false, seed: UInt64 = 1) -> CGImage {
        var rng = RedactNoise(seed: seed)
        var px = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                let fx = Double(x) / Double(width), fy = Double(y) / Double(height)
                let n = Double(rng.unit()) * 24 - 12
                px[i] = UInt8(max(0, min(255, 40 + 180 * fx + n)))
                px[i + 1] = UInt8(max(0, min(255, 60 + 150 * fy + n)))
                px[i + 2] = UInt8(max(0, min(255, 200 - 120 * fx * fy + n)))
                px[i + 3] = alpha ? UInt8(max(0, min(255, 255 * (1 - fx * 0.7)))) : 255
            }
        }
        return image(fromRGBA: px, width: width, height: height, alpha: alpha)
    }

    /// Uniform random noise (every pixel independent): used where tests check
    /// that no original value survives.
    static func noise(width: Int, height: Int, seed: UInt64 = 7) -> CGImage {
        var rng = RedactNoise(seed: seed)
        var px = [UInt8](repeating: 255, count: width * height * 4)
        for i in stride(from: 0, to: px.count, by: 4) {
            px[i] = UInt8(rng.next() & 0xFF); px[i + 1] = UInt8(rng.next() & 0xFF); px[i + 2] = UInt8(rng.next() & 0xFF)
        }
        return image(fromRGBA: px, width: width, height: height, alpha: false)
    }

    static func solid(width: Int, height: Int, r: UInt8, g: UInt8, b: UInt8) -> CGImage {
        var px = [UInt8](repeating: 255, count: width * height * 4)
        for i in stride(from: 0, to: px.count, by: 4) { px[i] = r; px[i + 1] = g; px[i + 2] = b }
        return image(fromRGBA: px, width: width, height: height, alpha: false)
    }

    /// Straight (unpremultiplied) RGBA → CGImage.
    static func image(fromRGBA px: [UInt8], width: Int, height: Int, alpha: Bool) -> CGImage {
        var premul = px
        if alpha {
            for i in stride(from: 0, to: premul.count, by: 4) {
                let a = Int(premul[i + 3])
                for k in 0..<3 { premul[i + k] = UInt8(Int(premul[i + k]) * a / 255) }
            }
        }
        let info: CGImageAlphaInfo = alpha ? .premultipliedLast : .noneSkipLast
        let provider = CGDataProvider(data: Data(premul) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: srgb,
                       bitmapInfo: CGBitmapInfo(rawValue: info.rawValue), provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }

    @discardableResult
    static func write(_ image: CGImage, to url: URL, type: UTType, quality: Double = 0.9, properties: [String: Any] = [:]) throws -> URL {
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        var p = properties
        p[kCGImageDestinationLossyCompressionQuality as String] = quality
        CGImageDestinationAddImage(dest, image, p as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    static func decode(_ url: URL) throws -> CGImage {
        let src = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(src, 0, nil))
    }

    static func properties(_ url: URL) -> [String: Any] {
        ToolImageSupport.properties(of: url) ?? [:]
    }

    /// Straight RGBA8 sRGB pixels of a file or image.
    static func pixels(_ image: CGImage) -> [UInt8] {
        ToolImageSupport.rgba8(image, colorSpace: srgb)?.pixels ?? []
    }

    static func pixel(_ px: [UInt8], width: Int, x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        let i = (y * width + x) * 4
        return (Int(px[i]), Int(px[i + 1]), Int(px[i + 2]), Int(px[i + 3]))
    }

    static func meanRGB(_ image: CGImage) -> (r: Double, g: Double, b: Double) {
        let px = pixels(image)
        var r = 0.0, g = 0.0, b = 0.0
        let n = Double(px.count / 4)
        for i in stride(from: 0, to: px.count, by: 4) { r += Double(px[i]); g += Double(px[i + 1]); b += Double(px[i + 2]) }
        return (r / n, g / n, b / n)
    }

    static func fileSize(_ url: URL) -> Int { (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 }

    // MARK: Running tools

    static func run(_ tool: ToolID, inputs: [URL], options: OptionValues = OptionValues(), metadata: MetadataPolicy = .keep,
                    in dir: URL, baseName: String = "out") async throws -> [URL] {
        let runner = try XCTUnwrap(ToolRegistry(ImageToolRunners.all)[tool], "no runner for \(tool)")
        let defaults = ToolCatalog.spec(tool)?.defaultOptions ?? OptionValues()
        let out = dir.appendingPathComponent("out-\(UUID().uuidString.prefix(6))", isDirectory: true)
        let request = ToolRequest(tool: tool, inputs: inputs, options: defaults.merging(options), outputDirectory: out,
                                  baseName: baseName, metadata: metadata)
        let result = try await runner.run(request, context: context)
        for f in result.files {
            XCTAssertEqual(f.deletingLastPathComponent().standardizedFileURL.path, out.standardizedFileURL.path, "tool wrote outside its output directory")
            XCTAssertTrue(FileManager.default.fileExists(atPath: f.path))
        }
        // Scratch folders must be gone.
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: out.path))?.filter { $0.hasPrefix(".halo-scratch") } ?? []
        XCTAssertEqual(leftovers, [])
        return result.files
    }

    /// 1 s mono 440 Hz WAV (16-bit PCM).
    static func writeWAV(to url: URL, seconds: Double = 1, rate: Int = 44_100) throws {
        let n = Int(Double(rate) * seconds)
        var d = Data()
        func le32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func le16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }
        d.append(Data("RIFF".utf8)); le32(UInt32(36 + n * 2)); d.append(Data("WAVE".utf8))
        d.append(Data("fmt ".utf8)); le32(16); le16(1); le16(1); le32(UInt32(rate)); le32(UInt32(rate * 2)); le16(2); le16(16)
        d.append(Data("data".utf8)); le32(UInt32(n * 2))
        for i in 0..<n { le16(UInt16(bitPattern: Int16(sin(Double(i) * 2 * .pi * 440 / Double(rate)) * 12_000))) }
        try d.write(to: url)
    }

    static var ffmpeg: FFmpeg { FFmpeg(locator: locator) }
}
