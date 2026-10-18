import Foundation

// Owned by lane D (Image + PDF). Declarative: every image/SVG/PDF route is a row here.
//
// Inputs we can fixture and decode: the raster formats below, SVG (resvg) and PDF
// (PDFKit). JPEG XL and camera RAW decode in ImageIO but can't be generated as
// fixtures on a stock Mac, so they don't ship yet (docs/lanes/D-image.md).
public enum ImageRoutes {
    /// Raster formats ImageIO decodes.
    public static let rasterInputs: [FormatID] = [
        Formats.jpg, Formats.png, Formats.webp, Formats.heic, Formats.heif, Formats.tiff, Formats.avif, Formats.bmp,
        Formats.gif, Formats.jp2, Formats.psd, Formats.ico, Formats.icns, Formats.tga, Formats.exr,
    ]

    /// Targets on the wheel by default (the familiar set, plus icons).
    public static let primaryOutputs: [FormatID] = [
        Formats.jpg, Formats.png, Formats.webp, Formats.heic, Formats.tiff, Formats.avif, Formats.bmp, Formats.gif,
        Formats.pdf, Formats.ico, Formats.icns,
    ]

    /// Specialist targets: CLI, matrix and the wheel's "more" ring only.
    public static let extraOutputs: [FormatID] = [Formats.heif, Formats.jp2, Formats.psd, Formats.tga, Formats.exr]

    /// PDF page renders.
    public static let pdfImageOutputs: [FormatID] = PDFKitEngine.imageOutputs

    /// Pixel-exact for 8-bit sRGB content; the router prefers these as intermediates.
    static let losslessOutputs: Set<FormatID> = [Formats.png, Formats.tiff, Formats.bmp, Formats.psd, Formats.tga]

    public static let rows: [Capability] = imageIORows + ocrRows + ffmpegRows + svgRows + pdfRows

    // MARK: Row groups

    /// ImageIO's GIF writer is the fallback (40): it bands on gradients. ffmpeg's
    /// palettegen/paletteuse row (90) wins whenever the bundled ffmpeg is present.
    static let imageIORows: [Capability] = ImageIOEngine.outputs.flatMap { to in
        Capability.grid(rasterInputs, [to], EngineIDs.imageIO, schema: schema(for:), priority: to == Formats.gif ? 40 : 100,
                        cost: 1, flags: flags(for: to))
    }

    /// Image → TXT with on-device Vision OCR (screenshots, photos of documents).
    /// Not on the wheel by default; text extraction is terminal and drops layout.
    static let ocrRows: [Capability] = rasterInputs.map {
        Capability($0, Formats.txt, EngineIDs.imageIO, schema: .none, priority: 100, cost: 2,
                   flags: [.terminalOnly, .lossyStructure, .hiddenByDefault])
    }

    /// WebP is ffmpeg-only (ImageIO never encodes it). AVIF here is the fallback for
    /// Macs whose ImageIO lacks an AVIF encoder; the ImageIO row wins when it's available.
    /// GIF here is the preferred encoder (optimal palette + dithering).
    static let ffmpegRows: [Capability] =
        Capability.grid(rasterInputs, [Formats.webp], EngineIDs.ffmpegImage, schema: schema(for:), priority: 60, cost: 1.5, flags: flags(for: Formats.webp))
        + Capability.grid(rasterInputs, [Formats.avif], EngineIDs.ffmpegImage, schema: schema(for:), priority: 60, cost: 2.5, flags: flags(for: Formats.avif))
        + Capability.grid(rasterInputs, [Formats.gif], EngineIDs.ffmpegImage, schema: schema(for:), priority: 90, cost: 1.5, flags: flags(for: Formats.gif))

    /// SVG renders to PNG; every other SVG target is a router hop through PNG.
    static let svgRows: [Capability] = [
        Capability(Formats.svg, Formats.png, EngineIDs.resvg, schema: StandardSchemas.imageLossless, priority: 90, cost: 1, flags: .lossless),
    ]

    static let pdfRows: [Capability] =
        pdfImageOutputs.map { Capability(Formats.pdf, $0, EngineIDs.pdfKit, schema: StandardSchemas.pdfRender, priority: 100, cost: 2, flags: .multiOutput) }
        + [Capability(Formats.pdf, Formats.txt, EngineIDs.pdfKit, schema: .none, priority: 100, cost: 1, flags: [.terminalOnly, .lossyStructure])]

    // MARK: Schemas and flags

    static func schema(for to: FormatID) -> OptionsSchema {
        switch to {
        case Formats.jpg: StandardSchemas.imageOpaque
        case Formats.webp: StandardSchemas.imageLosslessCapable
        case Formats.heic, Formats.heif, Formats.avif, Formats.jp2: StandardSchemas.imageLossy
        case Formats.bmp: StandardSchemas.imageOpaqueLossless
        case Formats.pdf: StandardSchemas.toPDF
        default: StandardSchemas.imageLossless // png tiff gif psd tga exr ico icns
        }
    }

    static func flags(for to: FormatID) -> CapabilityFlags {
        var f: CapabilityFlags = []
        if losslessOutputs.contains(to) { f.insert(.lossless) }
        if extraOutputs.contains(to) { f.insert(.hiddenByDefault) }
        return f
    }
}
