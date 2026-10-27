/**
 * Release notes, newest first. Curated from the app's git history (dates and counts are real:
 * `git log` on the app, excluding the website). Tags match the three wheel keys plus the rest.
 */
export type Tag = 'convert' | 'tools' | 'actions' | 'cli' | 'cloud' | 'design' | 'fix' | 'perf'

export const TAGS: { id: Tag; label: string; glyph: string; key?: boolean }[] = [
  { id: 'convert', label: 'Convert', glyph: '⇧', key: true },
  { id: 'tools', label: 'Tools', glyph: '⌘', key: true },
  { id: 'actions', label: 'Actions', glyph: '⌃', key: true },
  { id: 'cli', label: 'CLI and agents', glyph: '>_' },
  { id: 'cloud', label: 'Cloud', glyph: '☁' },
  { id: 'design', label: 'Design', glyph: '◐' },
  { id: 'perf', label: 'Speed', glyph: '↯' },
  { id: 'fix', label: 'Fixes', glyph: '✓' },
]

export interface Entry { tag: Tag; title: string; body?: string }
export interface Release {
  version: string
  date: string // ISO day, or '' while upcoming
  status: 'upcoming' | 'build'
  title: string
  summary: string
  visual: 'box' | 'rename' | 'manners' | 'dayone'
  entries: Entry[]
}

export const RELEASES: Release[] = [
  {
    version: '0.1.0', date: '', status: 'upcoming',
    title: 'The first public release',
    summary: 'Everything below, signed, notarized and in one 25 MB download. Apple silicon, macOS 13 or later.',
    visual: 'box',
    entries: [
      { tag: 'convert', title: '793 conversion routes, every one tested', body: 'Images, video, audio, PDF, documents, slides, spreadsheets, ebooks, subtitles and archives. Every route runs on a generated file and its output is opened and checked before release. 516 are on the wheel by default; the rest are one switch away in Settings › Formats.' },
      { tag: 'tools', title: '26 tools on ⌘ Command', body: 'Compress to a target size, resize, crop, adjust, annotate, redact, remove or add a background, collage, trim and split video, normalize audio, bleep, merge and compress PDFs, strip metadata.' },
      { tag: 'actions', title: '6 actions on ⌃ Control', body: 'AirDrop, Float, Copy, Move, Copy Path and Terminal. They work on folders and mixed selections too.' },
      { tag: 'cli', title: 'The anyfmt command and an MCP server', body: 'Same routes as the wheel, --json on every command, stable exit codes, and `anyfmt mcp` for agents. Neither opens a network socket.' },
    ],
  },
  {
    version: 'Build 3', date: '2026-10-26', status: 'build',
    title: 'anyfmt gets its name',
    summary: 'The codename is gone. The app, the command, the bundle id and every screen now say anyfmt.',
    visual: 'rename',
    entries: [
      { tag: 'design', title: 'Renamed everywhere', body: 'The app, the CLI, the menu bar, onboarding, the DMG and every screenshot. The bundle id is app.anyfmt.' },
      { tag: 'cloud', title: 'Old licence keys keep working', body: 'Keys issued before the rename are still accepted by the app and the issuing tool.' },
      { tag: 'fix', title: 'The full test suite runs green end to end', body: 'Unit tests no longer wait on a terminal for input, so `make test` finishes on a fresh checkout.' },
    ],
  },
  {
    version: 'Build 2', date: '2026-10-18', status: 'build',
    title: 'The wheel learns some manners',
    summary: 'The afternoon pass: aiming that forgives a shaky hand, presets you can see, a new look, and anyfmt opened up to scripts and agents.',
    visual: 'manners',
    entries: [
      { tag: 'convert', title: 'Sticky aim and ⌥ lock', body: 'A selection holds against small drift, and tapping ⌥ Option mid-drag locks the segment you are on. No permission needed.' },
      { tag: 'convert', title: 'Presets on the wheel', body: 'Built-in and saved presets appear as chips on a segment, each showing the file size it will produce. The app and the CLI share one presets file.' },
      { tag: 'convert', title: 'Live estimates', body: 'The options panel shows the output size, duration and frame count as you change settings, measured with the real encoder.' },
      { tag: 'convert', title: 'Better GIFs', body: 'Loop, colour count and dithering options for video to GIF.' },
      { tag: 'cli', title: 'An agent-ready CLI and `anyfmt mcp`', body: 'NDJSON progress, dry runs, `anyfmt schema` for planning, and an MCP server with convert, estimate, formats, options, presets, run_tool and targets.' },
      { tag: 'cloud', title: 'Offline licence keys', body: 'Ed25519-signed keys that verify without a network. They never limit anything that runs on your Mac.' },
      { tag: 'cloud', title: 'A public conversion API, specified', body: 'An OpenAPI 3.1 contract, a mock server that implements all of it, and a TypeScript SDK tested against the mock.' },
      { tag: 'design', title: 'A new look', body: 'A painted black disc, a heat band on hover, display type for format names, a new icon, and the same language across settings, onboarding, progress cards and every editor.' },
      { tag: 'fix', title: 'Drags from Photos, Mail and Safari', body: 'Promised files from these apps no longer crash the drop, and drags out of Photos and Mail no longer end after a second.' },
    ],
  },
  {
    version: 'Build 1', date: '2026-10-18', status: 'build',
    title: 'Day one: the whole app',
    summary: 'Parallel build lanes, merged by mid-afternoon: the drag sensor, the wheel, every engine, every tool, the actions, the settings and the packaging.',
    visual: 'dayone',
    entries: [
      { tag: 'convert', title: 'A drag sensor that needs no permissions', body: 'anyfmt reads the mouse button, the modifier keys and the system drag pasteboard, the same public state any app can read. It never sees ordinary keys.' },
      { tag: 'convert', title: 'Engines inside', body: 'ffmpeg built without network support, x264, x265, VP9, AV1, Opus, WebP and the resvg SVG renderer, from pinned, checksummed sources. Plus Apple ImageIO, AVFoundation, PDFKit and our own document, spreadsheet, EPUB and subtitle writers.' },
      { tag: 'tools', title: 'Editors for every tool', body: 'Crop, adjust, annotate, redact, backgrounds, collage, trim, split, join, snapshot, audio trim, bleep and PDF organise, each with its own window.' },
      { tag: 'actions', title: 'The Float shelf', body: 'A pile you can drop files onto and drag them back out of, with a grid view and VoiceOver support.' },
      { tag: 'perf', title: 'Under budget', body: 'Launch in 147 ms, 30 MB idle, 0.05 % idle CPU, and a 12 MP HEIC to JPG in 74 ms on an M5 Max.' },
      { tag: 'design', title: 'Settings and onboarding', body: 'Settings for keys, output, formats, engines and advanced options, a short onboarding demo, and a permissions coach that explains every optional permission.' },
    ],
  },
]

