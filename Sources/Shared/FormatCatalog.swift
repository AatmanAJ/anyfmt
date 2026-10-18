import Foundation
import UniformTypeIdentifiers

/// Every format Halo knows about. The capability table refers to these ids.
/// Adding a format: add one `Format` here, then capability rows in the
/// owning lane's `*Routes.swift`.
public enum Formats {
    // MARK: Images
    public static let jpg: FormatID = "jpg"
    public static let png: FormatID = "png"
    public static let webp: FormatID = "webp"
    public static let heic: FormatID = "heic"
    public static let heif: FormatID = "heif"
    public static let tiff: FormatID = "tiff"
    public static let avif: FormatID = "avif"
    public static let bmp: FormatID = "bmp"
    public static let gif: FormatID = "gif"
    public static let svg: FormatID = "svg"
    public static let jp2: FormatID = "jp2"
    public static let jxl: FormatID = "jxl"
    public static let psd: FormatID = "psd"
    public static let ico: FormatID = "ico"
    public static let icns: FormatID = "icns"
    public static let tga: FormatID = "tga"
    public static let exr: FormatID = "exr"
    public static let raw: FormatID = "raw"
    // MARK: PDF
    public static let pdf: FormatID = "pdf"
    // MARK: Audio
    public static let mp3: FormatID = "mp3"
    public static let m4a: FormatID = "m4a"
    public static let wav: FormatID = "wav"
    public static let flac: FormatID = "flac"
    public static let ogg: FormatID = "ogg"
    public static let opus: FormatID = "opus"
    public static let aiff: FormatID = "aiff"
    public static let wma: FormatID = "wma"
    public static let caf: FormatID = "caf"
    // MARK: Video
    public static let mp4: FormatID = "mp4"
    public static let mov: FormatID = "mov"
    public static let mkv: FormatID = "mkv"
    public static let webm: FormatID = "webm"
    public static let avi: FormatID = "avi"
    public static let wmv: FormatID = "wmv"
    public static let m4v: FormatID = "m4v"
    // MARK: Documents
    public static let docx: FormatID = "docx"
    public static let doc: FormatID = "doc"
    public static let odt: FormatID = "odt"
    public static let pages: FormatID = "pages"
    public static let md: FormatID = "md"
    public static let txt: FormatID = "txt"
    public static let rtf: FormatID = "rtf"
    public static let rtfd: FormatID = "rtfd"
    public static let textClipping: FormatID = "textclipping"
    public static let html: FormatID = "html"
    public static let webarchive: FormatID = "webarchive"
    // MARK: Slides
    public static let ppt: FormatID = "ppt"
    public static let pptx: FormatID = "pptx"
    public static let key: FormatID = "key"
    public static let odp: FormatID = "odp"
    // MARK: Spreadsheets
    public static let xlsx: FormatID = "xlsx"
    public static let xls: FormatID = "xls"
    public static let ods: FormatID = "ods"
    public static let csv: FormatID = "csv"
    public static let tsv: FormatID = "tsv"
    public static let numbers: FormatID = "numbers"
    public static let json: FormatID = "json"
    // MARK: Ebooks
    public static let epub: FormatID = "epub"
    // MARK: Subtitles
    public static let srt: FormatID = "srt"
    public static let vtt: FormatID = "vtt"
    // MARK: Archives
    public static let zip: FormatID = "zip"
    public static let tar: FormatID = "tar"
    public static let gz: FormatID = "gz"
    public static let rar: FormatID = "rar"
    public static let sevenZip: FormatID = "7z"
    public static let folder: FormatID = "folder"

