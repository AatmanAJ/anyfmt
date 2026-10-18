import AppKit
import CoreGraphics
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import HaloApp
import HaloCore

/// Sample media for editor tests and screenshots, drawn from scratch.
@MainActor
enum EditorSamples {
    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    static func dir(_ name: String) throws -> URL {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("halo-g1-app-\(name)-\(UUID().uuidString.prefix(6))", isDirectory: true)
        try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// A landscape "photo": dusk sky, sun, layered hills, a lake.
    static func landscape(width w: Int = 1600, height h: Int = 1067, hue: CGFloat = 0) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let W = CGFloat(w), H = CGFloat(h)
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
            // Rotate hue a little per sample so collages look varied.
            let rr = r * (1 - hue) + b * hue, bb = b * (1 - hue) + r * hue
            return CGColor(srgbRed: rr, green: g, blue: bb, alpha: 1)
        }
        let sky = CGGradient(colorsSpace: srgb, colors: [c(0.98, 0.62, 0.42), c(0.55, 0.42, 0.78), c(0.18, 0.2, 0.45)] as CFArray, locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: H * 0.35), end: CGPoint(x: 0, y: H), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        // Sun with glow.
        let sun = CGPoint(x: W * 0.68, y: H * 0.52)
        let glow = CGGradient(colorsSpace: srgb, colors: [CGColor(srgbRed: 1, green: 0.93, blue: 0.75, alpha: 1), CGColor(srgbRed: 1, green: 0.8, blue: 0.55, alpha: 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: sun, startRadius: 0, endCenter: sun, endRadius: H * 0.28, options: [])
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.95, blue: 0.82, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: sun.x - H * 0.07, y: sun.y - H * 0.07, width: H * 0.14, height: H * 0.14))
        // Hills, far to near.
        let hills: [(CGFloat, CGFloat, CGColor)] = [(0.5, 0.08, c(0.36, 0.27, 0.52)), (0.42, 0.1, c(0.25, 0.2, 0.42)), (0.33, 0.07, c(0.14, 0.13, 0.3))]
        for (i, hill) in hills.enumerated() {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 0, y: H * hill.0))
            var x: CGFloat = 0
            while x <= W {
                let y = H * hill.0 + sin(x / W * .pi * (2.2 + CGFloat(i)) + CGFloat(i)) * H * hill.1 + cos(x / W * 9 + CGFloat(i)) * H * 0.015
                p.addLine(to: CGPoint(x: x, y: y))
                x += W / 80
            }
            p.addLine(to: CGPoint(x: W, y: 0))
            p.closeSubpath()
            ctx.addPath(p)
            ctx.setFillColor(hill.2)
            ctx.fillPath()
        }
        // Lake with reflection streaks.
        let lake = CGGradient(colorsSpace: srgb, colors: [c(0.2, 0.22, 0.42), c(0.08, 0.09, 0.2)] as CFArray, locations: [0, 1])!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: H * 0.22))
        ctx.drawLinearGradient(lake, start: CGPoint(x: 0, y: H * 0.22), end: .zero, options: [])
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.65, alpha: 0.16))
        for k in 0..<9 {
            let y = H * 0.2 - CGFloat(k) * H * 0.022
            let half = W * (0.06 - CGFloat(k) * 0.004)
            ctx.fill(CGRect(x: sun.x - half, y: y, width: half * 2, height: H * 0.006))
        }
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    /// A simple "document" screenshot: header bar, lines of fake text, an email-like line.
    static func screenshot(width w: Int = 1400, height h: Int = 900) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let H = CGFloat(h), W = CGFloat(w)
        ctx.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        ctx.setFillColor(CGColor(srgbRed: 0.43, green: 0.34, blue: 0.97, alpha: 1)); ctx.fill(CGRect(x: 0, y: H - 90, width: W, height: 90))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9)); ctx.fill(CGRect(x: 60, y: H - 60, width: 320, height: 26))
        var y = H - 170
        var rng = SplitMixTest(seed: 3)
        while y > 80 {
            var x: CGFloat = 60
            while x < W - 200 {
                let word = CGFloat(40 + rng.next() % 110)
                ctx.setFillColor(CGColor(srgbRed: 0.2, green: 0.2, blue: 0.26, alpha: 0.75))
                ctx.fill(CGRect(x: x, y: y, width: word, height: 16))
                x += word + 14
            }
            y -= 42
        }
        return ctx.makeImage()!
    }

    @discardableResult
    static func writeJPEG(_ image: CGImage, to url: URL, properties: [String: Any] = [:]) -> URL {
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        var p = properties
        p[kCGImageDestinationLossyCompressionQuality as String] = 0.88
        CGImageDestinationAddImage(d, image, p as CFDictionary)
        CGImageDestinationFinalize(d)
        return url
    }

    static let photoMetadata: [String: Any] = [
        kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifDateTimeOriginal as String: "2026:07:14 20:41:09",
                                                   kCGImagePropertyExifFNumber as String: 1.8, kCGImagePropertyExifExposureTime as String: 0.008,
                                                   kCGImagePropertyExifISOSpeedRatings as String: [80], kCGImagePropertyExifFocalLength as String: 6.9,
                                                   kCGImagePropertyExifFocalLenIn35mmFilm as String: 26],
        kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFMake as String: "Apple", kCGImagePropertyTIFFModel as String: "iPhone 17 Pro",
                                                   kCGImagePropertyTIFFArtist as String: "Sam Rivera"],
        kCGImagePropertyIPTCDictionary as String: [kCGImagePropertyIPTCObjectName as String: "Dusk over the lake",
                                                   kCGImagePropertyIPTCKeywords as String: ["lake", "sunset", "hills"]],
        kCGImagePropertyGPSDictionary as String: [kCGImagePropertyGPSLatitude as String: 46.4523, kCGImagePropertyGPSLatitudeRef as String: "N",
                                                  kCGImagePropertyGPSLongitude as String: 8.0213, kCGImagePropertyGPSLongitudeRef as String: "E",
                                                  kCGImagePropertyGPSAltitude as String: 1240.0],
    ]

    /// Writes the standard set: photo.jpg (with metadata), screen.jpg, and three collage images.
    static func standardSet(in dir: URL) -> (photo: URL, screen: URL, more: [URL]) {
        let photo = writeJPEG(landscape(), to: dir.appendingPathComponent("Lake at dusk.jpg"), properties: photoMetadata)
        let screen = writeJPEG(screenshot(), to: dir.appendingPathComponent("Account details.jpg"))
        let more = [
            writeJPEG(landscape(width: 900, height: 1200, hue: 0.35), to: dir.appendingPathComponent("Ridge.jpg")),
            writeJPEG(landscape(width: 1200, height: 800, hue: 0.7), to: dir.appendingPathComponent("Bay.jpg")),
            writeJPEG(landscape(width: 1000, height: 1000, hue: 0.15), to: dir.appendingPathComponent("Peak.jpg")),
            writeJPEG(landscape(width: 1400, height: 700, hue: 0.5), to: dir.appendingPathComponent("Valley.jpg")),
        ]
        return (photo, screen, more)
    }

    static func spec(_ id: ToolID) -> ToolSpec { ToolCatalog.spec(id)! }
}

