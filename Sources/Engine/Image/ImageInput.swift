import Foundation
import ImageIO

/// Frame timing of an animated source (GIF, animated WebP, APNG, AVIF sequence).
struct AnimationInfo: Sendable, Equatable {
    /// Seconds per frame, in order.
    let delays: [Double]
    /// 0 = loop forever.
    let loopCount: Int
    var frameCount: Int { delays.count }
    var totalDuration: Double { delays.reduce(0, +) }
}

/// An opened image file: the ImageIO source plus the facts every encoder needs.
/// Opened once per request and used synchronously inside `convert`.
struct ImageInput {
    let url: URL
    let source: CGImageSource
    /// UTI ImageIO detected (may differ from the extension: a PNG named .jpg).
    let type: String
    /// The image we convert: the primary image, or the largest size of an icon file.
    let index: Int
    let count: Int
    /// Properties of `index`.
    let properties: [CFString: Any]
    /// Stored (unrotated) pixel size of `index`.
    let pixelWidth: Int
    let pixelHeight: Int
    /// EXIF/TIFF orientation 1...8.
    let orientation: Int
    let hasAlpha: Bool
    /// Non-nil only for real animations (not TIFF pages or icon sizes).
    let animation: AnimationInfo?

    /// Size after orientation is applied.
    var orientedWidth: Int { orientation >= 5 ? pixelHeight : pixelWidth }
    var orientedHeight: Int { orientation >= 5 ? pixelWidth : pixelHeight }
    var longestEdge: Int { max(pixelWidth, pixelHeight) }
    var isAnimated: Bool { animation != nil }

    /// TIFF pages (a document) as opposed to icon sizes or animation frames.
    var isMultiPageDocument: Bool { type == ImageUTI.tiff && count > 1 }

    static func open(_ url: URL, format: FormatID) throws -> ImageInput {
        var opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        if let hint = Formats.format(format)?.typeIdentifiers.first { opts[kCGImageSourceTypeIdentifierHint] = hint }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, opts as CFDictionary) else {
            throw ConversionError.unreadable(url, detail: "CGImageSourceCreateWithURL returned nil")
        }
        let count = CGImageSourceGetCount(src)
        guard count > 0, CGImageSourceGetStatus(src) == .statusComplete else {
            throw ConversionError.unreadable(url, detail: "ImageIO status \(CGImageSourceGetStatus(src).rawValue), \(count) images")
        }
        let type = (CGImageSourceGetType(src) as String?) ?? ""
        let index = Self.chooseIndex(src, type: type, count: count)
        let props = (CGImageSourceCopyPropertiesAtIndex(src, index, nil) as? [CFString: Any]) ?? [:]
        let w = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let h = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0
        guard w > 0, h > 0 else {
            throw ConversionError.unreadable(url, detail: "no pixel size at index \(index)")
        }
        let orientation = (props[kCGImagePropertyOrientation] as? Int).flatMap { (1...8).contains($0) ? $0 : nil } ?? 1
        let hasAlpha = (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
        let animation = count > 1 ? Self.animationInfo(src, type: type, count: count) : nil
        return ImageInput(url: url, source: src, type: type, index: index, count: count, properties: props,
                          pixelWidth: w, pixelHeight: h, orientation: orientation, hasAlpha: hasAlpha, animation: animation)
    }

    /// Icon files hold several sizes: use the biggest. Everything else: the primary image
    /// (first frame of an animation, first page of a TIFF).
    private static func chooseIndex(_ src: CGImageSource, type: String, count: Int) -> Int {
        guard count > 1 else { return 0 }
        if type == ImageUTI.ico || type == ImageUTI.icns || type == "com.microsoft.cur" {
            var best = 0, bestArea = -1
            for i in 0..<count {
                guard let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any] else { continue }
                let area = ((p[kCGImagePropertyPixelWidth] as? Int) ?? 0) * ((p[kCGImagePropertyPixelHeight] as? Int) ?? 0)
                if area > bestArea { best = i; bestArea = area }
            }
            return best
        }
        let primary = CGImageSourceGetPrimaryImageIndex(src)
        return primary < count ? primary : 0
    }

    /// Dictionary key holding frame timing for each animated container.
    private static func animationKey(for type: String) -> CFString? {
        switch type {
        case ImageUTI.gif: kCGImagePropertyGIFDictionary
        case ImageUTI.webp: kCGImagePropertyWebPDictionary
        case ImageUTI.png: kCGImagePropertyPNGDictionary
        case ImageUTI.avis, ImageUTI.avif: kCGImagePropertyAVISDictionary
        case "public.heics": kCGImagePropertyHEICSDictionary
        default: nil
        }
    }

    private static func animationInfo(_ src: CGImageSource, type: String, count: Int) -> AnimationInfo? {
        guard let key = animationKey(for: type) else { return nil }
        let container = CGImageSourceCopyProperties(src, nil) as? [CFString: Any]
        let animDict = container?[key] as? [CFString: Any]
        // Multi-item HEIF/AVIF files aren't animations unless the container says so.
        if type != ImageUTI.gif && animDict == nil { return nil }
        var delays: [Double] = []
        delays.reserveCapacity(count)
        for i in 0..<count {
            let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
            let d = p?[key] as? [CFString: Any]
            let unclamped = (d?["UnclampedDelayTime" as CFString] as? Double) ?? 0
            let clamped = (d?["DelayTime" as CFString] as? Double) ?? 0
            // Browsers treat delays under 20 ms as 100 ms; so do we, so output plays at the same speed.
            let raw = unclamped >= 0.02 ? unclamped : clamped
            delays.append(raw >= 0.02 ? raw : 0.1)
        }
        let loop = (animDict?["LoopCount" as CFString] as? Int) ?? 0
        return AnimationInfo(delays: delays, loopCount: max(0, loop))
    }
}
