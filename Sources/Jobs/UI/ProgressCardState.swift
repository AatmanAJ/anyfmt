import Foundation
import AnyfmtCore

/// Everything a progress card shows, derived purely from queue records so it
/// can be unit-tested and rendered offscreen without a queue.
struct ProgressCardState: Equatable {
    enum Phase: Equatable {
        case queued, running, succeeded, failed, cancelled
    }

    /// The big display figure on the card's left: the percent while running,
    /// the size change ("−62%") or the time it took once done, or a glyph.
    enum Numeral: Equatable {
        enum Tone: Equatable { case primary, dim }

        case text(String, tone: Tone)
        /// An SF Symbol (failure), always paired with words in the headline.
        case glyph(String)

        var text: String? { if case .text(let t, _) = self { t } else { nil } }
    }

    var phase: Phase
    /// Status line: "Converting to MP4", "Converted 12 files to JPG".
    var title: String
    /// File name, or "3 of 12 · 2 already JPG".
    var caption: String
    /// `caption` without the skipped-files note ("3 of 12"), for tight footers.
    var captionShort: String? = nil
    /// "42% · About 12 s left", "Saved beside the original".
    var trailing: String
    /// A shorter `trailing` ("42% · 12 s left").
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
    /// What "Copy details" puts on the pasteboard (before `ProgressDiagnostics` tidies it).
    var details: String?
    var outputs: [URL]
    /// Reveal outputs in Finder when this card succeeds (policy snapshot).
    var revealOnSuccess: Bool
    var accessibilityLabel: String

    // The board layout (docs/screens/after/direction/5-progress-cards-dark.png).

    /// Bold line: "interview.mov → MP4", the output's name once done, the failure title.
    var headline = ""
    /// Quiet line under it: "About 20 s left", "Done · 2.4 MB · from 6.3 MB".
    var detail = ""
    /// A shorter `detail` for when the full one would truncate ("4 of 12 · 31 s left").
    var detailShort: String? = nil
    var numeral = Numeral.text("", tone: .dim)
    /// What VoiceOver says for the numeral ("62% smaller").
    var numeralSpoken = ""

    var isFinished: Bool { phase == .succeeded || phase == .failed || phase == .cancelled }

    // MARK: Single job

    static func single(_ r: JobRecord, note: String? = nil, sizes: FileSizes = .disk) -> ProgressCardState {
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
        applyBoard(&s, single: r, name: name, note: note, sizes: sizes)
        s.accessibilityLabel = accessibility(s)
        return s
    }

    private static func applyBoard(_ s: inout ProgressCardState, single r: JobRecord, name: String, note: String?,
                                   sizes: FileSizes) {
        let noted: (String) -> String = { base in note.map { "\(base) · \($0)" } ?? base }
        switch s.phase {
        case .queued:
            s.headline = r.title
            s.detail = noted(String(localized: "Waiting…"))
            s.numeral = .text(percent(0), tone: .dim)
            s.numeralSpoken = String(localized: "Waiting")
        case .running:
            s.headline = r.title
            let left = r.cancelRequested ? String(localized: "Cancelling…") : (etaText(r.eta) ?? r.activityTitle)
            s.detail = noted(left)
            if !r.cancelRequested, let compact = etaText(r.eta, compact: true) { s.detailShort = compact }
            s.numeral = .text(percent(r.fraction), tone: r.cancelRequested ? .dim : .primary)
            s.numeralSpoken = percent(r.fraction)
        case .succeeded:
            s.headline = outputName(s.outputs) ?? name
            let figure = ResultFigure(inputs: r.inputs, outputs: s.outputs, started: r.startedAt,
                                      finished: r.finishedAt, sizes: sizes, files: nil)
            s.numeral = .text(figure.numeral, tone: .primary)
            s.numeralSpoken = figure.spoken
            s.detail = noted(([String(localized: "Done")] + (figure.sizes.map { [$0] } ?? [s.trailing]))
                .joined(separator: " · "))
            // The check glyph already says "done" when space is short.
            s.detailShort = figure.sizes ?? s.trailing
        case .failed:
            s.headline = r.failedTitle
            s.detail = noted(name)
            s.numeral = .glyph("exclamationmark.triangle.fill")
            s.numeralSpoken = String(localized: "Failed")
        case .cancelled:
            s.headline = String(localized: "Cancelled")
            s.detail = noted(name)
            s.numeral = .text(percent(r.fraction), tone: .dim)
            s.numeralSpoken = String(localized: "Cancelled")
        }
    }

    // MARK: Batch

    static func batch(_ b: JobBatch, records: [JobRecord], sizes: FileSizes = .disk) -> ProgressCardState {
        // One job (others skipped): show it like a single job, with the note.
        if records.count == 1, let only = records.first { return single(only, note: b.note, sizes: sizes) }
        let p = BatchProgress(records)
        let policy = records.first?.policy ?? .default
        var s = ProgressCardState(
            phase: .running, title: b.activityTitle, caption: "", trailing: "", fraction: p.fraction, message: nil,
            iconURLs: Array(records.compactMap(\.iconURL).prefix(3)), isBatch: true, canCancel: true, canRetry: false,
            retryLabel: String(localized: "Retry"), details: nil, outputs: p.outputs,
            revealOnSuccess: policy.revealInFinder, accessibilityLabel: "")
        let note = b.note.map { " · \($0)" } ?? ""
        var cancelling = false

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
            cancelling = records.contains { $0.cancelRequested && !$0.isFinished }
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
        applyBoard(&s, batch: b, records: records, cancelling: cancelling, sizes: sizes)
        s.accessibilityLabel = accessibility(s)
        return s
    }

