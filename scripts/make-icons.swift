#!/usr/bin/env swift
// Draws Halo's own icons, procedurally (no third-party or generated art):
//   - AppIcon.appiconset: near-black squircle with a radial wheel of charcoal
//     wedges; the top wedge is lit with the heat band, the hub is cobalt.
//   - MenuBarIcon.imageset: template glyph (black + alpha), a ring with one
//     filled wedge, 18×18 pt at @1x/@2x.
//   - docs/screens/app-icon.png (1024 master) and docs/redesign/icon-sizes.png
//     (preview strip of the small sizes and the menu bar glyph).
// Colours are the approved phase 2 tokens (docs/PLAN-PHASE2.md §2).
// Deterministic: same script, same pixels.
// Usage: swift scripts/make-icons.swift Sources/App/Resources/Assets.xcassets
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count > 1 else { fatalError("usage: make-icons.swift <Assets.xcassets>") }
let assets = URL(fileURLWithPath: args[1]).standardizedFileURL
// Assets.xcassets → Resources → App → Sources → repo root
let root = assets.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

// MARK: Tokens

func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
}
let ink1000 = hex(0x000000), ink950 = hex(0x0A0A0A), ink900 = hex(0x1F1F1F), ink800 = hex(0x2A2A2A)
let cobalt500 = hex(0x2766EE)
// band.heat, hot end → white
let heat: [UInt32] = [0xFF2600, 0xFF7D00, 0xFF9500, 0xFFCAA0, 0xFFF0D9, 0xFFFFFF]

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func bitmap(_ w: Int, _ h: Int) -> CGContext {
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("ctx") }
    ctx.interpolationQuality = .high
    return ctx
}

func png(_ ctx: CGContext) -> Data {
    guard let img = ctx.makeImage(), let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) else { fatalError("png") }
    return data
}

func rad(_ deg: CGFloat) -> CGFloat { deg * .pi / 180 }

/// Annular sector centred on `mid` degrees (0 = up, clockwise), `span` wide, with
/// a constant-width gap of `gap` on each side (parallel edges, like the wheel).
func wedgePath(center c: CGPoint, inner: CGFloat, outer: CGFloat, mid: CGFloat, span: CGFloat, gap: CGFloat) -> CGPath {
    // Convert "0 = up, clockwise" to CG math angles.
    let a0 = rad(90 - (mid - span / 2)), a1 = rad(90 - (mid + span / 2))
    // Shrink each side by the angle that subtends half the gap at each radius.
    let dOut = asin(min(1, gap / 2 / outer)), dIn = inner > 0 ? asin(min(1, gap / 2 / inner)) : 0
    let p = CGMutablePath()
    p.addArc(center: c, radius: outer, startAngle: a0 - dOut, endAngle: a1 + dOut, clockwise: true)
    if inner > 0 {
        p.addArc(center: c, radius: inner, startAngle: a1 + dIn, endAngle: a0 - dIn, clockwise: false)
    } else {
        p.addLine(to: c)
    }
    p.closeSubpath()
    return p
}

