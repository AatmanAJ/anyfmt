import CoreGraphics
import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Renders PDF pages to bitmaps (honouring /Rotate) for slide decks and slide images.
public enum PDFRaster {
    /// Page size in points after rotation.
    public static func size(_ page: PDFPage) -> CGSize {
        let b = page.bounds(for: .mediaBox)
        return page.rotation % 180 == 0 ? b.size : CGSize(width: b.height, height: b.width)
    }

    public static func render(_ page: PDFPage, scale: CGFloat) -> CGImage? {
        guard let cg = page.pageRef else { return nil }
        let s = size(page)
        let w = max(1, Int((s.width * scale).rounded())), h = max(1, Int((s.height * scale).rounded()))
        guard w * h < 200_000_000, let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                                     space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.scaleBy(x: CGFloat(w) / s.width, y: CGFloat(h) / s.height)
        ctx.concatenate(cg.getDrawingTransform(.mediaBox, rect: CGRect(origin: .zero, size: s), rotate: 0, preserveAspectRatio: true))
        ctx.drawPDFPage(cg)
        return ctx.makeImage()
    }

    /// Writes every page as an image file (`base-01.png` …). Returns the files in page order.
    public static func writePages(_ pdf: URL, to dir: URL, baseName: String, type: UTType, dpi: Double, quality: Double,
                                  progress: ProgressSink = .ignore) throws -> [URL] {
        guard let doc = PDFDocument(url: pdf), doc.pageCount > 0 else { throw ConversionError.unreadable(pdf, detail: "no pages") }
        let digits = max(2, String(doc.pageCount).count)
        let ext = type == .jpeg ? "jpg" : (type.preferredFilenameExtension ?? "png")
        var out: [URL] = []
        for i in 0..<doc.pageCount {
            try Task.checkCancellation()
            guard let page = doc.page(at: i), let img = render(page, scale: dpi / 72) else { continue }
            guard let data = ImageSupport.encode(img, type: type, quality: quality) else { continue }
            let name = String(format: "%@-%0\(digits)d.%@", baseName, i + 1, ext)
            let url = dir.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            out.append(url)
            progress(Double(i + 1) / Double(doc.pageCount))
        }
        guard !out.isEmpty else { throw ConversionError.outputMissing(pdf.lastPathComponent) }
        return out
    }
}

/// PDF → PPTX: one slide per page, the page rendered at high resolution filling
/// the slide. Slide size follows the first page's aspect ratio so nothing is
/// letterboxed. (Slides are pictures, not editable text — see PARITY notes.)
public struct PPTXWriter {
    public var zipOptions: ZipWriter.Options
    /// Pixels on the long edge of each rendered page.
    public var longEdge: CGFloat = 2400

    public init(zipOptions: ZipWriter.Options = .init()) { self.zipOptions = zipOptions }

