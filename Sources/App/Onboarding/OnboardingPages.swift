import SwiftUI
import AnyfmtCore

// Every page: a sentence-case headline at the top left, a plain subtitle, then
// at most one charcoal tile of controls. The page's band column (if any) is drawn
// by `OnboardingView`; nothing here adds colour of its own. The quieter pages set
// the headline at the top and the controls at the foot, like a poster.

/// Screen 1. The heat band column on the right is the page's spotlight.
struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeadline(text: String(localized: "Convert\nwhile you\ndrag.", comment: "Onboarding welcome headline; keep each line short"),
                               size: DesignTokens.Component.Onboarding.headlineWelcome)
            OnboardingSubtitle(text: String(localized: "Convert, edit and share files from the drag you're already doing. Press a key mid-drag and a wheel of options opens around the pointer."))
                .padding(.top, DesignTokens.Space.l + DesignTokens.Space.xxs)
            Spacer(minLength: DesignTokens.Space.l)
            OnboardingTile(spacing: DesignTokens.Space.s + DesignTokens.Space.xxs) {
                FactLine(tag: String(localized: "Local", comment: "Onboarding welcome fact tag"),
                         text: String(localized: "Hundreds of conversions, on this Mac, with nothing to install."))
                OnboardingDivider()
                FactLine(tag: String(localized: "Private", comment: "Onboarding welcome fact tag"),
                         text: Brand.cloudAvailable ? String(localized: "Files never leave your Mac unless you choose a cloud feature.")
                                                     : String(localized: "Files never leave your Mac."))
                OnboardingDivider()
                FactLine(tag: String(localized: "Free", comment: "Onboarding welcome fact tag"),
                         text: String(localized: "Every local feature is free, with no account and no time limit."))
            }
        }
    }
}

/// A short display tag and one plain sentence.
private struct FactLine: View {
    let tag: String
    let text: String

    private typealias T = DesignTokens.Component.Onboarding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Space.m) {
            Text(verbatim: tag)
                .font(.anyfmtDisplay(T.tagSize))
                .displayTracking(T.tagSize)
                .frame(width: T.tagWidth, alignment: .leading)
            Text(verbatim: text)
                .font(.system(size: DesignTokens.TypeRamp.body))
                .foregroundStyle(Color.anyfmtSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Screen 3: no permissions needed; the opt-in Finder shortcut explains its own.
/// The cobalt band column is the page's spotlight.
struct OnboardingPermissionsPage: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeadline(text: String(localized: "No permissions\nneeded.", comment: "Onboarding permissions headline; keep each line short"),
                               size: DesignTokens.Typeface.Size.displayL)
            OnboardingSubtitle(text: String(localized: "The wheel works without any special access. There’s nothing to approve."))
                .padding(.top, DesignTokens.Space.m)
            Spacer(minLength: DesignTokens.Space.l)
            OnboardingTile {
                OnboardingToggleRow(title: String(localized: "Optional: press Return in Finder to open the wheel"),
                                    subtitle: String(localized: "Select files and press Return instead of dragging. This one extra needs the permissions below.",
                                                     comment: "Onboarding: the Finder shortcut toggle"),
                                    isOn: Binding(get: { settings.finderShortcutEnabled }, set: { model.setFinderShortcut($0) }),
                                    identifier: "onboarding.finderShortcut")
                if settings.finderShortcutEnabled {
                    OnboardingDivider()
                    PermissionsCoachList(coach: model.coach)
                        .transition(.opacity)
                }
            }
            OnboardingFootnote(text: String(localized: "Prefer no permissions at all? Right-click files › Services › Open in \(Brand.name) Wheel does the same."))
                .padding(.top, DesignTokens.Space.m)
        }
        .animation(OnboardingMotion.page(reduceMotion: reduceMotion), value: settings.finderShortcutEnabled)
    }
}

