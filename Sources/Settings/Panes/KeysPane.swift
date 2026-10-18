import AppKit
import SwiftUI
import HaloCore

struct KeysPane: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var settings: AppSettings

    init(model: SettingsModel) {
        self.model = model
        self.settings = model.settings
    }

    var body: some View {
        Form {
            Section {
                ForEach(TriggerRole.allCases) { role in
                    TriggerRow(role: role, model: model)
                }
            } header: {
                Text("Wheels")
            } footer: {
                FootnoteText(text: String(localized: "Tap once mid-drag: press and let go. Holds and key combinations are ignored, so Finder’s own ⌘ and ⌥ drag shortcuts still work. Picking a key another wheel uses swaps the two."))
            }

            Section {
                LabeledContent {
                    HStack(spacing: DesignTokens.Space.s) {
                        Text("Quick").font(.system(size: DesignTokens.TypeRamp.caption)).foregroundStyle(.secondary)
                        Slider(value: Binding(get: { settings.tapThreshold }, set: { new in
                            settings.tapThreshold = OptionsFormLogic.snap(new, min: 0.15, max: 0.8, step: 0.05)
                            model.hooks.onTriggerKeysChanged?()
                        }), in: 0.15...0.8)
                        .labelsHidden()
                        .tint(Color.iris)
                        .frame(width: 170)
                        .accessibilityIdentifier("keys.tapThreshold")
                        Text("Relaxed").font(.system(size: DesignTokens.TypeRamp.caption)).foregroundStyle(.secondary)
                        Text(verbatim: OptionsFormLogic.display(settings.tapThreshold, decimals: 2, unit: "s"))
                            .font(.system(size: DesignTokens.TypeRamp.body).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                } label: {
                    Text("Tap speed")
                    Text("The longest press that still counts as a tap.")
                }
                TapTestArea(threshold: settings.tapThreshold, triggers: model.triggers)
            } header: {
                Text("Tap")
            }

            Section {
                Toggle(isOn: Binding(get: { settings.dropRingHotKeyEnabled }, set: { on in
                    settings.dropRingHotKeyEnabled = on
                    model.hooks.onTriggerKeysChanged?()
                })) {
                    Text("Open a drop ring with a shortcut")
                    Text("Press the shortcut, then drag files onto the ring at the pointer. Needs no permissions.")
                }
                .accessibilityIdentifier("keys.dropRingEnabled")
                LabeledContent {
                    HotkeyRecorder(hotkey: Binding(
                        get: { Hotkey(keyCode: settings.dropRingKeyCode, rawModifiers: settings.dropRingModifiers) },
                        set: { hk in
                            settings.dropRingKeyCode = hk.keyCode
                            settings.dropRingModifiers = hk.rawModifiers
                        }), onChange: { model.hooks.onTriggerKeysChanged?() })
                } label: {
                    Text("Shortcut")
                    Text("Must include ⌘ or ⌃.")
                }
                .disabled(!settings.dropRingHotKeyEnabled)
            } header: {
                Text("Drop ring")
            }

            Section {
                Toggle(isOn: Binding(get: { settings.finderShortcutEnabled }, set: { on in
                    settings.finderShortcutEnabled = on
                    model.hooks.onFinderShortcutChanged?(on)
                })) {
                    Text("Return opens the wheel for the Finder selection")
                    Text("Off by default. Needs Accessibility and Automation, explained below. Renaming with Return still works in text fields.")
                }
                .accessibilityIdentifier("keys.finderShortcut")
                if settings.finderShortcutEnabled {
                    PermissionsCoachList(coach: model.coach)
                }
                ServicesNote()
            } header: {
                Text("Finder")
            }
        }
        .formStyle(.grouped)
        .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: settings.finderShortcutEnabled)
    }
}

/// One wheel's trigger key picker.
private struct TriggerRow: View {
    let role: TriggerRole
    @ObservedObject var model: SettingsModel

    var body: some View {
        LabeledContent {
            Picker("", selection: Binding(get: { model.triggers[role] }, set: { model.assign($0, to: role) })) {
                ForEach(TriggerKey.allCases) { key in
                    Text(verbatim: key.displayName).tag(key)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityIdentifier("keys.trigger.\(role.rawValue)")
        } label: {
            HStack(spacing: DesignTokens.Space.m) {
                Image(systemName: role.glyph)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.iris.gradient))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: role.title)
                    Text(verbatim: role.summary)
                        .font(.system(size: DesignTokens.TypeRamp.label))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// The zero-permission alternative to the Finder shortcut (D-004).
private struct ServicesNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.m) {
            Image(systemName: "contextualmenu.and.cursorarrow")
                .font(.system(size: 15))
                .foregroundStyle(Color.iris)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.iris.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text("No permissions? Use the Services menu")
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                Text("Right-click files in Finder › Services › “Open in \(Brand.name) Wheel”. To give it a shortcut, go to System Settings › Keyboard › Keyboard Shortcuts › Services › Files and Folders.")
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Space.s)
            Button("Keyboard Shortcuts…") { SystemSettingsLink.open(SystemSettingsLink.keyboardShortcuts) }
                .controlSize(.small)
                .accessibilityIdentifier("keys.openServicesShortcuts")
        }
    }
}

