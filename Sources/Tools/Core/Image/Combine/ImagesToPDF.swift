import Foundation
import CoreGraphics
import ImageIO

/// EXIF orientation as an affine transform, so a raw (stored) image can be
/// drawn upright without re-rendering its pixels. In y-up space it maps the
/// raw image rect (0, 0, w, h) onto the upright rect (0, 0, W, H).
public enum OrientationTransform {
    public static func transform(_ o: CGImagePropertyOrientation, width w: CGFloat, height h: CGFloat) -> CGAffineTransform {
        switch o {
        case .up: .identity
        case .upMirrored: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)
        case .down: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: w, ty: h)
        case .downMirrored: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
        case .leftMirrored: CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: h, ty: w)
        case .right: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w)
        case .rightMirrored: CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case .left: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
        }
    }

    /// Draws `raw` upright into `rect` (y-up user space).
    static func draw(_ raw: CGImage, orientation: CGImagePropertyOrientation, in rect: CGRect, context ctx: CGContext) {
        let w = CGFloat(raw.width), h = CGFloat(raw.height)
        let upright = orientation.swapsAxes ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.minY)
        ctx.scaleBy(x: rect.width / upright.width, y: rect.height / upright.height)
        ctx.concatenate(transform(orientation, width: w, height: h))
        ctx.draw(raw, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
    }
}

/// Page geometry for Images → PDF. Shared with the editor's page preview.
public enum PDFPagePlan {
    public static let a4 = CGSize(width: 595.276, height: 841.89)
    public static let letter = CGSize(width: 612, height: 792)
    public static let margin: CGFloat = 24
    static let maxPageEdge: CGFloat = 14_400 // PDF implementation limit (200 in)

    /// Media box and image frame (points, y-up) for an upright image of
    /// `pixels` at `dpi`. Paper pages turn landscape for landscape images
    /// and never enlarge an image beyond its natural size.
    public static func page(for pixels: CGSize, dpi: CGFloat, pageSize: String) -> (media: CGRect, frame: CGRect) {
        let scale = 72 / max(72, dpi)
        var natural = CGSize(width: pixels.width * scale, height: pixels.height * scale)
        let longest = max(natural.width, natural.height)
        if longest > maxPageEdge { natural = CGSize(width: natural.width * maxPageEdge / longest, height: natural.height * maxPageEdge / longest) }
        let paper: CGSize? = switch pageSize {
        case "a4": a4
        case "letter": letter
        default: nil
        }
        guard var p = paper else {
            let media = CGRect(origin: .zero, size: natural)
            return (media, media)
        }
        if natural.width > natural.height { p = CGSize(width: p.height, height: p.width) }
        let box = CGRect(origin: .zero, size: p).insetBy(dx: margin, dy: margin)
        let s = min(1, box.width / natural.width, box.height / natural.height)
        let size = CGSize(width: natural.width * s, height: natural.height * s)
        let frame = CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height)
        return (CGRect(origin: .zero, size: p), frame)
    }
}

/// Tool 10: Images → PDF, one image per page. JPEGs are embedded as-is
/// (Quartz passes DCT data through when the image comes straight from
/// ImageIO), and orientation is applied with a transform, so no photo is
/// recompressed.
struct ImagesToPDFRunner: ToolRunner {
    let id = ToolIDs.imagesToPDF

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let inputs = OrderOption.apply(request.options.string("order", default: ""), to: request.inputs)
        guard !inputs.isEmpty else { throw ConversionError.invalidOption("inputs") }
        let pageSize = request.options.string(OptionKey.pageSize, default: "fit")
        let out = ToolOutput(request: request)
        let url = try out.url(ext: "pdf")
        var aux: [String: Any] = [:]
        if request.metadata != .stripAll {
            aux[kCGPDFContextCreator as String] = Brand.name
            aux[kCGPDFContextTitle as String] = request.baseName
        }
        guard let ctx = CGContext(url as CFURL, mediaBox: nil, aux as CFDictionary) else {
            throw ConversionError.other(L("The PDF couldn’t be created."), detail: "CGPDFContext at \(url.path)")
        }
        var finished = false
        defer {
            if !finished { ctx.closePDF(); try? FileManager.default.removeItem(at: url) }
        }
        for (i, input) in inputs.enumerated() {
            try Task.checkCancellation()
            guard let src = CGImageSourceCreateWithURL(input as CFURL, nil), CGImageSourceGetCount(src) > 0,
                  let raw = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                throw ConversionError.unreadable(input, detail: "ImageIO could not open")
            }
            let props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]) ?? [:]
            let o = ImageSupport.orientation(of: props)
            let dpi = CGFloat((props[kCGImagePropertyDPIWidth as String] as? NSNumber)?.doubleValue ?? 72)
            let pixels = o.swapsAxes ? CGSize(width: raw.height, height: raw.width) : CGSize(width: raw.width, height: raw.height)
            let plan = PDFPagePlan.page(for: pixels, dpi: dpi, pageSize: pageSize)
            var media = plan.media
            let boxData = Data(bytes: &media, count: MemoryLayout<CGRect>.size)
            ctx.beginPDFPage([kCGPDFContextMediaBox as String: boxData] as CFDictionary)
            ctx.interpolationQuality = .high
            OrientationTransform.draw(raw, orientation: o, in: plan.frame, context: ctx)
            ctx.endPDFPage()
            context.progress(Double(i + 1) / Double(inputs.count) * 0.95)
        }
        ctx.closePDF()
        finished = true
        context.progress(1)
        return ConversionOutput(url)
    }
}
