/**
 * Changelog, wheel-sorted. Filter by the three keys (⇧ convert, ⌘ tools, ⌃ actions) or the rest.
 * Each release gets its own object: the box of routes, a rename, the wheel's manners, the day one
 * commit histogram.
 */
import { CircleHalf, Cloud, Key, Lightning, Rss, Wrench } from '@phosphor-icons/react'
import { AnimatePresence, motion, useInView } from 'motion/react'
import { useMemo, useRef, useState } from 'react'
import { AppIcon } from '../components/AppIcon'
import { Flutes } from '../components/Flutes'
import { Page } from '../components/Page'
import { Container, Eyebrow } from '../components/ui'
import catalog from '../data/catalog.json'
import { COMMITS_BY_HOUR, RELEASES, TAGS, type Release, type Tag } from '../data/changelog'
import { useHead } from '../lib/head'
import { EASE, SNAP } from '../lib/hooks'

const fmtDate = (d: string) => (d ? new Date(d + 'T12:00:00Z').toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' }) : 'Coming soon')
const ICON: Partial<Record<Tag, React.ReactNode>> = { cloud: <Cloud size={16} weight="bold" />, design: <CircleHalf size={16} weight="bold" />, perf: <Lightning size={16} weight="bold" />, fix: <Wrench size={16} weight="bold" /> }
const TAG = Object.fromEntries(TAGS.map((t) => [t.id, t])) as Record<Tag, (typeof TAGS)[number]>

/** The entry's key or kind; licence entries get a key, since nothing about them leaves your Mac. */
function TagGlyph({ tag, title }: { tag: Tag; title: string }) {
  const t = TAG[tag]
  const icon = /licen[cs]e/i.test(title) ? <Key size={16} weight="bold" /> : ICON[tag] ?? t.glyph
  return <span aria-hidden className="flex h-7 w-7 shrink-0 items-center justify-center text-[16px] font-semibold text-mute-2">{icon}</span>
}

/* ── hero ──────────────────────────────────────────────────── */

function Hero() {
  return (
    <section className="relative overflow-hidden bg-night text-white">
      <Flutes variant="dark" corner="bl" className="pointer-events-none absolute inset-0" />
      <Container className="relative pb-16 pt-40 lg:pb-24 lg:pt-48">
        <Eyebrow tone="white">Changelog</Eyebrow>
        <h1 className="mt-6 max-w-[1000px] text-[clamp(48px,7vw,112px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">Every build of anyfmt, newest first.</h1>
        <div className="mt-12 flex flex-wrap items-end justify-between gap-8">
          <p className="max-w-[480px] text-[18px] leading-[1.55] text-white/75">Filter by the key you care about: ⇧&nbsp;Shift for formats, ⌘&nbsp;Command for tools, ⌃&nbsp;Control for actions. Dates and counts come from the app's git history.</p>
          <a href="/changelog.xml" className="group inline-flex h-12 items-center gap-2.5 rounded-full bg-white px-5 text-[15px] font-medium text-ink outline-none transition-transform active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-flare">
            <Rss size={17} weight="bold" /> <span className="link-line">Subscribe by RSS</span>
          </a>
        </div>
      </Container>
    </section>
  )
}

/* ── release visuals ───────────────────────────────────────── */

/** A stable pseudo-random tint per cell, so the grid reads as a field, not stripes. */
const cellColour = (i: number) => { const h = (Math.imul(i + 1, 2654435761) >>> 0) % 100; return h < 3 ? '#E4FF3A' : h < 20 ? '#FFB23E' : h < 34 ? '#FF6A1F' : '#FF4A14' }

function BoxVisual() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.3 })
  const n = catalog.counts.routes
  const stats: [string, string][] = [[String(n), 'routes'], [String(catalog.counts.tools), 'tools'], ['6', 'actions'], ['0', 'uploads']]
  return (
    <div ref={ref} className="overflow-hidden rounded-[28px] bg-night p-6 text-white sm:p-8">
      <div className="flex flex-wrap items-end justify-between gap-6">
        <div className="grid grid-cols-4 gap-6 sm:gap-10">
          {stats.map(([v, l]) => <div key={l}><p className="text-[clamp(30px,3.4vw,48px)] font-semibold leading-none tracking-[-0.05em]">{v}</p><p className="mt-1.5 text-[13px] text-white/55">{l}</p></div>)}
        </div>
        <p className="font-mono text-[12px] text-volt">make matrix · {n}/{n} pass</p>
      </div>
      <div className="mt-7 grid gap-[3px] [grid-template-columns:repeat(auto-fill,minmax(7px,1fr))]" aria-label={`${n} of ${n} routes pass`}>
        {Array.from({ length: n }, (_, i) => (
          <span key={i} className="aspect-square rounded-[1.5px] transition-colors duration-500"
            style={{ background: seen ? cellColour(i) : 'rgba(255,255,255,.08)', transitionDelay: seen ? `${Math.min(i * 1.6, 1300)}ms` : '0ms' }} />
        ))}
      </div>
    </div>
  )
}

