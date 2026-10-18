import Foundation
import UniformTypeIdentifiers

/// Slides via Quick Look's own Office generator: `qlmanage -p -o` writes an HTML
/// preview bundle (one absolutely positioned `div.slide` per slide), which we
/// print with WebKit one slide per page at the slide's aspect ratio, then
/// rasterise for PNG/JPG.
///
/// `qlmanage` is a debug tool with an undocumented output layout, so this is a
/// best-effort, low-priority path (the Office pack wins when installed) and the
/// engine checks the bundle it gets back before using it.
public struct QuickLookEngine: ConversionEngine {
    public let id = EngineIDs.quickLook
    public static let qlmanage = URL(fileURLWithPath: "/usr/bin/qlmanage")

    public init() {}

    public func isAvailable(_ capability: Capability) -> Bool {
        FileManager.default.isExecutableFile(atPath: Self.qlmanage.path)
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let work = request.outputDirectory.appendingPathComponent(".ql-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        context.progress(0.05)
        let html = try await Self.preview(request.input, into: work)
        context.progress(0.4)
        let pdf = request.to == Formats.pdf ? request.defaultOutputURL : work.appendingPathComponent("slides.pdf")
        try await Self.printSlides(html, to: pdf, input: request.input)
        context.progress(0.75)
        switch request.to {
        case Formats.pdf:
            return ConversionOutput(pdf)
        case Formats.png, Formats.jpg:
            let dpi = Double(request.options.string(OptionKey.dpi, default: "150")) ?? 150
            let quality = Double(request.options.int(OptionKey.quality, default: 90)) / 100
            let files = try PDFRaster.writePages(pdf, to: request.outputDirectory, baseName: request.baseName,
                                                 type: request.to == Formats.png ? .png : .jpeg, dpi: dpi, quality: quality,
                                                 progress: context.progress.scaled(0.75...1))
            return ConversionOutput(files)
        default:
            throw ConversionError.unsupported(from: request.from, to: request.to)
        }
    }

    /// Runs qlmanage (with a timeout) and returns the preview's HTML file.
    static func preview(_ input: URL, into dir: URL) async throws -> URL {
        // qlmanage names the bundle after the file; give it a plain copy name so odd characters can't trip it.
        let staged = dir.appendingPathComponent("input").appendingPathExtension(input.pathExtension)
        try FileManager.default.copyItem(at: input, to: staged)
        let out = dir.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try await ProcessRunner.run(qlmanage, ["-p", "-o", out.path, staged.path], checkExit: false)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 90_000_000_000)
                throw ConversionError.engineFailed("qlmanage", status: -1, detail: "timed out")
            }
            try await group.next()
            group.cancelAll()
        }
        let bundle = out.appendingPathComponent(staged.lastPathComponent + ".qlpreview")
        let html = bundle.appendingPathComponent("Preview.html")
        guard FileManager.default.fileExists(atPath: html.path) else {
            throw ConversionError.other(L("Quick Look couldn’t produce a preview of this file."), detail: "no Preview.html in \(out.path)")
        }
        return html
    }

    /// Prints a Quick Look slide preview: one slide per page, no margins, page = slide aspect.
    static func printSlides(_ html: URL, to pdf: URL, input: URL) async throws {
        var text = TextDecoding.decode(try Data(contentsOf: html))
        let (w, h) = slideSize(text) ?? slideSizeFromPackage(input) ?? (960, 540)
        guard text.contains("class=\"slide\"") else {
            throw ConversionError.other(L("Quick Look couldn’t produce a preview of this file."), detail: "preview has no slides")
        }
        let css = """
        <style type="text/css">
        @page { margin: 0; }
        html, body { margin: 0 !important; padding: 0 !important; background: #ffffff !important; }
        div.slide { margin: 0 !important; -webkit-box-shadow: none !important; box-shadow: none !important; break-after: page; page-break-after: always; background: #ffffff; }
        div.slide:last-of-type { break-after: auto; page-break-after: auto; }
        div.loading-slide { display: none !important; }
        </style>
        """
        if let r = text.range(of: "</head>", options: .caseInsensitive) { text.insert(contentsOf: css, at: r.lowerBound) } else { text = css + text }
        let patched = html.deletingLastPathComponent().appendingPathComponent("Print.html")
        try Data(text.utf8).write(to: patched, options: .atomic)
        // CSS px → pt.
        let page = WebPDFRenderer.PageSetup(size: CGSize(width: w * 0.75, height: h * 0.75), margin: 0)
        try await WebPDFRenderer.render(fileURL: patched, readAccess: html.deletingLastPathComponent(), to: pdf, page: page)
    }

    /// `div.slide, div.loading-slide { width: 960; height: 540;}`
    static func slideSize(_ html: String) -> (Double, Double)? {
        guard let r = html.range(of: #"div\.slide[^{]*\{\s*width:\s*([0-9.]+)(px)?;\s*height:\s*([0-9.]+)"#, options: .regularExpression) else { return nil }
        let nums = html[r].split(whereSeparator: { !"0123456789.".contains($0) }).compactMap { Double($0) }
        guard nums.count >= 2, nums[0] > 0, nums[1] > 0 else { return nil }
        return (nums[0], nums[1])
    }

    /// PPTX `p:sldSz` in EMU → CSS px at Quick Look's 1 pt = 1 px scale.
    static func slideSizeFromPackage(_ url: URL) -> (Double, Double)? {
        guard let zip = try? ZipReader(url: url), let pres = try? XMLTree.parse(zip.data("ppt/presentation.xml")),
              let sz = pres.first("sldSz"), let cx = sz["cx"].flatMap(Double.init), let cy = sz["cy"].flatMap(Double.init) else { return nil }
        return (cx / 12700, cy / 12700)
    }
}
