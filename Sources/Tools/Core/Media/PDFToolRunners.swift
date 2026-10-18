import Foundation
import PDFKit
import Quartz

// Tools 25–26: organise pages (merge / split / reorder / rotate / delete) and
// compress. Both keep page content as vectors: pages are copied, never rasterised.

/// One page of the output: which input, which page, extra rotation.
public struct PDFPageRef: Sendable, Equatable, Hashable {
    /// 0-based input index.
    public let input: Int
    /// 0-based page index.
    public let page: Int
    /// Clockwise degrees added to the page's own rotation (multiple of 90).
    public let rotation: Int

    public init(input: Int, page: Int, rotation: Int = 0) {
        self.input = input
        self.page = page
        self.rotation = ((rotation % 360) + 360) % 360
    }

    /// `ToolSchemas.organizePDF` order text: "1:1,1:3:90,2:1", ranges "1:2-5",
    /// bare pages "3" (input 1). 1-based. Empty → every page of every input.
    public static func parse(_ text: String, pageCounts: [Int]) -> [PDFPageRef]? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            return pageCounts.enumerated().flatMap { i, n in (0..<n).map { PDFPageRef(input: i, page: $0) } }
        }
        var out: [PDFPageRef] = []
        for item in t.split(separator: ",") {
            let f = item.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            let (inputText, pageText, rotText): (String, String, String?) = switch f.count {
            case 1: ("1", f[0], nil)
            case 2: (f[0], f[1], nil)
            case 3: (f[0], f[1], f[2])
            default: ("", "", nil)
            }
            guard let input = Int(inputText), (1...pageCounts.count).contains(input) else { return nil }
            let rotation = rotText.flatMap(Int.init) ?? 0
            guard rotation % 90 == 0 else { return nil }
            let count = pageCounts[input - 1]
            let bounds = pageText.split(separator: "-").compactMap { Int($0) }
            guard (1...2).contains(bounds.count), let a = bounds.first, let b = bounds.last,
                  (1...count).contains(a), (1...count).contains(b) else { return nil }
            let pages = a <= b ? Array(a...b) : Array((b...a).reversed())
            out += pages.map { PDFPageRef(input: input - 1, page: $0 - 1, rotation: rotation) }
        }
        return out.isEmpty ? nil : out
    }

    /// Order text for a list of refs (what the editor saves).
    public static func format(_ refs: [PDFPageRef]) -> String {
        refs.map { r in r.rotation == 0 ? "\(r.input + 1):\(r.page + 1)" : "\(r.input + 1):\(r.page + 1):\(r.rotation)" }
            .joined(separator: ",")
    }
}

enum PDFSupport {
    static func open(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else {
            throw ConversionError.unreadable(url, detail: "PDFKit could not open the file")
        }
        if doc.isLocked {
            throw ConversionError.other(L("“\(url.lastPathComponent)” is password-protected. Unlock it in Preview first."),
                                        detail: "locked PDF")
        }
        return doc
    }

    /// Document info filtered by the metadata policy.
    static func attributes(from doc: PDFDocument, policy: MetadataPolicy) -> [AnyHashable: Any] {
        guard policy != .stripAll else { return [:] }
        var a = doc.documentAttributes ?? [:]
        if policy == .stripPrivate {
            for k in [PDFDocumentAttribute.authorAttribute, .creatorAttribute, .producerAttribute] { a.removeValue(forKey: k) }
        }
        return a
    }

    static func write(_ doc: PDFDocument, to url: URL, options: [PDFDocumentWriteOption: Any]? = nil) throws {
        let ok = options.map { doc.write(to: url, withOptions: $0) } ?? doc.write(to: url)
        guard ok, FileManager.default.fileExists(atPath: url.path) else {
            throw ConversionError.other(L("The PDF couldn’t be saved."), detail: "PDFDocument.write failed for \(url.lastPathComponent)")
        }
    }
}

