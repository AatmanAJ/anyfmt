import Foundation
import ImageIO

/// Builds what an encoder writes for each `MetadataPolicy`.
///
/// - `.keep`: every EXIF/TIFF/GPS/IPTC/maker-note property plus the full XMP tree.
/// - `.stripPrivate`: drops location (GPS, IPTC place fields), device identity
///   (make, model, lens, serial numbers, maker notes, host/software) and author
///   identity (artist, owner, by-line, creator contact). Keeps capture settings,
///   dates, keywords, caption, copyright notice, DPI and the colour profile.
///   XMP is rebuilt by ImageIO from the filtered properties, so custom XMP is dropped.
/// - `.stripAll`: nothing but the pixels (the caller also converts to sRGB, so no
///   device profile is left behind).
///
/// Pixels are always written already oriented, so orientation is always reset to 1.
enum ImageMetadata {
    /// Top-level property groups worth carrying between formats. Container-specific
    /// groups ({PNG}, {JFIF}, {GIF}, {HEIF}, {8BIM}…) describe the old file, not the new one.
    private static let carriedGroups: [String] = [
        kCGImagePropertyExifDictionary, kCGImagePropertyExifAuxDictionary, kCGImagePropertyGPSDictionary,
        kCGImagePropertyIPTCDictionary, kCGImagePropertyTIFFDictionary, kCGImagePropertyDNGDictionary,
        kCGImagePropertyMakerAppleDictionary, kCGImagePropertyMakerCanonDictionary, kCGImagePropertyMakerNikonDictionary,
        kCGImagePropertyMakerMinoltaDictionary, kCGImagePropertyMakerFujiDictionary, kCGImagePropertyMakerOlympusDictionary,
        kCGImagePropertyMakerPentaxDictionary,
    ].map { $0 as String }

    private static let privateGroups = Set([
        kCGImagePropertyGPSDictionary, kCGImagePropertyExifAuxDictionary, kCGImagePropertyDNGDictionary,
        kCGImagePropertyMakerAppleDictionary, kCGImagePropertyMakerCanonDictionary, kCGImagePropertyMakerNikonDictionary,
        kCGImagePropertyMakerMinoltaDictionary, kCGImagePropertyMakerFujiDictionary, kCGImagePropertyMakerOlympusDictionary,
        kCGImagePropertyMakerPentaxDictionary,
    ].map { $0 as String })

    static let privateExifKeys: [String] = [
        kCGImagePropertyExifBodySerialNumber, kCGImagePropertyExifLensSerialNumber, kCGImagePropertyExifLensMake,
        kCGImagePropertyExifLensModel, kCGImagePropertyExifLensSpecification, kCGImagePropertyExifCameraOwnerName,
        kCGImagePropertyExifImageUniqueID, kCGImagePropertyExifUserComment, kCGImagePropertyExifMakerNote,
    ].map { $0 as String }

    static let privateTIFFKeys: [String] = [
        kCGImagePropertyTIFFMake, kCGImagePropertyTIFFModel, kCGImagePropertyTIFFArtist,
        kCGImagePropertyTIFFHostComputer, kCGImagePropertyTIFFSoftware,
    ].map { $0 as String }

    static let privateIPTCKeys: [String] = [
        kCGImagePropertyIPTCByline, kCGImagePropertyIPTCBylineTitle, kCGImagePropertyIPTCCredit,
        kCGImagePropertyIPTCCreatorContactInfo, kCGImagePropertyIPTCWriterEditor,
        kCGImagePropertyIPTCCity, kCGImagePropertyIPTCSubLocation, kCGImagePropertyIPTCProvinceState,
        kCGImagePropertyIPTCCountryPrimaryLocationCode, kCGImagePropertyIPTCCountryPrimaryLocationName,
        kCGImagePropertyIPTCOriginatingProgram, kCGImagePropertyIPTCProgramVersion,
        kCGImagePropertyIPTCExtLocationCreated, kCGImagePropertyIPTCExtLocationShown,
        kCGImagePropertyIPTCExtArtworkCreator, kCGImagePropertyIPTCExtPersonInImage,
    ].map { $0 as String }