function RenameVisual() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.6 })
  return (
    <div ref={ref} className="flex flex-col items-start gap-5 rounded-[28px] bg-sand p-6 sm:flex-row sm:items-center sm:gap-6 sm:p-8">
      <AppIcon size={104} uid="cl-rename" className="shrink-0" />
      <div className="min-w-0">
        <p className="text-[13px] text-mute-2">Applications</p>
        <p className="mt-1 flex items-center font-mono text-[clamp(20px,2.4vw,30px)] font-medium tracking-[-0.02em]">
          <span className="relative inline-flex overflow-hidden rounded-md px-1.5 py-0.5" style={{ background: seen ? 'transparent' : '#B4D5FE' }}>
            <AnimatePresence mode="wait" initial={false}>
              {seen ? (
                <motion.span key="new" initial={{ y: 24, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ duration: 0.5, ease: EASE, delay: 0.5 }}>anyfmt<span className="text-flare">.</span>app</motion.span>
              ) : <span key="old">Untitled.app</span>}
            </AnimatePresence>
          </span>
        </p>
        <p className="mt-2 text-[13px] text-mute-2">Bundle id <span className="font-mono">app.anyfmt</span></p>
      </div>
    </div>
  )
}

function MannersVisual() {
  const [lock, setLock] = useState(false)
  return (
    <div className="grid gap-6 rounded-[28px] bg-sand p-6 sm:grid-cols-[auto_1fr] sm:items-center sm:p-8">
      <svg viewBox="-110 -110 220 220" className="mx-auto w-[180px]" aria-hidden>
        {Array.from({ length: 6 }, (_, i) => {
          const n = 6, gap = 0.04, a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap, a1 = a0 + (Math.PI * 2) / n - gap * 2
          const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(1)},${(Math.sin(a) * r).toFixed(1)}`
          const on = i === 1
          const mid = (a0 + a1) / 2
          return (
            <g key={i}>
              <path d={`M${p(100, a0)} A100,100 0 0 1 ${p(100, a1)} L${p(42, a1)} A42,42 0 0 0 ${p(42, a0)} Z`} fill={on ? '#FF4A14' : '#fff'} />
              <text x={Math.cos(mid) * 71} y={Math.sin(mid) * 71} textAnchor="middle" dominantBaseline="central" fontSize="15" fontWeight="600" fill={on ? '#fff' : '#0A0A0A'}>{['JPG', 'WEBP', 'PNG', 'GIF', 'AVIF', 'PDF'][i]}</text>
            </g>
          )
        })}
        <circle r="36" fill="#0A0A0A" />
        <text y="-5" textAnchor="middle" fontSize="12" fill="rgba(255,255,255,.6)">{lock ? 'locked' : 'aiming'}</text>
        <text y="11" textAnchor="middle" fontSize="13" fontWeight="600" fill="#fff">WEBP</text>
      </svg>
      <div>
        <p className="text-[14px] font-semibold">Presets on the WEBP segment</p>
        <ul className="mt-3 flex flex-wrap gap-2">
          {[['Small · 60 %', '412 KB'], ['Best · 90 %', '1.3 MB'], ['Last used', '780 KB']].map(([t, s]) => (
            <li key={t} className="flex items-center gap-2 rounded-full bg-white py-1.5 pl-3 pr-1.5 text-[14px] font-medium ring-1 ring-black/10">{t}<span className="rounded-full bg-sand-2 px-2 py-0.5 font-mono text-[12px]">{s}</span></li>
          ))}
        </ul>
        <button type="button" onClick={() => setLock((l) => !l)} aria-pressed={lock}
          className="mt-4 inline-flex h-10 items-center gap-2 rounded-full bg-white px-4 text-[14px] font-medium ring-1 ring-black/10 outline-none transition-colors hover:bg-volt focus-visible:ring-2 focus-visible:ring-flare">
          <span className={`inline-flex h-6 min-w-6 items-center justify-center rounded-[6px] text-[13px] transition-[transform,background-color,color] duration-200 ${lock ? 'translate-y-[2px] bg-ink text-white' : 'bg-sand-2 shadow-[0_2px_0_#D9D4CE]'}`}>⌥</span>
          {lock ? 'Locked. Tap again to aim' : 'Tap Option to lock the segment'}
        </button>
        <p className="mt-3 text-[13px] text-mute-2">Sizes shown are illustrative. In the app each chip shows the estimate for your file.</p>
      </div>
    </div>
  )
}

function DayOneVisual() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.4 })
  const max = Math.max(...COMMITS_BY_HOUR.map((h) => h.n))
  const total = COMMITS_BY_HOUR.reduce((a, h) => a + h.n, 0)
  return (
    <div ref={ref} className="rounded-[28px] bg-sand p-6 sm:p-8">
      <div className="flex flex-wrap items-baseline justify-between gap-3">
        <p className="text-[14px] font-semibold">Commits per hour, 18 October</p>
        <p className="text-[14px] text-mute"><span className="font-semibold text-ink">{total}</span> commits · <span className="inline-block h-2 w-2 rounded-sm bg-flare align-middle" /> Build 1 · <span className="inline-block h-2 w-2 rounded-sm bg-ink align-middle" /> Build 2</p>
      </div>
      <div className="mt-6 flex h-[170px] items-end gap-1.5 sm:gap-2.5">
        {COMMITS_BY_HOUR.map((h, i) => (
          <div key={h.hour} className="flex h-full flex-1 flex-col items-center justify-end gap-2">
            <span className={`text-[12px] font-medium tabular-nums transition-opacity duration-500 ${seen && h.n ? 'opacity-100' : 'opacity-0'}`} style={{ transitionDelay: `${300 + i * 60}ms` }}>{h.n || ''}</span>
            <span className={`w-full rounded-t-[6px] ${h.hour < 16 ? 'bg-flare' : 'bg-ink'}`}
              style={{ height: seen ? `${Math.max(2, (h.n / max) * 130)}px` : '2px', transition: `height .9s ${SNAP} ${i * 60}ms` }} />
            <span className="text-[12px] tabular-nums text-mute-2">{h.hour}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

const VISUAL: Record<Release['visual'], () => React.ReactElement> = { box: BoxVisual, rename: RenameVisual, manners: MannersVisual, dayone: DayOneVisual }

/* ── releases ─────────────────────────────────────────────── */

function ReleaseBlock({ r, filter }: { r: Release; filter: Tag | null }) {
  const entries = filter ? r.entries.filter((e) => e.tag === filter) : r.entries
  const Visual = VISUAL[r.visual]
  const id = r.version.toLowerCase().replace(/\s+/g, '-')
  return (
    <article id={id} className="grid scroll-mt-40 gap-8 border-t border-line py-16 lg:grid-cols-[300px_minmax(0,1fr)] lg:gap-16 lg:py-24">
      <header className="lg:sticky lg:top-44 lg:self-start">
        <p className="font-wordmark text-[clamp(56px,6vw,88px)] font-bold leading-[0.85] tracking-[-0.04em]">{r.version}</p>
        <div className="mt-4 flex flex-wrap items-center gap-2.5">
          <span className={`rounded-full px-2.5 py-1 text-[12px] font-semibold ${r.status === 'upcoming' ? 'bg-volt text-ink' : 'bg-sand-2 text-mute'}`}>{r.status === 'upcoming' ? 'Upcoming' : 'Pre-release build'}</span>
          {r.date && <time dateTime={r.date} className="text-[14px] tabular-nums text-mute-2">{fmtDate(r.date)}</time>}
        </div>
      </header>
      <div className="min-w-0">
        <h2 className="text-[clamp(28px,3vw,44px)] font-semibold leading-[1.04] tracking-[-0.04em] [text-wrap:balance]">{r.title}</h2>
        <p className="mt-4 max-w-[640px] text-[17.5px] leading-[1.55] text-mute">{r.summary}</p>
        <div className="mt-8"><Visual /></div>
        <motion.ul layout className="mt-10 flex flex-col">
          <AnimatePresence initial={false} mode="popLayout">
            {entries.map((e) => (
              <motion.li layout key={e.title} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.98 }} transition={{ duration: 0.35, ease: EASE }}
                className="flex gap-4 border-b border-line py-5 last:border-0">
                <TagGlyph tag={e.tag} title={e.title} />
                <div className="min-w-0">
                  <h3 className="text-[18px] font-semibold tracking-[-0.02em] [&_code]:rounded [&_code]:bg-sand-2 [&_code]:px-1 [&_code]:font-mono [&_code]:text-[0.85em] [&_code]:font-medium">{renderTicks(e.title)}</h3>
                  {e.body && <p className="mt-1.5 max-w-[620px] text-[16px] leading-[1.55] text-mute [&_code]:rounded [&_code]:bg-sand-2 [&_code]:px-1 [&_code]:font-mono [&_code]:text-[0.88em]">{renderTicks(e.body)}</p>}
                </div>
              </motion.li>
            ))}
            {entries.length === 0 && (
              <motion.li key="none" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="py-5 text-[15px] text-mute-2">Nothing for {TAG[filter!].label.toLowerCase()} in this build.</motion.li>
            )}
          </AnimatePresence>
        </motion.ul>
      </div>
    </article>
  )
}

/** `code` spans in entry bodies. */
function renderTicks(s: string) {
  return s.split(/(`[^`]+`)/).map((part, i) => (part.startsWith('`') ? <code key={i}>{part.slice(1, -1)}</code> : part))
}

function FilterBar({ value, onChange }: { value: Tag | null; onChange: (t: Tag | null) => void }) {
  const counts = useMemo(() => Object.fromEntries(TAGS.map((t) => [t.id, RELEASES.reduce((n, r) => n + r.entries.filter((e) => e.tag === t.id).length, 0)])), [])
  return (
    <div className="sticky top-[84px] z-30 -mx-5 border-b border-line bg-white px-5 py-4 sm:-mx-10 sm:px-10 lg:-mx-14 lg:px-14">
      <div role="toolbar" aria-label="Filter by kind of change" className="flex gap-2 overflow-x-auto no-scrollbar [mask-image:linear-gradient(90deg,#000_calc(100%-28px),transparent)] lg:[mask-image:none]">
        <button type="button" aria-pressed={value === null} onClick={() => onChange(null)}
          className={`h-10 shrink-0 rounded-full px-4 text-[14.5px] font-medium outline-none ring-1 transition-colors focus-visible:ring-2 focus-visible:ring-flare ${value === null ? 'bg-ink text-white ring-ink' : 'bg-white ring-black/10 hover:bg-sand'}`}>Everything</button>
        {TAGS.map((t) => (
          <button key={t.id} type="button" aria-pressed={value === t.id} onClick={() => onChange(value === t.id ? null : t.id)}
            className={`flex h-10 shrink-0 items-center gap-2 rounded-full px-4 text-[14.5px] font-medium outline-none ring-1 transition-colors focus-visible:ring-2 focus-visible:ring-flare ${value === t.id ? 'bg-ink text-white ring-ink' : 'bg-white ring-black/10 hover:bg-sand'}`}>
            {t.key && <span aria-hidden>{t.glyph}</span>}{t.label}<span className={value === t.id ? 'text-white/65' : 'text-mute-2'}>{counts[t.id]}</span>
          </button>
        ))}
      </div>
    </div>
  )
}

export default function Changelog() {
  const [filter, setFilter] = useState<Tag | null>(null)
  useHead({
    title: 'Changelog',
    description: 'Every anyfmt build, newest first: formats, tools, actions, the command line, cloud and design changes, with dates.',
    path: '/changelog',
  })
  return (
    <Page nav="dark">
      <Hero />
      <section className="bg-white pb-16">
        <Container>
          <FilterBar value={filter} onChange={setFilter} />
          {RELEASES.map((r) => <ReleaseBlock key={r.version} r={r} filter={filter} />)}
        </Container>
      </section>
    </Page>
  )
}
