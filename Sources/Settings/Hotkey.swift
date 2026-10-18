import AppKit
import Carbon.HIToolbox
import SwiftUI
import HaloCore

/// A global shortcut: Carbon virtual key code + Cocoa modifier flags, as
/// stored in `AppSettings.dropRingKeyCode` / `dropRingModifiers`.
struct Hotkey: Equatable, Sendable {
    var keyCode: Int
    var modifiers: NSEvent.ModifierFlags

    static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    /// ⌃⌥Space (D-004).
    static let `default` = Hotkey(keyCode: kVK_Space, modifiers: [.control, .option])

    init(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantModifiers)
    }

    init(keyCode: Int, rawModifiers: Int) {
        self.init(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: UInt(max(0, rawModifiers))))
    }

    var rawModifiers: Int { Int(modifiers.rawValue) }

    enum Issue: Equatable {
        /// macOS refuses Option-only / Option+Shift hotkeys, and plain keys
        /// would fire while typing. Every Halo hotkey includes ⌘ or ⌃.
        case needsCommandOrControl
        case modifierOnly
        case reserved(String)

        var message: String {
            switch self {
            case .needsCommandOrControl: String(localized: "Include ⌘ or ⌃, for example ⌃⌥Space.")
            case .modifierOnly: String(localized: "Add a key to go with the modifiers.")
            case .reserved(let owner): String(localized: "macOS already uses that for \(owner).")
            }
        }
    }

    /// nil when the shortcut can be registered.
    var issue: Issue? {
        if Self.modifierKeyCodes.contains(keyCode) { return .modifierOnly }
        guard modifiers.contains(.command) || modifiers.contains(.control) else { return .needsCommandOrControl }
        if let owner = Self.reserved[ReservedKey(keyCode: keyCode, modifiers: modifiers.rawValue)] { return .reserved(owner) }
        return nil
    }

    var isValid: Bool { issue == nil }

    /// "⌃⌥Space", in Apple's modifier order.
    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + Self.keyName(keyCode)
    }

    // MARK: Tables

    private struct ReservedKey: Hashable {
        let keyCode: Int
        let modifiers: UInt
    }

    private static let reserved: [ReservedKey: String] = {
        func k(_ code: Int, _ m: NSEvent.ModifierFlags) -> ReservedKey { ReservedKey(keyCode: code, modifiers: m.rawValue) }
        return [
            k(kVK_Space, [.command]): String(localized: "Spotlight"),
            k(kVK_Space, [.command, .option]): String(localized: "Finder search"),
            k(kVK_Space, [.control]): String(localized: "switching input sources"),
            k(kVK_Tab, [.command]): String(localized: "switching apps"),
            k(kVK_ANSI_Q, [.command]): String(localized: "Quit"),
            k(kVK_ANSI_W, [.command]): String(localized: "Close Window"),
            k(kVK_ANSI_H, [.command]): String(localized: "Hide"),
            k(kVK_ANSI_M, [.command]): String(localized: "Minimise"),
            k(kVK_ANSI_3, [.command, .shift]): String(localized: "screenshots"),
            k(kVK_ANSI_4, [.command, .shift]): String(localized: "screenshots"),
            k(kVK_ANSI_5, [.command, .shift]): String(localized: "screenshots"),
            k(kVK_UpArrow, [.control]): String(localized: "Mission Control"),
            k(kVK_DownArrow, [.control]): String(localized: "App Exposé"),
            k(kVK_LeftArrow, [.control]): String(localized: "switching Spaces"),
            k(kVK_RightArrow, [.control]): String(localized: "switching Spaces"),
            k(kVK_ANSI_Q, [.command, .control]): String(localized: "Lock Screen"),
        ]
    }()

    static let modifierKeyCodes: Set<Int> = [
        kVK_Shift, kVK_RightShift, kVK_Command, kVK_RightCommand, kVK_Control, kVK_RightControl,
        kVK_Option, kVK_RightOption, kVK_Function, kVK_CapsLock,
    ]

    static func keyName(_ code: Int) -> String {
        if let named = namedKeys[code] { return named }
        if let c = characterKeys[code] { return c }
        return String(localized: "Key \(code)")
    }

    private static let namedKeys: [Int: String] = [
        kVK_Space: String(localized: "Space", comment: "Key name"),
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18",
        kVK_F19: "F19", kVK_F20: "F20",
    ]

    /// US-ANSI positions; good enough for display (the key code is what's stored).
    private static let characterKeys: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E", kVK_ANSI_F: "F",
        kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R",
        kVK_ANSI_S: "S", kVK_ANSI_T: "T", kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".",
        kVK_ANSI_Slash: "/", kVK_ANSI_Backslash: "\\", kVK_ANSI_Grave: "`",
    ]
}

// MARK: - Recorder

/// Click, then press the new shortcut. Esc cancels. Invalid shortcuts are
/// explained inline and not saved.
struct HotkeyRecorder: View {
    @Binding var hotkey: Hotkey
    var onChange: () -> Void = {}

    @State private var recording = false
    @State private var issue: Hotkey.Issue?
    @State private var monitor: LocalKeyMonitor?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: DesignTokens.Space.s) {
                if hotkey != .default && !recording {
                    Button {
                        hotkey = .default
                        issue = nil
                        onChange()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help(Text("Restore \(Hotkey.default.displayString)"))
                    .accessibilityLabel(Text("Restore default shortcut"))
                }
                Button(action: toggleRecording) {
                    Text(verbatim: recording ? String(localized: "Type shortcut…") : hotkey.displayString)
                        .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium, design: recording ? .default : .rounded))
                        .foregroundStyle(recording ? Color.iris : Color.primary)
                        .frame(minWidth: 96)
                }
                .buttonStyle(.bordered)
                .tint(nil)
                .overlay {
                    if recording {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.iris, lineWidth: 1.5)
                    }
                }
                .accessibilityIdentifier("keys.hotkeyRecorder")
                .accessibilityLabel(Text("Drop ring shortcut"))
                .accessibilityValue(Text(verbatim: hotkey.displayString))
            }
            if let issue {
                Text(verbatim: issue.message)
                    .font(.system(size: DesignTokens.TypeRamp.caption))
                    .foregroundStyle(Color.haloDanger)
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggleRecording() {
        recording ? stop() : start()
    }

    private func start() {
        issue = nil
        recording = true
        let m = LocalKeyMonitor(onKeyDown: { event in
            handle(event)
            return true
        })
        m.start()
        monitor = m
    }

    private func stop() {
        monitor?.stop()
        monitor = nil
        recording = false
    }

    private func handle(_ event: NSEvent) {
        let code = Int(event.keyCode)
        let mods = event.modifierFlags.intersection(Hotkey.relevantModifiers)
        if code == kVK_Escape && mods.isEmpty {
            issue = nil
            stop()
            return
        }
        let candidate = Hotkey(keyCode: code, modifiers: mods)
        if let problem = candidate.issue {
            issue = problem
            NSSound.beep()
            return
        }
        issue = nil
        hotkey = candidate
        stop()
        onChange()
    }
}
