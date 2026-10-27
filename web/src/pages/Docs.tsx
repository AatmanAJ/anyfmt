/**
 * Docs: sidebar of sections, the page, and a rail with the live table of contents and an
 * "ask your agent" card. Every page has Copy for AI. /docs adds five doors before the overview.
 */
import { ArrowLeft, ArrowRight, List, MagnifyingGlass, ThumbsDown, ThumbsUp, X } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Link, useLocation, useParams } from 'react-router-dom'
import { CopyForAI } from '../components/docs/CopyForAI'
import { Markdown } from '../components/docs/Markdown'
import { SearchPalette, useSearchHotkey } from '../components/docs/SearchPalette'
import { Page } from '../components/Page'
import { CopyButton, Kbd } from '../components/ui'
import { DOC, DOC_SECTIONS, DOCS, tokensOf, type Doc } from '../lib/docs'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import NotFound from './NotFound'

function Sidebar({ current, onSearch }: { current: string; onSearch: () => void }) {
  return (
    <nav aria-label="Docs" className="flex flex-col gap-8">
      <button type="button" onClick={onSearch}
        className="flex h-11 w-full items-center gap-2.5 rounded-full bg-sand px-4 text-left text-[15px] text-mute-2 outline-none ring-1 ring-transparent transition-colors hover:text-ink hover:ring-black/10 focus-visible:ring-2 focus-visible:ring-flare">
        <MagnifyingGlass size={16} aria-hidden /> <span className="flex-1">Search docs</span>
        <kbd className="hidden rounded-md bg-white px-1.5 py-0.5 font-sans text-[12px] font-semibold text-mute ring-1 ring-black/10 sm:inline-block">⌘K</kbd>
      </button>
      {DOC_SECTIONS.map((s) => (
        <div key={s.title}>
          <p className="px-3 text-[14px] font-semibold text-ink">{s.title}</p>
          <ul className="mt-2 flex flex-col">
            {s.items.map(([slug, label]) => {
              const d = DOC[slug]
              const on = slug === current
              const to = slug === 'index' ? '/docs' : `/docs/${slug}`
              return (
                <li key={slug} className="relative">
                  {on && <motion.span layoutId="doc-active" className="absolute inset-0 rounded-[10px] bg-sand-2" transition={{ type: 'spring', stiffness: 500, damping: 40 }} />}
                  <Link to={to} aria-current={on ? 'page' : undefined}
                    className={`relative flex items-center justify-between gap-2 rounded-[10px] px-3 py-[7px] text-[15px] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare ${on ? 'font-medium text-ink' : d ? 'text-mute hover:bg-sand hover:text-ink' : 'text-mute-3'}`}>
                    {label}
                    {on && <span className="h-1.5 w-1.5 rounded-full bg-flare" />}
                  </Link>
                </li>
              )
            })}
          </ul>
        </div>
      ))}
    </nav>
  )
}

/** Which heading is under the reading line. */
function useActiveHeading(ids: string[]) {
  const [active, setActive] = useState(ids[0] ?? '')
  useEffect(() => {
    let raf = 0
    const on = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        let cur = ids[0] ?? ''
        for (const id of ids) { const el = document.getElementById(id); if (el && el.getBoundingClientRect().top < 150) cur = id }
        setActive(cur)
      })
    }
    on()
    window.addEventListener('scroll', on, { passive: true })
    return () => { window.removeEventListener('scroll', on); cancelAnimationFrame(raf) }
  }, [ids])
  return active
}

function Toc({ doc }: { doc: Doc }) {
  const ids = doc.headings.map((h) => h.id)
  const active = useActiveHeading(ids)
  if (!doc.headings.length) return null
  return (
    <nav aria-label="On this page">
      <p className="text-[14px] font-semibold text-ink">On this page</p>
      <ul className="relative mt-3 border-l border-line">
        {doc.headings.map((h) => (
          <li key={h.id} className="relative">
            {active === h.id && <motion.span layoutId="toc-bar" className="absolute -left-px top-1 bottom-1 w-[2px] bg-flare" transition={{ type: 'spring', stiffness: 500, damping: 40 }} />}
            <a href={`#${h.id}`} className={`block rounded-sm py-1.5 text-[14px] leading-[1.35] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare ${h.depth === 3 ? 'pl-7' : 'pl-4'} ${active === h.id ? 'font-medium text-ink' : 'text-mute-2 hover:text-ink'}`}>{h.text}</a>
          </li>
        ))}
      </ul>
    </nav>
  )
}

