import AppKit
import XCTest
@testable import HaloApp
@testable import HaloCore

/// A queue-level fake job: sleeps cooperatively, can fail the first N attempts.
private final class StubJob: Job, @unchecked Sendable {
    let id = UUID()
    let title: String
    let inputs: [URL]
    let resourceClass: ResourceClass = .cpu
    let progress = Progress.discreteProgress(totalUnitCount: 100)
    private let duration: TimeInterval
    private let outputs: [URL]
    private let failTimes: Int
    private let lock = NSLock()
    private var attempts = 0

    init(_ title: String, duration: TimeInterval = 0.05, inputs: [URL] = [], outputs: [URL] = [], failTimes: Int = 0) {
        self.title = title
        self.duration = duration
        self.inputs = inputs
        self.outputs = outputs
        self.failTimes = failTimes
    }

    func run(context: JobContext) async throws -> [URL] {
        let attempt = lock.withLock { attempts += 1; return attempts }
        progress.completedUnitCount = 0
        for i in 1...10 {
            try await Task.sleep(nanoseconds: UInt64(duration / 10 * 1_000_000_000))
            progress.completedUnitCount = Int64(i * 10)
        }
        if attempt <= failTimes { throw ConversionError.engineFailed("ffmpeg", status: 1, detail: "stub failure \(attempt)") }
        return outputs
    }
}

@MainActor
final class ProgressPresenterTests: XCTestCase {
    private var root: URL!
    private var queue: JobQueue!
    private var revealed: [[URL]] = []
    private var pasteboard: NSPasteboard!
    private let screen = ProgressScreen(frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                        visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
    private let margin = ProgressTheme.Metrics.shadowMargin

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("presenter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        queue = JobQueue(limits: ConcurrencyLimits(cpu: 8), scratch: JobScratch(root: root.appendingPathComponent("scratch")))
        revealed = []
        pasteboard = NSPasteboard(name: NSPasteboard.Name("halo-tests-\(UUID().uuidString)"))
    }

    override func tearDown() async throws {
        queue.cancelAll()
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: root)
    }

    private func presenter(autoClose: TimeInterval = 30, hoverResume: TimeInterval = 30) -> ProgressPresenter {
        var config = ProgressPresenter.Configuration()
        config.animated = false
        config.announcesToVoiceOver = false
        config.autoCloseDelay = autoClose
        config.hoverResumeDelay = hoverResume
        let screens = [screen]
        config.screens = { screens }
        let reveal = Reveal(window: 0) { [weak self] urls in self?.revealed.append(urls) }
        return ProgressPresenter(queue: queue, reveal: reveal, pasteboard: pasteboard, configuration: config)
    }

    private func file(_ name: String) throws -> URL {
        let u = root.appendingPathComponent(name)
        try Data(name.utf8).write(to: u)
        return u
    }

    /// The card's visual rect inside its panel.
    private func cardRect(_ panel: NSPanel) -> CGRect { panel.frame.insetBy(dx: margin, dy: margin) }

