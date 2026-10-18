import AppKit
import SwiftUI
import HaloCore

/// Building blocks shared by lane G1's editors. Namespaced so nothing clashes
/// with other lanes in the app module.
enum ImageEditorKit {
    // MARK: Colour

    static func dynamic(_ pair: (light: Int, dark: Int)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            let hex = (dark == .darkAqua || dark == .accessibilityHighContrastDarkAqua) ? pair.dark : pair.light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    static var accent: Color { dynamic(DesignTokens.Palette.iris) }
    static var mint: Color { dynamic(DesignTokens.Palette.mint) }
    static var danger: Color { dynamic(DesignTokens.Palette.danger) }

    static func color(hex: String) -> Color {
        guard let c = HexColor.components(hex) else { return .black }
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    // MARK: Geometry

    /// Largest rect of `size`'s aspect inside `bounds`, centred.
    static func fit(_ size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let s = min(bounds.width / size.width, bounds.height / size.height)
        let w = size.width * s, h = size.height * s
        return CGRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h).integral
    }

    static func normalized(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGPoint(x: (p.x - rect.minX) / rect.width, y: (p.y - rect.minY) / rect.height)
    }

    static func denormalized(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
    }

    static func denormalized(_ r: CGRect, in rect: CGRect) -> CGRect {
        CGRect(x: rect.minX + r.minX * rect.width, y: rect.minY + r.minY * rect.height, width: r.width * rect.width, height: r.height * rect.height)
    }

    static func clamp01(_ p: CGPoint) -> CGPoint { CGPoint(x: min(1, max(0, p.x)), y: min(1, max(0, p.y))) }

    static func pixelText(_ size: CGSize) -> String {
        "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) px"
    }

    // MARK: Preview loading

    /// Longest edge used for live previews: big enough for a Retina canvas,
    /// small enough that Core Image re-renders well inside 50 ms.
    static let previewEdge = 1400

    static func preview(_ url: URL, edge: Int = previewEdge) -> CGImage? {
        ImageSupport.thumbnail(url, maxPixelSize: edge)
    }
}

// MARK: - Views

extension ImageEditorKit {
    /// Sidebar section: small caps-style title above its content.
    struct Section<Content: View>: View {
        let title: String
        @ViewBuilder var content: Content

        init(_ title: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
                Text(title)
                    .font(.system(size: DesignTokens.TypeRamp.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                content
            }
        }
    }

    /// The image, aspect-fitted with breathing room, plus an overlay that
    /// receives the image's on-screen rect.
    struct FittedImage<Overlay: View>: View {
        let image: CGImage?
        var size: CGSize? = nil
        var padding: CGFloat = DesignTokens.Space.xl
        var checkerboard = false
        @ViewBuilder var overlay: (CGRect) -> Overlay

        var body: some View {
            GeometryReader { geo in
                let imageSize = size ?? image.map { CGSize(width: $0.width, height: $0.height) } ?? CGSize(width: 4, height: 3)
                let rect = ImageEditorKit.fit(imageSize, in: CGRect(origin: .zero, size: geo.size).insetBy(dx: padding, dy: padding))
                ZStack(alignment: .topLeading) {
                    Group {
                        if checkerboard { Checkerboard().frame(width: rect.width, height: rect.height) }
                        if let image {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .interpolation(.high)
                                .frame(width: rect.width, height: rect.height)
                        } else {
                            ProgressView().controlSize(.small).frame(width: rect.width, height: rect.height)
                        }
                    }
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
                    .offset(x: rect.minX, y: rect.minY)
                    overlay(rect)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            }
        }
    }

