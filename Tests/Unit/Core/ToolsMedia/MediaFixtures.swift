import XCTest
import AppKit
import CoreText
import PDFKit
@testable import HaloCore

/// Bundled engines for tests: HALO_ENGINES_DIR, else the checkout's Engines/dist
/// found by walking up from this file (worktrees live inside the main checkout).
enum TestEngines {
    static let locator: EngineLocator = {
        var dirs: [URL] = []
        if let d = ProcessInfo.processInfo.environment["HALO_ENGINES_DIR"], !d.isEmpty {
            dirs.append(URL(fileURLWithPath: d).appendingPathComponent("Helpers"))
        }
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            let c = dir.appendingPathComponent("Engines/dist/Helpers")
            if FileManager.default.isExecutableFile(atPath: c.appendingPathComponent("ffmpeg").path) { dirs.append(c) }
            dir.deleteLastPathComponent()
        }
        return EngineLocator(helperDirectories: dirs)
    }()

    static var context: EngineContext { EngineContext(locator: locator) }

    static func ffmpeg(_ args: [String]) async throws {
        guard let exe = locator.ffmpeg else { throw XCTSkip("bundled ffmpeg not found") }
        _ = try await ProcessRunner.run(exe, ["-hide_banner", "-nostdin", "-loglevel", "error", "-y"] + args)
    }

    /// Decodes audio to mono float samples at `rate`.
    static func pcm(_ url: URL, rate: Int = 48000, channel: Int? = nil) async throws -> [Float] {
        guard let exe = locator.ffmpeg else { throw XCTSkip("bundled ffmpeg not found") }
        var args = ["-hide_banner", "-nostdin", "-loglevel", "error", "-i", url.path, "-map", "0:a:0"]
        if let channel { args += ["-af", "pan=mono|c0=c\(channel)"] } else { args += ["-ac", "1"] }
        args += ["-ar", String(rate), "-f", "f32le", "pipe:1"]
        let r = try await ProcessRunner.run(exe, args)
        return r.stdout.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    static func rms(_ s: ArraySlice<Float>) -> Double {
        guard !s.isEmpty else { return 0 }
        return (s.reduce(0) { $0 + Double($1) * Double($1) } / Double(s.count)).squareRoot()
    }
}

