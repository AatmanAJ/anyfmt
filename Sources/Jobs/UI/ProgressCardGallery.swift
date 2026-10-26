import AppKit
import AnyfmtCore
import SwiftUI

/// Renders progress cards (and toasts) in every state offscreen into PNGs
/// (docs/screens), so design regressions are visible in review. Built from the
/// real `ProgressCardState` builders over fake records, so it exercises the
/// same code as the live windows. `--render-gallery` calls `render(into:)` too.
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

    struct ToastScene {
        let name: String
        let scheme: ColorScheme
        var increasedContrast = false
        let toasts: [ToastContent]
    }

    @discardableResult
    static func render(into directory: URL, scale: CGFloat = 2) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written: [URL] = []
        for scene in scenes() {
            let url = directory.appendingPathComponent("progress-\(scene.name).png")
            try png(SceneView(scene: scene)
                .environment(\.colorScheme, scene.scheme)
                .environment(\.progressAppearanceOverrides, scene.overrides), scale: scale).write(to: url, options: .atomic)
            written.append(url)
        }
        for scene in toastScenes() {
            let url = directory.appendingPathComponent("toast-\(scene.name).png")
            try png(ToastSceneView(scene: scene).environment(\.colorScheme, scene.scheme), scale: scale)
                .write(to: url, options: .atomic)
            written.append(url)
        }
        return written
    }

    static func png(for scene: Scene, scale: CGFloat) throws -> Data {
        try png(SceneView(scene: scene)
            .environment(\.colorScheme, scene.scheme)
            .environment(\.progressAppearanceOverrides, scene.overrides), scale: scale)
    }

    private static func png<V: View>(_ view: V, scale: CGFloat) throws -> Data {
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
        let board: [(ProgressCardModel.Subject, ProgressCardState)] = [
            (.job(UUID()), Fixtures.success),
            (.job(UUID()), Fixtures.running),
        ]
        let overview: [(ProgressCardModel.Subject, ProgressCardState)] = [
            (.job(UUID()), Fixtures.running),
            (.batch(UUID()), Fixtures.batchRunning),
            (.job(UUID()), Fixtures.success),
            (.job(UUID()), Fixtures.failure),
        ]
        let more: [(ProgressCardModel.Subject, ProgressCardState)] = [
            (.job(UUID()), Fixtures.queued),
            (.job(UUID()), Fixtures.cancelling),
            (.job(UUID()), Fixtures.successTimed),
            (.batch(UUID()), Fixtures.batchDone),
            (.batch(UUID()), Fixtures.batchPartial),
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
            Scene(name: "board-dark", scheme: .dark, cards: board),
            Scene(name: "running", scheme: .light, cards: [(.job(UUID()), Fixtures.running)]),
            Scene(name: "success", scheme: .light, cards: [(.job(UUID()), Fixtures.success)]),
            Scene(name: "failure", scheme: .light, cards: [(.job(UUID()), Fixtures.failure)]),
            Scene(name: "batch", scheme: .light, cards: [(.batch(UUID()), Fixtures.batchRunning), (.batch(UUID()), Fixtures.batchPartial)]),
            Scene(name: "states-light", scheme: .light, cards: overview),
            Scene(name: "states-dark", scheme: .dark, cards: overview),
            Scene(name: "more-states-light", scheme: .light, cards: more),
            Scene(name: "more-states-dark", scheme: .dark, cards: more),
            Scene(name: "stack-light", scheme: .light, cards: stack),
            Scene(name: "stack-dark", scheme: .dark, cards: stack),
            Scene(name: "high-contrast", scheme: .light, overrides: ProgressAppearanceOverrides(increasedContrast: true),
                  cards: [(.job(UUID()), Fixtures.running), (.job(UUID()), Fixtures.success), (.job(UUID()), Fixtures.failure)]),
            Scene(name: "high-contrast-dark", scheme: .dark, overrides: ProgressAppearanceOverrides(increasedContrast: true),
                  cards: [(.job(UUID()), Fixtures.running), (.job(UUID()), Fixtures.success), (.job(UUID()), Fixtures.failure)]),
            Scene(name: "reduce-transparency-dark", scheme: .dark,
                  overrides: ProgressAppearanceOverrides(reduceTransparency: true),
                  cards: [(.job(UUID()), Fixtures.running), (.job(UUID()), Fixtures.success)]),
            Scene(name: "interactions", scheme: .dark,
                  cards: [(.job(UUID()), Fixtures.success), (.job(UUID()), Fixtures.failure)],
                  hovered: [0], copied: [1]),
        ]
    }

    static func toastScenes() -> [ToastScene] {
        let all = [
            ToastContent(message: "Copied 3 items", kind: .success),
            ToastContent(message: "Link copied", systemImage: "link", kind: .info),
            ToastContent(message: "Moved 4 items to “Client Work”", kind: .success),
            ToastContent(message: "Couldn’t open Ghostty.", kind: .error),
            ToastContent(message: "Moved 2 of 3 items. “Budget.xlsx” is open in another app, so it stayed where it was.", kind: .error),
        ]
        return [
            ToastScene(name: "states-dark", scheme: .dark, toasts: all),
            ToastScene(name: "states-light", scheme: .light, toasts: all),
            ToastScene(name: "high-contrast", scheme: .light, increasedContrast: true, toasts: [all[0], all[3]]),
        ]
    }

    private struct SceneView: View {
        let scene: Scene
        var body: some View {
            VStack(alignment: .leading, spacing: scene.spacing) {
                ForEach(Array(scene.cards.enumerated()), id: \.offset) { i, item in
                    let model = Self.model(item.0, item.1, hovered: scene.hovered.contains(i), copied: scene.copied.contains(i))
                    if item.0 == .summary { ProgressSummaryCard(model: model) } else { ProgressCard(model: model) }
                }
            }
            .padding(DesignTokens.Space.xxl)
            .background(Backdrop(scheme: scene.scheme))
        }

        static func model(_ subject: ProgressCardModel.Subject, _ state: ProgressCardState,
                          hovered: Bool, copied: Bool) -> ProgressCardModel {
            let m = ProgressCardModel(subject: subject, state: state)
            m.isShown = true
            m.isHovered = hovered
            m.didCopyDetails = copied
            return m
        }
    }

    private struct ToastSceneView: View {
        let scene: ToastScene
        var body: some View {
            VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
                ForEach(Array(scene.toasts.enumerated()), id: \.offset) { _, t in
                    ToastView(content: t, increasedContrast: scene.increasedContrast)
                }
            }
            .padding(DesignTokens.Space.xxl)
            .frame(width: DesignTokens.Component.Toast.maxWidth + 2 * DesignTokens.Space.xxl, alignment: .leading)
            .background(Backdrop(scheme: scene.scheme))
        }
    }

    /// A plain desktop stand-in: page black in dark (the board), a light grey
    /// in light so the #F2F2F2 tile and its hairline still read.
    private struct Backdrop: View {
        let scheme: ColorScheme
        var body: some View {
            Color(hex: scheme == .dark ? DesignTokens.Primitive.ink1000 : DesignTokens.Primitive.paper100)
        }
    }

    // MARK: Fake jobs

    enum Fixtures {
        static let dir = URL(fileURLWithPath: "/Users/Shared/Example", isDirectory: true)
        static func file(_ name: String) -> URL { dir.appendingPathComponent(name) }

        /// Sizes for the fake files, so finished cards show a real size change.
        static let sizes = FileSizes { url in
            let table: [String: Int64] = [
                "clip.mov": 6_300_000, "clip.gif": 2_400_000,
                "Trip 01.heic": 3_100_000, "Trip 02.heic": 2_900_000, "Trip 03.heic": 3_300_000,
                "Trip 01.jpg": 2_200_000, "Trip 02.jpg": 2_000_000, "Trip 03.jpg": 2_500_000,
            ]
            return table[url.lastPathComponent]
        }

        static let finished = Date(timeIntervalSinceReferenceDate: 800_000_000)

        static var running: ProgressCardState {
            ProgressCardState.single(JobRecord(
                title: "interview.mov → MP4", activityTitle: L("Converting to \("MP4")"),
                inputs: [file("interview.mov")], resourceClass: .videoToolbox, state: .running, fraction: 0.48, eta: 20),
                sizes: sizes)
        }

        static var queued: ProgressCardState {
            ProgressCardState.single(JobRecord(
                title: "Interview B-roll.mov → MP4", activityTitle: L("Converting to \("MP4")"),
                inputs: [file("Interview B-roll.mov")], resourceClass: .videoToolbox, state: .queued), sizes: sizes)
        }

        static var cancelling: ProgressCardState {
            ProgressCardState.single(JobRecord(
                title: "Keynote.mov → WebM", activityTitle: L("Converting to \("WebM")"),
                inputs: [file("Keynote.mov")], state: .running, fraction: 0.31, eta: 40, cancelRequested: true), sizes: sizes)
        }

        static var audio: ProgressCardState {
            ProgressCardState.single(JobRecord(
                title: "Podcast episode 12.wav → MP3", activityTitle: L("Converting to \("MP3")"),
                inputs: [file("Podcast episode 12.wav")], state: .running, fraction: 0.77, eta: 134), sizes: sizes)
        }

        static var success: ProgressCardState {
            let out = file("clip.gif")
            return ProgressCardState.single(JobRecord(
                title: "clip.mov → GIF", activityTitle: L("Converting to \("GIF")"), completedTitle: L("Converted to \("GIF")"),
                inputs: [file("clip.mov")], state: .succeeded([out]), fraction: 1, outputs: [out]), sizes: sizes)
        }

        /// Sizes unknown (e.g. a folder): the numeral is the time it took.
        static var successTimed: ProgressCardState {
            let out = file("Product demo.mp4")
            return ProgressCardState.single(JobRecord(
                title: "Product demo.mov → MP4", activityTitle: L("Converting to \("MP4")"), completedTitle: L("Converted to \("MP4")"),
                inputs: [file("Product demo.mov")], state: .succeeded([out]), fraction: 1, outputs: [out],
                startedAt: finished.addingTimeInterval(-4.8), finishedAt: finished), sizes: sizes)
        }

        static var failure: ProgressCardState {
            let failure = JobFailure.from(ConversionError.engineFailed("ffmpeg", status: 1, detail: "moov atom not found"))
            return ProgressCardState.single(JobRecord(
                title: "Screen recording.mov → MP4", activityTitle: L("Converting to \("MP4")"),
                failedTitle: L("Couldn’t convert to \("MP4")"), inputs: [file("Screen recording.mov")],
                state: .failed(message: failure.message, details: failure.details),
                errorMessage: failure.message, errorDetails: failure.details), sizes: sizes)
        }

        static var batchRunning: ProgressCardState {
            let names = (1...12).map { String(format: "Trip %02d.heic", $0) }
            let records: [JobRecord] = names.enumerated().map { i, n in
                let state: JobState = i < 3 ? .succeeded([file(n)]) : (i < 5 ? .running : .queued)
                return JobRecord(title: n, inputs: [file(n)], state: state, fraction: i < 3 ? 1 : (i < 5 ? 0.5 : 0))
            }
            let batch = JobBatch(title: "12 files → JPG", activityTitle: L("Converting \(12) files to \("JPG")"),
                                 note: L("\(2) already \("JPG")"), jobIDs: records.map(\.id), fileCount: 14, eta: 31)
            return ProgressCardState.batch(batch, records: records, sizes: sizes)
        }

        static var batchDone: ProgressCardState {
            let names = ["Trip 01", "Trip 02", "Trip 03"]
            let records: [JobRecord] = names.map { n in
                let out = file("\(n).jpg")
                return JobRecord(title: "\(n).heic", inputs: [file("\(n).heic")], state: .succeeded([out]), fraction: 1,
                                 outputs: [out])
            }
            let batch = JobBatch(title: "3 files → JPG", activityTitle: L("Converting \(3) files to \("JPG")"),
                                 completedTitle: L("Converted \(3) files to \("JPG")"), jobIDs: records.map(\.id))
            return ProgressCardState.batch(batch, records: records, sizes: sizes)
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
            return ProgressCardState.batch(batch, records: records, sizes: sizes)
        }
    }
}
