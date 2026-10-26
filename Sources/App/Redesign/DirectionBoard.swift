import AppKit
import AnyfmtCore
import SwiftUI

/// The phase 2 art-direction board (PLAN-PHASE2 §2): the wheel, options panel,
/// progress cards and the first onboarding page drawn with the new tokens, plus
/// the palette. It exists to approve the direction before the app is migrated,
/// so the pieces are faithful mock-ups, not the live components.
/// `anyfmt --render-direction <dir>` writes the PNGs.
@MainActor
enum DirectionBoard {
    typealias T = DesignTokens

    static func render(into dir: URL) throws -> [URL] {
        AnyfmtFonts.registerBundled()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pieces: [(String, NSAppearance.Name, AnyView)] = [
            ("1-wheel-locked-presets-dark", .darkAqua, AnyView(WheelMock(state: .locked))),
            ("2-wheel-hover-tune-dark", .darkAqua, AnyView(WheelMock(state: .tuneLip))),
            ("3-options-panel-dark", .darkAqua, AnyView(OptionsPanelMock())),
            ("4-options-panel-light", .aqua, AnyView(OptionsPanelMock())),
            ("5-progress-cards-dark", .darkAqua, AnyView(ProgressMock())),
            ("6-onboarding-welcome-dark", .darkAqua, AnyView(OnboardingMock())),
            ("7-palette", .darkAqua, AnyView(PaletteSheet())),
        ]
        var out: [URL] = []
        for (name, appearance, view) in pieces {
            let url = dir.appendingPathComponent("\(name).png")
            try snapshot(view, appearance: appearance).write(to: url)
            out.append(url)
        }
        return out
    }

    private static func snapshot(_ view: AnyView, appearance: NSAppearance.Name) throws -> Data {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, appearance == .darkAqua ? .dark : .light))
        host.appearance = NSAppearance(named: appearance)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            throw CocoaError(.fileWriteUnknown)
        }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}

// MARK: - Wheel

private struct WheelMock: View {
    enum State { case locked, tuneLip }
    let state: State
    typealias T = DesignTokens

    private let labels = ["GIF", "MP4", "WEBM", "MOV", "M4V", "MKV", "MP3", "PNG"]
    private let inner: CGFloat = 58, outer: CGFloat = 168, gap: CGFloat = 2.5