    /// The full catalogue. Order within a kind = default wheel order.
    public static let all: [Format] = [
        // Images
        Format(jpg, kind: .image, label: "JPG", name: L("JPEG image"), extensions: ["jpg", "jpeg", "jpe"], types: ["public.jpeg"], order: 10),
        Format(png, kind: .image, label: "PNG", name: L("PNG image"), extensions: ["png"], types: ["public.png"], order: 20),
        Format(heic, kind: .image, label: "HEIC", name: L("HEIC image"), extensions: ["heic"], types: ["public.heic"], order: 30),
        Format(webp, kind: .image, label: "WebP", name: L("WebP image"), extensions: ["webp"], types: ["org.webmproject.webp"], order: 40),
        Format(avif, kind: .image, label: "AVIF", name: L("AVIF image"), extensions: ["avif"], types: ["public.avif"], order: 50),
        Format(tiff, kind: .image, label: "TIFF", name: L("TIFF image"), extensions: ["tiff", "tif"], types: ["public.tiff"], order: 60),
        Format(gif, kind: .image, label: "GIF", name: L("GIF image"), extensions: ["gif"], types: ["com.compuserve.gif"], glyph: "photo.stack", order: 70),
        Format(bmp, kind: .image, label: "BMP", name: L("Bitmap image"), extensions: ["bmp"], types: ["com.microsoft.bmp"], order: 80),
        Format(heif, kind: .image, label: "HEIF", name: L("HEIF image"), extensions: ["heif", "hif"], types: ["public.heif"], order: 90),
        Format(jp2, kind: .image, label: "JP2", name: L("JPEG 2000 image"), extensions: ["jp2", "j2k", "jpf"], types: ["public.jpeg-2000"], order: 100),
        Format(jxl, kind: .image, label: "JXL", name: L("JPEG XL image"), extensions: ["jxl"], types: ["public.jpeg-xl"], order: 110),
        Format(psd, kind: .image, label: "PSD", name: L("Photoshop image"), extensions: ["psd"], types: ["com.adobe.photoshop-image"], order: 120),
        Format(ico, kind: .image, label: "ICO", name: L("Windows icon"), extensions: ["ico"], types: ["com.microsoft.ico"], order: 130),
        Format(icns, kind: .image, label: "ICNS", name: L("macOS icon"), extensions: ["icns"], types: ["com.apple.icns"], order: 140),
        Format(tga, kind: .image, label: "TGA", name: L("Targa image"), extensions: ["tga"], types: ["com.truevision.tga-image"], order: 150),
        Format(exr, kind: .image, label: "EXR", name: L("OpenEXR image"), extensions: ["exr"], types: ["com.ilm.openexr-image"], order: 160),
        Format(raw, kind: .image, label: "RAW", name: L("Camera RAW image"),
               extensions: ["dng", "cr2", "cr3", "nef", "nrw", "arw", "raf", "orf", "rw2", "pef", "srw", "3fr", "erf", "rwl", "iiq"],
               types: ["public.camera-raw-image"], glyph: "camera.aperture", order: 170),
        Format(svg, kind: .vector, label: "SVG", name: L("SVG vector image"), extensions: ["svg"], types: ["public.svg-image"], order: 10),
        // PDF
        Format(pdf, kind: .pdf, label: "PDF", name: L("PDF document"), extensions: ["pdf"], types: ["com.adobe.pdf"], order: 10),
        // Audio
        Format(mp3, kind: .audio, label: "MP3", name: L("MP3 audio"), extensions: ["mp3"], types: ["public.mp3"], order: 10),
        Format(m4a, kind: .audio, label: "M4A", name: L("AAC audio (M4A)"), extensions: ["m4a"], types: ["com.apple.m4a-audio", "public.mpeg-4-audio"], order: 20),
        Format(wav, kind: .audio, label: "WAV", name: L("WAV audio"), extensions: ["wav"], types: ["com.microsoft.waveform-audio"], order: 30),
        Format(flac, kind: .audio, label: "FLAC", name: L("FLAC audio"), extensions: ["flac"], types: ["org.xiph.flac"], order: 40),
        Format(aiff, kind: .audio, label: "AIFF", name: L("AIFF audio"), extensions: ["aiff", "aif", "aifc"], types: ["public.aiff-audio", "public.aifc-audio"], order: 50),
        Format(ogg, kind: .audio, label: "OGG", name: L("Ogg Vorbis audio"), extensions: ["ogg", "oga"], types: ["org.xiph.ogg-audio", "org.xiph.ogg"], order: 60),
        Format(opus, kind: .audio, label: "Opus", name: L("Opus audio"), extensions: ["opus"], types: ["org.xiph.opus"], order: 70),
        Format(caf, kind: .audio, label: "CAF", name: L("Core Audio file"), extensions: ["caf"], types: ["com.apple.coreaudio-format"], order: 80),
        Format(wma, kind: .audio, label: "WMA", name: L("Windows Media audio"), extensions: ["wma"], types: ["com.microsoft.windows-media-wma"], order: 90),
        // Video
        Format(mp4, kind: .video, label: "MP4", name: L("MPEG-4 video"), extensions: ["mp4"], types: ["public.mpeg-4"], order: 10),
        Format(mov, kind: .video, label: "MOV", name: L("QuickTime movie"), extensions: ["mov", "qt"], types: ["com.apple.quicktime-movie"], order: 20),
        Format(webm, kind: .video, label: "WebM", name: L("WebM video"), extensions: ["webm"], types: ["org.webmproject.webm"], order: 30),
        Format(mkv, kind: .video, label: "MKV", name: L("Matroska video"), extensions: ["mkv"], types: ["org.matroska.mkv"], order: 40),
        Format(avi, kind: .video, label: "AVI", name: L("AVI video"), extensions: ["avi"], types: ["public.avi"], order: 50),
        Format(wmv, kind: .video, label: "WMV", name: L("Windows Media video"), extensions: ["wmv"], types: ["com.microsoft.windows-media-wmv"], order: 60),
        Format(m4v, kind: .video, label: "M4V", name: L("iTunes video"), extensions: ["m4v"], types: ["com.apple.m4v-video"], order: 70),
        // Documents
        Format(docx, kind: .document, label: "DOCX", name: L("Word document"), extensions: ["docx"], types: ["org.openxmlformats.wordprocessingml.document"], order: 10),
        Format(pages, kind: .document, label: "Pages", name: L("Pages document"), extensions: ["pages"], types: ["com.apple.iwork.pages.sffpages", "com.apple.iwork.pages.pages"], order: 20, isPackage: true),
        Format(md, kind: .document, label: "MD", name: L("Markdown"), extensions: ["md", "markdown", "mdown", "mkd"], types: ["net.daringfireball.markdown"], glyph: "text.badge.checkmark", order: 30),
        Format(txt, kind: .document, label: "TXT", name: L("Plain text"), extensions: ["txt", "text"], types: ["public.plain-text"], glyph: "text.alignleft", order: 40),
        Format(html, kind: .document, label: "HTML", name: L("Web page"), extensions: ["html", "htm"], types: ["public.html"], glyph: "chevron.left.forwardslash.chevron.right", order: 50),
        Format(rtf, kind: .document, label: "RTF", name: L("Rich text"), extensions: ["rtf"], types: ["public.rtf"], order: 60),
        Format(rtfd, kind: .document, label: "RTFD", name: L("Rich text with attachments"), extensions: ["rtfd"], types: ["com.apple.rtfd"], order: 70, isPackage: true),
        Format(odt, kind: .document, label: "ODT", name: L("OpenDocument text"), extensions: ["odt"], types: ["org.oasis-open.opendocument.text"], order: 80),
        Format(doc, kind: .document, label: "DOC", name: L("Word 97 document"), extensions: ["doc"], types: ["com.microsoft.word.doc"], order: 90),
        Format(webarchive, kind: .document, label: "Web Archive", name: L("Safari web archive"), extensions: ["webarchive"], types: ["com.apple.webarchive"], order: 100),
        Format(textClipping, kind: .document, label: "Clipping", name: L("Text clipping"), extensions: ["textclipping"], types: ["com.apple.finder.textclipping", "com.apple.textclipping"], order: 110),
        // Slides
        Format(pptx, kind: .slides, label: "PPTX", name: L("PowerPoint presentation"), extensions: ["pptx"], types: ["org.openxmlformats.presentationml.presentation"], order: 10),
        Format(ppt, kind: .slides, label: "PPT", name: L("PowerPoint 97 presentation"), extensions: ["ppt", "pps"], types: ["com.microsoft.powerpoint.ppt"], order: 20),
        Format(key, kind: .slides, label: "Keynote", name: L("Keynote presentation"), extensions: ["key"], types: ["com.apple.iwork.keynote.sffkey", "com.apple.iwork.keynote.key"], order: 30, isPackage: true),
        Format(odp, kind: .slides, label: "ODP", name: L("OpenDocument presentation"), extensions: ["odp"], types: ["org.oasis-open.opendocument.presentation"], order: 40),
        // Spreadsheets
        Format(xlsx, kind: .spreadsheet, label: "XLSX", name: L("Excel workbook"), extensions: ["xlsx"], types: ["org.openxmlformats.spreadsheetml.sheet"], order: 10),
        Format(csv, kind: .spreadsheet, label: "CSV", name: L("Comma-separated values"), extensions: ["csv"], types: ["public.comma-separated-values-text"], order: 20),
        Format(tsv, kind: .spreadsheet, label: "TSV", name: L("Tab-separated values"), extensions: ["tsv", "tab"], types: ["public.tab-separated-values-text"], order: 30),
        Format(ods, kind: .spreadsheet, label: "ODS", name: L("OpenDocument spreadsheet"), extensions: ["ods"], types: ["org.oasis-open.opendocument.spreadsheet"], order: 40),
        Format(xls, kind: .spreadsheet, label: "XLS", name: L("Excel 97 workbook"), extensions: ["xls"], types: ["com.microsoft.excel.xls"], order: 50),
        Format(numbers, kind: .spreadsheet, label: "Numbers", name: L("Numbers spreadsheet"), extensions: ["numbers"], types: ["com.apple.iwork.numbers.sffnumbers", "com.apple.iwork.numbers.numbers"], order: 60, isPackage: true),
        Format(json, kind: .spreadsheet, label: "JSON", name: L("JSON data"), extensions: ["json"], types: ["public.json"], glyph: "curlybraces", order: 70),
        // Ebooks
        Format(epub, kind: .ebook, label: "EPUB", name: L("EPUB ebook"), extensions: ["epub"], types: ["org.idpf.epub-container"], order: 10),
        // Subtitles
        Format(srt, kind: .subtitle, label: "SRT", name: L("SubRip subtitles"), extensions: ["srt"], types: ["org.matroska.srt", "public.srt"], order: 10),
        Format(vtt, kind: .subtitle, label: "VTT", name: L("WebVTT subtitles"), extensions: ["vtt"], types: ["org.w3.webvtt", "public.vtt"], order: 20),
        // Archives
        Format(zip, kind: .archive, label: "ZIP", name: L("ZIP archive"), extensions: ["zip"], types: ["public.zip-archive"], order: 10),
        Format(tar, kind: .archive, label: "TAR", name: L("Tar archive"), extensions: ["tar"], types: ["public.tar-archive"], order: 20),
        Format(gz, kind: .archive, label: "GZIP", name: L("Gzip archive"), extensions: ["gz", "tgz"], types: ["org.gnu.gnu-zip-archive", "org.gnu.gnu-zip-tar-archive"], order: 30),
        Format(rar, kind: .archive, label: "RAR", name: L("RAR archive"), extensions: ["rar"], types: ["com.rarlab.rar-archive"], order: 40),
        Format(sevenZip, kind: .archive, label: "7z", name: L("7-Zip archive"), extensions: ["7z"], types: ["org.7-zip.7-zip-archive"], order: 50),
        Format(folder, kind: .folder, label: "Folder", name: L("Folder"), extensions: [], types: ["public.folder"], glyph: "folder", order: 10),
    ]