    private static func applyBoard(_ s: inout ProgressCardState, batch b: JobBatch, records: [JobRecord],
                                   cancelling: Bool, sizes: FileSizes) {
        s.headline = s.title
        switch s.phase {
        case .queued, .running:
            let dim = s.phase == .queued || cancelling
            let tail = dim ? s.trailing : (etaText(b.eta) ?? b.activityTitle)
            s.detail = [s.caption, tail].filter { !$0.isEmpty }.joined(separator: " · ")
            let compactTail = dim ? s.trailing : (etaText(b.eta, compact: true) ?? "")
            s.detailShort = [s.captionShort ?? s.caption, compactTail].filter { !$0.isEmpty }.joined(separator: " · ")
            s.numeral = .text(percent(s.fraction), tone: dim ? .dim : .primary)
            s.numeralSpoken = dim ? s.trailing : percent(s.fraction)
        case .succeeded where records.isEmpty:
            s.detail = s.caption
            s.numeral = .text("0", tone: .dim)
            s.numeralSpoken = String(localized: "No files")
        case .succeeded:
            let done = records.filter(\.didSucceed)
            let figure = ResultFigure(inputs: done.flatMap(\.inputs), outputs: done.flatMap(\.outputs),
                                      started: done.compactMap(\.startedAt).min(),
                                      finished: done.compactMap(\.finishedAt).max(), sizes: sizes, files: done.count)
            s.numeral = .text(figure.numeral, tone: .primary)
            s.numeralSpoken = figure.spoken
            s.detail = ([s.caption] + (figure.sizes.map { [$0] } ?? [s.trailing])).joined(separator: " · ")
            s.detailShort = figure.sizes ?? s.caption
        case .failed:
            s.detail = s.caption
            s.numeral = .glyph("exclamationmark.triangle.fill")
            s.numeralSpoken = String(localized: "Failed")
        case .cancelled:
            s.detail = s.caption
            s.numeral = .text(percent(BatchProgress(records).fraction), tone: .dim)
            s.numeralSpoken = String(localized: "Cancelled")
        }
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
        // Read after the "+3" numeral: "+3 more jobs".
        s.headline = hidden.count == 1 ? String(localized: "more job") : String(localized: "more jobs")
        s.detail = running.isEmpty ? String(localized: "All finished")
            : String(localized: "\(running.count) running · \(s.trailing)")
        s.numeral = .text("+\(hidden.count)", tone: .primary)
        s.numeralSpoken = "+\(hidden.count)"
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
        [s.headline, s.numeralSpoken, s.detail, s.message ?? ""].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// File sizes for the "−62%" figure. Injected so renders and tests don't touch disk.
struct FileSizes: Sendable {
    let size: @Sendable (URL) -> Int64?

    static let disk = FileSizes { url in
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
              values.isDirectory != true, let n = values.fileSize else { return nil }
        return Int64(n)
    }

    static let none = FileSizes { _ in nil }
}

/// The finished-card numeral: the size change when both sides are known, else
/// how long it took, else the file count, else "Done".
struct ResultFigure: Equatable {
    let numeral: String
    let spoken: String
    /// "2.4 MB · from 6.3 MB" when the sizes are known.
    let sizes: String?

    init(inputs: [URL], outputs: [URL], started: Date?, finished: Date?, sizes: FileSizes, files: Int?) {
        let inBytes = Self.total(inputs, sizes), outBytes = Self.total(outputs, sizes)
        if let inBytes, let outBytes, inBytes > 0, !outputs.isEmpty {
            let change = Double(outBytes - inBytes) / Double(inBytes) * 100
            let pct = Int(change.rounded())
            let format = { (n: Int64) in ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }
            self.sizes = String(localized: "\(format(outBytes)) · from \(format(inBytes))")
            if pct < 0 {
                numeral = "\u{2212}\(-pct)%"
                spoken = String(localized: "\(-pct)% smaller")
            } else if pct > 0 {
                numeral = "+\(pct)%"
                spoken = String(localized: "\(pct)% larger")
            } else {
                numeral = "0%"
                spoken = String(localized: "Same size")
            }
            return
        }
        self.sizes = nil
        if let started, let finished, finished > started {
            let t = Self.duration(finished.timeIntervalSince(started))
            numeral = t
            spoken = String(localized: "Took \(t)")
        } else if let files, files > 1 {
            numeral = "\(files)"
            spoken = String(localized: "\(files) files")
        } else {
            numeral = String(localized: "Done")
            spoken = String(localized: "Done")
        }
    }

    /// "0.8 s", "4.8 s", "42 s", "3 min", "1 h 5 min".
    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 10 { return String(localized: "\(max(0.1, seconds).formatted(.number.precision(.fractionLength(1)))) s") }
        if seconds < 60 { return String(localized: "\(Int(seconds.rounded())) s") }
        if seconds < 3600 { return String(localized: "\(Int((seconds / 60).rounded())) min") }
        let h = Int(seconds / 3600), m = Int((seconds - Double(h) * 3600) / 60)
        return m == 0 ? String(localized: "\(h) h") : String(localized: "\(h) h \(m) min")
    }

    private static func total(_ urls: [URL], _ sizes: FileSizes) -> Int64? {
        guard !urls.isEmpty else { return nil }
        var sum: Int64 = 0
        for u in urls {
            guard let n = sizes.size(u) else { return nil }
            sum += n
        }
        return sum
    }
}
