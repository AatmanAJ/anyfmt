import AppKit
import AVFoundation
import ImageIO
import PDFKit
import AnyfmtCore

/// Opens an output for real and checks it's what the target format promises.
/// Validation is deliberately independent of the engine that produced it.
struct Validator {
    let locator = EngineLocator.shared

    struct Verdict {
        var ok: Bool
        var detail: String
        static func pass(_ d: String) -> Verdict { Verdict(ok: true, detail: d) }
        static func fail(_ d: String) -> Verdict { Verdict(ok: false, detail: d) }
    }

    /// - Parameters:
    ///   - outputs: what the route produced (files, folders, or packages).
    ///   - target: the target format.
    ///   - inputDuration: seconds, for time-based inputs (duration check).
    func validate(_ outputs: [URL], target: FormatID, inputDuration: Double?) async -> Verdict {
        guard !outputs.isEmpty else { return .fail("no output") }
        var details: [String] = []
        for o in outputs {
            let v = await validateOne(o, target: target, inputDuration: inputDuration)
            if !v.ok { return Verdict(ok: false, detail: "\(o.lastPathComponent): \(v.detail)") }
            details.append(v.detail)
        }
        return .pass(outputs.count == 1 ? details[0] : "\(outputs.count) files; \(details[0])")
    }

    private func validateOne(_ url: URL, target: FormatID, inputDuration: Double?) async -> Verdict {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return .fail("missing") }
        let format = Formats.format(target)
        // A multi-output route returns a folder of files; validate its contents.
        if isDir.boolValue && target != Formats.folder && format?.isPackage != true {
            let items = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            guard !items.isEmpty else { return .fail("empty folder") }
            return await validate(items.sorted { $0.path < $1.path }, target: target, inputDuration: inputDuration)
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if !isDir.boolValue && size == 0 { return .fail("zero bytes") }

        switch format?.kind ?? .other {
        case .image, .vector:
            return image(url, target: target)
        case .pdf:
            guard let doc = PDFDocument(url: url), doc.pageCount > 0 else { return .fail("PDFKit can't open it") }
            return .pass("\(doc.pageCount) page(s)")
        case .audio, .video:
            return await media(url, target: target, inputDuration: inputDuration)
        case .subtitle:
            guard let s = text(url) else { return .fail("not UTF-8 text") }
            guard s.contains("-->") else { return .fail("no cues") }
            if target == Formats.vtt && !s.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("WEBVTT") { return .fail("missing WEBVTT header") }
            return .pass("\(s.components(separatedBy: "-->").count - 1) cues")
        case .archive:
            return await archive(url)
        case .folder:
            let items = (try? FileManager.default.subpathsOfDirectory(atPath: url.path)) ?? []
            return items.isEmpty ? .fail("empty folder") : .pass("\(items.count) item(s)")
        case .document, .ebook, .slides, .spreadsheet:
            return await document(url, target: target)
        case .other:
            return size > 0 ? .pass("\(size) bytes") : .fail("empty")
        }
    }

