import AppKit
import SwiftUI

/// Editor keyboard commands (space, arrows, I/O, …). macOS 13 has no
/// `onKeyPress`, so a local event monitor scoped to the editor's own window
/// handles them. Keys typed into a text field are left alone.
enum EditorKey: Hashable {
    case space, left, right, shiftLeft, shiftRight, delete, character(Character), command(Character)
}

struct KeyMonitor: NSViewRepresentable {
    /// Return true when handled (the event is then swallowed).
    let handler: (EditorKey) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let v = MonitorView()
        v.handler = handler
        return v
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.handler = handler
    }

    final class MonitorView: NSView {
        var handler: ((EditorKey) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                let handled = MainActor.assumeIsolated { self.handle(event) }
                return handled ? nil : event
            }
        }

        override func removeFromSuperview() {
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            super.removeFromSuperview()
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard let window, event.window === window, let handler else { return false }
            if window.firstResponder is NSText { return false } // typing in a field
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let key: EditorKey?
            switch event.keyCode {
            case 49 where mods.isEmpty: key = .space
            case 123: key = mods == .shift ? .shiftLeft : (mods.isEmpty ? .left : nil)
            case 124: key = mods == .shift ? .shiftRight : (mods.isEmpty ? .right : nil)
            case 51, 117: key = mods.isEmpty ? .delete : nil
            default:
                guard let c = event.charactersIgnoringModifiers?.lowercased().first else { return false }
                if mods == .command { key = .command(c) } else if mods.isEmpty { key = .character(c) } else { key = nil }
            }
            guard let key else { return false }
            return handler(key)
        }
    }
}