    /// TIFF fields that describe the old encoding and must not leak into the new file.
    private static let encodingTIFFKeys: [String] = [
        kCGImagePropertyTIFFOrientation, kCGImagePropertyTIFFCompression, kCGImagePropertyTIFFPhotometricInterpretation,
        kCGImagePropertyTIFFTileWidth, kCGImagePropertyTIFFTileLength,
    ].map { $0 as String }

    /// Properties for `CGImageDestinationAddImage[AndMetadata]` describing an already
    /// oriented image of `width`×`height`.
    static func destinationProperties(from source: [CFString: Any], policy: MetadataPolicy, width: Int, height: Int) -> [CFString: Any] {
        guard policy != .stripAll else { return [:] }
        var out: [CFString: Any] = [:]
        for name in carriedGroups {
            let group = name as CFString
            if policy == .stripPrivate && privateGroups.contains(name) { continue }
            guard var dict = source[group] as? [CFString: Any] else { continue }
            if name == kCGImagePropertyTIFFDictionary as String {
                for k in encodingTIFFKeys { dict.removeValue(forKey: k as CFString) }
                if policy == .stripPrivate { for k in privateTIFFKeys { dict.removeValue(forKey: k as CFString) } }
                dict[kCGImagePropertyTIFFOrientation] = 1
            } else if name == kCGImagePropertyExifDictionary as String {
                // ImageIO writes the right ColorSpace tag for the profile it embeds.
                dict.removeValue(forKey: kCGImagePropertyExifColorSpace)
                dict[kCGImagePropertyExifPixelXDimension] = width
                dict[kCGImagePropertyExifPixelYDimension] = height
                if policy == .stripPrivate { for k in privateExifKeys { dict.removeValue(forKey: k as CFString) } }
            } else if name == kCGImagePropertyIPTCDictionary as String {
                dict.removeValue(forKey: kCGImagePropertyIPTCImageOrientation)
                if policy == .stripPrivate { for k in privateIPTCKeys { dict.removeValue(forKey: k as CFString) } }
            }
            if !dict.isEmpty { out[group] = dict }
        }
        if let dpi = source[kCGImagePropertyDPIWidth] { out[kCGImagePropertyDPIWidth] = dpi }
        if let dpi = source[kCGImagePropertyDPIHeight] { out[kCGImagePropertyDPIHeight] = dpi }
        out[kCGImagePropertyOrientation] = 1
        return out
    }

    /// The full XMP/EXIF tree for `.keep`, with orientation and size updated. nil otherwise.
    static func metadataTree(_ input: ImageInput, policy: MetadataPolicy, width: Int, height: Int) -> CGImageMetadata? {
        guard policy == .keep, let tree = CGImageSourceCopyMetadataAtIndex(input.source, input.index, nil),
              let m = CGImageMetadataCreateMutableCopy(tree) else { return nil }
        // The tree mirrors the old file's TIFF encoding tags (HEIC reports its 512² grid
        // as tiles); left in, they make the TIFF writer emit bogus uncompressed tiles.
        for path in ["tiff:TileWidth", "tiff:TileLength", "tiff:Compression", "tiff:PhotometricInterpretation",
                     "tiff:ImageWidth", "tiff:ImageLength", "tiff:BitsPerSample", "tiff:SamplesPerPixel"] {
            CGImageMetadataRemoveTagWithPath(m, nil, path as CFString)
        }
        _ = CGImageMetadataSetValueMatchingImageProperty(m, kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFOrientation, 1 as CFNumber)
        _ = CGImageMetadataSetValueMatchingImageProperty(m, kCGImagePropertyExifDictionary, kCGImagePropertyExifPixelXDimension, width as CFNumber)
        _ = CGImageMetadataSetValueMatchingImageProperty(m, kCGImagePropertyExifDictionary, kCGImagePropertyExifPixelYDimension, height as CFNumber)
        return m
    }
}
