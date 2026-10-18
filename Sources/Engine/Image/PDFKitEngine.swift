import Foundation
import ImageIO
import PDFKit

/// PDFKit: PDF pages → images at a chosen DPI (all pages or a range), and PDF → plain
/// text. Page images are rendered on white (paper), in sRGB. Because multi-output
/// rows can't chain, this engine encodes every image target itself, borrowing the
/// ImageIO and ffmpeg-image encoders.
///
/// Naming inside the work dir: a one-page PDF gives `name.png`; longer PDFs give
/// `name-001.png`, `name-002.png`… numbered by real page number.
public struct PDFKitEngine: ConversionEngine {
    public let id = EngineIDs.pdfKit
    public init() {}

    static let imageOutputs: [FormatID] = [Formats.png, Formats.jpg, Formats.heic, Formats.webp, Formats.tiff, Formats.avif, Formats.bmp]
    /// Default and bounds for the DPI option.
    static let defaultDPI = 300
    static let dpiRange = 36...1200
    /// Longest rendered edge; a 600 DPI A0 poster would otherwise need 1.4 GB of RAM.
    static let maxPixelEdge = 16_384.0
    /// Resolution used to OCR pages that have no text layer.
    static let ocrDPI = 200.0

    public func isAvailable(_ capability: Capability) -> Bool {
        guard capability.from == Formats.pdf else { return false }
        switch capability.to {
        case Formats.txt: return true
        case Formats.webp: return EngineLocator.shared.ffmpeg != nil
        case Formats.avif: return ImageIOSupport.canEncodeAVIF || EngineLocator.shared.ffmpeg != nil
        default:
            guard Self.imageOutputs.contains(capability.to), let uti = ImageTargetTraits.forFormat(capability.to)?.uti else { return false }
            return ImageIOSupport.canEncode(uti)
        }
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let doc = try Self.open(request.input)
        if request.to == Formats.txt {
            let out = request.defaultOutputURL
            try Self.extractText(doc, input: request.input, to: out, progress: context.progress)
            return ConversionOutput(out)
        }
        guard Self.imageOutputs.contains(request.to) else { throw ConversionError.unsupported(from: request.from, to: request.to) }
        let pageNumbers: [Int]
        do {
            pageNumbers = try PageRange.parse(request.options.string(OptionKey.pages, default: ""), pageCount: doc.pageCount)
        } catch {
            throw ConversionError.invalidOption(request.options.string(OptionKey.pages, default: ""))
        }
        guard !pageNumbers.isEmpty else { throw ConversionError.invalidOption(request.options.string(OptionKey.pages, default: "")) }
        let dpi = Double(min(Self.dpiRange.upperBound, max(Self.dpiRange.lowerBound, request.options.int(OptionKey.dpi, default: Self.defaultDPI))))
        let digits = max(3, String(doc.pageCount).count)
        let ext = Formats.extension(for: request.to)
        let work = try WorkFolder(in: request.outputDirectory)
        defer { work.remove() }
        var outputs: [URL] = []
        for (n, number) in pageNumbers.enumerated() {
            try Task.checkCancellation()
            guard let page = doc.page(at: number - 1), let image = Self.render(page, dpi: dpi) else {
                throw ConversionError.unreadable(request.input, detail: "PDFKit could not render page \(number)")
            }
            let name = doc.pageCount == 1 ? request.baseName : "\(request.baseName)-\(String(repeating: "0", count: max(0, digits - String(number).count)))\(number)"
            let url = request.outputDirectory.appendingPathComponent(name).appendingPathExtension(ext)
            let sink = context.progress.scaled(Double(n) / Double(pageNumbers.count)...Double(n + 1) / Double(pageNumbers.count))
            try await Self.encode(image, as: request.to, to: url, dpi: dpi, options: request.options, work: work.url, context: context, progress: sink)
            outputs.append(url)
        }
        context.progress(1)
        return ConversionOutput(outputs)
    }

    // MARK: Open

