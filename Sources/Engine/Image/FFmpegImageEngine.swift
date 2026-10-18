import Foundation
import ImageIO

/// WebP (stills and animations) and the AVIF fallback, through the bundled ffmpeg's
/// libwebp / libwebp_anim / libaom-av1. ImageIO never encodes WebP, and only some
/// macOS versions encode AVIF.
///
/// Pixels always come from our own ImageIO pipeline (oriented, downscaled,
/// colour-managed) as 8-bit PNG intermediates in a private work folder, so ffmpeg
/// never has to interpret colour or orientation. ffmpeg writes no metadata, so for
/// WebP we add the ICC profile, EXIF and XMP chunks ourselves afterwards
/// (`WebPContainer`). AVIF from ffmpeg carries no EXIF/XMP and is converted to sRGB.
public struct FFmpegImageEngine: ConversionEngine {
    public let id = EngineIDs.ffmpegImage
    public init() {}

    public func isAvailable(_ capability: Capability) -> Bool {
        guard EngineLocator.shared.ffmpeg != nil else { return false }
        guard capability.to == Formats.webp || capability.to == Formats.avif else { return false }
        return ImageIOSupport.canDecode(format: capability.from)
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let ffmpeg = FFmpeg(locator: context.locator)
        guard ffmpeg.isAvailable else {
            throw ConversionError.engineMissing("ffmpeg", detail: "not found in \(context.locator.helperDirectories.map(\.path))")
        }
        let input = try ImageInput.open(request.input, format: request.from)
        let out = request.defaultOutputURL
        let work = try WorkFolder(in: request.outputDirectory)
        defer { work.remove() }
        switch request.to {
        case Formats.webp:
            if let anim = input.animation {
                try await Self.animatedWebP(input, animation: anim, options: request.options, to: out, work: work.url, ffmpeg: ffmpeg, progress: context.progress)
            } else {
                let still = try StillPipeline.prepare(input, target: Self.intermediateTarget, options: request.options, policy: request.metadata)
                try await Self.stillWebP(still, policy: request.metadata, options: request.options, to: out, work: work.url, ffmpeg: ffmpeg, progress: context.progress)
            }
        case Formats.avif:
            if input.isAnimated && input.type == ImageUTI.gif {
                try await Self.animatedAVIF(fromGIF: input, options: request.options, to: out, ffmpeg: ffmpeg, progress: context.progress)
            } else {
                var target = Self.intermediateTarget
                target.color = .convertToSRGB
                let still = try StillPipeline.prepare(input, target: target, options: request.options, policy: request.metadata)
                try await Self.stillAVIF(still.image, options: request.options, to: out, work: work.url, ffmpeg: ffmpeg, progress: context.progress)
            }
        default:
            throw ConversionError.unsupported(from: request.from, to: request.to)
        }
        context.progress(1)
        return ConversionOutput(out)
    }

    /// 8-bit RGB(A) in the source's RGB colour space; alpha kept.
    static let intermediateTarget = StillPipeline.Target(keepsAlpha: true, color: .embedProfile, maxBits: 8, requireRGB: true)

    // MARK: WebP

    /// Encodes a prepared still to WebP, then embeds ICC/EXIF/XMP per policy.
    static func stillWebP(_ still: PreparedStill, policy: MetadataPolicy, options: OptionValues, to out: URL,
                          work: URL, ffmpeg: FFmpeg, progress: ProgressSink) async throws {
        let png = work.appendingPathComponent("frame.png")
        try ImageWriter.write(still.image, to: png, uti: ImageUTI.png, options: [:])
        try await ffmpeg.run(["-i", png.path, "-frames:v", "1"] + webpCodecArgs(options, animated: false) + [out.path],
                             duration: nil, progress: progress.scaled(0.2...0.9))
        guard let data = try? Data(contentsOf: out), var container = WebPContainer(data) else {
            throw ConversionError.outputMissing("ffmpeg wrote no readable WebP")
        }
        let space = still.image.colorSpace
        let icc = ImageOps.isSRGB(space) ? nil : space.flatMap { $0.copyICCData() as Data? }
        let exif = policy == .stripAll ? nil : ExifBlob.tiffStructure(from: still.properties)
        let xmp = policy == .keep ? ExifBlob.xmp(still.metadataTree) : nil
        container.embed(icc: icc, exif: exif, xmp: xmp, canvasWidth: still.image.width, canvasHeight: still.image.height,
                        hasAlpha: ImageOps.hasAlpha(still.image))
        try container.data.write(to: out)
    }

    static func webpCodecArgs(_ options: OptionValues, animated: Bool) -> [String] {
        let lossless = options.bool(OptionKey.lossless, default: false)
        let quality = min(100, max(1, options.int(OptionKey.quality, default: 85)))
        // bgra lets libwebp do its own (sharper) RGB→YUV conversion.
        var args = ["-c:v", animated ? "libwebp_anim" : "libwebp", "-pix_fmt", "bgra"]
        if lossless {
            args += ["-lossless", "1", "-quality", "75", "-compression_level", "5"]
        } else {
            args += ["-lossless", "0", "-quality", String(quality), "-compression_level", "4"]
        }
        return args
    }

