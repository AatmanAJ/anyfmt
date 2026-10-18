import AppKit

/// One segment of a radial menu. Generic: the menu knows nothing about what an
/// item does. Hosts map their own model onto these.
public struct RadialItem: Identifiable, Equatable {
    /// How the segment balances its glyph and its title.
    public enum Prominence: Equatable, Sendable {
        /// Title-forward: short bold caps label with a small glyph above it
        /// (format targets such as "JPG", "MP4").
        case title
        /// Glyph-forward: a larger glyph with a small label under it, wrapping
        /// to two lines when needed (tools such as "Remove background").
        case glyph
    }

    /// Stable identity. Used to keep hover and to match segments across morphs.
    public var id: String
    public var title: String
    /// Optional secondary line (e.g. "via PNG"). Shown under the title when it
    /// fits and in the hub while hovered.
    public var subtitle: String?
    /// Glyph. Template images are tinted to match the segment state; others are
    /// drawn as-is.
    public var image: NSImage?
    /// Small chip under the label, e.g. "Pro".
    public var badge: String?
    /// Small glyph drawn inside the badge chip (or beside the glyph without a
    /// badge), e.g. a cloud for items that upload.
    public var accessory: NSImage?
    public var isEnabled: Bool
    public var prominence: Prominence
    /// Spoken by VoiceOver. Defaults to `title` (+ `subtitle`).
    public var accessibilityLabel: String?
    public var accessibilityHint: String?

    public init(id: String, title: String, subtitle: String? = nil, image: NSImage? = nil,
                badge: String? = nil, accessory: NSImage? = nil, isEnabled: Bool = true,
                prominence: Prominence = .glyph,
                accessibilityLabel: String? = nil, accessibilityHint: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.badge = badge
        self.accessory = accessory
        self.isEnabled = isEnabled
        self.prominence = prominence
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    /// Convenience for SF Symbols. The symbol is loaded as a template image.
    public init(id: String, title: String, symbolName: String, subtitle: String? = nil,
                badge: String? = nil, accessorySymbolName: String? = nil, isEnabled: Bool = true,
                prominence: Prominence = .glyph,
                accessibilityLabel: String? = nil, accessibilityHint: String? = nil) {
        self.init(id: id, title: title, subtitle: subtitle,
                  image: RadialItem.symbol(symbolName),
                  badge: badge, accessory: accessorySymbolName.flatMap(RadialItem.symbol),
                  isEnabled: isEnabled, prominence: prominence,
                  accessibilityLabel: accessibilityLabel, accessibilityHint: accessibilityHint)
    }

    /// Loads an SF Symbol as a template image, or nil if the name is unknown on this OS.
    public static func symbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    var spokenLabel: String {
        if let accessibilityLabel { return accessibilityLabel }
        if let subtitle, !subtitle.isEmpty { return "\(title), \(subtitle)" }
        return title
    }
}

/// What the hub (centre disc) shows.
public struct RadialHubContent: Equatable {
    /// The dragged file's thumbnail or icon.
    public var image: NSImage?
    /// More than 1 draws a stacked-cards look with a count badge.
    public var stackCount: Int
    /// Pill text while nothing is hovered, e.g. "2.4 MB" or "3 files".
    public var idleText: String

    public init(image: NSImage? = nil, stackCount: Int = 1, idleText: String = "") {
        self.image = image
        self.stackCount = max(1, stackCount)
        self.idleText = idleText
    }
}

/// An empty ring that accepts drops (e.g. a hotkey-summoned "drop files here" target).
public struct RadialDropZone: Equatable {
    public var title: String
    public var image: NSImage?
    public init(title: String, image: NSImage? = nil) {
        self.title = title
        self.image = image
    }
}
