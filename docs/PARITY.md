# Parity with the reference app

Feature by feature, against the commercial drag-to-convert app we benchmark
(behaviour from its public site, App Store listing and press kit, Oct 2026;
BUILD.md §1). Built from the merged `main`, `docs/MATRIX.md` and the lane notes
(`docs/lanes/*.md`) on 2026-10-18.

✅ shipped and tested · 🟡 shipped with a stated limit · ❌ not shipped (what it would take) · ➕ beyond the reference · 👁 built and unit-tested, needs the real-hardware check in BLOCKERS B-001

## Interaction

| Reference behaviour | anyfmt | Notes |
|---|---|---|
| Menu bar only, no Dock icon, no main window | ✅ | `LSUIElement`, template glyph, recents, Float toggle, Settings, About |
| Drag in Finder, tap Shift → radial wheel of output formats | ✅ 👁 | Zero permissions (D-001). Est. ≈ 30 ms p95 key tap → visible |
| Tap Command mid-drag → tools wheel | ✅ 👁 | |
| Tap Control mid-drag → actions wheel (AirDrop, Float, Copy, Move, Copy Path, Terminal) | ✅ 👁 | |
| Actions on folders, mixed selections, files with no conversions | ✅ | No-conversion files fall back to Actions with a hub note |
| Wheel stays open after the key is released, until drop or cancel | ✅ 👁 | Hub = cancel; DragSense state machine, 97 tests |
| Enter on a Finder selection opens the format menu | 🟡 | Opt-in: needs Accessibility + Automation (D-004). Zero-permission alternatives: Services menu item, menu-bar item, ⌃⌥Space drop ring |
| Command / Control switch wheels; arrows; Enter; Escape | ✅ | ➕ Tab cycles, 1–9 jump, Page Up/Down, VoiceOver |
| Trigger keys remappable | ✅ | Settings › Keys, live tap tester, conflict swap |
| Only relevant formats/tools for the file | ✅ | Router + per-kind tools; cross-family routes opt-in (`Route.isShownByDefault`) |
| Multi-file: only targets every file can produce, batched | ✅ | Intersection; files already in the target format are skipped and reported |
| Progress window per job; reveal in Finder | ✅ | ➕ ETA, stacking, batch cards, Retry, Copy details |
| Always a new copy, never overwrite | ✅ | `renamex_np(RENAME_EXCL)`, Finder-style `name 2.ext` |
| Everything local, no uploads | ✅ | `make netcheck`: 0 sockets. ffmpeg built `--disable-network` |
| Apple silicon, macOS 13+ | 🟡 | arm64, macOS 13 target; verified on macOS 27 only (B-007) |
| ➕ Options per target | ✅ | Configure after the drop: tune lip or ⌥-drop opens a pinned panel from the schema, with live size/duration/frame estimates (D-038) |
| ➕ Sticky aim + lock | ✅ | Selection holds against drift (30 %/10° + 60 ms); ⌥ tap locks the segment mid-drag, no permission needed |
| ➕ Presets | ✅ | Built-in + saved presets per format as chips on the wheel, "Last used", editable in Settings › Formats, shared with the CLI, synced (Pro) |
| ➕ More than 8 targets | ✅ | Second ring 9–20, paging above |
| ➕ Command-line tool | ✅ | Agent-ready `anyfmt` CLI: `--json` everywhere, NDJSON progress, dry runs, stable exit codes, `anyfmt schema` (docs/CLI.md) |
| ➕ MCP server | ✅ | `anyfmt mcp` over stdio, no network, no port: convert, targets, options, estimate, presets, tools (agents/SKILL.md) |
| ➕ Public API (Pro) | 🟡 | Contract, mock and TypeScript SDK done (docs/API.md); the server isn't built (B-006) |

## Scale

| | Reference | anyfmt |
|---|---|---|
| Conversion options | ~275 | **793 shipped and passing `make matrix`**, 516 on the wheel by default |
| Tools | 26 | **26** local + 3 Pro (cloud) |
| Actions | 6 | **6** + Pro share link |

## Formats

