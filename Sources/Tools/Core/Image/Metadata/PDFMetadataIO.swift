import Foundation
import CoreGraphics
import PDFKit

/// PDF document info through PDFKit. PDFKit keeps the catalog's XMP packet
/// when only attributes change (verified on 27.0.1), which would leave the
/// old title in XMP. So both edit and strip re-host the pages in a fresh
/// document (annotations, links and the outline come along) and write that.
/// Quartz always adds Producer and creation/modification dates on write.
enum PDFMetadataIO {
    static let keys: [(key: String, attribute: PDFDocumentAttribute, label: String)] = [
        ("title", .titleAttribute, L("Title")), ("author", .authorAttribute, L("Author")),
        ("subject", .subjectAttribute, L("Subject")), ("keywords", .keywordsAttribute, L("Keywords")),
        ("creator", .creatorAttribute, L("Creator")),
    ]

    private static func open(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else { throw ConversionError.unreadable(url, detail: "PDFKit could not open") }
        guard !doc.isLocked else {
            throw ConversionError.other(L("This PDF is password-protected. Unlock it in Preview first."), detail: "locked PDF")
        }
        return doc
    }

    static func read(_ url: URL) throws -> MetadataSnapshot {
        let doc = try open(url)
        let attrs = doc.documentAttributes ?? [:]
        var fields: [MetadataField] = keys.map { k in
            MetadataField(key: k.key, label: k.label, group: L("PDF info"), value: string(attrs[k.attribute]) ?? "", editable: true,
                          placeholder: k.key == "keywords" ? L("Comma-separated") : nil)
        }
        func info(_ key: String, _ label: String, _ group: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            fields.append(MetadataField(key: key, label: label, group: group, value: value, editable: false))
        }
        info("pdf.producer", L("Producer"), L("PDF info"), string(attrs[PDFDocumentAttribute.producerAttribute]))
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        info("pdf.created", L("Created"), L("PDF info"), (attrs[PDFDocumentAttribute.creationDateAttribute] as? Date).map(df.string))
        info("pdf.modified", L("Modified"), L("PDF info"), (attrs[PDFDocumentAttribute.modificationDateAttribute] as? Date).map(df.string))
        info("pdf.pages", L("Pages"), L("Document"), String(doc.pageCount))
        if let page = doc.page(at: 0) {
            let b = page.bounds(for: .mediaBox)
            info("pdf.pageSize", L("Page size"), L("Document"), String(format: "%.0f × %.0f pt", b.width, b.height))
        }
        info("pdf.version", L("PDF version"), L("Document"), "\(doc.majorVersion).\(doc.minorVersion)")
        info("pdf.xmp", L("XMP metadata"), L("Document"), hasXMP(url) ? L("Present") : nil)
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            info("file.size", L("Size"), L("File"), ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        return MetadataSnapshot(container: .pdf, fields: fields)
    }

    static func write(_ input: URL, changes: [String: String?], output: ToolOutput) throws -> URL {
        let doc = try open(input)
        var attrs: [AnyHashable: Any] = [:]
        // Keep the document's existing descriptive fields, then apply edits.
        let old = doc.documentAttributes ?? [:]
        for k in keys { if let v = old[k.attribute] { attrs[k.attribute] = v } }
        for (key, value) in changes {
            guard let k = keys.first(where: { $0.key == key }) else { throw ConversionError.invalidOption("fields.\(key)") }
            let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                attrs.removeValue(forKey: k.attribute)
            } else if key == "keywords" {
                attrs[k.attribute] = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else {
                attrs[k.attribute] = text
            }
        }
        if let created = old[PDFDocumentAttribute.creationDateAttribute] { attrs[PDFDocumentAttribute.creationDateAttribute] = created }
        return try save(rehost(doc), attributes: attrs, output: output)
    }

    static func strip(_ input: URL, output: ToolOutput) throws -> URL {
        try save(rehost(try open(input)), attributes: [:], output: output)
    }

    private static func save(_ doc: PDFDocument, attributes: [AnyHashable: Any], output: ToolOutput) throws -> URL {
        doc.documentAttributes = attributes
        let url = try output.url(ext: "pdf")
        guard doc.write(to: url) else { throw ConversionError.other(L("The PDF couldn’t be saved."), detail: "PDFDocument.write failed") }
        return url
    }

    /// Copies every page (with its annotations) into a new document, then
    /// rebuilds the outline against the new pages.
    private static func rehost(_ doc: PDFDocument) -> PDFDocument {
        let fresh = PDFDocument()
        var map: [ObjectIdentifier: PDFPage] = [:]
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let copy = page.copy() as? PDFPage else { continue }
            fresh.insert(copy, at: fresh.pageCount)
            map[ObjectIdentifier(page)] = copy
        }
        if let root = doc.outlineRoot, root.numberOfChildren > 0 {
            let newRoot = PDFOutline()
            copyOutline(root, into: newRoot, pages: map)
            fresh.outlineRoot = newRoot
        }
        return fresh
    }

    private static func copyOutline(_ from: PDFOutline, into to: PDFOutline, pages: [ObjectIdentifier: PDFPage]) {
        for i in 0..<from.numberOfChildren {
            guard let child = from.child(at: i) else { continue }
            let item = PDFOutline()
            item.label = child.label
            item.isOpen = child.isOpen
            if let dest = child.destination, let page = dest.page, let newPage = pages[ObjectIdentifier(page)] {
                item.destination = PDFDestination(page: newPage, at: dest.point)
            }
            to.insertChild(item, at: to.numberOfChildren)
            copyOutline(child, into: item, pages: pages)
        }
    }

    static func hasXMP(_ url: URL) -> Bool {
        guard let d = CGPDFDocument(url as CFURL), let catalog = d.catalog else { return false }
        var stream: CGPDFStreamRef?
        return CGPDFDictionaryGetStream(catalog, "Metadata", &stream)
    }

    private static func string(_ v: Any?) -> String? {
        switch v {
        case let s as String: s.isEmpty ? nil : s
        case let a as [Any]: a.map { "\($0)" }.joined(separator: ", ")
        default: nil
        }
    }
}
