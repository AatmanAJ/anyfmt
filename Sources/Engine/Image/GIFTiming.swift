import Foundation

/// Rewrites frame delays and the loop count of a GIF89a file in place.
///
/// ffmpeg's GIF muxer is fed one frame per centisecond (`-framerate 100`) so that
/// every source frame becomes exactly one GIF frame; we then put the source's real
/// delays into each Graphic Control Extension. Walks the block structure (header,
/// colour tables, extensions, image descriptors) rather than pattern-matching, so
/// LZW data can never be mistaken for a control block.
enum GIFTiming {
    /// Number of image frames, or nil if the data isn't a well-formed GIF.
    static func frameCount(_ data: Data) -> Int? { walk([UInt8](data)).map { $0.frames } }

    /// Delays in centiseconds per frame (from each frame's GCE; 0 when absent).
    static func delays(_ data: Data) -> [Int]? {
        let b = [UInt8](data)
        return walk(b)?.gce.map { Int(b[$0 + 4]) | Int(b[$0 + 5]) << 8 }
    }

    /// Applies `delays` (seconds) frame by frame and sets the NETSCAPE loop count.
    /// Returns nil when the frame count doesn't match (caller keeps ffmpeg's timing).
    static func apply(_ data: Data, delays: [Double], loopCount: Int) -> Data? {
        var b = [UInt8](data)
        guard let layout = walk(b), layout.gce.count == layout.frames, layout.frames == delays.count else { return nil }
        for (frame, at) in layout.gce.enumerated() {
            let cs = UInt16(min(65535, max(2, Int((delays[frame] * 100).rounded()))))
            b[at + 4] = UInt8(cs & 0xFF)
            b[at + 5] = UInt8(cs >> 8)
        }
        if let loop = layout.loop {
            let n = UInt16(min(65535, max(0, loopCount)))
            b[loop] = UInt8(n & 0xFF)
            b[loop + 1] = UInt8(n >> 8)
        }
        return Data(b)
    }

    /// Offsets of every GCE introducer (0x21 0xF9) in frame order, the NETSCAPE loop
    /// count bytes, and the number of image descriptors.
    private static func walk(_ b: [UInt8]) -> (gce: [Int], loop: Int?, frames: Int)? {
        guard b.count >= 13, b[0] == 0x47, b[1] == 0x49, b[2] == 0x46 else { return nil } // "GIF"
        var i = 13
        if b[10] & 0x80 != 0 { i += 3 * (1 << (Int(b[10] & 0x07) + 1)) }
        var gce: [Int] = []
        var loop: Int?
        var frames = 0
        func skipSubBlocks(_ j: inout Int) -> Bool {
            while j < b.count {
                let n = Int(b[j]); j += 1
                if n == 0 { return true }
                j += n
            }
            return false
        }
        while i < b.count {
            switch b[i] {
            case 0x21: // extension
                guard i + 2 < b.count else { return nil }
                let label = b[i + 1]
                if label == 0xF9, i + 7 < b.count { gce.append(i) }
                if label == 0xFF, i + 18 < b.count, b[i + 2] == 11,
                   String(decoding: b[(i + 3)..<(i + 14)], as: UTF8.self) == "NETSCAPE2.0", b[i + 14] >= 3, b[i + 15] == 1 {
                    loop = i + 16
                }
                var j = i + 2
                guard skipSubBlocks(&j) else { return nil }
                i = j
            case 0x2C: // image descriptor
                guard i + 10 <= b.count else { return nil }
                frames += 1
                var j = i + 10
                if b[i + 9] & 0x80 != 0 { j += 3 * (1 << (Int(b[i + 9] & 0x07) + 1)) }
                j += 1 // LZW minimum code size
                guard j <= b.count, skipSubBlocks(&j) else { return nil }
                i = j
            case 0x3B: // trailer
                return (gce, loop, frames)
            default:
                return nil
            }
        }
        return nil
    }
}
