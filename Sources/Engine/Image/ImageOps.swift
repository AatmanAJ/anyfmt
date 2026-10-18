import Foundation
import ImageIO
import CoreGraphics

/// Pixel-level helpers shared by every image engine. All synchronous; callers
/// run them inside an engine's `convert`.
enum ImageOps {
    static let sRGB: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    // MARK: Decode

    /// Decodes image `index` (default: the input's chosen image) with EXIF orientation
    /// applied and the longest edge capped at `maxPixelSize` (0 = keep).
    ///
    /// Uses ImageIO's thumbnail decoder whenever pixels must move (it rotates and
    /// downsamples in one high-quality pass and keeps 16-bit depth); otherwise the
    /// plain lazy decode, which lets ImageIO stream straight into the encoder.
    static func decode(_ input: ImageInput, index: Int? = nil, maxPixelSize: Int = 0, applyOrientation: Bool = true) throws -> CGImage {
        let idx = index ?? input.index
        let (longest, orientation) = idx == input.index ? (input.longestEdge, input.orientation) : frameInfo(input.source, idx)
        let target = maxPixelSize > 0 ? min(maxPixelSize, longest) : longest
        let rotate = applyOrientation && orientation != 1
        let image: CGImage?
        if rotate || target < longest {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: applyOrientation,
                kCGImageSourceThumbnailMaxPixelSize: max(1, target),
                kCGImageSourceShouldCacheImmediately: true,
            ]
            image = CGImageSourceCreateThumbnailAtIndex(input.source, idx, opts as CFDictionary)
        } else {
            image = CGImageSourceCreateImageAtIndex(input.source, idx, [kCGImageSourceShouldCacheImmediately: false] as CFDictionary)
        }
        guard let image else { throw ConversionError.unreadable(input.url, detail: "ImageIO could not decode image \(idx)") }
        return image
    }

    private static func frameInfo(_ src: CGImageSource, _ i: Int) -> (longest: Int, orientation: Int) {
        let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
        let longest = max((p?[kCGImagePropertyPixelWidth] as? Int) ?? 0, (p?[kCGImagePropertyPixelHeight] as? Int) ?? 0)
        return (longest, (p?[kCGImagePropertyOrientation] as? Int) ?? 1)
    }

    // MARK: Inspect

    static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }

    static func isSRGB(_ space: CGColorSpace?) -> Bool {
        guard let name = space?.name as String? else { return false }
        return name == (CGColorSpace.sRGB as String)
    }

    static func isRGB(_ space: CGColorSpace?) -> Bool { space?.model == .rgb }

    // MARK: Redraw

    /// Returns `image` unchanged when nothing is needed, otherwise one redraw that
    /// flattens alpha onto `flattenOnto`, converts to `colorSpace` (ColorSync does
    /// the maths) and keeps 16-bit samples when `maxBits` allows.
    static func prepare(_ image: CGImage, flattenOnto: CGColor?, colorSpace: CGColorSpace?, maxBits: Int) -> CGImage {
        let alpha = hasAlpha(image)
        let flatten = flattenOnto != nil && alpha
        let convert: Bool = {
            guard let colorSpace else { return false }
            guard let current = image.colorSpace else { return true }
            if let a = current.name as String?, let b = colorSpace.name as String? { return a != b }
            return true
        }()
        guard flatten || convert else { return image }
        let space: CGColorSpace = colorSpace ?? (isRGB(image.colorSpace) ? (image.colorSpace ?? sRGB) : sRGB)
        let deep = image.bitsPerComponent > 8 && maxBits >= 16
        return redraw(image, width: image.width, height: image.height, space: space, sixteenBit: deep,
                      keepAlpha: alpha && !flatten, background: flatten ? flattenOnto : nil) ?? image
    }

    /// Draws `image` into a new bitmap of `width`×`height`.
    static func redraw(_ image: CGImage, width: Int, height: Int, space: CGColorSpace, sixteenBit: Bool = false,
                       keepAlpha: Bool, background: CGColor?, inset: CGRect? = nil) -> CGImage? {
        let rgbSpace = space.model == .rgb ? space : sRGB
        var info = keepAlpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        if sixteenBit { info |= CGBitmapInfo.byteOrder16Little.rawValue }
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: sixteenBit ? 16 : 8,
                                  bytesPerRow: 0, space: rgbSpace, bitmapInfo: info) else { return nil }
        ctx.interpolationQuality = .high
        if let background {
            ctx.setFillColor(background)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        ctx.draw(image, in: inset ?? CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    /// High-quality resize. Big reductions halve repeatedly first so the final
    /// filter never skips source pixels (no aliasing in 16 px icons from 4K art).
    static func resized(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        if image.width == width && image.height == height { return image }
        let space = isRGB(image.colorSpace) ? (image.colorSpace ?? sRGB) : sRGB
        let alpha = hasAlpha(image)
        var current = image
        while current.width / 2 >= width * 2 && current.height / 2 >= height * 2 {
            guard let half = redraw(current, width: current.width / 2, height: current.height / 2, space: space,
                                    keepAlpha: alpha, background: nil) else { break }
            current = half
        }
        return redraw(current, width: width, height: height, space: space, keepAlpha: alpha, background: nil)
    }

    /// Centres a non-square image on a transparent square canvas (icons).
    static func paddedToSquare(_ image: CGImage) -> CGImage? {
        let side = max(image.width, image.height)
        if image.width == image.height { return image }
        let space = isRGB(image.colorSpace) ? (image.colorSpace ?? sRGB) : sRGB
        let rect = CGRect(x: (side - image.width) / 2, y: (side - image.height) / 2, width: image.width, height: image.height)
        return redraw(image, width: side, height: side, space: space, keepAlpha: true, background: nil, inset: rect)
    }

    // MARK: Colour option

    /// Parses `#RGB`, `#RRGGBB` or `#RRGGBBAA` (the `background` option). The result
    /// is always opaque, because it fills formats that can't store alpha.
    static func opaqueColor(_ text: String, default fallback: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)) -> CGColor {
        var hex = text.trimmingCharacters(in: .whitespaces)
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6 || hex.count == 8, let v = UInt64(hex, radix: 16) else { return fallback }
        let rgb = hex.count == 8 ? v >> 8 : v
        let r = CGFloat((rgb >> 16) & 0xFF) / 255, g = CGFloat((rgb >> 8) & 0xFF) / 255, b = CGFloat(rgb & 0xFF) / 255
        return CGColor(colorSpace: sRGB, components: [r, g, b, 1]) ?? fallback
    }
}
