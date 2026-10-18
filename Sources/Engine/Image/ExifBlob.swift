import Foundation
import ImageIO

/// Serialises ImageIO property dictionaries into raw metadata blobs for
/// containers ImageIO can't write (WebP via ffmpeg).
enum ExifBlob {
    /// EXIF as a bare TIFF structure ("II*\0…"), the form the WebP EXIF chunk holds.
    /// ImageIO has no public EXIF serialiser, so we let it write a tiny JPEG with
    /// the properties and lift the APP1 "Exif\0\0" segment out of it.
    static func tiffStructure(from properties: [CFString: Any]) -> Data? {
        let interesting = properties.keys.contains { k in
            [kCGImagePropertyExifDictionary, kCGImagePropertyTIFFDictionary, kCGImagePropertyGPSDictionary].contains(k)
        }
        guard interesting,
              let ctx = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0, space: ImageOps.sRGB,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let tiny = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, ImageUTI.jpeg as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, tiny, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return app1Exif(in: data as Data)
    }

    /// Walks JPEG markers up to the first scan and returns the EXIF APP1 payload
    /// without its 6-byte "Exif\0\0" identifier.
    static func app1Exif(in jpeg: Data) -> Data? {
        let b = [UInt8](jpeg)
        guard b.count > 4, b[0] == 0xFF, b[1] == 0xD8 else { return nil }
        var i = 2
        while i + 4 <= b.count {
            guard b[i] == 0xFF else { return nil }
            let marker = b[i + 1]
            if marker == 0xDA || marker == 0xD9 { return nil } // start of scan / end: no EXIF
            let len = Int(b[i + 2]) << 8 | Int(b[i + 3])
            guard len >= 2, i + 2 + len <= b.count else { return nil }
            let payload = i + 4
            if marker == 0xE1, len >= 8, b[payload..<payload + 6].elementsEqual([0x45, 0x78, 0x69, 0x66, 0, 0]) {
                return Data(b[(payload + 6)..<(i + 2 + len)])
            }
            i += 2 + len
        }
        return nil
    }

    /// Serialised XMP packet of a metadata tree.
    static func xmp(_ tree: CGImageMetadata?) -> Data? {
        guard let tree, let d = CGImageMetadataCreateXMPData(tree, nil) else { return nil }
        let data = d as Data
        return data.isEmpty ? nil : data
    }
}