    private static let byID: [FormatID: Format] = {
        var d: [FormatID: Format] = [:]
        for f in all where d[f.id] == nil { d[f.id] = f }
        return d
    }()

    private static let byExtension: [String: FormatID] = {
        var d: [String: FormatID] = [:]
        for f in all { for e in f.extensions where d[e] == nil { d[e] = f.id } }
        return d
    }()

    public static func format(_ id: FormatID) -> Format? { byID[id] }

    public static func label(_ id: FormatID) -> String { byID[id]?.label ?? id.rawValue.uppercased() }

    public static func kind(_ id: FormatID) -> FileKind { byID[id]?.kind ?? .other }

    public static func `extension`(for id: FormatID) -> String { byID[id]?.primaryExtension ?? id.rawValue }


    /// Detects the format of a file on disk: folder check, then `.tar.gz`, then
    /// extension, then UTType conformance. Returns nil for unknown files.
    public static func detect(_ url: URL) -> FormatID? {
        let ext = url.pathExtension.lowercased()
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if exists, isDir.boolValue {
            // Packages (rtfd, pages, key, numbers) are directories with a known extension.
            if let id = byExtension[ext], byID[id]?.isPackage == true { return id }
            return folder
        }
        if let id = byExtension[ext] { return id }
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: ext)
        guard let type else { return nil }
        for f in all {
            for t in f.typeIdentifiers {
                if let ft = UTType(t), type.conforms(to: ft) { return f.id }
            }
        }
        return nil
    }
}
