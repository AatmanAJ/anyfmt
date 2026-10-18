import Foundation

/// What to do with embedded metadata (EXIF/IPTC/ID3/tags/PDF info).
public enum MetadataPolicy: String, Sendable, Codable, CaseIterable {
    /// Keep everything the target format can carry (default).
    case keep
    /// Keep orientation/colour profile, drop location + device + author fields.
    case stripPrivate
    /// Remove all metadata.
    case stripAll
}

/// Where and how outputs are written. Snapshot of user settings, passed into
/// every job so engines never read UserDefaults directly.
public struct OutputPolicy: Sendable, Codable, Hashable {
    public enum Location: Sendable, Codable, Hashable {
        /// Beside the original (default).
        case besideOriginal
        /// A fixed folder chosen in Settings.
        case folder(URL)
    }

    public var location: Location
    /// Name template. Tokens: {name} original base name, {ext} new extension
    /// (without dot), {format} target label, {tool} tool suffix, {date} yyyy-MM-dd.
    /// Default "{name}" for conversions; tools always get "-{tool}" appended.
    public var namePattern: String
    public var metadata: MetadataPolicy
    /// Copy creation/modification dates from the source for format conversions.
    public var preserveDates: Bool
    public var revealInFinder: Bool

    public init(location: Location = .besideOriginal, namePattern: String = "{name}",
                metadata: MetadataPolicy = .keep, preserveDates: Bool = true, revealInFinder: Bool = true) {
        self.location = location
        self.namePattern = namePattern
        self.metadata = metadata
        self.preserveDates = preserveDates
        self.revealInFinder = revealInFinder
    }

    public static let `default` = OutputPolicy()
}
