#!/usr/bin/env swift
// Draws the DMG window background (our own art, procedural): a near-black
// field in the phase 2 palette, an arrow from the app to Applications drawn as
// the heat band (the one spotlight on this surface), and a caption.
// Finder draws icon labels in the system text colour (black in light mode,
// white in dark mode), so each label sits on a mid-grey pill (#777777) where
// both read at ≥ 4.5:1.
// Usage: swift make-background.swift <out-dir> <app name>
import AppKit

let args = CommandLine.arguments
guard args.count > 2 else { fatalError("usage: make-background.swift <out-dir> <app name>") }
let outDir = URL(fileURLWithPath: args[1])
let appName = args[2]
let size = CGSize(width: 660, height: 400)
// Icons are placed by make-dmg.sh at Finder (165,195) and (495,195), 112 pt,
// 12 pt labels: label centre ≈ y 139 in this bottom-left space.
let iconY: CGFloat = 205
let labelBand = CGRect(x: 0, y: 122, width: 660, height: 34)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let heat: [UInt32] = [0xFF2600, 0xFF7D00, 0xFF9500, 0xFFCAA0, 0xFFF0D9, 0xFFFFFF]

func render(scale: CGFloat) -> Data {
    let px = CGSize(width: size.width * scale, height: size.height * scale)
    let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(px.width), height: Int(px.height), bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("ctx") }
    ctx.scaleBy(x: scale, y: scale)
    // Field: ink.950 → ink.1000
    let g = CGGradient(colorsSpace: cs, colors: [hex(0x0A0A0A), hex(0x000000)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: size.height), end: .zero, options: [])
    // Label plates (radius.pill), mid grey so Finder's black or white label text both read.
    for x in [165.0, 495.0] as [CGFloat] {
        let plate = CGRect(x: x - 76, y: labelBand.minY + 2, width: 152, height: labelBand.height - 4)
        ctx.addPath(CGPath(roundedRect: plate, cornerWidth: plate.height / 2, cornerHeight: plate.height / 2, transform: nil))
        ctx.setFillColor(hex(0x777777)); ctx.fillPath()
    }
    // Arrow: six hard-edged dashes in band.heat order, then the head in white.
    let x0: CGFloat = 268, x1: CGFloat = 378, dashGap: CGFloat = 4
    let dw = (x1 - x0 - dashGap * 5) / 6
    for (i, c) in heat.enumerated() {
        ctx.setFillColor(hex(c))
        ctx.fill(CGRect(x: x0 + CGFloat(i) * (dw + dashGap), y: iconY - 3, width: dw, height: 6))
    }
    ctx.setFillColor(hex(0xFFFFFF))
    ctx.move(to: CGPoint(x: x1 + 18, y: iconY)); ctx.addLine(to: CGPoint(x: x1 + 2, y: iconY + 10)); ctx.addLine(to: CGPoint(x: x1 + 2, y: iconY - 10))
    ctx.fillPath()
    // Caption
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: para,
    ]
    ("Drag \(appName) to Applications" as NSString).draw(in: CGRect(x: 0, y: 64, width: size.width, height: 24), withAttributes: attrs)
    let small: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0x9A / 255, green: 0x9A / 255, blue: 0x9A / 255, alpha: 1),
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
