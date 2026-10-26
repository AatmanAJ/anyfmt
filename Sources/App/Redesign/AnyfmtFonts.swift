import AppKit
import CoreText
import AnyfmtCore
import SwiftUI

/// The bundled display face (Inter Display, SIL OFL 1.1, LICENSES/inter-4.1).
/// Registered for this process only, so nothing is installed system-wide.
enum AnyfmtFonts {
    /// Runs once, thread-safely (a lazy static).
    private static let registration: Void = {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls where url.lastPathComponent.hasPrefix("InterDisplay") {
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

/// Hard-edged vertical bands, each a short top-to-bottom fade into the next
/// colour: the "stripes of light" signature. Flat when bands are switched off.
struct BandGradient: View {
    let bands: [Int]
    var flat: Int? = nil
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if reduceTransparency || contrast == .increased, let flat {
            Color(hex: flat)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(bands.enumerated()), id: \.offset) { i, band in
                    LinearGradient(colors: [Color(hex: band), Color(hex: bands[min(i + 1, bands.count - 1)])],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
        }
    }
}
