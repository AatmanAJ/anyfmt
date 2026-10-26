#!/usr/bin/env bash
# Lane F fixtures: documents, slides, spreadsheets, EPUB, archives.
# Everything is generated from scratch with system tools (textutil, bsdtar,
# ditto, gzip) and a stdlib-only Python builder for the zip-based formats
# (DOCX, EPUB, PPTX, XLSX, ODS) and RAR (stored entries, written from the
# published RAR 4.x block layout). Contract: see Tests/Fixtures/make-fixtures.sh.
set -euo pipefail
OUT="${OUT:?OUT must be set}"
mkdir -p "$OUT"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/anyfmt-docs-fixtures.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# --- Python builder: PNG, DOCX, EPUB, PPTX, XLSX, ODS, text clipping, RAR, edge archives
/usr/bin/python3 -I - "$OUT" "$TMP" <<'PY'
import os, sys, struct, zlib, zipfile, plistlib, tarfile, io, time

OUT, TMP = sys.argv[1], sys.argv[2]

def png(w, h):
    raw = b''.join(b'\x00' + bytes(v for x in range(w) for v in ((x * 255) // max(w - 1, 1), (y * 255) // max(h - 1, 1), 160)) for y in range(h))
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')

FIG = png(96, 64)
with open(os.path.join(OUT, 'docs-figure.png'), 'wb') as f:
    f.write(FIG)

def write_zip(path, entries, mimetype=None):
    with zipfile.ZipFile(path, 'w') as z:
        if mimetype:
            z.writestr(zipfile.ZipInfo('mimetype', (2024, 1, 1, 0, 0, 0)), mimetype, compress_type=zipfile.ZIP_STORED)
        for name, data in entries:
            info = zipfile.ZipInfo(name, (2024, 1, 1, 0, 0, 0))
            z.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED)

W = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"'

def p(text, style=None, num=None, runs=None):
    ppr = ''
    if style: ppr += '<w:pStyle w:val="%s"/>' % style
    if num: ppr += '<w:numPr><w:ilvl w:val="%d"/><w:numId w:val="%d"/></w:numPr>' % (num[1], num[0])
    body = runs if runs is not None else '<w:r><w:t xml:space="preserve">%s</w:t></w:r>' % text
    return '<w:p>%s%s</w:p>' % ('<w:pPr>%s</w:pPr>' % ppr if ppr else '', body)

def run(text, props=''):
    return '<w:r>%s<w:t xml:space="preserve">%s</w:t></w:r>' % ('<w:rPr>%s</w:rPr>' % props if props else '', text)

def cell(text, header=False):
    r = run(text, '<w:b/>' if header else '')
    return '<w:tc><w:tcPr><w:tcW w:w="3000" w:type="dxa"/></w:tcPr><w:p>%s</w:p></w:tc>' % r

table = '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/></w:tblPr><w:tblGrid><w:gridCol w:w="3000"/><w:gridCol w:w="3000"/><w:gridCol w:w="3000"/></w:tblGrid>'
table += '<w:tr><w:trPr><w:tblHeader/></w:trPr>' + cell('Fruit', True) + cell('Colour', True) + cell('Price', True) + '</w:tr>'
for row in (('Apple', 'Red', '1.20'), ('Banana', 'Yellow', '0.50')):
    table += '<w:tr>' + ''.join(cell(c) for c in row) + '</w:tr>'
table += '</w:tbl>'
drawing = ('<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="1828800" cy="1219200"/><wp:docPr id="1" name="Picture 1" descr="A gradient figure"/>'
           '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="1" name="figure.png"/><pic:cNvPicPr/></pic:nvPicPr>'
           '<pic:blipFill><a:blip r:embed="rId10"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="1828800" cy="1219200"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>')
body = ''.join([
    p('anyfmt Sample Document', 'Heading1'),
    p('', runs=run('This paragraph has ') + run('bold', '<w:b/>') + run(', ') + run('italic', '<w:i/>') + run(', ') + run('underlined', '<w:u w:val="single"/>') + run(' and ') + run('struck', '<w:strike/>') + run(' text, plus a ') +
      '<w:hyperlink r:id="rId11" w:history="1">' + run('link to example.org', '<w:rStyle w:val="Hyperlink"/>') + '</w:hyperlink>' + run('.')),
    p('Lists', 'Heading2'),
    p('First bullet', num=(1, 0)), p('Nested bullet', num=(1, 1)), p('Second bullet', num=(1, 0)),
    p('Step one', num=(2, 0)), p('Step two', num=(2, 0)), p('Step three', num=(2, 0)),
    p('Table', 'Heading2'),
    table,
    p('', runs=drawing),
    '<w:p><w:r><w:br w:type="page"/></w:r></w:p>',
    p('After the break', 'Heading2'),
    p('The last paragraph of the sample document.'),
])
document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document %s><w:body>%s<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>' % (W, body)
styles = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles %s><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>'
          '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style>'
          '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:pPr><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>'
          '<w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/><w:rPr><w:color w:val="0563C1"/><w:u w:val="single"/></w:rPr></w:style>'
          '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr></w:style></w:styles>') % W
numbering = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:numbering %s>'
             '<w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl><w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="o"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>'
             '<w:abstractNum w:abstractNumId="1"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum>'
             '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num><w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num></w:numbering>') % W