/// Screen 4: launch at login. Restraint: type and one tile.
struct OnboardingLaunchPage: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeadline(text: String(localized: "Ready when\nyou drag.", comment: "Onboarding launch-at-login headline; keep each line short"))
            OnboardingSubtitle(text: String(localized: "\(Brand.name) lives in the menu bar, with no Dock icon and no window. Start it with your Mac so the wheel is always there."))
                .padding(.top, DesignTokens.Space.l + DesignTokens.Space.xxs)
            Spacer(minLength: DesignTokens.Space.xl)
            OnboardingTile {
                LaunchAtLoginRow(model: model.loginItem, card: true)
            }
            OnboardingFootnote(text: String(localized: "You can change this any time in Settings › General, or in System Settings › General › Login Items."))
                .padding(.top, DesignTokens.Space.m)
        }
    }
}

/// Screen 5: update checks (off by default).
struct OnboardingUpdatesPage: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeadline(text: String(localized: "Stay up\nto date.", comment: "Onboarding updates headline; keep each line short"))
            OnboardingSubtitle(text: String(localized: "\(Brand.name) never connects to the internet unless you ask it to."))
                .padding(.top, DesignTokens.Space.l + DesignTokens.Space.xxs)
            Spacer(minLength: DesignTokens.Space.xl)
            OnboardingTile {
                OnboardingToggleRow(title: String(localized: "Check for updates automatically"),
                                    subtitle: model.info.updateLine,
                                    isOn: Binding(get: { settings.updateChecksEnabled }, set: { model.setUpdateChecks($0) }),
                                    identifier: "onboarding.updateChecks")
            }
            OnboardingFootnote(text: String(localized: "Free and open source. Everything on your Mac stays free, with no account."))
                .padding(.top, DesignTokens.Space.m)
        }
    }
}

/// Screen 6: optional, last, guilt-free. The quiet page: one sentence, a key
/// field with an Activate pill, and "Start Using anyfmt" as the default, which skips.
struct OnboardingActivatePage: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var licence: LicenceActivationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeadline(text: String(localized: "Got a\nPro key?", comment: "Onboarding activation headline; keep each line short"))
            OnboardingSubtitle(text: String(localized: "Optional. Pro adds cloud features like share links and cloud conversions. Nothing local ever needs a key, so skipping changes nothing.",
                                            comment: "Onboarding activation page"))
                .padding(.top, DesignTokens.Space.l + DesignTokens.Space.xxs)
            Spacer(minLength: DesignTokens.Space.xl)
            KeyEntry(licence: licence)
                .frame(maxWidth: DesignTokens.Component.Onboarding.tileWidth, alignment: .leading)
            HStack(spacing: DesignTokens.Space.xs) {
                Text("Or sign in to your account", comment: "Onboarding activation page")
                    .font(.system(size: DesignTokens.TypeRamp.body))
                    .foregroundStyle(Color.anyfmtSecondaryText)
                Button(String(localized: "Sign In…", comment: "Onboarding activation page")) { model.signIn() }
                    .buttonStyle(AccentTextButtonStyle())
                    .accessibilityIdentifier("onboarding.signIn")
                Text(verbatim: "·").foregroundStyle(Color.anyfmtSecondaryText).accessibilityHidden(true)
                Text("You can do this later in Settings › Account.", comment: "Onboarding activation page")
                    .font(.system(size: DesignTokens.TypeRamp.body))
                    .foregroundStyle(Color.anyfmtSecondaryText)
            }
            .padding(.top, DesignTokens.Space.l)
        }
    }
}

