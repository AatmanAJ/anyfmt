import AppKit
import Combine
import DragSense
import HaloCore
import UniformTypeIdentifiers

/// Wires the pieces together: drag sensing → wheel → jobs / editors / actions /
/// cloud, plus the menu bar, hotkey, Services, Finder shortcut and updater.
/// Everything here is glue; behaviour lives in the lanes' types.
@MainActor
final class AppCoordinator {
    let settings: AppSettings
    let launch: LaunchOptions
    let jobs: JobsController
    let sense: DragSense
    let wheel: WheelController
    let updater = UpdaterController()
    private let services = ServicesProvider()
    private var statusItem: StatusItemController?
    private var hotKey: GlobalHotKey?
    private var finderShortcut: FinderReturnShortcut?
    private var cancellables = Set<AnyCancellable>()
    /// Tool batches whose results need extra UI when they finish (Read QR).
    private var resultTools: [UUID: ToolSpec] = [:]

    init(settings: AppSettings = .shared, launch: LaunchOptions = LaunchOptions()) {
        self.settings = settings
        self.launch = launch
        jobs = JobsController(policyProvider: { AppSettings.shared.outputPolicy },
                              limits: Self.limits(for: settings))
        sense = DragSense(configuration: Self.senseConfiguration(settings))
        wheel = WheelController(provider: .live(), preferences: Self.wheelPreferences(settings))
    }

    // MARK: Lifecycle

    func start() {
        wheel.onSelect = { [weak self] selection, urls, promises, point in
            self?.handle(selection, urls: urls, promises: promises, at: point)
        }
        wheel.onCancel = { [weak self] in self?.sense.cancelWheel() }
        wheel.markVisible = { [weak self] in self?.sense.markWheelVisible() }
        wheel.rememberedOptions = settings.formatDefaults
        jobs.onJobFinished = { [weak self] record in self?.jobFinished(record) }
        sense.onEvent = { [weak self] event in self?.handle(event) }
        sense.start()
        wheel.prewarm()
        CloudIntegration.start(wheel: wheel)
        _ = ActionPerformer.shared // purges stale received file promises

        statusItem = StatusItemController(actions: menuActions())
        services.onFiles = { [weak self] urls in self?.wheel.showForSelection(urls: urls, at: NSEvent.mouseLocation) }
        ServicesProvider.register(services)
        applyHotKey()
        applyFinderShortcut()
        updater.apply(enabled: settings.updateChecksEnabled)
        observeSettings()
        Log.app.info("ready")
    }

    func stop() {
        sense.stop()
        hotKey?.unregister()
        finderShortcut?.stop()
    }

    // MARK: Drag sensing → wheel

    private func handle(_ event: DragSenseEvent) {
        switch event {
        case .triggerTapped(let trigger, let info, let location):
            guard let kind = WheelKind(rawValue: trigger.id) else { return }
            if wheel.isVisible && wheel.mode == .drag {
                wheel.switchKind(kind)
            } else {
                let promised = info.promisedTypes.compactMap { UTType($0) }
                wheel.show(kind: kind, urls: info.fileURLs, promisedTypes: promised, at: location)
            }
        case .dragEnded:
            // If the drop landed on the wheel, onSelect already ran and told DragSense.
            wheel.dragDidEnd()
            if sense.state != .idle { sense.cancelWheel() }
        case .dragBegan, .dragMoved:
            break
        }
    }

    // MARK: Selection → work

    private func handle(_ selection: WheelSelection, urls: [URL], promises: [NSFilePromiseReceiver], at point: CGPoint) {
        sense.wheelDidAcceptDrop()
        if case .action(let spec) = selection {
            // Actions take promises themselves (received into Application Support).
            perform(spec, urls: urls, promises: promises, at: point)
            return
        }
        Task { @MainActor in
            var files = urls
            if !promises.isEmpty {
                do {
                    files += try await PromiseIntake().receive(promises)
                } catch {
                    ToastHUD.show(String(localized: "Couldn’t receive the dragged files."), isError: true, near: point)
                    return
                }
            }
            guard !files.isEmpty else { return }
            switch selection {
            case .convert(let target, let chosen):
                let options = settings.defaultOptions(for: target.format)
                    .merging(wheel.rememberedOptions[target.format] ?? OptionValues())
                    .merging(chosen ?? OptionValues())
                if CloudIntegration.convertIfRequested(files, target: target.format, options: options, jobs: jobs, near: point) { return }
                jobs.convert(files, to: target, options: options, near: point)
            case .tool(let tool):
                run(tool, on: files, at: point)
            case .action:
                break
            }
        }
    }

    private func run(_ tool: ToolSpec, on files: [URL], at point: CGPoint) {
        if tool.cloudFeature != nil {
            CloudIntegration.runTool(tool, on: files, jobs: jobs, near: point)
            return
        }
        if tool.needsEditor {
            let opened = EditorFactory.open(tool, inputs: files) { [weak self] result in
                guard let self else { return }
                self.track(self.jobs.runTool(result.tool, on: result.inputs, options: result.options, near: NSEvent.mouseLocation), tool)
            }
            if opened { return }
        }
        track(jobs.runTool(tool.id, on: files, near: point), tool)
    }

    private func track(_ batch: UUID, _ tool: ToolSpec) {
        if tool.id == ToolIDs.readCodes { resultTools[batch] = tool }
    }

