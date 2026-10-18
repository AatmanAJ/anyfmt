import AppKit
import Foundation
import WebKit

/// HTML → paginated PDF with an offscreen `WKWebView`.
///
/// Verified approach (research/PLATFORM_RESEARCH.md §E): `printOperation(with:)`
/// + `runModal(for:)` on a hidden borderless window paginates properly and
/// honours CSS page breaks; `createPDF` produces one tall page and
/// `NSPrintOperation.run()` hangs. Everything runs on the main actor, so the
/// engine works from the app, the CLI and the matrix runner as long as the main
/// run loop is serviced (Swift's async `main` does that). Renders are serialised.
///
/// No network: JavaScript is off, the data store is ephemeral, a content rule
/// list blocks every remote scheme and non-local navigations are cancelled.
@MainActor
public final class WebPDFRenderer: NSObject, WKNavigationDelegate {
    public struct PageSetup: Sendable {
        public var size: CGSize
        public var margin: CGFloat
        public var landscape: Bool

        public init(size: CGSize, margin: CGFloat = 54, landscape: Bool = false) {
            self.size = size
            self.margin = margin
            self.landscape = landscape
        }

        public init(_ page: PageSize, margin: CGFloat = 54, landscape: Bool = false) {
            self.init(size: CGSize(width: page.size.width, height: page.size.height), margin: margin, landscape: landscape)
        }

        var paper: CGSize { landscape ? CGSize(width: size.height, height: size.width) : size }
    }

    public enum Failure: Error, LocalizedError {
        case loadFailed(String), timeout, printFailed
        public var errorDescription: String? {
            switch self {
            case .loadFailed(let d): "WebKit couldn't load the page: \(d)"
            case .timeout: "WebKit timed out"
            case .printFailed: "WebKit couldn't produce the PDF"
            }
        }
    }

    // Serialisation gate (one render at a time).
    private static var busy = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []
    private static var ruleList: WKContentRuleList?
    private static var ruleListTried = false

    private static func acquire() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private static func release() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }

    public static func render(html: String, to output: URL, page: PageSetup, timeout: TimeInterval = 90) async throws {
        try await render(output: output, page: page, timeout: timeout) { web in
            web.loadHTMLString(html, baseURL: URL(string: "about:blank"))
        }
    }

    /// Renders a local HTML file; `readAccess` is the folder WebKit may read (attachments next to it).
    public static func render(fileURL: URL, readAccess: URL, to output: URL, page: PageSetup, timeout: TimeInterval = 90) async throws {
        try await render(output: output, page: page, timeout: timeout) { web in
            web.loadFileURL(fileURL, allowingReadAccessTo: readAccess)
        }
    }

    private static func render(output: URL, page: PageSetup, timeout: TimeInterval, load: (WKWebView) -> Void) async throws {
        await acquire()
        defer { release() }
        try Task.checkCancellation()
        _ = NSApplication.shared
        let rules = await blockRemoteRules()
        let r = WebPDFRenderer()
        try await r.run(output: output, page: page, timeout: timeout, rules: rules, load: load)
    }

    private static func blockRemoteRules() async -> WKContentRuleList? {
        if ruleListTried { return ruleList }
        ruleListTried = true
        let json = #"[{"trigger":{"url-filter":"^(https?|ftp|wss?|blob):"},"action":{"type":"block"}}]"#
        guard let store = WKContentRuleListStore.default() else { return nil }
        ruleList = await withCheckedContinuation { (c: CheckedContinuation<WKContentRuleList?, Never>) in
            store.compileContentRuleList(forIdentifier: "halo.block-remote", encodedContentRuleList: json) { list, _ in
                c.resume(returning: list)
            }
        }
        return ruleList
    }

    // MARK: Instance

    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var printContinuation: CheckedContinuation<Bool, Never>?

    private func run(output: URL, page: PageSetup, timeout: TimeInterval, rules: WKContentRuleList?, load: (WKWebView) -> Void) async throws {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = false
        if let rules { cfg.userContentController.add(rules) }
        let paper = page.paper
        let frame = NSRect(x: 0, y: 0, width: max(paper.width - 2 * page.margin, 200), height: max(paper.height - 2 * page.margin, 200))
        let web = WKWebView(frame: frame, configuration: cfg)
        web.navigationDelegate = self
        let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: frame.width, height: frame.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = web
        defer {
            web.navigationDelegate = nil
            window.contentView = nil
        }

        try await withTimeout(timeout) {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                self.loadContinuation = c
                load(web)
            }
        } onTimeout: { [weak self] in
            self?.loadContinuation?.resume(throwing: Failure.timeout)
            self?.loadContinuation = nil
            web.stopLoading()
        }
        try Task.checkCancellation()

        let info = NSPrintInfo()
        info.paperSize = NSSize(width: paper.width, height: paper.height)
        info.orientation = page.landscape ? .landscape : .portrait
        info.topMargin = page.margin
        info.bottomMargin = page.margin
        info.leftMargin = page.margin
        info.rightMargin = page.margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = output
        let op = web.printOperation(with: info)
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        op.view?.frame = web.bounds
        let ok: Bool = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            self.printContinuation = c
            op.runModal(for: window, delegate: self, didRun: #selector(printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
        }
        guard ok, FileManager.default.fileExists(atPath: output.path) else { throw Failure.printFailed }
    }

    @objc private func printOperationDidRun(_ op: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        printContinuation?.resume(returning: success)
        printContinuation = nil
    }

    private func withTimeout(_ seconds: TimeInterval, _ body: () async throws -> Void, onTimeout: @escaping @MainActor () -> Void) async throws {
        let timer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if !Task.isCancelled { onTimeout() }
        }
        defer { timer.cancel() }
        try await body()
    }

    // MARK: WKNavigationDelegate

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: Failure.loadFailed(error.localizedDescription))
        loadContinuation = nil
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: Failure.loadFailed(error.localizedDescription))
        loadContinuation = nil
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased() ?? "about"
        decisionHandler(["file", "about", "data"].contains(scheme) ? .allow : .cancel)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadContinuation?.resume(throwing: Failure.loadFailed("web content process terminated"))
        loadContinuation = nil
    }
}
