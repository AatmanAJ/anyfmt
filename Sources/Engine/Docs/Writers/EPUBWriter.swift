import Foundation

/// `DocModel` → EPUB 3 with an EPUB 2 NCX fallback. Chapters split at H1 (or
/// H2 when there's no H1); images packaged under `images/`; first-block image
/// becomes the cover. `mimetype` is the first entry, stored, as OCF requires.
public struct EPUBWriter {
    public var zipOptions: ZipWriter.Options

    public init(zipOptions: ZipWriter.Options = .init()) { self.zipOptions = zipOptions }

    struct Chapter {
        var title: String
        var blocks: [DocBlock]
        var file: String
        /// (block index, level, text) of sub-headings for the navigation tree.
        var sections: [(Int, Int, String)]
    }

    public func write(_ doc: DocModel) throws -> Data {
        let title = doc.displayTitle ?? L("Untitled")
        let lang = doc.metadata.language ?? "en"
        let chapters = Self.split(doc, fallbackTitle: title)
        let uid = "urn:uuid:" + Self.stableUUID(doc)

        // Images → package files.
        var images: [(name: String, data: Data, mime: String)] = []
        var hrefByKey: [String: String] = [:]
        var coverName: String?
        for (k, im) in doc.allImages.enumerated() {
            guard let data = im.data else { continue }
            let key = Self.key(data)
            if hrefByKey[key] != nil { continue }
            var payload = data
            var mime = ImageSupport.sniffMIME(data) ?? im.mime
            if mime != "image/svg+xml", let p = ImageSupport.portable(im) { payload = p.data; mime = p.mime } else if mime != "image/svg+xml" { continue }
            let name = "img\(images.count + 1).\(ImageSupport.fileExtension(forMIME: mime))"
            images.append((name, payload, mime))
            hrefByKey[key] = "../images/\(name)"
            if k == 0, case .image? = doc.blocks.first { coverName = name }
        }
        let lookup = hrefByKey
        var html = HTMLWriter(flavor: .xhtml, imageMode: .external({ im in im.data.flatMap { lookup[EPUBWriter.key($0)] } }))
        html.stylesheetHref = "../style.css"
        html.headingIDPrefix = "s"

        var zip = ZipWriter(options: zipOptions)
        try zip.add("mimetype", "application/epub+zip", compress: false)
        try zip.add("META-INF/container.xml", """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
        """)
        try zip.add("OEBPS/style.css", HTMLWriter.epubCSS)
        for ch in chapters {
            var chDoc = doc
            chDoc.blocks = ch.blocks
            try zip.add("OEBPS/text/\(ch.file)", html.document(chDoc, title: ch.title))
        }
        for im in images { try zip.add("OEBPS/images/\(im.name)", im.data, compress: im.mime == "image/svg+xml") }
        try zip.add("OEBPS/nav.xhtml", navXHTML(chapters, lang: lang))
        try zip.add("OEBPS/toc.ncx", ncx(chapters, title: title, uid: uid))
        try zip.add("OEBPS/content.opf", opf(doc, title: title, lang: lang, uid: uid, chapters: chapters, images: images.map { ($0.name, $0.mime) }, cover: coverName))
        return try zip.finish()
    }

    static func key(_ d: Data) -> String { "\(CRC32.checksum(d))-\(d.count)" }

