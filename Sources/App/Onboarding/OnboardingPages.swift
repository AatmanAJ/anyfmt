import SwiftUI
import HaloCore

/// Screen 2: no permissions needed; the opt-in Finder shortcut explains its two.
struct OnboardingPermissionsPage: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: DesignTokens.Space.xl) {
            PageIcon(symbol: "checkmark.shield", tint: .haloSuccess)
            PageHeader(title: String(localized: "No permissions needed"),
                       subtitle: String(localized: "The wheel works without any special access. There’s nothing to approve."))
            Card {
                CardToggle(title: String(localized: "Optional: press Return in Finder to open the wheel"),
                           subtitle: String(localized: "Select files and press Return instead of dragging. This one extra needs two permissions:"),
                           isOn: Binding(get: { settings.finderShortcutEnabled }, set: { model.setFinderShortcut($0) }),
                           identifier: "onboarding.finderShortcut")
                Divider()
                PermissionsCoachList(coach: model.coach)
                    .opacity(settings.finderShortcutEnabled ? 1 : 0.45)
                    .disabled(!settings.finderShortcutEnabled)
            }
            FootnoteText(text: String(localized: "Prefer no permissions at all? Right-click files › Services › Open in \(Brand.name) Wheel does the same."),
                         symbol: "contextualmenu.and.cursorarrow")
        }
        .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: settings.finderShortcutEnabled)
    }
}

/// Screen 3: launch at login.
struct OnboardingLaunchPage: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(spacing: DesignTokens.Space.xl) {
            PageIcon(symbol: "menubar.arrow.up.rectangle", tint: .iris)
            PageHeader(title: String(localized: "Ready when you drag"),
                       subtitle: String(localized: "\(Brand.name) lives in the menu bar, with no Dock icon and no window. Start it with your Mac so the wheel is always there."))
            Card {
                LaunchAtLoginRow(model: model.loginItem, card: true)
            }
            FootnoteText(text: String(localized: "You can change this any time in Settings › General, or in System Settings › General › Login Items."))
        }
    }
}

/// Screen 4: update checks (off by default) and finish.
struct OnboardingUpdatesPage: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: DesignTokens.Space.xl) {
            PageIcon(symbol: "arrow.down.circle", tint: .iris)
            PageHeader(title: String(localized: "Stay up to date"),
                       subtitle: String(localized: "\(Brand.name) never connects to the internet unless you ask it to."))
            Card {
                CardToggle(title: String(localized: "Check for updates automatically"),
                           subtitle: model.info.updateLine,
                           isOn: Binding(get: { settings.updateChecksEnabled }, set: { model.setUpdateChecks($0) }),
                           identifier: "onboarding.updateChecks")
            }
            FootnoteText(text: String(localized: "Free and open source. Everything on your Mac stays free, with no account."),
                         symbol: "heart")
        }
    }
}

// MARK: - Pieces

struct PageIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 64, height: 64)
            .background(Circle().fill(tint.opacity(0.12)))
            .overlay(Circle().strokeBorder(tint.opacity(0.2), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Grouped-form-style card for onboarding controls.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
            content
        }
        .padding(DesignTokens.Space.l)
        .frame(width: 540, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }
}
