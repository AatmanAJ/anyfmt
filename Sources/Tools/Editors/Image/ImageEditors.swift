import AppKit
import HaloCore

// Owned by lane G1. Placeholder until the lane lands.
@MainActor
enum ImageEditors {
    static func open(_ tool: ToolSpec, inputs: [URL], onSave: @escaping (EditorResult) -> Void) -> Bool { false }
}