write_zip(os.path.join(OUT, 'sample.docx'), [
    ('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>'),
    ('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>'),
    ('word/_rels/document.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/><Relationship Id="rId10" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/><Relationship Id="rId11" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.org/" TargetMode="External"/></Relationships>'),
    ('word/document.xml', document), ('word/styles.xml', styles), ('word/numbering.xml', numbering),
    ('word/media/image1.png', FIG),
    ('docProps/core.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>anyfmt Sample Document</dc:title><dc:creator>anyfmt Fixtures</dc:creator></cp:coreProperties>'),
])

# --- EPUB 3
XH = '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE html>\n<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en" xml:lang="en"><head><meta charset="utf-8"/><title>%s</title><link rel="stylesheet" type="text/css" href="style.css"/></head><body>%s</body></html>'
ch1 = XH % ('Chapter One', '<h1>Chapter One</h1><p>It was a <em>bright</em> cold day, and the clocks were striking <strong>thirteen</strong>.</p><ul><li>First point</li><li>Second point</li></ul><figure><img src="images/fig.png" alt="Gradient figure"/></figure>')
ch2 = XH % ('Chapter Two', '<h1>Chapter Two</h1><p>See <a href="https://example.org/">the website</a> for more.</p><table><thead><tr><th>Name</th><th>Score</th></tr></thead><tbody><tr><td>Ada</td><td>10</td></tr><tr><td>Grace</td><td>9</td></tr></tbody></table><blockquote><p>A quoted line.</p></blockquote>')
nav = XH % ('Contents', '<nav epub:type="toc" id="toc"><h1>Contents</h1><ol><li><a href="ch1.xhtml">Chapter One</a></li><li><a href="ch2.xhtml">Chapter Two</a></li></ol></nav>')
opf = ('<?xml version="1.0" encoding="UTF-8"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:uuid:7d3d0c38-6a7e-4a3e-9e57-6b1e2f1d0a01</dc:identifier><dc:title>anyfmt Sample Book</dc:title><dc:creator>anyfmt Fixtures</dc:creator><dc:language>en</dc:language><meta property="dcterms:modified">2024-01-01T00:00:00Z</meta></metadata>'
       '<manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/><item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/><item id="css" href="style.css" media-type="text/css"/><item id="fig" href="images/fig.png" media-type="image/png"/></manifest>'
       '<spine><itemref idref="nav" linear="no"/><itemref idref="ch1"/><itemref idref="ch2"/></spine></package>')
write_zip(os.path.join(OUT, 'sample.epub'), [
    ('META-INF/container.xml', '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'),
    ('OEBPS/content.opf', opf), ('OEBPS/nav.xhtml', nav), ('OEBPS/ch1.xhtml', ch1), ('OEBPS/ch2.xhtml', ch2),
    ('OEBPS/style.css', 'body { font-family: serif; }'), ('OEBPS/images/fig.png', FIG),
], mimetype='application/epub+zip')

# --- PPTX (3 slides: title, bullets, picture)
PNS = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"'
GRP = '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>'
def sp(i, name, x, y, cx, cy, paras, size):
    ps = ''.join('<a:p><a:r><a:rPr lang="en-US" sz="%d"/><a:t>%s</a:t></a:r></a:p>' % (size, t) for t in paras)
    return '<p:sp><p:nvSpPr><p:cNvPr id="%d" name="%s"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="%d" y="%d"/><a:ext cx="%d" cy="%d"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr><p:txBody><a:bodyPr wrap="square"/><a:lstStyle/>%s</p:txBody></p:sp>' % (i, name, x, y, cx, cy, ps)
