import AppKit
import Combine
import HaloCore
import SwiftUI

/// Shows a floating progress card per job or batch and keeps them stacked
/// near where the user dropped.
///
/// - Newest card on top, anchored just below the drop point, the column pushed
///   fully on-screen on whichever display the point is on.
/// - At most `maxVisible` cards; older ones fold into a "+3 more" card.
/// - Success: check morph, optional reveal in Finder, auto-close after 1.6 s
///   (paused while the pointer is over the card). Failure: stays, with the
///   human message, Copy details, Close and Retry. Cancel closes at once.
@MainActor
final class ProgressPresenter {
    struct Configuration {
        var autoCloseDelay = ProgressTheme.Timing.autoClose
        var hoverResumeDelay = ProgressTheme.Timing.hoverResume
        var maxVisible = ProgressTheme.Metrics.maxVisibleCards
        /// Off in tests: no springs, no delays.
        var animated = true
        var announcesToVoiceOver = true
        /// Running progress is spoken only while VoiceOver is on (and sparingly).
        var voiceOverEnabled: @MainActor () -> Bool = { NSWorkspace.shared.isVoiceOverEnabled }
        var screens: @MainActor () -> [ProgressScreen] = { ProgressScreen.system() }
        var reduceMotion: @MainActor () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    }

    typealias Subject = ProgressCardModel.Subject

    final class Card {
        let model: ProgressCardModel
        let panel: ProgressPanel
        let host: ProgressHostingView<ProgressCardRoot>
        var finishHandled = false
        var dismissing = false
        var autoClose: Task<Void, Never>?
        /// Last quarter (25/50/75%) VoiceOver heard, and when.
        var spokenQuarter = 0
        var spokenAt: Date?

        init(model: ProgressCardModel, panel: ProgressPanel, host: ProgressHostingView<ProgressCardRoot>) {
            self.model = model
            self.panel = panel
            self.host = host
        }
    }

    let queue: JobQueue
    var configuration: Configuration
    /// Newest first. Includes cards folded into the summary.
    private(set) var cards: [Card] = []
    private(set) var summaryCard: Card?
    private(set) var anchor: CGPoint = .zero

    private let reveal: Reveal
    private let pasteboard: NSPasteboard
    private let icons: FileIconProvider
    private var subscription: AnyCancellable?
    private var records: [UUID: JobRecord] = [:]
    private var batches: [UUID: JobBatch] = [:]

    init(queue: JobQueue, reveal: Reveal = .finder, pasteboard: NSPasteboard = .general,
         icons: FileIconProvider = .shared, configuration: Configuration = Configuration()) {
        self.queue = queue
        self.reveal = reveal
        self.pasteboard = pasteboard
        self.icons = icons
        self.configuration = configuration
        // @Published emits in willSet, so use the emitted values, never `queue.records`.
        subscription = queue.$records.combineLatest(queue.$batches).sink { [weak self] recs, batches in
            MainActor.assumeIsolated { self?.queueChanged(recs, batches) }
        }
    }

    // MARK: Presenting

    func present(job id: UUID, near point: CGPoint) { present(.job(id), near: point) }

    func present(batch id: UUID, near point: CGPoint) { present(.batch(id), near: point) }

    /// Presents one card for a whole batch when `ids` are exactly its jobs, else one per job.
    func present(jobs ids: [UUID], near point: CGPoint) {
        let owners = Set(ids.compactMap { records[$0]?.batchID })
        if owners.count == 1, let bid = owners.first, let batch = batches[bid], Set(batch.jobIDs) == Set(ids) {
            present(.batch(bid), near: point)
        } else {
            for id in ids { present(.job(id), near: point) }
        }
    }

    func dismissAll() {
        for card in cards { dismiss(card) }
    }

    /// Visible card panels, newest first (tests, gallery).
    var visiblePanels: [ProgressPanel] { cards.prefix(configuration.maxVisible).map(\.panel).filter(\.isVisible) }

    func card(for subject: Subject) -> Card? { cards.first { $0.model.subject == subject } }

    private func present(_ subject: Subject, near point: CGPoint) {
        anchor = point
        if let existing = card(for: subject) {
            cards.removeAll { $0 === existing }
            cards.insert(existing, at: 0)
            updateSummary()
            layout()
            return
        }
        guard let state = state(for: subject) else {
            Log.jobs.error("present: unknown \(String(describing: subject), privacy: .public)")
            return
        }
        let card = makeCard(subject, state)
        cards.insert(card, at: 0)
        loadIcons(card)
        updateSummary()
        layout()
        handlePhase(card)
    }

    // MARK: Queue changes