    /// Animated source → animated WebP. Frames are decoded by ImageIO (fully
    /// composited), fed to libwebp_anim at one frame per millisecond, then every
    /// ANMF duration is rewritten from the source delays (ffmpeg guesses the last one).
    static func animatedWebP(_ input: ImageInput, animation: AnimationInfo, options: OptionValues, to out: URL,
                             work: URL, ffmpeg: FFmpeg, progress: ProgressSink) async throws {
        try writeFrames(input, animation: animation, maxDimension: options.int(OptionKey.maxDimension, default: 0),
                        into: work, progress: progress.scaled(0...0.5))
        let pattern = work.appendingPathComponent("f%06d.png").path
        try await ffmpeg.run(["-framerate", "1000", "-i", pattern] + webpCodecArgs(options, animated: true)
                             + ["-loop", String(animation.loopCount), out.path],
                             duration: Double(animation.frameCount) / 1000, progress: progress.scaled(0.5...0.95))
        guard let data = try? Data(contentsOf: out), var container = WebPContainer(data) else {
            throw ConversionError.outputMissing("ffmpeg wrote no readable animated WebP")
        }
        container.applyTiming(sourceDelays: animation.delays, loopCount: animation.loopCount)
        try container.data.write(to: out)
    }

    /// Writes every frame as sRGB 8-bit PNG `f000001.png`… into `dir`.
    static func writeFrames(_ input: ImageInput, animation: AnimationInfo, maxDimension: Int, into dir: URL, progress: ProgressSink) throws {
        for i in 0..<animation.frameCount {
            try Task.checkCancellation()
            let frame = try ImageOps.decode(input, index: i, maxPixelSize: maxDimension, applyOrientation: false)
            let srgb = ImageOps.prepare(frame, flattenOnto: nil, colorSpace: ImageOps.sRGB, maxBits: 8)
            let url = dir.appendingPathComponent(String(format: "f%06d.png", i + 1))
            try ImageWriter.write(srgb, to: url, uti: ImageUTI.png, options: [:])
            progress(Double(i + 1) / Double(animation.frameCount))
        }
    }

    // MARK: AVIF

    /// libaom CRF from the 1–100 quality slider (85 → 13, 50 → 34, 100 → 4).
    static func aomCRF(_ options: OptionValues) -> Int {
        let q = min(100, max(1, options.int(OptionKey.quality, default: 85)))
        return min(63, Int((Double(100 - q) * 0.6).rounded()) + 4)
    }

    private static let srgbTags = ["-color_primaries", "bt709", "-color_trc", "iec61966-2-1", "-colorspace", "bt709"]

    static func stillAVIF(_ image: CGImage, options: OptionValues, to out: URL, work: URL, ffmpeg: FFmpeg, progress: ProgressSink) async throws {
        let png = work.appendingPathComponent("frame.png")
        try ImageWriter.write(image, to: png, uti: ImageUTI.png, options: [:])
        var args = ["-i", png.path, "-frames:v", "1"]
        if ImageOps.hasAlpha(image) {
            // AVIF stores alpha as a second AV1 image; ffmpeg's avif muxer pairs the two streams.
            args += ["-filter_complex", "[0:v]format=yuva420p,split[main][a];[a]alphaextract[alpha]", "-map", "[main]", "-map", "[alpha]"]
        } else {
            args += ["-pix_fmt", "yuv420p"]
        }
        args += ["-c:v", "libaom-av1", "-still-picture", "1", "-crf", String(aomCRF(options)), "-cpu-used", "6", "-row-mt", "1"]
        args += srgbTags + [out.path]
        try await ffmpeg.run(args, duration: nil, progress: progress.scaled(0.2...0.95))
    }

    /// Animated GIF → animated AVIF straight from ffmpeg's GIF demuxer, which keeps
    /// exact frame timing (verified with ffprobe).
    static func animatedAVIF(fromGIF input: ImageInput, options: OptionValues, to out: URL, ffmpeg: FFmpeg, progress: ProgressSink) async throws {
        var args = ["-i", input.url.path]
        let maxDim = options.int(OptionKey.maxDimension, default: 0)
        if maxDim > 0 && maxDim < input.longestEdge {
            let scale = input.pixelWidth >= input.pixelHeight ? "\(maxDim):-2" : "-2:\(maxDim)"
            args += ["-vf", "scale=\(scale):flags=lanczos"]
        }
        args += ["-c:v", "libaom-av1", "-crf", String(aomCRF(options)), "-cpu-used", "8", "-row-mt", "1", "-pix_fmt", "yuv420p",
                 "-fps_mode", "passthrough", "-loop", String(input.animation?.loopCount ?? 0)] + srgbTags + [out.path]
        try await ffmpeg.run(args, duration: input.animation?.totalDuration, progress: progress.scaled(0.05...0.95))
    }
}

/// A private scratch folder inside an engine's output directory, removed after use.
struct WorkFolder {
    let url: URL
    init(in parent: URL) throws {
        url = parent.appendingPathComponent(".work-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: url) }
}
