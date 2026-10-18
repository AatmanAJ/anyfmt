import AppKit
import SwiftUI

/// A borderless, non-activating floating panel holding one progress card.
/// It never becomes key or main, so Finder keeps focus and keystrokes.
final class ProgressPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        // The card draws its own soft shadow inside the panel's margin.
        hasShadow = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
        setAccessibilitySubrole(.floatingWindow)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosts a card: clicks work without activating the app, hover is tracked even
/// while Finder is frontmost, and content size changes are reported.
final class ProgressHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChange: ((Bool) -> Void)?
    var onContentSizeChange: (() -> Void)?
    /// Hover only counts over the card itself, not its transparent shadow margin.
    var hoverInset: CGFloat = 0
    private var hoverArea: NSTrackingArea?
    private var sizeChangeScheduled = false

    required init(rootView: Content) {
        super.init(rootView: rootView)
        // Only report the ideal size; never let Auto Layout resize the panel behind the presenter's back.
        sizingOptions = [.intrinsicContentSize]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let rect = bounds.insetBy(dx: hoverInset, dy: hoverInset)
        guard rect.width > 0, rect.height > 0 else { hoverArea = nil; return }
        let area = NSTrackingArea(rect: rect, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea === hoverArea { onHoverChange?(true) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === hoverArea { onHoverChange?(false) }
    }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // Coalesce: SwiftUI may invalidate several times in one update.
        guard !sizeChangeScheduled, onContentSizeChange != nil else { return }
        sizeChangeScheduled = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.sizeChangeScheduled = false
                self?.onContentSizeChange?()
            }
        }
    }
}
