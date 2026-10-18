// DragSense: MIT licence, see LICENSE.
import AppKit
import Carbon

/// A system-wide keyboard shortcut via Carbon `RegisterEventHotKey`, which
/// needs **no** TCC permission and works from a background (LSUIElement) app.
///
/// Meant as the fallback trigger when a drag can't be sensed: for example a
/// shortcut that opens an empty drop ring at the pointer.
///
/// ```swift
/// let hotKey = GlobalHotKey(shortcut: .init(keyCode: UInt32(kVK_Space), modifiers: [.control, .option])) {
///     showDropRing()
/// }
/// try hotKey.register()
/// ```
///
/// Rules enforced by ``validate(_:)``:
/// - The shortcut must include ⌘ or ⌃. From macOS 15, Option-only and
///   Option+Shift-only hotkeys are refused for sandboxed apps; requiring ⌘ or
///   ⌃ keeps a shortcut portable and clear of text-entry combinations.
/// - fn can't be part of a Carbon hotkey.
/// - The key itself must not be a modifier key.
@MainActor
public final class GlobalHotKey {
    /// A key plus modifiers. `keyCode` is a virtual key code (`kVK_…` in
    /// Carbon's `Events.h`), layout-independent.
    public struct Shortcut: Hashable, Codable, Sendable {
        public var keyCode: UInt32
        public var modifiers: Set<ModifierKey>

        public init(keyCode: UInt32, modifiers: Set<ModifierKey>) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }

        /// Carbon modifier mask (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`).
        public var carbonModifiers: UInt32 {
            var mask: UInt32 = 0
            if modifiers.contains(.command) { mask |= UInt32(cmdKey) }
            if modifiers.contains(.shift) { mask |= UInt32(shiftKey) }
            if modifiers.contains(.option) { mask |= UInt32(optionKey) }
            if modifiers.contains(.control) { mask |= UInt32(controlKey) }
            return mask
        }

        /// Modifier glyphs in Apple's order, e.g. "⌃⌥". The key name is the
        /// host's job (it depends on the keyboard layout).
        public var modifierSymbols: String { ModifierKey.symbols(for: modifiers) }
    }

    public enum ValidationError: Error, Equatable, Sendable {
        /// The shortcut has neither ⌘ nor ⌃.
        case needsCommandOrControl
        /// fn isn't supported by Carbon hotkeys.
        case functionModifierUnsupported
        /// The key code is itself a modifier key.
        case keyIsModifier(UInt32)
    }

    public enum RegistrationError: Error, Equatable, Sendable {
        case invalid(ValidationError)
        /// Another app (or another `GlobalHotKey`) already holds this shortcut.
        case alreadyTaken
        /// Carbon returned this status.
        case failed(OSStatus)
    }

    /// Virtual key codes of the modifier keys themselves (⌘ ⇧ ⇪ ⌥ ⌃, both
    /// sides, and fn).
    public static let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    /// Checks the rules above; throws a ``ValidationError``.
    public static func validate(_ shortcut: Shortcut) throws {
        if let error = validationError(for: shortcut) { throw error }
    }

    /// The first rule `shortcut` breaks, or nil when it's valid.
    public static func validationError(for shortcut: Shortcut) -> ValidationError? {
        if modifierKeyCodes.contains(shortcut.keyCode) { return .keyIsModifier(shortcut.keyCode) }
        if shortcut.modifiers.contains(.function) { return .functionModifierUnsupported }
        if !shortcut.modifiers.contains(.command) && !shortcut.modifiers.contains(.control) {
            return .needsCommandOrControl
        }
        return nil
    }

    public let shortcut: Shortcut
    public var isRegistered: Bool { HotKeyCenter.shared.isRegistered(id) }

    private let id: UInt32
    private let handler: @MainActor () -> Void

    /// Creates an unregistered hotkey. `handler` runs on the main actor each
    /// time the shortcut is pressed.
    public init(shortcut: Shortcut, handler: @escaping @MainActor () -> Void) {
        self.shortcut = shortcut
        self.handler = handler
        self.id = HotKeyCenter.shared.allocateID()
    }

    deinit {
        let id = self.id
        Task { @MainActor in HotKeyCenter.shared.unregister(id) }
    }

    /// Registers the shortcut system-wide. Throws ``RegistrationError``.
    /// Registering an already-registered hotkey does nothing.
    public func register() throws {
        if let error = Self.validationError(for: shortcut) { throw RegistrationError.invalid(error) }
        guard !isRegistered else { return }
        try HotKeyCenter.shared.register(id: id, shortcut: shortcut, handler: handler)
    }

    /// Releases the shortcut. Safe to call when not registered.
    public func unregister() {
        HotKeyCenter.shared.unregister(id)
    }
}

/// Owns the single Carbon event handler and every registered hotkey.
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    /// 'DrSn'
    static let signature: OSType = 0x4472_536E

    private struct Entry {
        var ref: EventHotKeyRef
        var handler: @MainActor () -> Void
    }

    private var entries: [UInt32: Entry] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    func allocateID() -> UInt32 {
        defer { nextID &+= 1 }
        return nextID
    }

    func isRegistered(_ id: UInt32) -> Bool { entries[id] != nil }

    func register(id: UInt32, shortcut: GlobalHotKey.Shortcut, handler: @escaping @MainActor () -> Void) throws {
        try installEventHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref
        )
        guard status == noErr, let ref else {
            DragSenseLog.hotKey.error("RegisterEventHotKey failed: \(status, privacy: .public)")
            if status == OSStatus(eventHotKeyExistsErr) { throw GlobalHotKey.RegistrationError.alreadyTaken }
            throw GlobalHotKey.RegistrationError.failed(status)
        }
        entries[id] = Entry(ref: ref, handler: handler)
        DragSenseLog.hotKey.debug("registered hotkey \(id, privacy: .public) keyCode \(shortcut.keyCode, privacy: .public) \(shortcut.modifierSymbols, privacy: .public)")
    }

    func unregister(_ id: UInt32) {
        guard let entry = entries.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(entry.ref)
    }

    func dispatch(_ id: UInt32) {
        entries[id]?.handler()
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            guard let event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == HotKeyCenter.signature else {
                return OSStatus(eventNotHandledErr)
            }
            let id = hotKeyID.id
            // The application event target dispatches on the main thread.
            if Thread.isMainThread {
                MainActor.assumeIsolated { HotKeyCenter.shared.dispatch(id) }
            } else {
                DispatchQueue.main.async { HotKeyCenter.shared.dispatch(id) }
            }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        guard status == noErr else {
            DragSenseLog.hotKey.error("InstallEventHandler failed: \(status, privacy: .public)")
            throw GlobalHotKey.RegistrationError.failed(status)
        }
        eventHandler = handlerRef
    }
}
