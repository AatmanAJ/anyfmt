import AppKit
import SwiftUI
import AnyfmtCore

// Shared shell for every tool editor (BUILD.md §7): live preview, before/after
// toggle, options sidebar, "Save copy" primary pill, Esc closes.
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

extension ToolEditorModel {
    /// The line under the editor's title: the file name, or how many files.
    var editorSubject: String {
        inputs.count == 1 ? inputs[0].lastPathComponent : String(localized: "\(inputs.count) files")
    }
}

/// The standard editor layout: the canvas in a black well on the left with the
/// compare toggle and status under it; on the right the editor's name in heavy
/// display type, its options as charcoal tiles, then Cancel and Save copy.
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
        HStack(alignment: .top, spacing: EditorTokens.gutter) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
                ZStack(alignment: .topLeading) {
                    preview(showOriginal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if showOriginal {
                        OverlayBadge(text: String(localized: "Original"))
                            .padding(DesignTokens.Space.m)
                            .accessibilityHidden(true)
                    }
                }
                .background(EditorPalette.canvas)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
                HStack(spacing: DesignTokens.Space.m) {
                    BeforeAfterToggle(showOriginal: $showOriginal)
                    if let s = model.statusLine {
                        Text(s)
                            .font(.system(size: DesignTokens.TypeRamp.label, weight: .medium).monospacedDigit())
                            .foregroundStyle(Color.anyfmtSecondaryText)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                    DisplayText(EditorTitle.display(model.tool), size: EditorTokens.titleSize)
                        .lineLimit(1)
                        .foregroundStyle(Color.anyfmtInk)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.editorSubject)
                        .font(.system(size: DesignTokens.TypeRamp.label, weight: .medium))
                        .foregroundStyle(Color.anyfmtSecondaryText)
                        .lineLimit(1).truncationMode(.middle)
                }
                .padding(.bottom, DesignTokens.Space.l)
                ScrollView {
                    VStack(alignment: .leading, spacing: EditorTokens.sectionSpacing) {
                        sidebar()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: DesignTokens.Space.s) {
                    Button(String(localized: "Cancel"), action: onClose)
                        .buttonStyle(.anyfmtQuiet)
                        .keyboardShortcut(.cancelAction)
                    Spacer(minLength: 0)
                    Button(String(localized: "Save copy")) {
                        onSave(EditorResult(tool: model.tool.id, inputs: model.inputs, options: model.options))
                    }
                    .buttonStyle(AnyfmtPillButtonStyle(kind: .primary, large: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSave)
                }
                .padding(.top, DesignTokens.Space.l)
            }
            .frame(width: EditorWindow.sidebarWidth)
        }
        .buttonStyle(.editorChip)
        .toggleStyle(.editorSwitch)
        .padding(EditorTokens.gutter)
        .foregroundStyle(Color.anyfmtInk, Color.anyfmtSecondaryText)
        .tint(Color.iris)
        .background(Color.anyfmtWindow.ignoresSafeArea())
    }
}

/// Hosts an editor in a standard window. Escape closes (via the Cancel button's
/// `.cancelAction` shortcut). Windows cascade and remember nothing between runs.
@MainActor
public final class EditorWindow: NSWindowController, NSWindowDelegate {
    public static let sidebarWidth: CGFloat = EditorTokens.sidebarWidth
    public static let defaultSize = NSSize(width: 1000, height: 660)
    private static var open: [EditorWindow] = []

    private var onCloseHandler: (() -> Void)?

    /// Presents `content` (an `EditorShell`) titled after the tool and first input.
    public static func present<Content: View>(title: String, content: Content, size: NSSize = defaultSize,
                                              onClose: (() -> Void)? = nil) -> EditorWindow {
        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        // The chrome is the window: near-black (dark) or white (light), up into the title bar.
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .anyfmt(DesignTokens.Semantic.windowBackground)
        window.setContentSize(size)
        window.contentMinSize = NSSize(width: 760, height: 480)
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