struct SplitMixTest {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Offscreen rendering of SwiftUI content into PNGs (docs/screens).
@MainActor
enum EditorSnapshot {
    static var screensDirectory: URL {
        // Tests/Unit/App/EditorsImage/<file> → repo root.
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/screens", isDirectory: true)
    }

    /// Hosts `view` in a window (needed for AppKit-backed controls), lets
    /// SwiftUI settle, then caches the display.
    static func render<V: View>(_ view: V, size: NSSize, dark: Bool = false, settle: TimeInterval = 0.35) -> NSBitmapImageRep? {
        // Borderless: no title-bar safe area, so the image shows exactly the content view.
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -6000, y: -6000), size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.appearance = appearance
        window.backgroundColor = .windowBackgroundColor
        // The real window paints its background behind the content; cacheDisplay doesn't, so paint it here.
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        hosting.appearance = appearance
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        window.orderFrontRegardless()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(settle))
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        hosting.display()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { window.close(); return nil }
        (appearance ?? NSAppearance.currentDrawing()).performAsCurrentDrawingAppearance {
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
        }
        window.orderOut(nil)
        window.close()
        return rep
    }

    @discardableResult
    static func write<V: View>(_ view: V, size: NSSize, name: String, dark: Bool = false) throws -> URL {
        let rep = try XCTUnwrap(render(view, size: size, dark: dark))
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: screensDirectory, withIntermediateDirectories: true)
        let url = screensDirectory.appendingPathComponent("\(name)\(dark ? "-dark" : "").png")
        try data.write(to: url)
        return url
    }
}
