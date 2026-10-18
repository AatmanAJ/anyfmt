import Foundation
import ImageIO

/// Thin, throwing wrappers around CGImageDestination.
enum ImageWriter {
    static func write(_ image: CGImage, to url: URL, uti: String, options: [CFString: Any], metadata: CGImageMetadata? = nil) throws {
        let dest = try create(url, uti: uti, count: 1)
        if let metadata {
            CGImageDestinationAddImageAndMetadata(dest, image, metadata, options as CFDictionary)
        } else {
            CGImageDestinationAddImage(dest, image, options as CFDictionary)
        }
        try finalize(dest, url)
    }

    static func create(_ url: URL, uti: String, count: Int) throws -> CGImageDestination {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti as CFString, count, nil) else {
            throw ConversionError.engineMissing("ImageIO \(uti) encoder", detail: "CGImageDestinationCreateWithURL returned nil for \(uti)")
        }
        return dest
    }

    static func finalize(_ dest: CGImageDestination, _ url: URL) throws {
        guard CGImageDestinationFinalize(dest) else {
            try? FileManager.default.removeItem(at: url)
            throw ConversionError.engineFailed("ImageIO", status: 0, detail: "CGImageDestinationFinalize failed for \(url.lastPathComponent)")
        }
    }

    /// Encodes `image` as PNG into memory (icon payloads, intermediates).
    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, ImageUTI.png as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }
}