    /// Splits at the highest heading level present (1 or 2); front matter becomes its own chapter.
    static func split(_ doc: DocModel, fallbackTitle: String) -> [Chapter] {
        let levels = doc.blocks.compactMap { b -> Int? in if case .heading(let l, _) = b { return l }; return nil }
        let splitLevel = levels.contains(1) ? 1 : (levels.contains(2) ? 2 : nil)
        var chapters: [Chapter] = []
        var current: [DocBlock] = []
        var currentTitle: String?
        func flush() {
            let meaningful = current.contains { b in
                switch b {
                case .pageBreak, .horizontalRule: return false
                default: return true
                }
            }
            guard meaningful else { current.removeAll(); return }
            let n = chapters.count + 1
            chapters.append(Chapter(title: currentTitle ?? fallbackTitle, blocks: current, file: String(format: "ch%03d.xhtml", n), sections: []))
            current.removeAll()
        }
        for b in doc.blocks {
            if let splitLevel, case .heading(let l, let inl) = b, l <= splitLevel {
                flush()
                currentTitle = inl.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if case .pageBreak = b { continue }
            current.append(b)
        }
        flush()
        if chapters.isEmpty {
            chapters = [Chapter(title: fallbackTitle, blocks: [.paragraph([])], file: "ch001.xhtml", sections: [])]
        }
        // Sub-sections for the navigation tree: the next level down.
        let sub = (splitLevel ?? 0) + 1
        for k in chapters.indices {
            var secs: [(Int, Int, String)] = []
            for (i, b) in chapters[k].blocks.enumerated() {
                if case .heading(let l, let inl) = b, l == sub, splitLevel != nil || l == 1 {
                    secs.append((i, l, inl.plainText.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            chapters[k].sections = secs
        }
        return chapters
    }

    func navXHTML(_ chapters: [Chapter], lang: String) -> String {
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="\(XMLEscape.text(lang))" xml:lang="\(XMLEscape.text(lang))">
        <head><meta charset="utf-8"/><title>\(XMLEscape.text(L("Contents")))</title></head>
        <body><nav epub:type="toc" id="toc"><h1>\(XMLEscape.text(L("Contents")))</h1><ol>
        """
        for ch in chapters {
            s += "<li><a href=\"text/\(ch.file)\">\(XMLEscape.text(ch.title.isEmpty ? "—" : ch.title))</a>"
            if !ch.sections.isEmpty {
                s += "<ol>" + ch.sections.map { "<li><a href=\"text/\(ch.file)#s\($0.0)\">\(XMLEscape.text($0.2.isEmpty ? "—" : $0.2))</a></li>" }.joined() + "</ol>"
            }
            s += "</li>"
        }
        return s + "</ol></nav></body></html>\n"
    }

    func ncx(_ chapters: [Chapter], title: String, uid: String) -> String {
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="\(uid)"/><meta name="dtb:depth" content="2"/><meta name="dtb:totalPageCount" content="0"/><meta name="dtb:maxPageNumber" content="0"/></head><docTitle><text>\(XMLEscape.text(title))</text></docTitle><navMap>
        """
        var order = 0
        for ch in chapters {
            order += 1
            s += "<navPoint id=\"np\(order)\" playOrder=\"\(order)\"><navLabel><text>\(XMLEscape.text(ch.title))</text></navLabel><content src=\"text/\(ch.file)\"/>"
            for sec in ch.sections {
                order += 1
                s += "<navPoint id=\"np\(order)\" playOrder=\"\(order)\"><navLabel><text>\(XMLEscape.text(sec.2))</text></navLabel><content src=\"text/\(ch.file)#s\(sec.0)\"/></navPoint>"
            }
            s += "</navPoint>"
        }
        return s + "</navMap></ncx>\n"
    }

    func opf(_ doc: DocModel, title: String, lang: String, uid: String, chapters: [Chapter], images: [(String, String)], cover: String?) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        let modified = f.string(from: zipOptions.deterministic ? Date(timeIntervalSince1970: 0) : zipOptions.date)
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid" xml:lang="\(XMLEscape.text(lang))"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="bookid">\(uid)</dc:identifier><dc:title>\(XMLEscape.text(title))</dc:title><dc:language>\(XMLEscape.text(lang))</dc:language>
        """
        if let a = doc.metadata.author { s += "<dc:creator>\(XMLEscape.text(a))</dc:creator>" }
        s += "<meta property=\"dcterms:modified\">\(modified)</meta>"
        if let cover, let idx = images.firstIndex(where: { $0.0 == cover }) { s += "<meta name=\"cover\" content=\"img\(idx + 1)\"/>" }
        s += "<meta name=\"generator\" content=\"\(XMLEscape.text(Brand.name))\"/></metadata><manifest>"
        s += "<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/>"
        s += "<item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\"/>"
        s += "<item id=\"css\" href=\"style.css\" media-type=\"text/css\"/>"
        for (k, ch) in chapters.enumerated() {
            s += "<item id=\"ch\(k + 1)\" href=\"text/\(ch.file)\" media-type=\"application/xhtml+xml\"/>"
        }
        for (k, im) in images.enumerated() {
            let props = im.0 == cover ? " properties=\"cover-image\"" : ""
            s += "<item id=\"img\(k + 1)\" href=\"images/\(im.0)\" media-type=\"\(im.1)\"\(props)/>"
        }
        s += "</manifest><spine toc=\"ncx\">"
        for k in chapters.indices { s += "<itemref idref=\"ch\(k + 1)\"/>" }
        return s + "</spine></package>\n"
    }

    /// Content-derived UUID (stable for identical input) in v5-style layout.
    static func stableUUID(_ doc: DocModel) -> String {
        let text = doc.blocks.map(\.plainText).joined(separator: "\n") + (doc.metadata.title ?? "")
        let d = Data(text.utf8)
        var parts: [UInt32] = []
        for salt in 0..<4 {
            var c = CRC32()
            c.update(Data([UInt8(salt), 0x48, 0x61, 0x6C, 0x6F]))
            c.update(d)
            parts.append(c.value)
        }
        let hex = parts.map { String(format: "%08x", $0) }.joined()
        let chars = Array(hex)
        func seg(_ a: Int, _ b: Int) -> String { String(chars[a..<b]) }
        return "\(seg(0, 8))-\(seg(8, 12))-5\(seg(13, 16))-8\(seg(17, 20))-\(seg(20, 32))"
    }
}
