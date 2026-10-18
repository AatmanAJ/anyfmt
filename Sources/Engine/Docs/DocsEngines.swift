import Foundation
import UniformTypeIdentifiers

// Lane F engines (documents, slides, spreadsheets, EPUB). Rows live in DocsRoutes.swift.
public enum DocsEngines {
    public static let all: [any ConversionEngine] = [
        MarkdownEngine(), OOXMLEngine(), EPUBEngine(), WebKitPDFEngine(), AttributedTextEngine(),
        TextClippingEngine(), SheetsEngine(), QuickLookEngine(), PagesAppleEventsEngine(), OfficePackEngine(),
        PandocPackEngine(),
    ]
}

/// Markdown, plain text and HTML output from the document model.
public struct MarkdownEngine: ConversionEngine {
    public let id = EngineIDs.markdown
    public init() {}
    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        try await DocumentIO.convert(request, context: context)
    }
}

/// Our own OOXML/ODF writers: DOCX/ODT from the model, PDF → PPTX (page images),
/// PDF → XLSX (table reconstruction).
public struct OOXMLEngine: ConversionEngine {
    public let id = EngineIDs.ooxmlWriter
    public init() {}
    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let out = request.defaultOutputURL
        switch (request.from, request.to) {
        case (Formats.pdf, Formats.pptx):
            let title = request.metadata == .keep ? request.input.deletingPathExtension().lastPathComponent : nil
            let data = try PPTXWriter().write(pdf: request.input, title: title, progress: context.progress.scaled(0...0.95))
            try data.write(to: out, options: .atomic)
            context.progress(1)
            return ConversionOutput(out)
        case (Formats.pdf, Formats.xlsx):
            let wb = try PDFTableExtractor.workbook(request.input)
            try XLSXWriter().write(wb).write(to: out, options: .atomic)
            return ConversionOutput(out)
        default:
            return try await DocumentIO.convert(request, context: context)
        }
    }
}

public struct EPUBEngine: ConversionEngine {
    public let id = EngineIDs.epub
    public init() {}
    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        try await DocumentIO.convert(request, context: context)
    }
}

/// Anything → PDF through WebKit's paginating print path. HTML and web archives
/// are rendered as-is (their own CSS); every other format goes through the model.
public struct WebKitPDFEngine: ConversionEngine {
    public let id = EngineIDs.webKitPDF
    public init() {}
    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let out = request.defaultOutputURL
        let page = WebPDFRenderer.PageSetup(PageSize.from(request.options))
        switch request.from {
        case Formats.html, Formats.webarchive:
            context.progress(0.1)
            try await WebPDFRenderer.render(fileURL: request.input, readAccess: request.input.deletingLastPathComponent(), to: out, page: page)
            context.progress(1)
            return ConversionOutput(out)
        default:
            return try await DocumentIO.convert(request, context: context)
        }
    }
}

/// AppKit's text system for RTF/RTFD/DOC ↔ RTF/RTFD (keeps fonts and colours),
/// and the model path for everything else that targets RTF/RTFD.
public struct AttributedTextEngine: ConversionEngine {
    public let id = EngineIDs.attributedText
    public init() {}
    static let native: Set<FormatID> = [Formats.rtf, Formats.rtfd, Formats.doc]

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        if Self.native.contains(request.from), request.to == Formats.rtf || request.to == Formats.rtfd {
            let (s, attrs) = try AttributedReader.load(request.input, format: request.from)
            var keep = attrs
            if request.metadata != .keep { keep[.author] = nil; keep[.company] = nil }
            if request.metadata == .stripAll { keep = [:] }
            let out = request.defaultOutputURL
            try AttributedWriter.write(s, attributes: keep, as: request.to, to: out)
            return ConversionOutput(out)
        }
        return try await DocumentIO.convert(request, context: context)
    }
}

