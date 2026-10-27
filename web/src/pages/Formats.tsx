/**
 * The route atlas. Pick any format and the wheel shows what it becomes, ring by ring, exactly as
 * the app lays it out (eight on the first ring, up to twelve more on the second). Below, every
 * route at once as a matrix, then the formats in plain lists for reading and for search engines.
 * All of it is generated from `anyfmt schema --json`.
 */
import { ArrowRight, CaretDown, MagnifyingGlass } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Page } from '../components/Page'
import { Container, Eyebrow } from '../components/ui'
import catalog from '../data/catalog.json'
import { GUIDES } from '../data/guides'
import { useHead } from '../lib/head'

type Format = (typeof catalog.formats)[number]
type Target = Format['targets'][number]
const F = Object.fromEntries(catalog.formats.map((f) => [f.id, f])) as Record<string, Format>
const ENG = catalog.engines as Record<string, { name: string; by: string; what: string }>
const engineNames = (t: Target) => [...new Set(t.engines.map((e) => ENG[e]?.name ?? e))].join(' → ')

/* ── the explorer ──────────────────────────────────────────── */

/** The picker groups the twelve kinds into six shelves, so each shelf holds a handful of formats. */
const SHELVES: { name: string; kinds: string[] }[] = [
  { name: 'Images', kinds: ['image', 'vector'] },
  { name: 'Video', kinds: ['video'] },
  { name: 'Audio', kinds: ['audio'] },
  { name: 'Documents', kinds: ['document', 'pdf', 'slides', 'ebook'] },
  { name: 'Spreadsheets', kinds: ['spreadsheet'] },
  { name: 'Archives and more', kinds: ['archive', 'subtitle', 'folder'] },
]
const shelfOf = (id: string) => SHELVES.findIndex((s) => s.kinds.includes(F[id].kind))
const GUIDE = Object.fromEntries(GUIDES.filter((g) => g.kind === 'convert').flatMap((g) => g.from.map((f) => [`${f}>${g.to}`, g.slug])))

const RINGS = [{ r0: 70, r1: 160 }, { r0: 166, r1: 218 }]

