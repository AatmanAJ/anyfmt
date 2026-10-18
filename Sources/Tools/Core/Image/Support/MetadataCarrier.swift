import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Lets ImageIO serialise metadata blocks (EXIF, IPTC, XMP, PNG text) for
/// files whose pixels we write or keep ourselves: encode a flat grey image of
/// the same size with the wanted properties, then lift its metadata segments
/// out. The pixel data of the real file is never re-encoded.
enum MetadataCarrier {
    private static func carrierImage(width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: max(1, width), height: max(1, height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 0.5, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private static func encode(type: UTType, width: Int, height: Int, properties: [String: Any]) -> Data? {
        guard let image = carrierImage(width: width, height: height) else { return nil }
        var props = properties
        if type == .jpeg { props[kCGImageDestinationLossyCompressionQuality as String] = 0.1 }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    /// PNG metadata chunks (tEXt/zTXt/iTXt/eXIf/tIME) for `properties`.
    static func pngChunks(properties: [String: Any], width: Int, height: Int) -> [PNGChunks.Chunk] {
        guard !properties.isEmpty, let data = encode(type: .png, width: width, height: height, properties: properties),
              let chunks = PNGChunks.parse(data) else { return [] }
        return chunks.filter { PNGChunks.metadataTypes.contains($0.type) }
    }

    /// JPEG APP1 (Exif) and APP13 (IPTC) segments for `properties`. XMP is
    /// handled separately so a source's own XMP packet can be preserved.
    static func jpegSegments(properties: [String: Any], width: Int, height: Int) -> (exif: [JPEGSegments.Segment], iptc: [JPEGSegments.Segment]) {
        guard !properties.isEmpty, let data = encode(type: .jpeg, width: width, height: height, properties: properties),
              let file = JPEGSegments.parse(data) else { return ([], []) }
        return (file.header.filter(\.isExif), file.header.filter(\.isIPTC))
    }
}