    var body: some View {
        ZStack {
            Color(hex: T.Primitive.ink1000)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
                // Disc
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - outer - 10, y: c.y - outer - 10, width: (outer + 10) * 2, height: (outer + 10) * 2)),
                         with: .color(Color(hex: T.Primitive.ink950)))
                let step = 360.0 / Double(labels.count)
                for (i, label) in labels.enumerated() {
                    let start = -90 - step / 2 + Double(i) * step + Double(gap) / 2
                    let end = start + step - Double(gap)
                    let hot = i == 0
                    let reach = hot ? outer + 10 : outer
                    let wedge = wedgePath(c, inner, reach, start, end)
                    if hot {
                        ctx.drawLayer { layer in
                            layer.clip(to: wedge)
                            let rect = wedge.boundingRect
                            let bands = T.Band.heat
                            let w = rect.width / CGFloat(bands.count)
                            for (b, color) in bands.enumerated() {
                                let r = CGRect(x: rect.minX + CGFloat(b) * w, y: rect.minY, width: w + 0.5, height: rect.height)
                                layer.fill(Path(r), with: .linearGradient(
                                    Gradient(colors: [Color(hex: color), Color(hex: bands[min(b + 1, bands.count - 1)])]),
                                    startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.maxY)))
                            }
                        }
                        if state == .locked {
                            ctx.stroke(wedge, with: .color(Color(hex: T.Primitive.cobalt500)), lineWidth: 3)
                        } else {
                            // Tune lip: the outer edge of the hovered segment.
                            let lip = wedgePath(c, reach - 12, reach, start, end)
                            ctx.fill(lip, with: .color(Color(hex: T.Primitive.cobalt500)))
                        }
                    } else {
                        ctx.fill(wedge, with: .color(Color(hex: T.Primitive.ink800)))
                    }
                    let mid = (start + end) / 2 * .pi / 180
                    let r = (inner + reach) / 2 + (hot ? 4 : 0)
                    let p = CGPoint(x: c.x + cos(mid) * r, y: c.y + sin(mid) * r)
                    let size: CGFloat = hot ? 30 : 22
                    ctx.draw(Text(label).font(.anyfmtDisplay(size)).tracking(size * T.Typeface.displayTracking)
                        .foregroundColor(Color(hex: hot ? T.Primitive.ink1000 : T.Primitive.paper0)), at: p)
                }
                // Hub
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - 48, y: c.y - 48, width: 96, height: 96)), with: .color(Color(hex: T.Primitive.ink900)))
                ctx.draw(Text("clip.mp4").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: T.Primitive.ink400)),
                         at: CGPoint(x: c.x, y: c.y - 10))
                ctx.draw(Text("34 MB").font(.anyfmtDisplay(18)).foregroundColor(Color(hex: T.Primitive.paper0)),
                         at: CGPoint(x: c.x, y: c.y + 10))
            }
            VStack {
                Spacer()
                pill(state == .locked ? "GIF · LOCKED" : "GIF · OPTIONS", lock: state == .locked)
                    .padding(.bottom, 26)
            }
            if state == .locked {
                // Preset chips outside the rim, above the locked segment.
                HStack(spacing: 8) {
                    chip("SMALL · 10 FPS · 480 W", hot: false)
                    chip("SMOOTH · 24 FPS · 720 W", hot: true)
                    chip("LAST USED", hot: false)
                }
                .offset(y: -224)
            }
        }
        .frame(width: 600, height: 560)
    }

    private func pill(_ text: String, lock: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: lock ? "lock.fill" : "slider.horizontal.3").font(.system(size: 11, weight: .bold))
            Text(text).font(.anyfmtDisplay(13, black: false)).tracking(0.4)
        }
        .foregroundStyle(Color(hex: T.Semantic.onAccentPrimary))
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: T.Primitive.cobalt500)))
    }

    private func chip(_ text: String, hot: Bool) -> some View {
        Text(text).font(.anyfmtDisplay(11, black: false)).tracking(0.3)
            .foregroundStyle(Color(hex: hot ? T.Primitive.paper0 : T.Primitive.paper0))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color(hex: hot ? T.Primitive.cobalt500 : T.Primitive.ink800)))
            .overlay(Capsule().stroke(Color(hex: T.Primitive.ink700), lineWidth: hot ? 0 : 1))
    }

    private func wedgePath(_ c: CGPoint, _ r0: CGFloat, _ r1: CGFloat, _ a0: Double, _ a1: Double) -> Path {
        var p = Path()
        p.addArc(center: c, radius: r1, startAngle: .degrees(a0), endAngle: .degrees(a1), clockwise: false)
        p.addArc(center: c, radius: r0, startAngle: .degrees(a1), endAngle: .degrees(a0), clockwise: true)
        p.closeSubpath()
        return p
    }
}

// MARK: - Options panel

