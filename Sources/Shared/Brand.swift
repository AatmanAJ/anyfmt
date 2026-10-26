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
    public static var sourceURL: URL? { URL(string: "https://github.com/aiwithaj/\(slug)") }
    public static let licence = "AGPL-3.0-only"
}