    static func open(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else {
            throw ConversionError.unreadable(url, detail: "PDFDocument(url:) returned nil")
        }
        // Owner-password-only PDFs open with an empty user password.
        if doc.isLocked && !doc.unlock(withPassword: "") {
            throw ConversionError.other(L("“\(url.lastPathComponent)” is password-protected. Open it in Preview, remove the password, then try again."),
                                        detail: "encrypted PDF: \(url.path)")
        }
        guard doc.pageCount > 0 else { throw ConversionError.unreadable(url, detail: "PDF has no pages") }
        return doc
    }

    // MARK: Render

    /// One page on white at `dpi`, honouring the page's rotation and crop box.
    static func render(_ page: PDFPage, dpi: Double) -> CGImage? {
        let box = page.bounds(for: .cropBox)
        let rotation = ((page.rotation % 360) + 360) % 360
        let (wPt, hPt) = rotation % 180 == 0 ? (box.width, box.height) : (box.height, box.width)
        guard wPt > 0, hPt > 0 else { return nil }
        var scale = dpi / 72
        if Double(max(wPt, hPt)) * scale > maxPixelEdge { scale = maxPixelEdge / Double(max(wPt, hPt)) }
        let w = max(1, Int((Double(wPt) * scale).rounded())), h = max(1, Int((Double(hPt) * scale).rounded()))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: ImageOps.sRGB,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(colorSpace: ImageOps.sRGB, components: [1, 1, 1, 1]) ?? CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.setShouldAntialias(true)
        ctx.scaleBy(x: CGFloat(Double(w) / Double(wPt)), y: CGFloat(Double(h) / Double(hPt)))
        // draw(with:to:) applies the page's rotation and box origin itself.
        page.draw(with: .cropBox, to: ctx)
        return ctx.makeImage()
    }

    /// Encodes one rendered page. DPI is recorded so the image prints at page size.
    static func encode(_ image: CGImage, as format: FormatID, to url: URL, dpi: Double, options: OptionValues,
                       work: URL, context: EngineContext, progress: ProgressSink) async throws {
        let ffmpeg = FFmpeg(locator: context.locator)
        let dpiProps: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
        switch format {
        case Formats.webp:
            let still = PreparedStill(image: image, properties: [:], metadataTree: nil)
            try await FFmpegImageEngine.stillWebP(still, policy: .stripAll, options: options, to: url, work: work, ffmpeg: ffmpeg, progress: progress)
        case Formats.avif where !ImageIOSupport.canEncodeAVIF:
            try await FFmpegImageEngine.stillAVIF(image, options: options, to: url, work: work, ffmpeg: ffmpeg, progress: progress)
        default:
            guard let traits = ImageTargetTraits.forFormat(format), let uti = traits.uti else {
                throw ConversionError.unsupported(from: Formats.pdf, to: format)
            }
            var props = dpiProps
            if traits.lossy {
                props[kCGImageDestinationLossyCompressionQuality] = Double(min(100, max(1, options.int(OptionKey.quality, default: 90)))) / 100
            }
            if format == Formats.tiff { props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFCompression: 5] }
            try ImageWriter.write(image, to: url, uti: uti, options: props)
            progress(1)
        }
    }

    // MARK: Text

    /// Page texts separated by a form feed on its own line (the pdftotext convention,
    /// shown as a page break by TextEdit and `less`). Pages without a text layer
    /// (scans) are read with Vision OCR.
    static func extractText(_ doc: PDFDocument, input: URL, to out: URL, progress: ProgressSink) throws {
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            try Task.checkCancellation()
            guard let page = doc.page(at: i) else { continue }
            var text = page.string ?? ""
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let image = render(page, dpi: ocrDPI) {
                text = (try? TextRecognizer.text(in: image)) ?? ""
            }
            pages.append(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines))
            progress(Double(i + 1) / Double(doc.pageCount))
        }
        guard pages.contains(where: { !$0.isEmpty }) else { throw TextRecognizer.noTextError(input) }
        let body = pages.joined(separator: "\n\u{0C}\n") + "\n"
        try Data(body.utf8).write(to: out, options: .withoutOverwriting)
    }
}
