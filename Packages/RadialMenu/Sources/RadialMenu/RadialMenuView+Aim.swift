import AppKit
import QuartzCore

// Aiming: sticky selection, the lock, the tune lip and preset chips.
//
// Mid-drag the same pointer aims and (formerly) configured, so small drift picked
// the wrong segment. Here the selection is sticky (see `RadialLayout.stickySlack`
// and `switchDelay`), can be locked outright, and configuring happens after the
// drop (the lip or the tune modifier), so there's nothing left to mis-aim.

/// One preset chip outside the rim.
@MainActor
final class ChipNode {
    let preset: RadialPreset
    let layer = CAShapeLayer()
    let text = CATextLayer()
    /// View coordinates.
    var frame: CGRect = .zero

    init(preset: RadialPreset) {
        self.preset = preset
        layer.actions = SegmentNode.noActions
        text.actions = SegmentNode.noActions
        layer.addSublayer(text)
    }
}

extension RadialMenuView {
    func installAimLayers() {
        for l in [lipLayer, lockLayer] {
            l.actions = SegmentNode.noActions
            l.frame = bounds
            l.zPosition = 2
            l.opacity = 0
            overlayView.content.addSublayer(l)
        }
        lockLayer.fillColor = nil
        lockLayer.lineWidth = 2.5
        lockLayer.lineJoin = .round
    }

    /// Back to nothing locked, no chips, no lip (new items, new show).
    func resetAim() {
        cancelPendingSwitch()
        let wasLocked = isLocked
        isLocked = false
        hideChips()
        isInLip = false
        LayerAnimation.withoutActions {
            lipLayer.opacity = 0
            lockLayer.opacity = 0
        }
        dropTarget = nil
        if wasLocked { delegate?.radialMenu(self, didChangeLock: false) }
    }

    // MARK: Sticky hover

    func aimHover(at point: NSPoint, animated: Bool) {
        if let chip = chipIndex(at: point) {
            setHoveredChip(chip)
            return
        }
        setHoveredChip(nil)
        // Locked: the pointer can wander anywhere; the selection stays.
        if isLocked { return }
        switch radialLayout.hitTest(relative(point), current: highlightedSlot) {
        case .slot(let s):
            if s == highlightedSlot {
                cancelPendingSwitch()
            } else if highlightedSlot == nil || configuration.switchDelay <= 0 {
                cancelPendingSwitch()
                setHighlightedSlot(s, animated: animated)
            } else {
                deferSwitch(to: s, animated: animated)
            }
        case .deadZone, .outside:
            // On the way out to a chip, keep its segment selected.
            if isInChipCorridor(point) { return }
            cancelPendingSwitch()
            setHighlightedSlot(nil, animated: animated)
        }
        updateLip(at: point)
    }