// MARK: - Tap test

/// Watches modifier presses inside the Settings window (a local monitor:
/// no permission needed) and says whether each one counted as a tap.
@MainActor
final class TapTester: ObservableObject {
    enum Result: Equatable {
        case idle
        case pressing(TriggerKey)
        case tap(TriggerKey, TimeInterval)
        case held(TriggerKey, TimeInterval)
        case chord(Set<TriggerKey>)
    }

    @Published private(set) var result: Result = .idle
    private var detector: ModifierTapDetector
    private var monitor: LocalKeyMonitor?

    init(threshold: TimeInterval) {
        detector = ModifierTapDetector(threshold: threshold)
    }

    var threshold: TimeInterval {
        get { detector.threshold }
        set { detector.threshold = newValue }
    }

    func start() {
        guard monitor == nil else { return }
        let m = LocalKeyMonitor(onFlags: { [weak self] keys, time, _ in
            self?.flags(keys, time)
        }, onKeyDown: { [weak self] _ in
            self?.detector.otherKeyPressed()
            return false
        })
        m.start()
        monitor = m
    }

    func stop() {
        monitor?.stop()
        monitor = nil
        detector.reset()
    }

    /// Exposed for tests.
    func flags(_ keys: Set<TriggerKey>, _ time: TimeInterval) {
        if let outcome = detector.flagsChanged(to: keys, at: time) {
            switch outcome {
            case .tap(let k, let d): result = .tap(k, d)
            case .held(let k, let d): result = .held(k, d)
            case .chord(let ks): result = .chord(ks)
            }
        } else if let k = detector.pendingKey {
            result = .pressing(k)
        }
    }
}

private struct TapTestArea: View {
    let threshold: TimeInterval
    let triggers: TriggerAssignment
    @StateObject private var tester: TapTester

    init(threshold: TimeInterval, triggers: TriggerAssignment) {
        self.threshold = threshold
        self.triggers = triggers
        _tester = StateObject(wrappedValue: TapTester(threshold: threshold))
    }

    var body: some View {
        HStack(spacing: DesignTokens.Space.m) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30)
                .contentTransition(.opacity)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .medium))
                Text(verbatim: subtitle)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Space.m)
        .padding(.vertical, DesignTokens.Space.m)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(tint.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(tint.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: tester.result == .idle ? [4, 3] : []))
        }
        .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: tester.result)
        .onAppear { tester.threshold = threshold; tester.start() }
        .onDisappear { tester.stop() }
        .onChangeCompat(of: threshold) { tester.threshold = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("keys.tapTest")
    }

    private var keysHint: String {
        TriggerRole.allCases.map { triggers[$0].displayName }.joined(separator: ", ")
    }

    private var title: String {
        switch tester.result {
        case .idle: String(localized: "Try it: tap a trigger key now")
        case .pressing(let k): String(localized: "Holding \(k.displayName)…")
        case .tap(let k, _): String(localized: "Tap detected ✓ \(k.displayName)")
        case .held(let k, let d): String(localized: "Held \(k.displayName) for \(seconds(d)) — not a tap")
        case .chord(let ks): String(localized: "\(ks.sorted { $0.rawValue < $1.rawValue }.map(\.symbol).joined(separator: " + ")) together — not a tap")
        }
    }

    private var subtitle: String {
        switch tester.result {
        case .idle:
            return String(localized: "\(keysHint). Watched only while this window is open.")
        case .pressing:
            return String(localized: "Let go within \(seconds(threshold)).")
        case .tap(let k, let d):
            if let role = triggers.role(for: k) {
                return String(localized: "\(seconds(d)) — this opens the \(role.title) wheel mid-drag.")
            }
            return String(localized: "\(seconds(d)) — but \(k.name) isn’t assigned to a wheel.")
        case .held:
            return String(localized: "Press and let go within \(seconds(threshold)), or make taps more relaxed above.")
        case .chord:
            return String(localized: "Use one key on its own.")
        }
    }

    private var icon: String {
        switch tester.result {
        case .idle: "hand.tap"
        case .pressing: "hourglass"
        case .tap: "checkmark.circle.fill"
        case .held: "tortoise.fill"
        case .chord: "rectangle.on.rectangle.slash"
        }
    }

    private var tint: Color {
        switch tester.result {
        case .idle, .pressing: .iris
        case .tap: .haloSuccess
        case .held, .chord: .haloMist
        }
    }

    private func seconds(_ t: TimeInterval) -> String {
        OptionsFormLogic.display(t, decimals: 2, unit: "s")
    }
}