    /// Transparency backdrop.
    struct Checkerboard: View {
        var cell: CGFloat = 8
        var body: some View {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.96)))
                var path = Path()
                var y: CGFloat = 0, row = 0
                while y < size.height {
                    var x: CGFloat = row % 2 == 0 ? 0 : cell
                    while x < size.width { path.addRect(CGRect(x: x, y: y, width: cell, height: cell)); x += cell * 2 }
                    y += cell; row += 1
                }
                ctx.fill(path, with: .color(Color(white: 0.86)))
            }
            .accessibilityHidden(true)
        }
    }

    /// A slider drawn in SwiftUI so it can reset on double-click and fill
    /// from its neutral value (exposure, warmth …). Adjustable for VoiceOver.
    struct ValueSlider: View {
        let label: String
        @Binding var value: Double
        let range: ClosedRange<Double>
        var step: Double = 0.01
        var neutral: Double
        var format: (Double) -> String
        var onEditingEnded: () -> Void = {}

        @State private var dragging = false
        @Environment(\.colorSchemeContrast) private var contrast

        var body: some View {
            VStack(alignment: .leading, spacing: DesignTokens.Space.xs) {
                HStack {
                    Text(label).font(.system(size: DesignTokens.TypeRamp.body))
                    Spacer()
                    Text(format(value))
                        .font(.system(size: DesignTokens.TypeRamp.caption).monospacedDigit())
                        .foregroundStyle(value == neutral ? .secondary : .primary)
                }
                GeometryReader { geo in
                    let w = geo.size.width
                    let x = position(value, w)
                    let n = position(neutral, w)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(contrast == .increased ? 0.3 : 0.12)).frame(height: 4)
                        Capsule().fill(ImageEditorKit.accent)
                            .frame(width: abs(x - n), height: 4)
                            .offset(x: min(x, n))
                        if neutral != range.lowerBound {
                            Rectangle().fill(Color.primary.opacity(0.35)).frame(width: 1, height: 8).offset(x: n - 0.5)
                        }
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().strokeBorder(Color.black.opacity(contrast == .increased ? 0.6 : 0.18), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.25), radius: dragging ? 3 : 1.5, y: 1)
                            .frame(width: 16, height: 16)
                            .offset(x: x - 8)
                    }
                    .frame(height: 18)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            dragging = true
                            set(fraction: g.location.x / max(1, w))
                        }
                        .onEnded { _ in dragging = false; onEditingEnded() })
                    .simultaneousGesture(TapGesture(count: 2).onEnded { value = neutral; onEditingEnded() })
                }
                .frame(height: 18)
            }
            .help(String(localized: "Double-click to reset"))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(format(value))
            .accessibilityHint(String(localized: "Double-click the slider to reset"))
            .accessibilityAdjustableAction { direction in
                let big = (range.upperBound - range.lowerBound) / 20
                switch direction {
                case .increment: value = min(range.upperBound, value + max(step, big))
                case .decrement: value = max(range.lowerBound, value - max(step, big))
                @unknown default: break
                }
                onEditingEnded()
            }
        }

        private func position(_ v: Double, _ w: CGFloat) -> CGFloat {
            let f = (v - range.lowerBound) / (range.upperBound - range.lowerBound)
            return 8 + CGFloat(min(1, max(0, f))) * max(0, w - 16)
        }

        private func set(fraction raw: CGFloat) {
            let f = Double(min(1, max(0, raw)))
            var v = range.lowerBound + f * (range.upperBound - range.lowerBound)
            v = (v / step).rounded() * step
            // Gentle detent at the neutral value.
            if abs(v - neutral) < (range.upperBound - range.lowerBound) * 0.015 { v = neutral }
            value = min(range.upperBound, max(range.lowerBound, v))
        }
    }

    /// Row of colour swatches plus the system colour picker.
    struct SwatchPicker: View {
        @Binding var hex: String
        var swatches: [String] = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#0A84FF", "#6E56F8", "#1C1B22", "#FFFFFF"]

        var body: some View {
            HStack(spacing: 6) {
                ForEach(swatches, id: \.self) { s in
                    let selected = s.uppercased() == hex.uppercased()
                    Button { hex = s } label: {
                        Circle()
                            .fill(ImageEditorKit.color(hex: s))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5))
                            .overlay(Circle().strokeBorder(ImageEditorKit.accent, lineWidth: selected ? 2 : 0).padding(-3))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.name(s))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                let custom = !swatches.contains { $0.uppercased() == hex.uppercased() }
                Button { ColorPanelBridge.shared.open(hex: hex) { hex = $0 } } label: {
                    Circle()
                        .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
                        .overlay(Circle().fill(custom ? ImageEditorKit.color(hex: hex) : .clear).padding(4))
                        .overlay(Circle().strokeBorder(ImageEditorKit.accent, lineWidth: custom ? 2 : 0).padding(-3))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Custom colour…"))
                .accessibilityLabel(String(localized: "Custom colour"))
                .accessibilityAddTraits(custom ? .isSelected : [])
            }
        }

        static func name(_ hex: String) -> String {
            switch hex.uppercased() {
            case "#FF3B30": String(localized: "Red")
            case "#FF9500": String(localized: "Orange")
            case "#FFCC00": String(localized: "Yellow")
            case "#34C759": String(localized: "Green")
            case "#0A84FF": String(localized: "Blue")
            case "#6E56F8": String(localized: "Violet")
            case "#1C1B22", "#000000": String(localized: "Black")
            case "#FFFFFF": String(localized: "White")
            default: hex
            }
        }
    }

    /// A round well showing a colour; click opens the system colour panel.
    struct ColorWell: View {
        let label: String
        @Binding var hex: String

        var body: some View {
            HStack(spacing: DesignTokens.Space.s) {
                Text(label).font(.system(size: DesignTokens.TypeRamp.body))
                Button { ColorPanelBridge.shared.open(hex: hex) { hex = $0 } } label: {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(ImageEditorKit.color(hex: hex))
                        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.small).strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5))
                        .frame(width: 34, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityValue(SwatchPicker.name(hex))
            }
        }
    }

    /// One-line hint text under controls.
    struct Hint: View {
        let text: String
        init(_ text: String) { self.text = text }
        var body: some View {
            Text(text)
                .font(.system(size: DesignTokens.TypeRamp.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Keyboard

/// Captures key presses for canvas editing (nudge, delete) on macOS 13,
/// where SwiftUI has no `onKeyPress`. Text fields keep their keys because
/// this view only handles events while it is the first responder.
struct ImageEditorKeyCatcher: NSViewRepresentable {
    final class Handle {
        weak var view: NSView?
        @MainActor func focus() { if let v = view { v.window?.makeFirstResponder(v) } }
    }

    let handle: Handle
    /// Return true when handled.
    let onKey: (NSEvent) -> Bool

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.onKey = onKey
        handle.view = v
        return v
    }

    func updateNSView(_ v: CatcherView, context: Context) {
        v.onKey = onKey
        handle.view = v
    }

    final class CatcherView: NSView {
        var onKey: ((NSEvent) -> Bool)?
        override var acceptsFirstResponder: Bool { true }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            // Take focus when the editor opens so arrow keys work at once.
            DispatchQueue.main.async { [weak self] in
                guard let self, let w = self.window, !(w.firstResponder is NSTextView) else { return }
                w.makeFirstResponder(self)
            }
        }
        override func keyDown(with event: NSEvent) {
            if onKey?(event) != true { super.keyDown(with: event) }
        }
    }
}

extension NSEvent {
    var isDeleteKey: Bool { keyCode == 51 || keyCode == 117 }
    /// (dx, dy) for arrow keys, y down; nil otherwise.
    var arrowDelta: CGPoint? {
        switch keyCode {
        case 123: CGPoint(x: -1, y: 0)
        case 124: CGPoint(x: 1, y: 0)
        case 125: CGPoint(x: 0, y: 1)
        case 126: CGPoint(x: 0, y: -1)
        default: nil
        }
    }
}

/// Routes the shared `NSColorPanel` to whichever well opened it last.
@MainActor
final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    private var onChange: ((String) -> Void)?

    func open(hex: String, onChange: @escaping (String) -> Void) {
        self.onChange = nil // don't echo the initial colour
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        if let c = HexColor.components(hex) {
            panel.color = NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
        }
        self.onChange = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        let c = sender.color.usingColorSpace(.sRGB) ?? .black
        onChange?(HexColor.string(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent)))
    }
}

/// Closes an editor window from inside its SwiftUI content.
@MainActor
final class ImageEditorWindowBox {
    weak var controller: EditorWindow?
    func close() { controller?.close() }
}
