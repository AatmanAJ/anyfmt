import AppKit
import Combine
import HaloCore

/// Every user setting, persisted in UserDefaults. The Settings window edits
/// this; the drag sensor, wheel, job queue and actions read snapshots from it.
/// Keys are stable strings, so a rename of the app never resets settings.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.registered)
        load()
    }

    // MARK: General
    @Published var soundsEnabled = true { didSet { save(\.soundsEnabled, Key.sounds) } }
    @Published var hapticsEnabled = true { didSet { save(\.hapticsEnabled, Key.haptics) } }
    /// Sparkle never checks unless this is on (D-024).
    @Published var updateChecksEnabled = false { didSet { save(\.updateChecksEnabled, Key.updateChecks) } }
    @Published var onboardingCompleted = false { didSet { save(\.onboardingCompleted, Key.onboardingDone) } }

    // MARK: Keys (raw ModifierKey values from DragSense: shift, command, control, option, function)
    @Published var convertKey = "shift" { didSet { save(\.convertKey, Key.convertKey) } }
    @Published var toolsKey = "command" { didSet { save(\.toolsKey, Key.toolsKey) } }
    @Published var actionsKey = "control" { didSet { save(\.actionsKey, Key.actionsKey) } }
    @Published var tapThreshold: Double = 0.35 { didSet { save(\.tapThreshold, Key.tapThreshold) } }
    /// "press": the wheel opens when a trigger key goes down mid-drag (tap or hold).
    /// "tap": only a quick tap opens it.
    @Published var triggerActivation = "press" { didSet { save(\.triggerActivation, Key.triggerActivation) } }
    var opensOnPress: Bool { triggerActivation != "tap" }
    /// Opt-in: Return on a Finder selection opens the wheel (needs Accessibility + Automation, D-004).
    @Published var finderShortcutEnabled = false { didSet { save(\.finderShortcutEnabled, Key.finderShortcut) } }
    /// Global hotkey for the drop ring (Carbon key code + modifier mask). Default ⌃⌥Space.
    @Published var dropRingKeyCode = 49 { didSet { save(\.dropRingKeyCode, Key.dropRingKeyCode) } }
    @Published var dropRingModifiers = Int(NSEvent.ModifierFlags([.control, .option]).rawValue) { didSet { save(\.dropRingModifiers, Key.dropRingModifiers) } }
    @Published var dropRingHotKeyEnabled = true { didSet { save(\.dropRingHotKeyEnabled, Key.dropRingEnabled) } }

    // MARK: Output
    /// nil = beside the original.
    @Published var outputFolderBookmark: Data? { didSet { defaults.set(outputFolderBookmark, forKey: Key.outputFolder) } }
    @Published var namePattern = "{name}" { didSet { save(\.namePattern, Key.namePattern) } }
    @Published var metadataPolicy = MetadataPolicy.keep { didSet { defaults.set(metadataPolicy.rawValue, forKey: Key.metadata) } }
    @Published var preserveDates = true { didSet { save(\.preserveDates, Key.preserveDates) } }
    @Published var revealInFinder = true { didSet { save(\.revealInFinder, Key.reveal) } }

    // MARK: Formats
    /// Favourites sit first on the ring, in this order.
    @Published var favouriteFormats: [FormatID] = [] { didSet { defaults.set(favouriteFormats.map(\.rawValue), forKey: Key.favourites) } }
    @Published var hiddenFormats: Set<FormatID> = [] { didSet { defaults.set(hiddenFormats.map(\.rawValue).sorted(), forKey: Key.hiddenFormats) } }
    /// Targets the user switched on for routes that are opt-in by default
    /// (`Route.isShownByDefault`, e.g. photo → DOCX via PDF + text recognition).
    @Published var shownFormats: Set<FormatID> = [] { didSet { defaults.set(shownFormats.map(\.rawValue).sorted(), forKey: Key.shownFormats) } }
    @Published var hiddenTools: Set<ToolID> = [] { didSet { defaults.set(hiddenTools.map(\.rawValue).sorted(), forKey: Key.hiddenTools) } }
    /// Per-target default options (e.g. jpg quality 80), keyed by FormatID.
    @Published var formatDefaults: [FormatID: OptionValues] = [:] { didSet { saveFormatDefaults() } }

    // MARK: Advanced
    /// 0 = automatic (performance cores − 1).
    @Published var cpuConcurrency = 0 { didSet { save(\.cpuConcurrency, Key.concurrency) } }
    @Published var verboseLogging = false { didSet { save(\.verboseLogging, Key.verbose) } }

    // MARK: Snapshots for the core

    var outputPolicy: OutputPolicy {
        var location = OutputPolicy.Location.besideOriginal
        if let data = outputFolderBookmark, let url = resolveBookmark(data) { location = .folder(url) }
        return OutputPolicy(location: location, namePattern: namePattern, metadata: metadataPolicy,
                            preserveDates: preserveDates, revealInFinder: revealInFinder)
    }

    func defaultOptions(for target: FormatID) -> OptionValues { formatDefaults[target] ?? OptionValues() }

    func setOutputFolder(_ url: URL?) {
        outputFolderBookmark = url.flatMap { try? $0.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) }
    }

    var outputFolderURL: URL? { outputFolderBookmark.flatMap(resolveBookmark) }

    /// Back to factory settings (keeps onboarding state).
    func resetAll() {
        let done = onboardingCompleted
        for k in Key.all { defaults.removeObject(forKey: k) }
        load()
        onboardingCompleted = done
    }

    // MARK: Persistence

    private enum Key {
        static let sounds = "general.sounds", haptics = "general.haptics", updateChecks = "general.updateChecks"
        static let onboardingDone = "general.onboardingCompleted"
        static let convertKey = "keys.convert", toolsKey = "keys.tools", actionsKey = "keys.actions"
        static let tapThreshold = "keys.tapThreshold", finderShortcut = "keys.finderShortcut"
        static let triggerActivation = "keys.activation"
        static let dropRingKeyCode = "keys.dropRing.keyCode", dropRingModifiers = "keys.dropRing.modifiers", dropRingEnabled = "keys.dropRing.enabled"
        static let outputFolder = "output.folderBookmark", namePattern = "output.namePattern", metadata = "output.metadata"
        static let preserveDates = "output.preserveDates", reveal = "output.reveal"
        static let favourites = "formats.favourites", hiddenFormats = "formats.hidden", hiddenTools = "tools.hidden"
        static let shownFormats = "formats.shown"
        static let formatDefaults = "formats.defaults"
        static let concurrency = "advanced.cpuConcurrency", verbose = "advanced.verboseLogging"
        static let all = [sounds, haptics, updateChecks, convertKey, toolsKey, actionsKey, tapThreshold, triggerActivation, finderShortcut,
                          dropRingKeyCode, dropRingModifiers, dropRingEnabled, outputFolder, namePattern, metadata,
                          preserveDates, reveal, favourites, hiddenFormats, shownFormats, hiddenTools, formatDefaults, concurrency, verbose]
    }

    private static let registered: [String: Any] = [
        Key.sounds: true, Key.haptics: true, Key.updateChecks: false,
        Key.convertKey: "shift", Key.toolsKey: "command", Key.actionsKey: "control",
        Key.tapThreshold: 0.35, Key.triggerActivation: "press", Key.finderShortcut: false,
        Key.dropRingKeyCode: 49, Key.dropRingModifiers: Int(NSEvent.ModifierFlags([.control, .option]).rawValue), Key.dropRingEnabled: true,
        Key.namePattern: "{name}", Key.metadata: MetadataPolicy.keep.rawValue, Key.preserveDates: true, Key.reveal: true,
        Key.concurrency: 0, Key.verbose: false,
    ]

    private var loading = false

    private func load() {
        loading = true
        defer { loading = false }
        let d = defaults
        soundsEnabled = d.bool(forKey: Key.sounds)
        hapticsEnabled = d.bool(forKey: Key.haptics)
        updateChecksEnabled = d.bool(forKey: Key.updateChecks)
        onboardingCompleted = d.bool(forKey: Key.onboardingDone)
        convertKey = d.string(forKey: Key.convertKey) ?? "shift"
        toolsKey = d.string(forKey: Key.toolsKey) ?? "command"
        actionsKey = d.string(forKey: Key.actionsKey) ?? "control"
        tapThreshold = d.double(forKey: Key.tapThreshold)
        triggerActivation = d.string(forKey: Key.triggerActivation) ?? "press"
        finderShortcutEnabled = d.bool(forKey: Key.finderShortcut)
        dropRingKeyCode = d.integer(forKey: Key.dropRingKeyCode)
        dropRingModifiers = d.integer(forKey: Key.dropRingModifiers)
        dropRingHotKeyEnabled = d.bool(forKey: Key.dropRingEnabled)
        outputFolderBookmark = d.data(forKey: Key.outputFolder)
        namePattern = d.string(forKey: Key.namePattern) ?? "{name}"
        metadataPolicy = MetadataPolicy(rawValue: d.string(forKey: Key.metadata) ?? "") ?? .keep
        preserveDates = d.bool(forKey: Key.preserveDates)
        revealInFinder = d.bool(forKey: Key.reveal)
        favouriteFormats = (d.stringArray(forKey: Key.favourites) ?? []).map { FormatID($0) }
        hiddenFormats = Set((d.stringArray(forKey: Key.hiddenFormats) ?? []).map { FormatID($0) })
        shownFormats = Set((d.stringArray(forKey: Key.shownFormats) ?? []).map { FormatID($0) })
        hiddenTools = Set((d.stringArray(forKey: Key.hiddenTools) ?? []).map { ToolID(rawValue: $0) })
        if let data = d.data(forKey: Key.formatDefaults),
           let decoded = try? JSONDecoder().decode([String: OptionValues].self, from: data) {
            formatDefaults = Dictionary(uniqueKeysWithValues: decoded.map { (FormatID($0.key), $0.value) })
        } else {
            formatDefaults = [:]
        }
        cpuConcurrency = d.integer(forKey: Key.concurrency)
        verboseLogging = d.bool(forKey: Key.verbose)
    }

    private func save<T>(_ path: KeyPath<AppSettings, T>, _ key: String) {
        guard !loading else { return }
        defaults.set(self[keyPath: path], forKey: key)
    }

    private func saveFormatDefaults() {
        guard !loading else { return }
        let raw = Dictionary(uniqueKeysWithValues: formatDefaults.map { ($0.key.rawValue, $0.value) })
        defaults.set(try? JSONEncoder().encode(raw), forKey: Key.formatDefaults)
    }

    private func resolveBookmark(_ data: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
}
