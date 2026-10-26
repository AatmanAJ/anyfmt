# Lane F: documents, slides, spreadsheets, EPUB, archives

Status: **done**. 165 direct rows + 43 router-derived options = **208 shipped
options**, all passing the lane-local matrix on generated fixtures (≈ 6 s for
the whole set). 52 more rows are opt-in (iWork) or need an optional pack
(LibreOffice, pandoc) and are excluded from the shipped count. Everything is our
own Swift on Apple frameworks and system tools: no third-party code, nothing
bundled, zero bytes added to the app.

## What was built

All under `Sources/Engine/Docs/` and `Sources/Engine/Archive/` (~9.2k lines),
tests under `Tests/Unit/Core/Docs/` and `Tests/Unit/Core/Archive/` (~1.4k lines).

| Area | Files | Public API |
|---|---|---|
| ZIP | `Zip/CRC32.swift`, `Deflate.swift`, `ZipReader.swift`, `ZipWriter.swift` | `ZipReader(url:/data:)` (ZIP64 read, CRC check, UTF-8/CP437 names, case-insensitive lookup, `safeDestination` zip-slip guard, `extractAll`), `ZipWriter` (deflate/stored, UTF-8 flag, deterministic timestamps, entry order kept for `mimetype`-first), `Deflate`/`DeflateStream` (Compression framework raw DEFLATE), `CRC32` |
| XML | `Support/XMLTree.swift` | `XNode` (Sendable tree), `XMLTree.parse` (strict, SAX), `parseHTML` (HTML Tidy via `XMLDocument`, off-main safe), `parseXHTML`; `TextDecoding`, `XMLEscape` |
| Model | `Model/DocModel.swift` | `DocModel`, `DocBlock` (heading, paragraph, list, table, image, codeBlock, blockquote, horizontalRule, pageBreak), `DocInline` (text, emphasis, strong, underline, strikethrough, code, link, image, lineBreak), `DocMetadata` |
| Readers | `Readers/*.swift` | `MarkdownReader`, `HTMLReader` (+ `PlainTextReader`), `DOCXReader`, `ODTReader`, `AttributedReader` (RTF/RTFD/DOC), `WebArchiveReader`, `TextClippingReader`, `EPUBReader`, `PDFDocReader` (+ `PDFImageExtractor`), shared `FlowAssembler` |
| Writers | `Writers/*.swift` | `DOCXWriter`, `ODTWriter`, `HTMLWriter` (web / print / XHTML flavours), `MarkdownWriter`, `PlainTextWriter`, `AttributedWriter` (RTF/RTFD), `EPUBWriter` |
| PDF | `PDF/WebPDFRenderer.swift` | `WebPDFRenderer.render(html:/fileURL:…)`, `PageSetup` |
| Slides | `Slides/PPTXWriter.swift`, `QuickLookEngine.swift` | `PPTXWriter` (PDF → slides), `PDFRaster` (page → image, `writePages`), `QuickLookEngine` |
| Sheets | `Sheets/*.swift` | `Workbook`/`Sheet`/`Cell`, `JSONValue` (order-preserving), `XLSXReader` (streaming SAX worksheets)/`XLSXWriter`, `XLSReader` (BIFF8) + `CompoundFile` (OLE2), `ODSReader`/`ODSWriter`, `CSVReader`/`DelimitedWriter`, `JSONTable`/`JSONTableWriter`, `SheetHTMLWriter`, `PDFTableExtractor`, `SheetIO` |
| Packs / iWork | `Packs/Packs.swift`, `Packs/IWorkEngine.swift` | `PackSpec`, `OfficePack.spec`, `PandocPack.spec`, `PackInstaller` (verify SHA-256 → install from a local DMG/zip), `PackSystem` (injectable), `OfficePackEngine`, `PandocPackEngine`, `PagesAppleEventsEngine` |
| Facade, engines, rows | `DocumentIO.swift`, `DocsEngines.swift`, `DocsRoutes.swift`, `Archive/ArchiveEngine.swift`, `ArchiveRoutes.swift`, `ArchiveEngines.swift` | `DocumentIO.read/write`, `DocsSchemas`, `DocsOptionKey`, engines below, `Gzip` |