/// Finder text clippings → plain text / RTF straight from the clipping's own flavours.
public struct TextClippingEngine: ConversionEngine {
    public let id = EngineIDs.textClipping
    public init() {}
    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let out = request.defaultOutputURL
        let content = try TextClippingReader.content(request.input)
        switch (request.to, content) {
        case (Formats.txt, .text(let t)):
            try Data((t.hasSuffix("\n") ? t : t + "\n").utf8).write(to: out, options: .atomic)
        case (Formats.txt, .attributed(let s)):
            try Data((s.string.hasSuffix("\n") ? s.string : s.string + "\n").utf8).write(to: out, options: .atomic)
        case (Formats.rtf, .attributed(let s)):
            try AttributedWriter.write(s, attributes: [:], as: Formats.rtf, to: out)
        default:
            return try await DocumentIO.convert(request, context: context)
        }
        return ConversionOutput(out)
    }
}

/// Spreadsheets: XLSX/ODS/CSV/TSV/JSON ↔ each other, plus HTML and PDF tables.
public struct SheetsEngine: ConversionEngine {
    public let id = EngineIDs.sheets
    public init() {}

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        context.progress(0.05)
        let wb = try SheetIO.read(request.input, format: request.from)
        try Task.checkCancellation()
        context.progress(0.4)
        let all = request.options.string(OptionKey.sheet, default: "first") == "all"
        let base = request.baseName
        let dir = request.outputDirectory
        func single(_ sheets: [Sheet], write: (Sheet, URL) throws -> Void, ext: String) throws -> ConversionOutput {
            let list = sheets.isEmpty ? [Sheet(name: base, rows: [])] : sheets
            if !all || list.count == 1 {
                let u = request.defaultOutputURL
                try write(list[0], u)
                return ConversionOutput(u)
            }
            var used = Set<String>()
            var outs: [URL] = []
            for (k, sh) in list.enumerated() {
                var name = "\(base) - \(OutputNamer.baseName(for: URL(fileURLWithPath: sh.name + ".x")))"
                if name.hasSuffix(" - ") || sh.name.isEmpty { name = "\(base) - \(k + 1)" }
                while used.contains(name.lowercased()) { name += " \(k + 1)" }
                used.insert(name.lowercased())
                let u = dir.appendingPathComponent(name).appendingPathExtension(ext)
                try write(sh, u)
                outs.append(u)
            }
            return ConversionOutput(outs)
        }
        let out: ConversionOutput
        switch request.to {
        case Formats.xlsx:
            try XLSXWriter().write(wb).write(to: request.defaultOutputURL, options: .atomic)
            out = ConversionOutput(request.defaultOutputURL)
        case Formats.ods:
            try ODSWriter().write(wb).write(to: request.defaultOutputURL, options: .atomic)
            out = ConversionOutput(request.defaultOutputURL)
        case Formats.csv, Formats.tsv:
            let bom = request.options.bool(DocsOptionKey.bom, default: false)
            let delim: Character = request.to == Formats.tsv ? "\t" : ","
            out = try single(wb.sheets, write: { try DelimitedWriter.write($0, delimiter: delim, bom: bom).write(to: $1, options: .atomic) }, ext: request.to.rawValue)
        case Formats.json:
            out = try single(wb.sheets, write: { try JSONTableWriter.write($0).write(to: $1, options: .atomic) }, ext: "json")
        case Formats.html:
            // HTML and PDF carry every sheet (one section each).
            try Data(SheetHTMLWriter.html(wb, print: false).utf8).write(to: request.defaultOutputURL, options: .atomic)
            out = ConversionOutput(request.defaultOutputURL)
        case Formats.pdf:
            let html = SheetHTMLWriter.html(wb, print: true)
            let page = WebPDFRenderer.PageSetup(PageSize.from(request.options), margin: 36, landscape: SheetHTMLWriter.needsLandscape(wb))
            try await WebPDFRenderer.render(html: html, to: request.defaultOutputURL, page: page)
            out = ConversionOutput(request.defaultOutputURL)
        default:
            throw ConversionError.unsupported(from: request.from, to: request.to)
        }
        context.progress(1)
        return out
    }
}
