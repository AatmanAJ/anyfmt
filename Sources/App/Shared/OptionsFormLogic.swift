import Foundation
import HaloCore

/// The pure rules behind `OptionsForm`: visibility, value coercion and the
/// parsing/validation of text-encoded kinds. Kept free of SwiftUI so it is
/// unit-tested directly.
enum OptionsFormLogic {
    // MARK: Values

    /// The value a control shows: the stored value coerced to the spec's kind,
    /// or the spec default when missing or unusable.
    static func effectiveValue(_ spec: OptionSpec, in values: OptionValues) -> OptionValue {
        coerce(values[spec.id], to: spec.kind, default: spec.defaultValue)
    }

    /// Normalises any stored value into the canonical representation for `kind`:
    /// numbers are `.int` (clamped, snapped to the step), decimals `.double`,
    /// toggles `.bool`, choices a valid choice id, text kinds `.string`.
    static func coerce(_ value: OptionValue?, to kind: OptionKind, default fallback: OptionValue) -> OptionValue {
        guard let value else { return canonicalDefault(fallback, kind) }
        switch kind {
        case .slider(let lo, let hi, let step, _):
            guard let n = number(value) else { return canonicalDefault(fallback, kind) }
            return .int(snap(Int(n.rounded()), min: lo, max: hi, step: step))
        case .integer(let lo, let hi, _):
            guard let n = number(value) else { return canonicalDefault(fallback, kind) }
            return .int(clamp(Int(n.rounded()), lo, hi))
        case .fileSize:
            guard let n = number(value) else { return canonicalDefault(fallback, kind) }
            return .int(max(0, Int(n.rounded())))
        case .decimal(let lo, let hi, let step):
            guard let n = number(value) else { return canonicalDefault(fallback, kind) }
            return .double(snap(n, min: lo, max: hi, step: step))
        case .toggle:
            guard let b = bool(value) else { return canonicalDefault(fallback, kind) }
            return .bool(b)
        case .choice(let choices):
            let id = value.description
            if choices.contains(where: { $0.id == id }) { return .string(id) }
            // Numeric ids written as numbers ("300" vs 300.0).
            if let n = number(value), let match = choices.first(where: { Double($0.id) == n }) { return .string(match.id) }
            return canonicalDefault(fallback, kind)
        case .text, .pageRange, .timeRange, .color, .rect:
            return .string(value.description)
        }
    }

    private static func canonicalDefault(_ fallback: OptionValue, _ kind: OptionKind) -> OptionValue {
        switch kind {
        case .slider, .integer, .fileSize: return .int(Int((number(fallback) ?? 0).rounded()))
        case .decimal: return .double(number(fallback) ?? 0)
        case .toggle: return .bool(bool(fallback) ?? false)
        case .choice(let choices):
            let id = fallback.description
            return .string(choices.contains { $0.id == id } ? id : (choices.first?.id ?? id))
        case .text, .pageRange, .timeRange, .color, .rect: return .string(fallback.description)
        }
    }

    static func number(_ v: OptionValue) -> Double? {
        switch v {
        case .int(let i): Double(i)
        case .double(let d): d.isFinite ? d : nil
        case .string(let s): Double(s.trimmingCharacters(in: .whitespaces))
        case .bool(let b): b ? 1 : 0
        }
    }

    static func bool(_ v: OptionValue) -> Bool? {
        switch v {
        case .bool(let b): b
        case .int(let i): i != 0
        case .double(let d): d != 0
        case .string(let s):
            ["1", "true", "yes", "on"].contains(s.lowercased()) ? true
                : ["0", "false", "no", "off"].contains(s.lowercased()) ? false : nil
        }
    }

    /// Loose equality used by `visibleWhen`: 3 == 3.0 == "3", true == "true".
    static func matches(_ a: OptionValue, _ b: OptionValue) -> Bool {
        if a == b { return true }
        switch (a, b) {
        case (.bool, _), (_, .bool):
            guard let x = bool(a), let y = bool(b) else { return false }
            return x == y
        default:
            if let x = number(a), let y = number(b) { return abs(x - y) < 1e-9 }
            return a.description == b.description
        }
    }

