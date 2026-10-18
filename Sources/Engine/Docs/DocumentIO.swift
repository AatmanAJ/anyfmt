import Foundation

/// Option keys owned by the docs lane (the shared ones live in `OptionKey`).
public enum DocsOptionKey {
    /// Markdown output: "embed" images as data URIs or "omit" them.
    public static let images = "images"
    /// CSV/TSV output: prefix a UTF-8 byte order mark (Excel on Windows likes it).
    public static let bom = "bom"
}

public enum DocsSchemas {
    public static let markdown = OptionsSchema("doc.md", [
        OptionSpec(DocsOptionKey.images, L("Images"), .choice([
            OptionChoice("embed", L("Embed in the file")), OptionChoice("omit", L("Leave out")),
        ]), default: .string("embed")),
    ])

    public static let delimited = OptionsSchema("sheet.delimited", [
        OptionSpec(OptionKey.sheet, L("Sheets"), .choice([
            OptionChoice("first", L("First sheet")), OptionChoice("all", L("All sheets (one file each)")),
        ]), default: .string("first")),
        OptionSpec(DocsOptionKey.bom, L("Add byte order mark (for Excel on Windows)"), .toggle, default: .bool(false)),
    ])

    /// Slides → images: resolution of the rendered pages.
    public static let slideImages = OptionsSchema("slides.images", [
        OptionSpec(OptionKey.dpi, L("Resolution"), .choice([
            OptionChoice("72", "72 DPI"), OptionChoice("150", "150 DPI"), OptionChoice("300", "300 DPI"),
        ]), default: .string("150")),
        OptionSpec(OptionKey.quality, L("Quality"), .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(90)),
    ])
}

/// Reads any supported document format into a `DocModel` and writes one back out.
public enum DocumentIO {
    /// Formats with a reader.
    public static let readable: [FormatID] = [
        Formats.docx, Formats.odt, Formats.md, Formats.txt, Formats.html, Formats.rtf, Formats.rtfd,
        Formats.doc, Formats.webarchive, Formats.textClipping, Formats.epub, Formats.pdf,
    ]
    /// Formats with a writer.
    public static let writable: [FormatID] = [
        Formats.docx, Formats.odt, Formats.md, Formats.txt, Formats.html, Formats.rtf, Formats.rtfd, Formats.epub, Formats.pdf,
    ]

    public static func read(_ url: URL, format: FormatID) throws -> DocModel {
        do {
            switch format {
            case Formats.md: return MarkdownReader.parse(TextDecoding.decode(try Data(contentsOf: url)), baseURL: url.deletingLastPathComponent())
            case Formats.txt: return PlainTextReader.parse(TextDecoding.decode(try Data(contentsOf: url)))
            case Formats.html: return HTMLReader.read(TextDecoding.decode(try Data(contentsOf: url)), baseURL: url.deletingLastPathComponent())
            case Formats.docx: return try DOCXReader.read(url)
            case Formats.odt: return try ODTReader.read(url)
            case Formats.rtf, Formats.rtfd, Formats.doc: return try AttributedReader.read(url, format: format)
            case Formats.webarchive: return try WebArchiveReader.read(url)
            case Formats.textClipping: return try TextClippingReader.read(url)
            case Formats.epub: return try EPUBReader.read(url)
            case Formats.pdf: return try PDFDocReader.read(url)
            default: throw ConversionError.unsupported(from: format, to: Formats.txt)
            }
        } catch let e as ConversionError {
            throw e
        } catch {
            throw ConversionError.unreadable(url, detail: "\(error)")
        }
    }

    public static func write(_ doc: DocModel, format: FormatID, to url: URL, options: OptionValues) async throws {
        switch format {
        case Formats.docx:
            try DOCXWriter(pageSize: PageSize.from(options)).write(doc).write(to: url, options: .atomic)
        case Formats.odt:
            try ODTWriter(pageSize: PageSize.from(options)).write(doc).write(to: url, options: .atomic)
        case Formats.md:
            let images: MarkdownWriter.Images = options.string(DocsOptionKey.images, default: "embed") == "omit" ? .omit : .embed
            try Data(MarkdownWriter(images: images).write(doc).utf8).write(to: url, options: .atomic)
        case Formats.txt:
            try Data(PlainTextWriter().write(doc).utf8).write(to: url, options: .atomic)
        case Formats.html:
            try Data(HTMLWriter(flavor: .web).document(doc).utf8).write(to: url, options: .atomic)
        case Formats.rtf:
            try AttributedWriter().writeRTF(doc, to: url)
        case Formats.rtfd:
            try AttributedWriter().writeRTFD(doc, to: url)
        case Formats.epub:
            try EPUBWriter().write(doc).write(to: url, options: .atomic)
        case Formats.pdf:
            let html = HTMLWriter(flavor: .print).document(doc)
            try await WebPDFRenderer.render(html: html, to: url, page: .init(PageSize.from(options)))
        default:
            throw ConversionError.unsupported(from: Formats.md, to: format)
        }
    }

    /// Applies the user's metadata policy to document properties.
    static func apply(_ policy: MetadataPolicy, to doc: inout DocModel) {
        switch policy {
        case .keep: break
        case .stripPrivate: doc.metadata.author = nil
        case .stripAll: doc.metadata = DocMetadata(language: doc.metadata.language)
        }
    }

    /// Shared conversion step for the model-based engines.
    static func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        context.progress(0.05)
        var doc = try read(request.input, format: request.from)
        try Task.checkCancellation()
        apply(request.metadata, to: &doc)
        context.progress(0.5)
        let out = request.defaultOutputURL
        try await write(doc, format: request.to, to: out, options: request.options)
        try Task.checkCancellation()
        context.progress(1)
        return ConversionOutput(out)
    }
}