/// The licence field as a pill, Paste, and the Activate pill. Uses the same
/// model (and strings) as Settings › Account.
private struct KeyEntry: View {
    @ObservedObject var licence: LicenceActivationModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            if let status = licence.status {
                Label {
                    Text(verbatim: status.message)
                } icon: {
                    Image(systemName: status.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(status.isValid ? Color.accentText : Color.anyfmtDanger)
                }
                .font(.system(size: DesignTokens.TypeRamp.body))
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: DesignTokens.Space.s) {
                TextField(String(localized: "ANYFMT1-…", comment: "Placeholder for the licence key field"), text: $licence.keyText)
                    .textFieldStyle(.plain)
                    .font(.system(size: DesignTokens.TypeRamp.body, design: .monospaced))
                    .focused($focused)
                    .padding(.horizontal, DesignTokens.Space.l)
                    .frame(height: DesignTokens.Component.Pill.largeHeight)
                    .background(PillBorder(fill: Color.anyfmtTile,
                                           border: focused ? Color.token(DesignTokens.Semantic.focusRing) : Color.anyfmtHairline,
                                           width: focused ? DesignTokens.Component.Focus.ringWidth : DesignTokens.Shape.hairline))
                    .onSubmit { if licence.canActivate { licence.activate() } }
                    .accessibilityLabel(Text("Licence key", comment: "VoiceOver label of the licence key field"))
                Button(String(localized: "Paste", comment: "Pastes a licence key from the clipboard")) { licence.pasteFromClipboard() }
                    .buttonStyle(AnyfmtPillButtonStyle(kind: .quiet, large: true))
                Button(String(localized: "Activate", comment: "Activates a pasted licence key")) { licence.activate() }
                    // Quiet until there's a key to activate, then the orange pill.
                    .buttonStyle(AnyfmtPillButtonStyle(kind: licence.canActivate ? .secondary : .quiet, large: true))
                    .disabled(!licence.canActivate)
                    .accessibilityIdentifier("onboarding.activate")
            }
            if let message = licence.message {
                Label {
                    Text(verbatim: message)
                } icon: {
                    Image(systemName: licence.isError ? "exclamationmark.circle" : "checkmark.circle")
                }
                .font(.system(size: DesignTokens.TypeRamp.label))
                .foregroundStyle(licence.isError ? Color.anyfmtDanger : Color.anyfmtSecondaryText)
            }
            OnboardingFootnote(text: String(localized: "Keys are checked on this Mac, offline. A key only unlocks cloud features; every local conversion, tool and action is free without one.",
                                            comment: "Explains what a licence key does"))
        }
    }
}

// MARK: - Pieces

/// Display lines in sentence case, set tight, like a poster. Lines come from the
/// localized string (one per `\n`) so translators choose the breaks.
struct OnboardingHeadline: View {
    let text: String
    var size: CGFloat = DesignTokens.Component.Onboarding.headline

    var body: some View {
        let lines = text.split(separator: "\n").map(String.init)
        VStack(alignment: .leading, spacing: size * DesignTokens.Component.Onboarding.headlineLeading) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
                    .font(.anyfmtDisplay(size))
                    .displayTracking(size)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(Color.anyfmtInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: lines.joined(separator: " ")))
        .accessibilityAddTraits(.isHeader)
    }
}

/// The plain sentence under a headline.
struct OnboardingSubtitle: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: DesignTokens.Component.Onboarding.subtitleSize))
            .foregroundStyle(Color.anyfmtSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: DesignTokens.Component.Onboarding.subtitleWidth, alignment: .leading)
    }
}

/// A charcoal tile for a page's controls (the one tile radius).
struct OnboardingTile<Content: View>: View {
    var spacing: CGFloat = DesignTokens.Space.m
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(DesignTokens.Space.l)
        .frame(maxWidth: DesignTokens.Component.Onboarding.tileWidth, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).fill(Color.anyfmtTile))
    }
}

struct OnboardingDivider: View {
    var body: some View {
        Rectangle().fill(Color.anyfmtHairline).frame(height: DesignTokens.Shape.hairline)
            .accessibilityHidden(true)
    }
}

/// Small print under a tile.
struct OnboardingFootnote: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: DesignTokens.TypeRamp.label))
            .foregroundStyle(Color.anyfmtSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: DesignTokens.Component.Onboarding.tileWidth, alignment: .leading)
    }
}

/// Title, subtitle and a trailing switch, in the page's own colours.
struct OnboardingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var identifier: String

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.l) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                Text(verbatim: title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                    .foregroundStyle(Color.anyfmtInk)
                Text(verbatim: subtitle)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(Color.anyfmtSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle(isOn: $isOn) { Text(verbatim: title) }
                .labelsHidden()
                .toggleStyle(AnyfmtSwitchStyle())
                .accessibilityIdentifier(identifier)
                .accessibilityHint(Text(verbatim: subtitle))
        }
    }
}

/// An inline text button in the accent text colour (AA on both surfaces).
private struct AccentTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
            .foregroundStyle(Color.accentText)
            .padding(.vertical, DesignTokens.Space.xs)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
