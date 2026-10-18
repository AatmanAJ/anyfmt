import Foundation

/// Parsing and formatting of the time options media tools take.
/// Times are seconds from the start of the file, as a player shows them.
public enum MediaTimes {
    /// "12.5", "1:02.25", "1:02:03.5" → seconds.
    public static func seconds(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let parts = t.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count <= 3 else { return nil }
        var total = 0.0
        for p in parts {
            guard let v = Double(p), v >= 0, v.isFinite else { return nil }
            total = total * 60 + v
        }
        return total
    }

    /// `ToolSchemas.trim` range: "start-end". Returns nil for empty or malformed text.
    public static func range(_ text: String) -> ClosedRange<Double>? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard let dash = t.firstIndex(of: "-") else { return nil }
        guard let a = seconds(String(t[..<dash])), let b = seconds(String(t[t.index(after: dash)...])), b > a else { return nil }
        return a...b
    }

    /// Bleep ranges: "1-2.5; 4-5". Overlaps merged, sorted.
    public static func ranges(_ text: String) -> [ClosedRange<Double>] {
        let list = text.split(whereSeparator: { $0 == ";" || $0 == "\n" }).compactMap { range(String($0)) }
        return merge(list)
    }

    /// Comma-separated time list: "1.5, 3, 0:10". Sorted, deduplicated.
    public static func list(_ text: String) -> [Double] {
        let values = text.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " }).compactMap { seconds(String($0)) }
        var out: [Double] = []
        for v in values.sorted() where out.last.map({ abs($0 - v) > 0.0005 }) ?? true { out.append(v) }
        return out
    }

    public static func merge(_ ranges: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        var out: [ClosedRange<Double>] = []
        for r in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = out.last, r.lowerBound <= last.upperBound {
                out[out.count - 1] = last.lowerBound...max(last.upperBound, r.upperBound)
            } else {
                out.append(r)
            }
        }
        return out
    }

    /// Option text for a range: "1.5-9.25" (millisecond precision, trailing zeros trimmed).
    public static func format(_ r: ClosedRange<Double>) -> String { "\(format(r.lowerBound))-\(format(r.upperBound))" }

    public static func format(_ seconds: Double) -> String {
        var s = String(format: "%.3f", max(0, seconds))
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// ffmpeg argument text (microseconds, never exponent notation).
    static func arg(_ seconds: Double) -> String { String(format: "%.6f", max(0, seconds)) }

    /// Human timecode: "0:04.25", "1:02:03.50". `fraction` digits after the point.
    public static func timecode(_ seconds: Double, fraction: Int = 2) -> String {
        let s = max(0, seconds)
        let scale = pow(10, Double(fraction))
        let totalUnits = (s * scale).rounded()
        let whole = Int(totalUnits / scale)
        let frac = Int(totalUnits.truncatingRemainder(dividingBy: scale))
        let h = whole / 3600, m = (whole % 3600) / 60, sec = whole % 60
        let fracText = fraction > 0 ? "." + String(format: "%0\(fraction)d", frac) : ""
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) + fracText : String(format: "%d:%02d", m, sec) + fracText
    }
}

/// How a trim will be cut: losslessly on keyframes, or re-encoded frame-exact.
public enum TrimPlan: Sendable, Equatable {
    /// Stream copy from keyframe `start` to keyframe `end` (or the end of the file).
    case copy(start: Double, end: Double, toEnd: Bool)
    /// Frame-accurate re-encode of the requested (frame-snapped) range.
    case reencode(start: Double, end: Double, reason: Reason)

    public enum Reason: Sendable, Equatable {
        case losslessOff
        case noKeyframeNearStart
        case noKeyframeNearEnd
        case noVideoIndex
    }

    public var start: Double {
        switch self { case .copy(let s, _, _), .reencode(let s, _, _): s }
    }

    public var end: Double {
        switch self { case .copy(_, let e, _), .reencode(_, let e, _): e }
    }

    public var isLossless: Bool { if case .copy = self { return true } else { return false } }
}

