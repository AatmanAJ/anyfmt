#!/usr/bin/env swift
// Draws the DMG window background (our own art): soft iris→mint wash, a
// segmented-ring motif and a guide arrow from the app to Applications.
// Usage: swift make-background.swift <out-dir> <app name>
import AppKit

let args = CommandLine.arguments
guard args.count > 2 else { fatalError("usage: make-background.swift <out-dir> <app name>") }
let outDir = URL(fileURLWithPath: args[1])
let appName = args[2]
let size = CGSize(width: 660, height: 400)

func render(scale: CGFloat) -> Data {
    let px = CGSize(width: size.width * scale, height: size.height * scale)
    let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(px.width), height: Int(px.height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("ctx") }
    ctx.scaleBy(x: scale, y: scale)
    // Base
    let base = [NSColor(srgbRed: 0.975, green: 0.972, blue: 0.99, alpha: 1).cgColor,
                NSColor(srgbRed: 0.93, green: 0.92, blue: 0.99, alpha: 1).cgColor] as CFArray
    if let g = CGGradient(colorsSpace: cs, colors: base, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }
    // Iris and mint glows
    func glow(_ c: NSColor, _ p: CGPoint, _ r: CGFloat) {
        let cols = [c.withAlphaComponent(0.22).cgColor, c.withAlphaComponent(0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: cols, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: [])
        }
    }
    glow(NSColor(srgbRed: 0.43, green: 0.34, blue: 0.97, alpha: 1), CGPoint(x: 150, y: 260), 260)
    glow(NSColor(srgbRed: 0.08, green: 0.72, blue: 0.63, alpha: 1), CGPoint(x: 560, y: 120), 240)
    // Faint segmented ring motif behind the app icon
    ctx.setStrokeColor(NSColor(srgbRed: 0.43, green: 0.34, blue: 0.97, alpha: 0.10).cgColor)
    ctx.setLineWidth(10)
    ctx.setLineCap(.round)
    let c = CGPoint(x: 165, y: 205)
    for i in 0..<6 {
        let a0 = (90 - CGFloat(i) * 60 - 8) * .pi / 180, a1 = (90 - CGFloat(i + 1) * 60 + 8) * .pi / 180
        ctx.addArc(center: c, radius: 104, startAngle: a0, endAngle: a1, clockwise: true)
        ctx.strokePath()
    }
    // Arrow
    ctx.setStrokeColor(NSColor(srgbRed: 0.32, green: 0.30, blue: 0.42, alpha: 0.55).cgColor)
    ctx.setLineWidth(3)
    ctx.setLineDash(phase: 0, lengths: [2, 7])
    ctx.move(to: CGPoint(x: 262, y: 205))
    ctx.addCurve(to: CGPoint(x: 392, y: 205), control1: CGPoint(x: 300, y: 232), control2: CGPoint(x: 354, y: 232))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.setFillColor(NSColor(srgbRed: 0.32, green: 0.30, blue: 0.42, alpha: 0.55).cgColor)
    ctx.move(to: CGPoint(x: 404, y: 203)); ctx.addLine(to: CGPoint(x: 388, y: 214)); ctx.addLine(to: CGPoint(x: 390, y: 196)); ctx.fillPath()
    // Caption
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.18, green: 0.17, blue: 0.24, alpha: 0.85),
        .paragraphStyle: para,
    ]
    ("Drag \(appName) to Applications" as NSString).draw(in: CGRect(x: 0, y: 64, width: size.width, height: 24), withAttributes: attrs)
    let small: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.32, green: 0.30, blue: 0.42, alpha: 0.75),
        .paragraphStyle: para,
    ]
    ("Then drag any file and tap ⇧ for the conversion wheel." as NSString).draw(in: CGRect(x: 0, y: 42, width: size.width, height: 18), withAttributes: small)
    NSGraphicsContext.restoreGraphicsState()

    guard let img = ctx.makeImage(), let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else { fatalError("png") }
    return png
}

try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try render(scale: 1).write(to: outDir.appendingPathComponent("background.png"))
try render(scale: 2).write(to: outDir.appendingPathComponent("background@2x.png"))
print("background written")
