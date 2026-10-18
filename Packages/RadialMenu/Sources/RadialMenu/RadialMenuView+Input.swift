import AppKit

// Drag destination, mouse and keyboard input.

extension RadialMenuView {
    // MARK: Dragging destination

    public override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    public override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    public override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        clearHover()
        setDropZoneTargeted(false)
        delegate?.radialMenuDragDidExit(self)
    }

    /// We only need updates when the pointer moves; dwell uses its own timer.
    public override func wantsPeriodicDraggingUpdates() -> Bool { false }

    public override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let point = convert(sender.draggingLocation, from: nil)
        if isShowingDropZone {
            return hypot(point.x - wheelCenter.x, point.y - wheelCenter.y) <= configuration.innerRing.outer + configuration.outerTolerance
        }
        updateHover(at: point, animated: false)
        guard let item = highlightedItem, item.isEnabled,
              delegate?.radialMenu(self, canAcceptDropOn: item, info: sender) ?? true else {
            // Dead zone, pager, disabled item or veto: the drop is refused (the
            // icon slides home) and the wheel closes.
            cancel()
            return false
        }
        return true
    }

    public override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if isShowingDropZone {
            return delegate?.radialMenu(self, didDropOnEmptyRing: sender) ?? false
        }
        guard let item = highlightedItem else { return false }
        return delegate?.radialMenu(self, didDrop: sender, on: item) ?? false
    }

    private func dragOperation(for info: any NSDraggingInfo) -> NSDragOperation {
        let point = convert(info.draggingLocation, from: nil)
        if isShowingDropZone {
            let inside = hypot(point.x - wheelCenter.x, point.y - wheelCenter.y)
                <= configuration.innerRing.outer + configuration.outerTolerance
            setDropZoneTargeted(inside)
            return inside ? .copy : []
        }
        updateHover(at: point)
        guard let item = highlightedItem, item.isEnabled,
              delegate?.radialMenu(self, canAcceptDropOn: item, info: info) ?? true else { return [] }
        // Copy, never move: the original always stays where it is.
        return .copy
    }

    // MARK: Mouse (keyboard mode, drop ring, onboarding demos)

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    public override func mouseMoved(with event: NSEvent) {
        guard !isShowingDropZone else { return }
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    public override func mouseExited(with event: NSEvent) {
        guard !isShowingDropZone else { return }
        clearHover()
    }

    public override func mouseDown(with event: NSEvent) {
        guard !isShowingDropZone else { return }
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    public override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if isShowingDropZone {
            // A click in the empty ring's hub dismisses it.
            if hypot(point.x - wheelCenter.x, point.y - wheelCenter.y) < configuration.hubRadius { cancel() }
            return
        }
        switch radialLayout.hitTest(relative(point), current: highlightedSlot) {
        case .slot(let s):
            setHighlightedSlot(s, animated: true)
            activate(slot: s)
        case .deadZone:
            cancel()
        case .outside:
            break
        }
    }

    public override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard case .slot(let s) = radialLayout.hitTest(relative(point)), let index = radialLayout.slots[s].itemIndex else { return }
        setHighlightedSlot(s, animated: true)
        if delegate?.radialMenu(self, hasOptionsFor: items[index]) == true {
            delegate?.radialMenu(self, didRequestOptionsFor: items[index], anchor: frame(forSlot: s))
        }
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Scroll (mouse wheel or trackpad) flips the outer ring's pages.
    public override func scrollWheel(with event: NSEvent) {
        guard radialLayout.isPaginated else { return }
        scrollAccumulatorDelta(event.scrollingDeltaY + event.scrollingDeltaX)
    }

    private func scrollAccumulatorDelta(_ delta: CGFloat) {
        scrollAccumulatorValue += delta
        let threshold: CGFloat = 24
        if abs(scrollAccumulatorValue) >= threshold {
            showPage(radialLayout.page + (scrollAccumulatorValue < 0 ? 1 : -1), animated: true)
            scrollAccumulatorValue = 0
        }
    }

    // MARK: Keyboard

    public override var acceptsFirstResponder: Bool { keyboardEnabled }

    public override func keyDown(with event: NSEvent) {
        guard keyboardEnabled, handleKey(event) else {
            super.keyDown(with: event)
            return
        }
    }

    /// Returns true if the key was handled. Exposed for hosts that route keys themselves.
    @discardableResult
    public func handleKey(_ event: NSEvent) -> Bool {
        let shift = event.modifierFlags.contains(.shift)
        switch event.keyCode {
        case 123: moveSelection(by: -1)                     // ←
        case 124: moveSelection(by: 1)                      // →
        case 126: radialLayout.hasOuterRing ? moveAcrossRing(outward: true) : moveSelection(by: -1)  // ↑
        case 125: radialLayout.hasOuterRing ? moveAcrossRing(outward: false) : moveSelection(by: 1)  // ↓
        case 36, 76: activateHighlighted()                  // Return, Enter
        case 53: cancel()                                   // Escape
        case 48: delegate?.radialMenu(self, didRequestNextMenu: !shift) // Tab
        case 116: showPage(radialLayout.page - 1, animated: true) // Page Up
        case 121: showPage(radialLayout.page + 1, animated: true) // Page Down
        default:
            guard let chars = event.charactersIgnoringModifiers, let digit = Int(chars), (1...9).contains(digit) else {
                return false
            }
            guard items.indices.contains(digit - 1) else {
                NSSound.beep()
                return true
            }
            highlightItem(at: digit - 1)
        }
        return true
    }

    func moveSelection(by delta: Int) {
        setHighlightedSlot(radialLayout.step(from: highlightedSlot, by: delta), animated: true)
    }

    func moveAcrossRing(outward: Bool) {
        guard let current = highlightedSlot else {
            setHighlightedSlot(radialLayout.step(from: nil, by: 1), animated: true)
            return
        }
        let ring = radialLayout.slots[current].ring
        if (outward && ring == 1) || (!outward && ring == 0) {
            moveSelection(by: outward ? -1 : 1)
        } else {
            setHighlightedSlot(radialLayout.acrossRing(from: current), animated: true)
        }
    }
}
