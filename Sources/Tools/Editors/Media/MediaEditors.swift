import AppKit
import SwiftUI
import AnyfmtCore

/// Editor models in this lane also start/stop their media.
@MainActor
protocol MediaEditorModel: ToolEditorModel {
    func start()
    func teardown()
    /// Window title detail ("clip.mp4", "3 clips").
    var subject: String { get }
    /// Waits until media, thumbnails and stills are loaded (offscreen renders, tests).
    func settle() async
}

extension MediaEditorModel {
    var subject: String {
        inputs.count == 1 ? inputs[0].lastPathComponent : String(localized: "\(inputs.count) files")
    }
}

extension MediaSession {
    /// Waits for load, then thumbnails and the paused still.
    func settle(timeout: Double = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !state.isReady, Date() < deadline {
            if case .failed = state { return }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        if isVideo {
            await filmstrip.waitUntilComplete()
            await player.waitForStill()
        }
    }
}

/// Opens lane G2's editors: trim/crop/split/join/snapshot video, trim audio,
/// bleep, organise PDF pages.
@MainActor
enum MediaEditors {
    static let editorTools: [ToolID] = [
        ToolIDs.trimVideo, ToolIDs.cropVideo, ToolIDs.splitVideo, ToolIDs.joinVideo, ToolIDs.snapshotVideo,
        ToolIDs.trimAudio, ToolIDs.bleepAudio, ToolIDs.organizePDF,
    ]

    static func open(_ tool: ToolSpec, inputs: [URL], onSave: @escaping (EditorResult) -> Void) -> Bool {
        guard editorTools.contains(tool.id), !inputs.isEmpty else { return false }
        final class Box { var window: EditorWindow? }
        let box = Box()
        guard let editor = makeEditor(tool, inputs: inputs,
                                      onSave: { result in onSave(result); box.window?.close() },
                                      onClose: { box.window?.close() }) else { return false }
        editor.start()
        let title = "\(tool.title) — \(editor.subject)"
        box.window = EditorWindow.present(title: title, content: editor.view, onClose: { editor.teardown() })
        return true
    }

    /// A built editor: its root view plus lifecycle hooks. Tests render `view` offscreen.
    @MainActor
    struct Editor {
        let view: AnyView
        let model: any MediaEditorModel
        func start() { model.start() }
        func teardown() { model.teardown() }
        var subject: String { model.subject }
    }

    static func makeEditor(_ tool: ToolSpec, inputs: [URL], options: OptionValues? = nil,
                           onSave: @escaping (EditorResult) -> Void, onClose: @escaping () -> Void) -> Editor? {
        let opts = options ?? tool.defaultOptions
        switch tool.id {
        case ToolIDs.trimVideo:
            let m = TrimVideoModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(TrimVideoEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        case ToolIDs.cropVideo:
            let m = CropVideoModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(CropVideoEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        case ToolIDs.splitVideo:
            let m = SplitVideoModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(SplitVideoEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        case ToolIDs.joinVideo:
            let m = JoinVideoModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(JoinVideoEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        case ToolIDs.snapshotVideo:
            let m = SnapshotVideoModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(SnapshotVideoEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        case ToolIDs.trimAudio:
            let m = TrimAudioModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(TrimAudioEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        case ToolIDs.bleepAudio:
            let m = BleepAudioModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(BleepAudioEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        case ToolIDs.organizePDF:
            let m = OrganizePDFModel(tool: tool, inputs: inputs, options: opts)
            return Editor(view: AnyView(OrganizePDFEditor(model: m, onSave: onSave, onClose: onClose)), model: m)
        default:
            return nil
        }
    }
}
