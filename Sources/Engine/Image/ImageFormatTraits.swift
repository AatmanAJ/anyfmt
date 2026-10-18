import Foundation
import ImageIO

/// What ImageIO on *this* machine can decode and encode. Read once, at first use,
/// from `CGImageSourceCopyTypeIdentifiers` / `CGImageDestinationCopyTypeIdentifiers`.
/// Rows gate on this at runtime instead of guessing from OS versions
/// (research/PLATFORM_RESEARCH.md §C: AVIF encode is unverified before macOS 26).
enum ImageIOSupport {
    static let decodableTypes: Set<String> = {
        Set((CGImageSourceCopyTypeIdentifiers() as? [String]) ?? [])
    }()

    static let encodableTypes: Set<String> = {
        Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    }()

    static func canDecode(_ uti: String) -> Bool { decodableTypes.contains(uti) }
    static func canEncode(_ uti: String) -> Bool { encodableTypes.contains(uti) }

    /// True when ImageIO can open files of this format.
    static func canDecode(format: FormatID) -> Bool {
        guard let f = Formats.format(format) else { return false }
        return f.typeIdentifiers.contains { canDecode($0) }
    }

    static var canEncodeAVIF: Bool { canEncode(ImageUTI.avif) }
}

/// UTIs we pass to ImageIO. Strings, because `UTType.avif` doesn't exist and
/// `UTType.jpegxl` is 15.2+.
enum ImageUTI {
    static let jpeg = "public.jpeg"
    static let png = "public.png"
    static let heic = "public.heic"
    static let heif = "public.heif"
    static let avif = "public.avif"
    static let avis = "public.avis"
    static let tiff = "public.tiff"
    static let bmp = "com.microsoft.bmp"
    static let gif = "com.compuserve.gif"
    static let jp2 = "public.jpeg-2000"
    static let psd = "com.adobe.photoshop-image"
    static let ico = "com.microsoft.ico"
    static let icns = "com.apple.icns"
    static let tga = "com.truevision.tga-image"
    static let exr = "com.ilm.openexr-image"
    static let webp = "org.webmproject.webp"
    static let pdf = "com.adobe.pdf"
}

/// How an encoder treats colour.
enum ColorHandling: Sendable {
    /// The format embeds an ICC profile: keep the source's colour space.
    case embedProfile
    /// The format (or ImageIO's writer for it) can't carry a profile. We convert
    /// pixels to sRGB ourselves, because ImageIO relabels instead of converting
    /// for TGA and JPEG 2000 (verified on macOS 27).
    case convertToSRGB
    /// ImageIO converts correctly by itself (OpenEXR → extended linear sRGB).
    case imageIOConverts
}

/// Encoder facts per still-image target. One place, so engine code never
/// switches on format ids.
struct ImageTargetTraits: Sendable {
    let format: FormatID
    /// ImageIO destination type; nil when we write the container ourselves.
    let uti: String?
    let color: ColorHandling
    /// False → transparent pixels are flattened onto the `background` option.
    let keepsAlpha: Bool
    /// Deepest sample size worth keeping (8, 16 or 32 = float).
    let maxBitsPerComponent: Int
    /// `quality` maps to kCGImageDestinationLossyCompressionQuality.
    let lossy: Bool
    /// The container stores EXIF/IPTC/XMP via ImageIO properties.
    let carriesMetadata: Bool

    static func forFormat(_ id: FormatID) -> ImageTargetTraits? { table[id] }

    private static let table: [FormatID: ImageTargetTraits] = {
        func t(_ f: FormatID, _ uti: String?, _ color: ColorHandling, alpha: Bool, bits: Int, lossy: Bool, meta: Bool) -> (FormatID, ImageTargetTraits) {
            (f, ImageTargetTraits(format: f, uti: uti, color: color, keepsAlpha: alpha, maxBitsPerComponent: bits, lossy: lossy, carriesMetadata: meta))
        }
        return Dictionary(uniqueKeysWithValues: [
            t(Formats.jpg, ImageUTI.jpeg, .embedProfile, alpha: false, bits: 8, lossy: true, meta: true),
            t(Formats.png, ImageUTI.png, .embedProfile, alpha: true, bits: 16, lossy: false, meta: true),
            t(Formats.heic, ImageUTI.heic, .embedProfile, alpha: true, bits: 16, lossy: true, meta: true),
            // ImageIO has no `public.heif` writer; HEVC-in-HEIF written as .heif is a valid HEIF file.
            t(Formats.heif, ImageUTI.heic, .embedProfile, alpha: true, bits: 16, lossy: true, meta: true),
            t(Formats.avif, ImageUTI.avif, .embedProfile, alpha: true, bits: 16, lossy: true, meta: true),
            t(Formats.tiff, ImageUTI.tiff, .embedProfile, alpha: true, bits: 16, lossy: false, meta: true),
            t(Formats.psd, ImageUTI.psd, .embedProfile, alpha: true, bits: 16, lossy: false, meta: true),
            t(Formats.bmp, ImageUTI.bmp, .convertToSRGB, alpha: false, bits: 8, lossy: false, meta: false),
            t(Formats.gif, ImageUTI.gif, .convertToSRGB, alpha: true, bits: 8, lossy: false, meta: false),
            t(Formats.jp2, ImageUTI.jp2, .convertToSRGB, alpha: true, bits: 8, lossy: true, meta: false),
            t(Formats.tga, ImageUTI.tga, .convertToSRGB, alpha: true, bits: 8, lossy: false, meta: false),
            t(Formats.exr, ImageUTI.exr, .imageIOConverts, alpha: true, bits: 32, lossy: false, meta: false),
            t(Formats.ico, nil, .convertToSRGB, alpha: true, bits: 8, lossy: false, meta: false),
            t(Formats.icns, nil, .convertToSRGB, alpha: true, bits: 8, lossy: false, meta: false),
        ])
    }()
}
