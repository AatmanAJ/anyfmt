import AppKit

/// One VoiceOver element per segment: a radio button ("JPG, radio button,
/// selected, 3 of 8") that can be pressed. AppKit calls accessibility
/// methods on the main thread.
final class RadialSegmentElement: NSAccessibilityElement, @unchecked Sendable {
    private nonisolated(unsafe) weak var menu: RadialMenuView?
    let slot: Int

    @MainActor
    init(menu: RadialMenuView, slot: Int) {
        self.menu = menu
        self.slot = slot
        super.init()
        setAccessibilityParent(menu)
        setAccessibilityRole(.radioButton)
        if let item = menu.accessibilityItem(forSlot: slot) {
            setAccessibilityLabel(item.spokenLabel)
            setAccessibilityHelp(item.accessibilityHint)
            setAccessibilityEnabled(item.isEnabled)
        }
        setAccessibilityFrameInParentSpace(menu.frame(forSlot: slot))
        refreshSelection()
    }

    @MainActor
    func refreshSelection() {
        let selected = menu?.accessibilitySelectedSlot == slot
        setAccessibilitySelected(selected)
        setAccessibilityValue(selected ? 1 : 0)
    }

    override func accessibilityPerformPress() -> Bool {
        let menu = self.menu, slot = self.slot
        return MainActor.assumeIsolated {
            guard let menu else { return false }
            menu.setHighlightedSlot(slot, animated: true)
            return menu.activate(slot: slot)
        }
    }

    override func isAccessibilityFocused() -> Bool {
        let menu = self.menu, slot = self.slot
        return MainActor.assumeIsolated { menu?.accessibilitySelectedSlot == slot }
    }
}
