import SwiftUI
import HaloCore

/// One calm screen shown when someone taps a Pro segment they can't use yet.
/// Says what it does, that it uploads, and that everything local stays free.
/// Never a nag: it appears only in response to tapping a cloud feature, and
/// "Not now" closes it for good.
struct ProExplainerView: View {
    enum Reason: Equatable {
        /// Not signed in on this server.
        case signedOut
        /// Signed in, but the plan doesn't include the feature.
        case notInPlan
    }

    let feature: CloudFeature
    let serverName: String
    var reason: Reason = .signedOut
    let onPrimary: () -> Void
    let onNotNow: () -> Void

    private typealias Space = DesignTokens.Space
    private typealias TypeRamp = DesignTokens.TypeRamp

    var body: some View {
        VStack(spacing: Space.l) {
            ZStack {
                Circle()
                    .fill(CloudStyle.iris.opacity(0.14))
                    .frame(width: 64, height: 64)
                Image(systemName: CloudCopy.glyph(for: feature))
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(CloudStyle.iris)
            }
            .accessibilityHidden(true)

            VStack(spacing: Space.s) {
                HStack(spacing: Space.s) {
                    Text(CloudCopy.title(for: feature))
                        .font(.system(size: TypeRamp.headline, weight: .semibold))
                    CloudProChip()
                }
                .accessibilityElement(children: .combine)
                Text(CloudCopy.summary(for: feature))
                    .font(.system(size: TypeRamp.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Space.s) {
                fact("icloud.and.arrow.up", String(localized: "Uploads to \(serverName). Results come back to your Mac."))
                fact("laptopcomputer", String(localized: "Every conversion, tool and action on your Mac stays free, with no account."))
                if reason == .notInPlan {
                    fact("person.crop.circle.badge.checkmark", String(localized: "Your current plan doesn’t include this."))
                }
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium).fill(Color.primary.opacity(0.04)))

            HStack(spacing: Space.m) {
                Button(String(localized: "Not Now"), action: onNotNow)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                Button(reason == .signedOut ? String(localized: "Sign In…") : String(localized: "See Plans…"), action: onPrimary)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(Space.xxl)
        .frame(width: 400)
    }

    private func fact(_ glyph: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: glyph)
                .foregroundStyle(CloudStyle.mist)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: TypeRamp.body))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
