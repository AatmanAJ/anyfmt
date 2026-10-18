import AppKit
import SwiftUI
import HaloCore

// Shared shell for every tool editor (BUILD.md §7): live preview, before/after
// toggle, options sidebar, "Save copy" primary button, Esc closes.
// Contract between lanes G1 (image + metadata tools) and G2 (video, audio, PDF
// tools). Editors supply `preview(showOriginal:)` and `sidebar`; the shell owns
// layout, keyboard, window chrome and the save flow.

/// What an editor hands back when the user presses "Save copy".
public struct EditorResult: Sendable {
    public let tool: ToolID
    public let inputs: [URL]
    public let options: OptionValues
    public init(tool: ToolID, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        self.options = options
    }
}

/// Implemented by each editor's view model.
@MainActor
public protocol ToolEditorModel: ObservableObject {
    var tool: ToolSpec { get }
    var inputs: [URL] { get }
    /// Current options; "Save copy" submits these.
    var options: OptionValues { get }
    /// False disables "Save copy" (e.g. nothing selected yet).
    var canSave: Bool { get }
    /// Optional one-line status under the preview ("1920 × 1080 → 960 × 540").
    var statusLine: String? { get }
}

public extension ToolEditorModel {
    var canSave: Bool { true }
    var statusLine: String? { nil }
}

/// The standard editor layout.
public struct EditorShell<Model: ToolEditorModel, Preview: View, Sidebar: View>: View {
    @ObservedObject var model: Model
    let preview: (_ showOriginal: Bool) -> Preview
    let sidebar: () -> Sidebar
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void
    @State private var showOriginal = false

    public init(model: Model,
                @ViewBuilder preview: @escaping (_ showOriginal: Bool) -> Preview,
                @ViewBuilder sidebar: @escaping () -> Sidebar,
                onSave: @escaping (EditorResult) -> Void,
                onClose: @escaping () -> Void) {
        self.model = model
        self.preview = preview
        self.sidebar = sidebar
        self.onSave = onSave
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    preview(showOriginal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: .underPageBackgroundColor))
                    if showOriginal {
                        Text("Original", bundle: .main)
                            .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.thinMaterial, in: Capsule())
                            .padding(DesignTokens.Space.m)
                            .accessibilityHidden(true)
                    }
                }
                Divider()
                HStack(spacing: DesignTokens.Space.m) {
                    Toggle(isOn: $showOriginal) {
                        Label(String(localized: "Before / After"), systemImage: "square.split.2x1")
                    }
                    .toggleStyle(.button)
                    .help(String(localized: "Compare with the original (B)"))
                    .keyboardShortcut("b", modifiers: [])
                    if let s = model.statusLine {
                        Text(s).font(.system(size: DesignTokens.TypeRamp.caption)).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Space.l)
                .padding(.vertical, DesignTokens.Space.s)
            }
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.l) {
                        sidebar()
                    }
                    .padding(DesignTokens.Space.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack {
                    Button(String(localized: "Cancel"), action: onClose)
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(String(localized: "Save copy")) {
                        onSave(EditorResult(tool: model.tool.id, inputs: model.inputs, options: model.options))
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSave)
                }
                .padding(DesignTokens.Space.l)
            }
            .frame(width: EditorWindow.sidebarWidth)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

/// Hosts an editor in a standard window. Escape closes (via the Cancel button's
/// `.cancelAction` shortcut). Windows cascade and remember nothing between runs.
@MainActor
public final class EditorWindow: NSWindowController, NSWindowDelegate {
    public static let sidebarWidth: CGFloat = 280
    public static let defaultSize = NSSize(width: 980, height: 640)
    private static var open: [EditorWindow] = []

    private var onCloseHandler: (() -> Void)?

    /// Presents `content` (an `EditorShell`) titled after the tool and first input.
    public static func present<Content: View>(title: String, content: Content, size: NSSize = defaultSize,
                                              onClose: (() -> Void)? = nil) -> EditorWindow {
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = false
        window.setContentSize(size)
        window.contentMinSize = NSSize(width: 720, height: 460)
        window.isReleasedWhenClosed = false
        window.center()
        if let last = open.last?.window {
            window.setFrameTopLeftPoint(window.cascadeTopLeft(from: NSPoint(x: last.frame.minX, y: last.frame.maxY)))
        }
        let controller = EditorWindow(window: window)
        controller.onCloseHandler = onClose
        window.delegate = controller
        open.append(controller)
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        return controller
    }

    public func windowWillClose(_ notification: Notification) {
        onCloseHandler?()
        EditorWindow.open.removeAll { $0 === self }
    }
}