Engines registered (`DocsEngines.all` + `ArchiveEngines.all`): `MarkdownEngine`
(md/txt/html out), `OOXMLEngine` (docx/odt out, pdf→pptx, pdf→xlsx),
`EPUBEngine`, `WebKitPDFEngine`, `AttributedTextEngine` (rtf/rtfd out; native
RTF/RTFD/DOC → RTF/RTFD keeps fonts and colours), `TextClippingEngine`,
`SheetsEngine`, `QuickLookEngine`, `PagesAppleEventsEngine`, `OfficePackEngine`,
`PandocPackEngine`, `ArchiveEngine`.

## Routes shipped (count by family) and quality grades

Grades: **A** = structure and content survive; **B** = content survives,
some structure inferred or approximated; **C** = not good enough to ship.

| Family | Direct rows | Grade | Notes |
|---|---:|---|---|
| Documents: DOCX ODT MD TXT HTML RTF RTFD DOC WebArchive Clipping EPUB → DOCX ODT MD TXT HTML RTF RTFD EPUB PDF | 91 | **A−** model-based; **A** RTF/RTFD/DOC→RTF/RTFD (AppKit native) | Headings, nested lists, tables (header rows), links, images, code, quotes, page breaks, title/author/lang. Lost by design: fonts, colours, exact spacing. DOCX input also: numbering → lists, HYPERLINK fields, footnotes (appended as a numbered list), text boxes, content controls, tracked insertions; textutil-style DOCX (bold big runs, "\t•\t" bullets) recovered by heuristics |
| → PDF (WebKit, A4/Letter, 54 pt margins) | (in the 91) | **A−** | Paginated, CSS page breaks, repeating table headers, text bullets, Helvetica Neue. Reflowed, not Word's page layout (the Office pack gives that). HTML and web archives render with their own CSS |
| PDF → DOCX ODT MD HTML RTF RTFD EPUB | 7 | **B** | Paragraphs rebuilt from line geometry, headings by relative size (+ bold short lines), lists from bullets/numbers, **tables from word positions**, embedded raster images placed where they sit, running heads/page numbers dropped, paragraphs split by page breaks rejoined, link annotations kept, **scanned pages OCR'd with Vision on device**. Inline bold/italic only when PDFKit reports real font names (true for installed fonts; embedded exotic fonts come back as Times). Multi-column magazines and forms are B−/C territory |
| PDF → PPTX | 1 | **B** | One slide per page, page rendered at 2400 px on the long edge, slide = page aspect. Pictures, not editable text |
| PDF → XLSX | 1 | **B** on tabular PDFs | Grid from word positions and x-coverage column bands; numbers with thousands separators/currency become numeric cells; text outside tables becomes one-cell rows. Verified exact on a 4×5 table. Merged cells and ruled-but-irregular tables are weaker |
| Slides: PPTX → PDF PNG JPG (Quick Look) | 3 | **B** | Same fidelity as Finder's Quick Look (positioned text boxes, pictures, slide aspect kept, one page/image per slide). Charts, SmartArt and some theme art can be missing → Office pack wins at priority 110 vs 40 when installed |
| Sheets: XLSX XLS ODS CSV TSV JSON → XLSX ODS CSV TSV JSON HTML PDF | 37 | **A** (PDF/HTML **A−**; XLS **A−**) | Typed cells (number/bool/date/date-time/text), shared + inline strings, cached formula values, numFmt date detection, multiple sheets, sparse cells, ODS repeat compression (a million empty rows trimmed), RFC 4180 CSV with delimiter sniffing (`,` `;` tab `|`) and decimal-comma for `;`, order-preserving JSON. XLSX out: bold frozen header, ISO date formats, column widths. `sheet` = first/all (one file per sheet). PDF: landscape when wide |
| Archives: ZIP TAR GZ RAR 7z + folder → ZIP TAR GZ 7z + folder | 25 | **A** | Folder(s) → archive is `.combine` (multi-drag → one archive). Unicode/space names, names starting with `-`, `__MACOSX` dropped, single top folder unwrapped when it repeats the archive name, layout preserved on archive→archive |
| XLS input (part of the 37 above) | 7 | **A−** | Own OLE2 container reader (v3/v4 sectors, DIFAT, mini stream) and BIFF8 parser: SST with CONTINUE splits, LABELSST/LABEL/RSTRING, NUMBER, RK/MULRK, BOOLERR, cached FORMULA results incl. STRING records, XF → FORMAT date detection, 1904 dates, FILEPASS (encrypted) refused. HTML tables saved as `.xls` read as HTML. Not read: BIFF5/BIFF7 (Excel 95), charts, formatting |

