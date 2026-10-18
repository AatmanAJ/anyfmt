import AppKit
import ApplicationServices
import CoreServices
import SwiftUI
import HaloCore

/// The only permissions Halo can ever ask for. The wheel needs none (D-001);
/// both of these exist solely for the opt-in Finder Return shortcut (D-004).
enum OptionalPermission: String, CaseIterable, Identifiable, Sendable {
    case accessibility
    case automationFinder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accessibility: String(localized: "Accessibility")
        case .automationFinder: String(localized: "Automation for Finder")
        }
    }

    /// One sentence: what it's for, nothing else.
    var reason: String {
        switch self {
        case .accessibility:
            String(localized: "Lets \(Brand.name) catch Return in Finder before Finder starts renaming the file.")
        case .automationFinder:
            String(localized: "Lets \(Brand.name) ask Finder which files are selected. Nothing else is read.")
        }
    }

    var glyph: String {
        switch self {
        case .accessibility: "accessibility"
        case .automationFinder: "gearshape.2"
        }
    }

    /// Deep link to the exact Privacy & Security pane.
    var settingsLink: String {
        switch self {
        case .accessibility: SystemSettingsLink.accessibility
        case .automationFinder: SystemSettingsLink.automation
        }
    }
}

enum PermissionStatus: Equatable, Sendable {
    case unknown
    case granted
    /// Not granted yet. For Automation the system can't tell "not asked" from
    /// "denied" without prompting, so both land here.
    case notGranted
}

/// How the coach reads (and, on request, asks for) a permission. Injected so
/// tests and screenshots never touch TCC.
struct PermissionProbe: Sendable {
    var accessibility: @Sendable () -> Bool
    /// Never prompts.
    var automation: @Sendable () -> PermissionStatus
    /// User-initiated: shows the system prompt.
    var requestAccessibility: @Sendable () -> Void
    var requestAutomation: @Sendable () -> Void

    static let live = PermissionProbe(
        accessibility: { AXIsProcessTrusted() },
        automation: { FinderAutomation.status(prompt: false) },
        requestAccessibility: {
            let key = "AXTrustedCheckOptionPrompt" // kAXTrustedCheckOptionPrompt
            _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        },
        requestAutomation: { _ = FinderAutomation.status(prompt: true) }
    )
}

/// Apple Events permission for Finder (`AEDeterminePermissionToAutomateTarget`).
/// The header says not to call it on the main thread; the coach never does.
enum FinderAutomation {
    static let finderBundleID = "com.apple.finder"

    static func status(prompt: Bool) -> PermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: finderBundleID)
        let rc: OSStatus = withExtendedLifetime(target) {
            guard let desc = target.aeDesc else { return OSStatus(procNotFound) }
            return AEDeterminePermissionToAutomateTarget(desc, AEEventClass(typeWildCard), AEEventID(typeWildCard), prompt)
        }
        switch rc {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted), OSStatus(errAEEventWouldRequireUserConsent): return .notGranted
        default: return .unknown // procNotFound: Finder not running (rare)
        }
    }
}

/// Live status of the optional permissions. While any view is watching, it
/// re-reads every 0.5 s, so a grant made in System Settings shows up at once:
/// no "restart the app".
@MainActor
final class PermissionsCoach: ObservableObject {
    static let shared = PermissionsCoach()

    @Published private(set) var status: [OptionalPermission: PermissionStatus] = [:]

    private let probe: PermissionProbe
    private let defaults: UserDefaults
    private var watchers = 0
    private var loop: Task<Void, Never>?
    let interval: Duration
    /// Opens a System Settings deep link; injectable so tests never open anything.
    var openLink: @MainActor (String) -> Void = { SystemSettingsLink.open($0) }

    init(probe: PermissionProbe = .live, defaults: UserDefaults = .standard, interval: Duration = .milliseconds(500)) {
        self.probe = probe
        self.defaults = defaults
        self.interval = interval
    }

    /// Number of views currently watching (tests).
    var watcherCount: Int { watchers }

    subscript(permission: OptionalPermission) -> PermissionStatus { status[permission] ?? .unknown }