function AgentCard() {
  const cmd = 'claude mcp add anyfmt -- anyfmt mcp'
  return (
    <div className="rounded-[20px] bg-night p-5 text-white">
      <p className="text-[15px] font-semibold">Give your agent anyfmt</p>
      <p className="mt-1.5 text-[14px] leading-[1.5] text-white/70">Conversions on your Mac, through MCP. No network, no key.</p>
      <div className="mt-4 rounded-[12px] bg-white/[0.07] p-3">
        <code className="block font-mono text-[13px] leading-[1.6] text-white/90"><span aria-hidden className="text-flare">$ </span><span className="whitespace-nowrap">claude mcp add anyfmt</span> <span className="whitespace-nowrap">-- anyfmt mcp</span></code>
        <CopyButton text={cmd} tone="dark" className="mt-3" />
      </div>
      <Link to="/docs/mcp" className="mt-3 inline-flex items-center gap-1 rounded-sm text-[14px] font-medium text-white underline decoration-white/30 underline-offset-4 outline-none transition-colors hover:decoration-white focus-visible:ring-2 focus-visible:ring-flare">Codex, Cursor and other clients</Link>
    </div>
  )
}

/** Five ways in, each with the thing you'd actually type or press. */
const DOORS: { to: string; title: string; text: string; cue: ReactNode }[] = [
  { to: '/docs/first-conversion', title: 'Use the app', text: 'The wheel, the three keys, options and presets.', cue: <span className="inline-flex gap-1.5 py-0.5 text-[16px] sm:justify-end">{['⇧', '⌘', '⌃'].map((k) => <Kbd key={k} className="min-w-[1.9em] py-1 text-ink">{k}</Kbd>)}</span> },
  { to: '/docs/cli', title: 'Script it', text: 'anyfmt in Terminal, JSON on every command, stable exit codes.', cue: <code className="block truncate font-mono text-[13.5px]">anyfmt convert IMG_0042.heic --to jpg</code> },
  { to: '/docs/mcp', title: 'Give it to an agent', text: 'A local MCP server with seven tools. No network, no key.', cue: <code className="block truncate font-mono text-[13.5px]">claude mcp add anyfmt -- anyfmt mcp</code> },
  { to: '/docs/api', title: 'Call the HTTP API', text: 'The same routes over HTTP, paid per conversion. In preview.', cue: <code className="block truncate font-mono text-[13.5px]">POST /v1/conversions</code> },
  { to: '/docs/self-host', title: 'Run your own server', text: 'Share links, sync and the inbox on your own hardware.', cue: <span className="text-[13.5px]">Settings › Account › Server URL</span> },
]

function Doors() {
  return (
    <ul className="mb-4 mt-10 divide-y divide-line border-y border-line">
      {DOORS.map((d) => (
        <li key={d.to}>
          <Link to={d.to} className="group -mx-3 grid items-center gap-x-6 gap-y-2 rounded-[14px] px-3 py-5 outline-none transition-colors hover:bg-sand focus-visible:ring-2 focus-visible:ring-flare sm:grid-cols-[minmax(0,1fr)_auto_20px]">
            <span className="min-w-0">
              <span className="block text-[19px] font-semibold tracking-[-0.02em]">{d.title}</span>
              <span className="mt-1 block text-[15px] leading-[1.45] text-mute">{d.text}</span>
            </span>
            <span className="min-w-0 text-mute sm:max-w-[300px] sm:text-right">{d.cue}</span>
            <ArrowRight size={16} aria-hidden className="hidden transition-transform duration-300 group-hover:translate-x-1 sm:block" />
          </Link>
        </li>
      ))}
    </ul>
  )
}