def slide(content):
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sld %s><p:cSld><p:spTree>%s%s</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>' % (PNS, GRP, content)
pic = '<p:pic><p:nvPicPr><p:cNvPr id="4" name="Figure" descr="Gradient figure"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="3048000" y="2286000"/><a:ext cx="6096000" cy="4064000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>'
slides = [
    slide(sp(2, 'Title', 914400, 2286000, 10363200, 1371600, ['anyfmt Sample Deck'], 4400) + sp(3, 'Subtitle', 914400, 3810000, 10363200, 914400, ['Generated fixture'], 2400)),
    slide(sp(2, 'Title', 609600, 304800, 10972800, 1143000, ['Agenda'], 3600) + sp(3, 'Body', 609600, 1600200, 10972800, 4572000, ['Introductions', 'Results', 'Next steps'], 2400)),
    slide(sp(2, 'Title', 609600, 304800, 10972800, 1143000, ['A picture'], 3600) + pic),
]
theme = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office"><a:themeElements><a:clrScheme name="Office"><a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1><a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2><a:accent1><a:srgbClr val="4472C4"/></a:accent1><a:accent2><a:srgbClr val="ED7D31"/></a:accent2><a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4><a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6><a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink></a:clrScheme>'
         '<a:fontScheme name="Office"><a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont><a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>'
         '<a:fmtScheme name="Office"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>')
master = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldMaster %s><p:cSld><p:spTree>%s</p:spTree></p:cSld><p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>' % (PNS, GRP)
layout = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:sldLayout %s type="blank"><p:cSld name="Blank"><p:spTree>%s</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>' % (PNS, GRP)
REL = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">%s</Relationships>'
def rel(i, t, target):
    return '<Relationship Id="rId%d" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/%s" Target="%s"/>' % (i, t, target)
entries = [
    ('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>'
     + ''.join('<Override PartName="/ppt/slides/slide%d.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>' % (k + 1) for k in range(len(slides))) + '</Types>'),
    ('_rels/.rels', REL % '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>'),
    ('ppt/presentation.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><p:presentation %s><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst><p:sldIdLst>%s</p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>' % (PNS, ''.join('<p:sldId id="%d" r:id="rId%d"/>' % (256 + k, 10 + k) for k in range(len(slides))))),
    ('ppt/_rels/presentation.xml.rels', REL % (rel(1, 'slideMaster', 'slideMasters/slideMaster1.xml') + rel(2, 'theme', 'theme/theme1.xml') + ''.join(rel(10 + k, 'slide', 'slides/slide%d.xml' % (k + 1)) for k in range(len(slides))))),
    ('ppt/slideMasters/slideMaster1.xml', master),
    ('ppt/slideMasters/_rels/slideMaster1.xml.rels', REL % (rel(1, 'slideLayout', '../slideLayouts/slideLayout1.xml') + rel(2, 'theme', '../theme/theme1.xml'))),
    ('ppt/slideLayouts/slideLayout1.xml', layout),
    ('ppt/slideLayouts/_rels/slideLayout1.xml.rels', REL % rel(1, 'slideMaster', '../slideMasters/slideMaster1.xml')),
    ('ppt/theme/theme1.xml', theme),
    ('ppt/media/image1.png', FIG),
]
for k, s in enumerate(slides):
    entries.append(('ppt/slides/slide%d.xml' % (k + 1), s))
    rels = rel(1, 'slideLayout', '../slideLayouts/slideLayout1.xml') + (rel(2, 'image', '../media/image1.png') if k == 2 else '')
    entries.append(('ppt/slides/_rels/slide%d.xml.rels' % (k + 1), REL % rels))
write_zip(os.path.join(OUT, 'sample.pptx'), entries)

# --- XLSX (two sheets; shared + inline strings, numbers, dates, booleans, a cached formula)
SNS = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
shared = ['Item', 'Quantity', 'Price', 'Date', 'In stock', 'Widget, large', 'Gadget "pro"', 'Note']
sst = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><sst %s count="%d" uniqueCount="%d">%s</sst>' % (SNS, len(shared), len(shared), ''.join('<si><t>%s</t></si>' % s.replace('&', '&amp;').replace('"', '&quot;') for s in shared))
def c(ref, v, t=None, s=None):
    return '<c r="%s"%s%s><v>%s</v></c>' % (ref, ' t="%s"' % t if t else '', ' s="%d"' % s if s is not None else '', v)
