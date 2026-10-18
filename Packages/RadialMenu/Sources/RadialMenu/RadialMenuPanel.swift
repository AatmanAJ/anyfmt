import AppKit

/// Borderless overlay panel that hosts a `RadialMenuView` above everything
/// while another app (Finder) owns a drag:
///
/// - `.nonactivatingPanel`, never key unless `allowsKeyboard` is on, so the
///   source app keeps focus and keeps owning the drag session.
/// - Level `.popUpMenu` (101): above the Dock and menu bar, below the drag
///   image (500), so the dragged icon stays on top of the wheel.
/// - Joins every Space and full-screen app; ignored by Mission Control and ⌘`.
/// - Drag types are registered before the panel is ever ordered in.
/// - Transparent pixels are click/drag-through, so the menu view paints its
///   whole hit disc with a minimum alpha.
@MainActor
public final class RadialMenuPanel: NSPanel {
    public let menuView: RadialMenuView

    /// File URLs and file promises (Mail, Photos, browsers) by default.
    public static var defaultDraggedTypes: [NSPasteboard.PasteboardType] {
        [.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
    }

    public var draggedTypes: [NSPasteboard.PasteboardType] {
        didSet { menuView.registerForDraggedTypes(draggedTypes) }
    }

    /// Lets the panel become key (keyboard/selection mode). Off for drags.
    public var allowsKeyboard = false {
        didSet { menuView.keyboardEnabled = allowsKeyboard }
    }

    /// Called once the window server reports the panel visible (latency measurement).
    public var onVisible: (@MainActor () -> Void)?

    /// Screens used for placement. Nil = `NSScreen.screens` (tests inject frames).
    public var screensProvider: (@MainActor () -> [RadialScreen])?

    /// The point the wheel was summoned at (global coordinates).
    public private(set) var anchorPoint: CGPoint = .zero

    private var occlusionObserver: NSObjectProtocol?

    public init(configuration: RadialMenuConfiguration = RadialMenuConfiguration(),
                style: RadialMenuStyle = RadialMenuStyle(),
                draggedTypes: [NSPasteboard.PasteboardType] = RadialMenuPanel.defaultDraggedTypes) {
        menuView = RadialMenuView(configuration: configuration, style: style, materialMode: .live)
        self.draggedTypes = draggedTypes
        let side = configuration.canvasSide
        super.init(contentRect: NSRect(x: 0, y: 0, width: side, height: side),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // the menu draws its own per-segment shadows
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        contentView = menuView
        // Before the panel is ever ordered in (D-003).
        menuView.registerForDraggedTypes(draggedTypes)
    }

    public override var canBecomeKey: Bool { allowsKeyboard }
    public override var canBecomeMain: Bool { false }

    // MARK: Showing

    /// Orders the panel in once, invisibly and off-screen, so the first real show
    /// doesn't pay for window-server and Core Animation setup. Call at launch.
    public func prewarm() {
        guard !isVisible else { return }
        let saved = frame
        alphaValue = 0
        setFrame(NSRect(x: -20_000, y: -20_000, width: saved.width, height: saved.height), display: false)
        orderFrontRegardless()
        menuView.layoutSubtreeIfNeeded()
        menuView.displayIfNeeded()
        orderOut(nil)
        setFrame(saved, display: false)
        alphaValue = 1
    }

    /// Centres the wheel on `point` (global coordinates), pushed inward near
    /// screen edges, and orders it in without activating the app.
    public func show(at point: CGPoint, animated: Bool = true) {
        anchorPoint = point
        menuView.registerForDraggedTypes(draggedTypes)
        position(animated: false)
        menuView.prepareForDisplay()
        alphaValue = 1
        observeVisibility()
        if allowsKeyboard {
            makeKeyAndOrderFront(nil)
            makeFirstResponder(menuView)
        } else {
            orderFrontRegardless()
        }
        if animated { menuView.playOpenAnimation() }
    }

    /// Re-centres after the wheel changed size (e.g. a morph added a second ring).
    public func position(animated: Bool) {
        let screens = screensProvider?() ?? NSScreen.screens.map {
            RadialScreen(frame: $0.frame, visibleFrame: $0.visibleFrame, backingScale: $0.backingScaleFactor)
        }
        let config = menuView.configuration
        let center = RadialPlacement.center(for: anchorPoint, radius: menuView.wheelRadius, screens: screens,
                                            edgeInset: config.screenEdgeInset, topExclusion: config.topExclusion)
        let target = RadialPlacement.frame(side: config.canvasSide, centeredAt: center)
        guard target != frame else { return }
        if animated && isVisible && !menuView.resolvedAppearance.reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = config.morphDuration
                ctx.allowsImplicitAnimation = true
                animator().setFrame(target, display: true)
            }
        } else {
            setFrame(target, display: false)
        }
    }

    /// Where the wheel's centre is on screen (global coordinates).
    public var wheelCenterOnScreen: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    /// Animates out (collapse toward `point`, global coordinates) and orders out.
    public func dismiss(toward point: CGPoint? = nil, animated: Bool = true, completion: (@MainActor () -> Void)? = nil) {
        guard isVisible else {
            completion?()
            return
        }
        let finish: @MainActor () -> Void = { [weak self] in
            self?.orderOut(nil)
            completion?()
        }
        guard animated else {
            finish()
            return
        }
        let local = point.map { menuView.convert(convertPoint(fromScreen: $0), from: nil) }
        menuView.playCloseAnimation(toward: local, completion: finish)
    }

    /// Drop landed: pulse the segment, dissolve, order out.
    public func confirmDrop(at point: CGPoint? = nil, completion: (@MainActor () -> Void)? = nil) {
        let local = point.map { menuView.convert(convertPoint(fromScreen: $0), from: nil) }
        menuView.playDropConfirmation(at: local) { [weak self] in
            self?.orderOut(nil)
            completion?()
        }
    }

    private func observeVisibility() {
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        guard onVisible != nil else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: self, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.occlusionState.contains(.visible) else { return }
                if let o = self.occlusionObserver { NotificationCenter.default.removeObserver(o) }
                self.occlusionObserver = nil
                self.onVisible?()
            }
        }
    }
}
