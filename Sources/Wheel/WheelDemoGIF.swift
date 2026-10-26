import AppKit
import AnyfmtCore
import RadialMenu

/// Renders the README's wheel GIF from the real wheel renderer: the convert
/// wheel for a photo with the pointer sweeping its segments, then the tools and
/// actions wheels, each with a caption. `anyfmt --render-demo-gif <file.gif>`.
@MainActor
public enum WheelDemoGIF {
    public static func render(to output: URL, scale: CGFloat = 1) async throws {
        let frames = FileManager.default.temporaryDirectory.appendingPathComponent("wheel-demo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: frames) }

        // The live capability table: exactly what a JPG offers in this build.
        let sample = WheelGalleryData.samples[0]
        let input = WheelInput(urls: [URL(fileURLWithPath: "/Demo/IMG_2041.jpg")])
        let hubBase = WheelGalleryData.hub(for: sample)
        let provider = WheelContentProvider.live()
        let cloud = CloudSegments()
        func items(_ kind: WheelKind) -> [RadialItem] {
            WheelContentProvider.items(for: provider.resolve(input, kind: kind, preferences: .standard).entries, cloud: cloud)
        }
        let scenes: [(WheelKind, String)] = [
            (.convert, String(localized: "Drag a file, press ⇧ Shift: every format it can become", comment: "Demo GIF caption")),
            (.tools, String(localized: "Press ⌘ Command: tools for this file", comment: "Demo GIF caption")),
            (.actions, String(localized: "Press ⌃ Control: AirDrop, Float, Copy, Move, Path, Terminal", comment: "Demo GIF caption")),
        ]
        var index = 0
        func write(_ image: NSImage, caption: String, repeat count: Int) throws {
            let framed = compose(image, caption: caption, scale: scale)
            guard let tiff = framed.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return }
            for _ in 0..<count {
                try png.write(to: frames.appendingPathComponent(String(format: "f%04d.png", index)))
                index += 1
            }
        }
        for (kind, caption) in scenes {
            let list = items(kind)
            var hub = hubBase
            func frame(_ hovered: Int?) -> NSImage {
                if let hovered, list.indices.contains(hovered) { hub.idleText = list[hovered].title } else { hub = hubBase }
                return RadialMenuSnapshot.render(items: list, configuration: WheelTheme.configuration, style: WheelTheme.style,
                                                 appearance: .light, hoveredIndex: hovered, hub: hub,
                                                 strings: WheelTheme.strings, backdrop: .none, cropToWheel: true, scale: 2)
            }
            try write(frame(nil), caption: caption, repeat: 6)
            let sweep = Array(list.indices.prefix(min(list.count, 8)))
            for i in sweep { try write(frame(i), caption: caption, repeat: 3) }
            try write(frame(sweep.last ?? 0), caption: caption, repeat: 8)
        }
        guard let ffmpeg = EngineLocator.shared.ffmpeg else {
            throw ConversionError.engineMissing("ffmpeg", detail: "needed to assemble the GIF")
        }
        try? FileManager.default.removeItem(at: output)
        _ = try await ProcessRunner.run(ffmpeg, [
            "-hide_banner", "-loglevel", "error", "-framerate", "10", "-i", frames.appendingPathComponent("f%04d.png").path,
            "-filter_complex", "[0:v]scale=560:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a",
            "-loop", "0", output.path,
        ])
    }

    /// Wheel centred on black with a display-type caption underneath.
    static func compose(_ wheel: NSImage, caption: String, scale: CGFloat) -> NSImage {
        let canvas = NSSize(width: 640, height: 600)
        let image = NSImage(size: canvas)
        image.lockFocus()
        // The phase 2 hero: black, the wheel as the only colour (D-042).
        NSColor(hex: DesignTokens.Primitive.ink1000).setFill()
        NSRect(origin: .zero, size: canvas).fill()
        let side = min(canvas.width - 80, canvas.height - 130)
        let w = wheel.size
        let s = min(side / w.width, side / w.height)
        let rect = NSRect(x: (canvas.width - w.width * s) / 2, y: 100, width: w.width * s, height: w.height * s)
        wheel.draw(in: rect)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: AnyfmtFonts.display(DesignTokens.Typeface.Size.displayM),
            .foregroundColor: NSColor(hex: DesignTokens.Primitive.paper0),
            .kern: DesignTokens.Typeface.Size.displayM * DesignTokens.Typeface.displayTracking,
            .paragraphStyle: para,
        ]
        (caption as NSString).draw(in: NSRect(x: 30, y: 36, width: canvas.width - 60, height: 50), withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}
