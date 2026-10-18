// Lane D fixture generator, run by images.sh with `swift`. Writes deterministic
// sample.<ext> files for every image/PDF input lane D ships. System frameworks only.
//
//   swift images-fixtures.swift <out-dir>
import Foundation
import ImageIO
import CoreGraphics
import CoreText
import PDFKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".", isDirectory: true)
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("images-fixtures: \(msg)\n".utf8))
    exit(1)
}

guard let p3 = CGColorSpace(name: CGColorSpace.displayP3), let srgb = CGColorSpace(name: CGColorSpace.sRGB) else { fail("colour spaces") }

/// 640×480 test card: saturated P3 bars, a gradient, a corner marker (top-left red
/// square, so orientation is visible) and a half-transparent band at the bottom.
func card(width w: Int = 640, height h: Int = 480, space: CGColorSpace = p3, bits: Int = 8, alpha: Bool = true, label: String = "Halo") -> CGImage {
    var info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
    if bits == 16 { info |= CGBitmapInfo.byteOrder16Little.rawValue }
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: bits, bytesPerRow: 0, space: space, bitmapInfo: info) else { fail("context") }
    let colors: [(CGFloat, CGFloat, CGFloat)] = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (1, 1, 0), (0, 1, 1), (1, 0, 1), (1, 1, 1), (0.2, 0.2, 0.2)]
    let barW = CGFloat(w) / CGFloat(colors.count)
    for (i, c) in colors.enumerated() {
        ctx.setFillColor(CGColor(colorSpace: space, components: [c.0, c.1, c.2, 1]) ?? CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: CGFloat(i) * barW, y: CGFloat(h) * 0.35, width: barW, height: CGFloat(h) * 0.65))
    }
    if let g = CGGradient(colorsSpace: space, colors: [CGColor(colorSpace: space, components: [0, 0, 0, 1])!, CGColor(colorSpace: space, components: [1, 1, 1, 1])!] as CFArray, locations: nil) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(h) * 0.25), end: CGPoint(x: CGFloat(w), y: CGFloat(h) * 0.25), options: [])
    }
    // Top-left orientation marker (CG origin is bottom-left).
    ctx.setFillColor(CGColor(colorSpace: space, components: [1, 0, 0, 1])!)
    ctx.fill(CGRect(x: 0, y: CGFloat(h) - 60, width: 60, height: 60))
    if alpha {
        ctx.clear(CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h) * 0.12))
        ctx.setFillColor(CGColor(colorSpace: space, components: [0, 0.4, 1, 0.5])!)
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(w) / 2, height: CGFloat(h) * 0.12))
    }
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, CGFloat(h) / 8, nil)
    let text = NSAttributedString(string: label, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font,
                                                              NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(colorSpace: space, components: [0, 0, 0, 1])!])
    ctx.textPosition = CGPoint(x: CGFloat(w) * 0.3, y: CGFloat(h) * 0.55)
    CTLineDraw(CTLineCreateWithAttributedString(text), ctx)
    guard let img = ctx.makeImage() else { fail("makeImage") }
    return img
}

/// Camera-like metadata: rotated 90° CW (orientation 6), GPS, device and author fields.
let cameraProps: [CFString: Any] = [
    kCGImagePropertyOrientation: 6,
    kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144,
    kCGImagePropertyTIFFDictionary: [
        kCGImagePropertyTIFFOrientation: 6, kCGImagePropertyTIFFMake: "Halo", kCGImagePropertyTIFFModel: "Fixture Cam",
        kCGImagePropertyTIFFArtist: "Fixture Author", kCGImagePropertyTIFFSoftware: "images-fixtures",
    ],
    kCGImagePropertyExifDictionary: [
        kCGImagePropertyExifDateTimeOriginal: "2026:10:18 12:00:00", kCGImagePropertyExifBodySerialNumber: "HALO-0001",
        kCGImagePropertyExifLensModel: "Fixture 24mm", kCGImagePropertyExifISOSpeedRatings: [100], kCGImagePropertyExifFNumber: 2.8,
    ],
    kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 51.5007, kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 0.1246, kCGImagePropertyGPSLongitudeRef: "W",
    ],
    kCGImagePropertyIPTCDictionary: [kCGImagePropertyIPTCByline: ["Fixture Author"], kCGImagePropertyIPTCCity: "London", kCGImagePropertyIPTCKeywords: ["halo", "fixture"]],
]

func write(_ name: String, _ uti: String, _ images: [(CGImage, [CFString: Any])], container: [CFString: Any]? = nil) {
    let url = out.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, uti as CFString, images.count, nil) else { fail("no encoder for \(uti) (\(name))") }
    if let container { CGImageDestinationSetProperties(dest, container as CFDictionary) }
    for (img, props) in images { CGImageDestinationAddImage(dest, img, props as CFDictionary) }
    guard CGImageDestinationFinalize(dest) else { fail("encode \(name)") }
}

let destTypes = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
let photo = card()
let opaque = card(alpha: false)
let srgbCard = card(space: srgb)