/// Hard-edged vertical bands across `rect`; each band fades slightly toward the
/// next colour from top to bottom (the band.heat recipe).
func drawBands(_ ctx: CGContext, rect: CGRect, colors: [UInt32]) {
    let n = colors.count
    let w = rect.width / CGFloat(n)
    for i in 0..<n {
        let r = CGRect(x: (rect.minX + CGFloat(i) * w).rounded(.down), y: rect.minY,
                       width: (w + 1).rounded(.up), height: rect.height)
        let top = hex(colors[i])
        let next = hex(colors[min(i + 1, n - 1)])
        let bottom = mix(top, next, 0.55)
        ctx.saveGState()
        ctx.clip(to: r)
        let g = CGGradient(colorsSpace: srgb, colors: [top, bottom] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
        ctx.restoreGState()
    }
}

func mix(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
    let x = a.converted(to: srgb, intent: .defaultIntent, options: nil)!.components!
    let y = b.converted(to: srgb, intent: .defaultIntent, options: nil)!.components!
    return CGColor(srgbRed: x[0] + (y[0] - x[0]) * t, green: x[1] + (y[1] - x[1]) * t, blue: x[2] + (y[2] - x[2]) * t, alpha: 1)
}

/// Big Sur+ continuous-corner squircle (superellipse, n = 5) inside `rect`.
func squircle(_ rect: CGRect) -> CGPath {
    let p = CGMutablePath()
    let n: CGFloat = 5, steps = 720
    let a = rect.width / 2, b = rect.height / 2, c = CGPoint(x: rect.midX, y: rect.midY)
    for i in 0..<steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = c.x + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2 / n)
        let y = c.y + b * (st < 0 ? -1 : 1) * pow(abs(st), 2 / n)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

// MARK: App icon

struct Tier {
    var wedges: Int       // segments in the wheel
    var bands: [UInt32]   // band.heat subset for the lit wedge
    var gap: CGFloat      // gap between wedges, fraction of icon size
    var hub: CGFloat      // hub radius (cobalt), fraction
    var hubRing: CGFloat  // black ring around the hub, fraction
    var shadow: Bool
}

func tier(for px: Int) -> Tier {
    switch px {
    case ..<24:  return Tier(wedges: 3, bands: [0xFF2600, 0xFF9500, 0xFFF0D9], gap: 0.07, hub: 0.07, hubRing: 0.05, shadow: false)
    case ..<48:  return Tier(wedges: 6, bands: [0xFF2600, 0xFF9500, 0xFFCAA0, 0xFFFFFF], gap: 0.045, hub: 0.075, hubRing: 0.04, shadow: false)
    case ..<200: return Tier(wedges: 8, bands: [0xFF2600, 0xFF7D00, 0xFF9500, 0xFFCAA0, 0xFFFFFF], gap: 0.028, hub: 0.068, hubRing: 0.032, shadow: false)
    default:     return Tier(wedges: 8, bands: heat, gap: 0.02, hub: 0.066, hubRing: 0.03, shadow: true)
    }
}

func appIcon(px: Int) -> CGContext {
    let s = CGFloat(px)
    let t = tier(for: px)
    let ctx = bitmap(px, px)
    // Apple grid: 824/1024 body centred on the canvas. Small sizes use more of
    // the canvas so the mark keeps its pixels (Apple's own small icons do too).
    let bodyFrac: CGFloat = px <= 16 ? 0.94 : (px <= 32 ? 0.88 : 824.0 / 1024)
    let bodySide = (s * bodyFrac).rounded()
    let off = ((s - bodySide) / 2).rounded(.down)
    // Shadow takes a few pixels below the body at large sizes; lift by 2/1024.
    let body = CGRect(x: off, y: off + (t.shadow ? s * 2 / 1024 : 0), width: bodySide, height: bodySide)
    let shape = squircle(body)

    if t.shadow {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 10 / 1024), blur: s * 22 / 1024, color: hex(0x000000, 0.45))
        ctx.addPath(shape); ctx.setFillColor(ink1000); ctx.fillPath()
        ctx.restoreGState()
    }

    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    // Surface: ink.950 at the top to ink.1000 at the bottom.
    let surface = CGGradient(colorsSpace: srgb, colors: [ink950, ink1000] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(surface, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

    let c = CGPoint(x: s / 2, y: body.midY)
    let wheelR = bodySide * (px <= 16 ? 0.47 : (px <= 32 ? 0.44 : 0.41))   // disc (ink.1000 rim)
    let segOuter = wheelR * 0.94
    let litOuter = wheelR * 1.06                        // the lit wedge steps out past the rim
    let segInner = (t.hub + t.hubRing) * s
    let gap = t.gap * s

    // Disc behind the wedges, a hair darker than the surface (the wheel's rim).
    ctx.setFillColor(ink1000)
    ctx.fillEllipse(in: CGRect(x: c.x - wheelR, y: c.y - wheelR, width: wheelR * 2, height: wheelR * 2))

    let span = 360 / CGFloat(t.wedges)
    for i in 1..<t.wedges {
        ctx.addPath(wedgePath(center: c, inner: segInner, outer: segOuter, mid: CGFloat(i) * span, span: span, gap: gap))
        ctx.setFillColor(ink800)
        ctx.fillPath()
    }

    // Lit wedge at 12 o'clock: heat band clipped to the wedge.
    let lit = wedgePath(center: c, inner: segInner, outer: litOuter, mid: 0, span: span, gap: gap)
    ctx.saveGState()
    ctx.addPath(lit); ctx.clip()
    let bb = lit.boundingBoxOfPath
    drawBands(ctx, rect: bb, colors: t.bands)
    ctx.restoreGState()

    // Hub: cobalt, the one accent.
    let hubR = t.hub * s
    ctx.setFillColor(cobalt500)
    ctx.fillEllipse(in: CGRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2))
    ctx.restoreGState()
    return ctx
}

let appSizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
let iconDir = assets.appendingPathComponent("AppIcon.appiconset")
for (pt, scale) in appSizes {
    let name = "AppIcon_\(pt)x\(pt)@\(scale)x.png"
    try png(appIcon(px: pt * scale)).write(to: iconDir.appendingPathComponent(name))
    images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(pt)x\(pt)", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconDir.appendingPathComponent("Contents.json"))
try png(appIcon(px: 1024)).write(to: root.appendingPathComponent("docs/screens/app-icon.png"))

// MARK: Menu bar template (18×18 pt; black + alpha only)

/// Draws the glyph in point space (18×18) into a context already scaled to px.
func menuGlyph(_ ctx: CGContext, scale: CGFloat, color: CGColor) {
    ctx.setFillColor(color)
    let c = CGPoint(x: 9, y: 9)
    // A ring of six pieces with a constant gap, like the wheel's rim; the piece at
    // 12 o'clock is filled all the way in toward the hub (the lit wedge).
    let outer: CGFloat = 8
    let ring: CGFloat = scale == 1 ? 1.6 : 1.45   // SF Symbols regular-ish stroke weight
    let gap: CGFloat = scale == 1 ? 1.6 : 1.4
    let span: CGFloat = 90
    for i in 0..<4 {
        let inner = i == 0 ? 1.6 : outer - ring
        ctx.addPath(wedgePath(center: c, inner: inner, outer: outer, mid: CGFloat(i) * span, span: span, gap: gap))
    }
    ctx.fillPath()
}

func menuIcon(scale: Int, color: CGColor = hex(0x000000)) -> CGContext {
    let px = 18 * scale
    let ctx = bitmap(px, px)
    ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    menuGlyph(ctx, scale: CGFloat(scale), color: color)
    return ctx
}

let menuDir = assets.appendingPathComponent("MenuBarIcon.imageset")
try? FileManager.default.removeItem(at: menuDir.appendingPathComponent("MenuBarIcon.pdf"))
var menuImages: [[String: String]] = []
// macOS image sets take @1x/@2x only (actool rejects a 3x child; no Mac has a
// 3x display), so the glyph ships as two pixel-tuned PNGs.
for scale in 1...2 {
    let name = "MenuBarIcon@\(scale)x.png"
    try png(menuIcon(scale: scale)).write(to: menuDir.appendingPathComponent(name))
    menuImages.append(["idiom": "mac", "scale": "\(scale)x", "filename": name])
}
let menuContents: [String: Any] = ["images": menuImages, "info": ["author": "xcode", "version": 1],
                                   "properties": ["template-rendering-intent": "template"]]
try JSONSerialization.data(withJSONObject: menuContents, options: [.prettyPrinted, .sortedKeys])
    .write(to: menuDir.appendingPathComponent("Contents.json"))

// MARK: Preview strip (docs/redesign/icon-sizes.png)
// Two rows (dark, light). Each: 16/32/64/128 at actual pixels; 16 and 32 again
// magnified 4× (nearest neighbour) to judge the pixels; then a menu bar strip
// with the template glyph at @1x and @2x, plus @1x magnified 8× and @2x.

do {
    let W = 1400, rowH = 300, H = rowH * 2
    let ctx = bitmap(W, H)
    func put(_ img: CGImage, _ x: CGFloat, _ y: CGFloat, _ k: CGFloat = 1) {
        ctx.interpolationQuality = k == 1 ? .default : .none
        ctx.draw(img, in: CGRect(x: x, y: y, width: CGFloat(img.width) * k, height: CGFloat(img.height) * k))
    }
    let icons = [16, 32, 64, 128].map { appIcon(px: $0).makeImage()! }
    for dark in [true, false] {
        let y0 = CGFloat(dark ? rowH : 0)
        ctx.setFillColor(dark ? ink1000 : hex(0xF2F2F2)); ctx.fill(CGRect(x: 0, y: y0, width: CGFloat(W), height: CGFloat(rowH)))
        let mid = y0 + CGFloat(rowH) / 2
        var x: CGFloat = 40
        for img in icons { put(img, x, (mid - CGFloat(img.height) / 2).rounded()); x += CGFloat(img.width) + 32 }
        x += 24
        for img in icons.prefix(2) { put(img, x, (mid - CGFloat(img.height) * 2).rounded(), 4); x += CGFloat(img.width) * 4 + 32 }
        x += 24
        let tint = dark ? hex(0xFFFFFF, 0.92) : hex(0x000000, 0.85)
        let bar = CGRect(x: x, y: mid + 60, width: CGFloat(W) - x - 40, height: 24)
        ctx.setFillColor(dark ? hex(0x262626) : hex(0xE6E6E6)); ctx.fill(bar)
        let g1 = menuIcon(scale: 1, color: tint).makeImage()!
        let g2 = menuIcon(scale: 2, color: tint).makeImage()!
        put(g1, bar.minX + 16, bar.minY + 3)
        put(g2, bar.minX + 56, bar.midY - 18)
        put(g1, bar.minX + 16, mid - 100, 8)
        put(g2, bar.minX + 200, mid - 100 + 72 - 18)
    }
    let dir = root.appendingPathComponent("docs/redesign")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try png(ctx).write(to: dir.appendingPathComponent("icon-sizes.png"))
}

print("icons written")
