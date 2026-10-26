import AppKit
import AnyfmtCore

/// Runs the Control wheel's actions (BUILD.md §8). The wheel calls
/// `perform(_:urls:promises:at:)` after a drop on an action segment.
///
/// Actions work on files, folders and mixed selections, never consult
/// anything about accounts, and never touch the network. The Pro share-link
/// action belongs to the cloud client and is not handled here.
///
/// Usage from the wheel's drop handler (start it straight away so promise
/// requests go out while the drag is fresh):
///
///     Task { @MainActor in
///         let outcome = await ActionPerformer.shared.perform(id, urls: urls, promises: promises, at: dropPoint)
///         // show outcome.message in the confirmation HUD / error toast
///     }
///
/// `point` is in screen coordinates (AppKit, bottom-left origin), e.g. `NSEvent.mouseLocation`.
@MainActor
public final class ActionPerformer {
    public static let shared = ActionPerformer()

    /// Actions implemented here. Share link is lane I's.
    public static let localActions: [ActionID] = [
        ActionIDs.airDrop, ActionIDs.float, ActionIDs.copy, ActionIDs.move, ActionIDs.copyPath, ActionIDs.terminal,
    ]

    let preferences: ActionPreferences
    let pasteboard: NSPasteboard
    let shelf: FloatShelf
    let intake: PromiseIntake
    let appLookup: TerminalLauncher.AppLookup
    let openTerminal: @MainActor (TerminalLaunchPlan) async throws -> Void
    let chooseDestination: @MainActor ([URL], [URL], CGPoint) async -> URL?
    let modifierFlags: @MainActor () -> NSEvent.ModifierFlags

    convenience init() {
        self.init(preferences: .shared, pasteboard: .general, shelf: .shared, intake: PromiseIntake())
    }

