/**
 * Loads the docs: Markdown files in content/docs with `title` and `description` front matter,
 * ordered by the registry. Also builds the search index and the files agents read (llms.txt,
 * llms-full.txt, one .md twin per page).
 */
import { DOC_ORDER, DOC_SECTIONS } from '../content/docs/registry'

const RAW = import.meta.glob('../content/docs/*.md', { query: '?raw', import: 'default', eager: true }) as Record<string, string>

export interface Heading { depth: 2 | 3; text: string; id: string }
export interface Doc { slug: string; label: string; section: string; title: string; description: string; body: string; headings: Heading[]; path: string }

export const slugify = (s: string) =>
  s.toLowerCase().replace(/`/g, '').replace(/[^\p{L}\p{N}\s-]/gu, '').trim().replace(/\s+/g, '-').replace(/-+/g, '-')

function frontMatter(raw: string) {
  const m = /^---\n([\s\S]*?)\n---\n?/.exec(raw)
  const meta: Record<string, string> = {}
  if (m) for (const line of m[1].split('\n')) {
    const i = line.indexOf(':')
    if (i > 0) meta[line.slice(0, i).trim()] = line.slice(i + 1).trim().replace(/^["']|["']$/g, '')
  }
  return { meta, body: m ? raw.slice(m[0].length) : raw }
}

/** Headings outside fenced code, with the same ids the renderer gives them. */
function headingsOf(body: string): Heading[] {
  const out: Heading[] = []
  let fence = false
  const seen = new Map<string, number>()
  for (const line of body.split('\n')) {
    if (/^\s*(```|~~~)/.test(line)) { fence = !fence; continue }
    if (fence) continue
    const m = /^(##|###)\s+(.+?)\s*#*$/.exec(line)
    if (!m) continue
    const text = m[2].replace(/\*\*|`|\[([^\]]+)\]\([^)]+\)/g, (_, l) => l ?? '')
    let id = slugify(text)
    const n = seen.get(id) ?? 0
    seen.set(id, n + 1)
    if (n) id = `${id}-${n}`
    out.push({ depth: m[1].length as 2 | 3, text, id })
  }
  return out
}

const bySlug: Record<string, string> = {}
for (const [file, raw] of Object.entries(RAW)) bySlug[file.split('/').pop()!.replace(/\.md$/, '')] = raw

export const DOCS: Doc[] = DOC_ORDER.filter((d) => bySlug[d.slug]).map((d) => {
  const { meta, body } = frontMatter(bySlug[d.slug])
  return {
    slug: d.slug, label: d.label, section: d.section,
    title: meta.title || d.label, description: meta.description || '',
    body, headings: headingsOf(body), path: d.slug === 'index' ? '/docs' : `/docs/${d.slug}`,
  }
})
export const DOC = Object.fromEntries(DOCS.map((d) => [d.slug, d])) as Record<string, Doc>
export { DOC_SECTIONS }

const SITE = 'https://anyfmt.app'
export const mdUrl = (d: Doc) => `${SITE}/docs/${d.slug === 'index' ? 'index' : d.slug}.md`

/** The page as an agent should read it: title, summary, source URL, then the Markdown. */
export const docAsMarkdown = (d: Doc) => `# ${d.title}\n\n> ${d.description}\n\nSource: ${SITE}${d.path}\n\n${d.body.trim()}\n`

export const tokensOf = (s: string) => Math.max(1, Math.round(s.length / 4))

export function llmsTxt() {
  const lines = [
    '# anyfmt',
    '',
    '> anyfmt is an open-source (AGPL-3.0) macOS menu bar app that converts files where they are: drag a file in Finder, tap Shift, and drop it on a format. 793 tested conversion routes across images, video, audio, PDF, documents, spreadsheets, ebooks, subtitles and archives, plus 26 editing tools. Everything runs on the Mac; nothing is uploaded. It also ships a CLI (`anyfmt`) and a local MCP server (`anyfmt mcp`).',
    '',
    'Requirements: Apple silicon, macOS 13 or later. Site: https://anyfmt.app. Every docs page is also available as Markdown by appending .md to its URL.',
    '',
  ]
  for (const s of DOC_SECTIONS) {
    const docs = s.items.map(([slug]) => DOC[slug]).filter(Boolean)
    if (!docs.length) continue
    lines.push(`## ${s.title}`, '')
    for (const d of docs) lines.push(`- [${d.title}](${mdUrl(d)}): ${d.description}`)
    lines.push('')
  }
  lines.push('## Site', '', `- [Formats](${SITE}/formats): every format and route, generated from the app`, `- [Pricing](${SITE}/pricing): build it yourself (free), Desktop (one payment), donations`, `- [Changelog](${SITE}/changelog)`, `- [Full docs in one file](${SITE}/llms-full.txt)`, '')
  return lines.join('\n')
}

export const llmsFull = () => DOCS.map(docAsMarkdown).join('\n\n---\n\n')

/* ── search ─────────────────────────────────────────────────── */

export interface Hit { doc: Doc; heading?: Heading; text: string; score: number; at: number }
interface Chunk { doc: Doc; heading?: Heading; text: string; lower: string }

const plain = (s: string) => s.replace(/```[\s\S]*?```/g, ' ').replace(/^\s*\|?[\s:|-]*-{3,}[\s:|-]*\|?\s*$/gm, ' ').replace(/`([^`]+)`/g, '$1').replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/[*_>#|]/g, ' ').replace(/\s+/g, ' ').trim()

let INDEX: Chunk[] | null = null
function index() {
  if (INDEX) return INDEX
  INDEX = []
  for (const doc of DOCS) {
    const parts = doc.body.split(/^(?=##+\s)/m)
    for (const part of parts) {
      const m = /^(##+)\s+(.+)/.exec(part)
      const heading = m ? doc.headings.find((h) => h.text === m[2].replace(/\*\*|`/g, '').trim()) : undefined
      const text = plain(m ? part.slice(m[0].length) : part)
      INDEX.push({ doc, heading, text, lower: `${heading?.text ?? doc.title} ${text}`.toLowerCase() })
    }
  }
  return INDEX
}

export function search(q: string, limit = 12): Hit[] {
  const query = q.trim().toLowerCase()
  if (!query) return []
  const words = query.split(/\s+/)
  const hits: Hit[] = []
  for (const c of index()) {
    if (!words.every((w) => c.lower.includes(w))) continue
    const title = c.doc.title.toLowerCase(), head = c.heading?.text.toLowerCase() ?? ''
    let score = 1
    if (title.includes(query)) score += 6
    if (head.includes(query)) score += 4
    if (title.startsWith(query) || head.startsWith(query)) score += 2
    const at = c.text.toLowerCase().indexOf(words[0])
    hits.push({ doc: c.doc, heading: c.heading, text: c.text, score, at })
  }
  hits.sort((a, b) => b.score - a.score)
  const seen = new Set<string>()
  return hits.filter((h) => { const k = h.doc.slug + (h.heading?.id ?? ''); if (seen.has(k)) return false; seen.add(k); return true }).slice(0, limit)
}
