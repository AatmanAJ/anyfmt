/**
 * Per-page head tags. On the server the prerenderer reads what each page asked for; in the
 * browser the same call updates the document as you navigate.
 */
import { createContext, useContext, useEffect } from 'react'
import { SITE } from './site'

export interface HeadData {
  title: string
  description: string
  path: string
  image?: string
  type?: 'website' | 'article'
  jsonLd?: object | object[]
  noindex?: boolean
}

export const HeadContext = createContext<{ current: HeadData | null } | null>(null)

const fullTitle = (t: string) => (t.includes('anyfmt') ? t : `${t} · anyfmt`)

export function headTags(h: HeadData): string {
  const url = SITE.url + (h.path === '/' ? '/' : h.path.replace(/\/$/, ''))
  const image = h.image ?? `${SITE.url}/og/default.png`
  const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;')
  const ld = h.jsonLd ? (Array.isArray(h.jsonLd) ? h.jsonLd : [h.jsonLd]) : []
  return [
    `<title>${esc(fullTitle(h.title))}</title>`,
    `<meta name="description" content="${esc(h.description)}" />`,
    `<link rel="canonical" href="${url}" />`,
    h.noindex ? '<meta name="robots" content="noindex" />' : '',
    `<meta property="og:type" content="${h.type ?? 'website'}" />`,
    `<meta property="og:site_name" content="anyfmt" />`,
    `<meta property="og:title" content="${esc(fullTitle(h.title))}" />`,
    `<meta property="og:description" content="${esc(h.description)}" />`,
    `<meta property="og:url" content="${url}" />`,
    `<meta property="og:image" content="${image}" />`,
    `<meta name="twitter:card" content="summary_large_image" />`,
    ...ld.map((o) => `<script type="application/ld+json">${JSON.stringify(o).replace(/</g, '\\u003c')}</script>`),
  ].filter(Boolean).join('\n    ')
}

function setMeta(attr: 'name' | 'property', key: string, value: string) {
  let el = document.head.querySelector<HTMLMetaElement>(`meta[${attr}="${key}"]`)
  if (!el) { el = document.createElement('meta'); el.setAttribute(attr, key); document.head.appendChild(el) }
  el.content = value
}

export function useHead(h: HeadData) {
  const ctx = useContext(HeadContext)
  if (ctx) ctx.current = h
  useEffect(() => {
    document.title = fullTitle(h.title)
    setMeta('name', 'description', h.description)
    setMeta('property', 'og:title', fullTitle(h.title))
    setMeta('property', 'og:description', h.description)
  }, [h.title, h.description])
}
