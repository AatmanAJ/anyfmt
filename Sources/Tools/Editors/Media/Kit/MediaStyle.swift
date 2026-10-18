import AppKit
import SwiftUI
import HaloCore

/// Colours and small building blocks shared by the media editors. Everything
/// comes from `DesignTokens`; colours resolve per appearance (light, dark,
/// increased contrast).
enum MediaStyle {
    static func color(_ pair: (light: Int, dark: Int)) -> Color {
        let light = pair.light, dark = pair.dark
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua,
                                                     .accessibilityHighContrastDarkAqua])
                .map { $0 == .darkAqua || $0 == .accessibilityHighContrastDarkAqua } ?? false
            return nsColor(hex: isDark ? dark : light)
        })
    }

    static func nsColor(hex: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    static let accent = color(DesignTokens.Palette.iris)
    static let mint = color(DesignTokens.Palette.mint)
    static let danger = color(DesignTokens.Palette.danger)
    static let success = color(DesignTokens.Palette.success)
    static let ink = color(DesignTokens.Palette.ink)

    /// Timeline geometry.
    static let stripHeight: CGFloat = 56
    static let handleWidth: CGFloat = 14
    static let rulerHeight: CGFloat = 18
    static let playheadWidth: CGFloat = 2

    static func caption(_ weight: Font.Weight = .regular) -> Font { .system(size: DesignTokens.TypeRamp.caption, weight: weight) }
    static func label(_ weight: Font.Weight = .regular) -> Font { .system(size: DesignTokens.TypeRamp.label, weight: weight) }
    static func body(_ weight: Font.Weight = .regular) -> Font { .system(size: DesignTokens.TypeRamp.body, weight: weight) }
    static var timecode: Font { .system(size: DesignTokens.TypeRamp.label, weight: .medium).monospacedDigit() }

    /// "h264" → "H.264", "pcm_s16le" → "PCM 16-bit".
    static func codecName(_ codec: String) -> String {
        switch codec {
        case "h264": return "H.264"
        case "hevc": return "HEVC"
        case "prores": return "ProRes"
        case "vp8": return "VP8"
        case "vp9": return "VP9"
        case "av1": return "AV1"
        case "mpeg4": return "MPEG-4"
        case "msmpeg4v3", "msmpeg4v2", "wmv1", "wmv2", "wmv3": return "Windows Media"
        case "aac": return "AAC"
        case "mp3": return "MP3"
        case "alac": return "Apple Lossless"
        case "flac": return "FLAC"
        case "opus": return "Opus"
        case "vorbis": return "Vorbis"
        case "wmav2", "wmav1": return "WMA"
        default:
            if codec.hasPrefix("pcm_") {
                let digits = codec.filter(\.isNumber)
                return digits.isEmpty ? "PCM" : "PCM \(digits)-bit"
            }
            return codec.uppercased()
        }
    }
}

/// A titled group in an editor sidebar.
struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            Text(title)
                .font(MediaStyle.caption(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// "Label ……… value" row.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: DesignTokens.Space.s)
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(MediaStyle.label())
        .accessibilityElement(children: .combine)
    }
}

/// Keyboard shortcut legend.
struct KeyHints: View {
    let hints: [(key: String, action: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, h in
                HStack(spacing: DesignTokens.Space.s) {
                    Text(h.key)
                        .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .frame(minWidth: 40)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.15)))
                    Text(h.action).font(MediaStyle.caption()).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A short explanatory note with an icon.
struct Note: View {
    let systemImage: String
    let text: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.s) {
            Image(systemName: systemImage).foregroundStyle(tint).frame(width: 16)
            Text(text).font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Spinner + message while media loads, or the failure message.
struct LoadingOverlay: View {
    let state: MediaLoadState

    var body: some View {
        switch state {
        case .loading(let message):
            VStack(spacing: DesignTokens.Space.m) {
                ProgressView().controlSize(.small)
                Text(message).font(MediaStyle.caption()).foregroundStyle(.secondary)
            }
            .padding(DesignTokens.Space.l)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(MediaStyle.label())
                .padding(DesignTokens.Space.l)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        case .ready:
            EmptyView()
        }
    }
}

enum MediaLoadState: Equatable {
    case loading(String)
    case ready
    case failed(String)

    var isReady: Bool { self == .ready }
}

extension View {
    /// Animation that respects Reduce Motion.
    func motion<V: Equatable>(_ reduce: Bool, value: V) -> some View {
        animation(reduce ? nil : .spring(response: DesignTokens.Motion.hoverResponse, dampingFraction: DesignTokens.Motion.hoverDamping), value: value)
    }
}
