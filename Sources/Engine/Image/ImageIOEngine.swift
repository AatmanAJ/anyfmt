import Foundation
import ImageIO

/// Apple's ImageIO: decodes everything macOS reads and encodes JPEG, PNG, HEIC/HEIF,
/// TIFF, BMP, JPEG 2000, PSD, TGA, OpenEXR and AVIF (where the OS has an encoder),
/// plus our own ICO, ICNS and PDF containers, image → TXT via Vision OCR, and GIF as
/// the fallback when the bundled ffmpeg (better palettes) is missing. Zero size cost.
public struct ImageIOEngine: ConversionEngine {
    public let id = EngineIDs.imageIO
    public init() {}

    /// Outputs this engine writes (AVIF only where `CGImageDestinationCopyTypeIdentifiers` lists it).
    static let outputs: [FormatID] = [
        Formats.jpg, Formats.png, Formats.heic, Formats.heif, Formats.tiff, Formats.avif, Formats.bmp, Formats.gif,
        Formats.jp2, Formats.psd, Formats.ico, Formats.icns, Formats.tga, Formats.exr, Formats.pdf,
    ]

    public func isAvailable(_ capability: Capability) -> Bool {
        guard ImageIOSupport.canDecode(format: capability.from) else { return false }
        switch capability.to {
        case Formats.txt:
            return true // Vision OCR
        case Formats.pdf, Formats.icns, Formats.ico:
            return ImageIOSupport.canEncode(ImageUTI.png) // our own containers, PNG payloads
        default:
            guard let uti = ImageTargetTraits.forFormat(capability.to)?.uti else { return false }
            return ImageIOSupport.canEncode(uti)
        }
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        try Task.checkCancellation()
        let out = request.defaultOutputURL
        let input = try ImageInput.open(request.input, format: request.from)
        let maxDim = max(0, request.options.int(OptionKey.maxDimension, default: 0))
        context.progress(0.05)
        switch request.to {
        case Formats.txt:
            let image = try ImageOps.decode(input)
            let text = try TextRecognizer.text(in: image).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw TextRecognizer.noTextError(request.input) }
            try Data((text + "\n").utf8).write(to: out, options: .withoutOverwriting)
        case Formats.pdf:
            try ImagePDFWriter.write(input, to: out, pageSize: request.options.string(OptionKey.pageSize, default: "fit"),
                                     policy: request.metadata, title: request.baseName)
        case Formats.ico:
            try IconWriter.writeICO(input, to: out, maxDimension: maxDim)
        case Formats.icns:
            try IconWriter.writeICNS(input, to: out, maxDimension: maxDim)
        case Formats.gif where input.isAnimated:
            try writeAnimatedGIF(input, to: out, maxDimension: maxDim, progress: context.progress)
        case Formats.avif where input.isAnimated && input.type == ImageUTI.gif && FFmpeg(locator: context.locator).isAvailable:
            // ImageIO can't write AVIF sequences; hand animated GIFs to ffmpeg so they stay animated.
            return try await FFmpegImageEngine().convert(request, context: context)
        default:
            guard let traits = ImageTargetTraits.forFormat(request.to), let uti = traits.uti else {
                throw ConversionError.unsupported(from: request.from, to: request.to)
            }
            if try writeKeepingGainMap(input, request: request, traits: traits, uti: uti, to: out) {
                break
            }
            let still = try StillPipeline.prepare(input, target: StillPipeline.target(for: traits),
                                                  options: request.options, policy: request.metadata)
            try Task.checkCancellation()
            var options: [CFString: Any] = traits.carriesMetadata ? still.properties : [:]
            if traits.lossy {
                options[kCGImageDestinationLossyCompressionQuality] = Self.quality(request.options)
            }
            if request.to == Formats.tiff {
                var tiff = options[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
                tiff[kCGImagePropertyTIFFCompression] = 5 // LZW: lossless and ~half the size of raw
                options[kCGImagePropertyTIFFDictionary] = tiff
            }
            try ImageWriter.write(still.image, to: out, uti: uti, options: options,
                                  metadata: traits.carriesMetadata ? still.metadataTree : nil)
        }
        context.progress(1)
        return ConversionOutput(out)
    }