private struct OptionsPanelMock: View {
    typealias T = DesignTokens

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text("GIF").font(.anyfmtDisplay(T.Typeface.Size.displayXL)).displayTracking(T.Typeface.Size.displayXL)
                    .foregroundStyle(Color.token(T.Semantic.textPrimary))
                Spacer()
                Text("clip.mp4 → GIF").font(.system(size: T.Typeface.Size.body, weight: .medium))
                    .foregroundStyle(Color.token(T.Semantic.textSecondary))
            }
            HStack(spacing: 10) {
                stat("2.4 MB", "−62 % vs 6.3 MB", hero: true)
                stat("4.8 s", "Duration")
                stat("116", "Frames")
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 14) {
                row("Width", ["320", "480", "720", "Keep"], selected: 2)
                row("Frame rate", ["10", "15", "24", "Keep"], selected: 2)
                row("Loop", ["Forever", "Once"], selected: 0)
                row("Colours", ["256", "128", "64"], selected: 0)
                row("Dither", ["On", "Off"], selected: 0)
            }
            HStack {
                Label("Remember as default for GIF", systemImage: "square")
                    .font(.system(size: T.Typeface.Size.body))
                    .foregroundStyle(Color.token(T.Semantic.textSecondary))
                Spacer()
                pillButton("Save preset", fill: T.Primitive.orange500, text: T.Semantic.onAccentSecondary)
                pillButton("Convert", fill: T.Primitive.cobalt500, text: T.Semantic.onAccentPrimary)
            }
        }
        .padding(28)
        .frame(width: 560)
        .background(Color.token(T.Semantic.windowBackground))
    }

    private func stat(_ value: String, _ caption: String, hero: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.anyfmtDisplay(T.Typeface.Size.displayL)).displayTracking(T.Typeface.Size.displayL)
                .foregroundStyle(hero ? Color(hex: T.Primitive.ink1000) : Color.token(T.Semantic.textPrimary))
            Text(caption).font(.system(size: T.Typeface.Size.label, weight: .semibold))
                .foregroundStyle(hero ? Color(hex: T.Primitive.ink1000) : Color.token(T.Semantic.textSecondary))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if hero {
                BandGradient(bands: Array(T.Band.heat.dropLast(2)), flat: T.Band.heatFlat)
                    .clipShape(RoundedRectangle(cornerRadius: T.Shape.tile))
            } else {
                RoundedRectangle(cornerRadius: T.Shape.tile).fill(Color.token(T.Semantic.tile))
            }
        }
    }

    private func row(_ label: String, _ choices: [String], selected: Int) -> some View {
        GridRow {
            Text(label).font(.system(size: T.Typeface.Size.body, weight: .medium))
                .foregroundStyle(Color.token(T.Semantic.textSecondary))
            HStack(spacing: 4) {
                ForEach(Array(choices.enumerated()), id: \.offset) { i, c in
                    Text(c).font(.system(size: T.Typeface.Size.label, weight: .semibold))
                        .foregroundStyle(i == selected ? Color(hex: T.Semantic.onAccentPrimary) : Color.token(T.Semantic.textPrimary))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(i == selected ? Color(hex: T.Primitive.cobalt500) : Color.token(T.Semantic.tile)))
                }
            }
        }
    }

    private func pillButton(_ title: String, fill: Int, text: Int) -> some View {
        Text(title).font(.system(size: T.Typeface.Size.body, weight: .bold))
            .foregroundStyle(Color(hex: text))
            .padding(.horizontal, 18).padding(.vertical, 9)
            .background(Capsule().fill(Color(hex: fill)))
    }
}

// MARK: - Progress cards

private struct ProgressMock: View {
    typealias T = DesignTokens

    var body: some View {
        VStack(spacing: 10) {
            card(big: "−62%", title: "clip.gif", detail: "2.4 MB · from 6.3 MB", progress: 1, done: true)
            card(big: "48%", title: "interview.mov → MP4", detail: "1080p · about 20 s left", progress: 0.48, done: false)
        }
        .padding(20)
        .background(Color(hex: T.Primitive.ink1000))
    }

    private func card(big: String, title: String, detail: String, progress: Double, done: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(big).font(.anyfmtDisplay(T.Typeface.Size.displayL)).displayTracking(T.Typeface.Size.displayL)
                .foregroundStyle(Color(hex: T.Primitive.paper0))
                .frame(width: 128, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: T.Primitive.cobalt400)) }
                    Text(title).font(.system(size: T.Typeface.Size.body, weight: .semibold)).foregroundStyle(Color(hex: T.Primitive.paper0))
                }
                Text(done ? "Done · \(detail)" : detail).font(.system(size: T.Typeface.Size.label))
                    .foregroundStyle(Color(hex: T.Primitive.ink400))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: T.Primitive.ink800))
                        BandGradient(bands: T.Band.cobalt, flat: T.Band.cobaltFlat)
                            .frame(width: g.size.width * progress).clipShape(Capsule())
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(RoundedRectangle(cornerRadius: T.Shape.tile).fill(Color(hex: T.Primitive.ink900)))
    }
}

// MARK: - Onboarding

