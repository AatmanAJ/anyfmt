import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Image helpers for document readers/writers: MIME sniffing, pixel size,
/// and re-encoding to a format every office suite and ebook reader accepts.
public enum ImageSupport {
    /// MIME type from magic bytes, else from a file extension, else nil.
    public static func sniffMIME(_ data: Data, fileExtension: String? = nil) -> String? {
        let b = [UInt8](data.prefix(16))
        if b.count >= 8, b[0] == 0x89, b[1] == 0x50, b[2] == 0x4E, b[3] == 0x47 { return "image/png" }
        if b.count >= 3, b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return "image/jpeg" }
        if b.count >= 6, b[0] == 0x47, b[1] == 0x49, b[2] == 0x46 { return "image/gif" }
        if b.count >= 12, b[0] == 0x52, b[1] == 0x49, b[2] == 0x46, b[3] == 0x46, b[8] == 0x57, b[9] == 0x45, b[10] == 0x42, b[11] == 0x50 { return "image/webp" }
        if b.count >= 2, b[0] == 0x42, b[1] == 0x4D { return "image/bmp" }
        if b.count >= 4, (b[0] == 0x49 && b[1] == 0x49 && b[2] == 0x2A) || (b[0] == 0x4D && b[1] == 0x4D && b[3] == 0x2A) { return "image/tiff" }
        if b.count >= 12, b[4] == 0x66, b[5] == 0x74, b[6] == 0x79, b[7] == 0x70 {
            let brand = String(decoding: b[8..<12], as: UTF8.self)
            if brand.hasPrefix("avif") { return "image/avif" }
            if brand.hasPrefix("hei") || brand.hasPrefix("mif1") { return "image/heic" }
        }
        let head = String(decoding: data.prefix(256), as: UTF8.self).lowercased()
        if head.contains("<svg") || (head.hasPrefix("<?xml") && head.contains("svg")) { return "image/svg+xml" }
        if let ext = fileExtension?.lowercased(), let t = UTType(filenameExtension: ext), t.conforms(to: .image) {
            return t.preferredMIMEType
        }
        return nil
    }

    public static func fileExtension(forMIME mime: String) -> String {
        switch mime.lowercased() {
        case "image/png": "png"
        case "image/jpeg", "image/jpg": "jpg"
        case "image/gif": "gif"
        case "image/webp": "webp"
        case "image/bmp": "bmp"
        case "image/tiff": "tiff"
        case "image/svg+xml": "svg"
        case "image/heic": "heic"
        case "image/avif": "avif"
        default: UTType(mimeType: mime)?.preferredFilenameExtension ?? "bin"
        }
    }

    /// Pixel dimensions and DPI, nil if the data isn't a decodable raster image.
    public static func pixelInfo(_ data: Data) -> (width: Int, height: Int, dpi: Double)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let dpi = (props[kCGImagePropertyDPIWidth] as? Double) ?? 72
        // EXIF orientations 5–8 swap width and height.
        let orientation = (props[kCGImagePropertyOrientation] as? Int) ?? 1
        return orientation >= 5 ? (h, w, dpi) : (w, h, dpi)
    }

    /// Display size in points: the explicit size if given (aspect-filled from
    /// pixels when only one side is known), else pixels at the image's DPI.
    public static func displaySize(_ image: DocImage) -> (width: Double, height: Double)? {
        let info = image.data.flatMap(pixelInfo)
        if let w = image.width, let h = image.height, w > 0, h > 0 { return (w, h) }
        guard let info else {
            if let w = image.width, w > 0 { return (w, w * 0.75) }
            return nil
        }
        let aspect = Double(info.height) / Double(max(info.width, 1))
        if let w = image.width, w > 0 { return (w, w * aspect) }
        if let h = image.height, h > 0 { return (h / max(aspect, 0.0001), h) }
        let scale = 72.0 / max(info.dpi, 1)
        return (Double(info.width) * scale, Double(info.height) * scale)
    }

    /// Fits a size into a box, preserving aspect ratio (never upscales).
    public static func fit(_ size: (width: Double, height: Double), maxWidth: Double, maxHeight: Double) -> (width: Double, height: Double) {
        let s = min(1, maxWidth / max(size.width, 1), maxHeight / max(size.height, 1))
        return (size.width * s, size.height * s)
    }

    /// Returns data in PNG/JPEG/GIF (universally supported). Other raster types
    /// are re-encoded as PNG with ImageIO. SVG and undecodable data return nil.
    public static func portable(_ image: DocImage) -> (data: Data, mime: String)? {
        guard let data = image.data else { return nil }
        let mime = sniffMIME(data) ?? image.mime
        if ["image/png", "image/jpeg", "image/gif"].contains(mime) { return (data, mime) }
        if mime == "image/svg+xml" { return nil }
        guard let png = reencodePNG(data) else { return nil }
        return (png, "image/png")
    }

    public static func reencodePNG(_ data: Data) -> Data? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        return encode(img, type: .png)
    }

    public static func encode(_ image: CGImage, type: UTType, quality: Double = 0.9) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// `data:` URI for embedding in HTML/Markdown.
    public static func dataURI(_ data: Data, mime: String) -> String {
        "data:\(mime);base64,\(data.base64EncodedString())"
    }

    /// Decodes a `data:` URI ("data:image/png;base64,...").
    public static func decodeDataURI(_ uri: String) -> (data: Data, mime: String)? {
        guard uri.hasPrefix("data:"), let comma = uri.firstIndex(of: ",") else { return nil }
        let meta = uri[uri.index(uri.startIndex, offsetBy: 5)..<comma]
        let payload = String(uri[uri.index(after: comma)...])
        let parts = meta.split(separator: ";")
        let mime = parts.first.map(String.init).flatMap { $0.isEmpty ? nil : $0 } ?? "text/plain"
        if parts.contains("base64") {
            let cleaned = payload.filter { !$0.isWhitespace }
            guard let d = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters) else { return nil }
            return (d, mime)
        }
        guard let s = payload.removingPercentEncoding else { return nil }
        return (Data(s.utf8), mime)
    }
}
