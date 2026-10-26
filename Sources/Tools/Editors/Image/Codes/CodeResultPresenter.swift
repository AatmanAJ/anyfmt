import AppKit
import SwiftUI
import AnyfmtCore

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
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .anyfmt(DesignTokens.Semantic.windowBackground)
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
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                DisplayText(results.count == 1 ? String(localized: "1 code") : String(localized: "\(results.count) codes"),
                            size: DesignTokens.Typeface.Size.displayM)
                    .foregroundStyle(Color.anyfmtInk)
                    .accessibilityAddTraits(.isHeader)
                if let source {
                    Text(source).font(.system(size: DesignTokens.TypeRamp.label, weight: .medium))
                        .foregroundStyle(Color.anyfmtSecondaryText).lineLimit(1).truncationMode(.middle)
                }
            }
            if results.isEmpty {
                EditorStateView(kind: .empty, title: String(localized: "No codes found"),
                                message: String(localized: "Nothing readable in this picture. A closer, sharper shot of the code usually works."),
                                systemImage: "qrcode.viewfinder")
            }
            ScrollView {
                VStack(spacing: DesignTokens.Space.s) {
                    ForEach(results) { r in row(r) }
                }
            }
            .frame(maxHeight: 360)
            .fixedSize(horizontal: false, vertical: results.count <= 4)
            HStack(spacing: DesignTokens.Space.s) {
                if copiedAll && !results.isEmpty {
                    Label(String(localized: "Copied to the clipboard"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold))
                        .foregroundStyle(Color.anyfmtSuccess)
                }
                Spacer()
                if results.count > 1 {
                    Button(String(localized: "Copy all")) {
                        CodeResultPresenter.copy(results.map(\.payload).joined(separator: "\n"))
                        flash("*")
                    }
                    .buttonStyle(.anyfmtQuiet)
                }
                Button(String(localized: "Done"), action: onDone)
                    .buttonStyle(.anyfmtPrimary)
                    .keyboardShortcut(.defaultAction)
                Button("", action: onDone).keyboardShortcut(.cancelAction).frame(width: 0, height: 0).opacity(0).accessibilityHidden(true)
            }
        }
        .padding(DesignTokens.Space.l)
        .frame(width: 420)
        .buttonStyle(.editorChip)
        .foregroundStyle(Color.anyfmtInk, Color.anyfmtSecondaryText)
        .background(Color.anyfmtWindow.ignoresSafeArea())
    }

    private func row(_ r: CodeReadResult) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.m) {
            Image(systemName: r.symbology.contains("QR") || r.symbology == "Aztec" || r.symbology == "DataMatrix" ? "qrcode" : "barcode")
                .font(.system(size: DesignTokens.TypeRamp.headline - 2))
                .foregroundStyle(ImageEditorKit.accentText)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                EditorCaption(r.label)
                Text(r.payload)
                    .font(.system(size: DesignTokens.TypeRamp.body, design: r.link == nil && r.payload.allSatisfy(\.isNumber) ? .monospaced : .default))
                    .foregroundStyle(Color.anyfmtInk)
                    .textSelection(.enabled)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: DesignTokens.Space.xs) {
                Button {
                    CodeResultPresenter.copy(r.payload)
                    flash(r.id)
                } label: {
                    if copied == r.id {
                        Label(String(localized: "Copied"), systemImage: "checkmark")
                    } else {
                        Text(String(localized: "Copy"))
                    }
                }
                .buttonStyle(.editorChip(selected: copied == r.id))
                .accessibilityLabel(String(localized: "Copy \(r.label)"))
                if let link = r.link {
                    Button(String(localized: "Open link…")) {
                        CodeResultPresenter.confirmOpen(link, attachedTo: NSApp.keyWindow)
                    }
                    .help(link.absoluteString)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .anyfmtTile(padding: DesignTokens.Space.m)
        .accessibilityElement(children: .contain)
    }

    private func flash(_ id: String) {
        copied = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { if copied == id { copied = nil } }
    }
}
