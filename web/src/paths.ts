/** Every URL the prerenderer writes, in sitemap order. */
import { COMPETITORS } from './data/compare'
import { GUIDES } from './data/guides'
import { DOCS } from './lib/docs'

export function allPaths(): string[] {
  return [
    '/', '/download', '/formats', '/pricing', '/changelog', '/open-source', '/brand', '/contact', '/privacy', '/terms',
    '/compare', ...COMPETITORS.map((c) => `/compare/${c.slug}`),
    '/convert', ...GUIDES.map((g) => `/convert/${g.slug}`),
    ...DOCS.map((d) => d.path),
  ].filter((p, i, a) => a.indexOf(p) === i && !PENDING.has(p))
}

/** Routes registered in App but not built yet are skipped so the prerender never writes a 404 as a page. */
const PENDING = new Set<string>([])
