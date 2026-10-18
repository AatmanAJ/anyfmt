import Foundation

/// A small immutable XML tree (Sendable values) built with `XMLParser`.
/// Element names are local names (prefix stripped); attributes keep their
/// qualified names and can be looked up by local name. Good enough for the
/// OOXML/ODF/EPUB/XHTML parts we read, where prefixes are conventional.
public struct XNode: Sendable, Hashable {
    public var name: String
    public var prefix: String
    public var attributes: [XAttr]
    public var children: [XContent]

    public init(name: String, prefix: String = "", attributes: [XAttr] = [], children: [XContent] = []) {
        self.name = name
        self.prefix = prefix
        self.attributes = attributes
        self.children = children
    }

    /// Attribute by qualified name ("r:id"), then by local name ("val").
    public subscript(_ key: String) -> String? {
        if let a = attributes.first(where: { $0.qname == key }) { return a.value }
        let local = key.split(separator: ":").last.map(String.init) ?? key
        return attributes.first(where: { $0.local == local })?.value
    }

    public var elements: [XNode] {
        children.compactMap { if case .element(let e) = $0 { return e } else { return nil } }
    }

    public func child(_ name: String) -> XNode? { elements.first { $0.name == name } }

    public func children(_ name: String) -> [XNode] { elements.filter { $0.name == name } }

    /// First descendant (depth-first) with this name.
    public func first(_ name: String) -> XNode? {
        for e in elements {
            if e.name == name { return e }
            if let f = e.first(name) { return f }
        }
        return nil
    }

    /// All descendants with this name, document order.
    public func all(_ name: String) -> [XNode] {
        var out: [XNode] = []
        collect(name, into: &out)
        return out
    }

    private func collect(_ name: String, into out: inout [XNode]) {
        for e in elements {
            if e.name == name { out.append(e) }
            e.collect(name, into: &out)
        }
    }

    /// Concatenated text of all descendants.
    public var text: String {
        var s = ""
        appendText(into: &s)
        return s
    }

    private func appendText(into s: inout String) {
        for c in children {
            switch c {
            case .text(let t): s += t
            case .element(let e): e.appendText(into: &s)
            }
        }
    }
}

public struct XAttr: Sendable, Hashable {
    public let qname: String
    public let value: String
    public var local: String { qname.split(separator: ":").last.map(String.init) ?? qname }
    public init(_ qname: String, _ value: String) { self.qname = qname; self.value = value }
}

public enum XContent: Sendable, Hashable {
    case element(XNode)
    case text(String)
}

public enum XMLTree {
    public enum Failure: Error, Sendable, CustomStringConvertible {
        case parse(String)
        public var description: String { if case .parse(let s) = self { return "XML parse error: \(s)" }; return "XML" }
    }

    /// Parses well-formed XML. Throws on malformed input.
    public static func parse(_ data: Data) throws -> XNode {
        let builder = TreeBuilder()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        if !parser.parse() || builder.root == nil {
            throw Failure.parse(parser.parserError?.localizedDescription ?? "unknown")
        }
        guard let root = builder.root else { throw Failure.parse("empty document") }
        return root
    }

    public static func parse(_ string: String) throws -> XNode { try parse(Data(string.utf8)) }

    /// Parses arbitrary (possibly malformed) HTML: HTML Tidy via `XMLDocument`,
    /// which is safe off the main thread (unlike the NSAttributedString HTML importer).
    public static func parseHTML(_ html: String) throws -> XNode {
        let doc = try XMLDocument(xmlString: html, options: [.documentTidyHTML, .nodePreserveWhitespace])
        guard let root = doc.rootElement() else { throw Failure.parse("no root element") }
        return convert(root)
    }

    /// Strict XML first (fast, exact), then the HTML tidy path (XHTML in EPUBs is sometimes sloppy).
    public static func parseXHTML(_ data: Data) throws -> XNode {
        if let n = try? parse(data) { return n }
        return try parseHTML(TextDecoding.decode(data))
    }

    private static func convert(_ e: XMLElement) -> XNode {
        let qname = e.name ?? ""
        let (prefix, local) = split(qname)
        var attrs: [XAttr] = []
        for a in e.attributes ?? [] {
            attrs.append(XAttr(a.name ?? "", a.stringValue ?? ""))
        }
        var kids: [XContent] = []
        for c in e.children ?? [] {
            switch c.kind {
            case .element:
                if let ce = c as? XMLElement { kids.append(.element(convert(ce))) }
            case .text:
                kids.append(.text(c.stringValue ?? ""))
            default:
                break
            }
        }
        return XNode(name: local.lowercased(), prefix: prefix, attributes: attrs, children: kids)
    }

    static func split(_ qname: String) -> (String, String) {
        if let i = qname.firstIndex(of: ":") {
            return (String(qname[..<i]), String(qname[qname.index(after: i)...]))
        }
        return ("", qname)
    }
}

private final class TreeBuilder: NSObject, XMLParserDelegate {
    var stack: [XNode] = []
    var root: XNode?
    var text = ""

    private func flushText() {
        guard !text.isEmpty, !stack.isEmpty else { text = ""; return }
        stack[stack.count - 1].children.append(.text(text))
        text = ""
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        flushText()
        let (prefix, local) = XMLTree.split(elementName)
        // Keep attribute order stable (dictionary order isn't) for deterministic behaviour.
        let attrs = attributeDict.keys.sorted().map { XAttr($0, attributeDict[$0] ?? "") }
        stack.append(XNode(name: local, prefix: prefix, attributes: attrs))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        flushText()
        guard let node = stack.popLast() else { return }
        if stack.isEmpty { root = node } else { stack[stack.count - 1].children.append(.element(node)) }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }
}

/// Text decoding with BOM / declared charset sniffing and sane fallbacks.
public enum TextDecoding {
    public static func decode(_ data: Data) -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(decoding: data.dropFirst(3), as: UTF8.self)
        }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            if let s = String(data: data, encoding: .utf16) { return s }
        }
        if let s = String(data: data, encoding: .utf8) { return s }
        // Declared charset in the first 1 KB (HTML meta / XML declaration).
        let head = String(decoding: data.prefix(1024), as: UTF8.self).lowercased()
        if head.contains("windows-1252") || head.contains("iso-8859-1") || head.contains("latin1") {
            if let s = String(data: data, encoding: .windowsCP1252) { return s }
        }
        if head.contains("shift_jis"), let s = String(data: data, encoding: .shiftJIS) { return s }
        if let s = String(data: data, encoding: .windowsCP1252) { return s }
        if let s = String(data: data, encoding: .macOSRoman) { return s }
        return String(decoding: data, as: UTF8.self)
    }
}

/// XML text escaping and cleanup for everything we write.
public enum XMLEscape {
    /// Escapes text content and attribute values, dropping characters XML 1.0 forbids.
    public static func text(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.utf8.count)
        for u in s.unicodeScalars {
            switch u {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default:
                let v = u.value
                if v == 0x9 || v == 0xA || v == 0xD || (v >= 0x20 && v <= 0xD7FF) || (v >= 0xE000 && v <= 0xFFFD) || v >= 0x10000 {
                    out.unicodeScalars.append(u)
                }
            }
        }
        return out
    }
}
