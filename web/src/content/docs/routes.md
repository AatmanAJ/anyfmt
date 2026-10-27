---
title: How routes work
description: How anyfmt plans a conversion from one format to another, why some routes are hidden from the wheel, which engines run them, and how every route is tested.
---

A route is the path anyfmt takes from an input format to a target format: one engine step, or up to three steps chained through intermediate formats. anyfmt ships 793 routes between 59 formats, every one run on a real file and checked, and 516 of them are on the wheel by default.

## In numbers

| | |
|---|---|
| Routes | 793 |
| On the wheel by default | 516 |
| Routes with more than one step | 202 |
| Formats | 59 (all can be inputs, 52 can be outputs) |
| Input-only formats | SVG, WMA, DOC, Web Archive, Clipping, XLS, RAR |

To see every route for a format, use the [formats explorer](/formats) or run `anyfmt formats --from heic`.

## How a route is planned

Every direct conversion is one row in a single capability table, which the wheel, the command line, the router and the test matrix all read. When no single row goes from your format to the target, the router looks for a chain. It tries every path of up to three steps and picks the cheapest. A path costs more for each extra step, for each lossy intermediate format, and most of all for a step that loses structure. A few rules keep the results sensible:

- Still images and time-based media cross over only in one direct step. GIF to MP4 is a direct row, but PNG to GIF to MP4 is never planned.
- A step that produces several files, such as PDF pages to images, can only be the last step.
- Steps that combine several files are never chained.

For example, SVG to AVIF renders the SVG to PNG with resvg, then encodes AVIF with ImageIO. To see the route for any pair:

```bash title="Terminal"
anyfmt route heic jpg
```

```text
heic → jpg(imageio)  (cost 1.0)
```

`anyfmt convert … --dry-run` shows each file's route without writing anything.

## Shown by default, or opt-in

All 793 routes work, but some would clutter the wheel or surprise you, such as a photo to DOCX through PDF and text recognition. A route is hidden from the wheel when it:

- passes through a row that's marked as hidden by default, or
- crosses between families (images, text documents, spreadsheets, slides, audio, video, archives) in more than one step.

Direct rows, and anything that ends in PDF, stay on the wheel.

To show a hidden target on the wheel:

1. Open **Settings › Formats** and select the target format.
2. Turn on **Also offer it for other kinds of files**.

The command line always offers every route; `anyfmt targets --json` marks hidden ones `"shownByDefault": false`.

## The engines

| Engine | Handles |
|---|---|
| ImageIO | Photos and raster images |
| FFmpeg | Video and audio, plus animated and unusual images |
| AVFoundation | Lossless passthrough for Apple video |
| resvg | SVG rendering |
| PDFKit | PDF pages |
| WebKit | Typesetting documents to PDF |
| Quick Look | Slides to PDF and images |
| Cocoa text | RTF, RTFD and DOC |
| anyfmt OOXML | DOCX, XLSX and PPTX, written from scratch |
| anyfmt Markdown | Markdown and HTML |
| anyfmt Sheets | CSV, TSV, ODS, XLS and JSON tables |
| anyfmt EPUB | Ebooks |
| anyfmt Subtitles | SRT and VTT, to the millisecond |
| anyfmt Clippings | Finder text clippings |
| libarchive | ZIP, TAR, GZIP, 7z and RAR |

FFmpeg and its codec libraries, and resvg, ship inside the app, built from pinned sources, and FFmpeg is built without network support. Archives use the `bsdtar` and `ditto` that come with macOS. **Settings › Engines** lists each bundled engine with its version and licence.

## Every route is tested

`make matrix` runs every shipped route on a generated sample file, then opens the result to check it: an image decode, a probe of the video or audio with a duration check, a PDF page count, an archive listing, or a re-parse of a text format. A route that doesn't pass isn't shipped.

## Optional packs add routes

Two optional packs add routes the bundled engines can't do well. **Install** in **Settings › Engines** opens the official download page; anyfmt never downloads them itself, and checks the file you choose against a pinned SHA-256.

| Pack | Licence | Adds |
|---|---|---|
| pandoc 3.12.1 | GPL-2.0-or-later | pandoc's fidelity for DOCX, ODT and EPUB to DOCX, ODT and EPUB |
| Office pack (LibreOffice 26.8.1) | MPL-2.0 | Legacy PPT, Keynote and ODP slides, and higher-fidelity Office routes |

pandoc isn't bundled because its binary alone is 192 MB. The Office pack can't be installed yet, because its checksum isn't pinned. The wheel picks up pack changes without a relaunch.

## Known gaps

- **Not supported:** JPEG XL (no encoder on a stock Mac), camera RAW input (it needs a real sample file in the test matrix first), WMA output, GIF to AVI, WMV or M4V, Excel 95 `.xls`, and ASS or SSA subtitles.
- **Limited:** PDF to PPTX gives picture slides, not editable text. PDF to XLSX works by detecting tables, so results vary.
- **Opt-in or with a pack:** Pages, Keynote and Numbers go through the iWork apps (see [Permissions](/docs/permissions)); legacy PPT, Keynote and ODP slides need the Office pack.
- **Refused:** encrypted archives, with a clear message.
