import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Tool 1: Compress. Three modes (ToolSchemas.compress):
/// - quality: encode at the chosen quality;
/// - size: highest quality that fits the target (binary search on quality,
///   then Lanczos downscaling if even the lowest quality is too big);
/// - percent: size mode with target = percent × original bytes.
/// Lossy formats (JPG, HEIC, WebP, AVIF, JP2) search quality. PNG has no
/// quality knob, so it is quantised honestly: lossless first, then palette
/// PNGs of 256 → 32 colours (dithered, full alpha), then downscaling. Other
/// lossless formats (TIFF, GIF, BMP …) only downscale. Never returns a file
/// larger than the original in the same format.
struct CompressImageRunner: ToolRunner {
    let id = ToolIDs.compressImage

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let input = request.inputs.first else { throw ConversionError.invalidOption("inputs") }
        let decoded = try ImageSupport.decode(input)
        let format = ImageFormats.outputFormat(for: decoded.format)
        let output = ToolOutput(request: request)
        let scratch = output.scratch
        defer { try? FileManager.default.removeItem(at: scratch) }
        let compressor = ImageCompressor(
            image: decoded.image, format: format,
            properties: MetadataFilter.properties(decoded.properties, policy: request.metadata, for: format),
            dpi: (decoded.properties[kCGImagePropertyDPIWidth as String] as? NSNumber)?.doubleValue,
            encoder: ImageEncoder(context: context, scratch: scratch), progress: context.progress)

        let o = request.options
        let original = decoded.fileSize
        let sameFormat = decoded.format == format
        // Copying the original is only honest when its metadata may travel as-is.
        let canReuseOriginal = sameFormat && request.metadata == .keep && decoded.sourceOrientation == .up
        let mode = o.string(OptionKey.sizeMode, default: "quality")
        var data: Data
        if format == Formats.gif, let animation = AnimatedGIF.read(input) {
            // Animated GIFs: GIF has no quality knob, so re-encode, then shrink every frame until it fits.
            let target: Int? = switch mode {
            case "size": max(1, o.int(OptionKey.targetSize, default: 1_000_000))
            case "percent": max(1, Int(Double(original) * Double(min(100, max(1, o.int(OptionKey.percent, default: 50)))) / 100))
            default: nil
            }
            if let t = target, canReuseOriginal, original > 0, original <= t {
                data = try Data(contentsOf: input)
            } else {
                data = try Self.fitAnimated(animation, target: target, progress: context.progress)
                if target == nil, canReuseOriginal, original > 0, data.count >= original { data = try Data(contentsOf: input) }
            }
            let url = try output.write(data, ext: "gif")
            context.progress(1)
            return ConversionOutput(url)
        }
        switch mode {
        case "size", "percent":
            let target = mode == "size"
                ? max(1, o.int(OptionKey.targetSize, default: 1_000_000))
                : max(1, Int(Double(original) * Double(min(100, max(1, o.int(OptionKey.percent, default: 50)))) / 100))
            if canReuseOriginal, original > 0, original <= target {
                data = try Data(contentsOf: input)
            } else {
                data = try await compressor.fit(target: sameFormat && original > 0 ? min(target, original) : target)
            }
        default:
            let q = min(100, max(1, o.int(OptionKey.quality, default: 70)))
            data = try await compressor.encode(quality: q)
            if canReuseOriginal, original > 0, data.count >= original {
                data = try Data(contentsOf: input)
            }
        }
        let url = try output.write(data, ext: Formats.extension(for: format))
        context.progress(1)
        return ConversionOutput(url)
    }
}

extension CompressImageRunner {
    /// Re-encodes an animation; with a target, scales all frames down together until it fits.
    static func fitAnimated(_ animation: AnimatedGIF.Animation, target: Int?, progress: ProgressSink) throws -> Data {
        var data = try AnimatedGIF.encode(animation)
        guard let target, data.count > target, let first = animation.frames.first?.image else { return data }
        var scale = 1.0
        for round in 0..<8 {
            try Task.checkCancellation()
            progress(min(0.9, 0.2 + Double(round) * 0.1))
            scale *= min(0.9, max(0.3, (Double(target) / Double(data.count)).squareRoot() * 0.95))
            let w = max(1, Int((Double(first.width) * scale).rounded())), h = max(1, Int((Double(first.height) * scale).rounded()))
            guard w >= 8, h >= 8 else { break }
            data = try AnimatedGIF.encode(AnimatedGIF.map(animation) { try ImageSupport.resample($0, width: w, height: h) })
            if data.count <= target { return data }
        }
        let want = ByteCountFormatter.string(fromByteCount: Int64(target), countStyle: .file)
        throw ConversionError.other(L("This animation can’t be made as small as \(want)."), detail: "animated GIF fit failed, last \(data.count)")
    }
}