    private func queueChanged(_ recs: [JobRecord], _ bs: [JobBatch]) {
        records = Dictionary(recs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        batches = Dictionary(bs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        guard !cards.isEmpty else { return }
        var structural = false
        for card in cards where !card.dismissing {
            guard let s = state(for: card.model.subject), s != card.model.state else { continue }
            if s.phase != card.model.state.phase || s.message != card.model.state.message { structural = true }
            card.model.state = s
            handlePhase(card)
        }
        let hiddenBefore = summaryCard?.model.state
        updateSummary()
        if structural || hiddenBefore?.title != summaryCard?.model.state.title { layout() }
    }

    private func state(for subject: Subject) -> ProgressCardState? {
        switch subject {
        case .job(let id):
            return records[id].map { ProgressCardState.single($0) }
        case .batch(let id):
            guard let b = batches[id] else { return nil }
            return ProgressCardState.batch(b, records: b.jobIDs.compactMap { records[$0] })
        case .summary:
            return nil
        }
    }

    private func handlePhase(_ card: Card) {
        let s = card.model.state
        switch s.phase {
        case .succeeded:
            guard !card.finishHandled else { return }
            card.finishHandled = true
            if s.revealOnSuccess, !s.outputs.isEmpty { reveal.inFinder(s.outputs) }
            announce(s)
            scheduleAutoClose(card, after: configuration.autoCloseDelay)
        case .failed:
            guard !card.finishHandled else { return }
            card.finishHandled = true
            card.autoClose?.cancel()
            // A partly failed batch still reveals what did convert.
            if s.revealOnSuccess, !s.outputs.isEmpty { reveal.inFinder(s.outputs) }
            announce(s)
        case .cancelled:
            dismiss(card)
        case .queued, .running:
            card.finishHandled = false
            card.autoClose?.cancel()
            card.autoClose = nil
            announceProgress(card)
        }
    }

    /// Speaks "interview.mov → MP4, 50%" when a running card crosses a quarter,
    /// at most every `spokenProgressInterval` seconds, only while VoiceOver is on,
    /// at low priority so it never cuts across what the user is doing.
    private func announceProgress(_ card: Card) {
        let s = card.model.state
        guard configuration.announcesToVoiceOver, s.phase == .running, configuration.voiceOverEnabled() else { return }
        let quarter = Int((min(1, max(0, s.fraction)) * 4).rounded(.down))
        guard quarter > card.spokenQuarter, quarter < 4 else { return }
        if let at = card.spokenAt, Date().timeIntervalSince(at) < ProgressTheme.Timing.spokenProgressInterval { return }
        card.spokenQuarter = quarter
        card.spokenAt = Date()
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                             userInfo: [.announcement: "\(s.headline), \(ProgressCardState.percent(s.fraction))",
                                        .priority: NSAccessibilityPriorityLevel.low.rawValue])
    }

    // MARK: Cards

    private func makeCard(_ subject: Subject, _ state: ProgressCardState) -> Card {
        let model = ProgressCardModel(subject: subject, state: state)
        let host = ProgressHostingView(rootView: ProgressCardRoot(model: model))
        host.hoverInset = ProgressTheme.Metrics.shadowMargin
        let panel = ProgressPanel()
        panel.contentView = host
        let card = Card(model: model, panel: panel, host: host)
        if !configuration.animated { model.isShown = true }

        model.onCancel = { [weak self, weak card] in
            guard let self, let card else { return }
            if let id = card.model.subjectID { self.queue.cancel(id) }
            self.dismiss(card)
        }
        model.onClose = { [weak self, weak card] in
            guard let self, let card else { return }
            self.dismiss(card)
        }
        model.onRetry = { [weak self, weak card] in
            guard let self, let card, let id = card.model.subjectID else { return }
            card.finishHandled = false
            self.queue.retry(id)
        }
        model.onCopyDetails = { [weak self, weak card] in
            guard let self, let card, let details = card.model.state.details else { return }
            self.pasteboard.clearContents()
            self.pasteboard.setString(ProgressDiagnostics.report(details), forType: .string)
            card.model.didCopyDetails = true
            Task { [weak card] in
                try? await Task.sleep(nanoseconds: UInt64(ProgressTheme.Timing.copiedFeedback * 1_000_000_000))
                card?.model.didCopyDetails = false
            }
        }
        model.onReveal = { [weak self, weak card] in
            guard let self, let card else { return }
            self.reveal.now(card.model.state.outputs)
        }
        host.onHoverChange = { [weak self, weak card] inside in
            MainActor.assumeIsolated {
                guard let self, let card else { return }
                card.model.isHovered = inside
                if inside {
                    card.autoClose?.cancel()
                    card.autoClose = nil
                } else if card.model.state.phase == .succeeded, !card.dismissing {
                    self.scheduleAutoClose(card, after: self.configuration.hoverResumeDelay)
                }
            }
        }
        host.onContentSizeChange = { [weak self] in
            MainActor.assumeIsolated { self?.layout() }
        }
        return card
    }

    /// Finder icons only: the board card leads with its numeral, so no Quick
    /// Look thumbnails are generated for it (the icons stay on the model for
    /// accessibility tooling and future layouts).
    private func loadIcons(_ card: Card) {
        card.model.icons = card.model.state.iconURLs.map { ProgressIconImage(image: icons.icon(for: $0), isThumbnail: false) }
    }

    private func scheduleAutoClose(_ card: Card, after delay: TimeInterval) {
        card.autoClose?.cancel()
        card.autoClose = nil
        guard !card.model.isHovered else { return }
        let nanos = UInt64(max(0, delay) * 1_000_000_000)
        card.autoClose = Task { [weak self, weak card] in
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled, let self, let card, card.model.state.phase == .succeeded, !card.model.isHovered else { return }
            self.dismiss(card)
        }
    }

    private func dismiss(_ card: Card) {
        guard !card.dismissing else { return }
        card.dismissing = true
        card.autoClose?.cancel()
        card.autoClose = nil
        guard configuration.animated, card.panel.isVisible else {
            remove(card)
            return
        }
        card.model.isShown = false
        let nanos = UInt64(ProgressTheme.Timing.dismiss * 1_000_000_000)
        Task { [weak self, weak card] in
            try? await Task.sleep(nanoseconds: nanos)
            guard let self, let card else { return }
            self.remove(card)
        }
    }

    private func remove(_ card: Card) {
        card.panel.orderOut(nil)
        card.host.onHoverChange = nil
        card.host.onContentSizeChange = nil
        cards.removeAll { $0 === card }
        updateSummary()
        layout()
    }

    private func updateSummary() {
        let hidden = cards.dropFirst(configuration.maxVisible).filter { !$0.dismissing }
        guard !hidden.isEmpty else {
            if let s = summaryCard {
                s.panel.orderOut(nil)
                summaryCard = nil
            }
            return
        }
        let state = ProgressCardState.summary(hidden: hidden.map(\.model.state))
        if let s = summaryCard {
            if s.model.state != state { s.model.state = state }
        } else {
            summaryCard = makeCard(.summary, state)
        }
    }

    // MARK: Layout

    /// Places the visible column. New panels appear in place (their content
    /// springs in); existing ones slide to their new slot.
    func layout() {
        let visible = Array(cards.prefix(configuration.maxVisible))
        let column = visible + (summaryCard.map { [$0] } ?? [])
        let margin = ProgressTheme.Metrics.shadowMargin
        let sizes = column.map { card -> CGSize in
            let fit = card.host.fittingSize
            return CGSize(width: max(1, fit.width - 2 * margin), height: max(1, fit.height - 2 * margin))
        }
        guard !column.isEmpty, let screen = ProgressStackLayout.screen(for: anchor, in: configuration.screens()) else {
            for card in cards where card.panel.isVisible { card.panel.orderOut(nil) }
            return
        }
        let rects = ProgressStackLayout.frames(sizes: sizes, anchor: anchor, visible: screen.visibleFrame,
                                               spacing: ProgressTheme.Metrics.stackSpacing,
                                               inset: ProgressTheme.Metrics.edgeInset, gap: ProgressTheme.Metrics.anchorGap)
        let animate = configuration.animated && !configuration.reduceMotion()
        var appeared: [Card] = []
        for (card, rect) in zip(column, rects) {
            let frame = rect.insetBy(dx: -margin, dy: -margin)
            if !card.panel.isVisible {
                card.panel.setFrame(frame, display: false)
                appeared.append(card)
            } else if card.panel.frame != frame {
                if animate {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = ProgressTheme.Timing.restack
                        ctx.timingFunction = ProgressTheme.Timing.caCurve(DesignTokens.Curve.glide)
                        card.panel.animator().setFrame(frame, display: true)
                    }
                } else {
                    card.panel.setFrame(frame, display: true)
                }
            }
        }
        if !appeared.isEmpty { orderStack(column) }
        for card in appeared { show(card) }
        for card in cards.dropFirst(configuration.maxVisible) where card.panel.isVisible {
            card.panel.orderOut(nil)
            card.model.isShown = !configuration.animated
        }
    }

    /// Newest at the back, oldest (and the summary) in front. Each panel's
    /// transparent top margin then overlaps the card above it only where it's
    /// fully clear (the shadow is clipped to the gap), so clicks pass through
    /// and every button stays reachable.
    private func orderStack(_ column: [Card]) {
        for card in column { card.panel.orderFrontRegardless() }
    }

    private func show(_ card: Card) {
        guard configuration.animated else {
            card.model.isShown = true
            return
        }
        // Let SwiftUI commit the hidden state first so the spring has somewhere to start.
        DispatchQueue.main.async { [weak card] in
            MainActor.assumeIsolated { card?.model.isShown = true }
        }
    }

    private func announce(_ s: ProgressCardState) {
        guard configuration.announcesToVoiceOver else { return }
        // "Converted to MP4. clip.mp4, 62% smaller" / "Couldn’t convert to MP4. <why>"
        let text = s.phase == .failed
            ? [s.title, s.message ?? s.caption].joined(separator: ". ")
            : [s.title, [s.headline, s.numeralSpoken].filter { !$0.isEmpty }.joined(separator: ", ")].joined(separator: ". ")
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}