sheet1 = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet %s><sheetData>' % SNS
          + '<row r="1">' + c('A1', 0, 's') + c('B1', 1, 's') + c('C1', 2, 's') + c('D1', 3, 's') + c('E1', 4, 's') + '</row>'
          + '<row r="2">' + c('A2', 5, 's') + c('B2', 3) + c('C2', '19.99') + c('D2', '45366', s=1) + c('E2', 1, 'b') + '</row>'
          + '<row r="3">' + c('A3', 6, 's') + c('B3', 12) + c('C3', '4.5') + c('D3', '45397', s=1) + c('E3', 0, 'b') + '</row>'
          + '<row r="4"><c r="A4" t="inlineStr"><is><t>Total</t></is></c><c r="B4"><f>SUM(B2:B3)</f><v>15</v></c></row>'
          + '</sheetData></worksheet>')
sheet2 = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet %s><sheetData><row r="1">' % SNS + c('A1', 7, 's') + '</row><row r="3"><c r="B3" t="inlineStr"><is><t>Sparse cell</t></is></c></row></sheetData></worksheet>')
xstyles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet %s><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs></styleSheet>' % SNS
write_zip(os.path.join(OUT, 'sample.xlsx'), [
    ('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>'),
    ('_rels/.rels', REL % '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'),
    ('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook %s><sheets><sheet name="Inventory" sheetId="1" r:id="rId1"/><sheet name="Notes" sheetId="2" r:id="rId2"/></sheets></workbook>' % SNS),
    ('xl/_rels/workbook.xml.rels', REL % (rel(1, 'worksheet', 'worksheets/sheet1.xml') + rel(2, 'worksheet', 'worksheets/sheet2.xml') + rel(3, 'styles', 'styles.xml') + rel(4, 'sharedStrings', 'sharedStrings.xml'))),
    ('xl/worksheets/sheet1.xml', sheet1), ('xl/worksheets/sheet2.xml', sheet2),
    ('xl/styles.xml', xstyles), ('xl/sharedStrings.xml', sst),
])

# --- ODS (typed cells, repeats, two tables)
ONS = 'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"'
def oc(kind, value, text):
    attr = {'float': 'office:value="%s"' % value, 'date': 'office:date-value="%s"' % value, 'boolean': 'office:boolean-value="%s"' % value, 'string': '', 'percentage': 'office:value="%s"' % value}[kind]
    return '<table:table-cell office:value-type="%s" %s><text:p>%s</text:p></table:table-cell>' % (kind, attr, text)
ods = ('<?xml version="1.0" encoding="UTF-8"?><office:document-content %s office:version="1.2"><office:body><office:spreadsheet>' % ONS
       + '<table:table table:name="Scores"><table:table-column table:number-columns-repeated="4"/>'
       + '<table:table-row>' + oc('string', '', 'Name') + oc('string', '', 'Score') + oc('string', '', 'Joined') + oc('string', '', 'Active') + '</table:table-row>'
       + '<table:table-row>' + oc('string', '', 'Ada') + oc('float', '9.5', '9.5') + oc('date', '2023-05-01', '05/01/23') + oc('boolean', 'true', 'TRUE') + '</table:table-row>'
       + '<table:table-row>' + oc('string', '', 'Grace') + oc('float', '8', '8') + oc('date', '2022-11-20', '11/20/22') + oc('boolean', 'false', 'FALSE') + '<table:table-cell table:number-columns-repeated="1020"/></table:table-row>'
       + '<table:table-row table:number-rows-repeated="1048570"><table:table-cell table:number-columns-repeated="1024"/></table:table-row>'
       + '</table:table><table:table table:name="Other"><table:table-row>' + oc('percentage', '0.25', '25%') + '<table:covered-table-cell/>' + oc('string', '', 'after covered') + '</table:table-row></table:table>'
       + '</office:spreadsheet></office:body></office:document-content>')
write_zip(os.path.join(OUT, 'sample.ods'), [
    ('META-INF/manifest.xml', '<?xml version="1.0" encoding="UTF-8"?><manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2"><manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/><manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/></manifest:manifest>'),
    ('content.xml', ods),
], mimetype='application/vnd.oasis.opendocument.spreadsheet')

# --- Text clipping (data-fork property list with UTI-Data)
rtf = b'{\\rtf1\\ansi\\ansicpg1252\\cocoartf2822\n{\\fonttbl\\f0\\fswiss Helvetica;\\f1\\fswiss\\b Helvetica-Bold;}\n\\f0\\fs24 Clipped text with \\b bold\\b0  words.\\\nSecond line.}'
with open(os.path.join(OUT, 'sample.textclipping'), 'wb') as f:
    plistlib.dump({'UTI-Data': {'public.utf8-plain-text': 'Clipped text with bold words.\nSecond line.', 'public.rtf': rtf}}, f, fmt=plistlib.FMT_BINARY)