    /// A different segment must stay under the pointer for `switchDelay` before it takes.
    private func deferSwitch(to slot: Int, animated: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        let delay = configuration.switchDelay
        if let pending = pendingSwitch, pending.slot == slot {
            if now - pending.since >= delay * 0.95 {
                cancelPendingSwitch()
                setHighlightedSlot(slot, animated: animated)
            }
            return
        }
        pendingSwitch = (slot, now)
        switchTask?.cancel()
        // Drags only report movement, so re-check once the delay has passed.
        switchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self, self.pendingSwitch?.slot == slot, let pointer = self.lastPointer else { return }
            self.updateHover(at: pointer)
        }
    }

    func cancelPendingSwitch() {
        pendingSwitch = nil
        switchTask?.cancel()
        switchTask = nil
    }

    // MARK: Lock

    /// Locks the highlighted (enabled) segment, or unlocks. No-op without a selection.
    public func setLocked(_ locked: Bool) {
        let lock = locked && highlightedItem?.isEnabled == true
        guard lock != isLocked else { return }
        isLocked = lock
        cancelPendingSwitch()
        isInLip = false
        LayerAnimation.withoutActions {
            lipLayer.opacity = 0
            if lock, let slot = highlightedSlot, nodes.indices.contains(slot) {
                lockLayer.frame = bounds
                lockLayer.path = nodes[slot].outlinePath(config: configuration, center: wheelCenter)
                lockLayer.strokeColor = palette.accent.cgColor
            }
            lockLayer.opacity = lock ? 1 : 0
        }
        if lock, let slot = highlightedSlot { showChips(forSlot: slot) }
        applyPill(animated: true)
        if let item = highlightedItem {
            announce(lock ? String(format: strings.lockedAnnouncement, item.title) : strings.unlockedAnnouncement)
        }
        delegate?.radialMenu(self, didChangeLock: lock)
    }

    public func toggleLock() { setLocked(!isLocked) }

    // MARK: Tune lip

    func updateLip(at point: NSPoint) {
        guard configuration.lipDepth > 0, !isLocked, let slot = highlightedSlot, nodes.indices.contains(slot),
              let index = radialLayout.slots[slot].itemIndex, items[index].isEnabled,
              delegate?.radialMenu(self, hasOptionsFor: items[index]) == true else {
            setLip(false)
            return
        }
        let rel = relative(point)
        let outer = nodes[slot].currentOuterRadius(config: configuration)
        setLip(hypot(rel.x, rel.y) >= outer - configuration.lipDepth)
    }

    func setLip(_ on: Bool) {
        guard on != isInLip else { return }
        isInLip = on
        LayerAnimation.withoutActions {
            if on, let slot = highlightedSlot, nodes.indices.contains(slot) {
                lipLayer.frame = bounds
                lipLayer.path = nodes[slot].lipPath(config: configuration, center: wheelCenter, depth: configuration.lipDepth)
                lipLayer.fillColor = palette.accent.cgColor
            }
            lipLayer.opacity = on ? 1 : 0
        }
        applyPill(animated: true)
    }

    // MARK: Preset chips

    func presets(forSlot slot: Int) -> [RadialPreset] {
        guard configuration.presetBand > 0, radialLayout.slots.indices.contains(slot),
              let index = radialLayout.slots[slot].itemIndex, items[index].isEnabled else { return [] }
        return Array((delegate?.radialMenu(self, presetsFor: items[index]) ?? []).prefix(3))
    }

    /// Lays the chips along the rim outside `slot`, facing outward, inside the canvas.
    func showChips(forSlot slot: Int) {
        guard chipsSlot != slot else { return }
        hideChips()
        let presets = presets(forSlot: slot)
        guard !presets.isEmpty, nodes.indices.contains(slot) else { return }
        chipsSlot = slot
        let mid = radialLayout.slots[slot].midAngle
        let rim = nodes[slot].currentOuterRadius(config: configuration) + 8
        // Clock angles: 0 at 12 o'clock, clockwise. Normal = outward, tangent = clockwise.
        let n = CGPoint(x: sin(mid), y: cos(mid))
        let t = CGPoint(x: cos(mid), y: -sin(mid))
        let font = NSFont.systemFont(ofSize: configuration.labelSize, weight: .semibold)
        let h = configuration.presetChipHeight
        let sizes = presets.map {
            CGSize(width: ceil(($0.title as NSString).size(withAttributes: [.font: font]).width) + 22, height: h)
        }
        let extents = sizes.map { abs($0.width * t.x) + abs($0.height * t.y) }
        let spacing: CGFloat = 6
        var along = -(extents.reduce(0, +) + spacing * CGFloat(sizes.count - 1)) / 2
        let c = wheelCenter
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let reduce = resolvedAppearance.reduceMotion
        for (i, preset) in presets.enumerated() {
            let offset = along + extents[i] / 2
            along += extents[i] + spacing
            let halfNormal = (abs(sizes[i].width * n.x) + abs(sizes[i].height * n.y)) / 2
            let r = rim + halfNormal
            var centre = CGPoint(x: c.x + n.x * r + t.x * offset, y: c.y + n.y * r + t.y * offset)
            centre.x = min(max(centre.x, sizes[i].width / 2 + 2), bounds.width - sizes[i].width / 2 - 2)
            centre.y = min(max(centre.y, h / 2 + 2), bounds.height - h / 2 - 2)
            let frame = CGRect(x: centre.x - sizes[i].width / 2, y: centre.y - h / 2, width: sizes[i].width, height: h)
            let chip = ChipNode(preset: preset)
            chip.frame = frame
            LayerAnimation.withoutActions {
                chip.layer.frame = frame
                chip.layer.path = CGPath(roundedRect: CGRect(origin: .zero, size: frame.size), cornerWidth: h / 2,
                                         cornerHeight: h / 2, transform: nil)
                chip.layer.fillColor = palette.hubFill
                chip.layer.strokeColor = palette.stroke
                chip.layer.lineWidth = max(1, palette.strokeWidth)
                chip.layer.zPosition = 3
                chip.text.contentsScale = window?.backingScaleFactor ?? 2
                chip.text.alignmentMode = .center
                chip.text.string = NSAttributedString(string: preset.title,
                                                      attributes: [.font: font, .foregroundColor: palette.content])
                chip.text.frame = CGRect(x: 0, y: (h - lineHeight) / 2, width: frame.width, height: lineHeight)
            }
            overlayView.content.addSublayer(chip.layer)
            if !reduce { chip.layer.animate("opacity", from: Float(0), animation: LayerAnimation.basic(0.12)) }
            chipNodes.append(chip)
        }
        updateHitArea()
    }

    func hideChips() {
        guard !chipNodes.isEmpty || chipsSlot != nil else { return }
        for chip in chipNodes { chip.layer.removeFromSuperlayer() }
        chipNodes = []
        chipsSlot = nil
        hoveredChip = nil
        updateHitArea()
    }

    /// Farthest chip corner from the wheel centre.
    var chipReach: CGFloat {
        let c = wheelCenter
        return chipNodes.reduce(0) { reach, chip in
            let f = chip.frame
            let corners = [CGPoint(x: f.minX, y: f.minY), CGPoint(x: f.maxX, y: f.minY),
                           CGPoint(x: f.minX, y: f.maxY), CGPoint(x: f.maxX, y: f.maxY)]
            return max(reach, corners.map { hypot($0.x - c.x, $0.y - c.y) }.max() ?? 0)
        }
    }

    func chipIndex(at point: NSPoint) -> Int? {
        chipNodes.firstIndex { $0.frame.insetBy(dx: -3, dy: -3).contains(point) }
    }

    func isInChipCorridor(_ point: NSPoint) -> Bool {
        guard let slot = chipsSlot, slot == highlightedSlot, !chipNodes.isEmpty else { return false }
        if chipNodes.contains(where: { $0.frame.insetBy(dx: -14, dy: -14).contains(point) }) { return true }
        let rel = relative(point)
        guard hypot(rel.x, rel.y) <= chipReach + 4 else { return false }
        let s = radialLayout.slots[slot]
        return s.contains(angle: RadialLayout.clockAngle(of: rel), slack: radialLayout.stickySlack(for: s))
    }

    func setHoveredChip(_ index: Int?) {
        guard index != hoveredChip else { return }
        hoveredChip = index
        let font = NSFont.systemFont(ofSize: configuration.labelSize, weight: .semibold)
        LayerAnimation.withoutActions {
            for (i, chip) in chipNodes.enumerated() {
                let hot = i == index
                chip.layer.fillColor = hot ? palette.accent.cgColor : palette.hubFill
                chip.layer.strokeColor = hot ? palette.accent.cgColor : palette.stroke
                // White on the accent fill (cobalt in Halo: 5.0:1); the surface's text otherwise.
                chip.text.string = NSAttributedString(string: chip.preset.title,
                                                      attributes: [.font: font, .foregroundColor: hot ? NSColor.white : palette.content])
            }
        }
        if index != nil { setLip(false) }
        applyPill(animated: true)
    }

    // MARK: Drop intent

    /// Where a drop released now would land, given hover, lock, lip and chips.
    func resolveDropTarget() -> RadialDropTarget? {
        guard let item = highlightedItem, item.isEnabled else { return nil }
        if let chip = hoveredChip, chipNodes.indices.contains(chip) {
            return .preset(item: item.id, preset: chipNodes[chip].preset.id)
        }
        if isLocked { return .item(item.id) }
        return isInLip ? .tune(item.id) : .item(item.id)
    }

    /// The final intent at the drop: the tune modifier turns a plain run into `.tune`.
    func finalDropTarget(for item: RadialItem) -> RadialDropTarget {
        var target = resolveDropTarget() ?? .item(item.id)
        if case .item = target, let modifier = tuneModifier, NSEvent.modifierFlags.contains(modifier),
           delegate?.radialMenu(self, hasOptionsFor: item) == true {
            target = .tune(item.id)
        }
        return target
    }

    // MARK: Testing

    /// Commits a deferred switch now (tests can't wait on drag events).
    func commitPendingSwitchForTesting() {
        guard let slot = pendingSwitch?.slot else { return }
        cancelPendingSwitch()
        setHighlightedSlot(slot, animated: false)
    }

    var chipTitlesForTesting: [String] { chipNodes.map(\.preset.title) }
    var chipFramesForTesting: [CGRect] { chipNodes.map(\.frame) }
}
