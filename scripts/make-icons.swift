#!/usr/bin/env swift
// Draws Halo's own icons (no third-party art):
//   - MenuBarIcon.pdf: template glyph, a ring with a segmented arc + orbit dot
//   - AppIcon_*.png: iris→mint squircle with a white segmented halo
// Usage: swift scripts/make-icons.swift <Assets.xcassets dir>
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count > 1 else { fatalError("usage: make-icons.swift <Assets.xcassets>") }
let assets = URL(fileURLWithPath: args[1])

func segmentedRing(in ctx: CGContext, center: CGPoint, radius: CGFloat, width: CGFloat, segments: Int, gapDeg: CGFloat, highlight: Int?) {
    let span = 360 / CGFloat(segments)
    for i in 0..<segments {
        let start = (90 - CGFloat(i) * span - gapDeg / 2) * .pi / 180
        let end = (90 - CGFloat(i + 1) * span + gapDeg / 2) * .pi / 180
        ctx.saveGState()
        if let h = highlight, h == i { ctx.setLineWidth(width * 1.35) } else { ctx.setLineWidth(width) }
        ctx.setLineCap(.round)
        ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

// MARK: Menu bar template (18×18 pt, vector)
do {
    let url = assets.appendingPathComponent("MenuBarIcon.imageset/MenuBarIcon.pdf")
    var box = CGRect(x: 0, y: 0, width: 18, height: 18)
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { fatalError("pdf ctx") }
    ctx.beginPDFPage(nil)
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setFillColor(NSColor.black.cgColor)
    segmentedRing(in: ctx, center: CGPoint(x: 9, y: 9), radius: 6.4, width: 1.9, segments: 6, gapDeg: 22, highlight: 0)
    ctx.fillEllipse(in: CGRect(x: 7.1, y: 7.1, width: 3.8, height: 3.8))
    ctx.endPDFPage()
    ctx.closePDF()
}

// MARK: App icon
func appIcon(px: Int) -> Data {
    let s = CGFloat(px)
    let cs = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("ctx") }
    // macOS icon grid: 824/1024 body with ~185/1024 corner radius.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: body, cornerWidth: s * 185 / 1024, cornerHeight: s * 185 / 1024, transform: nil)
    // Soft drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let colors = [NSColor(srgbRed: 0x5A / 255, green: 0x45 / 255, blue: 0xF0 / 255, alpha: 1).cgColor,
                  NSColor(srgbRed: 0x8B / 255, green: 0x78 / 255, blue: 0xFF / 255, alpha: 1).cgColor,
                  NSColor(srgbRed: 0x2C / 255, green: 0xD3 / 255, blue: 0xB5 / 255, alpha: 1).cgColor] as CFArray
    if let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.55, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])
    }
    // Inner glow
    if let glow = CGGradient(colorsSpace: cs, colors: [NSColor.white.withAlphaComponent(0.28).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.5, y: s * 0.55), startRadius: 0,
                               endCenter: CGPoint(x: s * 0.5, y: s * 0.55), endRadius: s * 0.42, options: [])
    }
    // Halo: segmented ring + hub
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setFillColor(NSColor.white.cgColor)
    let c = CGPoint(x: s / 2, y: s / 2)
    ctx.setShadow(offset: .zero, blur: s * 0.02, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    segmentedRing(in: ctx, center: c, radius: s * 0.255, width: s * 0.062, segments: 6, gapDeg: 16, highlight: 0)
    ctx.fillEllipse(in: CGRect(x: c.x - s * 0.085, y: c.y - s * 0.085, width: s * 0.17, height: s * 0.17))
    ctx.restoreGState()
    guard let img = ctx.makeImage() else { fatalError("img") }
    let rep = NSBitmapImageRep(cgImage: img)
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    return png
}

let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for (pt, scale) in sizes {
    let px = pt * scale
    let name = "AppIcon_\(pt)x\(pt)@\(scale)x.png"
    try appIcon(px: px).write(to: assets.appendingPathComponent("AppIcon.appiconset/\(name)"))
    images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(pt)x\(pt)", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: assets.appendingPathComponent("AppIcon.appiconset/Contents.json"))
try appIcon(px: 1024).write(to: assets.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/screens/app-icon.png"))
print("icons written")
