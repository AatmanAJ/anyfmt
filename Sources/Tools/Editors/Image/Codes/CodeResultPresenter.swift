import AppKit
import SwiftUI
import HaloCore

/// Shows what Read QR / barcode found (tool 11): a small floating window
/// listing every payload with a Copy button. Links are never opened on their
/// own: "Open link…" first shows the full URL and asks.
@MainActor
public enum CodeResultPresenter {
    private static var panels: [NSPanel] = []

    /// Presents results, copying them to the clipboard straight away (the
    /// tool's promise: "copies result"). Returns the panel for tests.
    @discardableResult
    public static func present(results: [CodeReadResult], source: String? = nil, copyToClipboard: Bool = true) -> NSPanel {
        if copyToClipboard, !results.isEmpty { copy(results.map(\.payload).joined(separator: "\n")) }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
                            styleMask: [.titled, .closable, .fullSizeContentView, .utilityWindow], backing: .buffered, defer: false)
        panel.title = results.count == 1 ? String(localized: "1 code found") : String(localized: "\(results.count) codes found")
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        let view = CodeResultsView(results: results, source: source, copiedAll: copyToClipboard) { [weak panel] in panel?.close() }
        let hosting = NSHostingController(rootView: view)
        panel.contentViewController = hosting
        panel.setContentSize(hosting.view.fittingSize)
        panel.center()
        panels.append(panel)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { note in
            let closing = note.object as? NSPanel
            MainActor.assumeIsolated { panels.removeAll { $0 === closing } }
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        return panel
    }

    /// Presents the `.txt` the tool wrote.
    @discardableResult
    public static func present(fileAt url: URL) -> NSPanel {
        present(results: CodeReader.parse(fileAt: url), source: url.lastPathComponent)
    }

    /// The general pasteboard; tests swap in a private one.
    static var pasteboard: NSPasteboard = .general

    static func copy(_ text: String) {
        let pb = pasteboard
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// Asks before opening; shows the whole URL so look-alike links are visible.
    static func confirmOpen(_ url: URL, attachedTo window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Open this link?")
        alert.informativeText = url.absoluteString
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Open"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        let open = { NSWorkspace.shared.open(url) }
        if let window {
            alert.beginSheetModal(for: window) { response in if response == .alertFirstButtonReturn { _ = open() } }
        } else if alert.runModal() == .alertFirstButtonReturn {
            _ = open()
        }
    }
}

struct CodeResultsView: View {
    let results: [CodeReadResult]
    let source: String?
    let copiedAll: Bool
    let onDone: () -> Void

    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
            if results.isEmpty {
                Label(String(localized: "No codes found"), systemImage: "qrcode.viewfinder")
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: DesignTokens.Space.s) {
                    ForEach(results) { r in row(r) }
                }
            }
            .frame(maxHeight: 360)
            .fixedSize(horizontal: false, vertical: results.count <= 4)
            HStack {
                if copiedAll && !results.isEmpty {
                    Label(String(localized: "Copied to the clipboard"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: DesignTokens.TypeRamp.caption))
                        .foregroundStyle(ImageEditorKit.mint)
                }
                Spacer()
                if results.count > 1 {
                    Button(String(localized: "Copy all")) {
                        CodeResultPresenter.copy(results.map(\.payload).joined(separator: "\n"))
                        flash("*")
                    }
                }
                Button(String(localized: "Done"), action: onDone)
                    .keyboardShortcut(.defaultAction)
                Button("", action: onDone).keyboardShortcut(.cancelAction).frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
            }
        }
        .padding(DesignTokens.Space.l)
        .frame(width: 420)
    }

    private func row(_ r: CodeReadResult) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.m) {
            Image(systemName: r.symbology.contains("QR") || r.symbology == "Aztec" || r.symbology == "DataMatrix" ? "qrcode" : "barcode")
                .font(.system(size: 18))
                .foregroundStyle(ImageEditorKit.accent)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(r.label)
                    .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(r.payload)
                    .font(.system(size: DesignTokens.TypeRamp.body, design: r.link == nil && r.payload.allSatisfy(\.isNumber) ? .monospaced : .default))
                    .textSelection(.enabled)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Button(copied == r.id ? String(localized: "Copied") : String(localized: "Copy")) {
                    CodeResultPresenter.copy(r.payload)
                    flash(r.id)
                }
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Copy \(r.label)"))
                if let link = r.link {
                    Button(String(localized: "Open link…")) {
                        CodeResultPresenter.confirmOpen(link, attachedTo: NSApp.keyWindow)
                    }
                    .controlSize(.small)
                    .help(link.absoluteString)
                }
            }
        }
        .padding(DesignTokens.Space.m)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium).fill(Color.primary.opacity(0.05)))
        .accessibilityElement(children: .contain)
    }

    private func flash(_ id: String) {
        copied = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { if copied == id { copied = nil } }
    }
}