    var allGranted: Bool { OptionalPermission.allCases.allSatisfy { self[$0] == .granted } }

    /// Ref-counted: call from `onAppear`, balance with `stopWatching()`.
    func startWatching() {
        watchers += 1
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                guard let interval = self?.interval else { return }
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopWatching() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        loop?.cancel()
        loop = nil
    }

    func refresh() async {
        let probe = self.probe
        let ax = probe.accessibility()
        // Apple Events preflight is an IPC to tccd; keep it off the main thread.
        let ae = await Task.detached(priority: .utility) { probe.automation() }.value
        let next: [OptionalPermission: PermissionStatus] = [
            .accessibility: ax ? .granted : .notGranted,
            .automationFinder: ae,
        ]
        if next != status { status = next }
    }

    // MARK: Granting (only ever from a button the user pressed)

    private func askedKey(_ p: OptionalPermission) -> String { "ui.permissions.asked.\(p.rawValue)" }

    func hasAsked(_ p: OptionalPermission) -> Bool { defaults.bool(forKey: askedKey(p)) }

    /// The row's button. The first time, macOS's own prompt appears: it puts
    /// \(Brand.name) in the pane's list (so there's a switch to turn on) and
    /// its button opens the pane. After that, deep-link straight to the pane.
    func grant(_ permission: OptionalPermission) {
        guard !hasAsked(permission) else {
            openSettings(for: permission)
            return
        }
        defaults.set(true, forKey: askedKey(permission))
        let probe = self.probe
        switch permission {
        case .accessibility:
            probe.requestAccessibility()
            Task { await refresh() }
        case .automationFinder:
            Task {
                // The Allow/Don't Allow alert blocks this call until answered.
                await Task.detached(priority: .userInitiated) { probe.requestAutomation() }.value
                await refresh()
                // Denied earlier: macOS won't ask again, so show the pane.
                if self[.automationFinder] != .granted { openSettings(for: .automationFinder) }
            }
        }
    }

    func openSettings(for permission: OptionalPermission) {
        openLink(permission.settingsLink)
    }
}

// MARK: - Rows

/// One permission: status dot, one sentence, and the way to grant it.
struct PermissionRow: View {
    let permission: OptionalPermission
    @ObservedObject var coach: PermissionsCoach

    var body: some View {
        let status = coach[permission]
        HStack(alignment: .center, spacing: DesignTokens.Space.m) {
            Image(systemName: permission.glyph)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(status == .granted ? Color.haloSuccess : Color.iris)
                .frame(width: 28, height: 28)
                .background(Circle().fill((status == .granted ? Color.haloSuccess : Color.iris).opacity(0.12)))
                .overlay(alignment: .bottomTrailing) {
                    // Status dot: green when granted, grey until then.
                    Circle()
                        .fill(status == .granted ? Color.haloSuccess : Color(nsColor: .tertiaryLabelColor))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                        .offset(x: 1, y: 1)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: permission.title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                Text(verbatim: permission.reason)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Space.s)
            if status == .granted {
                Label { Text("Granted") } icon: { Image(systemName: "checkmark.circle.fill") }
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold))
                    .foregroundStyle(Color.haloSuccess)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .accessibilityIdentifier("permission.\(permission.rawValue).granted")
            } else {
                Button {
                    coach.grant(permission)
                } label: {
                    Text("Open System Settings")
                }
                .controlSize(.small)
                .accessibilityIdentifier("permission.\(permission.rawValue).open")
            }
        }
        .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: status)
        .accessibilityElement(children: .contain)
        .accessibilityValue(status == .granted ? Text("Granted") : Text("Not granted"))
        .onAppear { coach.startWatching() }
        .onDisappear { coach.stopWatching() }
    }
}

/// Both optional permissions, live. Each row polls while it is on screen.
struct PermissionsCoachList: View {
    @ObservedObject var coach: PermissionsCoach

    var body: some View {
        ForEach(OptionalPermission.allCases) { p in
            PermissionRow(permission: p, coach: coach)
        }
    }
}
