import Foundation
import ImageIO
import CoreGraphics

/// Raster image → PDF, one page per image (every page of a multi-page TIFF).
/// Pixels are embedded at native resolution; the page size option only decides
/// the paper around them.
enum ImagePDFWriter {
    enum PageSize: String { case fit, a4, letter }

    static let a4 = CGSize(width: 595.28, height: 841.89)
    static let letter = CGSize(width: 612, height: 792)
    /// Margin used on fixed paper sizes (½ inch).
    static let margin: CGFloat = 36

    /// Formats whose pixels are already lossy: re-embedded as high-quality JPEG
    /// data so a 12 MP photo doesn't become a 40 MB Flate-compressed page.
    private static let lossySources: Set<String> = [ImageUTI.jpeg, ImageUTI.heic, ImageUTI.heif, ImageUTI.avif, ImageUTI.webp, ImageUTI.jp2, "public.heics"]

    static func write(_ input: ImageInput, to url: URL, pageSize: String, policy: MetadataPolicy, title: String) throws {
        let size = PageSize(rawValue: pageSize) ?? .fit
        var info: [CFString: Any] = [kCGPDFContextCreator: Brand.name]
        if policy != .stripAll { info[kCGPDFContextTitle] = title }
        guard let consumer = CGDataConsumer(url: url as CFURL) else {
            throw ConversionError.engineFailed("PDF", status: 0, detail: "cannot open \(url.path) for writing")
        }
        var defaultBox = CGRect(origin: .zero, size: letter)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &defaultBox, info as CFDictionary) else {
            throw ConversionError.engineFailed("PDF", status: 0, detail: "CGContext(consumer:) failed")
        }
        let pages = input.isMultiPageDocument ? Array(0..<input.count) : [input.index]
        for i in pages {
            try Task.checkCancellation()
            let decoded = ImageOps.sdr(try ImageOps.decode(input, index: i))
            let image = embeddable(decoded, lossySource: lossySources.contains(input.type))
            let dpi = dpi(of: input, index: i)
            let natural = CGSize(width: CGFloat(image.width) * 72 / dpi.x, height: CGFloat(image.height) * 72 / dpi.y)
            let (media, rect) = layout(natural: natural, size: size)
            var box = media
            let boxData = withUnsafeBytes(of: &box) { Data($0) }
            ctx.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
            ctx.interpolationQuality = .high
            ctx.draw(image, in: rect)
            ctx.endPDFPage()
        }
        ctx.closePDF()
    }

    /// Page box and image rect. `fit` = the image's own size at its DPI; paper sizes
    /// turn to match the image, keep ½-inch margins and only ever shrink the image.
    static func layout(natural: CGSize, size: PageSize) -> (page: CGRect, image: CGRect) {
        let paper: CGSize
        switch size {
        case .fit:
            return (CGRect(origin: .zero, size: natural), CGRect(origin: .zero, size: natural))
        case .a4: paper = a4
        case .letter: paper = letter
        }
        let landscape = natural.width > natural.height
        let page = landscape ? CGSize(width: paper.height, height: paper.width) : paper
        let avail = CGSize(width: page.width - 2 * margin, height: page.height - 2 * margin)
        let scale = min(1, avail.width / natural.width, avail.height / natural.height)
        let w = natural.width * scale, h = natural.height * scale
        let rect = CGRect(x: (page.width - w) / 2, y: (page.height - h) / 2, width: w, height: h)
        return (CGRect(origin: .zero, size: page), rect)
    }

    private static func dpi(of input: ImageInput, index: Int) -> (x: CGFloat, y: CGFloat) {
        let p = index == input.index ? input.properties : (CGImageSourceCopyPropertiesAtIndex(input.source, index, nil) as? [CFString: Any] ?? [:])
        func read(_ k: CFString) -> CGFloat {
            let v = (p[k] as? Double) ?? 72
            return v >= 1 && v <= 10_000 ? CGFloat(v) : 72
        }
        return (read(kCGImagePropertyDPIWidth), read(kCGImagePropertyDPIHeight))
    }

    /// Quartz keeps JPEG-backed images as DCT streams in the PDF, so photos are
    /// round-tripped through in-memory JPEG (q 0.92). Images with alpha, and
    /// lossless sources (screenshots, line art), stay lossless.
    private static func embeddable(_ image: CGImage, lossySource: Bool) -> CGImage {
        guard lossySource, !ImageOps.hasAlpha(image) else { return image }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, ImageUTI.jpeg as CFString, 1, nil) else { return image }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(dest),
              let src = CGImageSourceCreateWithData(data, nil),
              let jpeg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return image }
        return jpeg
    }
}
