import Foundation
import ImageIO

/// Pixels plus metadata for one still image, ready for any encoder.
struct PreparedStill {
    let image: CGImage
    /// Destination properties for the metadata policy (orientation already 1).
    let properties: [CFString: Any]
    /// Full XMP tree, only for `.keep`.
    let metadataTree: CGImageMetadata?
}

/// Decode → orient → downscale → flatten → colour-convert, shared by the ImageIO,
/// ffmpeg-image and PDFKit engines so every target treats pixels the same way.
enum StillPipeline {
    struct Target {
        var keepsAlpha: Bool
        var color: ColorHandling
        var maxBits: Int
        /// JPEG/TIFF/PSD store CMYK natively; everything else gets RGB.
        var keepsCMYK: Bool = false
        /// Force an RGB colour model (8-bit intermediates for ffmpeg).
        var requireRGB: Bool = false
    }

    static func target(for traits: ImageTargetTraits) -> Target {
        Target(keepsAlpha: traits.keepsAlpha, color: traits.color, maxBits: traits.maxBitsPerComponent,
               keepsCMYK: [Formats.jpg, Formats.tiff, Formats.psd].contains(traits.format))
    }

    static func prepare(_ input: ImageInput, target: Target, options: OptionValues, policy: MetadataPolicy) throws -> PreparedStill {
        let maxDim = max(0, options.int(OptionKey.maxDimension, default: 0))
        var decoded = try ImageOps.decode(input, maxPixelSize: maxDim)
        // HDR/float sources roll highlights off instead of clipping, unless the target is float too (EXR).
        if target.maxBits < 32 { decoded = ImageOps.sdr(decoded, sixteenBit: target.maxBits >= 16) }
        let background = target.keepsAlpha ? nil : ImageOps.opaqueColor(options.string(OptionKey.background, default: "#FFFFFF"))
        let space = colorSpace(for: decoded, target: target, policy: policy)
        let image = ImageOps.prepare(decoded, flattenOnto: background, colorSpace: space, maxBits: target.maxBits)
        let props = ImageMetadata.destinationProperties(from: input.properties, policy: policy, width: image.width, height: image.height)
        let tree = ImageMetadata.metadataTree(input, policy: policy, width: image.width, height: image.height)
        return PreparedStill(image: image, properties: props, metadataTree: tree)
    }

    /// The colour space pixels must be converted to, or nil to keep the source's.
    static func colorSpace(for image: CGImage, target: Target, policy: MetadataPolicy) -> CGColorSpace? {
        switch target.color {
        case .convertToSRGB:
            return ImageOps.sRGB
        case .imageIOConverts:
            return nil
        case .embedProfile:
            switch image.colorSpace?.model {
            case .rgb?:
                // Strip-all leaves no device profile behind: wide gamut becomes sRGB.
                return policy == .stripAll && !ImageOps.isSRGB(image.colorSpace) ? ImageOps.sRGB : nil
            case .monochrome?:
                return target.requireRGB ? ImageOps.sRGB : nil
            case .cmyk? where target.keepsCMYK && !target.requireRGB:
                return policy == .stripAll ? ImageOps.sRGB : nil
            default:
                return ImageOps.sRGB
            }
        }
    }
}
