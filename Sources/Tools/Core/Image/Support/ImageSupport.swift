import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// A decoded still image. `image` is upright (EXIF orientation applied) and
/// keeps the source's colour space, so writing it back embeds the same ICC profile.
public struct DecodedImage: @unchecked Sendable {
    public let image: CGImage
    public let format: FormatID?
    public let typeIdentifier: String?
    /// Top-level ImageIO properties ({Exif}, {TIFF}, {IPTC}, {GPS}, …).
    public let properties: [String: Any]
    /// Orientation tag of the source. Already applied to `image`.
    public let sourceOrientation: CGImagePropertyOrientation
    public let fileSize: Int

    public var width: Int { image.width }
    public var height: Int { image.height }
    public var size: CGSize { CGSize(width: image.width, height: image.height) }
    public var hasAlpha: Bool { ImageSupport.hasAlpha(image) }
}

/// Decoding, orientation, colour-space and rendering helpers shared by every image tool.
public enum ImageSupport {
    /// No colour management: pixels pass through untouched (orientation, crops).
    static let passthroughContext = CIContext(options: [
        .workingColorSpace: NSNull(), .outputColorSpace: NSNull(), .cacheIntermediates: false,
    ])
    /// Colour-managed (linear extended sRGB working space, half-float). Filters and resampling.
    public static let managedContext = CIContext(options: [
        .cacheIntermediates: false, .workingFormat: CIFormat.RGBAh,
    ])

    // MARK: Decoding