# --- RAR 4.x with stored entries (method 0x30), written from the published block layout.
def rar4(path, files):
    def crc16(b):
        return zlib.crc32(b) & 0xFFFF
    def dostime(t):
        lt = time.gmtime(t)
        return ((lt.tm_year - 1980) << 25) | (lt.tm_mon << 21) | (lt.tm_mday << 16) | (lt.tm_hour << 11) | (lt.tm_min << 5) | (lt.tm_sec // 2)
    out = bytearray(b'Rar!\x1a\x07\x00')
    main = struct.pack('<BHH', 0x73, 0, 13) + b'\x00' * 6
    out += struct.pack('<H', crc16(main)) + main
    ts = dostime(1704067200)
    for name, data in files:
        is_dir = data is None
        payload = b'' if is_dir else data
        nb = name.encode('ascii')
        flags = 0x8000 | (0x00E0 if is_dir else 0)
        mode = 0o40755 if is_dir else 0o100644
        fields = struct.pack('<IIBIIBBHI', len(payload), len(payload), 3, 0 if is_dir else (zlib.crc32(payload) & 0xffffffff), ts, 20, 0x30, len(nb), mode)
        head = struct.pack('<BHH', 0x74, flags, 7 + len(fields) + len(nb)) + fields + nb
        out += struct.pack('<H', crc16(head)) + head + payload
    end = struct.pack('<BHH', 0x7B, 0x4000, 7)
    out += struct.pack('<H', crc16(end)) + end
    with open(path, 'wb') as f:
        f.write(out)
rar4(os.path.join(OUT, 'sample.rar'), [('sample', None), ('sample/readme.txt', b'Hello from a RAR archive.\n'), ('sample/data', None), ('sample/data/numbers.csv', b'a,b\n1,2\n')])

# --- XLS: Excel 97-2003 BIFF8 workbook in an OLE2 compound file (version 3, 512-byte
# sectors), written from the published record/container layouts. The shared-string
# table is big enough to need CONTINUE records, with one string split across them.
def biff_rec(t, data):
    return struct.pack('<HH', t, len(data)) + data

def xl_ustr(s, length_bytes=2):
    wide = any(ord(ch) > 0xFF for ch in s)
    body = s.encode('utf-16-le') if wide else s.encode('latin-1')
    head = struct.pack('<B' if length_bytes == 1 else '<H', len(s)) + bytes([1 if wide else 0])
    return head + body

def sst_records(strings):
    MAX = 8224
    recs, cur = [], bytearray(struct.pack('<II', len(strings) + 3, len(strings)))
    rtype = 0x00FC
    def flush():
        nonlocal cur, rtype
        recs.append(biff_rec(rtype, bytes(cur)))
        cur, rtype = bytearray(), 0x003C
    for s in strings:
        wide = any(ord(ch) > 0xFF for ch in s)
        rest, size = s, (2 if wide else 1)
        if len(cur) + 3 + size > MAX:  # header plus at least one character stay together
            flush()
        cur += struct.pack('<H', len(s)) + bytes([1 if wide else 0])
        while rest:
            room = (MAX - len(cur)) // size
            if room <= 0:
                flush()
                cur += bytes([1 if wide else 0])  # continued characters restate the option byte
                continue
            part, rest = rest[:room], rest[room:]
            cur += part.encode('utf-16-le' if wide else 'latin-1')
    if cur or rtype == 0x00FC:
        flush()
    return b''.join(recs)

def rk_int(v):
    return struct.pack('<I', ((v << 2) | 0x02) & 0xFFFFFFFF)

def xf(fmt, style):
    flags = 0xFFF5 if style else 0x0001
    return biff_rec(0x00E0, struct.pack('<HHHBBBBIIH', 0, fmt, flags, 0x20, 0, 0, 0 if style else 0xF8, 0, 0, 0x20C0))

shared_xls = ['Name', 'Amount', 'Count', 'Date', 'Active', 'Doubled', 'Label']
shared_xls += ['Item %03d' % k for k in range(400)]
shared_xls += ['Zoë café – ünïcødé', 'L' + 'o' * 6000 + 'ng']
sst = sst_records(shared_xls)
def sidx(s):
    return shared_xls.index(s)

def sheet_stream(rows_fn):
    return biff_rec(0x0809, struct.pack('<HHHHII', 0x0600, 0x0010, 0x0DBB, 0x07CC, 0x41, 6)) + rows_fn() + \
        biff_rec(0x023E, struct.pack('<HHHHHHHHH', 0x06B6, 0, 0, 0x40, 0, 0, 0, 0, 0)) + biff_rec(0x000A, b'')

def data_rows():
    out = biff_rec(0x0200, struct.pack('<IIHHH', 0, 302, 0, 7, 0))
    out += b''.join(biff_rec(0x00FD, struct.pack('<HHHI', 0, c, 15, sidx(n))) for c, n in enumerate(['Name', 'Amount', 'Count', 'Date', 'Active', 'Doubled', 'Label']))
    for r in range(1, 301):
        out += biff_rec(0x00FD, struct.pack('<HHHI', r, 0, 15, sidx('Item %03d' % (r - 1))))
        out += biff_rec(0x0203, struct.pack('<HHHd', r, 1, 15, r * 1.5))
        out += biff_rec(0x027E, struct.pack('<HHH', r, 2, 15) + rk_int(r * 10))
        out += biff_rec(0x0203, struct.pack('<HHHd', r, 3, 16, 45366.0 + r))      # dates, custom yyyy-mm-dd
        out += biff_rec(0x0205, struct.pack('<HHHBB', r, 4, 15, r % 2, 0))
        out += biff_rec(0x0006, struct.pack('<HHHdHIH', r, 5, 15, r * 3.0, 0, 0, 3) + bytes([0x1E]) + struct.pack('<H', r * 3))
        if r == 1:  # string formula result + following STRING record
            out += biff_rec(0x0006, struct.pack('<HHH', r, 6, 15) + bytes([0, 0, 0, 0, 0, 0, 0xFF, 0xFF]) + struct.pack('<HIH', 0, 0, 3) + bytes([0x1E, 1, 0]))
            out += biff_rec(0x0207, xl_ustr('from formula'))
        elif r == 2:
            out += biff_rec(0x0204, struct.pack('<HHH', r, 6, 15) + xl_ustr('inline label'))
    # One MULRK row and the non-ASCII + long shared strings.
    out += biff_rec(0x00BD, struct.pack('<HH', 301, 1) + struct.pack('<H', 15) + rk_int(7) + struct.pack('<H', 15) + struct.pack('<I', 0x3FF00000) + struct.pack('<H', 2))  # cells at cols 1-2
    out += biff_rec(0x00FD, struct.pack('<HHHI', 301, 0, 15, sidx('Zoë café – ünïcødé')))
    out += biff_rec(0x00FD, struct.pack('<HHHI', 301, 6, 15, sidx(shared_xls[-1])))
    return out

def notes_rows():
    return biff_rec(0x0200, struct.pack('<IIHHH', 0, 2, 0, 1, 0)) + biff_rec(0x0204, struct.pack('<HHH', 0, 0, 15) + xl_ustr('Notes sheet')) + \
        biff_rec(0x0204, struct.pack('<HHH', 1, 0, 15) + xl_ustr('Ünïcødé note'))

font = biff_rec(0x0031, struct.pack('<HHHHHBBBB', 200, 0, 0x7FFF, 400, 0, 0, 0, 0, 0) + xl_ustr('Arial', 1))
def globals_stream(offsets):
    g = biff_rec(0x0809, struct.pack('<HHHHII', 0x0600, 0x0005, 0x0DBB, 0x07CC, 0x41, 6))
    g += biff_rec(0x0042, struct.pack('<H', 1200))
    g += biff_rec(0x003D, struct.pack('<HHHHHHHHH', 0, 0, 0x3000, 0x1E00, 0x38, 0, 0, 1, 0x258))
    g += biff_rec(0x0022, struct.pack('<H', 0))
    g += font * 5
    g += biff_rec(0x041E, struct.pack('<H', 164) + xl_ustr('yyyy-mm-dd'))
    g += b''.join(xf(0, True) for _ in range(15)) + xf(0, False) + xf(164, False)
    g += biff_rec(0x0293, struct.pack('<HBB', 0x8000, 0, 0xFF))
    for name, off in zip(['Data', 'Notes'], offsets):
        g += biff_rec(0x0085, struct.pack('<IBB', off, 0, 0) + xl_ustr(name, 1))
    g += sst
    g += biff_rec(0x000A, b'')
    return g

sheets_xls = [sheet_stream(data_rows), sheet_stream(notes_rows)]
base_len = len(globals_stream([0, 0]))
offsets = [base_len, base_len + len(sheets_xls[0])]
workbook = globals_stream(offsets) + b''.join(sheets_xls)

def compound_file(name, stream):
    SECT = 512
    data = stream + b'\x00' * ((-len(stream)) % SECT)
    n_stream, n_dir = len(data) // SECT, 1
    n_fat = 1
    while n_fat * 128 < n_fat + n_dir + n_stream:
        n_fat += 1
    fat = [0xFFFFFFFD] * n_fat + [0xFFFFFFFE]
    start = n_fat + n_dir
    fat += [start + k + 1 if k < n_stream - 1 else 0xFFFFFFFE for k in range(n_stream)]
    fat += [0xFFFFFFFF] * (n_fat * 128 - len(fat))
    header = bytearray(512)
    header[0:8] = b'\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1'
    struct.pack_into('<HHHHH', header, 24, 0x003E, 0x0003, 0xFFFE, 9, 6)
    struct.pack_into('<IIIIIIII', header, 44, n_fat, n_fat, 0, 4096, 0xFFFFFFFE, 0, 0xFFFFFFFE, 0)
    for k in range(109):
        struct.pack_into('<I', header, 76 + 4 * k, k if k < n_fat else 0xFFFFFFFF)
    def dirent(nm, typ, first, size, child=0xFFFFFFFF):
        e = bytearray(128)
        enc = (nm + '\x00').encode('utf-16-le') if nm else b''
        e[0:len(enc)] = enc
        struct.pack_into('<HBB', e, 64, len(enc), typ, 1)
        struct.pack_into('<III', e, 68, 0xFFFFFFFF, 0xFFFFFFFF, child)
        struct.pack_into('<II', e, 116, first, size)
        return bytes(e)
    directory = dirent('Root Entry', 5, 0xFFFFFFFE, 0, child=1) + dirent(name, 2, start, len(stream)) + dirent('', 0, 0, 0) * 2
    return bytes(header) + b''.join(struct.pack('<I', v) for v in fat) + directory + data

with open(os.path.join(OUT, 'sample.xls'), 'wb') as f:
    f.write(compound_file('Workbook', workbook))
with open(os.path.join(OUT, 'edge-html-table.xls'), 'w') as f:
    f.write('<html><body><table><tr><th>City</th><th>Pop</th></tr><tr><td>Oslo</td><td>709000</td></tr></table></body></html>')

# --- Edge archives: path traversal attempts (must never escape the extraction folder).
with zipfile.ZipFile(os.path.join(OUT, 'edge-zipslip.zip'), 'w') as z:
    z.writestr('../evil.txt', 'should never be written outside')
    z.writestr('safe/ok.txt', 'fine')
with tarfile.open(os.path.join(OUT, 'edge-zipslip.tar'), 'w') as t:
    for name, data in (('../evil.txt', b'outside'), ('/tmp/anyfmt-absolute-evil.txt', b'absolute'), ('safe/ok.txt', b'fine')):
        info = tarfile.TarInfo(name)
        info.size = len(data)
        info.mtime = 1704067200
        t.addfile(info, io.BytesIO(data))
PY

# --- Markdown with every construct the reader handles
cat > "$OUT/sample.md" <<'MD'
---
title: anyfmt Markdown Sample
author: anyfmt Fixtures
---

# anyfmt Markdown Sample

A paragraph with **bold**, *italic*, ***both***, ~~strikethrough~~, `inline code`,
a [link](https://example.org "Example") and an autolink <https://anyfmt.example/>.
Hard break here\
next line.

Setext heading
--------------

## Lists

- First item
- Second item with *emphasis*
  - Nested item
  - Another nested
    1. Deep ordered
- [x] Done task
- [ ] Open task

3. Third
4. Fourth

## Table

| Fruit  | Colour | Price |
|:-------|:------:|------:|
| Apple  | Red    | 1.20  |
| Banana | Yellow | 0.50  |

> A blockquote with **strong** text.
>
> Second quote paragraph.

```swift
let greeting = "Hello"
print(greeting)
```

    indented code block

![A gradient figure](docs-figure.png)

Escapes: \*not emphasis\* and 5 \< 6 &amp; 7.

***

Final paragraph with a footnote-style ref [example][ex].

[ex]: https://example.com/ref
MD

# --- Rich semantic HTML (also the textutil source for doc/odt/rtf/rtfd/webarchive)
cat > "$OUT/sample.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>anyfmt HTML Sample</title><meta name="author" content="anyfmt Fixtures"></head>
<body>
<h1>anyfmt HTML Sample</h1>
<p>A paragraph with <b>bold</b>, <i>italic</i>, <u>underline</u> and a <a href="https://example.org/">link</a>. Ünïcødé café.</p>
<h2>Lists</h2>
<ul><li>First bullet</li><li>Second bullet<ul><li>Nested bullet</li></ul></li></ul>
<ol><li>Step one</li><li>Step two</li></ol>
<h2>Table</h2>
<table border="1"><thead><tr><th>Fruit</th><th>Colour</th><th>Price</th></tr></thead>
<tbody><tr><td>Apple</td><td>Red</td><td>1.20</td></tr><tr><td>Banana</td><td>Yellow</td><td>0.50</td></tr></tbody></table>
<p><img src="docs-figure.png" alt="A gradient figure" width="96" height="64"></p>
<blockquote><p>A quoted paragraph.</p></blockquote>
<pre><code>let x = 1
print(x)</code></pre>
<hr>
<p>The end.</p>
</body>
</html>
HTML

cat > "$OUT/sample.txt" <<'TXT'
anyfmt Plain Text Sample

This is the first paragraph of plain text. It has two sentences.
A second line in the same paragraph.

Second paragraph with Ünïcødé: café, naïve, 日本語.
TXT

( cd "$OUT"
  textutil -convert doc sample.html -output sample.doc
  textutil -convert odt sample.html -output sample.odt
  textutil -convert rtf sample.html -output sample.rtf
  rm -rf sample.rtfd && textutil -convert rtfd sample.html -output sample.rtfd
  textutil -convert webarchive sample.html -output sample.webarchive
  textutil -convert docx sample.html -output edge-textutil.docx
)

# --- Spreadsheets (text formats)
printf 'Name,Amount,Date,Note\r\n"Smith, Jane",1234.5,2024-03-15,"Said ""hi"""\r\nZoë,007,2024-04-01,"Line one\nline two"\r\nBob,-12,2024-05-20,plain\r\n' > "$OUT/sample.csv"
printf 'Name\tAmount\tActive\nAda\t9.5\tTRUE\nGrace\t8\tFALSE\n' > "$OUT/sample.tsv"
printf 'Name;Amount\nAda;9,5\nGrace;8\n' > "$OUT/edge-semicolon.csv"
cat > "$OUT/sample.json" <<'JSON'
[
  {"name": "Ada", "score": 9.5, "active": true, "joined": "2023-05-01", "tags": ["math", "engines"]},
  {"name": "Grace", "score": 8, "active": false, "joined": "2022-11-20", "extra": null},
  {"name": "Linus", "score": 7.25, "active": true, "joined": "2021-01-02", "address": {"city": "Helsinki"}}
]
JSON

# --- Folder + archives
rm -rf "$OUT/sample-folder"
mkdir -p "$OUT/sample-folder/sub dir/deep"
printf 'Read me first.\n' > "$OUT/sample-folder/Read Me.txt"
printf '# Notes\n\nÜnïcødé file name.\n' > "$OUT/sample-folder/Ünïcødé – notes.md"
printf 'a,b\n1,2\n' > "$OUT/sample-folder/sub dir/data.csv"
cp "$OUT/docs-figure.png" "$OUT/sample-folder/sub dir/deep/pixel.png"

mkdir -p "$TMP/arch"
ditto "$OUT/sample-folder" "$TMP/arch/sample"
printf 'Plain notes inside a gzip.\n' > "$TMP/notes.txt"
rm -f "$OUT/sample.zip" "$OUT/sample.tar" "$OUT/sample.gz" "$OUT/sample.7z" "$OUT/edge-bundle.tgz"
ditto -c -k --sequesterRsrc --keepParent "$TMP/arch/sample" "$OUT/sample.zip"
/usr/bin/bsdtar --no-mac-metadata -cf "$OUT/sample.tar" -C "$TMP/arch" sample
/usr/bin/bsdtar --no-mac-metadata -czf "$OUT/edge-bundle.tgz" -C "$TMP/arch" sample
/usr/bin/bsdtar --no-mac-metadata --format 7zip -cf "$OUT/sample.7z" -C "$TMP/arch" sample
/usr/bin/gzip -c -9 "$TMP/notes.txt" > "$OUT/sample.gz"

echo "docs fixtures ok"
