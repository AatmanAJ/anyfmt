# Parity with the reference app

Feature by feature against the commercial drag-to-convert app we benchmark
(behaviour taken from its public site, App Store listing and press kit,
Oct 2026; see BUILD.md §1). Status is honest:

- ✅ shipped and tested
- 🟡 shipped with a stated limitation
- ❌ not shipped (with what it would take)
- ➕ something we do that the reference doesn't

_Statuses are filled in from the merged build, `docs/MATRIX.md` and the lane notes. See the final section for the date._

## Interaction

| Reference behaviour | Halo | Notes |
|---|---|---|
| Lives in the menu bar, no Dock icon, no main window | | |
| Drag a file in Finder, tap Shift → radial wheel of output formats | | |
| Tap Command mid-drag → wheel of file-specific tools | | |
| Tap Control mid-drag → wheel of file actions (AirDrop, Float, Copy, Move, Copy Path, Terminal) | | |
| Actions work on folders, mixed selections, files with no conversions | | |
| Release the key and keep dragging: wheel stays open until drop or cancel | | |
| Enter on a selected Finder file opens the format menu | | |
| Command / Control switch wheels; arrows choose; Enter applies; Escape cancels | | |
| Trigger keys remappable | | |
| Only relevant formats/tools for the dragged file | | |
| Multi-file drags: only targets every file can produce, batched | | |
| Each job opens a small progress window; finished files revealed in Finder | | |
| Always writes a new copy, never overwrites | | |
| Everything local, no uploads | | |
| Apple silicon, macOS 13+ | | |

## Scale

| Reference | Halo | Notes |
|---|---|---|
| ~275 conversion options | | `make matrix` count |
| 26 tools | | |
| 6 actions | | |

## Formats

| Category | Reference inputs → outputs | Halo | Gaps |
|---|---|---|---|
| Images | JPG PNG WebP HEIC TIFF AVIF BMP GIF SVG → JPG PNG WebP HEIC TIFF AVIF BMP GIF PDF | | |
| Audio | MP3 M4A WAV FLAC OGG Opus AIFF WMA → MP3 M4A WAV FLAC OGG Opus AIFF | | |
| Video | MP4 MOV MKV WebM AVI WMV GIF → same + GIF + MP3/M4A | | |
| PDF | PDF → DOCX PAGES PPTX XLSX JPG PNG EPUB TXT MD | | |
| Documents | DOCX PAGES MD TXT EPUB RTF RTFD clippings → DOCX PAGES MD TXT EPUB HTML PDF | | |
| Slides | PPT PPTX → PDF JPG PNG; PDF → PPTX | | |
| Spreadsheets | XLSX ODS CSV TSV XLS → XLSX ODS CSV TSV PDF | | |
| EPUB | EPUB → PDF DOCX TXT MD HTML | | |
| Subtitles | SRT VTT → SRT VTT TXT | | |
| Archives | ZIP TAR GZIP RAR 7z → ZIP TAR GZIP | | |

## Tools (26)

| # | Tool | Halo | Notes |
|---|---|---|---|
| 1 | Compress image (quality, target size, percentage) | | |
| 2 | Resize | | |
| 3 | Crop | | |
| 4 | Adjust | | |
| 5 | Annotate | | |
| 6 | Redact | | |
| 7 | Remove background | | |
| 8 | Add background | | |
| 9 | Collage | | |
| 10 | Images → PDF | | |
| 11 | Read QR / barcodes | | |
| 12 | Trim video | | |
| 13 | Crop video | | |
| 14 | Change speed | | |
| 15 | Split | | |
| 16 | Join | | |
| 17 | Snapshot frame(s) | | |
| 18 | Compress video | | |
| 19 | Trim audio | | |
| 20 | Normalize | | |
| 21 | Bleep | | |
| 22 | Change channels | | |
| 23 | View + edit metadata | | |
| 24 | Strip metadata | | |
| 25 | Merge / split / reorganise PDF | | |
| 26 | Compress PDF | | |

## Actions (6)

| Action | Halo | Notes |
|---|---|---|
| AirDrop | | |
| Float | | |
| Copy | | |
| Move | | |
| Copy Path | | |
| Terminal | | |

## Polish

| Moment | Reference (measured, research/INTERACTION_NOTES.md) | Halo |
|---|---|---|
| Wheel open | ≈ 100–130 ms scale + fade | |
| Hover | Instant orange fill | |
| Wheel switch | ≈ 100 ms crossfade | |
| More than 8 targets | Not seen | |
| Progress window | Title, name, bar; no ETA; no stacking | |
| Editors | Compact card, Apply; no before/after | |
| Dark mode / accessibility | Not shown | |
