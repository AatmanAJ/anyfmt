import Foundation

/// Bundle that owns AnyfmtCore's string catalog.
private final class AnyfmtCoreBundleToken {}

public extension Bundle {
    /// The AnyfmtCore framework bundle (owner of `Sources/Shared/Localizable.xcstrings`).
    static let anyfmtCore = Bundle(for: AnyfmtCoreBundleToken.self)
}

/// Localised string from AnyfmtCore's catalog. Use for every user-facing string
/// defined in AnyfmtCore (format names, option labels, error messages).
@inlinable
public func L(_ key: String.LocalizationValue, comment: StaticString = "") -> String {
    String(localized: key, bundle: .anyfmtCore, comment: comment)
}