function Helpful() {
  const [v, setV] = useState<null | boolean>(null)
  return (
    <div className="flex flex-wrap items-center gap-3 text-[15px] text-mute">
      <span>{v === null ? 'Was this page useful?' : v ? 'Thanks. Glad it helped.' : <>Thanks. Tell us what was missing at <Link to="/contact" className="text-ink underline decoration-flare/60 underline-offset-2">contact</Link>.</>}</span>
      {v === null && (
        <span className="flex gap-1.5">
          <button type="button" onClick={() => setV(true)} aria-label="Yes, it was useful" className="flex h-9 w-9 items-center justify-center rounded-full bg-sand-2 outline-none transition-colors hover:bg-volt focus-visible:ring-2 focus-visible:ring-flare"><ThumbsUp size={16} /></button>
          <button type="button" onClick={() => setV(false)} aria-label="No, something was missing" className="flex h-9 w-9 items-center justify-center rounded-full bg-sand-2 outline-none transition-colors hover:bg-[#FFE1D6] focus-visible:ring-2 focus-visible:ring-flare"><ThumbsDown size={16} /></button>
        </span>
      )}
    </div>
  )
}

function PrevNext({ doc }: { doc: Doc }) {
  const i = DOCS.findIndex((d) => d.slug === doc.slug)
  const prev = DOCS[i - 1], next = DOCS[i + 1]
  return (
    <div className="grid gap-3 sm:grid-cols-2">
      {prev ? (
        <Link to={prev.path} className="group rounded-[20px] p-5 outline-none ring-1 ring-line transition-colors hover:bg-sand focus-visible:ring-2 focus-visible:ring-flare">
          <span className="flex items-center gap-1.5 text-[14px] text-mute-2"><ArrowLeft size={13} className="transition-transform group-hover:-translate-x-1" />Previous</span>
          <span className="mt-1 block text-[17px] font-semibold tracking-[-0.02em]">{prev.label}</span>
        </Link>
      ) : <span />}
      {next && (
        <Link to={next.path} className="group rounded-[20px] p-5 text-right outline-none ring-1 ring-line transition-colors hover:bg-sand focus-visible:ring-2 focus-visible:ring-flare">
          <span className="flex items-center justify-end gap-1.5 text-[14px] text-mute-2">Next<ArrowRight size={13} className="transition-transform group-hover:translate-x-1" /></span>
          <span className="mt-1 block text-[17px] font-semibold tracking-[-0.02em]">{next.label}</span>
        </Link>
      )}
    </div>
  )
}