/// Small media generated once per test run with the bundled ffmpeg, PDFKit and CoreGraphics.
actor MediaFixtures {
    static let store = MediaFixtures()
    private var built: Set<String> = []
    let dir: URL = FileManager.default.temporaryDirectory.appendingPathComponent("halo-g2-fixtures-\(ProcessInfo.processInfo.processIdentifier)")

    static func url(_ name: String) async throws -> URL { try await store.make(name) }

    private func make(_ name: String) async throws -> URL {
        let u = dir.appendingPathComponent(name)
        if built.contains(name), FileManager.default.fileExists(atPath: u.path) { return u }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: u)
        let tone = "sine=frequency=440:sample_rate=48000:duration=4"
        switch name {
        case "clip.mp4": // 4 s, 320×240, 30 fps, keyframe every second, stereo AAC
            try await TestEngines.ffmpeg(["-filter_complex", "testsrc2=size=320x240:rate=30:duration=4[v];\(tone)[a]",
                                          "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-g", "30", "-keyint_min", "30",
                                          "-sc_threshold", "0", "-pix_fmt", "yuv420p", "-c:a", "aac", "-ac", "2", "-b:a", "128k", u.path])
        case "clip2.mp4": // same encoder settings, 2 s: joins losslessly with clip.mp4
            try await TestEngines.ffmpeg(["-filter_complex", "testsrc2=size=320x240:rate=30:duration=2,hue=h=120[v];sine=frequency=660:sample_rate=48000:duration=2[a]",
                                          "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-g", "30", "-keyint_min", "30",
                                          "-sc_threshold", "0", "-pix_fmt", "yuv420p", "-c:a", "aac", "-ac", "2", "-b:a", "128k", u.path])
        case "wide.mov": // different size + no audio: forces a re-encoded join
            try await TestEngines.ffmpeg(["-filter_complex", "testsrc2=size=640x360:rate=25:duration=2[v]", "-map", "[v]",
                                          "-c:v", "libx264", "-pix_fmt", "yuv420p", u.path])
        case "longgop.mp4": // one keyframe only: lossless trims must fall back to re-encode
            try await TestEngines.ffmpeg(["-filter_complex", "testsrc2=size=320x240:rate=30:duration=4[v];\(tone)[a]",
                                          "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-g", "300", "-keyint_min", "300",
                                          "-sc_threshold", "0", "-pix_fmt", "yuv420p", "-c:a", "aac", "-ac", "2", u.path])
        case "silent.mp4":
            try await TestEngines.ffmpeg(["-filter_complex", "testsrc2=size=320x240:rate=30:duration=2[v]", "-map", "[v]",
                                          "-c:v", "libx264", "-pix_fmt", "yuv420p", u.path])
        case "tone.mp3":
            try await TestEngines.ffmpeg(["-filter_complex", "\(tone),pan=stereo|c0=c0|c1=0.5*c0[a]", "-map", "[a]",
                                          "-c:a", "libmp3lame", "-b:a", "192k", u.path])
        case "tone.m4a":
            try await TestEngines.ffmpeg(["-filter_complex", "\(tone)[a]", "-map", "[a]", "-ac", "2", "-c:a", "aac", "-b:a", "160k", u.path])
        case "mono.wav":
            try await TestEngines.ffmpeg(["-filter_complex", "sine=frequency=440:sample_rate=44100:duration=4[a]", "-map", "[a]",
                                          "-c:a", "pcm_s16le", u.path])
        case "lr.wav": // left 440 Hz loud, right silent: shows swaps and downmixes
            try await TestEngines.ffmpeg(["-filter_complex", "\(tone),pan=stereo|c0=c0|c1=0*c0[a]", "-map", "[a]", "-c:a", "pcm_s16le", u.path])
        case "quiet.flac": // ≈ −33 LUFS sine
            try await TestEngines.ffmpeg(["-filter_complex", "sine=frequency=440:sample_rate=48000:duration=6,volume=0.12[a]",
                                          "-map", "[a]", "-ac", "2", "-c:a", "flac", u.path])
        case "pages.pdf":
            try Self.makePDF(u, pages: 3, label: "Halo fixture page", imagePixels: (2400, 1800), outline: true)
        case "extra.pdf":
            try Self.makePDF(u, pages: 2, label: "Extra page", imagePixels: (800, 600), outline: false)
        case "text.pdf":
            try Self.makePDF(u, pages: 2, label: "Only text", imagePixels: nil, outline: false)
        default:
            XCTFail("unknown fixture \(name)")
        }
        built.insert(name)
        return u
    }

    /// Letter pages with a big photo-like image (Flate, so it's large) and real text.
    static func makePDF(_ url: URL, pages: Int, label: String, imagePixels: (Int, Int)?, outline: Bool) throws {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { throw XCTSkip("no PDF context") }
        let image = imagePixels.flatMap { makeImage(w: $0.0, h: $0.1) }
        for i in 1...pages {
            ctx.beginPDFPage(nil)
            if let image { ctx.draw(image, in: CGRect(x: 56, y: 300, width: 500, height: 375)) }
            let s = NSAttributedString(string: "\(label) \(i) searchable text", attributes: [.font: NSFont.systemFont(ofSize: 24)])
            ctx.textPosition = CGPoint(x: 56, y: 200)
            CTLineDraw(CTLineCreateWithAttributedString(s), ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        if outline, let source = PDFDocument(url: url) {
            // PDFKit only persists a new outline on a document it assembled itself.
            let doc = PDFDocument()
            for i in 0..<source.pageCount {
                if let p = source.page(at: i)?.copy() as? PDFPage { doc.insert(p, at: doc.pageCount) }
            }
            let root = PDFOutline()
            for i in 0..<doc.pageCount {
                guard let p = doc.page(at: i) else { continue }
                let item = PDFOutline()
                item.label = "Chapter \(i + 1)"
                item.destination = PDFDestination(page: p, at: CGPoint(x: 0, y: 792))
                root.insertChild(item, at: i)
            }
            doc.outlineRoot = root
            let tmp = url.deletingLastPathComponent().appendingPathComponent("tmp-\(UUID().uuidString).pdf")
            guard doc.write(to: tmp) else { throw XCTSkip("outline write failed") }
            try FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: tmp, to: url)
        }
    }

    static func makeImage(w: Int, h: Int) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let colors = [CGColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1), CGColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1)] as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: w, y: h), options: [])
        }
        var seed: UInt64 = 42
        for _ in 0..<4000 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = CGFloat(seed % UInt64(w)), y = CGFloat((seed >> 20) % UInt64(h)), r = CGFloat((seed >> 40) % 60) + 5
            ctx.setFillColor(CGColor(red: CGFloat(seed % 255) / 255, green: CGFloat((seed >> 8) % 255) / 255,
                                     blue: CGFloat((seed >> 16) % 255) / 255, alpha: 0.6))
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
        }
        return ctx.makeImage()
    }
}

/// A fresh output directory per test, like the job layer's private temp dir.
func makeOutputDirectory() throws -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("halo-g2-out-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

func runTool(_ runner: any ToolRunner, _ inputs: [URL], _ options: [String: OptionValue], metadata: MetadataPolicy = .keep,
             base: String = "out") async throws -> (ConversionOutput, URL) {
    let dir = try makeOutputDirectory()
    let spec = ToolCatalog.spec(runner.id)
    let opts = (spec?.defaultOptions ?? OptionValues()).merging(OptionValues(options))
    let req = ToolRequest(tool: runner.id, inputs: inputs, options: opts, outputDirectory: dir, baseName: base, metadata: metadata)
    let out = try await runner.run(req, context: TestEngines.context)
    // Tools write only inside their output directory and clean their scratch.
    for f in out.files { XCTAssertEqual(f.deletingLastPathComponent().standardizedFileURL, dir.standardizedFileURL) }
    let leftovers = (try FileManager.default.contentsOfDirectory(atPath: dir.path)).filter { $0.hasPrefix(".halo-scratch") }
    XCTAssertTrue(leftovers.isEmpty, "scratch left behind: \(leftovers)")
    return (out, dir)
}