/** App commits per hour on 18 October and 26 October (git log, website excluded). */
export const COMMITS_BY_HOUR: { day: string; hour: number; n: number }[] = [
  { day: '18 Oct', hour: 11, n: 16 }, { day: '18 Oct', hour: 12, n: 71 }, { day: '18 Oct', hour: 13, n: 26 }, { day: '18 Oct', hour: 14, n: 7 },
  { day: '18 Oct', hour: 15, n: 1 }, { day: '18 Oct', hour: 16, n: 15 }, { day: '18 Oct', hour: 17, n: 19 }, { day: '18 Oct', hour: 18, n: 14 },
  { day: '18 Oct', hour: 19, n: 2 }, { day: '18 Oct', hour: 20, n: 0 }, { day: '18 Oct', hour: 21, n: 2 }, { day: '18 Oct', hour: 22, n: 0 }, { day: '18 Oct', hour: 23, n: 1 },
]

/** Real commit subjects (feat/fix/perf), newest first, for the build-log ticker. */
export const COMMIT_LOG: string[] = [
  "fix(make): run app unit tests with stdin from /dev/null; make test green end to end",
  "fix(dragsense): drags out of Photos/Mail ended within a second",
  "fix(actions): crash receiving promised files (Photos, Mail, Safari drags)",
  "feat(options): choice chips with a size per chip; instant numbers while the estimate refines",
  "feat(editors): phase 2 language for every editor window",
  "fix(engine): failure details start with the shell-quoted command line",
  "feat(design): Settings and cloud screens in the phase 2 language",
  "feat(design): progress cards, toasts, menu bar, Float shelf and Move chooser in the approved direction",
  "feat(onboarding): restyle onboarding and About to the approved direction",
  "feat(design): new app icon, menu bar glyph and DMG background in the phase 2 palette",
  "feat(wheel): phase 2 look: painted black disc, heat-band hover, display-type format names",
  "feat(design): bind the palette to the approved direction; shared pills, tiles, display type; token lint",
  "fix(presets): app and CLI see each other's preset edits; docs for phase 2 CLI/MCP",
  "fix(cli): find the bundled engines when run through a PATH symlink",
  "feat(onboarding): welcome + optional Pro activation; first-run reset and permission-path tests",
  "feat(wheel): presets on the wheel and the pinned options panel",
  "feat(sdk): TypeScript SDK for the public conversion API",
  "feat(mock): implement the public conversion API in the mock server",
  "feat(api): public pay-per-use conversion API contract (phase H)",
  "feat(cloud): offline Ed25519 licence keys (verifier, store, entitlement merge, issuing tool)",
  "feat(engine): live conversion estimates for the pinned options panel",
  "feat(design): phase 2 tokens, Inter Display, and the direction board (awaiting approval)",
  "feat(settings): edit presets in Settings › Formats",
  "feat(gif): loop, colour count and dither options for video → GIF",
  "feat(wheel): sticky aiming, ⌥-tap lock, tune lip and preset chips (RadialMenu, DragSense)",
  "fix: phase A audit findings (sync source, press-mode copy, CLI goldens)",
  "fix(wheel): drops on a segment land; faster, fresher wheel shows",
  "feat(keys): hold or tap opens the wheel (press activation, default); Return shortcut asks for Input Monitoring",
  "perf(router): cache live engine availability (2 s TTL + invalidateLive on pack install); 40x cheaper live()",
  "fix(app): settings that were stored but inert now drive behaviour",
  "feat(router): Route.isShownByDefault keeps cross-family multi-hop routes opt-in; matrix 793/793 (516 on the wheel by default); refreshed screens + GIF",
  "feat(sheets): own XLS (BIFF8 in OLE2) reader with generated, Quick Look-validated fixture",
  "feat(wheel): README demo GIF rendered from the real wheel and live capability table (make gallery)",
  "fix(radialmenu): keep compact Pro chips inside outer-ring wedges",
  "fix(docs): thread-safe font traits in RTF writer; test(docs): concurrent conversions",
  "fix(markdown): GFM footnotes are kept as numbered notes instead of being parsed as link definitions",
  "perf(sheets): byte-level CSV, hand-written type inference, streaming XLSX sheets; test(docs): corrupt-input and large-file robustness",
  "feat(docs): on-device OCR (Vision) for scanned PDF pages; docs: lane F contract-change requests",
  "fix(scripts): netcheck survives pgrep no-match; filter_complex test sources",
  "fix(image-tools): localise symbology and channel names"
]