Router-derived (lane F alone): 43 — spreadsheets → HTML → DOCX/ODT/MD/TXT/RTF/
RTFD/EPUB (42, tables in documents) and PDF → DOCX → TXT (1; lane D's direct
PDF → TXT supersedes it in the merged table). Rendered-PDF rows are
`.terminalOnly`, so the router never plans silly detours like DOCX → PDF → XLSX.

Not in the shipped count (flagged rows, need the user to act):
iWork opt-in 13 (`.optIn`), Office pack 33 and pandoc pack 6 (`.needsPack`).
For XLS → XLSX/ODS/CSV/PDF the Office pack (priority 110) takes over from our
reader (100) when installed.

## Decisions (ready for DECISIONS.md)

- **D-F01 Own document model and writers.** N readers × M writers through
  `DocModel`; no intermediate files, no pandoc by default (D-022). Zero size.
- **D-F02 ZIP on the Compression framework.** `COMPRESSION_ZLIB` is raw DEFLATE,
  exactly ZIP method 8 / gzip. Own CRC-32 (slicing-by-4). ZIP64 read support.
- **D-F03 AppKit's DOCX importer is never our DOCX reader.** Verified on macOS 27
  with textutil: it ignores `styles.xml` entirely and drops hyperlinks in every
  form (`w:hyperlink`, `fldSimple`, complex fields) and images. Our DOCX writer
  therefore also puts direct bold + size on heading runs so TextEdit/textutil
  users still see the hierarchy; Word/Pages/LibreOffice use the real styles.
- **D-F04 WebKit print completion arrives on AppKit's print thread.** The
  `runModal(for:)` callback is delivered on a background `NSThread`, so it goes
  to a non-isolated delegate (Swift 6 traps otherwise). Renders are serialised
  on the main actor. **No network**: JS off, ephemeral data store, content rules
  blocking `http(s)`/`ws(s)`/`ftp`/`blob` (one rule per scheme: WebKit rule
  regexes have no alternation), non-local navigations cancelled, print HTML
  never references remote images.
- **D-F05 Print CSS uses Helvetica Neue and text bullets.** With the system UI
  font, PDFKit reads every run back as Times; with Helvetica Neue it reports
  real names including Bold, so PDF → DOCX keeps inline bold. WebKit paints
  disc bullets as shapes; `::before` text bullets make our PDFs' bullets
  copyable and re-readable.
- **D-F06 Rendered PDFs are terminal.** All X → PDF rows are `.terminalOnly`.
- **D-F07 Quick Look slides at priority 40, Office pack 110.** `qlmanage -p -o`
  is a debug tool; it's used behind a check that a `Preview.html` with
  `div.slide` came back, with a 90 s timeout. Page size is read from the
  preview's `div.slide` size (fallback: `p:sldSz`); orientation is derived from
  the paper, because NSPrintInfo swaps width/height to match it.
- **D-F08 iWork via `/usr/bin/osascript`**, not `NSAppleScript` on the main
  thread: off-main, cancellable, the Automation prompt still names anyfmt.
  Default off (`optIn.iWorkAppleEvents`), requires the app installed. Never run
  in tests (script generation and availability are tested with a fake environment).
