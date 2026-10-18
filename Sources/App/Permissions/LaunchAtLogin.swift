import AppKit
import os
import ServiceManagement
import SwiftUI
import HaloCore

/// What `LaunchAtLogin` needs from ServiceManagement. Faked in tests and
/// screenshots so nothing ever registers a login item from a test run.
struct LoginItemService: Sendable {
    var status: @Sendable () -> SMAppService.Status
    var register: @Sendable () throws -> Void
    var unregister: @Sendable () throws -> Void
    var openSystemSettings: @Sendable () -> Void

    static let live = LoginItemService(
        status: { SMAppService.mainApp.status },
        register: { try SMAppService.mainApp.register() },
        unregister: { try SMAppService.mainApp.unregister() },
        openSystemSettings: { SMAppService.openSystemSettingsLoginItems() }
    )

    /// In-memory stand-in.
    static func fake(_ initial: SMAppService.Status = .notRegistered) -> LoginItemService {
        let box = StatusBox(initial)
        return LoginItemService(status: { box.value }, register: { box.value = .enabled },
                                unregister: { box.value = .notRegistered }, openSystemSettings: {})
    }

    private final class StatusBox: Sendable {
        private let lock: OSAllocatedUnfairLock<Int>
        init(_ v: SMAppService.Status) { lock = OSAllocatedUnfairLock(initialState: v.rawValue) }
        var value: SMAppService.Status {
            get { SMAppService.Status(rawValue: lock.withLock { $0 }) ?? .notRegistered }
            set { lock.withLock { $0 = newValue.rawValue } }
        }
    }
}

/// Launch at login via `SMAppService.mainApp`. The user can flip it in System
/// Settings › General › Login Items at any time, so the status is always
/// re-read (on appear, after every change, and when the app becomes active),
/// never cached as our own boolean.
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var lastError: String?

    private let service: LoginItemService
    private var activeObserver: NSObjectProtocol?

    init(service: LoginItemService = .live) {
        self.service = service
        self.status = service.status()
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// On, or waiting for the user's approval (which still means "they asked for it").
    var isRequested: Bool { status == .enabled || status == .requiresApproval }

    func refresh() {
        let s = service.status()
        if s != status { status = s }
    }

    func setEnabled(_ on: Bool) {
        lastError = nil
        do {
            if on { try service.register() } else { try service.unregister() }
        } catch {
            Log.settings.error("login item \(on ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            lastError = on
                ? String(localized: "macOS didn’t accept the login item. Try again, or add \(Brand.name) in System Settings › General › Login Items.")
                : String(localized: "macOS didn’t remove the login item. You can remove it in System Settings › General › Login Items.")
        }
        refresh()
    }

    func openLoginItems() { service.openSystemSettings() }

    /// One line for the current status, or nil when there's nothing to say.
    var statusNote: String? {
        if let lastError { return lastError }
        switch status {
        case .requiresApproval:
            return String(localized: "Waiting for your OK in System Settings › General › Login Items.")
        case .notFound:
            return String(localized: "Move \(Brand.name) to your Applications folder to launch it at login.")
        default:
            return nil
        }
    }
}

/// Toggle + live status, used by Settings › General and onboarding.
struct LaunchAtLoginRow: View {
    @ObservedObject var model: LaunchAtLogin
    /// Card layout (onboarding) instead of a grouped-Form row.
    var card = false

    var body: some View {
        let binding = Binding(get: { model.isRequested }, set: { model.setEnabled($0) })
        Group {
            if card {
                CardToggle(title: String(localized: "Launch \(Brand.name) at login"),
                           subtitle: String(localized: "Starts quietly in the menu bar when you log in."),
                           isOn: binding, identifier: "onboarding.launchAtLogin")
            } else {
                Toggle(isOn: binding) {
                    Text("Launch \(Brand.name) at login")
                    Text("Starts quietly in the menu bar when you log in.")
                }
                .toggleStyle(HaloSwitchStyle())
                .accessibilityIdentifier("settings.launchAtLogin")
            }
        }
        .onAppear { model.refresh() }
        if let note = model.statusNote {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: model.status == .requiresApproval ? "hourglass" : "exclamationmark.triangle")
                    .foregroundStyle(model.status == .requiresApproval ? Color.secondary : Color.haloDanger)
                Text(verbatim: note)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DesignTokens.Space.s)
                if model.status == .requiresApproval || model.lastError != nil {
                    Button("Open Login Items") { model.openLoginItems() }
                        .controlSize(.small)
                }
            }
            .font(.system(size: DesignTokens.TypeRamp.label))
        }
    }
}
