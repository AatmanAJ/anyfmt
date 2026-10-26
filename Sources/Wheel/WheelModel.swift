import AppKit
import AnyfmtCore
import UniformTypeIdentifiers

/// The three wheels: Shift → convert, Command → tools, Control → actions.
public enum WheelKind: String, CaseIterable, Codable, Sendable {
    case convert, tools, actions

    /// Tab order (Shift-Tab goes backwards).
    public var next: WheelKind {
        switch self {
        case .convert: .tools
        case .tools: .actions
        case .actions: .convert
        }
    }

    public var previous: WheelKind {
        switch self {
        case .convert: .actions
        case .tools: .convert
        case .actions: .tools
        }
    }

    /// Spoken when the wheel switches, and used as the wheel's accessibility name.
    public var title: String {
        switch self {
        case .convert: String(localized: "Convert", comment: "Name of the conversion wheel")
        case .tools: String(localized: "Tools", comment: "Name of the editing tools wheel")
        case .actions: String(localized: "Actions", comment: "Name of the file actions wheel")
        }
    }
}

/// What the host lets the user customise. Persistence belongs to Settings;
/// the wheel only reads this.
public struct WheelPreferences: Codable, Equatable, Sendable {
    /// Formats that sit first on the convert ring, in this order (12 o'clock, clockwise).
    public var favouriteFormats: [FormatID]
    /// Never offered on the convert wheel.
    public var hiddenFormats: Set<FormatID>
    /// Offered even though their capability row is `.hiddenByDefault`.
    public var shownFormats: Set<FormatID>
    /// Never offered on the tools wheel.
    public var hiddenTools: Set<ToolID>
    /// Show server-backed (Pro) segments at all. Local segments are unaffected.
    public var showCloudItems: Bool

    public init(favouriteFormats: [FormatID] = [], hiddenFormats: Set<FormatID> = [], shownFormats: Set<FormatID> = [],
                hiddenTools: Set<ToolID> = [], showCloudItems: Bool = true) {
        self.favouriteFormats = favouriteFormats
        self.hiddenFormats = hiddenFormats
        self.shownFormats = shownFormats
        self.hiddenTools = hiddenTools
        self.showCloudItems = showCloudItems
    }

    public static let standard = WheelPreferences()

    // Tolerant decoding: settings written by older builds may lack newer keys.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        favouriteFormats = try c.decodeIfPresent([FormatID].self, forKey: .favouriteFormats) ?? []
        hiddenFormats = try c.decodeIfPresent(Set<FormatID>.self, forKey: .hiddenFormats) ?? []
        shownFormats = try c.decodeIfPresent(Set<FormatID>.self, forKey: .shownFormats) ?? []
        hiddenTools = try c.decodeIfPresent(Set<ToolID>.self, forKey: .hiddenTools) ?? []
        showCloudItems = try c.decodeIfPresent(Bool.self, forKey: .showCloudItems) ?? true
    }
}

/// One segment's meaning.
public enum WheelEntry: Hashable, Sendable, Identifiable {
    case convert(RouteTarget)
    case tool(ToolSpec)
    case action(ActionSpec)

    /// Stable segment id ("convert.jpg", "tool.image.crop", "action.copy").
    public var id: String {
        switch self {
        case .convert(let t): "convert.\(t.format.rawValue)"
        case .tool(let t): "tool.\(t.id.rawValue)"
        case .action(let a): "action.\(a.id.rawValue)"
        }
    }
}

/// What the user chose, delivered to the host with the files.
public enum WheelSelection: Hashable, Sendable {
    /// `options` is nil when the user didn't open the options popover (use defaults / last used).
    case convert(RouteTarget, options: OptionValues?)
    case tool(ToolSpec)
    case action(ActionSpec)
}

/// The files a wheel is about: real URLs (Finder, Desktop, Spotlight) and/or
/// promised types (Mail, Photos, browsers) that only materialise on drop.
public struct WheelInput: Sendable, Equatable {
    public var urls: [URL]
    public var promisedTypes: [UTType]

    public init(urls: [URL] = [], promisedTypes: [UTType] = []) {
        self.urls = urls
        self.promisedTypes = promisedTypes
    }

    public var count: Int { urls.count + promisedTypes.count }
    public var isEmpty: Bool { count == 0 }

    /// Detected format per input, nil where unknown.
    public var formats: [FormatID?] {
        urls.map(Formats.detect) + promisedTypes.map(WheelInput.format(for:))
    }

    public var containsFolder: Bool {
        urls.contains { Formats.detect($0) == Formats.folder }
    }

    /// Format for a promised UTType: exact identifier first, then conformance.
    public static func format(for type: UTType) -> FormatID? {
        if let exact = Formats.all.first(where: { $0.typeIdentifiers.contains(type.identifier) }) { return exact.id }
        if let ext = type.preferredFilenameExtension, let byExt = Formats.all.first(where: { $0.extensions.contains(ext.lowercased()) }) {
            return byExt.id
        }
        for f in Formats.all {
            for t in f.typeIdentifiers {
                if let ft = UTType(t), type.conforms(to: ft) { return f.id }
            }
        }
        return nil
    }
}