function arc(r0: number, r1: number, a0: number, a1: number) {
  const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(2)},${(Math.sin(a) * r).toFixed(2)}`
  const big = a1 - a0 > Math.PI ? 1 : 0
  return `M${p(r1, a0)} A${r1},${r1} 0 ${big} 1 ${p(r1, a1)} L${p(r0, a1)} A${r0},${r0} 0 ${big} 0 ${p(r0, a0)} Z`
}

/** The wheel exactly as the app lays it out: up to eight on the first ring, up to twelve more on the second. */
function Wheel({ f, hot, setHot }: { f: Format; hot: string | null; setHot: (id: string | null) => void }) {
  const onWheel = f.targets.filter((t) => t.wheel)
  const rings = [onWheel.slice(0, 8), onWheel.slice(8, 20)].filter((r) => r.length)
  const hotT = f.targets.find((t) => t.to === hot)
  return (
    <svg viewBox="-230 -230 460 460" className="h-auto w-full max-w-[460px] select-none" role="img" aria-label={`${f.label} converts on the wheel to ${onWheel.map((t) => F[t.to]?.label).join(', ')}`}>
      <defs>
        <linearGradient id="fx-heat" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stopColor="#E8160C" /><stop offset="0.6" stopColor="#FF4A14" /><stop offset="1" stopColor="#FF9A3C" /></linearGradient>
      </defs>
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.g key={f.id} initial={{ rotate: -20, scale: 0.9, opacity: 0 }} animate={{ rotate: 0, scale: 1, opacity: 1 }} exit={{ rotate: 14, scale: 0.94, opacity: 0, transition: { duration: 0.18 } }} transition={{ type: 'spring', stiffness: 260, damping: 28 }}>
          {rings.map((ring, ri) => {
            const { r0, r1 } = RINGS[ri]
            const n = ri === 0 ? ring.length : 12
            const first = ri === 0 ? 0 : -(ring.length - 1) / 2
            const gap = ri === 0 ? 0.02 : 0.012
            return ring.map((t, j) => {
              const i = j + first
              const a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap
              const a1 = a0 + (Math.PI * 2) / n - gap * 2
              const mid = (a0 + a1) / 2, rm = (r0 + r1) / 2
              const on = hot === t.to
              const label = F[t.to]?.label ?? t.to
              const size = ri === 0 ? (label.length > 4 ? 15 : 18) : label.length > 4 ? 12 : 13
              return (
                <g key={t.to} onPointerEnter={() => setHot(t.to)} onPointerLeave={() => setHot(null)}>
                  <path d={arc(r0, r1, a0, a1)} fill={on ? 'url(#fx-heat)' : '#FFFFFF'} stroke={on ? 'none' : 'rgba(10,10,10,.09)'} strokeWidth={1} style={{ transition: 'fill .18s' }} />
                  <text x={Math.cos(mid) * rm} y={Math.sin(mid) * rm} textAnchor="middle" dominantBaseline="central" fontSize={size} fontWeight="600" fill={on ? '#fff' : '#0A0A0A'} style={{ pointerEvents: 'none', letterSpacing: '-0.01em' }}>{label}</text>
                  {t.via.length > 0 && <circle cx={Math.cos(mid) * (r1 - 10)} cy={Math.sin(mid) * (r1 - 10)} r={2.6} fill={on ? '#fff' : '#FF4A14'} />}
                </g>
              )
            })
          })}
        </motion.g>
      </AnimatePresence>
      <circle r={62} fill="#0A0A0A" />
      <text y={-14} textAnchor="middle" fontSize="12" fill="rgba(255,255,255,.6)">{hotT ? `${f.label} to` : 'convert'}</text>
      <text y={8} textAnchor="middle" fontSize="20" fontWeight="700" fill="#fff" style={{ letterSpacing: '-0.02em' }}>{hotT ? F[hotT.to]?.label : f.label}</text>
      {hotT && !hotT.wheel && <text y={28} textAnchor="middle" fontSize="12" fill="#FF8A5B">opt-in</text>}
    </svg>
  )
}

function Picker({ sel, onPick }: { sel: string; onPick: (id: string) => void }) {
  const [shelf, setShelf] = useState(() => shelfOf(sel))
  const [q, setQ] = useState('')
  const clean = q.trim().toLowerCase().replace(/^\./, '')
  const exact = (f: Format) => f.id === clean || f.extensions.includes(clean)
  const found = clean ? catalog.formats.filter((f) => f.targets.length && (f.id.includes(clean) || f.label.toLowerCase().includes(clean) || f.name.toLowerCase().includes(clean) || f.extensions.some((e) => e.startsWith(clean))))
    .sort((a, b) => Number(exact(b)) - Number(exact(a))) : null
  const list = found ?? catalog.formats.filter((f) => f.targets.length && SHELVES[shelf].kinds.includes(f.kind))
  return (
    <div>
      <div className="flex flex-wrap items-center gap-2">
        <div role="tablist" aria-label="Kind of file" className="flex flex-wrap gap-1.5">
          {SHELVES.map((s, i) => (
            <button key={s.name} type="button" role="tab" aria-selected={!found && shelf === i} onClick={() => { setShelf(i); setQ('') }}
              className={`h-10 rounded-full px-4 text-[14.5px] font-medium outline-none transition-colors duration-200 focus-visible:ring-2 focus-visible:ring-flare ${!found && shelf === i ? 'bg-ink text-white' : 'bg-white text-ink ring-1 ring-black/10 hover:bg-sand-2'}`}>{s.name}</button>
          ))}
        </div>
        <label className="flex h-10 min-w-[180px] flex-1 items-center gap-2 rounded-full bg-white px-4 ring-1 ring-black/10 focus-within:ring-2 focus-within:ring-flare sm:max-w-[240px]">
          <MagnifyingGlass size={16} className="shrink-0 text-mute-2" aria-hidden />
          <input value={q} onChange={(e) => setQ(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter' && list[0]) { onPick(list[0].id); setShelf(shelfOf(list[0].id)); setQ('') } }}
            placeholder="Find .heic, .mkv…" aria-label="Find a format by extension" className="h-full min-w-0 flex-1 bg-transparent text-[15px] outline-none placeholder:text-mute-2" />
        </label>
      </div>
      <ul className="mt-5 flex min-h-[48px] flex-wrap gap-2" aria-label="Formats">
        {list.map((f) => (
          <li key={f.id}>
            <button type="button" onClick={() => { onPick(f.id); setShelf(shelfOf(f.id)); setQ('') }} aria-pressed={sel === f.id}
              className={`h-11 rounded-[12px] px-3.5 text-[14.5px] font-semibold tracking-[0.01em] outline-none transition-[background-color,color,box-shadow] duration-200 focus-visible:ring-2 focus-visible:ring-flare ${sel === f.id ? 'bg-ink text-white' : 'bg-white text-ink ring-1 ring-black/10 hover:ring-black/30'}`}>{f.label}</button>
          </li>
        ))}
        {list.length === 0 && <li className="py-3 text-[15px] text-mute">No format matches “{q}”. anyfmt reads the {catalog.counts.inputs} formats on this page.</li>}
      </ul>
    </div>
  )
}

function Route({ from, t, hot, setHot }: { from: Format; t: Target; hot: string | null; setHot: (id: string | null) => void }) {
  const to = F[t.to]
  const guide = GUIDE[`${from.id}>${t.to}`]
  const on = hot === t.to
  const body = (
    <>
      <span className="w-[56px] shrink-0 text-[15px] font-semibold">{to?.label}</span>
      <span className="min-w-0 flex-1 truncate text-[15px]">{to?.name}{t.via.length > 0 && <span className="text-mute-2"> · via {t.via.map((v) => F[v]?.label).join(', ')}</span>}</span>
      <span className="hidden shrink-0 text-[13.5px] text-mute-2 sm:block">{engineNames(t)}</span>
      <span className="flex w-[60px] shrink-0 items-center justify-end gap-1 text-[13.5px] font-medium">{guide && <>Guide<ArrowRight size={13} weight="bold" aria-hidden /></>}</span>
    </>
  )
  const cls = `flex h-11 w-full items-center gap-3 rounded-[12px] px-3 text-left outline-none transition-colors duration-150 focus-visible:ring-2 focus-visible:ring-flare ${on ? 'bg-sand-2' : ''}`
  const events = { onPointerEnter: () => setHot(t.to), onPointerLeave: () => setHot(null), onFocus: () => setHot(t.to), onBlur: () => setHot(null) }
  return <li>{guide ? <Link to={`/convert/${guide}`} className={cls} {...events}>{body}</Link> : <div tabIndex={0} className={cls} {...events}>{body}</div>}</li>
}

function Explorer() {
  const [sel, setSel] = useState('heic')
  const [hot, setHot] = useState<string | null>(null)
  const [more, setMore] = useState(false)
  const f = F[sel]
  const onWheel = f.targets.filter((t) => t.wheel)
  const optIn = f.targets.filter((t) => !t.wheel)
  return (
    <div>
      <Picker sel={sel} onPick={(id) => { setSel(id); setHot(null); setMore(false) }} />
      <div className="mt-8 overflow-hidden rounded-[28px] bg-white ring-1 ring-black/[.07]">
        <div className="flex flex-wrap items-end justify-between gap-x-8 gap-y-3 border-b border-line px-6 py-6 sm:px-8">
          <div>
            <p className="text-[clamp(28px,3vw,40px)] font-semibold leading-none tracking-[-0.04em]">{f.name}</p>
            <p className="mt-2 font-mono text-[14px] text-mute-2">{f.extensions.map((e) => `.${e}`).join('  ')}</p>
          </div>
          <p className="text-[15px] text-mute"><strong className="font-semibold text-ink">{onWheel.length}</strong> on the wheel{optIn.length ? <>, <strong className="font-semibold text-ink">{optIn.length}</strong> more you can switch on</> : null}</p>
        </div>
        <div className="grid lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)]">
          <div className="flex items-center justify-center bg-sand p-6 sm:p-10 lg:border-r lg:border-line"><Wheel f={f} hot={hot} setHot={setHot} /></div>
          <div className="p-3 sm:p-5">
            <p className="px-3 pb-2 pt-3 text-[14px] font-semibold">On the wheel <span className="font-normal text-mute-2">· one drag, tap Shift</span></p>
            <ul>{onWheel.map((t) => <Route key={t.to} from={f} t={t} hot={hot} setHot={setHot} />)}</ul>
            {optIn.length > 0 && (
              <div className="mt-3 border-t border-line pt-3">
                <button type="button" aria-expanded={more} onClick={() => setMore(!more)}
                  className="group flex h-11 w-full items-center justify-between rounded-[12px] px-3 text-left text-[14px] outline-none hover:bg-sand focus-visible:ring-2 focus-visible:ring-flare">
                  <span><span className="font-semibold">{optIn.length} more you can switch on</span><span className="text-mute-2"> · Settings › Formats, or the command line</span></span>
                  <CaretDown size={14} weight="bold" aria-hidden className={`shrink-0 transition-transform duration-300 ${more ? 'rotate-180' : ''}`} />
                </button>
                <AnimatePresence initial={false}>
                  {more && (
                    <motion.ul initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }} className="overflow-hidden">
                      {optIn.map((t) => <Route key={t.to} from={f} t={t} hot={hot} setHot={setHot} />)}
                    </motion.ul>
                  )}
                </AnimatePresence>
              </div>
            )}
            <p className="px-3 pb-3 pt-5 text-[13px] leading-[1.5] text-mute-2"><span className="mr-1.5 inline-block h-2 w-2 rounded-full bg-flare align-middle" />An ember dot on the wheel marks a route with more than one step. anyfmt runs every step in one go.</p>
          </div>
        </div>
      </div>
    </div>
  )
}

/* ── the matrix ────────────────────────────────────────────── */

function Matrix() {
  const ins = catalog.formats.filter((f) => f.targets.length)
  const outIds = useMemo(() => catalog.formats.filter((f) => f.output).map((f) => f.id), [])
  const [tip, setTip] = useState<{ from: string; t: Target } | null>(null)
  const [hiRow, setHiRow] = useState<string | null>(null)
  const [hiCol, setHiCol] = useState<string | null>(null)
  const cell = 19
  return (
    <div>
      <div className="relative overflow-x-auto rounded-[24px] bg-white p-4 ring-1 ring-black/5 sm:p-6" onPointerLeave={() => { setTip(null); setHiRow(null); setHiCol(null) }}>
        <table className="border-separate" style={{ borderSpacing: 2 }} aria-label="Every conversion route: rows are inputs, columns are outputs">
          <thead>
            <tr>
              <th className="sticky left-0 z-10 bg-white" />
              {outIds.map((id) => (
                <th key={id} scope="col" className="relative h-[58px] p-0" style={{ width: cell, minWidth: cell, maxWidth: cell }}>
                  <span className={`absolute bottom-1 left-[7px] block origin-bottom-left -rotate-[60deg] whitespace-nowrap text-left text-[12px] font-semibold uppercase transition-colors ${hiCol === id ? 'text-flare' : 'text-mute-2'}`}>{F[id].label}</span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ins.map((f) => {
              const map = Object.fromEntries(f.targets.map((t) => [t.to, t]))
              return (
                <tr key={f.id}>
                  <th scope="row" className={`sticky left-0 z-10 bg-white pr-2 text-right text-[12px] font-semibold uppercase transition-colors ${hiRow === f.id ? 'text-flare' : 'text-mute-2'}`}>{f.label}</th>
                  {outIds.map((id) => {
                    const t = map[id]
                    const self = id === f.id
                    return (
                      <td key={id} onPointerEnter={() => { setHiRow(f.id); setHiCol(id); setTip(t ? { from: f.id, t } : null) }}
                        style={{ width: cell, height: cell, background: self ? 'repeating-linear-gradient(135deg,#E8E4DF 0 2px,transparent 2px 4px)' : t ? (t.wheel ? (t.via.length ? '#FF8A5B' : '#FF4A14') : '#FFD2B0') : (hiRow === f.id || hiCol === id) ? '#F1EEEA' : '#F7F5F2', borderRadius: 3, outline: tip && tip.from === f.id && tip.t.to === id ? '2px solid #0A0A0A' : undefined }} />
                    )
                  })}
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      <div className="mt-5 flex flex-wrap items-start justify-between gap-6">
        <ul className="flex flex-wrap gap-x-6 gap-y-2 text-[14px] text-mute">
          <li className="flex items-center gap-2"><span className="h-3 w-3 rounded-[3px] bg-flare" />On the wheel, one step</li>
          <li className="flex items-center gap-2"><span className="h-3 w-3 rounded-[3px] bg-[#FF8A5B]" />On the wheel, several steps</li>
          <li className="flex items-center gap-2"><span className="h-3 w-3 rounded-[3px] bg-[#FFD2B0]" />Opt-in</li>
        </ul>
        <p className="min-h-[22px] text-[14px] font-medium" aria-live="polite">
          {tip ? <>{F[tip.from].label} → {F[tip.t.to].label} <span className="font-normal text-mute">· {engineNames(tip.t)}{tip.t.via.length ? ` · via ${tip.t.via.map((v) => F[v].label).join(', ')}` : ''}</span></> : <span className="font-normal text-mute-2">Tap or point at a square.</span>}
        </p>
      </div>
    </div>
  )
}

/* ── engines and lists ─────────────────────────────────────── */

function Engines() {
  const counts: Record<string, number> = {}
  for (const f of catalog.formats) for (const t of f.targets) for (const e of new Set(t.engines.map((x) => ENG[x]?.name ?? x))) counts[e] = (counts[e] ?? 0) + 1
  const rows = Object.entries(ENG).filter(([id]) => id !== 'ffmpeg-image').map(([, e]) => ({ ...e, n: counts[e.name] ?? 0 })).sort((a, b) => b.n - a.n)
  const max = rows[0]?.n ?? 1
  return (
    <ul className="grid gap-x-10 gap-y-1 md:grid-cols-2">
      {rows.map((e) => (
        <li key={e.name} className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 border-b border-line py-3.5">
          <div className="min-w-0">
            <p className="text-[16.5px] font-semibold tracking-[-0.01em]">{e.name} <span className="text-[13px] font-normal text-mute-2">· {e.by}</span></p>
            <p className="text-[14px] text-mute">{e.what}</p>
          </div>
          <div className="flex w-[120px] items-center gap-2 sm:w-[160px]">
            <span className="h-2 flex-1 overflow-hidden rounded-full bg-sand-2"><span className="block h-full min-w-[6px] rounded-full bg-ink" style={{ width: `${(e.n / max) * 100}%` }} /></span>
            <span className="w-9 text-right text-[13px] tabular-nums text-mute">{e.n}</span>
          </div>
        </li>
      ))}
    </ul>
  )
}

/** Every format, one closed row per kind; the lists stay in the page for search and for reading. */
function Lists() {
  return (
    <div className="divide-y divide-line border-y border-line">
      {catalog.kinds.map((k) => {
        const fs = catalog.formats.filter((f) => f.kind === k.id && f.targets.length)
        if (!fs.length) return null
        return (
          <details key={k.id} id={k.id} className="group scroll-mt-28">
            <summary className="flex cursor-pointer list-none items-center justify-between gap-6 py-6 outline-none focus-visible:ring-2 focus-visible:ring-flare [&::-webkit-details-marker]:hidden">
              <span className="flex flex-wrap items-baseline gap-x-4 gap-y-1">
                <span className="text-[clamp(22px,2.2vw,30px)] font-semibold tracking-[-0.03em]">{k.name}</span>
                <span className="text-[15px] text-mute-2">{fs.map((f) => f.label).join(', ')}</span>
              </span>
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sand-2 transition-transform duration-300 group-open:rotate-45">
                <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden><path d="M7 1.5v11M1.5 7h11" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>
              </span>
            </summary>
            <ul className="mb-6 divide-y divide-line rounded-[20px] bg-sand px-5 sm:px-6">
              {fs.map((f) => (
                <li key={f.id} className="grid gap-x-8 gap-y-1.5 py-4 sm:grid-cols-[220px_minmax(0,1fr)]">
                  <h4 className="text-[16px] font-semibold">{f.label} <span className="font-normal text-mute-2">{f.name}</span></h4>
                  <p className="max-w-[62ch] text-[15px] leading-[1.6] text-mute">
                    {f.targets.map((t, i) => <span key={t.to} className={t.wheel ? 'text-ink' : ''}>{F[t.to]?.label}{i < f.targets.length - 1 ? ', ' : ''}</span>)}
                    {!f.output && <span className="mt-1 block text-[14px] text-mute-2">anyfmt reads {f.label} but doesn't write it.</span>}
                  </p>
                </li>
              ))}
            </ul>
          </details>
        )
      })}
    </div>
  )
}

export default function Formats() {
  const c = catalog.counts
  useHead({
    title: `Every format anyfmt converts: ${c.formats} formats, ${c.routes} routes`,
    description: `anyfmt converts ${c.inputs} input formats across images, video, audio, PDF, documents, spreadsheets, ebooks, subtitles and archives: ${c.routes} tested routes, all on your Mac.`,
    path: '/formats',
    jsonLd: {
      '@context': 'https://schema.org', '@type': 'Dataset', name: 'anyfmt conversion routes', description: `Every conversion route in ${catalog.generatedFrom}: ${c.routes} routes between ${c.formats} formats.`,
      url: 'https://anyfmt.app/formats', creator: { '@type': 'Organization', name: 'anyfmt' }, isAccessibleForFree: true,
    },
  })
  return (
    <Page>
      <section className="bg-sand pb-20 pt-36 lg:pt-44">
        <Container>
          <Eyebrow>Formats</Eyebrow>
          <div className="grid items-end gap-x-12 gap-y-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
            <h1 className="max-w-[900px] text-[clamp(48px,7vw,112px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">What can your file become?</h1>
            <p className="max-w-[460px] text-[17px] leading-[1.55] text-mute lg:pb-3">
              Pick the format you have. The wheel is the one anyfmt opens when you drag that file and tap Shift, read straight from <span className="font-mono text-[15px]">{catalog.generatedFrom}</span>: {c.inputs} formats in, {c.outputs} out, {c.routes} tested routes.
            </p>
          </div>
          <div className="mt-12 lg:mt-16"><Explorer /></div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>All {c.routes} at once</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Every route in one table, one square each.</h2>
          <p className="mt-6 max-w-[620px] text-[17px] leading-[1.55] text-mute">Rows are what you have, columns are what you want. Every coloured square is a route that ships, and every one is run on a real file and checked by <span className="font-mono text-[14px]">make matrix</span> before a release.</p>
          <div className="mt-12"><Matrix /></div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div className="lg:sticky lg:top-28 lg:self-start">
            <Eyebrow>Engines</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em] [text-wrap:balance]">Each route uses the best engine for that job.</h2>
            <p className="mt-6 max-w-[420px] text-[16.5px] leading-[1.55] text-mute">Apple's frameworks first, because they cost nothing to ship. Bundled engines where Apple has none. Our own writers where nothing good existed. Numbers show how many routes each one touches.</p>
            <Link to="/docs/routes" className="mt-8 inline-flex rounded-sm text-[15px] font-medium underline decoration-flare/60 underline-offset-4 outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">How routes work</Link>
          </div>
          <Engines />
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Every format</Eyebrow>
          <h2 className="mt-6 text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em]">All {c.inputs} formats, by kind.</h2>
          <p className="mt-6 max-w-[620px] text-[17px] leading-[1.55] text-mute">Open a kind to see every format in it and everything each one converts to. Formats in ink are on the wheel by default; the rest are one switch away in Settings.</p>
          <div className="mt-14"><Lists /></div>
        </Container>
      </section>
    </Page>
  )
}