    public static func decode(_ url: URL, applyOrientation: Bool = true) throws -> DecodedImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(src) > 0,
              let raw = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { throw ConversionError.unreadable(url, detail: "ImageIO could not decode the first image") }
        let props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]) ?? [:]
        let orientation = Self.orientation(of: props)
        let image = applyOrientation ? try oriented(raw, orientation) : raw
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return DecodedImage(image: image, format: Formats.detect(url), typeIdentifier: CGImageSourceGetType(src) as String?,
                            properties: props, sourceOrientation: orientation, fileSize: size)
    }

    /// Source properties without decoding pixels.
    public static func properties(of url: URL) -> [String: Any]? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(src) > 0 else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]
    }

    /// Upright pixel size (orientation applied) without decoding pixels.
    public static func pixelSize(of url: URL) -> CGSize? {
        guard let p = properties(of: url),
              let w = (p[kCGImagePropertyPixelWidth as String] as? NSNumber)?.doubleValue,
              let h = (p[kCGImagePropertyPixelHeight as String] as? NSNumber)?.doubleValue else { return nil }
        return orientation(of: p).swapsAxes ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }

    /// Fast, oriented, downsampled image for previews and thumbnails (uses
    /// embedded thumbnails when they are large enough).
    public static func thumbnail(_ url: URL, maxPixelSize: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(16, maxPixelSize),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    static func orientation(of props: [String: Any]) -> CGImagePropertyOrientation {
        let raw = (props[kCGImagePropertyOrientation as String] as? NSNumber)?.uint32Value ?? 1
        return CGImagePropertyOrientation(rawValue: raw) ?? .up
    }

    /// Applies an EXIF orientation by remapping pixels (exact, no resampling).
    static func oriented(_ image: CGImage, _ orientation: CGImagePropertyOrientation) throws -> CGImage {
        guard orientation != .up else { return image }
        // RGB sources pass through untouched; grey, indexed and CMYK ones are converted to sRGB.
        let rgb = image.colorSpace?.model == .rgb
        let ci = CIImage(cgImage: image, options: rgb ? [.colorSpace: NSNull()] : nil).oriented(orientation)
        let moved = ci.transformed(by: CGAffineTransform(translationX: -ci.extent.minX, y: -ci.extent.minY))
        let w = image.width, h = image.height
        let size = orientation.swapsAxes ? (h, w) : (w, h)
        return try render(moved, width: size.0, height: size.1, colorSpace: colorSpace(of: image), like: image,
                          opaque: !hasAlpha(image), context: rgb ? passthroughContext : managedContext, managed: !rgb)
    }

    // MARK: Colour

    /// The colour space tools render into: the source's own RGB space, or
    /// sRGB for grey, indexed and CMYK sources.
    public static func colorSpace(of image: CGImage) -> CGColorSpace {
        if let cs = image.colorSpace, cs.model == .rgb { return cs }
        return srgb
    }

    public static let srgb: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    public static let displayP3: CGColorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? srgb

    public static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }

    static func isDeep(_ image: CGImage) -> Bool { image.bitsPerComponent > 8 }

    // MARK: Rendering

    /// Renders a CIImage (extent at the origin) into a new CGImage with the
    /// depth of `like` (8 or 16 bit), labelled with `colorSpace`.
    /// `managed == false` means the context does no colour conversion (passthrough).
    static func render(_ ci: CIImage, width: Int, height: Int, colorSpace: CGColorSpace, like reference: CGImage?,
                       opaque: Bool, context: CIContext? = nil, managed: Bool = true) throws -> CGImage {
        let deep = reference.map(isDeep) ?? false
        let ctx = context ?? managedContext
        let bytesPerPixel = deep ? 8 : 4
        let rowBytes = width * bytesPerPixel
        var data = Data(count: rowBytes * height)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        data.withUnsafeMutableBytes { buf in
            guard let base = buf.baseAddress else { return }
            ctx.render(ci, toBitmap: base, rowBytes: rowBytes, bounds: bounds,
                       format: deep ? .RGBA16 : .RGBA8, colorSpace: managed ? colorSpace : nil)
        }
        let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
        let info = CGBitmapInfo(rawValue: alpha.rawValue | (deep ? CGBitmapInfo.byteOrder16Little.rawValue : 0))
        guard let provider = CGDataProvider(data: data as CFData),
              let out = CGImage(width: width, height: height, bitsPerComponent: deep ? 16 : 8, bitsPerPixel: bytesPerPixel * 8,
                                bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: info, provider: provider,
                                decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw ConversionError.other(L("The image couldn’t be processed."), detail: "CGImage from rendered bitmap failed") }
        return out
    }

    /// Bitmap context matching `reference` (depth) in `colorSpace`.
    static func makeContext(width: Int, height: Int, colorSpace: CGColorSpace, deep: Bool, opaque: Bool) -> CGContext? {
        let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
        let info = alpha.rawValue | (deep ? CGBitmapInfo.byteOrder16Little.rawValue : 0)
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: deep ? 16 : 8, bytesPerRow: 0,
                         space: colorSpace, bitmapInfo: info)
    }

    /// High-quality resample (Core Image Lanczos, colour managed, edges clamped).
    public static func resample(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
        let w = max(1, width), h = max(1, height)
        if w == image.width && h == image.height { return image }
        let cs = colorSpace(of: image)
        let input = CIImage(cgImage: image)
        let sy = CGFloat(h) / CGFloat(image.height)
        let sx = CGFloat(w) / CGFloat(image.width)
        let filter = CIFilter(name: "CILanczosScaleTransform")
        filter?.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter?.setValue(sy, forKey: kCIInputScaleKey)
        filter?.setValue(sx / sy, forKey: kCIInputAspectRatioKey)
        guard let scaled = filter?.outputImage else {
            throw ConversionError.other(L("The image couldn’t be resized."), detail: "CILanczosScaleTransform produced no output")
        }
        let cropped = scaled.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        return try render(cropped, width: w, height: h, colorSpace: cs, like: image, opaque: !hasAlpha(image))
    }

    /// Unpremultiplied RGBA8 pixels in `colorSpace` (default: the image's own).
    static func rgba8(_ image: CGImage, colorSpace: CGColorSpace? = nil) -> (pixels: [UInt8], width: Int, height: Int)? {
        let w = image.width, h = image.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let cs = colorSpace ?? self.colorSpace(of: image)
        let ok: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        // Unpremultiply in place.
        var i = 0
        while i < px.count {
            let a = Int(px[i + 3])
            if a != 0 && a != 255 {
                px[i] = UInt8(min(255, (Int(px[i]) * 255 + a / 2) / a))
                px[i + 1] = UInt8(min(255, (Int(px[i + 1]) * 255 + a / 2) / a))
                px[i + 2] = UInt8(min(255, (Int(px[i + 2]) * 255 + a / 2) / a))
            }
            i += 4
        }
        return (px, w, h)
    }
}

extension CGImagePropertyOrientation {
    /// True for the four orientations that swap width and height.
    var swapsAxes: Bool {
        switch self {
        case .left, .leftMirrored, .right, .rightMirrored: true
        default: false
        }
    }
}

/// Colours from "#RRGGBB" / "#RRGGBBAA" option strings.
public enum HexColor {
    public static func components(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255, 1)
        }
        return (Double((v >> 24) & 0xFF) / 255, Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    public static func cgColor(_ hex: String, fallback: CGColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)) -> CGColor {
        guard let c = components(hex) else { return fallback }
        return CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    public static func string(r: Double, g: Double, b: Double, a: Double = 1) -> String {
        func h(_ x: Double) -> String { String(format: "%02X", Int((min(1, max(0, x)) * 255).rounded())) }
        return "#" + h(r) + h(g) + h(b) + (a < 0.999 ? h(a) : "")
    }
}
