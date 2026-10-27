/**
 * The route atlas. Pick any format and the wheel shows what it becomes, ring by ring, exactly as
 * the app lays it out (eight on the first ring, up to twelve more on the second). Below, every
 * route at once as a matrix, then the formats in plain lists for reading and for search engines.
 * All of it is generated from `anyfmt schema --json`.
 */
import { MagnifyingGlass } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Page } from '../components/Page'
import { Container, Eyebrow, FormatChip, KIND_TINT } from '../components/ui'
import catalog from '../data/catalog.json'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'

type Format = (typeof catalog.formats)[number]
type Target = Format['targets'][number]
const F = Object.fromEntries(catalog.formats.map((f) => [f.id, f])) as Record<string, Format>
const ENG = catalog.engines as Record<string, { name: string; by: string; what: string }>
const KIND_NAME = Object.fromEntries(catalog.kinds.map((k) => [k.id, k.name])) as Record<string, string>
const engineNames = (t: Target) => [...new Set(t.engines.map((e) => ENG[e]?.name ?? e))].join(' → ')

/* ── the wheel ─────────────────────────────────────────────── */

const RINGS = [{ r0: 64, r1: 150, cap: 8 }, { r0: 156, r1: 214, cap: 12 }]

function arc(r0: number, r1: number, a0: number, a1: number) {
  const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(2)},${(Math.sin(a) * r).toFixed(2)}`
  const big = a1 - a0 > Math.PI ? 1 : 0
  return `M${p(r1, a0)} A${r1},${r1} 0 ${big} 1 ${p(r1, a1)} L${p(r0, a1)} A${r0},${r0} 0 ${big} 0 ${p(r0, a0)} Z`
}

function Wheel({ f, hot, setHot }: { f: Format; hot: string | null; setHot: (id: string | null) => void }) {
  const onWheel = f.targets.filter((t) => t.wheel)
  const rings = [onWheel.slice(0, 8), onWheel.slice(8, 20)].filter((r) => r.length)
  const hotT = f.targets.find((t) => t.to === hot)
  return (
    <svg viewBox="-226 -226 452 452" className="w-full max-w-[520px] select-none" role="img" aria-label={`${f.label} converts to ${onWheel.map((t) => F[t.to]?.label).join(', ')}`}>
      <defs>
        <linearGradient id="heat" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stopColor="#E8160C" /><stop offset="0.6" stopColor="#FF4A14" /><stop offset="1" stopColor="#FF9A3C" /></linearGradient>
      </defs>
      <AnimatePresence mode="popLayout">
        <motion.g key={f.id} initial={{ rotate: -24, scale: 0.85, opacity: 0 }} animate={{ rotate: 0, scale: 1, opacity: 1 }} exit={{ rotate: 18, scale: 0.9, opacity: 0, transition: { duration: 0.2 } }} transition={{ type: 'spring', stiffness: 260, damping: 26 }}>
          {rings.map((ring, ri) => {
            const { r0, r1 } = RINGS[ri]
            // the first ring divides itself among its targets; the second keeps twelve fixed slots, centred on top
            const n = ri === 0 ? ring.length : 12
            const first = ri === 0 ? 0 : -(ring.length - 1) / 2
            const gap = ri === 0 ? 0.022 : 0.012
            return ring.map((t, j) => {
              const i = j + first
              const a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap
              const a1 = a0 + (Math.PI * 2) / n - gap * 2
              const mid = (a0 + a1) / 2, rm = (r0 + r1) / 2
              const on = hot === t.to
              const label = F[t.to]?.label ?? t.to
              return (
                <g key={t.to} onPointerEnter={() => setHot(t.to)} onPointerLeave={() => setHot(null)} onFocus={() => setHot(t.to)} onBlur={() => setHot(null)} tabIndex={0} role="button" aria-label={`${f.label} to ${label}`} className="cursor-default outline-none">
                  <path d={arc(r0, r1, a0, a1)} fill={on ? 'url(#heat)' : ri === 0 ? '#FFFFFF' : '#FBFAF8'} stroke={on ? 'none' : 'rgba(10,10,10,.08)'} style={{ transition: 'fill .2s' }} />
                  <text x={Math.cos(mid) * rm} y={Math.sin(mid) * rm} textAnchor="middle" dominantBaseline="central" fontSize={ri === 0 ? (label.length > 5 ? 13 : 16) : label.length > 5 ? 9.5 : 11.5} fontWeight="600" fill={on ? '#fff' : '#0A0A0A'} style={{ pointerEvents: 'none' }}>{label}</text>
                  {t.via.length > 0 && <circle cx={Math.cos(mid) * (r1 - 9)} cy={Math.sin(mid) * (r1 - 9)} r={2.4} fill={on ? '#fff' : '#FF4A14'} />}
                </g>
              )
            })
          })}
        </motion.g>
      </AnimatePresence>
      <circle r={56} fill="#0A0A0A" />
      <text y={hotT ? -16 : -8} textAnchor="middle" fontSize="10" fill="rgba(255,255,255,.55)">{hotT ? `${f.label} to` : 'convert'}</text>
      <text y={hotT ? 3 : 10} textAnchor="middle" fontSize="17" fontWeight="700" fill="#fff">{hotT ? F[hotT.to]?.label : f.label}</text>
      {hotT && <text y={20} textAnchor="middle" fontSize="8.5" fill="rgba(255,255,255,.6)">{hotT.via.length ? `via ${hotT.via.map((v) => F[v]?.label).join(', ')}` : 'one step'}</text>}
    </svg>
  )
}

function Picker({ sel, onPick }: { sel: string; onPick: (id: string) => void }) {
  const [q, setQ] = useState('')
  const [kind, setKind] = useState<string>('all')
  const list = catalog.formats.filter((f) => f.targets.length && (kind === 'all' || f.kind === kind) &&
    (!q || f.label.toLowerCase().includes(q.toLowerCase()) || f.name.toLowerCase().includes(q.toLowerCase()) || f.extensions.some((e) => e.includes(q.toLowerCase().replace(/^\./, '')))))
  return (
    <div>
      <label className="flex h-12 items-center gap-3 rounded-full bg-white px-4 ring-1 ring-black/10 focus-within:ring-2 focus-within:ring-flare">
        <MagnifyingGlass size={18} className="text-mute-2" aria-hidden />
        <input value={q} onChange={(e) => { setQ(e.target.value); const m = catalog.formats.find((f) => f.targets.length && (f.id === e.target.value.toLowerCase().replace(/^\./, '') || f.extensions.includes(e.target.value.toLowerCase().replace(/^\./, '')))); if (m) onPick(m.id) }}
          placeholder="Type an extension: heic, mov, docx…" aria-label="Find a format" className="h-full flex-1 bg-transparent text-[16px] outline-none placeholder:text-mute-3" />
      </label>
      <div className="mt-4 flex gap-1.5 overflow-x-auto pb-1 pr-8 no-scrollbar [mask-image:linear-gradient(90deg,#000_88%,transparent)]" role="tablist" aria-label="Kind">
        {[{ id: 'all', name: 'All' }, ...catalog.kinds].map((k) => (
          <button key={k.id} type="button" role="tab" aria-selected={kind === k.id} onClick={() => setKind(k.id)}
            className={`h-9 shrink-0 rounded-full px-3.5 text-[13.5px] font-medium outline-none ring-1 transition-colors focus-visible:ring-2 focus-visible:ring-flare ${kind === k.id ? 'bg-ink text-white ring-ink' : 'bg-white ring-black/10 hover:bg-sand-2'}`}>{k.name}</button>
        ))}
      </div>
      <ul className="mt-4 flex max-h-[232px] flex-wrap content-start gap-1.5 overflow-y-auto pb-6 pr-1 no-scrollbar [mask-image:linear-gradient(180deg,#000_80%,transparent)]" aria-label="Formats">
        {list.map((f) => (
          <li key={f.id}>
            <button type="button" onClick={() => onPick(f.id)} aria-pressed={sel === f.id}
              className={`h-9 rounded-[10px] px-3 text-[13.5px] font-semibold uppercase tracking-wide outline-none ring-1 transition-[background-color,color,transform] duration-200 active:scale-95 focus-visible:ring-2 focus-visible:ring-flare ${sel === f.id ? 'text-white ring-transparent' : 'bg-white text-ink ring-black/10 hover:-translate-y-0.5'}`}
              style={sel === f.id ? { background: KIND_TINT[f.kind] } : undefined}>{f.label}</button>
          </li>
        ))}
        {list.length === 0 && <li className="py-2 text-[14px] text-mute">No format called “{q}”. anyfmt reads the {catalog.counts.inputs} on this page.</li>}
      </ul>
    </div>
  )
}

function Explorer() {
  const [sel, setSel] = useState('heic')
  const [hot, setHot] = useState<string | null>(null)
  const f = F[sel]
  const optIn = f.targets.filter((t) => !t.wheel)
  const onWheel = f.targets.filter((t) => t.wheel)
  const hotT = f.targets.find((t) => t.to === hot)
  return (
    <div className="grid items-start gap-10 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)] lg:gap-16">
      <div className="order-2 min-w-0 lg:order-1">
        <Picker sel={sel} onPick={(id) => { setSel(id); setHot(null) }} />
        <div className="mt-8 rounded-[24px] bg-white p-6 ring-1 ring-black/5">
          <div className="flex flex-wrap items-baseline justify-between gap-3">
            <p className="text-[22px] font-semibold tracking-[-0.03em]">{f.name}</p>
            <p className="font-mono text-[13px] text-mute-2">{f.extensions.map((e) => `.${e}`).join(' ')}</p>
          </div>
          <p className="mt-2 text-[15.5px] leading-[1.55] text-mute">
            Becomes <strong className="text-ink">{onWheel.length}</strong> formats from the wheel{optIn.length ? <>, and <strong className="text-ink">{optIn.length}</strong> more once you switch them on in Settings › Formats or call them from the CLI</> : null}.
          </p>
          <div className="mt-5 min-h-[64px] rounded-[16px] bg-sand p-4 text-[14px] leading-[1.5]">
            <AnimatePresence mode="wait" initial={false}>
              <motion.div key={hot ?? 'none'} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -4 }} transition={{ duration: 0.18 }}>
                {hotT ? (
                  <>
                    <p className="font-medium">{f.label} → {hotT.via.map((v) => `${F[v]?.label} → `).join('')}{F[hotT.to]?.label}</p>
                    <p className="mt-1 text-mute">{engineNames(hotT)}{hotT.via.length ? ` · ${hotT.via.length + 1} steps, run in one go` : ' · one step'}</p>
                  </>
                ) : <p className="text-mute">Point at a segment to see the route: the engines it uses and any formats it passes through. An ember dot marks routes with more than one step.</p>}
              </motion.div>
            </AnimatePresence>
          </div>
          {optIn.length > 0 && (
            <div className="mt-5">
              <p className="text-[12.5px] font-semibold uppercase tracking-[0.12em] text-mute-2">Opt-in</p>
              <ul className="mt-2 flex flex-wrap gap-1.5">
                {optIn.map((t) => <li key={t.to} onPointerEnter={() => setHot(t.to)} onPointerLeave={() => setHot(null)} className="rounded-[7px] px-2 py-1 text-[11.5px] font-semibold uppercase tracking-wide text-mute ring-1 ring-black/10">{F[t.to]?.label}</li>)}
              </ul>
            </div>
          )}
        </div>
      </div>
      <div className="order-1 flex min-w-0 justify-center lg:sticky lg:top-28 lg:order-2"><Wheel f={f} hot={hot} setHot={setHot} /></div>
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
                  <span className={`absolute bottom-1 left-[7px] block origin-bottom-left -rotate-[60deg] whitespace-nowrap text-left text-[10px] font-semibold uppercase transition-colors ${hiCol === id ? 'text-flare' : 'text-mute-2'}`}>{F[id].label}</span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ins.map((f) => {
              const map = Object.fromEntries(f.targets.map((t) => [t.to, t]))
              return (
                <tr key={f.id}>
                  <th scope="row" className={`sticky left-0 z-10 bg-white pr-2 text-right text-[10px] font-semibold uppercase transition-colors ${hiRow === f.id ? 'text-flare' : 'text-mute-2'}`}>{f.label}</th>
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
          {tip ? <>{F[tip.from].label} → {F[tip.t.to].label} <span className="font-normal text-mute">· {engineNames(tip.t)}{tip.t.via.length ? ` · via ${tip.t.via.map((v) => F[v].label).join(', ')}` : ''}</span></> : <span className="font-normal text-mute-2">Point at a square.</span>}
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
            <span className="h-2 flex-1 overflow-hidden rounded-full bg-sand-2"><span className="block h-full rounded-full bg-ink" style={{ width: `${(e.n / max) * 100}%` }} /></span>
            <span className="w-9 text-right text-[13px] tabular-nums text-mute">{e.n}</span>
          </div>
        </li>
      ))}
    </ul>
  )
}

function Lists() {
  return (
    <div className="space-y-14">
      {catalog.kinds.map((k) => {
        const fs = catalog.formats.filter((f) => f.kind === k.id && f.targets.length)
        if (!fs.length) return null
        return (
          <section key={k.id} id={k.id} className="grid scroll-mt-28 gap-6 border-t border-line pt-8 lg:grid-cols-[240px_minmax(0,1fr)] lg:gap-10">
            <h3 className="lg:sticky lg:top-28 lg:self-start">
              <span className="block text-[clamp(26px,2.6vw,36px)] font-semibold leading-none tracking-[-0.035em]">{k.name}</span>
              <span className="mt-2 block text-[15px] font-medium text-mute-2">{fs.length} {fs.length === 1 ? 'format' : 'formats'}</span>
            </h3>
            <ul className="grid gap-3 md:grid-cols-2">
              {fs.map((f) => (
                <li key={f.id} className="rounded-[20px] bg-white p-5 ring-1 ring-black/5">
                  <div className="flex items-center justify-between gap-3">
                    <h4 className="flex items-center gap-2.5 text-[17px] font-semibold"><FormatChip label={f.label} kind={f.kind} />{f.name}</h4>
                    <span className="font-mono text-[12px] text-mute-2">{f.targets.length}</span>
                  </div>
                  <p className="mt-3 text-[14px] leading-[1.6] text-mute">
                    <span className="text-mute-2">Converts to </span>
                    {f.targets.map((t, i) => <span key={t.to} className={t.wheel ? 'font-medium text-ink' : ''}>{F[t.to]?.label}{i < f.targets.length - 1 ? ', ' : ''}</span>)}
                  </p>
                  {!f.output && <p className="mt-2 text-[12.5px] text-mute-2">Read only: anyfmt opens {f.label} but doesn't write it.</p>}
                </li>
              ))}
            </ul>
          </section>
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
  const stats: [string, string][] = [[String(c.formats), 'formats'], [String(c.routes), 'routes'], [String(c.onWheel), 'on the wheel'], [String(c.multiHop), 'multi-step routes']]
  return (
    <Page>
      <section className="bg-sand pb-20 pt-36 lg:pt-44">
        <Container>
          <Eyebrow>Formats</Eyebrow>
          <h1 className="mt-6 max-w-[1100px] text-[clamp(44px,6.4vw,100px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">Pick a file. See everything it can become.</h1>
          <div className="mt-10 flex flex-wrap items-end justify-between gap-8">
            <ul className="flex flex-wrap gap-x-10 gap-y-4">
              {stats.map(([v, l]) => <li key={l}><p className="text-[40px] font-semibold leading-none tracking-[-0.05em]">{v}</p><p className="mt-1.5 text-[14px] text-mute">{l}</p></li>)}
            </ul>
            <p className="max-w-[420px] text-[15px] leading-[1.55] text-mute">Generated from <span className="font-mono text-[13px]">{catalog.generatedFrom}</span> itself, the same table the wheel reads, so this page can't drift from the app.</p>
          </div>
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, ease: EASE, delay: 0.2 }} className="mt-16"><Explorer /></motion.div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>All {c.routes} at once</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">The whole table, one square per route.</h2>
          <p className="mt-6 max-w-[620px] text-[17px] leading-[1.55] text-mute">Rows are what you have, columns are what you want. Every coloured square is a route that ships, and every one is run on a real file and checked by <span className="font-mono text-[14px]">make matrix</span> before a release.</p>
          <div className="mt-12"><Matrix /></div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div>
            <Eyebrow>Engines</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Picked per route, not per app.</h2>
            <p className="mt-6 max-w-[420px] text-[16.5px] leading-[1.55] text-mute">Apple's frameworks first, because they cost nothing to ship. Bundled engines where Apple has none. Our own writers where nothing good existed. Numbers show how many routes each one touches.</p>
            <Link to="/docs/routes" className="mt-8 inline-flex text-[15px] font-medium underline decoration-flare/60 underline-offset-4">How routes work</Link>
          </div>
          <Engines />
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Every format</Eyebrow>
          <h2 className="mt-6 text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">The list, kind by kind.</h2>
          <nav aria-label="Kinds" className="mt-8 flex flex-wrap gap-2">
            {catalog.kinds.filter((k) => catalog.formats.some((f) => f.kind === k.id && f.targets.length)).map((k) => (
              <a key={k.id} href={`#${k.id}`} className="rounded-full bg-sand px-3.5 py-2 text-[14px] font-medium transition-colors hover:bg-sand-2">{KIND_NAME[k.id]}</a>
            ))}
          </nav>
          <div className="mt-14"><Lists /></div>
        </Container>
      </section>
    </Page>
  )
}
