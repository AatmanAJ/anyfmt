import Foundation

/// The product name lives here and in `Config/Brand.xcconfig`. Nowhere else.
/// Everything user-visible derives from `Brand.name`.
public enum Brand {
    public static let name = "anyfmt"

    public static var slug: String { name.lowercased() }
    /// Matches BRAND_BUNDLE_ID in Brand.xcconfig.
    public static var bundleID: String { "app.\(slug)" }
    public static var urlScheme: String { slug }
    public static var cliName: String { slug }
    public static var sourceURL: URL? { URL(string: "https://github.com/AatmanAJ/\(slug)") }
    public static let licence = "AGPL-3.0-only"
    /// Whether the hosted cloud service (sign-in, Pro, share links, cloud jobs) exists yet.
    /// Off for v1: every cloud surface (wheel segments, the cloud option, Settings ›
    /// Account, the Pro onboarding page and menu item) is hidden. Flip it when the
    /// server is live and `CloudConfig.defaultServer` points at it (docs/BLOCKERS.md B-006).
    /// A `var` only so tests can cover both states; the app never writes it.
    nonisolated(unsafe) public static var cloudAvailable = false
}
