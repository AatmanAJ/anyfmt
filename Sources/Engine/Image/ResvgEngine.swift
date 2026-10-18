import Foundation
import ImageIO

/// SVG → PNG with the bundled resvg CLI (D-021). Renders at 2× the SVG's intrinsic
/// size by default, or with the longest edge at `maxDimension`, on a transparent
/// background. Other targets (JPG, PDF, WebP…) reach SVG through router hops via PNG.
public struct ResvgEngine: ConversionEngine {
    public let id = EngineIDs.resvg
    public init() {}

    /// Default render scale. 2× keeps text and edges crisp on Retina screens.
    static let defaultScale = 2.0
    /// Longest edge cap for the default scale, so a poster-sized SVG stays sane.
    static let defaultMaxEdge = 8192.0

    public func isAvailable(_ capability: Capability) -> Bool {
        EngineLocator.shared.resvg != nil && capability.to == Formats.png
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let resvg = context.locator.resvg else {
            throw ConversionError.engineMissing("resvg", detail: "not found in \(context.locator.helperDirectories.map(\.path))")
        }
        guard request.to == Formats.png else { throw ConversionError.unsupported(from: request.from, to: request.to) }
        let out = request.defaultOutputURL
        let work = try WorkFolder(in: request.outputDirectory)
        defer { work.remove() }
        let rendered = work.url.appendingPathComponent("render.png")

        let intrinsic = SVGSize.read(request.input)
        let maxDim = request.options.int(OptionKey.maxDimension, default: 0)
        var args = ["--quiet", "--resources-dir", request.input.deletingLastPathComponent().path]
        var scale = Self.defaultScale
        if maxDim > 0 {
            if let s = intrinsic, s.width > 0, s.height > 0 {
                args += s.width >= s.height ? ["-w", String(maxDim)] : ["-h", String(maxDim)]
                scale = Double(maxDim) / max(s.width, s.height)
            } else {
                args += ["-w", String(maxDim)]
                scale = 1
            }
        } else if let s = intrinsic, max(s.width, s.height) * scale > Self.defaultMaxEdge {
            scale = Self.defaultMaxEdge / max(s.width, s.height)
            args += ["-z", String(format: "%.4f", scale)]
        } else {
            args += ["-z", String(format: "%.1f", scale)]
        }
        args += [request.input.path, rendered.path]
        context.progress(0.1)
        do {
            _ = try await ProcessRunner.run(resvg, args)
        } catch ConversionError.engineFailed(_, _, let detail) {
            throw ConversionError.unreadable(request.input, detail: "resvg: \(detail)")
        }
        context.progress(0.8)
        // Tag the PNG with the render scale as DPI (72 × scale) so PDF pages and
        // print sizes come out at the SVG's own size.
        try Self.retag(rendered, to: out, dpi: 72 * scale)
        context.progress(1)
        return ConversionOutput(out)
    }

    private static func retag(_ png: URL, to out: URL, dpi: Double) throws {
        guard let src = CGImageSourceCreateWithURL(png as CFURL, nil), CGImageSourceGetCount(src) > 0 else {
            throw ConversionError.outputMissing("resvg produced no PNG")
        }
        let dest = try ImageWriter.create(out, uti: ImageUTI.png, count: 1)
        CGImageDestinationAddImageFromSource(dest, src, 0, [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
        try ImageWriter.finalize(dest, out)
    }
}

/// Reads an SVG's intrinsic size from the root element (width/height with units,
/// falling back to the viewBox). nil if it can't tell.
enum SVGSize {
    static func read(_ url: URL) -> CGSize? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let delegate = RootDelegate()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        parser.parse()
        guard let attrs = delegate.attributes else { return nil }
        let viewBox = attrs["viewBox"].flatMap(parseViewBox)
        let w = attrs["width"].flatMap { length($0, relativeTo: viewBox?.width) }
        let h = attrs["height"].flatMap { length($0, relativeTo: viewBox?.height) }
        switch (w, h, viewBox) {
        case let (w?, h?, _): return CGSize(width: w, height: h)
        case let (w?, nil, vb?) where vb.width > 0: return CGSize(width: w, height: w * vb.height / vb.width)
        case let (nil, h?, vb?) where vb.height > 0: return CGSize(width: h * vb.width / vb.height, height: h)
        case let (nil, nil, vb?): return vb
        default: return nil
        }
    }

    static func parseViewBox(_ s: String) -> CGSize? {
        let parts = s.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        guard parts.count == 4, parts[2] > 0, parts[3] > 0 else { return nil }
        return CGSize(width: parts[2], height: parts[3])
    }

    /// CSS length in px (96 dpi, as resvg does). Percentages resolve against the viewBox.
    static func length(_ s: String, relativeTo base: CGFloat?) -> CGFloat? {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        let units: [(String, Double)] = [("px", 1), ("pt", 96.0 / 72), ("pc", 16), ("mm", 96 / 25.4), ("cm", 96 / 2.54), ("in", 96), ("em", 16), ("ex", 8)]
        for (u, f) in units where t.hasSuffix(u) {
            return Double(t.dropLast(u.count)).map { CGFloat($0 * f) }
        }
        if t.hasSuffix("%") {
            guard let base, let p = Double(t.dropLast()) else { return nil }
            return base * CGFloat(p / 100)
        }
        return Double(t).map { CGFloat($0) }
    }

    private final class RootDelegate: NSObject, XMLParserDelegate {
        var attributes: [String: String]?
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            attributes = attributeDict
            parser.abortParsing()
        }
    }
}