    /// Everything with a side effect is injectable for tests.
    init(preferences: ActionPreferences,
         pasteboard: NSPasteboard,
         shelf: FloatShelf,
         intake: PromiseIntake,
         appLookup: @escaping TerminalLauncher.AppLookup = TerminalLauncher.systemLookup,
         openTerminal: @escaping @MainActor (TerminalLaunchPlan) async throws -> Void = TerminalLauncher.execute,
         chooseDestination: @escaping @MainActor ([URL], [URL], CGPoint) async -> URL? = MoveChooser.chooseDestination,
         modifierFlags: @escaping @MainActor () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }) {
        self.preferences = preferences
        self.pasteboard = pasteboard
        self.shelf = shelf
        self.intake = intake
        self.appLookup = appLookup
        self.openTerminal = openTerminal
        self.chooseDestination = chooseDestination
        self.modifierFlags = modifierFlags
        let root = intake
        Task.detached(priority: .background) { root.purge() }
    }

    /// True for the six local actions; false for share link and unknown ids.
    public func supports(_ id: ActionID) -> Bool {
        Self.localActions.contains(id)
    }

    /// Whether the action can run for these items on this Mac right now
    /// (e.g. AirDrop is missing on some Macs and VMs). Items may be empty for
    /// a promise-only drag; the answer then assumes files will arrive.
    public func canPerform(_ id: ActionID, urls: [URL]) -> Bool {
        guard supports(id) else { return false }
        if id == ActionIDs.airDrop { return NSSharingService(named: .sendViaAirDrop) != nil }
        return true
    }

    public func perform(_ id: ActionID, urls: [URL], promises: [NSFilePromiseReceiver] = [], at point: CGPoint) async -> ActionOutcome {
        guard supports(id) else {
            Log.actions.error("unsupported action \(id.rawValue, privacy: .public)")
            return .failed(String(localized: "This action isn’t available."))
        }
        // Read modifiers before anything async: they mean what was held at the drop.
        let flags = modifierFlags()
        var items = Self.unique(urls)
        if items.isEmpty && !promises.isEmpty {
            let pending = intake.begin(promises)
            do {
                items = try await pending.files()
            } catch {
                return .failed(PromiseIntake.IntakeError.nothingReceived.message)
            }
        }
        guard !items.isEmpty else { return .failed(String(localized: "There’s nothing to work with.")) }
        Log.actions.info("perform \(id.rawValue, privacy: .public) on \(items.count) item(s)")

        switch id {
        case ActionIDs.airDrop: return await AirDropSender.shared.send(items, near: point)
        case ActionIDs.float: return float(items, at: point)
        case ActionIDs.copy: return copy(items)
        case ActionIDs.move: return await move(items, at: point)
        case ActionIDs.copyPath: return copyPath(items, shell: flags.contains(.option))
        case ActionIDs.terminal: return await terminal(items)
        default: return .failed(String(localized: "This action isn’t available."))
        }
    }

    // MARK: The actions

    func float(_ items: [URL], at point: CGPoint) -> ActionOutcome {
        shelf.add(urls: items, near: point)
        return .done(nil)
    }

    func copy(_ items: [URL]) -> ActionOutcome {
        guard FileClipboard.copyFiles(items, to: pasteboard) else {
            return .failed(String(localized: "Couldn’t copy to the clipboard."))
        }
        return .done(items.count == 1
            ? String(localized: "Copied “\(items[0].lastPathComponent)”")
            : String(localized: "Copied \(items.count) items"))
    }

    /// Plain: newline-separated POSIX paths. Option held: shell-quoted, space-separated.
    func copyPath(_ items: [URL], shell: Bool) -> ActionOutcome {
        let text = shell ? PathFormatter.shellEscapedPaths(items) : PathFormatter.posixPaths(items)
        guard FileClipboard.copyText(text, to: pasteboard) else {
            return .failed(String(localized: "Couldn’t copy to the clipboard."))
        }
        return .done(items.count == 1 ? String(localized: "Copied path") : String(localized: "Copied \(items.count) paths"))
    }

    func move(_ items: [URL], at point: CGPoint) async -> ActionOutcome {
        guard let destination = await chooseDestination(items, preferences.recentFolders, point) else { return .cancelled }
        let mover = FileMover()
        if let refusal = mover.check(items, into: destination) { return .failed(refusal.message) }
        preferences.noteRecentFolder(destination)
        // Off the main thread: a cross-disk move can copy a lot.
        let report = await Task.detached(priority: .userInitiated) { mover.move(items, into: destination) }.value
        return Self.outcome(of: report, destination: destination)
    }

    func terminal(_ items: [URL]) async -> ActionOutcome {
        guard let folder = TerminalLauncher.workingFolder(for: items) else {
            return .failed(String(localized: "There’s nothing to open."))
        }
        guard let terminal = TerminalLauncher.resolve(preferred: preferences.terminalBundleID, lookup: appLookup),
              let plan = TerminalLauncher.launchPlan(for: terminal, folder: folder) else {
            return .failed(String(localized: "Couldn’t find a terminal app."))
        }
        if terminal.app.bundleID != preferences.terminalBundleID {
            Log.actions.info("terminal \(self.preferences.terminalBundleID, privacy: .public) missing; using Terminal")
        }
        do {
            try await openTerminal(plan)
            return .done(nil)
        } catch {
            Log.actions.error("terminal: \(error.localizedDescription, privacy: .public)")
            return .failed(String(localized: "Couldn’t open \(terminal.app.name)."))
        }
    }

    // MARK: Helpers

    /// Same file twice (or via a symlinked path) counts once; order kept.
    static func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.resolvingSymlinksInPath().path).inserted }
    }

    static func outcome(of report: MoveReport, destination: URL) -> ActionOutcome {
        let folder = FileManager.default.displayName(atPath: destination.path)
        let moved = report.moved.count
        if let failure = report.failures.first {
            if moved == 0 {
                return .failed(report.failures.count == 1
                    ? failure.message
                    : String(localized: "\(failure.message) (\(report.failures.count) items weren’t moved.)"))
            }
            let total = moved + report.failures.count
            return .failed(String(localized: "Moved \(moved) of \(total) items. \(failure.message)"))
        }
        if moved == 0 {
            return .done(String(localized: "Already in “\(folder)”"))
        }
        if moved == 1, let only = report.moved.first {
            return .done(only.wasRenamed
                ? String(localized: "Moved to “\(folder)” as “\(only.destination.lastPathComponent)”")
                : String(localized: "Moved “\(only.source.lastPathComponent)” to “\(folder)”"))
        }
        let renamed = report.moved.filter(\.wasRenamed).count
        return .done(renamed == 0
            ? String(localized: "Moved \(moved) items to “\(folder)”")
            : String(localized: "Moved \(moved) items to “\(folder)” (\(renamed) renamed to avoid replacing)"))
    }
}
