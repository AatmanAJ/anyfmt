import AppKit
import HaloCore
import SwiftUI

/// Renders progress cards in every state offscreen into PNGs (docs/screens),
/// so design regressions are visible in review. Built from real
/// `ProgressCardState` builders over fake records, so it exercises the same
/// code as the live windows. `--render-gallery` can call `render(into:)` too.
@MainActor
enum ProgressCardGallery {
    struct Scene {
        let name: String
        let scheme: ColorScheme
        var overrides = ProgressAppearanceOverrides()
        let cards: [(ProgressCardModel.Subject, ProgressCardState)]
        var spacing: CGFloat = ProgressTheme.Metrics.stackSpacing
        /// Indices of cards drawn as hovered / just after "Copy details".
        var hovered: Set<Int> = []
        var copied: Set<Int> = []
    }

    @discardableResult
    static func render(into directory: URL, scale: CGFloat = 2) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written: [URL] = []
        for scene in scenes() {
            let url = directory.appendingPathComponent("progress-\(scene.name).png")
            try png(for: scene, scale: scale).write(to: url, options: .atomic)
            written.append(url)
        }
        return written
    }

    static func png(for scene: Scene, scale: CGFloat) throws -> Data {
        let view = SceneView(scene: scene)
            .environment(\.colorScheme, scene.scheme)
            .environment(\.progressCardSurface, .translucent)
            .environment(\.progressAppearanceOverrides, scene.overrides)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cg = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }

    // MARK: Scenes

    static func scenes() -> [Scene] {
        let overview: [(ProgressCardModel.Subject, ProgressCardState)] = [
            (.job(UUID()), Fixtures.running),
            (.batch(UUID()), Fixtures.batchRunning),
            (.job(UUID()), Fixtures.success),
            (.job(UUID()), Fixtures.failure),
        ]
        let stack: [(ProgressCardModel.Subject, ProgressCardState)] = [
            (.job(UUID()), Fixtures.running),
            (.job(UUID()), Fixtures.success),
            (.batch(UUID()), Fixtures.batchRunning),
            (.job(UUID()), Fixtures.queued),
            (.job(UUID()), Fixtures.audio),
            (.summary, ProgressCardState.summary(hidden: [Fixtures.running, Fixtures.queued, Fixtures.audio])),
        ]
        return [
            Scene(name: "running", scheme: .light, cards: [(.job(UUID()), Fixtures.running)]),
            Scene(name: "success", scheme: .light, cards: [(.job(UUID()), Fixtures.success)]),
            Scene(name: "failure", scheme: .light, cards: [(.job(UUID()), Fixtures.failure)]),
            Scene(name: "batch", scheme: .light, cards: [(.batch(UUID()), Fixtures.batchRunning), (.batch(UUID()), Fixtures.batchPartial)]),
            Scene(name: "states-light", scheme: .light, cards: overview, spacing: 20),
            Scene(name: "states-dark", scheme: .dark, cards: overview, spacing: 20),
            Scene(name: "stack-light", scheme: .light, cards: stack),
            Scene(name: "stack-dark", scheme: .dark, cards: stack),
            Scene(name: "high-contrast", scheme: .light, overrides: ProgressAppearanceOverrides(increasedContrast: true),
                  cards: [(.job(UUID()), Fixtures.running), (.job(UUID()), Fixtures.failure)], spacing: 20),
            Scene(name: "reduce-transparency-dark", scheme: .dark,
                  overrides: ProgressAppearanceOverrides(increasedContrast: true, reduceTransparency: true),
                  cards: [(.job(UUID()), Fixtures.running), (.job(UUID()), Fixtures.success)], spacing: 20),
            Scene(name: "interactions", scheme: .light,
                  cards: [(.job(UUID()), Fixtures.success), (.job(UUID()), Fixtures.failure)], spacing: 20,
                  hovered: [0], copied: [1]),
        ]
    }

    private struct SceneView: View {
        let scene: Scene
        var body: some View {
            VStack(spacing: scene.spacing) {
                ForEach(Array(scene.cards.enumerated()), id: \.offset) { i, item in
                    let model = Self.model(item.0, item.1, hovered: scene.hovered.contains(i), copied: scene.copied.contains(i))
                    if item.0 == .summary { ProgressSummaryCard(model: model) } else { ProgressCard(model: model) }
                }
            }
            .padding(36)
            .background(Backdrop(scheme: scene.scheme))
        }

        static func model(_ subject: ProgressCardModel.Subject, _ state: ProgressCardState,
                          hovered: Bool, copied: Bool) -> ProgressCardModel {
            let m = ProgressCardModel(subject: subject, state: state)
            m.isShown = true
            m.isHovered = hovered
            m.didCopyDetails = copied
            m.icons = Fixtures.icons(for: state)
            return m
        }
    }

    /// Our own soft desktop-ish backdrop (an iris → mint wash), so translucency reads.
    /// A plain vertical gradient keeps the PNGs small (rows compress to almost nothing).
    private struct Backdrop: View {
        let scheme: ColorScheme
        var body: some View {
            let iris = ProgressTheme.accent(scheme), mint = ProgressTheme.color(DesignTokens.Palette.mint, scheme)
            let base = scheme == .dark ? Color(.sRGB, red: 0.08, green: 0.08, blue: 0.11) : Color(.sRGB, red: 0.95, green: 0.95, blue: 0.97)
            ZStack {
                base
                LinearGradient(colors: [iris.opacity(scheme == .dark ? 0.32 : 0.20), mint.opacity(scheme == .dark ? 0.22 : 0.22)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    // MARK: Fake jobs

    enum Fixtures {
        static let dir = URL(fileURLWithPath: "/Users/Shared/Example", isDirectory: true)
        static func file(_ name: String) -> URL { dir.appendingPathComponent(name) }

        static var running: ProgressCardState {
            ProgressCardState.single(JobRecord(
                title: "IMG_2041.heic → JPG", activityTitle: L("Converting to \("JPG")"),
                inputs: [file("IMG_2041.heic")], state: .running, fraction: 0.42, eta: 12))
        }

        static var queued: ProgressCardState {
            ProgressCardState.single(JobRecord(
                title: "Interview.mov → MP4", activityTitle: L("Converting to \("MP4")"),
                inputs: [file("Interview.mov")], resourceClass: .videoToolbox, state: .queued))
        }

        static var audio: ProgressCardState {
            ProgressCardState.single(JobRecord(
                title: "Podcast episode 12.wav → MP3", activityTitle: L("Converting to \("MP3")"),
                inputs: [file("Podcast episode 12.wav")], state: .running, fraction: 0.77, eta: 134))
        }

        static var success: ProgressCardState {
            let out = file("Product demo.mp4")
            return ProgressCardState.single(JobRecord(
                title: "Product demo.mov → MP4", activityTitle: L("Converting to \("MP4")"), completedTitle: L("Converted to \("MP4")"),
                inputs: [file("Product demo.mov")], state: .succeeded([out]), fraction: 1, outputs: [out]))
        }

        static var failure: ProgressCardState {
            let failure = JobFailure.from(ConversionError.engineFailed("ffmpeg", status: 1, detail: "moov atom not found"))
            return ProgressCardState.single(JobRecord(
                title: "Screen recording.mov → MP4", activityTitle: L("Converting to \("MP4")"),
                failedTitle: L("Couldn’t convert to \("MP4")"), inputs: [file("Screen recording.mov")],
                state: .failed(message: failure.message, details: failure.details),
                errorMessage: failure.message, errorDetails: failure.details))
        }

        static var batchRunning: ProgressCardState {
            let names = (1...12).map { String(format: "Trip %02d.heic", $0) }
            let records: [JobRecord] = names.enumerated().map { i, n in
                let state: JobState = i < 3 ? .succeeded([file(n)]) : (i < 5 ? .running : .queued)
                return JobRecord(title: n, inputs: [file(n)], state: state, fraction: i < 3 ? 1 : (i < 5 ? 0.5 : 0))
            }
            let batch = JobBatch(title: "12 files → JPG", activityTitle: L("Converting \(12) files to \("JPG")"),
                                 note: L("\(2) already \("JPG")"), jobIDs: records.map(\.id), fileCount: 14, eta: 31)
            return ProgressCardState.batch(batch, records: records)
        }

        static var batchPartial: ProgressCardState {
            let names = ["Scan 1.pdf", "Scan 2.pdf", "Scan 3.pdf", "Scan 4.pdf"]
            let message = ConversionError.unreadable(file("Scan 3.pdf"), detail: "bad xref").errorDescription ?? ""
            let records: [JobRecord] = names.enumerated().map { i, n in
                i == 2 ? JobRecord(title: n, inputs: [file(n)], state: .failed(message: message, details: "unreadable"),
                                   errorMessage: message, errorDetails: "unreadable")
                    : JobRecord(title: n, inputs: [file(n)], state: .succeeded([file(n)]), fraction: 1, outputs: [file(n)])
            }
            let batch = JobBatch(title: "4 files → DOCX", jobIDs: records.map(\.id))
            return ProgressCardState.batch(batch, records: records)
        }

        /// Finder icons by type, and a drawn "photo" thumbnail for images.
        static func icons(for state: ProgressCardState) -> [ProgressIconImage] {
            state.iconURLs.map { url in
                if Formats.detect(url).map(Formats.kind) == .image { return ProgressIconImage(image: photo, isThumbnail: true) }
                let type = Formats.detect(url).flatMap { Formats.format($0)?.utType } ?? .data
                return ProgressIconImage(image: NSWorkspace.shared.icon(for: type), isThumbnail: false)
            }
        }

        /// A tiny landscape (sky, sun, hills) standing in for a photo thumbnail.
        static let photo: NSImage = NSImage(size: NSSize(width: 48, height: 36), flipped: false) { rect in
            let sky = NSGradient(colors: [NSColor(srgbRed: 0.98, green: 0.78, blue: 0.55, alpha: 1),
                                          NSColor(srgbRed: 0.55, green: 0.62, blue: 0.95, alpha: 1)])
            sky?.draw(in: rect, angle: 90)
            NSColor(srgbRed: 1, green: 0.93, blue: 0.7, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 30, y: 18, width: 9, height: 9)).fill()
            NSColor(srgbRed: 0.26, green: 0.45, blue: 0.42, alpha: 1).setFill()
            let hills = NSBezierPath()
            hills.move(to: .zero)
            hills.curve(to: NSPoint(x: 48, y: 8), controlPoint1: NSPoint(x: 14, y: 22), controlPoint2: NSPoint(x: 30, y: 2))
            hills.line(to: NSPoint(x: 48, y: 0))
            hills.close()
            hills.fill()
            return true
        }
    }
}
