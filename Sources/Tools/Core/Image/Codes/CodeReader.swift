import Foundation
import CoreGraphics
import Vision

/// One decoded QR code or barcode.
public struct CodeReadResult: Sendable, Hashable, Codable, Identifiable {
    /// Decoded text.
    public let payload: String
    /// Vision symbology without its prefix: "QR", "EAN13", "Code128" …
    public let symbology: String

    public init(payload: String, symbology: String) {
        self.payload = payload
        self.symbology = symbology
    }

    public var id: String { symbology + "\u{1F}" + payload }

    /// Human name: "QR code", "EAN-13" …
    public var label: String { CodeReader.label(for: symbology) }

    /// A web, mail or phone link in the payload, if it is exactly one.
    /// Links are never opened automatically; the UI asks first.
    public var link: URL? {
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), ["http", "https", "mailto", "tel", "sms", "facetime"].contains(scheme) else { return nil }
        if scheme.hasPrefix("http"), url.host?.isEmpty ?? true { return nil }
        return url
    }
}

/// Reads every symbology Vision supports (QR, Aztec, PDF417, Data Matrix,
/// EAN/UPC, Code 39/93/128, ITF, Codabar, GS1 DataBar, Micro QR …).
public enum CodeReader {
    public static func read(_ image: CGImage) throws -> [CodeReadResult] {
        let request = VNDetectBarcodesRequest()
        if let all = try? request.supportedSymbologies() { request.symbologies = all }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch {
            throw ConversionError.other(L("\(Brand.name) couldn’t scan this image for codes."), detail: "Vision barcodes: \(error)")
        }
        // Reading order: top to bottom, then left to right (Vision boxes are y-up).
        let observations = (request.results ?? []).sorted {
            let a = $0.boundingBox, b = $1.boundingBox
            if abs(a.midY - b.midY) > 0.05 { return a.midY > b.midY }
            return a.midX < b.midX
        }
        var seen = Set<String>()
        var out: [CodeReadResult] = []
        for o in observations {
            guard let payload = o.payloadStringValue, !payload.isEmpty else { continue }
            let r = CodeReadResult(payload: payload, symbology: shortName(o.symbology.rawValue))
            if seen.insert(r.id).inserted { out.append(r) }
        }
        return out
    }

    static func shortName(_ raw: String) -> String {
        raw.hasPrefix("VNBarcodeSymbology") ? String(raw.dropFirst("VNBarcodeSymbology".count)) : raw
    }

    private static let labels: [String: String] = [
        "QR": "QR code", "MicroQR": "Micro QR code", "Aztec": "Aztec code", "DataMatrix": "Data Matrix",
        "PDF417": "PDF417", "MicroPDF417": "MicroPDF417", "EAN13": "EAN-13", "EAN8": "EAN-8", "UPCE": "UPC-E",
        "Code39": "Code 39", "Code39Checksum": "Code 39", "Code39FullASCII": "Code 39", "Code39FullASCIIChecksum": "Code 39",
        "Code93": "Code 93", "Code93i": "Code 93", "Code128": "Code 128", "I2of5": "Interleaved 2 of 5",
        "I2of5Checksum": "Interleaved 2 of 5", "ITF14": "ITF-14", "Codabar": "Codabar", "GS1DataBar": "GS1 DataBar",
        "GS1DataBarExpanded": "GS1 DataBar Expanded", "GS1DataBarLimited": "GS1 DataBar Limited", "MSIPlessey": "MSI Plessey",
    ]

    public static func label(for symbology: String) -> String { labels[symbology] ?? symbology }

    // MARK: Text file

    /// The `.txt` the tool writes: a header line per code ("[QR code · QR]"),
    /// the payload verbatim (lines starting with "[" or "\" escaped with "\"),
    /// and a blank separator line after every block. `parse` reads it back exactly.
    public static func text(for results: [CodeReadResult]) -> String {
        results.map { r in
            let body = r.payload.components(separatedBy: "\n").map { line in
                line.hasPrefix("[") || line.hasPrefix("\\") ? "\\" + line : line
            }.joined(separator: "\n")
            return "[\(r.label) · \(r.symbology)]\n\(body)\n\n"
        }.joined()
    }

    public static func parse(_ text: String) -> [CodeReadResult] {
        var results: [CodeReadResult] = []
        var symbology: String?
        var lines: [String] = []
        func flush() {
            guard let s = symbology else { return }
            if lines.last == "" { lines.removeLast() } // the separator
            results.append(CodeReadResult(payload: lines.joined(separator: "\n"), symbology: s))
            lines = []
        }
        var all = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if all.last == "" { all.removeLast() } // trailing newline of the last block
        for line in all {
            if line.hasPrefix("["), line.hasSuffix("]") {
                flush()
                let inner = line.dropFirst().dropLast()
                if let dot = inner.range(of: " · ", options: .backwards) {
                    symbology = String(inner[dot.upperBound...])
                } else {
                    symbology = String(inner)
                }
            } else if symbology != nil {
                lines.append(line.hasPrefix("\\") ? String(line.dropFirst()) : line)
            }
        }
        flush()
        return results
    }

    public static func parse(fileAt url: URL) -> [CodeReadResult] {
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(s)
    }
}

/// Tool 11: Read QR / barcodes → `<name>-codes.txt`. The app presents the
/// parsed results (`CodeReader.parse(fileAt:)`) with copy buttons.
struct ReadCodesRunner: ToolRunner {
    let id = ToolIDs.readCodes

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        guard let input = request.inputs.first else { throw ConversionError.invalidOption("inputs") }
        let decoded = try ToolImageSupport.decode(input)
        context.progress(0.3)
        var results = try CodeReader.read(decoded.image)
        if results.isEmpty, max(decoded.width, decoded.height) < 1200 {
            // Small codes read better enlarged.
            let up = try ToolImageSupport.resample(decoded.image, width: decoded.width * 2, height: decoded.height * 2)
            results = try CodeReader.read(up)
        }
        guard !results.isEmpty else {
            throw ConversionError.other(L("No QR code or barcode was found in “\(input.lastPathComponent)”."), detail: "no barcode observations")
        }
        let url = try ToolOutput(request: request).write(Data(CodeReader.text(for: results).utf8), ext: "txt")
        context.progress(1)
        return ConversionOutput(url)
    }
}