    public func write(pdf: URL, title: String?, progress: ProgressSink = .ignore) throws -> Data {
        guard let doc = PDFDocument(url: pdf), doc.pageCount > 0 else { throw ConversionError.unreadable(pdf, detail: "no pages") }
        if doc.isLocked { throw ConversionError.other(L("This PDF is password-protected."), detail: pdf.path) }
        guard let first = doc.page(at: 0) else { throw ConversionError.unreadable(pdf, detail: "no first page") }
        let fs = PDFRaster.size(first)
        // 7.5 in high, width from the page aspect (PowerPoint allows 1–56 in per side).
        var cy = 6_858_000.0
        var cx = cy * Double(fs.width / max(fs.height, 1))
        if cx > 51_206_400 { cx = 51_206_400; cy = cx * Double(fs.height / max(fs.width, 1)) }
        if cx < 914_400 { cx = 914_400; cy = cx * Double(fs.height / max(fs.width, 1)) }
        let slideW = Int(cx), slideH = Int(cy)

        var zip = ZipWriter(options: zipOptions)
        var slides: [(xml: String, media: String)] = []
        var mediaFiles: [(String, Data)] = []
        for i in 0..<doc.pageCount {
            try Task.checkCancellation()
            guard let page = doc.page(at: i) else { continue }
            let s = PDFRaster.size(page)
            let scale = longEdge / max(s.width, s.height)
            guard let img = PDFRaster.render(page, scale: scale), let jpeg = ImageSupport.encode(img, type: .jpeg, quality: 0.9) else { continue }
            let name = "image\(i + 1).jpeg"
            mediaFiles.append((name, jpeg))
            // Fit the page into the slide, centred.
            let fit = min(cx / Double(s.width), cy / Double(s.height))
            let w = Double(s.width) * fit, h = Double(s.height) * fit
            let x = Int((cx - w) / 2), y = Int((cy - h) / 2)
            slides.append((Self.slideXML(index: i + 1, x: x, y: y, w: Int(w), h: Int(h)), name))
            progress(Double(i + 1) / Double(doc.pageCount))
        }
        guard !slides.isEmpty else { throw ConversionError.outputMissing(pdf.lastPathComponent) }

        var ct = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/><Default Extension=\"png\" ContentType=\"image/png\"/>"
        ct += "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>"
        ct += "<Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml\"/>"
        ct += "<Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml\"/>"
        ct += "<Override PartName=\"/ppt/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>"
        ct += "<Override PartName=\"/ppt/presProps.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presProps+xml\"/>"
        ct += "<Override PartName=\"/ppt/viewProps.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml\"/>"
        ct += "<Override PartName=\"/ppt/tableStyles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml\"/>"
        for k in slides.indices { ct += "<Override PartName=\"/ppt/slides/slide\(k + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" }
        ct += "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/><Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/></Types>"
        try zip.add("[Content_Types].xml", ct)
        try zip.add("_rels/.rels", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>
        """)
        try zip.add("docProps/core.xml", OOXMLCommon.coreXML(DocMetadata(title: title), date: zipOptions.deterministic ? Date(timeIntervalSince1970: 0) : zipOptions.date))
        try zip.add("docProps/app.xml", OOXMLCommon.appXML)

        var pres = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:presentation \(Self.ns) saveSubsetFonts=\"1\"><p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rId1\"/></p:sldMasterIdLst><p:sldIdLst>"
        var presRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/><Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"theme/theme1.xml\"/><Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps\" Target=\"presProps.xml\"/><Relationship Id=\"rId4\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps\" Target=\"viewProps.xml\"/><Relationship Id=\"rId5\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles\" Target=\"tableStyles.xml\"/>"
        for k in slides.indices {
            pres += "<p:sldId id=\"\(256 + k)\" r:id=\"rId\(10 + k)\"/>"
            presRels += "<Relationship Id=\"rId\(10 + k)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(k + 1).xml\"/>"
        }
        pres += "</p:sldIdLst><p:sldSz cx=\"\(slideW)\" cy=\"\(slideH)\"/><p:notesSz cx=\"6858000\" cy=\"9144000\"/></p:presentation>"
        presRels += "</Relationships>"
        try zip.add("ppt/presentation.xml", pres)
        try zip.add("ppt/_rels/presentation.xml.rels", presRels)
        try zip.add("ppt/presProps.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:presentationPr \(Self.ns)/>")
        try zip.add("ppt/viewProps.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:viewPr \(Self.ns)><p:normalViewPr><p:restoredLeft sz=\"15620\"/><p:restoredTop sz=\"94660\"/></p:normalViewPr><p:gridSpacing cx=\"76200\" cy=\"76200\"/></p:viewPr>")
        try zip.add("ppt/tableStyles.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<a:tblStyleLst xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" def=\"{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}\"/>")
        try zip.add("ppt/slideMasters/slideMaster1.xml", Self.master)
        try zip.add("ppt/slideMasters/_rels/slideMaster1.xml.rels", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/></Relationships>
        """)
        try zip.add("ppt/slideLayouts/slideLayout1.xml", Self.layout)
        try zip.add("ppt/slideLayouts/_rels/slideLayout1.xml.rels", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>
        """)
        try zip.add("ppt/theme/theme1.xml", Self.theme)
        for (k, s) in slides.enumerated() {
            try zip.add("ppt/slides/slide\(k + 1).xml", s.xml)
            try zip.add("ppt/slides/_rels/slide\(k + 1).xml.rels", """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(s.media)"/></Relationships>
            """)
        }
        for (name, data) in mediaFiles { try zip.add("ppt/media/\(name)", data, compress: false) }
        return try zip.finish()
    }

    static let ns = "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\""

    static let emptyTree = "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"

    static func slideXML(index: Int, x: Int, y: Int, w: Int, h: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sld \(ns)><p:cSld><p:spTree>\(emptyTree)<p:pic><p:nvPicPr><p:cNvPr id="2" name="Page \(index)" descr="Page \(index)"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(w)" cy="\(h)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic></p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
        """
    }

    static let master = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldMaster \(ns)><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg><p:spTree>\(emptyTree)</p:spTree></p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst><p:txStyles><p:titleStyle><a:lvl1pPr><a:defRPr sz="4400"/></a:lvl1pPr></p:titleStyle><p:bodyStyle><a:lvl1pPr><a:defRPr sz="3200"/></a:lvl1pPr></p:bodyStyle><p:otherStyle><a:lvl1pPr><a:defRPr sz="1800"/></a:lvl1pPr></p:otherStyle></p:txStyles></p:sldMaster>
    """

    static let layout = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <p:sldLayout \(ns) type="blank" preserve="1"><p:cSld name="Blank"><p:spTree>\(emptyTree)</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
    """

    static let theme: String = {
        func solid(_ c: String) -> String { "<a:solidFill><a:srgbClr val=\"\(c)\"/></a:solidFill>" }
        let fill = "<a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill>"
        let line = "<a:ln w=\"9525\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln>"
        let effect = "<a:effectStyle><a:effectLst/></a:effectStyle>"
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office Theme"><a:themeElements><a:clrScheme name="Office"><a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2><a:accent1><a:srgbClr val="4472C4"/></a:accent1><a:accent2><a:srgbClr val="ED7D31"/></a:accent2><a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4><a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme><a:fontScheme name="Office"><a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme><a:fmtScheme name="Office"><a:fillStyleLst>\(fill)\(fill)\(fill)</a:fillStyleLst><a:lnStyleLst>\(line)\(line)\(line)</a:lnStyleLst><a:effectStyleLst>\(effect)\(effect)\(effect)</a:effectStyleLst><a:bgFillStyleLst>\(fill)\(solid("FFFFFF"))\(solid("F2F2F2"))</a:bgFillStyleLst></a:fmtScheme></a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>
        """
    }()
}
