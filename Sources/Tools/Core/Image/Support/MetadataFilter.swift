import Foundation
import ImageIO

/// Builds the ImageIO property dictionaries a re-encoded image carries, per
/// `MetadataPolicy`. Pixels handed to the encoder are always upright, so the
/// orientation tag is reset to 1. Colour profiles travel with the CGImage's
/// colour space, so every policy keeps them.
enum MetadataFilter {
    private static let metadataDictionaries: [String] = [
        kCGImagePropertyExifDictionary as String, kCGImagePropertyExifAuxDictionary as String, kCGImagePropertyTIFFDictionary as String,
        kCGImagePropertyIPTCDictionary as String, kCGImagePropertyGPSDictionary as String,
    ]

    /// Fields that identify a device, a person or a place (`.stripPrivate` drops them).
    private static let privateTIFF: [String] = [
        kCGImagePropertyTIFFMake as String, kCGImagePropertyTIFFModel as String, kCGImagePropertyTIFFSoftware as String,
        kCGImagePropertyTIFFArtist as String, kCGImagePropertyTIFFHostComputer as String,
    ]
    private static let privateExif: [String] = [
        kCGImagePropertyExifMakerNote as String, kCGImagePropertyExifLensMake as String, kCGImagePropertyExifLensModel as String,
        kCGImagePropertyExifLensSerialNumber as String, kCGImagePropertyExifBodySerialNumber as String, kCGImagePropertyExifCameraOwnerName as String,
        kCGImagePropertyExifUserComment as String, kCGImagePropertyExifSubjectLocation as String, kCGImagePropertyExifSubjectArea as String,
        kCGImagePropertyExifImageUniqueID as String,
    ]
    private static let privateIPTC: [String] = [
        kCGImagePropertyIPTCByline as String, kCGImagePropertyIPTCBylineTitle as String,
        kCGImagePropertyIPTCCity as String, kCGImagePropertyIPTCSubLocation as String, kCGImagePropertyIPTCProvinceState as String,
        kCGImagePropertyIPTCCountryPrimaryLocationCode as String, kCGImagePropertyIPTCCountryPrimaryLocationName as String,
        kCGImagePropertyIPTCWriterEditor as String, kCGImagePropertyIPTCCredit as String, kCGImagePropertyIPTCSource as String,
        kCGImagePropertyIPTCCreatorContactInfo as String, kCGImagePropertyIPTCOriginatingProgram as String, kCGImagePropertyIPTCProgramVersion as String,
    ]

    static func properties(_ source: [String: Any], policy: MetadataPolicy, for format: FormatID) -> [String: Any] {
        guard policy != .stripAll else { return [:] }
        var out: [String: Any] = [:]
        for key in metadataDictionaries {
            guard var dict = source[key] as? [String: Any] else { continue }
            let name = key
            if name == kCGImagePropertyExifDictionary as String {
                dict.removeValue(forKey: kCGImagePropertyExifPixelXDimension as String)
                dict.removeValue(forKey: kCGImagePropertyExifPixelYDimension as String)
                if policy == .stripPrivate { privateExif.forEach { dict.removeValue(forKey: $0) } }
            } else if name == kCGImagePropertyExifAuxDictionary as String {
                if policy == .stripPrivate { continue }
            } else if name == kCGImagePropertyTIFFDictionary as String {
                dict.removeValue(forKey: kCGImagePropertyTIFFOrientation as String)
                dict.removeValue(forKey: kCGImagePropertyTIFFTileWidth as String)
                dict.removeValue(forKey: kCGImagePropertyTIFFTileLength as String)
                dict.removeValue(forKey: kCGImagePropertyTIFFCompression as String)
                if policy == .stripPrivate { privateTIFF.forEach { dict.removeValue(forKey: $0) } }
            } else if name == kCGImagePropertyIPTCDictionary as String {
                dict.removeValue(forKey: kCGImagePropertyIPTCImageOrientation as String)
                if policy == .stripPrivate { privateIPTC.forEach { dict.removeValue(forKey: $0) } }
            } else if name == kCGImagePropertyGPSDictionary as String {
                if policy == .stripPrivate { continue }
            }
            if !dict.isEmpty { out[key] = dict }
        }
        for key in [kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight] {
            if let v = source[key as String] { out[key as String] = v }
        }
        out[kCGImagePropertyOrientation as String] = 1
        return out
    }
}