export default function DocsPage() {
  const { slug = 'index' } = useParams()
  const { pathname } = useLocation()
  const doc = DOC[slug]
  const [search, setSearch] = useState(false)
  const [menu, setMenu] = useState(false)
  const sheet = useRef<HTMLDivElement>(null)
  useSearchHotkey(setSearch)
  useEffect(() => setMenu(false), [pathname])

  useHead(doc ? {
    title: doc.slug === 'index' ? 'Docs' : `${doc.title} · Docs`,
    description: doc.description,
    path: doc.path,
    type: 'article',
    jsonLd: {
      '@context': 'https://schema.org', '@type': 'TechArticle', headline: doc.title, description: doc.description, url: `https://anyfmt.app${doc.path}`,
      isPartOf: { '@type': 'WebSite', name: 'anyfmt docs', url: 'https://anyfmt.app/docs' }, about: { '@type': 'SoftwareApplication', name: 'anyfmt' },
    },
  } : { title: 'Docs', description: 'anyfmt documentation', path: pathname, noindex: true })

  if (!doc) return DOCS.length ? <NotFound /> : <Page><div className="px-5 pb-40 pt-44 text-center text-mute">The docs are being written.</div></Page>

  return (
    <Page>
      <SearchPalette open={search} onClose={() => setSearch(false)} />
      <div className="mx-auto grid max-w-[1520px] gap-10 px-5 pb-10 pt-28 sm:px-10 lg:grid-cols-[250px_minmax(0,1fr)] lg:px-14 lg:pt-32 xl:grid-cols-[250px_minmax(0,1fr)_250px] xl:gap-14">
        <aside className="hidden lg:block">
          <div className="sticky top-28 max-h-[calc(100svh-8rem)] overflow-y-auto pb-10 pr-2 no-scrollbar"><Sidebar current={slug} onSearch={() => setSearch(true)} /></div>
        </aside>

        <article className="min-w-0">
          {/* phones and tablets: section menu and search */}
          <div className="sticky top-[84px] z-20 -mx-5 mb-6 flex gap-2 bg-white px-5 py-2 sm:-mx-10 sm:px-10 lg:hidden">
            <button type="button" onClick={() => setMenu(true)} className="flex h-10 min-w-0 items-center gap-2 rounded-full bg-sand px-4 text-[15px] font-medium outline-none focus-visible:ring-2 focus-visible:ring-flare"><List size={16} className="shrink-0" aria-hidden /><span className="truncate">{doc.section}</span></button>
            <button type="button" onClick={() => setSearch(true)} aria-label="Search docs" className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sand outline-none focus-visible:ring-2 focus-visible:ring-flare"><MagnifyingGlass size={16} /></button>
          </div>

          <div className="mx-auto max-w-[700px]">
            <p className="flex items-center gap-2 text-[14px] text-mute-2"><Link to="/docs" className="rounded-sm outline-none hover:text-ink focus-visible:ring-2 focus-visible:ring-flare">Docs</Link><span aria-hidden>/</span><span>{doc.section}</span></p>
            <motion.h1 key={doc.slug} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, ease: EASE }}
              className="mt-4 text-[clamp(36px,4.4vw,58px)] font-semibold leading-[1.02] tracking-[-0.045em] [text-wrap:balance]">{doc.slug === 'index' ? 'anyfmt docs' : doc.title}</motion.h1>
            {doc.description && <p className="mt-4 max-w-[640px] text-[clamp(17px,1.4vw,19px)] leading-[1.5] text-mute">{doc.description}</p>}
            <div className="mt-7 flex flex-wrap items-center gap-3">
              <CopyForAI doc={doc} />
              <span className="text-[14px] text-mute-2">{Math.max(1, Math.round(doc.body.split(/\s+/).length / 220))} min read · about {(tokensOf(doc.body) / 1000).toFixed(1)}k tokens</span>
            </div>
            {doc.slug === 'index' && <Doors />}
            <div className="mt-10"><Markdown source={doc.body} /></div>
            <div className="mt-16 space-y-8 border-t border-line pt-8">
              <Helpful />
              <PrevNext doc={doc} />
            </div>
          </div>
        </article>

        <aside className="hidden xl:block">
          <div className="sticky top-28 flex max-h-[calc(100svh-8rem)] flex-col gap-8 overflow-y-auto pb-10 no-scrollbar">
            <Toc doc={doc} />
            {/* the overview and MCP pages already show this command in their body */}
            {doc.slug !== 'index' && doc.slug !== 'mcp' && <AgentCard />}
          </div>
        </aside>
      </div>

      <AnimatePresence>
        {menu && (
          <motion.div className="fixed inset-0 z-50 lg:hidden" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} role="dialog" aria-modal="true" aria-label="Docs menu">
            <button type="button" aria-label="Close" onClick={() => setMenu(false)} className="absolute inset-0 bg-ink/50" />
            <motion.div initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }} transition={{ duration: 0.5, ease: [0.32, 0.72, 0, 1] }}
              onAnimationComplete={(def) => {
                // bring the current page into view inside the sheet, without moving the page behind it
                const box = sheet.current, el = box?.querySelector('[aria-current="page"]')
                if ((def as { y?: unknown }).y === 0 && box && el) box.scrollTop += el.getBoundingClientRect().top - box.getBoundingClientRect().top - box.clientHeight / 2
              }}
              ref={sheet} className="absolute inset-x-2 bottom-2 max-h-[86svh] overflow-y-auto rounded-[28px] bg-white p-6 pb-[max(24px,env(safe-area-inset-bottom))]">
              <div className="mb-5 flex items-center justify-between"><p className="text-[22px] font-semibold tracking-[-0.03em]">Docs</p><button type="button" onClick={() => setMenu(false)} aria-label="Close" className="flex h-10 w-10 items-center justify-center rounded-full bg-sand-2 outline-none focus-visible:ring-2 focus-visible:ring-flare"><X size={16} weight="bold" /></button></div>
              <Sidebar current={slug} onSearch={() => { setMenu(false); setSearch(true) }} />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </Page>
  )
}