/// 25. Merge / split / reorder / rotate / delete pages across one or more PDFs.
public struct OrganizePDFRunner: ToolRunner {
    public let id = ToolIDs.organizePDF
    public init() {}

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        guard !request.inputs.isEmpty else { throw ConversionError.invalidOption("inputs") }
        let docs = try request.inputs.map(PDFSupport.open)
        guard let refs = PDFPageRef.parse(request.options.string("order", default: ""), pageCounts: docs.map(\.pageCount)) else {
            throw ConversionError.invalidOption("order")
        }
        let out = PDFDocument()
        // (input, page) → index of its first copy in the output, for outlines.
        var firstCopy: [PDFPageRef: Int] = [:]
        for (n, ref) in refs.enumerated() {
            try Task.checkCancellation()
            guard let page = docs[ref.input].page(at: ref.page)?.copy() as? PDFPage else {
                throw ConversionError.unreadable(request.inputs[ref.input], detail: "page \(ref.page + 1)")
            }
            page.rotation = ((page.rotation + ref.rotation) % 360 + 360) % 360
            out.insert(page, at: out.pageCount)
            let key = PDFPageRef(input: ref.input, page: ref.page)
            if firstCopy[key] == nil { firstCopy[key] = n }
            context.progress(Double(n + 1) / Double(refs.count) * 0.8)
        }
        out.documentAttributes = PDFSupport.attributes(from: docs[0], policy: request.metadata)

        if request.options.bool("split", default: false) {
            var files: [URL] = []
            for i in 0..<out.pageCount {
                guard let page = out.page(at: i)?.copy() as? PDFPage else { continue }
                let single = PDFDocument()
                single.insert(page, at: 0)
                single.documentAttributes = out.documentAttributes
                let url = OutputNamer.freeURL(in: request.outputDirectory, base: request.baseName + String(format: "-%03d", i + 1), ext: "pdf")
                try PDFSupport.write(single, to: url)
                files.append(url)
                context.progress(0.8 + 0.2 * Double(i + 1) / Double(out.pageCount))
            }
            return ConversionOutput(files)
        }

        Self.rebuildOutline(into: out, from: docs, names: request.inputs.map { $0.deletingPathExtension().lastPathComponent }, firstCopy: firstCopy)
        let url = OutputNamer.freeURL(in: request.outputDirectory, base: request.baseName, ext: "pdf")
        try PDFSupport.write(out, to: url)
        context.progress(1)
        return ConversionOutput(url)
    }

    /// Copies each input's bookmarks that point at kept pages. With several
    /// inputs, each file's bookmarks nest under an entry named after the file.
    static func rebuildOutline(into out: PDFDocument, from docs: [PDFDocument], names: [String], firstCopy: [PDFPageRef: Int]) {
        let root = PDFOutline()
        var added = 0
        for (i, doc) in docs.enumerated() {
            let parent: PDFOutline
            if docs.count > 1 {
                guard let first = firstCopy.filter({ $0.key.input == i }).min(by: { $0.value < $1.value }),
                      let page = out.page(at: first.value) else { continue }
                let item = PDFOutline()
                item.label = names[i]
                item.destination = PDFDestination(page: page, at: CGPoint(x: 0, y: page.bounds(for: .cropBox).maxY))
                root.insertChild(item, at: root.numberOfChildren)
                parent = item
                added += 1
            } else {
                parent = root
            }
            if let src = doc.outlineRoot { added += copyChildren(of: src, into: parent, input: i, doc: doc, out: out, firstCopy: firstCopy) }
        }
        if added > 0 { out.outlineRoot = root }
    }

    private static func copyChildren(of src: PDFOutline, into dst: PDFOutline, input: Int, doc: PDFDocument,
                                     out: PDFDocument, firstCopy: [PDFPageRef: Int]) -> Int {
        var added = 0
        for c in 0..<src.numberOfChildren {
            guard let child = src.child(at: c) else { continue }
            let item = PDFOutline()
            item.label = child.label
            var keep = false
            if let dest = child.destination, let srcPage = dest.page {
                let idx = doc.index(for: srcPage)
                if let n = firstCopy[PDFPageRef(input: input, page: idx)], let page = out.page(at: n) {
                    item.destination = PDFDestination(page: page, at: dest.point)
                    keep = true
                }
            }
            let nested = copyChildren(of: child, into: item, input: input, doc: doc, out: out, firstCopy: firstCopy)
            if keep || nested > 0 {
                dst.insertChild(item, at: dst.numberOfChildren)
                added += 1
            }
        }
        return added
    }
}

/// 26. Compress PDF by downsampling and JPEG-recompressing embedded images
/// with a Quartz filter applied while PDFKit saves. Text and vector art are
/// untouched (still selectable/searchable). See docs/lanes/G2-media-tools.md.
public struct CompressPDFRunner: ToolRunner {
    public let id = ToolIDs.compressPDF
    public init() {}

