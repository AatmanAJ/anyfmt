import Foundation
import Vision

/// On-device OCR with Vision (macOS 10.15+, automatic language detection 13+).
/// Used for image → TXT and for PDF pages that have no text layer.
enum TextRecognizer {
    /// Recognised lines in reading order: top to bottom, then left to right.
    static func lines(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let observations = (request.results ?? []).sorted { a, b in
            // Same line when vertical centres are within half a line height.
            let tolerance = min(a.boundingBox.height, b.boundingBox.height) / 2
            if abs(a.boundingBox.midY - b.boundingBox.midY) > tolerance { return a.boundingBox.midY > b.boundingBox.midY }
            return a.boundingBox.minX < b.boundingBox.minX
        }
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    static func text(in image: CGImage) throws -> String { try lines(in: image).joined(separator: "\n") }

    static func noTextError(_ input: URL) -> ConversionError {
        .other(L("No text was found in “\(input.lastPathComponent)”."), detail: "no text layer and OCR found nothing")
    }
}
