import AppKit
import AnyfmtCore
import RadialMenu
import UniformTypeIdentifiers

/// Deterministic fake data for the Wheel Gallery: a small capability table per
/// file kind (so the gallery doesn't depend on which engine lanes have landed),
/// the real tool and action catalogues, and Finder icons for hubs.
enum WheelGalleryData {
    struct Sample: Sendable {
        let name: String
        let inputs: [FormatID]
        let promisedType: UTType?
        let idle: String
    }

    static let samples: [Sample] = [
        Sample(name: "image", inputs: [Formats.jpg], promisedType: .jpeg, idle: "2.4 MB"),
        Sample(name: "video", inputs: [Formats.mov], promisedType: .quickTimeMovie, idle: "148 MB"),
        Sample(name: "audio", inputs: [Formats.wav], promisedType: .wav, idle: "31.7 MB"),
        Sample(name: "pdf", inputs: [Formats.pdf], promisedType: .pdf, idle: "860 KB"),
        Sample(name: "document", inputs: [Formats.docx], promisedType: nil, idle: "54 KB"),
        Sample(name: "spreadsheet", inputs: [Formats.xlsx], promisedType: nil, idle: "212 KB"),
        Sample(name: "slides", inputs: [Formats.pptx], promisedType: nil, idle: "6.1 MB"),
        Sample(name: "ebook", inputs: [Formats.epub], promisedType: .epub, idle: "1.2 MB"),
        Sample(name: "subtitle", inputs: [Formats.srt], promisedType: nil, idle: "18 KB"),
        Sample(name: "archive", inputs: [Formats.zip], promisedType: .zip, idle: "9.4 MB"),
        Sample(name: "folder", inputs: [Formats.folder], promisedType: .folder, idle: "Folder"),
        Sample(name: "multi", inputs: [Formats.jpg, Formats.png, Formats.heic], promisedType: .jpeg, idle: "3 files"),
        Sample(name: "mixed", inputs: [Formats.jpg, Formats.mov], promisedType: .jpeg, idle: "2 files"),
    ]

    private static let engine: EngineID = "gallery"

    /// Plausible rows per input kind, with one multi-hop target where it makes sense.
    static let table: CapabilityTable = {
        var rows: [Capability] = []
        func grid(_ from: FormatID, _ to: [FormatID], flags: CapabilityFlags = []) {
            rows += Capability.grid([from], to, engine, flags: flags)
        }
        let stills = [Formats.jpg, Formats.png, Formats.heic, Formats.webp, Formats.avif, Formats.tiff, Formats.gif, Formats.bmp]
        for from in [Formats.jpg, Formats.png, Formats.heic] {
            grid(from, stills)
            // An image → PDF is an end point, never a stepping stone to documents.
            rows.append(Capability(from, Formats.pdf, engine, flags: [.terminalOnly]))
        }
        rows.append(Capability(Formats.png, Formats.ico, engine, flags: [.lossless]))
        grid(Formats.mov, [Formats.mp4, Formats.webm, Formats.mkv, Formats.gif, Formats.mp3, Formats.m4a, Formats.wav])
        grid(Formats.wav, [Formats.mp3, Formats.m4a, Formats.flac, Formats.aiff, Formats.ogg, Formats.opus])
        grid(Formats.pdf, [Formats.jpg, Formats.png, Formats.heic, Formats.tiff], flags: [.multiOutput])
        grid(Formats.pdf, [Formats.txt, Formats.docx, Formats.html, Formats.md, Formats.rtf], flags: [.terminalOnly])
        grid(Formats.docx, [Formats.pdf, Formats.odt, Formats.rtf, Formats.txt, Formats.html, Formats.md, Formats.epub], flags: [.terminalOnly])
        grid(Formats.xlsx, [Formats.csv, Formats.tsv, Formats.ods, Formats.json, Formats.pdf, Formats.html], flags: [.terminalOnly])
        grid(Formats.pptx, [Formats.pdf, Formats.png, Formats.jpg], flags: [.terminalOnly])
        grid(Formats.epub, [Formats.pdf, Formats.txt, Formats.html, Formats.docx, Formats.md], flags: [.terminalOnly])
        grid(Formats.srt, [Formats.vtt, Formats.txt])
        grid(Formats.zip, [Formats.tar, Formats.gz, Formats.sevenZip])
        grid(Formats.folder, [Formats.zip, Formats.tar, Formats.gz])
        return CapabilityTable(rows)
    }()

    static let provider = WheelContentProvider(router: Router(table: table))

    static func input(for sample: Sample) -> WheelInput {
        // Fake inputs are promises of the right type; the provider only needs formats.
        WheelInput(urls: [], promisedTypes: sample.inputs.compactMap { Formats.format($0)?.utType })
    }

    @MainActor
    static func hub(for sample: Sample) -> RadialHubContent {
        let icon = sample.promisedType.map { NSWorkspace.shared.icon(for: $0) }
            ?? sample.inputs.first.flatMap { Formats.format($0)?.utType }.map { NSWorkspace.shared.icon(for: $0) }
        return RadialHubContent(image: icon, stackCount: sample.inputs.count, idleText: sample.idle)
    }

    /// Generic format items for the segment-count series.
    @MainActor
    static func countItems(_ n: Int) -> [RadialItem] {
        let formats = Formats.all.filter { $0.kind != .folder }
        return (0..<n).map { i in
            let f = formats[i % formats.count]
            return RadialItem(id: "count.\(i)", title: f.label, symbolName: f.glyph,
                              subtitle: i == 2 ? String(localized: "via PNG", comment: "Gallery sample hint") : nil,
                              prominence: .title)
        }
    }
}
