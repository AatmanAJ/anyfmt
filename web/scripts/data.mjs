// Builds the site's data from the app itself. `anyfmt schema --json` is the one document the
// wheel, the CLI and the MCP server all read, so the formats page can't drift from the app.
// If a built CLI is around we refresh the snapshot; otherwise the committed snapshot is used.
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const snapshot = join(here, 'schema.json')
const out = join(here, '..', 'src', 'data')
const cli = join(here, '..', '..', 'build', 'DerivedData', 'Build', 'Products', 'Debug', 'anyfmt')

if (existsSync(cli)) {
  try {
    const fresh = execFileSync(cli, ['schema', '--json'], { maxBuffer: 64 << 20, timeout: 60_000 }).toString()
    JSON.parse(fresh)
    writeFileSync(snapshot, fresh)
  } catch (e) {
    console.warn(`data: keeping the committed schema snapshot (${e.message.split('\n')[0]})`)
  }
}

const schema = JSON.parse(readFileSync(snapshot, 'utf8'))

const ENGINES = {
  imageio: { name: 'ImageIO', by: 'Apple', what: 'Photos and raster images' },
  'ffmpeg-image': { name: 'FFmpeg', by: 'FFmpeg project', what: 'Animated and exotic images' },
  ffmpeg: { name: 'FFmpeg', by: 'FFmpeg project', what: 'Video and audio' },
  avfoundation: { name: 'AVFoundation', by: 'Apple', what: 'Lossless Apple video passthrough' },
  resvg: { name: 'resvg', by: 'linebender', what: 'SVG rendering' },
  pdfkit: { name: 'PDFKit', by: 'Apple', what: 'PDF pages' },
  webkitpdf: { name: 'WebKit', by: 'Apple', what: 'Typeset documents to PDF' },
  quicklook: { name: 'Quick Look', by: 'Apple', what: 'Slides to PDF and images' },
  attributedtext: { name: 'Cocoa text', by: 'Apple', what: 'RTF, RTFD and DOC' },
  ooxml: { name: 'anyfmt OOXML', by: 'anyfmt', what: 'DOCX, XLSX and PPTX, written from scratch' },
  markdown: { name: 'anyfmt Markdown', by: 'anyfmt', what: 'Markdown and HTML' },
  sheets: { name: 'anyfmt Sheets', by: 'anyfmt', what: 'CSV, TSV, ODS, XLS and JSON tables' },
  epub: { name: 'anyfmt EPUB', by: 'anyfmt', what: 'Ebooks' },
  subtitles: { name: 'anyfmt Subtitles', by: 'anyfmt', what: 'SRT and VTT, to the millisecond' },
  textclipping: { name: 'anyfmt Clippings', by: 'anyfmt', what: 'Finder text clippings' },
  bsdtar: { name: 'libarchive', by: 'libarchive project', what: 'ZIP, TAR, GZIP, 7z and RAR' },
}

const KINDS = [
  ['image', 'Images'], ['vector', 'Vector'], ['pdf', 'PDF'], ['video', 'Video'], ['audio', 'Audio'],
  ['document', 'Documents'], ['slides', 'Slides'], ['spreadsheet', 'Spreadsheets'], ['ebook', 'Ebooks'],
  ['subtitle', 'Subtitles'], ['archive', 'Archives'], ['folder', 'Folders'],
]

const label = Object.fromEntries(schema.formats.map((f) => [f.id, f.label]))
const formats = schema.formats.map((f) => {
  const targets = schema.routes
    .filter((r) => r.from === f.id)
    .map((r) => ({
      to: r.to,
      wheel: r.shownByDefault,
      engines: [...new Set(r.hops.map((h) => h.engine))],
      via: r.hops.slice(0, -1).map((h) => h.to),
    }))
    .sort((a, b) => Number(b.wheel) - Number(a.wheel) || a.via.length - b.via.length || label[a.to].localeCompare(label[b.to]))
  return { id: f.id, label: f.label, name: f.name, kind: f.kind, extensions: f.extensions, input: f.input, output: f.output, targets }
})

const localTools = schema.tools.filter((t) => !t.cloud)
const catalog = {
  generatedFrom: `${schema.cli.name} ${schema.cli.version}`,
  counts: {
    routes: schema.routes.length,
    onWheel: schema.routes.filter((r) => r.shownByDefault).length,
    formats: schema.formats.length,
    inputs: schema.formats.filter((f) => f.input).length,
    outputs: schema.formats.filter((f) => f.output).length,
    tools: localTools.length,
    cloudTools: schema.tools.length - localTools.length,
    multiHop: schema.routes.filter((r) => r.hops.length > 1).length,
  },
  kinds: KINDS.filter(([k]) => schema.formats.some((f) => f.kind === k)).map(([id, name]) => ({ id, name })),
  engines: ENGINES,
  formats,
}

const tools = schema.tools.map((t) => ({ id: t.id, title: t.title, cloud: t.cloud, kinds: t.kinds, suffix: t.suffix, arity: t.arity, options: t.options }))

mkdirSync(out, { recursive: true })
writeFileSync(join(out, 'catalog.json'), JSON.stringify(catalog))
writeFileSync(join(out, 'options.json'), JSON.stringify(schema.options))
writeFileSync(join(out, 'tools.json'), JSON.stringify(tools))
writeFileSync(join(out, 'presets.json'), JSON.stringify(schema.presets.filter((p) => !p.hidden)))
writeFileSync(join(out, 'cli.json'), JSON.stringify({ cli: schema.cli, exitCodes: schema.exitCodes, events: schema.events, mcp: schema.mcp }))
console.log(`data: ${catalog.counts.routes} routes (${catalog.counts.onWheel} on the wheel), ${catalog.counts.formats} formats, ${catalog.counts.tools} tools, from ${catalog.generatedFrom}`)
