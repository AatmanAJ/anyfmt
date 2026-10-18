import Foundation

/// Bundle that owns HaloCore's string catalog.
private final class HaloCoreBundleToken {}

public extension Bundle {
    /// The HaloCore framework bundle (owner of `Sources/Shared/Localizable.xcstrings`).
    static let haloCore = Bundle(for: HaloCoreBundleToken.self)
}

/// Localised string from HaloCore's catalog. Use for every user-facing string
/// defined in HaloCore (format names, option labels, error messages).
@inlinable
public func L(_ key: String.LocalizationValue, comment: StaticString = "") -> String {
    String(localized: key, bundle: .haloCore, comment: comment)
}
