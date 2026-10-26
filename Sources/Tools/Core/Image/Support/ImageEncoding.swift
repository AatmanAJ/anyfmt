import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Writes CGImages in any format the image tools output. ImageIO first; the
/// bundled ffmpeg (libwebp, libaom) for WebP always and AVIF when this macOS
/// has no native AVIF encoder (research/PLATFORM_RESEARCH.md §C).
struct ToolImageEncoder: Sendable {
    let ffmpeg: FFmpeg
    /// Private scratch folder inside the request's output directory (ffmpeg round trips).
    let scratch: URL
    /// Use the ffmpeg AVIF path even where ImageIO can encode AVIF (tests the macOS < 26 route).
    var forceFFmpegAVIF = false

    init(context: EngineContext, scratch: URL) {
        self.ffmpeg = FFmpeg(locator: context.locator)
        self.scratch = scratch
    }

    /// Encodes `image` as `format`. `quality` is 0…1 for lossy formats and
    /// ignored otherwise. `properties` are top-level ImageIO metadata dictionaries.
    func encode(_ image: CGImage, as format: FormatID, quality: Double?, properties: [String: Any]) async throws -> Data {
        try Task.checkCancellation()
        switch format {
        case Formats.webp:
            return try await encodeWithFFmpeg(image, format: format, quality: quality ?? 0.85)
        case Formats.avif where !ToolImageFormats.nativeAVIF || forceFFmpegAVIF:
            return try await encodeWithFFmpeg(image, format: format, quality: quality ?? 0.8)
        default:
            guard let type = ToolImageFormats.destinationType(for: format) else {
                throw ConversionError.unsupported(from: format, to: format)
            }
            return try Self.encodeNative(image, type: type, quality: ToolImageFormats.isLossy(format) ? (quality ?? 0.9) : nil,
                                         properties: properties, format: format)
        }
    }

    static func encodeNative(_ image: CGImage, type: String, quality: Double?, properties: [String: Any], format: FormatID) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, type as CFString, 1, nil) else {
            throw ConversionError.engineFailed("ImageIO", status: -1, detail: "no destination for \(type)")
        }
        var props = properties
        if let quality { props[kCGImageDestinationLossyCompressionQuality as String] = min(1, max(0, quality)) }
        if format == Formats.tiff {
            var tiff = (props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]) ?? [:]
            tiff[kCGImagePropertyTIFFCompression as String] = 5 // LZW
            props[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.engineFailed("ImageIO", status: -1, detail: "finalize failed for \(type)")
        }
        return data as Data
    }

    private func encodeWithFFmpeg(_ image: CGImage, format: FormatID, quality: Double) async throws -> Data {
        guard ffmpeg.isAvailable else {
            throw ConversionError.engineMissing("ffmpeg", detail: "needed to write \(Formats.label(format))")
        }
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let token = UUID().uuidString
        let png = scratch.appendingPathComponent("in-\(token).png")
        let out = scratch.appendingPathComponent("out-\(token).\(Formats.extension(for: format))")
        defer {
            try? FileManager.default.removeItem(at: png)
            try? FileManager.default.removeItem(at: out)
        }
        // ffmpeg ignores ICC profiles, so hand it 8-bit sRGB (what an untagged WebP/AVIF means).
        let srgbImage = try Self.convertedToSRGB8(image)
        try Self.encodeNative(srgbImage, type: UTType.png.identifier, quality: nil, properties: [:], format: Formats.png).write(to: png)
        var args = ["-i", png.path, "-map_metadata", "-1", "-frames:v", "1"]
        let q = Int((min(1, max(0, quality)) * 100).rounded())
        if format == Formats.webp {
            args += ["-c:v", "libwebp", "-compression_level", "5"]
            args += q >= 100 ? ["-lossless", "1"] : ["-quality", String(max(1, q))]
        } else {
            // AV1 still: CRF 10 (q 100) … 60 (q 0).
            let crf = Int((60 - Double(q) * 0.5).rounded())
            args += ["-c:v", "libaom-av1", "-still-picture", "1", "-crf", String(crf), "-b:v", "0", "-cpu-used", "6",
                     "-pix_fmt", "yuv420p", "-f", "avif"]
        }
        args.append(out.path)
        try await ffmpeg.run(args)
        return try Data(contentsOf: out)
    }

    static func convertedToSRGB8(_ image: CGImage) throws -> CGImage {
        if image.bitsPerComponent == 8, let cs = image.colorSpace, cs.name == CGColorSpace.sRGB { return image }
        let opaque = !ToolImageSupport.hasAlpha(image)
        guard let ctx = ToolImageSupport.makeContext(width: image.width, height: image.height, colorSpace: ToolImageSupport.srgb,
                                                 deep: false, opaque: opaque) else {
            throw ConversionError.other(L("The image couldn’t be processed."), detail: "sRGB context")
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let out = ctx.makeImage() else { throw ConversionError.other(L("The image couldn’t be processed."), detail: "sRGB makeImage") }
        return out
    }
}