    /// Shows tool-specific results (the codes Read QR found) once the job succeeds.
    private func jobFinished(_ record: JobRecord) {
        guard let batch = record.batchID ?? Optional(record.id), let tool = resultTools[batch] else { return }
        if record.didSucceed { EditorFactory.presentResult(tool, outputs: record.outputs) }
        if record.isFinished { resultTools[batch] = nil }
    }

    private func perform(_ action: ActionSpec, urls: [URL], promises: [NSFilePromiseReceiver], at point: CGPoint) {
        Task { @MainActor in
            if action.cloudFeature != nil {
                var files = urls
                if !promises.isEmpty { files += (try? await PromiseIntake().receive(promises)) ?? [] }
                if let message = await CloudIntegration.shareLink(files) { ToastHUD.show(message, systemImage: "link", near: point) }
                return
            }
            switch await ActionPerformer.shared.perform(action.id, urls: urls, promises: promises, at: point) {
            case .done(let message?): ToastHUD.show(message, near: point)
            case .failed(let message): ToastHUD.show(message, isError: true, near: point)
            case .done(nil), .cancelled: break
            }
        }
    }

    // MARK: Other ways in

    func openWheelForFinderSelection() {
        Task { @MainActor in
            let urls = await FinderSelection.read(ask: true)
            guard !urls.isEmpty else {
                ToastHUD.show(String(localized: "Select files in Finder first, or drop files on the ring."),
                              systemImage: "hand.point.up.left", near: NSEvent.mouseLocation)
                wheel.showDropRing(at: NSEvent.mouseLocation)
                return
            }
            wheel.showForSelection(urls: urls, at: NSEvent.mouseLocation)
        }
    }

    private func applyHotKey() {
        hotKey?.unregister()
        hotKey = nil
        guard settings.dropRingHotKeyEnabled else { return }
        let flags = NSEvent.ModifierFlags(rawValue: UInt(settings.dropRingModifiers))
        let modifiers = ModifierKey.keys(in: flags)
        let shortcut = GlobalHotKey.Shortcut(keyCode: UInt32(settings.dropRingKeyCode), modifiers: modifiers)
        let key = GlobalHotKey(shortcut: shortcut) { [weak self] in
            self?.wheel.showDropRing(at: NSEvent.mouseLocation)
        }
        do {
            try key.register()
            hotKey = key
        } catch {
            Log.app.error("hotkey: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func applyFinderShortcut() {
        if settings.finderShortcutEnabled {
            if finderShortcut == nil {
                finderShortcut = FinderReturnShortcut { [weak self] in self?.openWheelForFinderSelection() }
            }
            finderShortcut?.start()
        } else {
            finderShortcut?.stop()
        }
    }

    // MARK: Settings → live configuration

    private func observeSettings() {
        settings.objectWillChange
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.settingsChanged() }
            .store(in: &cancellables)
    }

    func settingsChanged() {
        sense.configuration = Self.senseConfiguration(settings)
        wheel.preferences = Self.wheelPreferences(settings)
        applyHotKey()
        applyFinderShortcut()
        updater.apply(enabled: settings.updateChecksEnabled)
    }

    static func senseConfiguration(_ s: AppSettings) -> DragSenseConfiguration {
        var c = DragSenseConfiguration.default
        func key(_ raw: String, _ fallback: ModifierKey) -> ModifierKey { ModifierKey(rawValue: raw) ?? fallback }
        c.triggers = [
            Trigger(id: WheelKind.convert.rawValue, key: key(s.convertKey, .shift)),
            Trigger(id: WheelKind.tools.rawValue, key: key(s.toolsKey, .command)),
            Trigger(id: WheelKind.actions.rawValue, key: key(s.actionsKey, .control)),
        ]
        c.tapThreshold = s.tapThreshold
        return c
    }

    static func wheelPreferences(_ s: AppSettings) -> WheelPreferences {
        WheelPreferences(favouriteFormats: s.favouriteFormats, hiddenFormats: s.hiddenFormats, hiddenTools: s.hiddenTools)
    }

    static func limits(for s: AppSettings) -> ConcurrencyLimits {
        var l = ConcurrencyLimits.system
        if s.cpuConcurrency > 0 { l.cpu = s.cpuConcurrency }
        return l
    }

    // MARK: Menu bar

    private func menuActions() -> StatusItemController.Actions {
        var a = StatusItemController.Actions()
        a.openWheelForSelection = { [weak self] in self?.openWheelForFinderSelection() }
        a.recents = { [weak self] in
            self?.jobs.recents.items.map { StatusItemController.Recent(title: $0.title, urls: $0.outputs) } ?? []
        }
        a.toggleFloat = { FloatShelf.shared.toggle() }
        a.isFloatVisible = { FloatShelf.shared.isVisible }
        a.checkForUpdates = { [weak self] in self?.updater.checkNow() }
        a.canCheckForUpdates = { [weak self] in self?.settings.updateChecksEnabled ?? false }
        a.openGallery = { WheelGallery.showWindow() }
        return a
    }

    /// Lets the app delegate install Settings/About/Onboarding presenters.
    func setMenuPresenters(settings: @escaping () -> Void, about: @escaping () -> Void, onboarding: @escaping () -> Void) {
        statusItem?.actions.openSettings = settings
        statusItem?.actions.openAbout = about
        statusItem?.actions.openOnboarding = onboarding
    }
}
