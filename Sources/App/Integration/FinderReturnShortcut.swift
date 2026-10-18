import AppKit
import ApplicationServices
import HaloCore

/// Opt-in "press Return on a Finder selection to open the wheel" (D-004).
/// Needs Accessibility (an active event tap that can swallow Return before
/// Finder starts renaming) and Automation → Finder (to read the selection).
/// Return passes through untouched while Finder is renaming (a text field has
/// focus), when Finder isn't frontmost, and when nothing is selected.
@MainActor
final class FinderReturnShortcut {
    enum Failure { case accessibility, inputMonitoring, unknown }
    /// Why the last `start()` failed, for a one-line explanation to the user.
    private(set) var lastFailure: Failure?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let onTrigger: @MainActor () -> Void

    init(onTrigger: @escaping @MainActor () -> Void) {
        self.onTrigger = onTrigger
    }

    var isActive: Bool { tap != nil }

    /// Starts the tap if permitted. Returns false when Accessibility isn't granted.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard AXIsProcessTrusted() else {
            lastFailure = .accessibility
            return false
        }
        // A tap that sees key presses also needs Input Monitoring on current macOS.
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: { _, type, event, refcon in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let refcon { Unmanaged<FinderReturnShortcut>.fromOpaque(refcon).takeUnretainedValue().reenable() }
                return Unmanaged.passUnretained(event)
            }
            guard type == .keyDown, let refcon else { return Unmanaged.passUnretained(event) }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            // Return (36) or keypad Enter (76), no modifiers.
            guard keyCode == 36 || keyCode == 76, flags.isEmpty else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<FinderReturnShortcut>.fromOpaque(refcon).takeUnretainedValue()
            guard FinderReturnShortcut.shouldIntercept() else { return Unmanaged.passUnretained(event) }
            DispatchQueue.main.async { MainActor.assumeIsolated { me.onTrigger() } }
            return nil // swallow: Finder doesn't start a rename
        }, userInfo: refcon) else {
            lastFailure = CGPreflightListenEventAccess() ? .unknown : .inputMonitoring
            Log.app.error("finder return tap: tapCreate failed (accessibility \(AXIsProcessTrusted(), privacy: .public), input monitoring \(CGPreflightListenEventAccess(), privacy: .public))")
            return false
        }
        lastFailure = nil
        tap = t
        source = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        Log.app.info("finder return shortcut active")
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    nonisolated private func reenable() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { if let t = self.tap { CGEvent.tapEnable(tap: t, enable: true) } }
        }
    }

    /// Finder frontmost, a file view focused (not a rename/search field).
    nonisolated static func shouldIntercept() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier == FinderSelection.finderBundleID else {
            return false
        }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID() else { return false }
        var role: CFTypeRef?
        // The CFTypeRef is an AXUIElement (type id checked above).
        let el = unsafeDowncast(element, to: AXUIElement.self)
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &role)
        let r = role as? String ?? ""
        let textRoles: Set<String> = [kAXTextFieldRole as String, kAXTextAreaRole as String, "AXSearchField", kAXComboBoxRole as String]
        return !textRoles.contains(r)
    }
}
