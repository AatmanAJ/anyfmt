import Combine
import Foundation
import HaloCore

/// This Mac's real data for sync, one small JSON document per namespace:
///
/// - `favourites`: the favourite formats, in wheel order.
/// - `wheel-order`: which formats and tools are hidden or switched on.
/// - `settings`: per-format default options, the output name pattern and the metadata policy.
///   Folder locations and keys stay per Mac.
/// - `presets`: conversion presets (`PresetStore`), once they exist.
/// - `recipes`: no local feature yet, so nothing is synced.
///
/// A document that only holds factory values reads as nil, so a fresh Mac never
/// overwrites the server's copy with an empty one.
final class SettingsSyncSource: SyncDocumentSource, @unchecked Sendable {
    // Only touched on the main actor (every access hops there).
    private let settings: AppSettings

    @MainActor init(settings: AppSettings) { self.settings = settings }

    func localDocument(_ namespace: SyncNamespace) async -> Data? {
        await MainActor.run { Self.document(namespace, from: settings) }
    }

    func applyRemoteDocument(_ data: Data, to namespace: SyncNamespace) async throws {
        try await MainActor.run { try Self.apply(data, to: namespace, settings: settings) }
    }

    // MARK: Documents

    struct Favourites: Codable, Equatable { var formats: [String] }
    struct WheelOrder: Codable, Equatable {
        var hiddenFormats: [String]
        var shownFormats: [String]
        var hiddenTools: [String]
    }
    struct SettingsDoc: Codable, Equatable {
        var formatDefaults: [String: OptionValues]
        var namePattern: String
        var metadata: String
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    @MainActor
    static func document(_ namespace: SyncNamespace, from s: AppSettings) -> Data? {
        switch namespace {
        case .favourites:
            guard !s.favouriteFormats.isEmpty else { return nil }
            return try? encoder.encode(Favourites(formats: s.favouriteFormats.map(\.rawValue)))
        case .wheelOrder:
            let doc = WheelOrder(hiddenFormats: s.hiddenFormats.map(\.rawValue).sorted(),
                                 shownFormats: s.shownFormats.map(\.rawValue).sorted(),
                                 hiddenTools: s.hiddenTools.map(\.rawValue).sorted())
            guard doc != WheelOrder(hiddenFormats: [], shownFormats: [], hiddenTools: []) else { return nil }
            return try? encoder.encode(doc)
        case .settings:
            let doc = SettingsDoc(formatDefaults: Dictionary(uniqueKeysWithValues: s.formatDefaults.map { ($0.key.rawValue, $0.value) }),
                                  namePattern: s.namePattern, metadata: s.metadataPolicy.rawValue)
            guard doc != SettingsDoc(formatDefaults: [:], namePattern: "{name}", metadata: MetadataPolicy.keep.rawValue) else { return nil }
            return try? encoder.encode(doc)
        case .presets:
            return PresetSync.document?()
        case .recipes:
            return nil
        }
    }

    @MainActor
    static func apply(_ data: Data, to namespace: SyncNamespace, settings s: AppSettings) throws {
        let decoder = JSONDecoder()
        switch namespace {
        case .favourites:
            let doc = try decoder.decode(Favourites.self, from: data)
            s.favouriteFormats = doc.formats.map { FormatID($0) }
        case .wheelOrder:
            let doc = try decoder.decode(WheelOrder.self, from: data)
            s.hiddenFormats = Set(doc.hiddenFormats.map { FormatID($0) })
            s.shownFormats = Set(doc.shownFormats.map { FormatID($0) })
            s.hiddenTools = Set(doc.hiddenTools.map { ToolID(rawValue: $0) })
        case .settings:
            let doc = try decoder.decode(SettingsDoc.self, from: data)
            s.formatDefaults = Dictionary(uniqueKeysWithValues: doc.formatDefaults.map { (FormatID($0.key), $0.value) })
            s.namePattern = doc.namePattern
            s.metadataPolicy = MetadataPolicy(rawValue: doc.metadata) ?? s.metadataPolicy
        case .presets:
            try PresetSync.apply?(data)
        case .recipes:
            break
        }
    }

    /// Which namespace each settings change belongs to, for debounced pushes.
    @MainActor
    static func changes(of s: AppSettings) -> AnyPublisher<SyncNamespace, Never> {
        let favourites = s.$favouriteFormats.dropFirst().map { _ in SyncNamespace.favourites }
        let wheel = Publishers.Merge3(s.$hiddenFormats.dropFirst().map { _ in () },
                                      s.$shownFormats.dropFirst().map { _ in () },
                                      s.$hiddenTools.dropFirst().map { _ in () })
            .map { SyncNamespace.wheelOrder }
        let prefs = Publishers.Merge3(s.$formatDefaults.dropFirst().map { _ in () },
                                      s.$namePattern.dropFirst().map { _ in () },
                                      s.$metadataPolicy.dropFirst().map { _ in () })
            .map { SyncNamespace.settings }
        return Publishers.Merge3(favourites, wheel, prefs).eraseToAnyPublisher()
    }
}

/// Hooks the preset store (Phase B) fills in, so this file needn't know its type.
@MainActor
enum PresetSync {
    static var document: (() -> Data?)?
    static var apply: ((Data) throws -> Void)?
}