| Category | Reference | anyfmt | Gaps |
|---|---|---|---|
| Images | JPG PNG WebP HEIC TIFF AVIF BMP GIF SVG → JPG PNG WebP HEIC TIFF AVIF BMP GIF PDF | ✅ all, plus inputs HEIF JP2 PSD ICO ICNS TGA EXR and outputs ICO ICNS (+ HEIF JP2 PSD TGA EXR opt-in) | ❌ JPEG XL in/out (no encoder on a stock Mac; needs libjxl); ❌ camera RAW input (needs a real CC0 DNG fixture, B-009) |
| Audio | MP3 M4A WAV FLAC OGG Opus AIFF WMA(in) → MP3 M4A WAV FLAC OGG Opus AIFF | ✅ all + CAF | WMA output not offered (input only, as the reference) |
| Video | MP4 MOV MKV WebM AVI WMV GIF → same + GIF + MP3/M4A | ✅ all + M4V, + WAV/FLAC/AIFF/OGG/Opus/CAF extraction | 🟡 GIF → AVI/WMV/M4V not offered (one direct row each if wanted); AV1 output only on request |
| PDF | PDF → DOCX PAGES PPTX XLSX JPG PNG EPUB TXT MD | ✅ DOCX PPTX XLSX JPG PNG EPUB TXT MD + HTML RTF RTFD ODT HEIC WebP AVIF TIFF BMP | 🟡 PDF → PPTX gives picture slides (not editable text); PDF → XLSX is table detection (grade B). 🟡 → PAGES: opt-in (Pages installed + Automation) |
| Documents | DOCX PAGES MD TXT EPUB RTF RTFD clippings → DOCX PAGES MD TXT EPUB HTML PDF | ✅ DOCX MD TXT EPUB RTF RTFD clippings + DOC ODT HTML WebArchive → DOCX MD TXT EPUB HTML PDF + RTF RTFD ODT | 🟡 PAGES in/out: opt-in only (proprietary IWA format; native reader is a large project) |
| Slides | PPT PPTX → PDF JPG PNG; PDF → PPTX | ✅ PPTX → PDF JPG PNG (Quick Look fidelity); ✅ PDF → PPTX | 🟡 PPT (legacy), KEY, ODP: with the optional Office pack only (no zero-install renderer; no fixture without Office) |
| Spreadsheets | XLSX ODS CSV TSV XLS(in) → XLSX ODS CSV TSV PDF | ✅ all + JSON in/out, HTML out | 🟡 Excel 95 (BIFF5) .xls not read; Numbers opt-in/Office pack |
| EPUB | EPUB → PDF DOCX TXT MD HTML | ✅ all + RTF RTFD ODT | |
| Subtitles | SRT VTT → SRT VTT TXT | ✅ exact ms timing, styling round-trips | ASS/SSA input not supported |
| Archives | ZIP TAR GZIP RAR(in) 7z(in) → ZIP TAR GZIP | ✅ all + 7z output, folder ⇄ archive, archive → archive | Encrypted archives refused with a clear message; single files → ZIP/GZ not on the wheel |

## Tools (26)

| # | Tool | anyfmt | Notes |
|---|---|---|---|
| 1 | Compress (quality, target size, percentage) | ✅ | JPG/HEIC/AVIF/WebP/PNG (own palette quantiser); never larger than the original |
| 2 | Resize | ✅ | presets, exact px, % |
| 3 | Crop | ✅ | editor with handles, aspect presets |
| 4 | Adjust | ✅ | exposure, contrast, saturation, warmth; 24 ms preview |
| 5 | Annotate | 🟡 | arrows, boxes, highlight, freehand, text; text typed in the sidebar, not inline |
| 6 | Redact | ✅ | irreversible by test |
| 7 | Remove background | 🟡 | any subject on macOS 14+; people only on macOS 13 (Vision) |
| 8 | Add background | ✅ | solid/gradient/image, padding, radius, shadow |
| 9 | Collage | ✅ | rows sized so nothing is cropped |
| 10 | Images → PDF | ✅ | JPEGs embedded without recompression |
| 11 | Read QR / barcodes | ✅ 👁 | results window with Copy; links open only after confirmation |
| 12 | Trim video | ✅ | lossless keyframe cut or frame-exact re-encode |
| 13 | Crop video | ✅ | display orientation correct for rotated phone video |
| 14 | Change speed | ✅ | pitch kept or not |
| 15 | Split | ✅ | at times / every N s |
| 16 | Join | ✅ | lossless when compatible, else one re-encode with letterboxing |
| 17 | Snapshot frame(s) | ✅ | exact frame, PNG/JPG |
| 18 | Compress video | ✅ | presets capped at % of source bitrate; target size two-pass |
| 19 | Trim audio | ✅ | waveform editor |
| 20 | Normalize | ✅ | EBU R128 two-pass, ±1 LUFS in tests |
| 21 | Bleep | ✅ | tone or silence, 5 ms edges |
| 22 | Change channels | ✅ | mono/stereo/swap |
| 23 | View + edit metadata | 🟡 | images/audio/video/PDF; GIF/BMP/TGA/EXR/ICO read-only |
| 24 | Strip all metadata | ✅ | images lossless for JPEG; AV stream copy; PDF rewritten |
| 25 | Merge / split / reorganise PDF | ✅ | vector preserved, bookmarks kept |
| 26 | Compress PDF | ✅ | own Quartz filter; text stays vector (4.1 MB → 315 KB) |
| ➕ | Transcribe, Upscale, HQ background removal | Pro | server-backed; client + mock done, server not built (B-006) |

## Actions (6)

| Action | anyfmt | Notes |
|---|---|---|
| AirDrop | ✅ 👁 | multi-file, anchor window |
| Float | ✅ 👁 | pile + grid, drag out (⌥ keeps), drop in, physics, VoiceOver; ❌ Quick Look and arrow keys on the shelf (follow-up) |
| Copy | ✅ | files on the pasteboard (⌘V in Finder) |
| Move | ✅ | recent folders + chooser, never overwrites, cross-volume safe; no undo |
| Copy Path | ✅ | newline-separated; ⌥ for shell-quoted |
| Terminal | ✅ | Terminal, iTerm2, Ghostty (opens a tab), Warp |
| ➕ Share link | Pro | upload with resume, expiry/password/limit; first-upload notice |

## Polish

See `docs/POLISH_AUDIT.md` for the line-by-line audit. Summary: the open animation
is staggered (≤ 150 ms vs ≈ 100–130 ms blob), hover lifts and fills, wheels morph,
progress cards add ETA and stacking, editors add before/after, and every surface
handles dark mode, increased contrast, reduce transparency, reduce motion and
VoiceOver. Known worse-or-unverified: no mid-drag haptics (platform), and live
vibrancy only seen through our own captures (B-001).