    public struct Setting: Sendable, Equatable {
        public let dpi: Int
        public let quality: Double
    }

    /// Target-size search ladder, largest result first.
    public static let ladder: [Setting] = [
        Setting(dpi: 300, quality: 0.8), Setting(dpi: 200, quality: 0.75), Setting(dpi: 150, quality: 0.7),
        Setting(dpi: 150, quality: 0.55), Setting(dpi: 120, quality: 0.5), Setting(dpi: 100, quality: 0.45),
        Setting(dpi: 72, quality: 0.4), Setting(dpi: 72, quality: 0.25), Setting(dpi: 50, quality: 0.2),
    ]

    /// Our own Quartz filter definition: JPEG at `quality`, images capped at `dpi`.
    static func filter(_ s: Setting) -> QuartzFilter? {
        let properties: [String: Any] = [
            "Name": "\(Brand.name) Compress",
            "FilterType": 1,
            "Domains": ["Applications": true, "Printing": false],
            "FilterData": [
                "ColorSettings": [
                    "ImageSettings": [
                        "Compression Quality": s.quality,
                        "ImageCompression": "ImageJPEGCompress",
                        "ImageScaleSettings": [
                            "ImageResolution": s.dpi,
                            "ImageScaleInterpolate": true,
                            "ImageSizeMax": 0,
                            "ImageSizeMin": 0,
                        ],
                    ],
                ],
            ],
        ]
        return QuartzFilter(properties: properties)
    }

    static func write(_ input: URL, setting: Setting, policy: MetadataPolicy, to url: URL) throws {
        let doc = try PDFSupport.open(input)
        doc.documentAttributes = PDFSupport.attributes(from: doc, policy: policy)
        guard let f = filter(setting) else { throw ConversionError.other(L("The PDF couldn’t be compressed."), detail: "QuartzFilter init failed") }
        try PDFSupport.write(doc, to: url, options: [PDFDocumentWriteOption(rawValue: "QuartzFilter"): f])
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let input = request.inputs.first else { throw ConversionError.invalidOption("inputs") }
        _ = try PDFSupport.open(input)
        let originalSize = MediaRun.fileSize(input)
        let dest = OutputNamer.freeURL(in: request.outputDirectory, base: request.baseName, ext: "pdf")
        let notSmaller = ConversionError.other(
            L("“\(input.lastPathComponent)” is already compact. Compressing its images wouldn’t make it smaller."),
            detail: "result not smaller than \(originalSize) bytes")

        if request.options.string(OptionKey.sizeMode, default: "quality") != "size" {
            let dpi = min(600, max(36, request.options.int(OptionKey.dpi, default: 150)))
            let q = Double(min(95, max(10, request.options.int(OptionKey.quality, default: 60)))) / 100
            try Self.write(input, setting: Setting(dpi: dpi, quality: q), policy: request.metadata, to: dest)
            context.progress(1)
            if MediaRun.fileSize(dest) >= originalSize {
                try? FileManager.default.removeItem(at: dest)
                throw notSmaller
            }
            return ConversionOutput(dest)
        }

        // Target size: binary search for the gentlest setting that fits.
        let target = Int64(request.options.int(OptionKey.targetSize, default: 2_000_000))
        let scratch = request.outputDirectory.appendingPathComponent(".halo-scratch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        var lo = 0, hi = Self.ladder.count - 1
        var fits: (Int, URL)?, smallest: (Int64, URL)?
        var probes = 0
        while lo <= hi {
            try Task.checkCancellation()
            let mid = (lo + hi) / 2
            let candidate = scratch.appendingPathComponent("try-\(mid).pdf")
            try Self.write(input, setting: Self.ladder[mid], policy: request.metadata, to: candidate)
            probes += 1
            context.progress(min(0.95, Double(probes) / 4.5))
            let size = MediaRun.fileSize(candidate)
            if smallest.map({ size < $0.0 }) ?? true { smallest = (size, candidate) }
            if size <= target {
                fits = (mid, candidate)
                hi = mid - 1
            } else {
                lo = mid + 1
            }
        }
        guard let chosen = fits?.1 ?? smallest?.1, MediaRun.fileSize(chosen) < originalSize else { throw notSmaller }
        if fits == nil { context.logger.info("compress PDF: target \(target) not reachable; best \(smallest?.0 ?? 0)") }
        try FileManager.default.moveItem(at: chosen, to: dest)
        context.progress(1)
        return ConversionOutput(dest)
    }
}