    private func eventually(_ what: String, timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { XCTFail("timed out: \(what)"); return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: Windows

    func testPresentCreatesFloatingNonActivatingPanelBelowDropPoint() throws {
        let p = presenter()
        let id = queue.submit(StubJob("a", duration: 5, inputs: [try file("a.heic")]))
        p.present(job: id, near: CGPoint(x: 700, y: 500))
        XCTAssertEqual(p.visiblePanels.count, 1)
        let panel = try XCTUnwrap(p.visiblePanels.first)
        XCTAssertTrue(panel.isVisible)
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.styleMask.contains(.borderless))
        XCTAssertFalse(panel.canBecomeKey, "never steals focus from Finder")
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        let card = cardRect(panel)
        XCTAssertEqual(card.width, ProgressTheme.Metrics.cardWidth, accuracy: 0.5)
        XCTAssertEqual(card.height, 82, accuracy: 8, "≈ the approved board (5-progress-cards-dark)")
        XCTAssertEqual(card.midX, 700, accuracy: 1)
        XCTAssertEqual(card.maxY, 500 - ProgressTheme.Metrics.anchorGap, accuracy: 1)
    }

    func testCardsStackNewestOnTopWithConsistentSpacing() throws {
        let p = presenter()
        var ids: [UUID] = []
        for i in 0..<3 {
            let id = queue.submit(StubJob("j\(i)", duration: 5, inputs: [try file("j\(i).png")]))
            ids.append(id)
            p.present(job: id, near: CGPoint(x: 600, y: 600))
        }
        let panels = p.visiblePanels
        XCTAssertEqual(panels.count, 3)
        XCTAssertEqual(p.cards.first?.model.subject, .job(ids[2]), "newest first")
        let rects = panels.map(cardRect)
        XCTAssertEqual(rects[0].maxY, 600 - ProgressTheme.Metrics.anchorGap, accuracy: 1, "newest sits at the drop point")
        for (upper, lower) in zip(rects, rects.dropFirst()) {
            XCTAssertEqual(upper.minY - lower.maxY, ProgressTheme.Metrics.stackSpacing, accuracy: 1)
            XCTAssertEqual(upper.minX, lower.minX, accuracy: 0.5)
        }
        // Older panels are ordered in front so their clear margins never block the card above.
        let frontToBack = (NSWindow.windowNumbers(options: []) ?? []).map(\.intValue)
        let order = frontToBack.compactMap { n in panels.firstIndex { $0.windowNumber == n } }
        XCTAssertEqual(order, [2, 1, 0])
    }

    func testAtMostFiveCardsThenSummary() throws {
        let p = presenter()
        for i in 0..<7 {
            let id = queue.submit(StubJob("j\(i)", duration: 5, inputs: [try file("k\(i).png")]))
            p.present(job: id, near: CGPoint(x: 600, y: 700))
        }
        XCTAssertEqual(p.cards.count, 7)
        XCTAssertEqual(p.visiblePanels.count, 5)
        let summary = try XCTUnwrap(p.summaryCard)
        XCTAssertEqual(summary.model.state.title, "+2 more")
        XCTAssertTrue(summary.panel.isVisible)
        let lastCard = try XCTUnwrap(p.visiblePanels.last)
        XCTAssertLessThan(cardRect(summary.panel).maxY, cardRect(lastCard).minY, "summary sits under the stack")
        XCTAssertTrue(p.cards.suffix(2).allSatisfy { !$0.panel.isVisible }, "the two oldest are folded away")

        // Close one visible card: a folded card comes back, summary shrinks.
        p.cards[0].model.onClose()
        XCTAssertEqual(p.visiblePanels.count, 5)
        XCTAssertEqual(p.summaryCard?.model.state.title, "+1 more")
        p.cards[0].model.onClose()
        XCTAssertNil(p.summaryCard, "summary gone when everything fits")
        XCTAssertEqual(p.visiblePanels.count, 5)
    }

    func testStackIsPushedOnScreenNearTheBottomEdge() throws {
        let p = presenter()
        for i in 0..<3 {
            let id = queue.submit(StubJob("b\(i)", duration: 5, inputs: [try file("b\(i).png")]))
            p.present(job: id, near: CGPoint(x: 1435, y: 40))
        }
        let inner = screen.visibleFrame.insetBy(dx: ProgressTheme.Metrics.edgeInset, dy: ProgressTheme.Metrics.edgeInset)
        for panel in p.visiblePanels {
            XCTAssertTrue(inner.contains(cardRect(panel)), "\(cardRect(panel)) inside \(inner)")
        }
    }

    // MARK: Lifecycle

    func testSuccessRevealsAndAutoCloses() async throws {
        let p = presenter(autoClose: 0.05)
        let out = try file("photo.jpg")
        let id = queue.submit(StubJob("photo", inputs: [try file("photo.heic")], outputs: [out]))
        p.present(job: id, near: CGPoint(x: 500, y: 500))
        await eventually("success") { p.cards.first?.model.state.phase == .succeeded }
        XCTAssertEqual(p.cards.first?.model.state.caption, "photo.jpg")
        XCTAssertEqual(p.cards.first?.model.state.trailing, "Saved beside the original")
        XCTAssertEqual(revealed, [[out]], "revealed once in Finder")
        await eventually("auto-close") { p.cards.isEmpty }
        XCTAssertTrue(p.visiblePanels.isEmpty)
    }

    func testNoRevealWhenPolicySaysNo() async throws {
        queue.policyProvider = { OutputPolicy(revealInFinder: false) }
        let p = presenter(autoClose: 0.05)
        let id = queue.submit(StubJob("x", inputs: [try file("x.heic")], outputs: [try file("x.jpg")]))
        p.present(job: id, near: CGPoint(x: 500, y: 500))
        await eventually("closed") { p.cards.isEmpty }
        XCTAssertTrue(revealed.isEmpty)
    }

    func testHoverPausesAutoClose() async throws {
        let p = presenter(autoClose: 0.05, hoverResume: 0.05)
        let id = queue.submit(StubJob("h", duration: 0.2, inputs: [try file("h.heic")], outputs: [try file("h.jpg")]))
        p.present(job: id, near: CGPoint(x: 500, y: 500))
        let card = try XCTUnwrap(p.cards.first)
        card.host.onHoverChange?(true)
        XCTAssertTrue(card.model.isHovered)
        await eventually("success") { card.model.state.phase == .succeeded }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(p.cards.count, 1, "still open while hovered")
        card.host.onHoverChange?(false)
        await eventually("closes after the pointer leaves") { p.cards.isEmpty }
    }

    func testFailureStaysOpenCopiesDetailsAndRetries() async throws {
        let p = presenter(autoClose: 0.05)
        let id = queue.submit(StubJob("broken.mov → MP4", inputs: [try file("broken.mov")], outputs: [try file("broken.mp4")], failTimes: 1))
        p.present(job: id, near: CGPoint(x: 500, y: 500))
        let card = try XCTUnwrap(p.cards.first)
        await eventually("failure") { card.model.state.phase == .failed }
        let runningHeight = card.panel.frame.height
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(p.cards.count, 1, "failures stay open")
        XCTAssertTrue(card.panel.isVisible)
        XCTAssertEqual(card.model.state.message, "The conversion stopped unexpectedly. The original file is untouched.")
        await eventually("panel grows for the message") { card.panel.frame.height > runningHeight || card.panel.frame.height > 110 }

        card.model.onCopyDetails()
        let copied = try XCTUnwrap(pasteboard.string(forType: .string))
        XCTAssertTrue(copied.contains("stub failure 1"))
        XCTAssertTrue(copied.contains("macOS"), "versions included")
        XCTAssertTrue(card.model.didCopyDetails)

        card.model.onRetry()
        XCTAssertEqual(queue.record(id)?.attempt, 2)
        await eventually("retry succeeds and closes") { p.cards.isEmpty }
        XCTAssertEqual(queue.record(id)?.didSucceed, true)
    }

    func testCancelFromCardCancelsJobAndClosesAtOnce() async throws {
        let p = presenter()
        let id = queue.submit(StubJob("long", duration: 10, inputs: [try file("long.mov")]))
        p.present(job: id, near: CGPoint(x: 500, y: 500))
        XCTAssertEqual(p.cards.first?.model.state.canCancel, true)
        p.cards.first?.model.onCancel()
        XCTAssertTrue(p.cards.isEmpty, "card closes immediately")
        let q = queue!
        await eventually("job cancelled") { q.record(id)?.wasCancelled == true }
    }

    func testBatchGetsOneCard() async throws {
        let p = presenter(autoClose: 0.05)
        let jobs = try (1...4).map { StubJob("f\($0)", inputs: [try file("f\($0).heic")], outputs: [try file("f\($0).jpg")]) }
        let bid = queue.submitBatch(jobs, title: "4 files → JPG", activityTitle: "Converting 4 files to JPG",
                                    completedTitle: "Converted 4 files to JPG", note: "1 already JPG", fileCount: 5)
        p.present(jobs: jobs.map(\.id), near: CGPoint(x: 500, y: 500))
        XCTAssertEqual(p.cards.count, 1)
        XCTAssertEqual(p.cards.first?.model.subject, .batch(bid))
        XCTAssertEqual(p.cards.first?.model.state.isBatch, true)
        XCTAssertTrue(p.cards.first?.model.state.caption.hasSuffix("of 4 · 1 already JPG") ?? false)
        await eventually("batch done") { p.cards.first?.model.state.phase == .succeeded || p.cards.isEmpty }
        XCTAssertEqual(revealed.count, 1, "one Finder reveal for the whole batch")
        XCTAssertEqual(revealed.first?.count, 4)
    }

    func testJobsControllerWiresQueuePresenterAndRecents() async throws {
        let recents = RecentConversions(directory: root.appendingPathComponent("support"))
        let controller = JobsController(recents: recents, reveal: Reveal(window: 0) { _ in },
                                        scratch: JobScratch(root: root.appendingPathComponent("scratch2")))
        controller.presenter.configuration.animated = false
        controller.presenter.configuration.announcesToVoiceOver = false
        let out = try file("r.jpg")
        let id = controller.submit(StubJob("r.heic → JPG", inputs: [try file("r.heic")], outputs: [out]), near: CGPoint(x: 400, y: 400))
        XCTAssertEqual(controller.presenter.cards.count, 1)
        _ = await controller.queue.waitForJob(id)
        XCTAssertEqual(recents.items.first?.outputs, [out])
        controller.presenter.dismissAll()
    }

    // MARK: Pure layout

    func testLayoutClampsToEveryEdge() {
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let sizes = [CGSize(width: 288, height: 70), CGSize(width: 288, height: 70)]
        func frames(_ p: CGPoint) -> [CGRect] {
            ProgressStackLayout.frames(sizes: sizes, anchor: p, visible: visible, spacing: 8, inset: 12, gap: 26)
        }
        let inner = visible.insetBy(dx: 12, dy: 12)
        for p in [CGPoint(x: 995, y: 400), CGPoint(x: 5, y: 400), CGPoint(x: 500, y: 795), CGPoint(x: 500, y: 5), CGPoint(x: 999, y: 1)] {
            for r in frames(p) { XCTAssertTrue(inner.contains(r), "\(r) for anchor \(p)") }
        }
        let centred = frames(CGPoint(x: 500, y: 500))
        XCTAssertEqual(centred[0].midX, 500)
        XCTAssertEqual(centred[0].maxY, 474)
        XCTAssertEqual(centred[0].minY - centred[1].maxY, 8)
    }

    func testLayoutNewestCardWinsWhenTheStackIsTallerThanTheScreen() {
        let visible = CGRect(x: 0, y: 0, width: 800, height: 200)
        let sizes = Array(repeating: CGSize(width: 288, height: 70), count: 5)
        let r = ProgressStackLayout.frames(sizes: sizes, anchor: CGPoint(x: 400, y: 100), visible: visible, spacing: 8, inset: 12, gap: 26)
        XCTAssertEqual(r[0].maxY, 188, "newest pinned to the top of the usable area")
    }

    func testScreenSelectionIsMultiDisplayAware() {
        let main = ProgressScreen(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
        let left = ProgressScreen(frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080), visibleFrame: CGRect(x: -1920, y: -200, width: 1920, height: 1080))
        XCTAssertEqual(ProgressStackLayout.screen(for: CGPoint(x: -100, y: 300), in: [main, left]), left)
        XCTAssertEqual(ProgressStackLayout.screen(for: CGPoint(x: 100, y: 300), in: [main, left]), main)
        XCTAssertEqual(ProgressStackLayout.screen(for: CGPoint(x: 2000, y: 300), in: [main, left]), main, "nearest when off every display")
        let r = ProgressStackLayout.frames(sizes: [CGSize(width: 288, height: 70)], anchor: CGPoint(x: -5, y: 300),
                                           visible: left.visibleFrame, spacing: 8, inset: 12, gap: 26)
        XCTAssertLessThanOrEqual(r[0].maxX, -12, "kept on the display the drop happened on")
    }

    // MARK: Card text

    func testETAAndPercentText() {
        XCTAssertNil(ProgressCardState.etaText(nil))
        XCTAssertEqual(ProgressCardState.etaText(1.5), "Almost done")
        XCTAssertEqual(ProgressCardState.etaText(11.2), "About 12 s left")
        XCTAssertEqual(ProgressCardState.etaText(11.2, compact: true), "12 s left")
        XCTAssertEqual(ProgressCardState.etaText(130), "About 2 min left")
        XCTAssertEqual(ProgressCardState.etaText(3900), "About 1 h 5 min left")
        XCTAssertEqual(ProgressCardState.percent(0.429), "42%")
        XCTAssertEqual(ProgressCardState.percent(0.999), "99%", "never claims 100% early")
        XCTAssertEqual(ProgressCardState.progressText(0.5, eta: 30), "50% · About 30 s left")
    }

    func testCardStatesFromRecords() {
        let input = URL(fileURLWithPath: "/x/clip.mov")
        var r = JobRecord(title: "clip.mov → MP4", activityTitle: "Converting to MP4", completedTitle: "Converted to MP4",
                          failedTitle: "Couldn’t convert to MP4", inputs: [input], state: .running, fraction: 0.42, eta: 12)
        var s = ProgressCardState.single(r)
        XCTAssertEqual(s.title, "Converting to MP4")
        XCTAssertEqual(s.caption, "clip.mov")
        XCTAssertEqual(s.trailing, "42% · About 12 s left")
        XCTAssertTrue(s.canCancel)

        r.cancelRequested = true
        XCTAssertEqual(ProgressCardState.single(r).trailing, "Cancelling…")

        r.state = .succeeded([URL(fileURLWithPath: "/x/clip 2.mp4")])
        r.policy = OutputPolicy(location: .folder(URL(fileURLWithPath: "/Users/me/Converted")))
        s = ProgressCardState.single(r)
        XCTAssertEqual(s.title, "Converted to MP4")
        XCTAssertEqual(s.caption, "clip 2.mp4", "shows the collision-safe name")
        XCTAssertEqual(s.trailing, "Saved to Converted")

        r.state = .failed(message: "Nope.", details: "tech")
        s = ProgressCardState.single(r)
        XCTAssertEqual(s.title, "Couldn’t convert to MP4")
        XCTAssertEqual(s.message, "Nope.")
        XCTAssertEqual(s.details, "tech")
        XCTAssertTrue(s.canRetry)
        XCTAssertFalse(s.canCancel)
    }

    func testBatchStateCountsAndNotes() {
        let recs = (0..<12).map { i in
            JobRecord(title: "f\(i)", inputs: [URL(fileURLWithPath: "/x/f\(i).heic")],
                      state: i < 3 ? .succeeded([URL(fileURLWithPath: "/x/f\(i).jpg")]) : (i < 5 ? .running : .queued),
                      fraction: i < 3 ? 1 : 0.5, outputs: i < 3 ? [URL(fileURLWithPath: "/x/f\(i).jpg")] : [])
        }
        let b = JobBatch(title: "t", activityTitle: "Converting 12 files to JPG", completedTitle: "Converted 12 files to JPG",
                         note: "2 already JPG", jobIDs: recs.map(\.id), fileCount: 14, eta: 31)
        let s = ProgressCardState.batch(b, records: recs)
        XCTAssertEqual(s.caption, "4 of 12 · 2 already JPG")
        XCTAssertEqual(s.captionShort, "4 of 12")
        XCTAssertEqual(s.trailing, "\(ProgressCardState.percent(BatchProgress(recs).fraction)) · About 31 s left")
        XCTAssertEqual(s.iconURLs.count, 3)

        let done = recs.map { r -> JobRecord in var c = r; c.state = .succeeded([URL(fileURLWithPath: "/x/o.jpg")]); c.fraction = 1; return c }
        let ok = ProgressCardState.batch(b, records: done)
        XCTAssertEqual(ok.phase, .succeeded)
        XCTAssertEqual(ok.title, "Converted 12 files to JPG")
        XCTAssertEqual(ok.caption, "12 files · 2 already JPG")
        XCTAssertEqual(ok.trailing, "Saved beside the originals")

        var partly = done
        partly[4].state = .failed(message: "“f4.heic” couldn’t be read.", details: "d4")
        partly[4].errorMessage = "“f4.heic” couldn’t be read."
        partly[4].errorDetails = "d4"
        let bad = ProgressCardState.batch(b, records: partly)
        XCTAssertEqual(bad.phase, .failed)
        XCTAssertEqual(bad.title, "11 of 12 finished")
        XCTAssertEqual(bad.message, "“f4.heic” couldn’t be read.", "no duplicated file name")
        XCTAssertEqual(bad.retryLabel, "Retry")
        XCTAssertTrue(bad.details?.contains("d4") ?? false)

        XCTAssertEqual(ProgressCardState.batch(b, records: [recs[3]]).isBatch, false, "a one-job batch reads like a single job")
        XCTAssertEqual(ProgressCardState.summary(hidden: [s, s, s]).title, "+3 more")
    }
}
