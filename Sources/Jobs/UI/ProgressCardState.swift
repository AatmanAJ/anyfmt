import Foundation
import HaloCore

/// Everything a progress card shows, derived purely from queue records so it
/// can be unit-tested and rendered offscreen without a queue.
struct ProgressCardState: Equatable {
    enum Phase: Equatable {
        case queued, running, succeeded, failed, cancelled
    }

    var phase: Phase
    /// Bold first line: "Converting to MP4", "Converted 12 files to JPG".
    var title: String
    /// Footer, left: file name, or "3 of 12 · 2 already JPG".
    var caption: String
    /// `caption` without the skipped-files note ("3 of 12"), for tight footers.
    var captionShort: String? = nil
    /// Footer, right: "42% · About 12 s left", "Saved beside the original".
    var trailing: String
    /// A shorter `trailing` ("42% · 12 s left") used when the full one would
    /// squeeze the file name.
    var trailingCompact: String? = nil
    var fraction: Double
    /// Failure explanation (only when failed).
    var message: String?
    /// Input files whose icons represent the card (up to 3 for batches).
    var iconURLs: [URL]
    var isBatch: Bool
    var canCancel: Bool
    var canRetry: Bool
    var retryLabel: String
    /// What "Copy details" puts on the pasteboard.
    var details: String?
    var outputs: [URL]
    /// Reveal outputs in Finder when this card succeeds (policy snapshot).
    var revealOnSuccess: Bool
    var accessibilityLabel: String

    var isFinished: Bool { phase == .succeeded || phase == .failed || phase == .cancelled }

    // MARK: Single job

    static func single(_ r: JobRecord, note: String? = nil) -> ProgressCardState {
        let name = r.inputs.first?.lastPathComponent ?? r.title
        let withNote: (String) -> String = { base in note.map { "\(base) · \($0)" } ?? base }
        var s = ProgressCardState(
            phase: .running, title: r.activityTitle, caption: withNote(name), trailing: "", fraction: r.fraction,
            message: nil, iconURLs: Array(r.inputs.prefix(1)), isBatch: false, canCancel: true, canRetry: false,
            retryLabel: String(localized: "Retry"), details: nil, outputs: r.outputs,
            revealOnSuccess: r.policy.revealInFinder, accessibilityLabel: "")
        if note != nil { s.captionShort = name }
        switch r.state {
        case .queued:
            s.phase = .queued
            s.trailing = String(localized: "Waiting…")
            s.fraction = 0
        case .running:
            if r.cancelRequested {
                s.trailing = String(localized: "Cancelling…")
            } else {
                s.trailing = progressText(r.fraction, eta: r.eta)
                s.trailingCompact = progressText(r.fraction, eta: r.eta, compact: true)
            }
            s.canCancel = !r.cancelRequested
        case .succeeded(let urls):
            s.phase = .succeeded
            s.title = r.completedTitle
            s.caption = withNote(outputName(urls) ?? name)
            s.trailing = savedNote(r.policy, plural: false)
            s.fraction = 1
            s.canCancel = false
            s.outputs = urls
        case .failed(let message, let details):
            s.phase = .failed
            s.title = r.failedTitle
            s.message = message
            s.details = details
            s.canCancel = false
            s.canRetry = true
        case .cancelled:
            s.phase = .cancelled
            s.title = String(localized: "Cancelled")
            s.canCancel = false
            s.canRetry = true
        }
        s.accessibilityLabel = accessibility(s)
        return s
    }

    // MARK: Batch

