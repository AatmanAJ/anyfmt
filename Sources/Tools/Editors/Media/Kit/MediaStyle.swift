import AppKit
import SwiftUI
import HaloCore

/// Colours and small building blocks shared by the media editors. Everything
/// comes from `DesignTokens`; colours resolve per appearance (light, dark,
/// increased contrast).
enum MediaStyle {
    static func color(_ pair: (light: Int, dark: Int)) -> Color { Color.token(pair) }

    static let accent = Color.iris
    static let mint = Color.mint
    static let danger = Color.haloDanger
    static let success = Color.haloSuccess
    static let ink = Color.haloInk
    static let warning = EditorPalette.warning

    /// Timeline geometry.
    static let stripHeight = EditorTokens.Timeline.stripHeight
    static let handleWidth = EditorTokens.Timeline.handleWidth
    static let rulerHeight = EditorTokens.Timeline.rulerHeight
    static let playheadWidth = EditorTokens.Timeline.playheadWidth

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

/// A titled group in an editor sidebar (a charcoal tile).
struct SidebarSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        EditorSection(title) { content }
    }
}

/// "Label ……… value" row.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Color.haloSecondaryText)
            Spacer(minLength: DesignTokens.Space.s)
            Text(value).fontWeight(.semibold).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(MediaStyle.label())
        .accessibilityElement(children: .combine)
    }
}

/// Keyboard shortcut legend.
struct KeyHints: View {
    let hints: [(key: String, action: String)]
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.xs + DesignTokens.Space.xxs) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, h in
                HStack(spacing: DesignTokens.Space.s) {
                    Text(h.key)
                        .font(.system(size: DesignTokens.TypeRamp.caption, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.haloInk)
                        .padding(.horizontal, DesignTokens.Space.s).padding(.vertical, DesignTokens.Space.xxs)
                        .frame(minWidth: EditorTokens.keyCapMinWidth)
                        .background(Capsule().fill(EditorPalette.chip))
                        .overlay(Capsule().strokeBorder(contrast == .increased ? Color.haloSecondaryText : Color.haloHairline,
                                                        lineWidth: DesignTokens.Shape.hairline))
                    Text(h.action).font(MediaStyle.caption()).foregroundStyle(Color.haloSecondaryText)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A short explanatory note with an icon. The icon carries the meaning
/// (check, warning, info) along with the words, never the tint alone.
struct Note: View {
    let systemImage: String
    let text: String
    var tint: Color = Color.haloSecondaryText

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.s) {
            Image(systemName: systemImage).foregroundStyle(tint).frame(width: 16)
            Text(text).font(MediaStyle.caption()).foregroundStyle(Color.haloSecondaryText).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The loading state while media opens, or why it couldn't be opened.
struct LoadingOverlay: View {
    let state: MediaLoadState

    var body: some View {
        switch state {
        case .loading(let message):
            EditorStateView(kind: .loading, title: message)
                .padding(DesignTokens.Space.xl)
        case .failed(let message):
            EditorStateView(kind: .problem, title: String(localized: "Can’t open this file"),
                            message: String(localized: "\(Self.sentence(message)) Your file hasn’t been changed."))
                .padding(DesignTokens.Space.xl)
        case .ready:
            EmptyView()
        }
    }

    /// Engine messages usually end in a full stop; make sure they do.
    static func sentence(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = t.last else { return t }
        return ".!?…".contains(last) ? t : t + "."
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
