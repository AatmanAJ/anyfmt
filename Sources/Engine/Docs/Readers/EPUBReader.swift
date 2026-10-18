import Foundation

/// EPUB 2/3 → `DocModel`: container.xml → OPF → spine documents in reading
/// order, each through the HTML reader with images resolved inside the package.
public enum EPUBReader {
    public struct Package {
        public var title: String?
        public var author: String?
        public var language: String?
        public var opfPath: String
        public var manifest: [String: (href: String, mediaType: String, properties: String)]
        public var spine: [String]
    }

    public static func read(_ url: URL) throws -> DocModel {
        try read(ZipReader(url: url))
    }

    public static func package(_ zip: ZipReader) throws -> Package {
        let container = try XMLTree.parse(zip.data("META-INF/container.xml"))
        guard let opfPath = container.first("rootfile")?["full-path"] else { throw ZipReader.Failure.missing("rootfile") }
        let opf = try XMLTree.parse(zip.data(opfPath))
        let meta = opf.first("metadata")
        func dc(_ n: String) -> String? {
            let t = meta?.first(n)?.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t?.isEmpty ?? true) ? nil : t
        }
        var manifest: [String: (href: String, mediaType: String, properties: String)] = [:]
        for item in opf.first("manifest")?.children("item") ?? [] {
            guard let id = item["id"], let href = item["href"] else { continue }
            let decoded = href.removingPercentEncoding ?? href
            manifest[id] = (OPC.resolve(decoded, relativeTo: opfPath), item["media-type"] ?? "", item["properties"] ?? "")
        }
        var spine: [String] = []
        for ref in opf.first("spine")?.children("itemref") ?? [] {
            guard let id = ref["idref"], (ref["linear"] ?? "yes") != "no" else { continue }
            spine.append(id)
        }
        return Package(title: dc("title"), author: dc("creator"), language: dc("language"), opfPath: opfPath, manifest: manifest, spine: spine)
    }

    public static func read(_ zip: ZipReader) throws -> DocModel {
        let pkg = try package(zip)
        var blocks: [DocBlock] = []
        for id in pkg.spine {
            guard let item = pkg.manifest[id], item.mediaType.contains("html") || item.href.hasSuffix("htm") || item.href.hasSuffix("html"),
                  !item.properties.contains("nav") else { continue }
            guard let data = try? zip.data(item.href) else { continue }
            let root: XNode
            do { root = try XMLTree.parseXHTML(data) } catch { continue }
            let chapterPath = item.href
            let loader: HTMLReader.ImageLoader = { src in
                guard !src.contains("://") else { return nil }
                let clean = (src.removingPercentEncoding ?? src).split(separator: "#").first.map(String.init) ?? src
                let path = OPC.resolve(clean, relativeTo: chapterPath)
                guard let d = try? zip.data(path) else { return nil }
                return (d, ImageSupport.sniffMIME(d, fileExtension: (path as NSString).pathExtension) ?? "application/octet-stream")
            }
            let chapter = HTMLReader.read(root, baseURL: nil, loader: loader).blocks
            guard !chapter.isEmpty else { continue }
            if !blocks.isEmpty { blocks.append(.pageBreak) }
            blocks.append(contentsOf: chapter)
        }
        return DocModel(metadata: DocMetadata(title: pkg.title, author: pkg.author, language: pkg.language), blocks: blocks)
    }
}