/// Size/quality search for one image in one format.
struct ImageCompressor {
    let image: CGImage
    let format: FormatID
    let properties: [String: Any]
    let dpi: Double?
    let encoder: ImageEncoder
    var progress: ProgressSink = .ignore

    private var isLossy: Bool { ImageFormats.isLossy(format) }

    /// Quality mode. For PNG, quality picks a palette size (≥ 95 stays lossless).
    func encode(quality q: Int) async throws -> Data {
        if isLossy { return try await encoder.encode(image, as: format, quality: Double(q) / 100, properties: properties) }
        if format == Formats.png {
            let lossless = try await encoder.encode(image, as: format, quality: nil, properties: properties)
            guard q < 95 else { return lossless }
            let colors = q >= 70 ? 256 : q >= 50 ? 128 : q >= 30 ? 64 : q >= 15 ? 32 : 16
            if let palette = quantizedPNG(image, colors: colors), palette.count < lossless.count { return palette }
            return lossless
        }
        return try await encoder.encode(image, as: format, quality: nil, properties: properties)
    }

    /// Largest/best encoding with `count <= target`. Throws if even a tiny
    /// downscaled version doesn't fit.
    func fit(target: Int) async throws -> Data {
        var current = image
        var smallest: Data?
        for round in 0..<10 {
            try Task.checkCancellation()
            progress(min(0.9, 0.1 + Double(round) * 0.1))
            let (best, floor) = try await bestFit(current, target: target)
            if let best { return best }
            if smallest == nil || floor.count < (smallest?.count ?? .max) { smallest = floor }
            // Even the most compact encoding is too big: shrink and retry.
            let ratio = Double(target) / Double(max(1, floor.count))
            let scale = min(0.9, max(0.2, ratio.squareRoot() * 0.95))
            let w = Int((Double(current.width) * scale).rounded()), h = Int((Double(current.height) * scale).rounded())
            guard w >= 8, h >= 8 else { break }
            current = try ImageSupport.resample(current, width: w, height: h)
        }
        let got = ByteCountFormatter.string(fromByteCount: Int64(smallest?.count ?? 0), countStyle: .file)
        let want = ByteCountFormatter.string(fromByteCount: Int64(target), countStyle: .file)
        throw ConversionError.other(L("This image can’t be made as small as \(want). The smallest \(Brand.name) could make was \(got)."),
                                    detail: "compress fit failed for \(format), target \(target)")
    }

    /// Best encoding of `img` within `target`, and the most compact encoding tried.
    private func bestFit(_ img: CGImage, target: Int) async throws -> (Data?, Data) {
        if isLossy {
            let lo = 0.02
            let low = try await encoder.encode(img, as: format, quality: lo, properties: properties)
            guard low.count <= target else { return (nil, low) }
            let high = try await encoder.encode(img, as: format, quality: 1, properties: properties)
            if high.count <= target { return (high, low) }
            var best = low, a = lo, b = 1.0
            for _ in 0..<8 {
                let mid = (a + b) / 2
                let d = try await encoder.encode(img, as: format, quality: mid, properties: properties)
                if d.count <= target {
                    best = d; a = mid
                    if Double(d.count) >= Double(target) * 0.97 { break } // close enough
                } else {
                    b = mid
                }
            }
            return (best, low)
        }
        if format == Formats.png {
            let lossless = try await encoder.encode(img, as: format, quality: nil, properties: properties)
            if lossless.count <= target { return (lossless, lossless) }
            var smallest = lossless
            for colors in [256, 128, 64, 32] {
                try Task.checkCancellation()
                guard let d = quantizedPNG(img, colors: colors) else { continue }
                if d.count < smallest.count { smallest = d }
                if d.count <= target { return (d, smallest) }
            }
            return (nil, quantizedPNG(img, colors: 256) ?? smallest)
        }
        let d = try await encoder.encode(img, as: format, quality: nil, properties: properties)
        return (d.count <= target ? d : nil, d)
    }

    private func quantizedPNG(_ img: CGImage, colors: Int) -> Data? {
        let cs = ImageSupport.colorSpace(of: img)
        guard let px = ImageSupport.rgba8(img, colorSpace: cs) else { return nil }
        let result = PaletteQuantizer(maxColors: colors).quantize(pixels: px.pixels, width: px.width, height: px.height)
        let meta = MetadataCarrier.pngChunks(properties: properties, width: img.width, height: img.height)
        return PalettePNGWriter.write(result, colorSpace: cs, dpi: dpi, metadataChunks: meta)
    }
}