    private func image(_ url: URL, target: FormatID) -> Verdict {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return .fail("ImageIO can't open it") }
        let count = CGImageSourceGetCount(src)
        guard count > 0, let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else { return .fail("no decodable image") }
        guard CGImageSourceCreateImageAtIndex(src, 0, nil) != nil else { return .fail("decode failed") }
        return .pass("\(w)×\(h)\(count > 1 ? ", \(count) frames" : "")")
    }

    private func media(_ url: URL, target: FormatID, inputDuration: Double?) async -> Verdict {
        guard let probe = try? await FFmpeg(locator: locator).probe(url) else { return .fail("ffprobe can't read it") }
        let kind = Formats.kind(target)
        if kind == .video && !probe.hasVideo { return .fail("no video stream") }
        if kind == .audio && !probe.hasAudio { return .fail("no audio stream") }
        if let d = probe.duration, let expected = inputDuration, expected > 0 {
            let tolerance = max(0.35, expected * 0.08)
            if abs(d - expected) > tolerance { return .fail(String(format: "duration %.2fs, expected %.2fs", d, expected)) }
        } else if probe.duration == nil || (probe.duration ?? 0) <= 0 {
            return .fail("no duration")
        }
        let codecs = probe.streams.compactMap(\.codec_name).joined(separator: "+")
        return .pass(String(format: "%.2fs %@", probe.duration ?? 0, codecs))
    }

    private func archive(_ url: URL) async -> Verdict {
        do {
            let r = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/bsdtar"), ["-tf", url.path])
            let entries = r.stdoutString.split(separator: "\n").count
            return entries > 0 ? .pass("\(entries) entr\(entries == 1 ? "y" : "ies")") : .fail("empty archive")
        } catch {
            return .fail("bsdtar can't list it")
        }
    }

    private func document(_ url: URL, target: FormatID) async -> Verdict {
        switch target {
        case Formats.txt, Formats.md, Formats.csv, Formats.tsv:
            guard let s = text(url), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .fail("empty or not UTF-8") }
            if target == Formats.csv || target == Formats.tsv {
                let sep: Character = target == Formats.csv ? "," : "\t"
                let rows = s.split(whereSeparator: \.isNewline)
                guard let first = rows.first, first.contains(sep) || rows.count > 1 else { return .fail("no table structure") }
                return .pass("\(rows.count) rows")
            }
            return .pass("\(s.count) chars")
        case Formats.json:
            guard let d = try? Data(contentsOf: url), (try? JSONSerialization.jsonObject(with: d)) != nil else { return .fail("invalid JSON") }
            return .pass("valid JSON")
        case Formats.html:
            guard let d = try? Data(contentsOf: url), let doc = try? XMLDocument(data: d, options: [.documentTidyHTML]),
                  let body = try? doc.nodes(forXPath: "//body").first, !(body.stringValue ?? "").isEmpty else { return .fail("no HTML body text") }
            return .pass("\((body.stringValue ?? "").count) chars")
        case Formats.docx, Formats.pptx, Formats.xlsx, Formats.odt, Formats.ods, Formats.odp, Formats.epub:
            return await zipPackage(url, target: target)
        case Formats.rtf, Formats.rtfd, Formats.doc, Formats.webarchive:
            return attributed(url)
        case Formats.pages, Formats.key, Formats.numbers:
            return FileManager.default.fileExists(atPath: url.path) ? .pass("package") : .fail("missing")
        default:
            return .pass("exists")
        }
    }

    private func zipPackage(_ url: URL, target: FormatID) async -> Verdict {
        guard let r = try? await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/unzip"), ["-Z1", url.path]) else {
            return .fail("not a valid zip")
        }
        let names = Set(r.stdoutString.split(separator: "\n").map(String.init))
        let required: [String] = switch target {
        case Formats.docx: ["[Content_Types].xml", "word/document.xml"]
        case Formats.pptx: ["[Content_Types].xml", "ppt/presentation.xml"]
        case Formats.xlsx: ["[Content_Types].xml", "xl/workbook.xml"]
        case Formats.odt, Formats.ods, Formats.odp: ["mimetype", "content.xml"]
        case Formats.epub: ["mimetype", "META-INF/container.xml"]
        default: []
        }
        for n in required where !names.contains(n) { return .fail("missing \(n)") }
        if target == Formats.docx || target == Formats.odt {
            let v = attributed(url)
            if !v.ok { return v }
        }
        return .pass("\(names.count) parts")
    }

    private func attributed(_ url: URL) -> Verdict {
        do {
            let s = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
            return s.length > 0 ? .pass("\(s.length) chars") : .fail("no text")
        } catch {
            return .fail("AppKit can't open it: \(error.localizedDescription)")
        }
    }

    private func text(_ url: URL) -> String? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return String(data: d, encoding: .utf8)
    }
}
