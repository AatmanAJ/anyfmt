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

    // MARK: HDR

    /// Float or extended-range pixels (OpenEXR, HDR renders) that may exceed 1.0.
    static func isExtendedRange(_ image: CGImage) -> Bool {
        if image.bitmapInfo.contains(.floatComponents) { return true }
        return image.colorSpace.map { CGColorSpaceUsesExtendedRange($0) } ?? false
    }

    /// `image`, tone-mapped to SDR first if it holds HDR values.
    static func sdr(_ image: CGImage, sixteenBit: Bool = false) -> CGImage {
        guard isExtendedRange(image) else { return image }
        return toneMappedToSDR(image, sixteenBit: sixteenBit) ?? image
    }

    /// Brings extended-range pixels into SDR with an extended Reinhard curve on
    /// luminance, white point at the 99.9th percentile, so highlights roll off instead
    /// of clipping. Returns nil when nothing exceeds 1.0 (already SDR). Output is sRGB.
    static func toneMappedToSDR(_ image: CGImage, sixteenBit: Bool) -> CGImage? {
        let w = image.width, h = image.height
        guard let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { return nil }
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 32, bytesPerRow: w * 16, space: linear, bitmapInfo: info),
              let base = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        // Rows are exactly w * 16 bytes, so the buffer is one contiguous run of RGBA floats.
        let px = base.bindMemory(to: Float.self, capacity: w * h * 4)
        func luminance(_ i: Int) -> Float {
            let a = px[i + 3]
            guard a > 0 else { return 0 }
            return (0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]) / a
        }
        // Robust peak from a sample of at most ~65k pixels.
        let count = w * h
        let step = max(1, count / 65_536)
        var samples: [Float] = []
        samples.reserveCapacity(count / step + 1)
        for p in stride(from: 0, to: count, by: step) { samples.append(luminance(p * 4)) }
        samples.sort()
        let peak = samples[min(samples.count - 1, Int(Float(samples.count) * 0.999))]
        guard peak > 1.0001 else { return nil }
        let white2 = peak * peak
        for p in 0..<count {
            let i = p * 4
            let l = luminance(i)
            guard l > 0 else { continue }
            let mapped = l * (1 + l / white2) / (1 + l)
            let scale = mapped / l
            for c in 0..<3 { px[i + c] = min(px[i + 3], max(0, px[i + c] * scale)) }
        }
        guard let made = ctx.makeImage() else { return nil }
        return redraw(made, width: w, height: h, space: sRGB, sixteenBit: sixteenBit, keepAlpha: hasAlpha(image), background: nil)
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