private struct OnboardingMock: View {
    typealias T = DesignTokens

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: -14) {
                    ForEach(["DRAG.", "PRESS.", "DROP."], id: \.self) { word in
                        Text(word).font(.anyfmtDisplay(T.Typeface.Size.displayXL)).displayTracking(T.Typeface.Size.displayXL)
                            .foregroundStyle(Color(hex: T.Primitive.paper0))
                            .fixedSize()
                    }
                }
                Text("Drag the photo and press ⇧ Shift while you hold it. Tap or hold, either works.")
                    .font(.system(size: T.Typeface.Size.title))
                    .foregroundStyle(Color(hex: T.Primitive.ink400))
                    .frame(maxWidth: 360, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                RoundedRectangle(cornerRadius: T.Shape.tile).fill(Color(hex: T.Primitive.ink900))
                    .overlay {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6).fill(Color(hex: T.Primitive.ink700)).frame(width: 72, height: 72)
                            Text("Sample.heic").font(.system(size: T.Typeface.Size.label, weight: .semibold))
                                .foregroundStyle(Color(hex: T.Primitive.paper0))
                        }
                    }
                    .frame(height: 150)
                Spacer(minLength: 0)
                HStack {
                    Text("Skip").font(.system(size: T.Typeface.Size.body, weight: .medium)).foregroundStyle(Color(hex: T.Primitive.ink400))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<6) { i in
                            Capsule().fill(Color(hex: i == 0 ? T.Primitive.paper0 : T.Primitive.ink700)).frame(width: i == 0 ? 18 : 6, height: 6)
                        }
                    }
                    Spacer()
                    Text("Continue").font(.system(size: T.Typeface.Size.body, weight: .bold))
                        .foregroundStyle(Color(hex: T.Semantic.onAccentPrimary))
                        .padding(.horizontal, 20).padding(.vertical, 9)
                        .background(Capsule().fill(Color(hex: T.Primitive.cobalt500)))
                }
            }
            .padding(36)
            .frame(width: 470, height: 540)
            BandGradient(bands: T.Band.heat, flat: T.Band.heatFlat)
                .frame(width: 250, height: 540)
        }
        .background(Color(hex: T.Primitive.ink1000))
    }
}

// MARK: - Palette

private struct PaletteSheet: View {
    typealias T = DesignTokens
    private let swatches: [(String, Int, String)] = [
        ("ink.1000", T.Primitive.ink1000, "page black"), ("ink.950", T.Primitive.ink950, "window"),
        ("ink.900", T.Primitive.ink900, "tiles"), ("ink.800", T.Primitive.ink800, "segments"),
        ("ink.500", T.Primitive.ink500, "large dim type"), ("ink.400", T.Primitive.ink400, "secondary 5.9:1"),
        ("paper.0", T.Primitive.paper0, "text on dark"), ("cobalt.500", T.Primitive.cobalt500, "primary · white 5.0:1"),
        ("cobalt.400", T.Primitive.cobalt400, "cobalt text 6.3:1"), ("cobalt.700", T.Primitive.cobalt700, "light text 6.6:1"),
        ("orange.500", T.Primitive.orange500, "secondary · black 9.6:1"), ("orange.600", T.Primitive.orange600, "band"),
        ("flame.500", T.Primitive.flame500, "errors · black 6.3:1"), ("flame.600", T.Primitive.flame600, "band hot end"),
        ("ember.700", T.Primitive.ember700, "deep band"), ("peach.200", T.Primitive.peach200, "fade"),
        ("cream.100", T.Primitive.cream100, "last band"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PALETTE").font(.anyfmtDisplay(T.Typeface.Size.displayL)).displayTracking(T.Typeface.Size.displayL)
                .foregroundStyle(Color(hex: T.Primitive.paper0))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(150), spacing: 10), count: 6), alignment: .leading, spacing: 10) {
                ForEach(swatches, id: \.0) { name, hex, use in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: T.Shape.tile).fill(Color(hex: hex)).frame(height: 64)
                            .overlay(RoundedRectangle(cornerRadius: T.Shape.tile).stroke(Color(hex: T.Primitive.ink700), lineWidth: 1))
                        Text(name).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: T.Primitive.paper0))
                        Text(String(format: "#%06X · %@", hex, use)).font(.system(size: 10.5))
                            .foregroundStyle(Color(hex: T.Primitive.ink400))
                    }
                }
            }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    BandGradient(bands: T.Band.heat).frame(width: 470, height: 80).clipShape(RoundedRectangle(cornerRadius: T.Shape.tile))
                    Text("band.heat").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: T.Primitive.paper0))
                }
                VStack(alignment: .leading, spacing: 4) {
                    BandGradient(bands: T.Band.cobalt).frame(width: 470, height: 80).clipShape(RoundedRectangle(cornerRadius: T.Shape.tile))
                    Text("band.cobalt").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: T.Primitive.paper0))
                }
            }
            Text("Aa INTER DISPLAY BLACK · body: SF Pro").font(.anyfmtDisplay(T.Typeface.Size.displayM))
                .foregroundStyle(Color(hex: T.Primitive.paper0))
        }
        .padding(28)
        .background(Color(hex: T.Primitive.ink1000))
    }
}
