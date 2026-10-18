import Foundation

// Lane F rows: documents, EPUB, PDF reconstruction, slides, spreadsheets.
// Quality grades and what's missing: docs/lanes/F-docs.md.
public enum DocsRoutes {
    typealias F = Formats

    /// Document formats we read into the model (PDF has its own rows below).
    static let docInputs: [FormatID] = [F.docx, F.odt, F.md, F.txt, F.html, F.rtf, F.rtfd, F.doc, F.webarchive, F.textClipping, F.epub]

    /// Engine that writes each document target.
    static func engine(for target: FormatID) -> EngineID {
        switch target {
        case F.docx, F.odt: EngineIDs.ooxmlWriter
        case F.md, F.txt, F.html: EngineIDs.markdown
        case F.rtf, F.rtfd: EngineIDs.attributedText
        case F.epub: EngineIDs.epub
        case F.pdf: EngineIDs.webKitPDF
        default: EngineIDs.markdown
        }
    }

    static func schema(for target: FormatID) -> OptionsSchema {
        switch target {
        case F.pdf, F.docx, F.odt: StandardSchemas.documentPDF
        case F.md: DocsSchemas.markdown
        default: .none
        }
    }

    static func flags(from: FormatID, to: FormatID) -> CapabilityFlags {
        if to == F.txt { return [.lossyStructure, .terminalOnly] }
        // A rendered PDF is an end product: never feed it back into PDF reconstruction
        // (no DOCX → PDF → XLSX/PPTX detours).
        if to == F.pdf { return [.terminalOnly] }
        // Lossless enough to chain through: our own structured formats.
        if [F.docx, F.odt, F.html].contains(to) && from != F.pdf { return [.lossless] }
        return []
    }

    static func cost(from: FormatID, to: FormatID) -> Double {
        var c = 1.0
        if to == F.pdf { c += 1.5 }          // WebKit print is the slow step
        if from == F.pdf { c += 1 }          // reconstruction
        if from == F.rtfd || from == F.doc || from == F.webarchive { c += 0.2 }
        return c
    }

    static let documentRows: [Capability] = {
        let targets: [FormatID] = [F.docx, F.odt, F.md, F.txt, F.html, F.rtf, F.rtfd, F.epub, F.pdf]
        var rows: [Capability] = []
        for from in docInputs {
            for to in targets where to != from {
                // Clippings are plain/rich text: TXT and RTF come straight from the clipping's own flavours.
                let engine = from == F.textClipping && (to == F.txt || to == F.rtf) ? EngineIDs.textClipping : engine(for: to)
                rows.append(Capability(from, to, engine, schema: schema(for: to), priority: 100, cost: cost(from: from, to: to),
                                       flags: flags(from: from, to: to)))
            }
        }
        return rows
    }()

    /// PDF → editable formats (text reconstruction). PDF → TXT/images belong to lane D.
    static let pdfRows: [Capability] = {
        var rows: [Capability] = []
        for to in [F.docx, F.odt, F.md, F.html, F.rtf, F.rtfd, F.epub] {
            rows.append(Capability(F.pdf, to, engine(for: to), schema: schema(for: to), priority: 100, cost: cost(from: F.pdf, to: to)))
        }
        rows.append(Capability(F.pdf, F.pptx, EngineIDs.ooxmlWriter, priority: 100, cost: 3, flags: [.terminalOnly]))
        rows.append(Capability(F.pdf, F.xlsx, EngineIDs.ooxmlWriter, priority: 100, cost: 2, flags: [.terminalOnly]))
        return rows
    }()

    /// Slides through Quick Look's Office generator (best effort, low priority).
    static let slideRows: [Capability] = [
        Capability(F.pptx, F.pdf, EngineIDs.quickLook, schema: .none, priority: 40, cost: 3, flags: [.terminalOnly]),
        Capability(F.pptx, F.png, EngineIDs.quickLook, schema: DocsSchemas.slideImagesLossless, priority: 40, cost: 4, flags: [.multiOutput]),
        Capability(F.pptx, F.jpg, EngineIDs.quickLook, schema: DocsSchemas.slideImages, priority: 40, cost: 4, flags: [.multiOutput]),
    ]

