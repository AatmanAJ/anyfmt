import AppKit
import HaloCore

// Owned by lane G2. Placeholder until the lane lands.
@MainActor
enum MediaEditors {
    static func open(_ tool: ToolSpec, inputs: [URL], onSave: @escaping (EditorResult) -> Void) -> Bool { false }
}