public enum TrimPlanner {
    /// A lossless cut may move each cut point by at most this much. Beyond it
    /// the result would no longer be what the user marked, so we re-encode.
    public static let maxSnap: Double = 1.0

    /// Plans a video trim. Cut points are first snapped to frame boundaries.
    /// Lossless keeps the request inside the result: in snaps back to the
    /// keyframe at or before it, out forward to the keyframe at or after it.
    public static func plan(requested: ClosedRange<Double>, duration: Double, frameDuration fd: Double,
                            keyframes: KeyframeIndex?, lossless: Bool) -> TrimPlan {
        let start = snapToFrame(max(0, requested.lowerBound), fd)
        let end = min(duration, max(start + fd, snapToFrame(requested.upperBound, fd)))
        guard lossless else { return .reencode(start: start, end: end, reason: .losslessOff) }
        guard let k = keyframes, !k.keyframes.isEmpty else { return .reencode(start: start, end: end, reason: .noVideoIndex) }
        let tol = fd / 2
        guard let kIn = k.keyframe(atOrBefore: start, tolerance: tol), start - kIn <= maxSnap else {
            return .reencode(start: start, end: end, reason: .noKeyframeNearStart)
        }
        if end >= duration - tol {
            return .copy(start: kIn, end: duration, toEnd: true)
        }
        if let kOut = k.keyframe(atOrAfter: end, tolerance: tol), kOut > kIn + tol, kOut - end <= maxSnap {
            return kOut >= duration - tol ? .copy(start: kIn, end: duration, toEnd: true) : .copy(start: kIn, end: kOut, toEnd: false)
        }
        if duration - end <= maxSnap { return .copy(start: kIn, end: duration, toEnd: true) }
        return .reencode(start: start, end: end, reason: .noKeyframeNearEnd)
    }

    public static func snapToFrame(_ t: Double, _ fd: Double) -> Double {
        guard fd > 0 else { return t }
        return (t / fd).rounded() * fd
    }
}

/// Where a split cuts and whether it can be done without re-encoding.
public struct SplitPlan: Sendable, Equatable {
    /// Cut points (seconds, ascending), excluding 0 and the end.
    public let cuts: [Double]
    public let lossless: Bool

    public var segmentCount: Int { cuts.count + 1 }

    /// Requested cut points for "every N seconds" or a time list.
    public static func requestedCuts(mode: String, every: Double, at: [Double], duration: Double, minimumSegment: Double) -> [Double] {
        var cuts: [Double]
        if mode == "at" {
            cuts = at
        } else {
            guard every > 0 else { return [] }
            cuts = []
            var t = every
            while t < duration - minimumSegment { cuts.append(t); t += every }
        }
        return cuts.filter { $0 > minimumSegment && $0 < duration - minimumSegment }
    }

    /// Lossless when every cut has a keyframe close after it (the segment
    /// muxer cuts on the first keyframe at or after each time).
    public static func plan(cuts requested: [Double], duration: Double, frameDuration fd: Double,
                            keyframes: KeyframeIndex?, preferLossless: Bool) -> SplitPlan {
        let snapped = requested.map { TrimPlanner.snapToFrame($0, fd) }
        guard preferLossless, let k = keyframes, !k.keyframes.isEmpty, !snapped.isEmpty else {
            return SplitPlan(cuts: snapped, lossless: false)
        }
        var bounds = [0.0] + snapped + [duration]
        let shortest = zip(bounds.dropFirst(), bounds).map { $0 - $1 }.min() ?? duration
        let tolerance = min(TrimPlanner.maxSnap, max(fd, shortest * 0.25))
        var keyCuts: [Double] = []
        for c in snapped {
            guard let kf = k.keyframe(atOrAfter: c, tolerance: fd / 2), kf - c <= tolerance, kf < duration - fd / 2,
                  keyCuts.last.map({ kf > $0 + fd / 2 }) ?? true
            else { return SplitPlan(cuts: snapped, lossless: false) }
            keyCuts.append(kf)
        }
        bounds = keyCuts
        return SplitPlan(cuts: bounds, lossless: true)
    }
}
