import AppKit
import CoreText
import PDFKit
import SwiftUI
import XCTest
@testable import HaloApp
import HaloCore

/// Points `EngineLocator.shared` at the checkout's Engines/dist before anything
/// reads it. (Engines embedded in an ad-hoc signed debug app currently fail
/// library validation; see docs/lanes/G2-media-tools.md, Blockers.)
enum TestEngineSetup {
    static let done: Bool = {
        if ProcessInfo.processInfo.environment["HALO_ENGINES_DIR"]?.isEmpty ?? true {
            var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            for _ in 0..<12 {
                let dist = dir.appendingPathComponent("Engines/dist")
                if FileManager.default.isExecutableFile(atPath: dist.appendingPathComponent("Helpers/ffmpeg").path) {
                    setenv("HALO_ENGINES_DIR", dist.path, 1)
                    break
                }
                dir.deleteLastPathComponent()
            }
        }
        return true
    }()
}

/// Sample media for editor tests and screenshots, made once per run with the
/// bundled ffmpeg, PDFKit and CoreGraphics.
actor EditorSamples {
    static let store = EditorSamples()
    private var built: Set<String> = []
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("halo-g2-editor-samples-\(ProcessInfo.processInfo.processIdentifier)")

    static func url(_ name: String) async throws -> URL {
        _ = TestEngineSetup.done
        return try await store.make(name)
    }

    private static func ffmpeg(_ args: [String]) async throws {
        guard let exe = EngineLocator.shared.ffmpeg else { throw XCTSkip("bundled ffmpeg not embedded in the test host") }
        _ = try await ProcessRunner.run(exe, ["-hide_banner", "-nostdin", "-loglevel", "error", "-y"] + args)
    }

    /// A pleasant moving gradient with a sliding block, and a two-voice "speech" envelope.
    private static let scene = "gradients=s=960x540:c0=0x2B1B6E:c1=0x6E56F8:c2=0x22C3A6:c3=0xF5C451:n=4:speed=0.015:duration=12:rate=30,"
        + "drawbox=x='120+mod(t*90\\,700)':y=300:w=120:h=120:color=white@0.85:t=fill,drawbox=x=0:y=440:w=iw:h=100:color=0x14102a@0.55:t=fill"
    private static let voice = "aevalsrc='0.55*sin(2*PI*220*t)*abs(sin(2*PI*0.45*t))*(0.6+0.4*sin(2*PI*2.7*t))"
        + "|0.5*sin(2*PI*330*t)*abs(sin(2*PI*0.45*t+0.3))*(0.6+0.4*sin(2*PI*2.1*t))':s=48000:d=12"

    private func make(_ name: String) async throws -> URL {
        let u = dir.appendingPathComponent(name)
        if built.contains(name), FileManager.default.fileExists(atPath: u.path) { return u }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: u)
        switch name {
        case "Beach day.mp4":
            try await Self.ffmpeg(["-filter_complex", "\(Self.scene)[v];\(Self.voice)[a]", "-map", "[v]", "-map", "[a]",
                                   "-c:v", "libx264", "-g", "30", "-keyint_min", "30", "-sc_threshold", "0",
                                   "-pix_fmt", "yuv420p", "-c:a", "aac", u.path])
        case "Sunset.mov":
            try await Self.ffmpeg(["-filter_complex", "gradients=s=640x480:c0=0xF5C451:c1=0xE5484D:c2=0x2B1B6E:n=3:speed=0.02:duration=5:rate=25[v]",
                                   "-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p", u.path])
        case "Intro.mp4":
            try await Self.ffmpeg(["-filter_complex", "\(Self.scene.replacingOccurrences(of: "duration=12", with: "duration=4"))[v];\(Self.voice.replacingOccurrences(of: "d=12", with: "d=4"))[a]",
                                   "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-g", "30", "-keyint_min", "30", "-sc_threshold", "0",
                                   "-pix_fmt", "yuv420p", "-c:a", "aac", u.path])
        case "Clip.mkv":
            try await Self.ffmpeg(["-filter_complex", "testsrc2=size=320x240:rate=30:duration=3[v]", "-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p", u.path])
        case "Interview.m4a":
            try await Self.ffmpeg(["-filter_complex", "\(Self.voice)[a]", "-map", "[a]", "-c:a", "aac", "-b:a", "160k", u.path])
        case "Short.wav":
            try await Self.ffmpeg(["-filter_complex", "sine=frequency=440:sample_rate=8000:duration=1[a]", "-map", "[a]", "-c:a", "pcm_s16le", u.path])
        case "Report.pdf":
            try Self.makePDF(u, title: "Quarterly report", pages: 5, hue: 0.72)
        case "Appendix.pdf":
            try Self.makePDF(u, title: "Appendix", pages: 3, hue: 0.45)
        default:
            XCTFail("unknown sample \(name)")
        }
        built.insert(name)
        return u
    }

    static func makePDF(_ url: URL, title: String, pages: Int, hue: CGFloat) throws {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { throw XCTSkip("no PDF context") }
        for i in 1...pages {
            ctx.beginPDFPage(nil)
            let tint = NSColor(calibratedHue: hue, saturation: 0.55, brightness: 0.85, alpha: 1).cgColor
            ctx.setFillColor(tint)
            ctx.fill(CGRect(x: 0, y: 692, width: 612, height: 100))
            ctx.setFillColor(NSColor(calibratedHue: hue, saturation: 0.25, brightness: 0.95, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 56, y: 380, width: 500, height: 260))
            ctx.setFillColor(NSColor(white: 0.75, alpha: 1).cgColor)
            for line in 0..<9 { ctx.fill(CGRect(x: 56, y: 330 - CGFloat(line) * 26, width: line % 3 == 2 ? 300 : 500, height: 10)) }
            let s = NSAttributedString(string: "\(title) · \(i)", attributes: [.font: NSFont.boldSystemFont(ofSize: 34), .foregroundColor: NSColor.white])
            ctx.textPosition = CGPoint(x: 56, y: 728)
            CTLineDraw(CTLineCreateWithAttributedString(s), ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
    }
}

@MainActor
enum EditorRender {
    /// Renders `view` offscreen at `size` in the given appearance.
    static func image(_ view: AnyView, size: NSSize = EditorWindow.defaultSize, dark: Bool,
                      settle: (@MainActor () async -> Void)? = nil) async -> NSBitmapImageRep? {
        // A real window paints its background behind the shell; offscreen we add it.
        let host = NSHostingView(rootView: AnyView(view.background(Color(nsColor: .windowBackgroundColor))))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -20_000, y: -20_000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        // Layout kicks off size-dependent loading (filmstrip thumbnails); wait for it.
        if let settle { await settle() }
        // Let SwiftUI lay out, load images and run a few animation frames.
        for _ in 0..<12 {
            host.layoutSubtreeIfNeeded()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        host.layoutSubtreeIfNeeded()
        host.display()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        window.orderOut(nil)
        window.contentView = nil
        return rep
    }

    static func downscaled(_ rep: NSBitmapImageRep) -> NSBitmapImageRep? {
        let w = rep.pixelsWide / 2, h = rep.pixelsHigh / 2
        guard let cg = rep.cgImage, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                                       space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage().map { NSBitmapImageRep(cgImage: $0) }
    }

    /// docs/screens in this checkout.
    static var screensDirectory: URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<4 { dir.deleteLastPathComponent() }
        return dir.appendingPathComponent("docs/screens")
    }

    /// Writes `rep` to docs/screens/<name>.png when HALO_EDITOR_SCREENS is set
    /// (TEST_RUNNER_HALO_EDITOR_SCREENS=1 on the xcodebuild line), else to a temp dir.
    @discardableResult
    static func save(_ rep: NSBitmapImageRep, name: String) throws -> URL {
        let wantsDocs = ProcessInfo.processInfo.environment["HALO_EDITOR_SCREENS"] != nil
        let dir = wantsDocs ? screensDirectory : FileManager.default.temporaryDirectory.appendingPathComponent("halo-editor-screens")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(name).png")
        // Dark variants are kept at 1× to keep the repo light; light ones stay Retina.
        let out = name.hasSuffix("-dark") ? (downscaled(rep) ?? rep) : rep
        guard let data = out.representation(using: .png, properties: [:]) else { throw XCTSkip("png encode failed") }
        try data.write(to: url)
        return url
    }
}