    static func quality(_ options: OptionValues) -> Double {
        Double(min(100, max(1, options.int(OptionKey.quality, default: 85)))) / 100
    }

    // MARK: HDR gain maps

    /// iPhone-style HDR photos carry a gain map next to the SDR base image. Redrawing
    /// pixels would drop it, so when nothing about the pixels has to change (keep
    /// metadata, no resize, no flattening) we write the untouched base image and copy
    /// the gain map across (Apple and ISO 21496-1 kinds) into JPEG/HEIC. Orientation
    /// stays a tag here, which every JPEG/HEIC viewer honours.
    private func writeKeepingGainMap(_ input: ImageInput, request: ConversionRequest, traits: ImageTargetTraits,
                                     uti: String, to url: URL) throws -> Bool {
        guard request.metadata == .keep, [Formats.jpg, Formats.heic, Formats.heif].contains(request.to) else { return false }
        let gainMaps = Self.gainMaps(input)
        guard !gainMaps.isEmpty else { return false }
        let maxDim = request.options.int(OptionKey.maxDimension, default: 0)
        if maxDim > 0 && maxDim < input.longestEdge { return false }
        if input.hasAlpha && !traits.keepsAlpha { return false }
        guard let base = CGImageSourceCreateImageAtIndex(input.source, input.index, nil) else { return false }
        var props = ImageMetadata.destinationProperties(from: input.properties, policy: .keep, width: base.width, height: base.height,
                                                        orientation: input.orientation)
        props[kCGImageDestinationLossyCompressionQuality] = Self.quality(request.options)
        let tree = ImageMetadata.metadataTree(input, policy: .keep, width: base.width, height: base.height, orientation: input.orientation)
        let dest = try ImageWriter.create(url, uti: uti, count: 1)
        if let tree {
            CGImageDestinationAddImageAndMetadata(dest, base, tree, props as CFDictionary)
        } else {
            CGImageDestinationAddImage(dest, base, props as CFDictionary)
        }
        for (type, info) in gainMaps { CGImageDestinationAddAuxiliaryDataInfo(dest, type, info) }
        try ImageWriter.finalize(dest, url)
        return true
    }

    /// Gain-map auxiliary images of the chosen image, by auxiliary type.
    static func gainMaps(_ input: ImageInput) -> [(CFString, CFDictionary)] {
        var types: [CFString] = [kCGImageAuxiliaryDataTypeHDRGainMap]
        if #available(macOS 15.0, *) { types.append(kCGImageAuxiliaryDataTypeISOGainMap) }
        return types.compactMap { t in CGImageSourceCopyAuxiliaryDataInfoAtIndex(input.source, input.index, t).map { (t, $0) } }
    }

    // MARK: Animated GIF

    /// Any animated source (GIF, WebP, APNG, AVIF sequence) → animated GIF with the
    /// same frame timing and loop count. ImageIO hands us fully composited frames.
    private func writeAnimatedGIF(_ input: ImageInput, to url: URL, maxDimension: Int, progress: ProgressSink) throws {
        guard let anim = input.animation else { return }
        let dest = try ImageWriter.create(url, uti: ImageUTI.gif, count: anim.frameCount)
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: anim.loopCount]] as CFDictionary)
        for i in 0..<anim.frameCount {
            try Task.checkCancellation()
            let frame = try ImageOps.decode(input, index: i, maxPixelSize: maxDimension, applyOrientation: false)
            let srgb = ImageOps.prepare(frame, flattenOnto: nil, colorSpace: ImageOps.sRGB, maxBits: 8)
            let delay = anim.delays[i]
            CGImageDestinationAddImage(dest, srgb, [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay,
            ]] as CFDictionary)
            progress(0.05 + 0.9 * Double(i + 1) / Double(anim.frameCount))
        }
        try ImageWriter.finalize(dest, url)
    }
}
