/**
 * A "how to convert X to Y on a Mac" guide. One object per page at /convert/<slug>. The page
 * template draws a centrepiece chosen by `visual`, so the copy here should match what that
 * visual shows.
 */
export type GuideVisual =
  | 'photo' // a photo leaving one container for another (HEIC/WebP/AVIF/PNG → JPG/PNG…)
  | 'vector' // SVG edges stay sharp at any zoom vs pixels
  | 'icon' // one artwork → the ladder of icon sizes (ICNS 16…1024, ICO 16…256)
  | 'container' // video remux: same streams, new box (MOV/MKV → MP4)
  | 'gif' // video → animated GIF: frames, fps, colours, width
  | 'audio' // waveform + bitrate (WAV/M4A/FLAC → MP3, video → MP3)
  | 'document' // a page re-typeset into another document format (DOCX/MD/EPUB → PDF)
  | 'pdf' // PDF reconstructed into an editable document, or rendered to images
  | 'sheet' // spreadsheet cells → CSV/XLSX rows
  | 'subtitle' // cue timings to the millisecond
  | 'archive' // RAR/7z/folder → ZIP listing
  | 'squeeze' // compress tools: size before/after against a target
  | 'cutout' // remove background
  | 'scrub' // strip metadata: EXIF/GPS rows disappearing

export interface Guide {
  slug: string // 'heic-to-jpg', 'compress-video'
  kind: 'convert' | 'tool'
  /** Input format ids from catalog.json (`heic`), or several for a family (`['mov','mp4']`). */
  from: string[]
  /** Target format id from catalog.json; for tools, the tool id from tools.json (`video.compress`). */
  to: string
  visual: GuideVisual
  /** Browser tab / search result title, < 60 chars: "Convert HEIC to JPG on Mac, offline". */
  title: string
  /** The page's H1, short and specific: "HEIC to JPG, without the upload." */
  h1: string
  /** Meta description, 140–160 chars, says what and how. */
  description: string
  /** The direct answer in 2–3 sentences, written so an assistant could quote it verbatim. */
  answer: string
  /** Why people need this conversion; concrete situations, 3–4 items. */
  why: string[]
  /** Side by side: what changes between the formats. 4–6 rows. */
  facts: { label: string; from: string; to: string }[]
  /** Exact steps in anyfmt, 3–5, naming real keys and UI. */
  steps: string[]
  /** The options that matter, by real option id from options.json (or the tool's options), with advice. */
  options: { id: string; label: string; advice: string }[]
  /** One real CLI line that does it. Must be valid for `anyfmt convert`/`anyfmt tool`. */
  cli: string
  /** Optional batch / folder variant. */
  batch?: string
  /** Honest caveats: what you lose, what won't work, limits. 2–4 items. */
  gotchas: string[]
  /** 4–6 questions people actually search, with short factual answers. */
  faq: [question: string, answer: string][]
  /** 3–5 other guide slugs. */
  related: string[]
  /** Measured numbers from docs/PERF.md, if any apply. Never invent one. */
  measured?: { label: string; value: string; source: string }[]
}
