import AppKit
import SwiftUI
import HaloCore

/// Lane G1 editors: crop, adjust, annotate, redact, add background, collage,
/// images → PDF and metadata. Each is a `ToolEditorModel` + views inside the
/// shared `EditorShell`.
@MainActor
enum ImageEditors {
    /// Tools that open an editor here.
    static let tools: [ToolID] = [
        ToolIDs.cropImage, ToolIDs.adjustImage, ToolIDs.annotateImage, ToolIDs.redactImage,
        ToolIDs.addBackground, ToolIDs.collage, ToolIDs.imagesToPDF, ToolIDs.editMetadata,
    ]

    /// A built editor: its model, window title and size, and a view factory.
    struct Built {
        let model: any ToolEditorModel
        let title: String
        let size: NSSize
        let makeView: (_ onSave: @escaping (EditorResult) -> Void, _ onClose: @escaping () -> Void) -> AnyView
    }

    static func open(_ tool: ToolSpec, inputs: [URL], onSave: @escaping (EditorResult) -> Void) -> Bool {
        guard let built = make(tool, inputs: inputs) else { return false }
        let box = ImageEditorWindowBox()
        let view = built.makeView({ result in
            onSave(result)
            box.close()
        }, { box.close() })
        let controller = EditorWindow.present(title: built.title, content: view)
        if let window = controller.window, window.frame.size != built.size {
            window.setContentSize(built.size)
            window.center()
        }
        box.controller = controller
        return true
    }

    /// Builds the editor for `tool`, or nil when it isn't one of ours or the inputs don't fit.
    static func make(_ tool: ToolSpec, inputs: [URL]) -> Built? {
        guard tools.contains(tool.id), !inputs.isEmpty else { return nil }
        let formats = inputs.compactMap(Formats.detect)
        guard formats.count == inputs.count, tool.applies(to: formats) else { return nil }
        let name = inputs.count == 1 ? inputs[0].lastPathComponent : String(localized: "\(inputs.count) images")
        let title = "\(tool.title) — \(name)"
        let standard = EditorWindow.defaultSize
        switch tool.id {
        case ToolIDs.cropImage:
            let m = ImageCropModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: standard) { s, c in AnyView(ImageCropEditor(model: m, onSave: s, onClose: c)) }
        case ToolIDs.adjustImage:
            let m = ImageAdjustModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: standard) { s, c in AnyView(ImageAdjustEditor(model: m, onSave: s, onClose: c)) }
        case ToolIDs.annotateImage:
            let m = ImageAnnotateModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: NSSize(width: 1040, height: 700)) { s, c in AnyView(ImageAnnotateEditor(model: m, onSave: s, onClose: c)) }
        case ToolIDs.redactImage:
            let m = ImageRedactModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: standard) { s, c in AnyView(ImageRedactEditor(model: m, onSave: s, onClose: c)) }
        case ToolIDs.addBackground:
            let m = ImageBackgroundModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: standard) { s, c in AnyView(ImageBackgroundEditor(model: m, onSave: s, onClose: c)) }
        case ToolIDs.collage:
            let m = ImageCollageModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: NSSize(width: 1040, height: 700)) { s, c in AnyView(ImageCollageEditor(model: m, onSave: s, onClose: c)) }
        case ToolIDs.imagesToPDF:
            let m = ImagesPDFModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: NSSize(width: 1000, height: 680)) { s, c in AnyView(ImagesPDFEditor(model: m, onSave: s, onClose: c)) }
        case ToolIDs.editMetadata:
            let m = MetadataEditorModel(tool: tool, inputs: inputs)
            return Built(model: m, title: title, size: NSSize(width: 940, height: 660)) { s, c in AnyView(MetadataEditor(model: m, onSave: s, onClose: c)) }
        default:
            return nil
        }
    }
}