- **D-F09 Archives:** `ditto -c -k --sequesterRsrc [--keepParent]` for ZIP
  (Finder-faithful; `--keepParent` only for folders: for a file it embeds the
  parent folder's name), `bsdtar --format pax --no-mac-metadata` for TAR,
  `bsdtar -z` for TAR.GZ, `bsdtar --format 7zip` (LZMA2) for 7z, member names
  passed NUL-separated via `-T` so no name is parsed as an option, own streaming
  gzip for a single file. Extraction: `bsdtar -x --no-same-owner` into a fresh
  folder. Verified bsdtar 3.5.3/libarchive 3.7.4 defaults: refuses `..`
  members, strips leading `/` (exit 1 with "Path contains '..'" is treated as a
  partial success after checking stderr holds only refusals). Password-protected
  archives get a clear message.
- **D-F10 RAR fixture without third-party files.** `docs.sh` writes a RAR 4.x
  archive with stored entries from the published block layout (marker, main
  header, file headers with CRC16-of-CRC32, end block); `bsdtar` lists and
  extracts it. Nothing committed under `Tests/Fixtures/static/`.
- **D-F11 pandoc pack limited to DOCX/ODT/EPUB ↔ DOCX/ODT/EPUB.** pandoc fetches
  remote images found in Markdown/HTML inputs; package inputs carry their own
  media, so the no-network rule holds. Pinned values mirror `Engines/versions.env`
  (a unit test enforces it). Install uses `ditto -x -k --noqtn` after the SHA-256
  check (the browser's quarantine would otherwise block the CLI binary).
- **D-F12 Office pack pinned to LibreOffice 26.8.1 (MPL-2.0), SHA-256 unset.**
  `PackInstaller` refuses to install until a release engineer fills
  `OfficePack.spec.sha256` (see Blockers). Install = verify → `hdiutil attach
  -nobrowse -readonly` → `ditto LibreOffice.app` → detach → atomic replace.
  Conversions run `soffice --headless` with a per-job `-env:UserInstallation`
  profile so a running LibreOffice or a first-run dialog never interferes.
- **D-F13 CSV:** RFC 4180 (CRLF, doubled quotes, quoting for delimiters,
  quotes, newlines and edge spaces), UTF-8 without BOM by default (`bom` option).
  Type inference keeps `007` and >15-digit numbers as text, ambiguous `01/02/2024`
  dates as text, ISO dates as dates.
- **D-F14 Dates** are wall-clock values stored as UTC; Excel serials use the
  1900 system (1904 flag honoured); text output is ISO 8601.
- **D-F15 PDF reconstruction OCR** uses `VNRecognizeTextRequest` (accurate,
  on device, macOS 10.15+) only for pages without a text layer; the page scan is
  then not kept as a figure.
- **D-F16 Markdown output embeds images as data URIs** by default (single file,
  lossless); `images=omit` option leaves alt text. Front matter carries title/author.
  GFM footnotes become `[n]` markers plus a numbered notes list.
- **D-F17 Own XLS (BIFF8) reader.** Legacy workbooks are common and the only
  alternative was the Office pack. The fixture is written by `docs.sh` from the
  published OLE2/BIFF8 layouts and is checked by Apple's Office Quick Look
  generator in `OfficeInteropTests` (which caught a malformed MULRK during
  development), so writer and reader can't share a misunderstanding unnoticed.
- **D-F18 Big-file paths:** CSV parsed as UTF-8 bytes; number/ISO-date inference
  and date formatting hand-written (civil-day maths) instead of regex/DateFormatter;
  XLSX worksheets streamed with SAX (no XML tree).

## Tests

`CoreTests` (AnyfmtCoreTests): 73 tests in the lane F classes, 89 with the two
existing suites, all green in 12.5 s (`xcodebuild … test -only-testing:CoreTests`).
The Debug `anyfmt-matrix` skeleton prints `routes: 208` in this worktree.

| Class | What it covers |
|---|---|
| `ZipTests` | CRC-32 vectors, deflate round trip (repetitive/random/empty), writer→reader incl. unicode + `unzip -t`, determinism, CRC corruption detection, hand-built ZIP64 archive, zip-slip (`safeDestination` + a python-made malicious zip) |
| `MarkdownTests` | ATX/setext, delimiter rules (`***x***`, intraword `_`/`*`, spaced `*`), code spans, inline/reference/collapsed/shortcut links, autolinks, bare URLs, escapes/entities, hard/soft breaks, nested/ordered/task lists, fences/indented code, quotes, GFM tables, front matter, raw HTML blocks, writer round trip, fixture |
| `DocumentFormatTests` | DOCX package parts well-formed, DOCX round trip (headings, nested ordered list, start numbers, table header, image size, link, bold/italic/code, code block, quote), AppKit DOCX import (table, list, heading size), fixture DOCX + textutil heuristics, ODT rules + round trip + AppKit import, HTML semantics + messy HTML, HTML writer safety, RTF/RTFD, DOC/RTFD/webarchive/clipping fixtures, EPUB writer structure (OCF/OPF/nav/NCX checks), EPUB fixture spine order, TXT writer |
| `SheetTests` | Cell inference, CSV edge cases + sniffing, RFC 4180 writer, XLSX/ODS round trips (types, dates, date-times, newlines, padding), XLSX fixture (shared/inline strings, cached formula, sparse rows), XLS BIFF8 fixture (every record type above, CONTINUE split, UTF-16, MULRK, HTML-as-.xls), RK decoding, ODS repeats, JSON order + escapes/surrogates, HTML/PDF tables, `sheet=all` |
| `PDFRouteTests` | WebKit pagination (>1 page, A4/Letter sizes), CSS page breaks, no remote refs in print HTML, PDF→DOCX headings/lists/images/bold/paragraph joining, PDF→PPTX slide count + aspect, PDF table extraction (exact grid) and tables in PDF→document, Vision OCR of a scanned page |
| `ArchiveTests` | Folder → ZIP/TAR/GZ/7z → folder (unicode/space names, top folder unwrapped), multi-input combine incl. `-dash` names, RAR/7z/gzip extraction, archive→archive layout, path traversal never escapes, streaming gzip vs `/usr/bin/gzip -t` |
| `SlidesAndPackTests` | Quick Look PPTX → PDF (3 pages, 16:9) and PNG (3 files), slide-size parsing, pack installer with a fake system (unpinned refusal, checksum mismatch, install, reinstall, zip layout, permissions, uninstall), pandoc pin = versions.env, pack availability/priorities, iWork opt-in gating and AppleScript generation |
| `OfficeInteropTests` | Apple's Office Quick Look generator renders our DOCX (table, image, nested list), XLSX (dates as ISO) and PPTX (every slide), and accepts the generated XLS fixture |
| `RobustnessTests` | Truncated / bit-flipped / empty / random variants of every fixture through every reader (must throw or degrade, never trap), pathological Markdown nesting, hostile ODS repeat counts, corrupt PDFs; 200k-row CSV → XLSX → read back; 20-page PDF reconstruction speed |
| `DocsRouteMatrixTests` | Lane table integrity, then **every shipped route (208) on its fixture**, output opened and checked (DOCX via our reader + AppKit, OCF rules for EPUB/ODT, PDF must have text, archives listed by bsdtar, images decoded…) |

Perf (M5 Max, Debug): whole lane matrix, 208 routes, in ≈ 6 s. WebKit PDF ≈ 0.1–0.3 s
per document after the first (≈ 0.6 s cold); Quick Look PPTX → PDF ≈ 0.15 s;
PDF → DOCX for a 3-page PDF ≈ 0.2 s; OCR ≈ 0.3 s per scanned page.
200 000-row × 5-column CSV: parse 0.75 s, XLSX write 0.8 s, XLSX read 2.4 s (Debug;
byte-level CSV parser, hand-written number/ISO-date inference, streaming SAX for
worksheet parts). Verified from a plain command-line process (async `main`) as
well as XCTest.

## Fixtures (`Tests/Fixtures/lanes/docs.sh`, ~2 s)

Generated, never committed: `sample.{md,html,txt,docx,doc,odt,rtf,rtfd/,webarchive,
textclipping,epub,pptx,xlsx,ods,csv,tsv,json,zip,tar,gz,7z,rar}`, `sample-folder/`
(spaces + unicode names, nested), plus `docs-figure.png`, `edge-textutil.docx`,
`edge-semicolon.csv`, `edge-bundle.tgz`, `edge-zipslip.{zip,tar}`, `edge-html-table.xls`,
and `sample.xls` (BIFF8 in OLE2, 302 rows, shared strings split across CONTINUE records). Tools: textutil,
ditto, bsdtar, gzip and `/usr/bin/python3 -I` (stdlib only) for the zip-based
formats and RAR. `sample.pdf` comes from lane D in the merged build (my tests
make their own PDFs).

## Not shipped / gaps for PARITY.md

| Gap | Why | What it would take |
|---|---|---|
| PAGES / KEY / NUMBERS read & write without the apps | Proprietary IWA (protobuf + Snappy) format; no fixture without iWork | Opt-in rows exist (needs app + Settings toggle); LibreOffice pack imports iWork (libetonyek). A native IWA reader is a large project |
| Documents / PDF → PAGES | Same | Opt-in route DOCX → Pages via AppleScript (PDF → DOCX → Pages is 2 hops) |
| PPT (legacy binary), ODP, KEY → PDF/images | No fixture can be generated here (no Office/LibreOffice/Keynote); Quick Look has no ODP generator (ODT produced nothing) | Office pack rows (`.needsPack`, ready); or an own PPT reader (the OLE2 reader is reusable) |
| Excel 95 (BIFF5/7) .xls | Rare; BIFF8 only | Extend `XLSReader` (byte strings, BOUNDSHEET/LABEL differences) |
| Numbers via Quick Look HTML tables | Can't fixture Numbers | `QuickLookEngine.preview` + `XLSReader.htmlWorkbook`; ~20 lines once a fixture exists |
| Slides with charts/SmartArt/theme art → PDF/PNG | Quick Look approximations | Office pack (LibreOffice) |
| Editable PPTX from PDF | Pages become pictures | Positioned text boxes from PDF line geometry (the PDF reader already has it) |
| Inline bold/italic from PDFs with unknown embedded fonts | PDFKit maps unknown fonts to Times | Read font names from the CGPDF font resources while scanning text operators |
| Any single file → ZIP/GZIP on the wheel | Not a format conversion; engine supports it (multi-input combine, `name.ext.gz`) | One `Capability.grid` over all formats if product wants it (+ contract change 1 for `.ext.gz` naming) |
| RAR/encrypted archive creation, password archives | RAR is proprietary; passwords unsupported by design (clear error) | — |
| `epubcheck` validation | Needs Java + network | Structural OCF/OPF checks are in the tests |
| Word / Pages / LibreOffice / PowerPoint / Excel open-checks | Apps not installed here | See Blockers; Apple's Office Quick Look generator and AppKit already read our files |

## Contract change requests

Details in `docs/contract-changes/F-docs.md`:
1. `OutputPlacer.ext` should keep `notes.txt.gz` (inner extension) for single-file gzip.
2. Matrix runner / CLI must keep an async `main` (WebKit and Quick Look engines need the main run loop).
3. Rebuild the cached router when a pack is installed or the iWork opt-in changes.
4. Settings hooks for the packs and the iWork toggle (information).

## Observation for the orchestrator (not lane F code)

The **Release** `anyfmt-matrix` (hardened runtime, ad-hoc signed) fails to load the
ad-hoc signed `AnyfmtCore.framework`: dyld reports "mapping process and mapped file
(non-platform) have different Team IDs" (library validation). The Debug build
runs. `make matrix` builds Release, so Phase 4 needs either the same signing
identity for both, `com.apple.security.cs.disable-library-validation` on the
matrix/CLI tools, or no hardened runtime for these test tools.

## Blockers needing a human

1. **Office pack checksum.** Download
   `https://download.documentfoundation.org/libreoffice/stable/26.8.1/mac/aarch64/LibreOffice_26.8.1_MacOS_aarch64.dmg`
   (or the current stable), verify its `.asc` with The Document Foundation's key,
   then `shasum -a 256 LibreOffice_26.8.1_MacOS_aarch64.dmg` and put the value
   (and version/URL if changed) into `OfficePack.spec` in
   `Sources/Engine/Docs/Packs/Packs.swift`. Until then the installer refuses.
2. **Open-checks in real apps.** Open `make fixtures` outputs of md/html → DOCX,
   ODT, XLSX, PPTX (PDF → PPTX), EPUB in Word, Pages, LibreOffice, PowerPoint,
   Excel, Keynote, Numbers and Apple Books; report any "repair" prompt.
3. **iWork opt-in end to end.** With Pages/Keynote/Numbers installed:
   `defaults write app.anyfmt optIn.iWorkAppleEvents -bool YES`, then run a
   Pages → PDF and DOCX → Pages conversion and accept the Automation prompt once.
