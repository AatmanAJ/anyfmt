import AppKit
import AnyfmtCore

/// Opens the editor for a tool, or returns false if the tool has no editor in
/// this build. Lane G1 implements `ImageEditors.open`, lane G2 `MediaEditors.open`.
@MainActor
public enum EditorFactory {
    @discardableResult
    public static func open(_ tool: ToolSpec, inputs: [URL], onSave: @escaping (EditorResult) -> Void) -> Bool {
        if ImageEditors.open(tool, inputs: inputs, onSave: onSave) { return true }
        if MediaEditors.open(tool, inputs: inputs, onSave: onSave) { return true }
        return false
    }

    /// Shows extra UI for a finished tool job (e.g. the codes found by Read QR).
    /// Returns false when the tool has nothing to show beyond its files.
    @discardableResult
    public static func presentResult(_ tool: ToolSpec, outputs: [URL]) -> Bool {
        ImageEditors.presentResult(tool, outputs: outputs)
    }
}
