import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Image metadata through ImageIO's EXIF / TIFF / IPTC / GPS dictionaries.
///
/// Writing never re-encodes pixels where the container allows otherwise:
/// - JPEG: the EXIF/IPTC (and XMP, when the file had one) segments are
///   regenerated and spliced around the untouched scan data;
/// - PNG: metadata chunks are replaced, IDAT is untouched;
/// - WebP: EXIF and XMP chunks are replaced, the VP8/VP8L data is untouched;
/// - HEIC/HEIF/AVIF/TIFF/JP2/PSD: ImageIO can't rewrite their metadata
///   losslessly (research §C), so the image is re-encoded (lossless for
///   TIFF/PSD, quality 0.92 for the lossy ones).
enum ImageMetadataIO {
    private static let exif = kCGImagePropertyExifDictionary as String
    private static let tiff = kCGImagePropertyTIFFDictionary as String
    private static let iptc = kCGImagePropertyIPTCDictionary as String
    private static let gps = kCGImagePropertyGPSDictionary as String
    private static let exifAux = kCGImagePropertyExifAuxDictionary as String

    static let editableKeys = ["title", "description", "artist", "copyright", "keywords", "dateTaken", "gpsLatitude", "gpsLongitude"]

    // MARK: Read

    static func read(_ url: URL) throws -> MetadataSnapshot {
        guard let props = ToolImageSupport.properties(of: url) else { throw ConversionError.unreadable(url, detail: "no image properties") }
        let format = Formats.detect(url)
        var fields: [MetadataField] = []
        func add(_ key: String, _ label: String, _ group: String, _ value: String?, editable: Bool = false, placeholder: String? = nil) {
            if editable || !(value ?? "").isEmpty {
                fields.append(MetadataField(key: key, label: label, group: group, value: value ?? "", editable: editable, placeholder: placeholder))
            }
        }
        let canEdit = canWrite(format)
        let t = dict(props, tiff), e = dict(props, exif), i = dict(props, iptc), g = dict(props, gps), aux = dict(props, exifAux)

        add("title", L("Title"), "IPTC", string(i[kCGImagePropertyIPTCObjectName as String]), editable: canEdit)
        add("keywords", L("Keywords"), "IPTC", list(i[kCGImagePropertyIPTCKeywords as String]), editable: canEdit, placeholder: L("Comma-separated"))
        add("description", L("Description"), "TIFF",
            string(t[kCGImagePropertyTIFFImageDescription as String]) ?? string(i[kCGImagePropertyIPTCCaptionAbstract as String]), editable: canEdit)
        add("artist", L("Artist"), "TIFF",
            string(t[kCGImagePropertyTIFFArtist as String]) ?? list(i[kCGImagePropertyIPTCByline as String]), editable: canEdit)
        add("copyright", L("Copyright"), "TIFF",
            string(t[kCGImagePropertyTIFFCopyright as String]) ?? string(i[kCGImagePropertyIPTCCopyrightNotice as String]), editable: canEdit)
        add("dateTaken", L("Date taken"), "EXIF", string(e[kCGImagePropertyExifDateTimeOriginal as String]).map(displayDate),
            editable: canEdit, placeholder: L("e.g. 2026-10-18 14:30:00"))
        add("gpsLatitude", L("Latitude"), "GPS", coordinate(g, kCGImagePropertyGPSLatitude, kCGImagePropertyGPSLatitudeRef, negative: "S"),
            editable: canEdit, placeholder: L("e.g. 48.858370"))
        add("gpsLongitude", L("Longitude"), "GPS", coordinate(g, kCGImagePropertyGPSLongitude, kCGImagePropertyGPSLongitudeRef, negative: "W"),
            editable: canEdit, placeholder: L("e.g. 2.294481"))
        if let alt = (g[kCGImagePropertyGPSAltitude as String] as? NSNumber)?.doubleValue {
            let below = (g[kCGImagePropertyGPSAltitudeRef as String] as? NSNumber)?.intValue == 1
            add("gps.altitude", L("Altitude"), "GPS", String(format: "%.0f m", below ? -alt : alt))
        }

        let camera = [string(t[kCGImagePropertyTIFFMake as String]), string(t[kCGImagePropertyTIFFModel as String])]
            .compactMap { $0 }.joined(separator: " ")
        add("tiff.camera", L("Camera"), L("Camera"), camera)
        add("exif.lens", L("Lens"), L("Camera"), string(e[kCGImagePropertyExifLensModel as String]) ?? string(aux[kCGImagePropertyExifAuxLensModel as String]))
        if let et = (e[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue, et > 0 {
            add("exif.exposure", L("Exposure"), L("Camera"), et < 1 ? "1/\(Int((1 / et).rounded())) s" : String(format: "%.1f s", et))
        }
        if let f = (e[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue {
            add("exif.aperture", L("Aperture"), L("Camera"), String(format: "ƒ/%.1f", f))
        }
        if let iso = (e[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first {
            add("exif.iso", L("ISO"), L("Camera"), "ISO \(iso.intValue)")
        }
        if let fl = (e[kCGImagePropertyExifFocalLength as String] as? NSNumber)?.doubleValue {
            var s = String(format: "%.0f mm", fl)
            if let eq = (e[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? NSNumber)?.intValue, eq > 0 { s += " (\(eq) mm equiv.)" }
            add("exif.focalLength", L("Focal length"), L("Camera"), s)
        }
        add("tiff.software", L("Software"), L("Camera"), string(t[kCGImagePropertyTIFFSoftware as String]))

        let w = (props[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue ?? 0
        let h = (props[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue ?? 0
        let o = ToolImageSupport.orientation(of: props)
        add("image.size", L("Dimensions"), L("Image"), ToolImageSupport.swapsAxes(o) ? "\(h) × \(w)" : "\(w) × \(h)")
        add("image.profile", L("Colour profile"), L("Image"), string(props[kCGImagePropertyProfileName as String]))
        add("image.model", L("Colour model"), L("Image"), string(props[kCGImagePropertyColorModel as String]))
        if let depth = (props[kCGImagePropertyDepth as String] as? NSNumber)?.intValue { add("image.depth", L("Bit depth"), L("Image"), "\(depth)-bit") }
        if let a = props[kCGImagePropertyHasAlpha as String] as? Bool { add("image.alpha", L("Transparency"), L("Image"), a ? L("Yes") : L("No")) }
        if let dpi = (props[kCGImagePropertyDPIWidth as String] as? NSNumber)?.doubleValue { add("image.dpi", L("Resolution"), L("Image"), "\(Int(dpi)) DPI") }
        if o != .up { add("image.orientation", L("Orientation"), L("Image"), orientationName(o)) }
        add("file.format", L("Format"), L("File"), format.map(Formats.label))
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            add("file.size", L("Size"), L("File"), ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        let reason: String? = canEdit ? nil : L("\(Brand.name) can read but not edit metadata in \(format.map(Formats.label) ?? "this") files.")
        return MetadataSnapshot(container: .image, fields: fields, readOnlyReason: reason)
    }

    static func canWrite(_ format: FormatID?) -> Bool {
        guard let format else { return false }
        if format == Formats.jpg || format == Formats.png || format == Formats.webp { return true }
        return [Formats.heic, Formats.heif, Formats.avif, Formats.tiff, Formats.jp2, Formats.psd].contains(format)
            && ToolImageFormats.destinationType(for: format) != nil
    }

    // MARK: Write

    static func write(_ input: URL, changes: [String: String?], output: ToolOutput) throws -> URL {
        let format = Formats.detect(input)
        guard canWrite(format), let format else {
            throw ConversionError.other(L("\(Brand.name) can’t edit metadata in \(format.map(Formats.label) ?? "these") files yet."), detail: "edit metadata: \(input.pathExtension)")
        }
        guard let src = CGImageSourceCreateWithURL(input as CFURL, nil), CGImageSourceGetCount(src) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] else {
            throw ConversionError.unreadable(input, detail: "ImageIO could not open")
        }
        let updated = try applying(changes, to: props)
        let meta = metadataDictionaries(updated, keepOrientation: true)
        let w = (props[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue ?? 1
        let h = (props[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue ?? 1
        let original = try Data(contentsOf: input)

        if format == Formats.jpg, let file = JPEGSegments.parse(original) {
            let blocks = MetadataCarrier.jpegSegments(properties: meta, width: w, height: h)
            var xmp: JPEGSegments.Segment?
            if file.header.contains(where: \.isXMP), let data = updatedXMP(src, changes: changes) { xmp = JPEGSegments.xmpSegment(data) }
            var header = file.header.filter { !($0.isExif || $0.isXMP || $0.isIPTC) }
            let at = header.firstIndex { !$0.isJFIF } ?? header.count
            header.insert(contentsOf: blocks.exif + (xmp.map { [$0] } ?? []) + blocks.iptc, at: at)
            return try output.write(JPEGSegments.build(JPEGSegments.File(header: header, scan: file.scan, trailer: file.trailer)), ext: "jpg")
        }
        if format == Formats.webp {
            // EXIF chunk = the carrier JPEG's APP1 payload without "Exif\0\0"; title,
            // keywords and the rest live in XMP (WebP has no IPTC block).
            let exif = MetadataCarrier.jpegSegments(properties: meta, width: w, height: h).exif.first.map { Data($0.payload.dropFirst(6)) }
            let xmp = updatedXMP(src, changes: changes)
            let alpha = props[kCGImagePropertyHasAlpha as String] as? Bool ?? false
            guard let data = WebPChunks.replacingMetadata(original, exif: exif, xmp: xmp, width: w, height: h, hasAlpha: alpha) else {
                throw ConversionError.unreadable(input, detail: "WebP container")
            }
            return try output.write(data, ext: "webp")
        }
        if format == Formats.png, let chunks = PNGChunks.parse(original) {
            var kept = chunks.filter { !PNGChunks.metadataTypes.contains($0.type) }
            let insert = MetadataCarrier.pngChunks(properties: meta, width: w, height: h)
            let at = kept.firstIndex { $0.type == "IDAT" } ?? max(1, kept.count - 1)
            kept.insert(contentsOf: insert, at: at)
            return try output.write(PNGChunks.build(kept), ext: "png")
        }
        // Re-encode the stored (un-rotated) pixels with the new properties.
        guard let raw = CGImageSourceCreateImageAtIndex(src, 0, nil), let type = ToolImageFormats.destinationType(for: format) else {
            throw ConversionError.unreadable(input, detail: "decode for re-encode")
        }
        let data = try ToolImageEncoder.encodeNative(raw, type: type, quality: ToolImageFormats.isLossy(format) ? 0.92 : nil,
                                                 properties: meta, format: format)
        return try output.write(data, ext: input.pathExtension.isEmpty ? Formats.extension(for: format) : input.pathExtension.lowercased())
    }

    /// Applies field changes to ImageIO properties, mirroring each value into
    /// every dictionary that carries it so readers agree.
    static func applying(_ changes: [String: String?], to source: [String: Any]) throws -> [String: Any] {
        var p = source
        func edit(_ key: String, _ body: (inout [String: Any]) -> Void) {
            var d = (p[key] as? [String: Any]) ?? [:]
            body(&d)
            p[key] = d.isEmpty ? nil : d
        }
        func set(_ d: inout [String: Any], _ k: CFString, _ v: Any?) { d[k as String] = v }
        for (key, value) in changes {
            let v = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = (v?.isEmpty ?? true) ? nil : v
            switch key {
            case "title":
                edit(iptc) { set(&$0, kCGImagePropertyIPTCObjectName, text) }
            case "description":
                edit(tiff) { set(&$0, kCGImagePropertyTIFFImageDescription, text) }
                edit(iptc) { set(&$0, kCGImagePropertyIPTCCaptionAbstract, text) }
            case "artist":
                edit(tiff) { set(&$0, kCGImagePropertyTIFFArtist, text) }
                edit(iptc) { set(&$0, kCGImagePropertyIPTCByline, text.map { [$0] }) }
            case "copyright":
                edit(tiff) { set(&$0, kCGImagePropertyTIFFCopyright, text) }
                edit(iptc) { set(&$0, kCGImagePropertyIPTCCopyrightNotice, text) }
            case "keywords":
                let words = text?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                edit(iptc) { set(&$0, kCGImagePropertyIPTCKeywords, (words?.isEmpty ?? true) ? nil : words) }
            case "dateTaken":
                let stamp = try text.map { s -> String in
                    guard let d = exifDate(s) else { throw ConversionError.invalidOption("dateTaken") }
                    return d
                }
                edit(exif) {
                    set(&$0, kCGImagePropertyExifDateTimeOriginal, stamp)
                    set(&$0, kCGImagePropertyExifDateTimeDigitized, stamp)
                }
                edit(iptc) {
                    let parts = stamp?.split(separator: " ")
                    set(&$0, kCGImagePropertyIPTCDateCreated, parts.map { $0[0].replacingOccurrences(of: ":", with: "") })
                    set(&$0, kCGImagePropertyIPTCTimeCreated, parts.flatMap { $0.count > 1 ? $0[1].replacingOccurrences(of: ":", with: "") : nil })
                }
            case "gpsLatitude", "gpsLongitude":
                let isLat = key == "gpsLatitude"
                let number = try text.map { s -> Double in
                    guard let d = Double(s.replacingOccurrences(of: ",", with: ".")), abs(d) <= (isLat ? 90 : 180) else {
                        throw ConversionError.invalidOption(key)
                    }
                    return d
                }
                edit(gps) {
                    let k = isLat ? kCGImagePropertyGPSLatitude : kCGImagePropertyGPSLongitude
                    let ref = isLat ? kCGImagePropertyGPSLatitudeRef : kCGImagePropertyGPSLongitudeRef
                    set(&$0, k, number.map { abs($0) })
                    set(&$0, ref, number.map { isLat ? ($0 < 0 ? "S" : "N") : ($0 < 0 ? "W" : "E") })
                    // Without a position the rest of the GPS block is meaningless (and still private).
                    if $0[kCGImagePropertyGPSLatitude as String] == nil && $0[kCGImagePropertyGPSLongitude as String] == nil { $0 = [:] }
                }
            default:
                throw ConversionError.invalidOption("fields.\(key)")
            }
        }
        return p
    }

    /// Metadata dictionaries for writing (pixel/encoding keys removed).
    static func metadataDictionaries(_ p: [String: Any], keepOrientation: Bool) -> [String: Any] {
        var out = ToolMetadataFilter.properties(p, policy: .keep, for: Formats.png)
        if keepOrientation { out[kCGImagePropertyOrientation as String] = p[kCGImagePropertyOrientation as String] ?? 1 }
        if keepOrientation, var t = out[tiff] as? [String: Any], let o = p[kCGImagePropertyOrientation as String] {
            t[kCGImagePropertyTIFFOrientation as String] = o
            out[tiff] = t
        }
        return out
    }

    /// The source's XMP with the same edits applied (JPEGs that had XMP).
    private static func updatedXMP(_ src: CGImageSource, changes: [String: String?]) -> Data? {
        let m: CGMutableImageMetadata = CGImageSourceCopyMetadataAtIndex(src, 0, nil).flatMap { CGImageMetadataCreateMutableCopy($0) }
            ?? CGImageMetadataCreateMutable()
        let mapping: [String: [(CFString, CFString)]] = [
            "title": [(kCGImagePropertyIPTCDictionary, kCGImagePropertyIPTCObjectName)],
            "description": [(kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFImageDescription)],
            "artist": [(kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFArtist)],
            "copyright": [(kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFCopyright)],
            "keywords": [(kCGImagePropertyIPTCDictionary, kCGImagePropertyIPTCKeywords)],
            "dateTaken": [(kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeOriginal)],
        ]
        for (key, value) in changes {
            let text = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            if key == "gpsLatitude" || key == "gpsLongitude" {
                if text?.isEmpty ?? true { removeTags(m) { $0.hasPrefix("exif:GPS") } }
                continue
            }
            for (dict, prop) in mapping[key] ?? [] {
                if let tag = CGImageMetadataCopyTagMatchingImageProperty(m, dict, prop),
                   let prefix = CGImageMetadataTagCopyPrefix(tag), let name = CGImageMetadataTagCopyName(tag) {
                    CGImageMetadataRemoveTagWithPath(m, nil, "\(prefix):\(name)" as CFString)
                }
                guard let text, !text.isEmpty else { continue }
                let cfValue: CFTypeRef = key == "keywords"
                    ? text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } as CFArray
                    : (key == "dateTaken" ? (exifDate(text) ?? text) : text) as CFString
                _ = CGImageMetadataSetValueMatchingImageProperty(m, dict, prop, cfValue)
            }
        }
        removeTags(m) { $0.hasPrefix("iio:") }
        return CGImageMetadataCreateXMPData(m, nil) as Data?
    }

    private static func removeTags(_ m: CGMutableImageMetadata, where match: (String) -> Bool) {
        var paths: [String] = []
        CGImageMetadataEnumerateTagsUsingBlock(m, nil, nil) { path, _ in
            paths.append(path as String)
            return true
        }
        for p in paths where match(p) { CGImageMetadataRemoveTagWithPath(m, nil, p as CFString) }
    }

    // MARK: Strip

    static func strip(_ input: URL, output: ToolOutput, context: EngineContext) async throws -> URL {
        let format = Formats.detect(input)
        let props = ToolImageSupport.properties(of: input) ?? [:]
        let orientation = ToolImageSupport.orientation(of: props)
        let original = try Data(contentsOf: input)
        let ext = input.pathExtension.isEmpty ? Formats.extension(for: format ?? Formats.png) : input.pathExtension.lowercased()

        if format == Formats.jpg, let file = JPEGSegments.parse(original) {
            // Keep only what decoding needs: JFIF, ICC profile, Adobe colour transform, tables.
            var header = file.header.filter { !$0.isAppOrComment || $0.isJFIF || $0.isICC || $0.isAdobe }
            if orientation != .up {
                // A bare orientation tag keeps the photo upright without re-encoding it.
                let w = (props[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue ?? 1
                let h = (props[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue ?? 1
                let exifOnly = MetadataCarrier.jpegSegments(properties: [kCGImagePropertyOrientation as String: orientation.rawValue], width: w, height: h).exif
                header.insert(contentsOf: exifOnly, at: header.firstIndex { !$0.isJFIF } ?? header.count)
            }
            // The trailer (MPF secondary images, gain maps) goes too.
            return try output.write(JPEGSegments.build(JPEGSegments.File(header: header, scan: file.scan, trailer: Data()), includeTrailer: false), ext: ext)
        }
        if format == Formats.png, orientation == .up, let data = PNGChunks.stripped(original) {
            return try output.write(data, ext: ext)
        }
        if format == Formats.webp, orientation == .up, let data = WebPChunks.stripped(original) {
            return try output.write(data, ext: ext)
        }
        if format == Formats.gif, let data = strippedGIF(input) {
            return try output.write(data, ext: ext)
        }
        // Everything else: re-encode upright pixels with no metadata (ICC travels with the colour space).
        let decoded = try ToolImageSupport.decode(input)
        let outFormat = ToolImageFormats.outputFormat(for: format)
        let scratch = output.scratch
        defer { try? FileManager.default.removeItem(at: scratch) }
        let data = try await ToolImageEncoder(context: context, scratch: scratch)
            .encode(decoded.image, as: outFormat, quality: ToolImageFormats.reencodeQuality(outFormat), properties: [:])
        return try output.write(data, ext: outFormat == format ? ext : Formats.extension(for: outFormat))
    }

    /// Re-writes every GIF frame with only its timing, keeping animation.
    private static func strippedGIF(_ url: URL) -> Data? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let n = CGImageSourceGetCount(src)
        let data = NSMutableData()
        guard n > 0, let dest = CGImageDestinationCreateWithData(data as CFMutableData, UTType.gif.identifier as CFString, n, nil) else { return nil }
        let gifKey = kCGImagePropertyGIFDictionary as String
        let fileGIF = (CGImageSourceCopyProperties(src, nil) as? [String: Any])?[gifKey] as? [String: Any]
        let loop = fileGIF?[kCGImagePropertyGIFLoopCount as String] ?? 0
        CGImageDestinationSetProperties(dest, [gifKey: [kCGImagePropertyGIFLoopCount as String: loop]] as CFDictionary)
        for i in 0..<n {
            guard let frame = CGImageSourceCreateImageAtIndex(src, i, nil) else { return nil }
            let fp = (CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [String: Any])?[gifKey] as? [String: Any] ?? [:]
            var timing: [String: Any] = [:]
            for k in [kCGImagePropertyGIFDelayTime, kCGImagePropertyGIFUnclampedDelayTime] {
                if let v = fp[k as String] { timing[k as String] = v }
            }
            CGImageDestinationAddImage(dest, frame, [gifKey: timing] as CFDictionary)
        }
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    // MARK: Formatting helpers

    private static func dict(_ p: [String: Any], _ key: String) -> [String: Any] { (p[key] as? [String: Any]) ?? [:] }

    private static func string(_ v: Any?) -> String? {
        switch v {
        case let s as String: s.isEmpty ? nil : s
        case let n as NSNumber: n.stringValue
        case let a as [Any]: a.first.flatMap { string($0) }
        default: nil
        }
    }

    private static func list(_ v: Any?) -> String? {
        if let a = v as? [Any] { let s = a.compactMap { string($0) }.joined(separator: ", "); return s.isEmpty ? nil : s }
        return string(v)
    }

    private static func coordinate(_ g: [String: Any], _ key: CFString, _ refKey: CFString, negative: String) -> String? {
        guard let v = (g[key as String] as? NSNumber)?.doubleValue else { return nil }
        let neg = (g[refKey as String] as? String)?.uppercased() == negative
        return String(format: "%.6f", neg ? -v : v)
    }

    /// "2020:01:02 03:04:05" → "2020-01-02 03:04:05"
    static func displayDate(_ exif: String) -> String {
        let parts = exif.split(separator: " ", maxSplits: 1)
        guard let d = parts.first else { return exif }
        return d.replacingOccurrences(of: ":", with: "-") + (parts.count > 1 ? " " + parts[1] : "")
    }

    /// Accepts "yyyy-MM-dd[ HH:mm[:ss]]" or EXIF's "yyyy:MM:dd HH:mm:ss".
    static func exifDate(_ text: String) -> String? {
        let s = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "T", with: " ")
        let parts = s.split(separator: " ", maxSplits: 1).map(String.init)
        guard let datePart = parts.first else { return nil }
        let d = datePart.split(whereSeparator: { $0 == "-" || $0 == ":" || $0 == "/" }).compactMap { Int($0) }
        guard d.count == 3, (1...9999).contains(d[0]), (1...12).contains(d[1]), (1...31).contains(d[2]) else { return nil }
        var t = [0, 0, 0]
        if parts.count > 1 {
            let tp = parts[1].split(separator: ":").compactMap { Int($0) }
            guard (2...3).contains(tp.count), (0...23).contains(tp[0]), (0...59).contains(tp[1]), tp.count < 3 || (0...59).contains(tp[2]) else { return nil }
            for (k, v) in tp.enumerated() { t[k] = v }
        }
        return String(format: "%04d:%02d:%02d %02d:%02d:%02d", d[0], d[1], d[2], t[0], t[1], t[2])
    }

    private static func orientationName(_ o: CGImagePropertyOrientation) -> String {
        switch o {
        case .up: L("Normal")
        case .upMirrored: L("Mirrored")
        case .down: L("Rotated 180°")
        case .downMirrored: L("Mirrored, rotated 180°")
        case .leftMirrored: L("Mirrored, rotated 90° anticlockwise")
        case .right: L("Rotated 90° clockwise")
        case .rightMirrored: L("Mirrored, rotated 90° clockwise")
        case .left: L("Rotated 90° anticlockwise")
        }
    }
}
