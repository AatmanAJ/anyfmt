import Foundation
import XCTest
@testable import HaloCore

/// Generates lane F fixtures once per test run (Tests/Fixtures/lanes/docs.sh) into a temp folder.
enum DocsFixtures {
    static let repoRoot: URL = {
        // …/Tests/Unit/Core/Docs/DocsTestSupport.swift → repo root
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }()

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: URL?

    static func directory() throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("halo-docs-fixtures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [repoRoot.appendingPathComponent("Tests/Fixtures/lanes/docs.sh").path]
        var env = ProcessInfo.processInfo.environment
        env["OUT"] = out.path
        p.environment = env
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw NSError(domain: "fixtures", code: Int(p.terminationStatus), userInfo: [NSLocalizedDescriptionKey: msg])
        }
        cached = out
        return out
    }

    static func url(_ name: String) throws -> URL { try directory().appendingPathComponent(name) }
}

func tempDir(_ name: String = "t") throws -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("halo-docs-\(name)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

/// Runs one engine directly on a file.
func runEngine(_ engine: any ConversionEngine, _ input: URL, from: FormatID, to: FormatID, options: OptionValues = .init(),
               baseName: String = "out", inputs: [URL]? = nil) async throws -> [URL] {
    let dir = try tempDir("out")
    let req = ConversionRequest(inputs: inputs ?? [input], from: from, to: to, options: options, outputDirectory: dir, baseName: baseName, metadata: .keep)
    return try await engine.convert(req, context: EngineContext()).files
}

extension DocModel {
    /// Flattened text of all blocks.
    var text: String { blocks.map(\.plainText).joined(separator: "\n") }

    func headings() -> [(Int, String)] {
        blocks.compactMap { if case .heading(let l, let i) = $0 { return (l, i.plainText) }; return nil }
    }

    func firstTable() -> DocTable? {
        for b in blocks { if case .table(let t) = b { return t } }
        return nil
    }

    func lists() -> [DocList] {
        blocks.compactMap { if case .list(let l) = $0 { return l }; return nil }
    }
}

/// A small PNG for image round trips.
func samplePNG(width: Int = 40, height: Int = 30) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return ImageSupport.encode(ctx.makeImage()!, type: .png)!
}

/// A document exercising every block type.
func richDoc(image: Bool = true) -> DocModel {
    var blocks: [DocBlock] = [
        .heading(level: 1, [.text("Main Title")]),
        .paragraph([.text("Plain "), .strong([.text("bold")]), .text(" and "), .emphasis([.text("italic")]), .text(" with a "),
                    .link(url: "https://example.org/", [.text("link")]), .text(" and "), .code("code()"), .text(".")]),
        .heading(level: 2, [.text("Lists")]),
        .list(DocList(ordered: false, items: [
            DocListItem([.paragraph([.text("Alpha")])]),
            DocListItem([.paragraph([.text("Beta")]), .list(DocList(ordered: true, items: [DocListItem([.paragraph([.text("Beta one")])])]))]),
        ])),
        .list(DocList(ordered: true, start: 3, items: [DocListItem([.paragraph([.text("Third")])]), DocListItem([.paragraph([.text("Fourth")])])])),
        .heading(level: 2, [.text("Table")]),
        .table(DocTable(rows: [
            DocTableRow([DocTableCell(inlines: [.text("Name")]), DocTableCell(inlines: [.text("Score")])], isHeader: true),
            DocTableRow([DocTableCell(inlines: [.text("Ada")]), DocTableCell(inlines: [.text("10")])]),
            DocTableRow([DocTableCell(inlines: [.text("Grace")]), DocTableCell(inlines: [.text("9")])]),
        ])),
        .blockquote([.paragraph([.text("Quoted words.")])]),
        .codeBlock(language: "swift", "let x = 1\nprint(x)"),
        .horizontalRule,
        .paragraph([.text("Last paragraph.")]),
    ]
    if image { blocks.insert(.image(DocImage(data: samplePNG(), mime: "image/png", alt: "Blue box", width: 60, height: 45)), at: 7) }
    return DocModel(metadata: DocMetadata(title: "Rich Doc", author: "Tester", language: "en"), blocks: blocks)
}