    static func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(max(v, lo), hi) }

    static func snap(_ v: Int, min lo: Int, max hi: Int, step: Int) -> Int {
        let s = Swift.max(1, step)
        let snapped = lo + Int((Double(v - lo) / Double(s)).rounded()) * s
        return clamp(snapped, lo, hi)
    }

    static func snap(_ v: Double, min lo: Double, max hi: Double, step: Double) -> Double {
        guard step > 0 else { return clamp(v, lo, hi) }
        let snapped = lo + ((v - lo) / step).rounded() * step
        // Trim float noise (0.30000000000000004 → 0.3).
        let digits = decimals(for: step)
        let p = pow(10, Double(digits))
        return clamp((snapped * p).rounded() / p, lo, hi)
    }

    /// Fraction digits a step needs: 1 → 0, 0.5 → 1, 0.05 → 2.
    static func decimals(for step: Double) -> Int {
        var d = 0
        var s = abs(step)
        while d < 6, abs(s - s.rounded()) > 1e-9 { s *= 10; d += 1 }
        return d
    }

    // MARK: Visibility

    /// A spec is visible when every `visibleWhen` condition matches the
    /// controlling option's effective value, and the controlling option is
    /// itself visible (so a chain of conditions collapses together).
    static func isVisible(_ spec: OptionSpec, in values: OptionValues, schema: OptionsSchema) -> Bool {
        isVisible(spec, values, schema, depth: 0)
    }

    private static func isVisible(_ spec: OptionSpec, _ values: OptionValues, _ schema: OptionsSchema, depth: Int) -> Bool {
        guard depth < 8 else { return true } // cycle guard; schemas are shallow
        for (key, expected) in spec.visibleWhen {
            if let controller = schema.spec(key) {
                guard isVisible(controller, values, schema, depth: depth + 1) else { return false }
                guard matches(effectiveValue(controller, in: values), expected) else { return false }
            } else {
                guard let actual = values[key], matches(actual, expected) else { return false }
            }
        }
        return true
    }

    static func visibleSpecs(_ schema: OptionsSchema, _ values: OptionValues) -> [OptionSpec] {
        schema.specs.filter { isVisible($0, in: values, schema: schema) }
    }

    /// Values that differ from the schema defaults (what Settings stores).
    static func nonDefault(_ values: OptionValues, schema: OptionsSchema) -> OptionValues {
        var out = OptionValues()
        for spec in schema.specs {
            guard let v = values[spec.id] else { continue }
            let c = coerce(v, to: spec.kind, default: spec.defaultValue)
            if !matches(c, coerce(nil, to: spec.kind, default: spec.defaultValue)) { out[spec.id] = c }
        }
        // Keys the schema doesn't know (another engine's option) are kept as-is.
        for (k, v) in values.values where schema.spec(k) == nil { out[k] = v }
        return out
    }

    // MARK: Choice presentation

    enum ChoiceStyle: Equatable { case segmented, menu }

    /// Segmented for up to four short choices, otherwise a pop-up menu.
    static func choiceStyle(_ choices: [OptionChoice]) -> ChoiceStyle {
        choices.count <= 4 && choices.allSatisfy { $0.label.count <= 12 } ? .segmented : .menu
    }

    // MARK: File size

    enum SizeUnit: String, CaseIterable, Identifiable {
        case kb = "KB", mb = "MB", gb = "GB"
        var id: String { rawValue }
        /// Decimal units, like Finder.
        var bytes: Double {
            switch self {
            case .kb: 1_000
            case .mb: 1_000_000
            case .gb: 1_000_000_000
            }
        }
    }

    /// The most natural unit for a byte count: 1 500 000 → (1.5, MB).
    static func split(bytes: Int) -> (value: Double, unit: SizeUnit) {
        let b = Double(max(0, bytes))
        let unit: SizeUnit = b >= SizeUnit.gb.bytes ? .gb : b >= SizeUnit.mb.bytes ? .mb : .kb
        return ((b / unit.bytes * 100).rounded() / 100, unit)
    }

    static func bytes(_ value: Double, _ unit: SizeUnit) -> Int {
        Int((max(0, value) * unit.bytes).rounded())
    }

    // MARK: Colour "#RRGGBB" / "#RRGGBBAA"

    struct RGBA: Equatable {
        var r: Double, g: Double, b: Double, a: Double
    }

    static func parseHex(_ text: String) -> RGBA? {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() } // #abc shorthand
        guard s.count == 6 || s.count == 8, let n = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            return RGBA(r: Double((n >> 16) & 0xFF) / 255, g: Double((n >> 8) & 0xFF) / 255, b: Double(n & 0xFF) / 255, a: 1)
        }
        return RGBA(r: Double((n >> 24) & 0xFF) / 255, g: Double((n >> 16) & 0xFF) / 255,
                    b: Double((n >> 8) & 0xFF) / 255, a: Double(n & 0xFF) / 255)
    }

    /// Alpha is written only when it isn't opaque.
    static func hex(_ c: RGBA) -> String {
        func byte(_ x: Double) -> Int { Int((clamp(x, 0, 1) * 255).rounded()) }
        let rgb = String(format: "#%02X%02X%02X", byte(c.r), byte(c.g), byte(c.b))
        return byte(c.a) == 255 ? rgb : rgb + String(format: "%02X", byte(c.a))
    }

    // MARK: Rect "x,y,w,h" (normalised, top-left origin)

    static func parseRect(_ text: String) -> [Double]? {
        let parts = text.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 4, parts.allSatisfy({ $0 != nil }) else { return nil }
        return parts.compactMap { $0 }
    }

    static func formatRect(_ r: [Double]) -> String {
        r.map { formatNumber($0, maxFractionDigits: 4) }.joined(separator: ",")
    }

    static func validateRect(_ text: String) -> String? {
        guard let r = parseRect(text) else { return String(localized: "Use four numbers: x, y, width, height") }
        guard r.allSatisfy({ (0...1).contains($0) }) else { return String(localized: "Each value is a fraction from 0 to 1") }
        guard r[2] > 0, r[3] > 0 else { return String(localized: "Width and height must be more than 0") }
        guard r[0] + r[2] <= 1.0001, r[1] + r[3] <= 1.0001 else { return String(localized: "The area goes past the edge") }
        return nil
    }

    // MARK: Ranges

    /// nil when valid. "" means all pages. "1-3,5" style lists, 1-based.
    static func validatePageRange(_ text: String) -> String? {
        let s = text.replacingOccurrences(of: " ", with: "")
        guard !s.isEmpty else { return nil }
        let bad = String(localized: "Use page numbers and ranges, like 1-3, 5")
        for part in s.split(separator: ",", omittingEmptySubsequences: false) {
            let ends = part.split(separator: "-", omittingEmptySubsequences: false)
            guard (1...2).contains(ends.count) else { return bad }
            let nums = ends.map { Int($0) }
            guard nums.allSatisfy({ ($0 ?? 0) >= 1 }) else { return bad }
            if nums.count == 2, let a = nums[0], let b = nums[1], a > b {
                return String(localized: "\(a)-\(b) runs backwards")
            }
        }
        return nil
    }

    /// nil when valid. "start-end" in seconds ("1.5-9.25"); "" means the whole file.
    static func validateTimeRange(_ text: String) -> String? {
        let s = text.replacingOccurrences(of: " ", with: "")
        guard !s.isEmpty else { return nil }
        let ends = s.split(separator: "-", omittingEmptySubsequences: false)
        guard ends.count == 2, let a = Double(ends[0]), let b = Double(ends[1]), a >= 0 else {
            return String(localized: "Use start-end in seconds, like 1.5-9.25")
        }
        guard b > a else { return String(localized: "The end must come after the start") }
        return nil
    }

    static func validateHex(_ text: String) -> String? {
        parseHex(text) == nil ? String(localized: "Use #RRGGBB or #RRGGBBAA") : nil
    }

    // MARK: Formatting

    static func formatNumber(_ v: Double, maxFractionDigits: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFractionDigits
        f.minimumIntegerDigits = 1
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }

    /// "85 %", "0.35 s", "16 px", "6".
    static func display(_ value: Double, decimals: Int, unit: String?) -> String {
        let n = value.formatted(.number.precision(.fractionLength(decimals)))
        guard let unit, !unit.isEmpty else { return n }
        return unit == "%" ? "\(n)%" : "\(n) \(unit)"
    }
}