    static let sheetRows: [Capability] = {
        let inputs: [FormatID] = [F.xlsx, F.xls, F.ods, F.csv, F.tsv, F.json]
        let outputs: [FormatID] = [F.xlsx, F.ods, F.csv, F.tsv, F.json, F.html, F.pdf]
        var rows: [Capability] = []
        for from in inputs {
            for to in outputs where to != from {
                let multiSheet = (from == F.xlsx || from == F.xls || from == F.ods) && [F.csv, F.tsv, F.json].contains(to)
                let schema: OptionsSchema
                switch to {
                case F.csv, F.tsv: schema = multiSheet ? DocsSchemas.delimited : OptionsSchema("sheet.bom", [DocsSchemas.delimited.specs[1]])
                case F.json: schema = multiSheet ? StandardSchemas.sheet : .none
                case F.pdf: schema = StandardSchemas.documentPDF
                default: schema = .none
                }
                var flags: CapabilityFlags = multiSheet ? [.multiOutput] : []
                if to == F.pdf { flags.insert(.terminalOnly) }
                if [F.xlsx, F.ods].contains(to) { flags.insert(.lossless) }
                rows.append(Capability(from, to, EngineIDs.sheets, schema: schema, priority: 100, cost: to == F.pdf ? 2.5 : 1, flags: flags))
            }
        }
        return rows
    }()

    /// Opt-in iWork scripting (needs the app + the Settings toggle; never in the shipped count).
    static let iWorkRows: [Capability] = {
        let e = EngineIDs.pagesAppleEvents
        var rows: [Capability] = []
        for to in [F.pdf, F.docx, F.epub, F.txt, F.rtf] { rows.append(Capability(F.pages, to, e, priority: 90, cost: 4, flags: [.optIn])) }
        rows.append(Capability(F.docx, F.pages, e, priority: 90, cost: 4, flags: [.optIn]))
        for to in [F.pdf, F.pptx] { rows.append(Capability(F.key, to, e, priority: 90, cost: 4, flags: [.optIn])) }
        rows.append(Capability(F.pptx, F.key, e, priority: 90, cost: 4, flags: [.optIn]))
        for to in [F.pdf, F.xlsx, F.csv] { rows.append(Capability(F.numbers, to, e, priority: 90, cost: 4, flags: [.optIn])) }
        rows.append(Capability(F.xlsx, F.numbers, e, priority: 90, cost: 4, flags: [.optIn]))
        return rows
    }()

    /// LibreOffice from the optional Office pack: faithful layout wins over our reflow when installed.
    static let officePackRows: [Capability] = {
        let e = EngineIDs.officePack
        var rows: [Capability] = []
        for from in [F.pptx, F.ppt, F.key, F.odp] {
            rows.append(Capability(from, F.pdf, e, priority: 110, cost: 5, flags: [.needsPack]))
            rows.append(Capability(from, F.png, e, schema: DocsSchemas.slideImagesLossless, priority: 110, cost: 6, flags: [.needsPack, .multiOutput]))
            rows.append(Capability(from, F.jpg, e, schema: DocsSchemas.slideImages, priority: 110, cost: 6, flags: [.needsPack, .multiOutput]))
        }
        for from in [F.ppt, F.key, F.odp] { rows.append(Capability(from, F.pptx, e, priority: 110, cost: 5, flags: [.needsPack])) }
        rows.append(Capability(F.pptx, F.odp, e, priority: 110, cost: 5, flags: [.needsPack]))
        for from in [F.docx, F.doc, F.odt, F.rtf] { rows.append(Capability(from, F.pdf, e, priority: 110, cost: 5, flags: [.needsPack])) }
        rows.append(Capability(F.doc, F.docx, e, priority: 110, cost: 5, flags: [.needsPack]))
        for to in [F.docx, F.odt, F.pdf] { rows.append(Capability(F.pages, to, e, priority: 80, cost: 5, flags: [.needsPack])) }
        for to in [F.xlsx, F.ods, F.csv, F.pdf] { rows.append(Capability(F.xls, to, e, priority: 110, cost: 5, flags: [.needsPack])) }
        for to in [F.xlsx, F.ods, F.pdf] { rows.append(Capability(F.numbers, to, e, priority: 80, cost: 5, flags: [.needsPack])) }
        for from in [F.xlsx, F.ods] { rows.append(Capability(from, F.pdf, e, priority: 110, cost: 5, flags: [.needsPack])) }
        return rows
    }()

    /// pandoc from the optional pandoc pack (package ↔ package only; see PandocPackEngine).
    static let pandocPackRows: [Capability] = {
        let pairs: [(FormatID, FormatID)] = [(F.docx, F.odt), (F.odt, F.docx), (F.docx, F.epub), (F.epub, F.docx), (F.odt, F.epub), (F.epub, F.odt)]
        return pairs.map { Capability($0.0, $0.1, EngineIDs.pandocPack, priority: 105, cost: 2, flags: [.needsPack]) }
    }()

    public static let rows: [Capability] = documentRows + pdfRows + slideRows + sheetRows + iWorkRows + officePackRows + pandocPackRows
}
