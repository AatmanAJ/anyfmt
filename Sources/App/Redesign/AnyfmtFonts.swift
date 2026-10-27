import AppKit
import CoreText
import AnyfmtCore
import SwiftUI

/// The bundled display face (Inter Tight, SIL OFL 1.1, LICENSES/inter-4.1).
/// Registered for this process only, so nothing is installed system-wide.
enum AnyfmtFonts {
    /// Runs once, thread-safely (a lazy static).
    private static let registration: Void = {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls where url.lastPathComponent.hasPrefix("InterTight") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    static func registerBundled() { _ = registration }

    /// The display face at `size`, falling back to the system's heaviest weight.
    static func display(_ size: CGFloat, black: Bool = true) -> NSFont {
        registerBundled()
        let name = black ? DesignTokens.Typeface.displayBlack : DesignTokens.Typeface.displayExtraBold
        return NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: black ? .black : .heavy)
    }
}

extension Font {
    /// Heavy uppercase display type with the token tracking applied by `.displayTracking(size)`.
    static func anyfmtDisplay(_ size: CGFloat, black: Bool = true) -> Font {
        Font(AnyfmtFonts.display(size, black: black))
    }
}

extension View {
    /// Tight display tracking from the tokens.
    func displayTracking(_ size: CGFloat) -> some View {
        tracking(size * DesignTokens.Typeface.displayTracking)
    }
}

extension Color {
    /// sRGB colour from 0xRRGGBB.
    init(hex: Int) { self.init(nsColor: NSColor(hex: hex)) }

    /// A semantic token pair resolved for the view's appearance.
    static func token(_ pair: (light: Int, dark: Int)) -> Color { Color(nsColor: .anyfmt(pair)) }
}

/// The brand's fluted glass: the colours run as one smooth gradient, seen through soft
/// diagonal ribs at 31° (the website's hero, in miniature). Thin pieces such as progress
/// bars get the gradient alone. Flat with Reduce Transparency or Increased Contrast.
struct BandGradient: View {
    let bands: [Int]
    var flat: Int? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if reduceTransparency || contrast == .increased, let flat {
            Color(hex: flat)
        } else {
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size)
                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: bands.map { Color(hex: $0) }),
                    startPoint: CGPoint(x: 0, y: size.height), endPoint: CGPoint(x: size.width, y: 0)))
                guard min(size.width, size.height) >= 24 else { return }
                // One rib: a highlight rolling into a shadow, repeated across the diagonal.
                let pitch = max(28, min(64, min(size.width, size.height) * 0.22))
                let angle = Angle.degrees(31)
                let span = hypot(size.width, size.height)
                var glass = ctx
                glass.translateBy(x: size.width / 2, y: size.height / 2)
                glass.rotate(by: angle)
                let rib = Gradient(stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.13), location: 0.32),
                    .init(color: .white.opacity(0.02), location: 0.55),
                    .init(color: .black.opacity(0.06), location: 0.85),
                    .init(color: .black.opacity(0), location: 1),
                ])
                var x = -span
                while x < span {
                    let r = CGRect(x: x, y: -span, width: pitch, height: span * 2)
                    glass.fill(Path(r), with: .linearGradient(rib, startPoint: CGPoint(x: r.minX, y: 0), endPoint: CGPoint(x: r.maxX, y: 0)))
                    x += pitch
                }
            }
        }
    }
}