    static func batch(_ b: JobBatch, records: [JobRecord]) -> ProgressCardState {
        // One job (others skipped): show it like a single job, with the note.
        if records.count == 1, let only = records.first { return single(only, note: b.note) }
        let p = BatchProgress(records)
        let policy = records.first?.policy ?? .default
        var s = ProgressCardState(
            phase: .running, title: b.activityTitle, caption: "", trailing: "", fraction: p.fraction, message: nil,
            iconURLs: Array(records.compactMap(\.iconURL).prefix(3)), isBatch: true, canCancel: true, canRetry: false,
            retryLabel: String(localized: "Retry"), details: nil, outputs: p.outputs,
            revealOnSuccess: policy.revealInFinder, accessibilityLabel: "")
        let note = b.note.map { " · \($0)" } ?? ""

        if records.isEmpty {
            s.phase = .succeeded
            s.title = String(localized: "Nothing to convert")
            s.caption = b.note ?? ""
            s.canCancel = false
            s.revealOnSuccess = false
        } else if !p.isFinished {
            s.phase = p.running == 0 && p.finished == 0 ? .queued : .running
            s.caption = String(localized: "\(p.position) of \(p.total)") + note
            if !note.isEmpty { s.captionShort = String(localized: "\(p.position) of \(p.total)") }
            let cancelling = records.contains { $0.cancelRequested && !$0.isFinished }
            if cancelling {
                s.trailing = String(localized: "Cancelling…")
            } else if s.phase == .queued {
                s.trailing = String(localized: "Waiting…")
            } else {
                s.trailing = progressText(p.fraction, eta: b.eta)
                s.trailingCompact = progressText(p.fraction, eta: b.eta, compact: true)
            }
            s.canCancel = !cancelling
        } else if p.failed > 0 {
            s.phase = .failed
            s.canCancel = false
            s.canRetry = true
            s.title = p.succeeded > 0 ? String(localized: "\(p.succeeded) of \(p.total) finished") : b.failedTitle
            s.caption = String(localized: "\(p.failed) didn’t finish") + note
            let failedRecords = records.filter(\.didFail)
            let first = failedRecords.first
            let reason = first?.errorMessage ?? String(localized: "Something went wrong.")
            if p.failed == 1 {
                // Name the file unless the reason already does.
                let name = first?.inputs.first?.lastPathComponent
                s.message = name.map { reason.contains($0) ? reason : "\($0): \(reason)" } ?? reason
            } else {
                s.message = String(localized: "\(p.failed) files couldn’t be finished. \(reason)")
            }
            s.retryLabel = p.failed > 1 ? String(localized: "Retry \(p.failed)") : String(localized: "Retry")
            s.details = failedRecords.compactMap { r in r.errorDetails.map { "— \(r.title)\n\($0)" } }
                .joined(separator: "\n\n")
        } else if p.succeeded == 0 {
            s.phase = .cancelled
            s.title = String(localized: "Cancelled")
            s.caption = String(localized: "\(p.total) files")
            s.canCancel = false
            s.canRetry = true
        } else {
            s.phase = .succeeded
            s.title = b.completedTitle
            s.caption = (p.succeeded == 1 ? String(localized: "1 file") : String(localized: "\(p.succeeded) files")) + note
            s.trailing = savedNote(policy, plural: p.succeeded > 1)
            s.fraction = 1
            s.canCancel = false
        }
        s.accessibilityLabel = accessibility(s)
        return s
    }

    // MARK: "+3 more"

    static func summary(hidden: [ProgressCardState]) -> ProgressCardState {
        let running = hidden.filter { !$0.isFinished }
        let fraction = running.isEmpty ? 1 : running.map(\.fraction).reduce(0, +) / Double(running.count)
        var s = ProgressCardState(
            phase: running.isEmpty ? .succeeded : .running, title: String(localized: "+\(hidden.count) more"),
            caption: "", trailing: running.isEmpty ? "" : percent(fraction), fraction: fraction, message: nil,
            iconURLs: [], isBatch: true, canCancel: false, canRetry: false, retryLabel: "", details: nil,
            outputs: [], revealOnSuccess: false, accessibilityLabel: "")
        s.accessibilityLabel = String(localized: "\(hidden.count) more jobs") + (running.isEmpty ? "" : ", \(s.trailing)")
        return s
    }

    // MARK: Text

    static func percent(_ fraction: Double) -> String {
        let pct = Int((min(1, max(0, fraction)) * 100).rounded(.down))
        return String(localized: "\(pct)%")
    }

    static func progressText(_ fraction: Double, eta: TimeInterval?, compact: Bool = false) -> String {
        guard let e = etaText(eta, compact: compact) else { return percent(fraction) }
        return "\(percent(fraction)) · \(e)"
    }

    /// "About 12 s left", "About 3 min left", "About 1 h 5 min left", "Almost done".
    /// Compact drops "About": "12 s left".
    static func etaText(_ seconds: TimeInterval?, compact: Bool = false) -> String? {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
        if seconds < 3 { return String(localized: "Almost done") }
        if seconds < 60 {
            let n = Int(seconds.rounded(.up))
            return compact ? String(localized: "\(n) s left") : String(localized: "About \(n) s left")
        }
        if seconds < 3600 {
            let m = max(1, Int((seconds / 60).rounded()))
            return compact ? String(localized: "\(m) min left") : String(localized: "About \(m) min left")
        }
        let h = Int(seconds / 3600)
        let m = Int((seconds - Double(h) * 3600) / 60)
        if compact { return m == 0 ? String(localized: "\(h) h left") : String(localized: "\(h) h \(m) min left") }
        return m == 0 ? String(localized: "About \(h) h left") : String(localized: "About \(h) h \(m) min left")
    }

    static func savedNote(_ policy: OutputPolicy, plural: Bool) -> String {
        switch policy.location {
        case .besideOriginal:
            return plural ? String(localized: "Saved beside the originals") : String(localized: "Saved beside the original")
        case .folder(let url):
            return String(localized: "Saved to \(FileManager.default.displayName(atPath: url.path))")
        }
    }

    private static func outputName(_ urls: [URL]) -> String? {
        guard let first = urls.first else { return nil }
        return urls.count == 1 ? first.lastPathComponent : String(localized: "\(urls.count) files")
    }

    private static func accessibility(_ s: ProgressCardState) -> String {
        [s.title, s.caption, s.trailing, s.message ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
