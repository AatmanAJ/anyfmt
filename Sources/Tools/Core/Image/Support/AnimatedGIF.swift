import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Animated GIF frames in and out, so pixel tools (resize, crop, adjust,
/// annotate, redact, add background) and compress keep the animation.
/// ImageIO hands back each frame already composited onto the full canvas.
enum AnimatedGIF {
    struct Frame {
        var image: CGImage
        /// Seconds this frame stays on screen.
        var delay: Double
    }

    struct Animation {
        var frames: [Frame]
        /// 0 = loop forever.
        var loopCount: Int
    }

    /// The frames of a multi-frame GIF, or nil for anything else.
    static func read(_ url: URL) -> Animation? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              (CGImageSourceGetType(src) as String?) == UTType.gif.identifier else { return nil }
        let n = CGImageSourceGetCount(src)
        guard n > 1 else { return nil }
        let key = kCGImagePropertyGIFDictionary as String
        let fileGIF = (CGImageSourceCopyProperties(src, nil) as? [String: Any])?[key] as? [String: Any]
        let loop = (fileGIF?[kCGImagePropertyGIFLoopCount as String] as? NSNumber)?.intValue ?? 0
        var frames: [Frame] = []
        frames.reserveCapacity(n)
        for i in 0..<n {
            guard let image = CGImageSourceCreateImageAtIndex(src, i, nil) else { return nil }
            let gif = (CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any])?[key] as? [String: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber)?.doubleValue
                ?? (gif?[kCGImagePropertyGIFDelayTime as String] as? NSNumber)?.doubleValue ?? 0.1
            frames.append(Frame(image: image, delay: delay))
        }
        return Animation(frames: frames, loopCount: loop)
    }

    static func encode(_ animation: Animation) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.gif.identifier as CFString,
                                                          animation.frames.count, nil) else {
            throw ConversionError.engineFailed("ImageIO", status: -1, detail: "no GIF destination")
        }
        let key = kCGImagePropertyGIFDictionary as String
        CGImageDestinationSetProperties(dest, [key: [kCGImagePropertyGIFLoopCount as String: animation.loopCount]] as CFDictionary)
        for f in animation.frames {
            let timing: [String: Any] = [kCGImagePropertyGIFDelayTime as String: f.delay, kCGImagePropertyGIFUnclampedDelayTime as String: f.delay]
            CGImageDestinationAddImage(dest, f.image, [key: timing] as CFDictionary)
        }
        guard CGImageDestinationFinalize(dest) else { throw ConversionError.engineFailed("ImageIO", status: -1, detail: "GIF finalize") }
        return data as Data
    }

    static func map(_ animation: Animation, _ transform: (CGImage) throws -> CGImage) rethrows -> Animation {
        var out = animation
        for i in out.frames.indices { out.frames[i].image = try transform(out.frames[i].image) }
        return out
    }
}