write("sample.jpg", "public.jpeg", [(opaque, cameraProps.merging([kCGImageDestinationLossyCompressionQuality: 0.9]) { $1 })])
write("sample.png", "public.png", [(photo, cameraProps)])
write("sample.heic", "public.heic", [(photo, cameraProps.merging([kCGImageDestinationLossyCompressionQuality: 0.8]) { $1 })])
write("sample.heif", "public.heic", [(photo, [kCGImageDestinationLossyCompressionQuality: 0.8])])
// Two-page TIFF: a 16-bit P3 page with alpha, then an 8-bit page.
write("sample.tiff", "public.tiff", [(card(bits: 16, label: "Page 1"), [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 5]]),
                                      (card(alpha: false, label: "Page 2"), [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFCompression: 5]])])
if destTypes.contains("public.avif") {
    write("sample.avif", "public.avif", [(photo, [kCGImageDestinationLossyCompressionQuality: 0.8])])
}
write("sample.bmp", "com.microsoft.bmp", [(card(space: srgb, alpha: false), [:])])
write("sample.jp2", "public.jpeg-2000", [(card(space: srgb, alpha: false), [kCGImageDestinationLossyCompressionQuality: 0.8])])
write("sample.psd", "com.adobe.photoshop-image", [(photo, [:])])
write("sample.tga", "com.truevision.tga-image", [(srgbCard, [:])])
write("sample.exr", "com.ilm.openexr-image", [(srgbCard, [:])])

// Square icons at several sizes.
func square(_ s: Int) -> CGImage { card(width: s, height: s, space: srgb, label: "Halo") }
write("sample.ico", "com.microsoft.ico", [16, 32, 48, 256].map { (square($0), [:]) })
write("sample.icns", "com.apple.icns", [16, 32, 128, 256, 512].map { (square($0), [:]) })

// Animated GIF: 5 frames, 100…500 ms, looping forever.
let frames: [(CGImage, [CFString: Any])] = (0..<5).map { i in
    let img = card(width: 320, height: 240, space: srgb, label: "Halo \(i + 1)")
    return (img, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1 * Double(i + 1)]])
}
write("sample.gif", "com.compuserve.gif", frames, container: [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]])

// Source for the ffmpeg-made fixtures (WebP, AVIF fallback): sRGB RGBA PNG.
write(".images-src.png", "public.png", [(srgbCard, [:])])

// MARK: PDF — 3 pages of text + vector art; plus edge cases.

func pdf(_ name: String, pages: Int, rotateSecond: Bool = false, scanned: Bool = false) {
    let url = out.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: url)
    var box = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, [kCGPDFContextTitle: "Halo fixture", kCGPDFContextCreator: "images-fixtures"] as CFDictionary) else { fail("pdf \(name)") }
    for i in 1...pages {
        ctx.beginPDFPage(nil)
        if scanned {
            // A page that is only a picture of text: no text layer, needs OCR.
            ctx.draw(card(width: 1200, height: 400, space: srgb, alpha: false, label: "Scanned words \(i)"), in: CGRect(x: 40, y: 400, width: 515, height: 172))
        } else {
            ctx.setFillColor(CGColor(colorSpace: srgb, components: [0.1, 0.45, 0.95, 1])!)
            ctx.fillEllipse(in: CGRect(x: 60, y: 600, width: 180, height: 180))
            ctx.setStrokeColor(CGColor(colorSpace: srgb, components: [0.9, 0.2, 0.2, 1])!)
            ctx.setLineWidth(6)
            ctx.stroke(CGRect(x: 300, y: 620, width: 220, height: 140))
            let font = CTFontCreateWithName("Helvetica" as CFString, 28, nil)
            for (n, line) in ["Halo fixture page \(i)", "The quick brown fox jumps over the lazy dog."].enumerated() {
                let s = NSAttributedString(string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
                ctx.textPosition = CGPoint(x: 60, y: 520 - CGFloat(n) * 44)
                CTLineDraw(CTLineCreateWithAttributedString(s), ctx)
            }
        }
        ctx.endPDFPage()
    }
    ctx.closePDF()
    if rotateSecond, let doc = PDFDocument(url: url), let page = doc.page(at: 1) {
        page.rotation = 90
        guard doc.write(to: url) else { fail("rotate \(name)") }
    }
}
pdf("sample.pdf", pages: 3)
pdf("edge-rotated.pdf", pages: 2, rotateSecond: true)
pdf("edge-scanned.pdf", pages: 1, scanned: true)

// MARK: SVG — hand-written: gradient, transparency, text, viewBox scaling.
let svg = """
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="200" viewBox="0 0 160 100">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#ff5a1f"/>
      <stop offset="1" stop-color="#1f7aff"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="152" height="92" rx="14" fill="url(#g)"/>
  <circle cx="40" cy="50" r="24" fill="#ffffff" fill-opacity="0.6"/>
  <path d="M90 30 L140 50 L90 70 Z" fill="#111111"/>
  <text x="80" y="92" font-family="Helvetica, Arial, sans-serif" font-size="12" text-anchor="middle" fill="#ffffff">Halo</text>
</svg>
"""
try? Data(svg.utf8).write(to: out.appendingPathComponent("sample.svg"))
print("images-fixtures: wrote fixtures to \(out.path)")