/// What the image tools can read and write on this Mac.
public enum ToolImageFormats {
    /// ImageIO destination types available at runtime.
    static let destinationTypes: Set<String> = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])

    static var nativeAVIF: Bool { destinationTypes.contains("public.avif") }

    /// ImageIO destination UTI for a format, if ImageIO can write it here.
    static func destinationType(for format: FormatID) -> String? {
        let type: String? = switch format {
        case Formats.jpg: UTType.jpeg.identifier
        case Formats.png: UTType.png.identifier
        case Formats.heic, Formats.heif: "public.heic"
        case Formats.tiff: UTType.tiff.identifier
        case Formats.gif: UTType.gif.identifier
        case Formats.bmp: UTType.bmp.identifier
        case Formats.avif: "public.avif"
        case Formats.jp2: "public.jpeg-2000"
        case Formats.psd: "com.adobe.photoshop-image"
        case Formats.tga: "com.truevision.tga-image"
        case Formats.exr: "com.ilm.openexr-image"
        default: nil
        }
        guard let type, destinationTypes.contains(type) else { return nil }
        return type
    }

    static func isLossy(_ format: FormatID) -> Bool {
        [Formats.jpg, Formats.heic, Formats.heif, Formats.webp, Formats.avif, Formats.jp2].contains(format)
    }

    /// True when anyfmt can write `format` (natively or via ffmpeg).
    public static func canWrite(_ format: FormatID) -> Bool {
        format == Formats.webp || format == Formats.avif || destinationType(for: format) != nil
    }

    /// The format an image tool writes for an input: the same format whenever
    /// we can write it, otherwise the closest sensible one (RAW → JPG; icons,
    /// JPEG XL and anything else → PNG).
    public static func outputFormat(for input: FormatID?) -> FormatID {
        guard let input else { return Formats.png }
        if input == Formats.raw { return Formats.jpg }
        if input == Formats.ico || input == Formats.icns { return Formats.png }
        return canWrite(input) ? input : Formats.png
    }

    /// Default quality (0…1) when a tool re-encodes a lossy format without a quality choice.
    static func reencodeQuality(_ format: FormatID) -> Double {
        format == Formats.jpg ? 0.92 : 0.9
    }
}

/// Where a tool writes: `<outputDirectory>/<baseName>.<ext>`, never over an
/// existing file, plus a private scratch folder that is removed afterwards.
struct ToolOutput {
    let request: ToolRequest

    func url(ext: String) throws -> URL {
        try FileManager.default.createDirectory(at: request.outputDirectory, withIntermediateDirectories: true)
        return OutputNamer.freeURL(in: request.outputDirectory, base: request.baseName, ext: ext)
    }

    func url(for format: FormatID) throws -> URL { try url(ext: Formats.extension(for: format)) }

    var scratch: URL { request.outputDirectory.appendingPathComponent(".anyfmt-scratch-\(UUID().uuidString)", isDirectory: true) }

    /// Writes `data` to a fresh URL and returns it.
    func write(_ data: Data, ext: String) throws -> URL {
        let u = try url(ext: ext)
        try data.write(to: u, options: .withoutOverwriting)
        return u
    }
}

/// Standard "decode → transform → encode" body shared by the pixel tools.
struct PixelToolPipeline {
    let request: ToolRequest
    let context: EngineContext

    /// Decodes the first input, lets `transform` produce new pixels, and
    /// writes them in the tool's output format with the metadata policy applied.
    func run(outputFormat: FormatID? = nil, quality: Double? = nil,
             _ transform: (ToolDecodedImage) async throws -> CGImage) async throws -> ConversionOutput {
        guard let input = request.inputs.first else { throw ConversionError.invalidOption("inputs") }
        let decoded = try ToolImageSupport.decode(input)
        context.progress(0.2)
        // Animated GIF in, GIF out: run the transform on every frame.
        if (outputFormat ?? Formats.gif) == Formats.gif, decoded.format == Formats.gif, let animation = ToolAnimatedGIF.read(input) {
            var frames: [ToolAnimatedGIF.Frame] = []
            for (i, f) in animation.frames.enumerated() {
                try Task.checkCancellation()
                let frame = ToolDecodedImage(image: f.image, format: decoded.format, typeIdentifier: decoded.typeIdentifier,
                                         properties: decoded.properties, sourceOrientation: .up, fileSize: decoded.fileSize)
                frames.append(ToolAnimatedGIF.Frame(image: try await transform(frame), delay: f.delay))
                context.progress(0.2 + 0.7 * Double(i + 1) / Double(animation.frames.count))
            }
            let url = try ToolOutput(request: request).write(try ToolAnimatedGIF.encode(.init(frames: frames, loopCount: animation.loopCount)), ext: "gif")
            context.progress(1)
            return ConversionOutput(url)
        }
        let image = try await transform(decoded)
        try Task.checkCancellation()
        context.progress(0.7)
        let format = outputFormat ?? ToolImageFormats.outputFormat(for: decoded.format)
        let out = ToolOutput(request: request)
        let scratch = out.scratch
        defer { try? FileManager.default.removeItem(at: scratch) }
        let encoder = ToolImageEncoder(context: context, scratch: scratch)
        let props = ToolMetadataFilter.properties(decoded.properties, policy: request.metadata, for: format)
        let data = try await encoder.encode(image, as: format, quality: quality ?? ToolImageFormats.reencodeQuality(format), properties: props)
        let url = try out.write(data, ext: Formats.extension(for: format))
        context.progress(1)
        return ConversionOutput(url)
    }
}
