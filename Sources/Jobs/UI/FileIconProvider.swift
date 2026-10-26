import AppKit
import AnyfmtCore
import QuickLookThumbnailing

/// File icons for progress cards: the Finder icon immediately, then a Quick
/// Look thumbnail for kinds where a thumbnail says more (photos, video, PDF).
@MainActor
final class FileIconProvider {
    static let shared = FileIconProvider()

    /// Bounded so a 500-file batch can't grow idle memory (each entry ≈ 20 KB).
    private let thumbnails: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 48
        return c
    }()
    private var inFlight: Set<String> = []

    /// The Finder icon (fast, synchronous). Falls back to the kind's generic icon
    /// when the file is gone.
    func icon(for url: URL) -> NSImage {
        if let thumb = thumbnails.object(forKey: url.path as NSString) { return thumb }
        if FileManager.default.fileExists(atPath: url.path) { return NSWorkspace.shared.icon(forFile: url.path) }
        if let type = Formats.detect(url).flatMap({ Formats.format($0)?.utType }) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    /// Asks Quick Look for a thumbnail; calls `update` on the main actor if one arrives.
    func loadThumbnail(for url: URL, pointSize: CGFloat, scale: CGFloat, update: @escaping @MainActor (NSImage) -> Void) {
        let key = url.path
        if let cached = thumbnails.object(forKey: key as NSString) { update(cached); return }
        guard Self.wantsThumbnail(url), !inFlight.contains(key) else { return }
        inFlight.insert(key)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: pointSize, height: pointSize),
                                                   scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            let cg = rep?.cgImage
            Task { @MainActor in
                self.inFlight.remove(key)
                guard let cg else { return }
                let image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / scale, height: CGFloat(cg.height) / scale))
                self.thumbnails.setObject(image, forKey: key as NSString)
                update(image)
            }
        }
    }

    static func wantsThumbnail(_ url: URL) -> Bool {
        switch Formats.detect(url).map(Formats.kind) {
        case .image, .vector, .video, .pdf: true
        default: false
        }
    }
}
