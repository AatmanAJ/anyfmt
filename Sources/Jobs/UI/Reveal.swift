import AppKit
import Foundation

/// Reveals results in Finder.
///
/// Requests arriving within `window` are merged into one
/// `activateFileViewerSelecting` call, so twelve separately dropped files that
/// finish together open one Finder window with twelve selections, not twelve.
@MainActor
final class Reveal {
    typealias Handler = @MainActor ([URL]) -> Void

    static let finder = Reveal(window: 0.25) { NSWorkspace.shared.activateFileViewerSelecting($0) }

    private let window: TimeInterval
    private let handler: Handler
    private var pending: [URL] = []
    private var flush: Task<Void, Never>?

    init(window: TimeInterval = 0.25, handler: @escaping Handler) {
        self.window = window
        self.handler = handler
    }

    /// Selects `urls` in Finder (existing files only), coalesced.
    func inFinder(_ urls: [URL]) {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return }
        for u in existing where !pending.contains(u) { pending.append(u) }
        guard window > 0 else { fire(); return }
        flush?.cancel()
        let delay = UInt64(window * 1_000_000_000)
        flush = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.fire()
        }
    }

    /// Selects `urls` in Finder right now (user clicked "Show").
    func now(_ urls: [URL]) {
        pending.removeAll { urls.contains($0) }
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        if !existing.isEmpty { handler(existing) }
    }

    private func fire() {
        let urls = pending
        pending = []
        flush = nil
        if !urls.isEmpty { handler(urls) }
    }
}
