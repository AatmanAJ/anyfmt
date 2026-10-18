import SwiftUI
import HaloCore

/// One calm screen shown when someone taps a Pro segment they can't use yet.
/// Says what it does, that it uploads, and that everything local stays free.
/// Never a nag: it appears only in response to tapping a cloud feature, and
/// "Not now" closes it for good.
///
/// Editorial layout: a cobalt-band glyph tile (the one band on this surface),
/// the feature name as a display headline, plain copy, the facts in a
/// charcoal tile, and a blue pill bottom right.
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
    @Environment(\.colorSchemeContrast) private var contrast

    private typealias Space = DesignTokens.Space
    private typealias TypeRamp = DesignTokens.TypeRamp
    private typealias T = DesignTokens.Component.Cloud

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            HStack(alignment: .top) {
                CloudGlyphTile(symbol: CloudCopy.glyph(for: feature))
                Spacer()
                CloudProChip()
            }

            VStack(alignment: .leading, spacing: Space.m) {
                DisplayText(CloudCopy.title(for: feature), size: T.headline)
                    .foregroundStyle(CloudStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(CloudCopy.summary(for: feature))
                    .font(.system(size: TypeRamp.title))
                    .foregroundStyle(CloudStyle.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Space.m) {
                fact("icloud.and.arrow.up", CloudCopy.uploadFact(for: feature, server: serverName))
                fact("laptopcomputer", String(localized: "Every conversion, tool and action on your Mac stays free, with no account."))
                if reason == .notInPlan {
                    fact("person.crop.circle.badge.checkmark", String(localized: "Your current plan doesn’t include this."))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cloudTile(highContrast: CloudStyle.isHighContrast(contrast))

            HStack(spacing: Space.s) {
                Spacer()
                Button(String(localized: "Not Now"), action: onNotNow)
                    .buttonStyle(.haloQuiet)
                    .keyboardShortcut(.cancelAction)
                Button(reason == .signedOut ? String(localized: "Sign In…") : String(localized: "See Plans…"), action: onPrimary)
                    .buttonStyle(.haloPrimary)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityHint(reason == .signedOut
                        ? Text("Opens \(serverName) in your browser")
                        : Text("Opens your plan on \(serverName) in your browser"))
            }
        }
        .padding(T.panelPadding)
        .frame(width: T.explainerWidth)
        .background(CloudStyle.window)
    }

    private func fact(_ glyph: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: glyph)
                .foregroundStyle(CloudStyle.irisText)
                .frame(width: T.factIconWidth)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: TypeRamp.body))
                .foregroundStyle(CloudStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A square glyph on the cobalt band: the one band per cloud surface. Flat
/// cobalt with Reduce Transparency or Increased Contrast (BandGradient).
struct CloudGlyphTile: View {
    let symbol: String
    private typealias T = DesignTokens.Component.Cloud

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: T.glyphSize, weight: .semibold))
            .foregroundStyle(CloudStyle.onAccent)
            .frame(width: T.glyphTile, height: T.glyphTile)
            .background {
                BandGradient(bands: DesignTokens.Band.cobalt, flat: DesignTokens.Band.cobaltFlat)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
            }
            .accessibilityHidden(true)
    }
}

extension View {
    /// A charcoal tile for the cloud screens; outlined in increased contrast.
    func cloudTile(highContrast: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
        return padding(DesignTokens.Component.Tile.padding)
            .background(shape.fill(CloudStyle.tile))
            .haloBorder(shape, highContrast ? CloudStyle.hairline : .clear)
    }
}
