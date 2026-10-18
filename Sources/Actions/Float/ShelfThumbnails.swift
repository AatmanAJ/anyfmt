import AppKit
import QuickLookThumbnailing

/// An image for a shelf item. `isIcon` means a Finder icon (drawn as-is with
/// a soft shadow); otherwise it's a content thumbnail (drawn as a bordered
/// "print" on the pile).
struct ShelfThumbnail {
    let image: NSImage
    let isIcon: Bool
}

@MainActor
protocol ShelfThumbnailProviding: AnyObject {
    /// Returns something to show right away (usually the Finder icon) and calls
    /// `update` later if a better image arrives. `side` is in points.
    func thumbnail(for url: URL, side: CGFloat, scale: CGFloat, update: @escaping @MainActor (ShelfThumbnail) -> Void) -> ShelfThumbnail
}

/// QuickLook thumbnails, with the Finder icon until (or instead of) one arrives.
/// Generated out of process; no window or activation needed. Cached in memory
/// for the session only.
@MainActor
final class QuickLookThumbnails: ShelfThumbnailProviding {
    static let shared = QuickLookThumbnails()

    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [String: [@MainActor (ShelfThumbnail) -> Void]] = [:]

    func thumbnail(for url: URL, side: CGFloat, scale: CGFloat, update: @escaping @MainActor (ShelfThumbnail) -> Void) -> ShelfThumbnail {
        let key = "\(url.path)#\(Int(side * scale))"
        if let cached = cache.object(forKey: key as NSString) {
            return ShelfThumbnail(image: cached, isIcon: false)
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: side, height: side)

        if inFlight[key] != nil {
            inFlight[key]?.append(update)
        } else {
            inFlight[key] = [update]
            let request = QLThumbnailGenerator.Request(
                fileAt: url, size: CGSize(width: side, height: side), scale: scale,
                representationTypes: .thumbnail)
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
                let image = representation.map { SendableImage($0.cgImage) }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.finish(key: key, image: image?.cgImage, side: side)
                    }
                }
            }
        }
        return ShelfThumbnail(image: icon, isIcon: true)
    }

    private func finish(key: String, image: CGImage?, side: CGFloat) {
        let waiters = inFlight.removeValue(forKey: key) ?? []
        guard let image else { return }
        let size = Self.fit(CGSize(width: image.width, height: image.height), in: side)
        let ns = NSImage(cgImage: image, size: size)
        cache.setObject(ns, forKey: key as NSString)
        for waiter in waiters { waiter(ShelfThumbnail(image: ns, isIcon: false)) }
    }

    /// Aspect-fit `size` into a `side`×`side` box.
    static func fit(_ size: CGSize, in side: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: side, height: side) }
        let s = min(side / size.width, side / size.height)
        return CGSize(width: (size.width * s).rounded(), height: (size.height * s).rounded())
    }
}

/// CGImage crossing from QuickLook's callback queue to the main actor. The
/// image is immutable once created.
private struct SendableImage: @unchecked Sendable {
    let cgImage: CGImage
    init(_ cgImage: CGImage) { self.cgImage = cgImage }
}
