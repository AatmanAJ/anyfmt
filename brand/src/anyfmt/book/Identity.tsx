import { ArrowRight, BatteryFull, CalendarDays, Folder, Globe, Image as ImageIcon, Mail, MousePointer2, Music, PenLine, Search, Trash2, Wifi } from 'lucide-react'
import { useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { AnyWheel } from '../AnyWheel'
import { brand, convertWedges } from '../copy'
import { Eyebrow, Streaks } from '../Landing'
import { AppIcon, GlassTile, Mark, petalPath, Wordmark } from '../Mark'
import { Fit, InkPanel, Section, Spec, Sub, useLive, Verdict } from './kit'

/* Same geometry as Mark.tsx: 100×100 box, centre 50,50. */
const C = 50, R0 = 17, R1 = 45, HEAD = 15, GAP = 7, RM = (R0 + R1) / 2
const pt = (r: number, deg: number) => {
  const a = (deg * Math.PI) / 180
  return [C + r * Math.sin(a), C - r * Math.cos(a)] as const
}
const STARTS = [0, 90, 180, 270].map((a) => a + GAP / 2 - 45)
const PETALS = STARTS.map((a0) => petalPath(a0))
const VERTS = STARTS.map((a0) => {
  const a1 = a0 + 90 - GAP
  return [pt(R1, a0), pt(R1, a1 - HEAD), pt(RM, a1), pt(R0, a1 - HEAD), pt(R0, a0), pt(RM, a0 + HEAD * 0.9)]
})

const PETAL_BOX = (() => {
  const xs = VERTS[0].map((v) => v[0]), ys = VERTS[0].map((v) => v[1])
  const x0 = Math.min(...xs) - 3, y0 = Math.min(...ys) - 3, w = Math.max(...xs) + 3 - x0, h = Math.max(...ys) + 3 - y0, m = Math.max(w, h)
  return `${x0 - (m - w) / 2} ${y0 - (m - h) / 2} ${m} ${m}`
})()

export const CHAPTERS = [
  { id: 'cover', label: 'Cover' }, { id: 'logo', label: 'Logo' }, { id: 'icon', label: 'Icon' }, { id: 'colour', label: 'Colour' },
  { id: 'type', label: 'Type' }, { id: 'voice', label: 'Voice' }, { id: 'components', label: 'Components' },
  { id: 'onboarding', label: 'Onboarding' }, { id: 'surfaces', label: 'App surfaces' }, { id: 'world', label: 'In the world' },
] as const

export function jump(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })
}

/* ---------- 01 Cover ---------- */

export function Cover() {
  const live = useLive()
  return (
    <section id="cover" data-book-section className="px-2 pt-2 sm:px-3 sm:pt-3">
      <div className="af-stage relative overflow-hidden rounded-[28px] sm:rounded-[36px]">
        <Streaks className="inset-0 h-full w-full" />
        <div aria-hidden className="pointer-events-none absolute inset-x-0 -bottom-[0.24em] select-none text-center font-semibold leading-none tracking-[-0.07em] text-white/[.12]"
          style={{ fontSize: 'clamp(140px, 30vw, 460px)' }}>anyfmt</div>
        <div className="relative mx-auto max-w-[1240px] px-5 pb-[clamp(120px,18vw,260px)] pt-28 sm:px-8 sm:pt-36">
          <div className="grid items-center gap-12 lg:grid-cols-[1.15fr_1fr]">
            <div>
              <Eyebrow tone="stage">Brand book · Version 1.0</Eyebrow>
              <h1 className="mt-6 text-[88px] font-semibold leading-[0.86] tracking-[-0.065em] sm:text-[140px] lg:text-[168px]">anyfmt</h1>
              <p className="mt-7 max-w-[560px] text-[24px] font-medium leading-[1.2] tracking-[-0.03em] text-white sm:text-[30px]">
                The shortest path between a file and the format it needs to be.
              </p>
              <p className="mt-5 max-w-[500px] text-[16px] leading-relaxed text-white/80">
                How anyfmt looks, sounds and behaves: the mark, the icon, colour, type, voice, components and every surface of the Mac app.
              </p>
            </div>
            <div className="flex justify-center lg:justify-end">
              <div className="relative">
                <div aria-hidden className="absolute inset-[-18%] rounded-full opacity-70 blur-[50px]" style={{ background: 'radial-gradient(circle, #FFE1C4 0%, transparent 65%)' }} />
                <div style={{ animation: live ? 'af-float 7s ease-in-out infinite' : undefined }}>
                  <GlassTile size={300} className="max-sm:!size-[230px]" />
                </div>
              </div>
            </div>
          </div>

          <dl className="mt-16 grid grid-cols-2 gap-px overflow-hidden rounded-[18px] bg-white/25 ring-1 ring-white/35 backdrop-blur-md sm:grid-cols-4">
            {[['Version', '1.0'], ['Date', '26 October 2026'], ['Domain', brand.domain], ['Licence', 'AGPL-3.0']].map(([k, v]) => (
              <div key={k} className="bg-white/[.08] px-4 py-3.5 sm:px-5">
                <dt className="text-[12px] font-medium text-white/70">{k}</dt>
                <dd className="mt-0.5 text-[16px] font-semibold tracking-[-0.02em]">{v}</dd>
              </div>
            ))}
          </dl>

          <nav aria-label="Chapters" className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-5">
            {CHAPTERS.map((c, i) => (
              <a key={c.id} href={`#${c.id}`} onClick={(e) => { e.preventDefault(); jump(c.id) }}
                className="group flex items-center justify-between rounded-[12px] bg-white/[.12] px-3.5 py-2.5 text-[14px] font-medium ring-1 ring-white/25 transition-colors hover:bg-white/20">
                <span><span className="af-mono mr-2 text-[11px] text-white/65">{String(i + 1).padStart(2, '0')}</span>{c.label}</span>
                <ArrowRight size={14} className="opacity-60 transition-transform group-hover:translate-x-0.5" />
              </a>
            ))}
          </nav>
        </div>
      </div>
    </section>
  )
}

/* ---------- 02 Logo ---------- */

function ConstructionCanvas() {
  const anchors = VERTS.flat()
  const guide = 'rgba(255,255,255,.22)'
  const sel = '#5AA2FF'
  return (
    <svg viewBox="-12 -12 124 124" className="block h-auto w-full" role="img" aria-label="Construction of the anyfmt mark">
      <defs>
        <pattern id="bk-dots" width="5" height="5" patternUnits="userSpaceOnUse" x="-12" y="-12">
          <circle cx=".4" cy=".4" r=".32" fill="rgba(255,255,255,.14)" />
        </pattern>
        <linearGradient id="bk-flat" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#F59248" /><stop offset="1" stopColor="#D35A1C" />
        </linearGradient>
      </defs>
      <rect x="-12" y="-12" width="124" height="124" fill="url(#bk-dots)" />
      {/* artboard */}
      <rect x="0" y="0" width="100" height="100" fill="none" stroke="rgba(255,255,255,.12)" strokeWidth=".3" />
      {/* axes and spokes */}
      <line x1="-6" y1="50" x2="106" y2="50" stroke={guide} strokeWidth=".25" />
      <line x1="50" y1="-6" x2="50" y2="106" stroke={guide} strokeWidth=".25" />
      {STARTS.map((a) => {
        const [x, y] = pt(54, a)
        return <line key={a} x1={50} y1={50} x2={x} y2={y} stroke="rgba(234,124,37,.55)" strokeWidth=".25" strokeDasharray="1 1" />
      })}
      {/* construction circles */}
      <circle cx="50" cy="50" r={R1} fill="none" stroke={guide} strokeWidth=".3" strokeDasharray="1.2 1" />
      <circle cx="50" cy="50" r={RM} fill="none" stroke="rgba(234,124,37,.7)" strokeWidth=".3" strokeDasharray="1.2 1" />
      <circle cx="50" cy="50" r={R0} fill="none" stroke={guide} strokeWidth=".3" strokeDasharray="1.2 1" />
      {/* the petals, as drawn */}
      {PETALS.map((d, i) => <path key={i} d={d} fill="url(#bk-flat)" stroke="url(#bk-flat)" strokeWidth="5" strokeLinejoin="round" opacity={i === 0 ? 1 : 0.92} />)}
      {/* the selected path outline */}
      {PETALS.map((d, i) => <path key={`o${i}`} d={d} fill="none" stroke={sel} strokeWidth={i === 0 ? '.45' : '.3'} opacity={i === 0 ? 1 : 0.7} />)}
      {anchors.map(([x, y], i) => (
        <rect key={i} x={x - 0.9} y={y - 0.9} width="1.8" height="1.8" fill={i < 6 ? sel : '#fff'} stroke={sel} strokeWidth=".3" />
      ))}
      <circle cx="50" cy="50" r=".9" fill="#fff" />
      {/* selection box */}
      <rect x="2.5" y="2.5" width="95" height="95" fill="none" stroke={sel} strokeWidth=".25" strokeDasharray=".8 .8" opacity=".6" />
      {[[2.5, 2.5], [97.5, 2.5], [2.5, 97.5], [97.5, 97.5], [50, 2.5], [50, 97.5], [2.5, 50], [97.5, 50]].map(([x, y], i) => (
        <rect key={i} x={x - 0.8} y={y - 0.8} width="1.6" height="1.6" fill="#fff" stroke={sel} strokeWidth=".25" />
      ))}
      {/* labels */}
      <g fontFamily="JetBrains Mono Variable, ui-monospace, monospace" fontSize="2.5" fill="rgba(255,255,255,.62)">
        <text x={50 + R1 * 0.72 + 2} y={50 - R1 * 0.72 - 2.5}>R 45</text>
        <text x="50" y="44.6" textAnchor="middle">R 17</text>
        <text x="51.5" y="53.6">50, 50</text>
        <text x="102" y="-5" textAnchor="end">7° gap</text>
        <text x="-9" y="109">15° head</text>
      </g>
    </svg>
  )
}

function Construction() {
  const specs: [string, string][] = [
    ['Artboard', '100 × 100 u'], ['Outer radius', '45 u'], ['Inner radius', '17 u'], ['Arrow tip', 'on r 31, the midline'],
    ['Gap between wedges', '7°'], ['Arrowhead sweep', '15°'], ['Tail notch', '0.9 × head'], ['Corners', '5 u stroke, round join'],
  ]
  return (
    <InkPanel className="grid lg:grid-cols-[1.35fr_1fr]">
      <div className="border-b border-white/10 lg:border-b-0 lg:border-r">
        <div className="flex items-center justify-between gap-3 border-b border-white/10 px-4 py-2.5">
          <div className="flex items-center gap-1.5 text-white/50">
            {[MousePointer2, PenLine, Search].map((I, i) => (
              <span key={i} className={`grid size-7 place-items-center rounded-[7px] ${i === 0 ? 'bg-[#2C6BE0] text-white' : ''}`}><I size={14} /></span>
            ))}
          </div>
          <Spec tone="white" className="truncate">anyfmt-mark.svg · 4 paths · 24 anchors</Spec>
          <Spec tone="white" className="hidden sm:inline">400%</Spec>
        </div>
        <div className="mx-auto max-w-[560px] px-3 py-4 sm:px-8 sm:py-8"><ConstructionCanvas /></div>
        <div className="flex flex-wrap gap-x-5 gap-y-1.5 border-t border-white/10 px-4 py-3 text-[12px] text-white/60">
          <span className="flex items-center gap-2"><span className="size-2 bg-[#5AA2FF]" />Path and anchors</span>
          <span className="flex items-center gap-2"><span className="w-4 border-t border-dashed border-[#F59248]" />r 31, where the arrow tips sit</span>
          <span className="flex items-center gap-2"><span className="w-4 border-t border-dashed border-white/40" />R 45 and R 17</span>
        </div>
      </div>
      <div className="flex flex-col gap-6 p-6 sm:p-8">
        <div>
          <div className="text-[13px] font-medium text-white/55">Construction</div>
          <p className="mt-2 text-[17px] leading-relaxed text-white/85">
            Two circles make a ring. Cut it into four quarters with 7° gaps. Each quarter ends in a 15° arrowhead whose tip sits on the midline, and its tail is notched to take the head of the one before.
          </p>
        </div>
        <dl className="grid grid-cols-1 gap-px overflow-hidden rounded-[14px] bg-white/10">
          {specs.map(([k, v]) => (
            <div key={k} className="flex items-baseline justify-between gap-3 bg-[#161616] px-3.5 py-2.5">
              <dt className="text-[13px] text-white/55">{k}</dt>
              <dd className="af-mono text-[12.5px] text-white">{v}</dd>
            </div>
          ))}
        </dl>
        <p className="text-[13px] leading-relaxed text-white/45">Source of truth: <span className="af-mono text-white/70">Mark.tsx</span>. Never redraw the mark by hand; export it from the component.</p>
      </div>
    </InkPanel>
  )
}

function Meaning() {
  const cycle = ['MOV', 'GIF', 'PNG', 'JPG']
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <div className="af-card flex flex-col gap-6 p-6 sm:p-8">
        <div className="af-well flex h-[280px] items-center justify-center gap-4 sm:gap-8">
          <Mark size={96} variant="gloss" />
          <ArrowRight size={20} className="shrink-0 text-[#8C8884]" />
          <div className="max-sm:hidden"><AnyWheel wedges={convertWedges} size={200} active={0} hub={<span className="text-[10px] font-semibold">MOV</span>} /></div>
          <div className="sm:hidden"><AnyWheel wedges={convertWedges} size={160} active={0} hub={<span className="text-[9px] font-semibold">MOV</span>} /></div>
        </div>
        <div>
          <h4 className="text-[20px] font-semibold tracking-[-0.03em]">A wheel</h4>
          <p className="mt-1 text-[15px] leading-relaxed text-[#55524F]">The mark is the product, seen from above: the ring of wedges that opens around your pointer when you press a key mid-drag.</p>
        </div>
      </div>
      <div className="af-card flex flex-col gap-6 p-6 sm:p-8">
        <div className="af-well relative flex h-[280px] items-center justify-center">
          <div className="relative size-[200px] sm:size-[220px]">
            <svg viewBox="0 0 220 220" className="absolute inset-0 size-full" aria-hidden>
              <circle cx="110" cy="110" r="88" fill="none" stroke="#D9D6D2" strokeWidth="1.5" strokeDasharray="4 5" />
            </svg>
            <div className="absolute inset-0 grid place-items-center"><Mark size={110} variant="gloss" /></div>
            {cycle.map((c, i) => {
              const a = (i * Math.PI) / 2
              return (
                <span key={c} className={`af-chip absolute !h-7 !px-2.5 !text-[12px] font-semibold ${i === 1 ? 'af-chip-on' : ''}`}
                  style={{ left: `${50 + 40 * Math.sin(a)}%`, top: `${50 - 40 * Math.cos(a)}%`, transform: 'translate(-50%,-50%)' }}>{c}</span>
              )
            })}
          </div>
        </div>
        <div>
          <h4 className="text-[20px] font-semibold tracking-[-0.03em]">A convert cycle</h4>
          <p className="mt-1 text-[15px] leading-relaxed text-[#55524F]">Four arrows chase each other round the ring: a file turning into something else, and back again if you want. Nothing is lost on the way.</p>
        </div>
      </div>
    </div>
  )
}

export function StackedLockup({ size = 44, tone = 'ink' }: { size?: number; tone?: 'ink' | 'white' }) {
  return (
    <span className="inline-flex flex-col items-center" style={{ gap: size * 0.4 }}>
      <Mark size={size * 2} variant={tone === 'white' ? 'white' : 'flat'} />
      <span style={{ fontSize: size, fontWeight: 650, letterSpacing: '-0.035em', lineHeight: 1, color: tone === 'white' ? '#fff' : 'var(--af-ink)' }}>anyfmt</span>
    </span>
  )
}

function Lockups() {
  const items: { name: string; use: string; node: ReactNode }[] = [
    { name: 'Horizontal', use: 'The default. Navigation, footers, docs, anything wider than it is tall.', node: <Wordmark size={44} /> },
    { name: 'Stacked', use: 'Square spaces: covers, badges, splash screens, a sticker.', node: <StackedLockup size={34} /> },
    { name: 'Mark only', use: 'Favicons, the menu bar, the Dock, or wherever the name is already close by.', node: <Mark size={96} /> },
  ]
  return (
    <div className="grid gap-4 md:grid-cols-3">
      {items.map((it) => (
        <div key={it.name} className="af-card flex flex-col p-2">
          <div className="af-well grid h-[220px] place-items-center">{it.node}</div>
          <div className="px-4 pb-4 pt-5">
            <div className="flex items-baseline justify-between"><h4 className="text-[18px] font-semibold tracking-[-0.025em]">{it.name}</h4><Spec>{it.name === 'Mark only' ? 'mark' : 'mark + name'}</Spec></div>
            <p className="mt-1 text-[14px] leading-relaxed text-[#55524F]">{it.use}</p>
          </div>
        </div>
      ))}
      <div className="flex flex-wrap gap-x-6 gap-y-2 md:col-span-3">
        <Spec>Name: Inter Tight 650, tracking −0.035em, always lowercase</Spec>
        <Spec>Mark height = 1.1 × name size</Spec>
        <Spec>Gap = 0.36 × name size</Spec>
      </div>
    </div>
  )
}

function Petal({ size, color = '#EA7C25' }: { size: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox={PETAL_BOX} aria-hidden style={{ overflow: 'visible' }}>
      <path d={PETALS[0]} fill={color} stroke={color} strokeWidth="5" strokeLinejoin="round" />
    </svg>
  )
}

function ClearZone({ x, children }: { x: number; children: ReactNode }) {
  const hatch = 'repeating-linear-gradient(135deg, rgba(234,124,37,.16) 0 1px, transparent 1px 7px)'
  return (
    <div className="relative" style={{ padding: x, background: hatch, outline: '1px dashed rgba(234,124,37,.7)', outlineOffset: 0 }}>
      <div className="relative bg-white" style={{ outline: '1px solid rgba(90,162,255,.6)' }}>{children}</div>
      <span className="af-mono absolute left-1/2 top-0 -translate-x-1/2 text-[10px] leading-none text-[#BB3F14]" style={{ top: x / 2 - 5 }}>x</span>
      <span className="af-mono absolute left-1/2 -translate-x-1/2 text-[10px] leading-none text-[#BB3F14]" style={{ bottom: x / 2 - 5 }}>x</span>
      <span className="af-mono absolute top-1/2 -translate-y-1/2 text-[10px] leading-none text-[#BB3F14]" style={{ left: x / 2 - 3 }}>x</span>
      <span className="af-mono absolute top-1/2 -translate-y-1/2 text-[10px] leading-none text-[#BB3F14]" style={{ right: x / 2 - 3 }}>x</span>
    </div>
  )
}

function Measured({ children, label }: { children: ReactNode; label?: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const [w, setW] = useState(0)
  useLayoutEffect(() => { if (ref.current) setW(ref.current.getBoundingClientRect().width) }, [])
  return (
    <div className="flex flex-col items-center gap-2">
      <div ref={ref} className="inline-flex">{children}</div>
      <div className="flex items-center" style={{ width: w || undefined }}>
        <span className="h-2 w-px bg-[#8C8884]" /><span className="h-px flex-1 bg-[#8C8884]" /><span className="h-2 w-px bg-[#8C8884]" />
      </div>
      <Spec>{label ?? `${Math.round(w)} px`}</Spec>
    </div>
  )
}

function ClearSpace() {
  const markSize = 56 * 1.1
  return (
    <div className="grid gap-4 lg:grid-cols-[1.25fr_1fr]">
      <div className="af-card flex flex-col gap-6 p-6 sm:p-8">
        <div className="af-well flex flex-1 flex-wrap items-center justify-center gap-10 px-4 py-10">
          <div className="max-sm:hidden"><ClearZone x={Math.round(markSize * 0.33)}><Wordmark size={56} /></ClearZone></div>
          <div className="sm:hidden"><ClearZone x={Math.round(36 * 1.1 * 0.33)}><Wordmark size={36} /></ClearZone></div>
          <ClearZone x={Math.round(72 * 0.33)}><Mark size={72} /></ClearZone>
        </div>
        <div className="flex items-start gap-4">
          <div className="grid size-12 shrink-0 place-items-center rounded-[12px] bg-[#FFF3E6] ring-1 ring-[#FFD9B3]"><Petal size={26} /></div>
          <div>
            <h4 className="text-[18px] font-semibold tracking-[-0.025em]">Clear space: x = one petal</h4>
            <p className="mt-1 text-[14px] leading-relaxed text-[#55524F]">Keep a margin the width of one petal (a third of the mark) on every side. Nothing else enters it: no text, no edge, no other logo.</p>
          </div>
        </div>
      </div>
      <div className="af-card flex flex-col gap-6 p-6 sm:p-8">
        <div className="af-well flex flex-col gap-8 px-4 py-8">
          <div className="flex flex-wrap items-end justify-center gap-7">
            {[16, 24, 32, 48].map((s) => (
              <div key={s} className="flex flex-col items-center gap-2">
                <div className={`grid place-items-center rounded-[6px] p-1.5 ${s === 16 ? 'ring-1 ring-[#EA7C25]' : ''}`}><Mark size={s} /></div>
                <Spec className={s === 16 ? '!text-[#BB3F14]' : ''}>{s} px{s === 16 ? ' min' : ''}</Spec>
              </div>
            ))}
          </div>
          <div className="h-px bg-[#E7E5E2]" />
          <div className="flex flex-wrap items-end justify-center gap-8">
            <Measured label="72 px min"><Wordmark size={15.3} /></Measured>
            <Measured><Wordmark size={27} /></Measured>
          </div>
        </div>
        <div>
          <h4 className="text-[18px] font-semibold tracking-[-0.025em]">Minimum sizes</h4>
          <p className="mt-1 text-[14px] leading-relaxed text-[#55524F]">The mark stays crisp down to 16 px. Below a 72 px wide lockup the name stops reading, so drop to the mark alone.</p>
        </div>
      </div>
    </div>
  )
}

function Backgrounds() {
  const photo: CSSProperties = {
    background: 'radial-gradient(60% 70% at 20% 85%, #F5B37A 0%, transparent 60%), radial-gradient(50% 60% at 85% 20%, #7FA3C9 0%, transparent 60%), radial-gradient(70% 60% at 60% 60%, #C7765A 0%, transparent 70%), linear-gradient(170deg, #3E4F6E 0%, #8B6A72 55%, #E39A62 100%)',
  }
  const tiles: { name: string; rule: string; cls?: string; style?: CSSProperties; node: ReactNode; dark?: boolean; streaks?: boolean }[] = [
    { name: 'Paper', rule: 'Flat orange mark, ink name.', style: { background: '#F7F7F7', boxShadow: 'inset 0 0 0 1px #E7E5E2' }, node: <Wordmark size={30} /> },
    { name: 'Orange', rule: 'All white. Never orange on orange.', cls: 'af-stage', streaks: true, node: <Wordmark size={30} tone="white" />, dark: true },
    { name: 'Ink', rule: 'Flat orange mark, white name.', style: { background: '#111' }, dark: true,
      node: <span className="inline-flex items-center gap-[11px]"><Mark size={33} /><span className="text-[30px] font-[650] leading-none tracking-[-0.035em] text-white">anyfmt</span></span> },
    { name: 'Photo', rule: 'All white, on the calmest part of the image.', style: photo, dark: true, node: <Wordmark size={30} tone="white" /> },
  ]
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {tiles.map((t) => (
        <div key={t.name} className="flex flex-col gap-3">
          <div className={`relative grid aspect-[4/3] place-items-center overflow-hidden rounded-[18px] ${t.cls ?? ''}`} style={t.style}>
            {t.streaks && <Streaks className="inset-0 h-full w-full" />}
            {t.name === 'Photo' && <>
              <div aria-hidden className="absolute -left-[10%] bottom-[-30%] h-[70%] w-[120%] rounded-[50%] bg-[#2C2A33]/70 blur-[18px]" />
              <div aria-hidden className="absolute right-[18%] top-[16%] size-14 rounded-full bg-[#FFE2BF] opacity-80 blur-[10px]" />
            </>}
            <div className="relative">{t.node}</div>
          </div>
          <div className="px-1"><div className="text-[15px] font-semibold">{t.name}</div><div className="text-[13px] text-[#55524F]">{t.rule}</div></div>
        </div>
      ))}
    </div>
  )
}

function Donts() {
  const busy: CSSProperties = {
    background: 'repeating-linear-gradient(45deg, #2F6BE0 0 10px, #F2C94C 10px 20px, #1F9D55 20px 30px, #E5484D 30px 40px)',
  }
  const items: { label: string; node: ReactNode; style?: CSSProperties }[] = [
    { label: 'Stretch or squash it', node: <Mark size={84} style={{ transform: 'scaleX(1.5)' }} /> },
    { label: 'Recolour it', node: <Mark size={84} style={{ filter: 'hue-rotate(190deg) saturate(1.3)' }} /> },
    { label: 'Rotate it', node: <Mark size={84} style={{ transform: 'rotate(24deg)' }} /> },
    {
      label: 'Use it as an outline',
      node: (
        <svg width="84" height="84" viewBox="0 0 100 100" aria-hidden style={{ overflow: 'visible' }}>
          {PETALS.map((d, i) => <path key={i} d={d} fill="none" stroke="#EA7C25" strokeWidth="3" strokeLinejoin="round" />)}
        </svg>
      ),
    },
    { label: 'Drop a shadow on the flat mark', node: <Mark size={84} style={{ filter: 'drop-shadow(7px 9px 4px rgba(0,0,0,.55))' }} /> },
    { label: 'Put it on a busy background', node: <Mark size={84} />, style: busy },
  ]
  return (
    <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-3">
      {items.map((it) => (
        <div key={it.label} className="af-card flex flex-col p-2">
          <div className="af-well relative grid h-[150px] place-items-center overflow-hidden sm:h-[180px]" style={it.style}>
            {it.node}
          </div>
          <div className="px-2.5 pb-2.5 pt-3.5"><Verdict ok={false}>{it.label}.</Verdict></div>
        </div>
      ))}
    </div>
  )
}

export function Logo() {
  return (
    <Section id="logo" n="02" eyebrow="Logo" title={<>One mark,<br /><span className="text-[#8C8884]">two readings.</span></>}
      intro="The anyfmt mark is four arrow-tipped quarter wedges. It is drawn from two circles and four angles, so it scales cleanly from a 16 px menu-bar glyph to a stage screen.">
      <Sub title="Construction" note="Shown as it lives in the vector file: guides, anchors and the selected path.">
        <Construction />
      </Sub>
      <Sub title="What it means" note="Hold both readings at once. That is the product: a wheel you aim at, and a file becoming something else.">
        <Meaning />
      </Sub>
      <Sub title="Wordmark and lockups" note="The name is always set in lowercase Inter Tight. Three lockups cover every space.">
        <Lockups />
      </Sub>
      <Sub title="Clear space and minimum size">
        <ClearSpace />
      </Sub>
      <Sub title="On backgrounds" note="Four backgrounds cover almost everything. When unsure, use paper.">
        <Backgrounds />
      </Sub>
      <Sub title="Six don’ts" note="The mark only works when it is exactly itself.">
        <Donts />
      </Sub>
    </Section>
  )
}

/* ---------- 03 App icon and glyphs ---------- */

function IconSizes() {
  const sizes = [
    { px: 1024, shown: 232, note: 'App Store, shown at 23%' },
    { px: 512, shown: 156, note: 'Finder, shown at 30%' },
    { px: 128, shown: 128, note: 'actual size' },
    { px: 32, shown: 32, note: 'actual' },
    { px: 16, shown: 16, note: 'actual' },
  ]
  return (
    <div className="af-card p-2">
      <div className="af-well flex flex-wrap items-end justify-center gap-x-10 gap-y-10 px-4 pb-8 pt-12 sm:justify-between sm:px-12">
        {sizes.map((s) => (
          <div key={s.px} className="flex flex-col items-center gap-4">
            <div className={s.px === 1024 ? 'max-sm:hidden' : ''}><AppIcon size={s.shown} /></div>
            {s.px === 1024 && <div className="sm:hidden"><AppIcon size={168} /></div>}
            <div className="text-center"><div className="af-mono text-[13px] font-medium">{s.px} px</div><Spec>{s.px === 1024 ? 'App Store, scaled' : s.note}</Spec></div>
          </div>
        ))}
      </div>
      <div className="grid gap-px px-3 pb-3 pt-4 sm:grid-cols-4">
        {[['Shape', 'macOS squircle, 22.5% radius'], ['Mark', 'gloss variant, 64% of the tile'], ['Body', 'white to #F2F0ED, top to bottom'], ['Shadow', 'tinted ember, never grey']].map(([k, v]) => (
          <div key={k} className="px-2 py-1.5"><div className="text-[13px] font-semibold">{k}</div><div className="text-[13px] text-[#55524F]">{v}</div></div>
        ))}
      </div>
    </div>
  )
}

function Marker({ n, style }: { n: number; style: CSSProperties }) {
  return (
    <span className="absolute z-10 grid size-7 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full bg-white text-[12px] font-bold text-[#BB3F14] shadow-[0_0_0_4px_rgba(255,255,255,.35),0_6px_14px_-4px_rgba(120,35,0,.6)]" style={style}>{n}</span>
  )
}

function GlassHero() {
  const live = useLive()
  const layers = [
    ['Body', 'Clear glass with a 30% corner, tilted 4° so the light catches one edge.'],
    ['Rim', 'A 1.5 px inner line of white at 65%, the edge of the glass.'],
    ['Specular', 'One soft highlight, top left. The light always comes from above.'],
    ['Mark', 'The gloss mark at 62%, extruded in two ember steps.'],
  ]
  return (
    <div className="grid gap-4 lg:grid-cols-[1.3fr_1fr]">
      <div className="af-stage relative grid min-h-[420px] place-items-center overflow-hidden rounded-[24px] py-14">
        <Streaks className="inset-0 h-full w-full" />
        <div className="relative" style={{ animation: live ? 'af-float 7s ease-in-out infinite' : undefined }}>
          <GlassTile size={300} className="max-sm:!size-[240px]" />
          <Marker n={1} style={{ left: '14%', top: '82%' }} />
          <Marker n={2} style={{ left: '93%', top: '30%' }} />
          <Marker n={3} style={{ left: '30%', top: '11%' }} />
          <Marker n={4} style={{ left: '62%', top: '58%' }} />
        </div>
      </div>
      <div className="af-card flex flex-col justify-between gap-8 p-6 sm:p-8">
        <div>
          <h4 className="text-[20px] font-semibold tracking-[-0.03em]">The glass tile</h4>
          <p className="mt-1 text-[15px] leading-relaxed text-[#55524F]">Our hero object, for covers, launch moments and the end of a page. Use it on orange only, one per view.</p>
        </div>
        <ol className="flex flex-col gap-4">
          {layers.map(([k, v], i) => (
            <li key={k} className="flex gap-3">
              <span className="grid size-6 shrink-0 place-items-center rounded-full bg-[#FFF3E6] text-[12px] font-bold text-[#BB3F14] ring-1 ring-[#FFD9B3]">{i + 1}</span>
              <div><div className="text-[15px] font-semibold">{k}</div><div className="text-[14px] leading-snug text-[#55524F]">{v}</div></div>
            </li>
          ))}
        </ol>
      </div>
    </div>
  )
}

function MenuBarStrip({ dark, size, open }: { dark?: boolean; size: number; open?: boolean }) {
  const fg = dark ? '#fff' : '#111'
  return (
    <div className={`flex h-9 items-center justify-between rounded-[10px] px-3 text-[12.5px] font-medium ${dark ? 'bg-[#1E1E1E] shadow-[inset_0_0_0_1px_rgba(255,255,255,.08)]' : 'bg-white/70 shadow-[inset_0_0_0_1px_rgba(17,17,17,.08)]'}`} style={{ color: fg }}>
      <span className="af-mono text-[11px] opacity-50">{size} px</span>
      <div className="flex items-center gap-3">
        <span className={`grid h-[26px] place-items-center rounded-[6px] px-1.5 ${open ? (dark ? 'bg-white/20' : 'bg-black/10') : ''}`}>
          <Mark size={size} variant="mono" style={{ color: fg, opacity: 0.9 }} />
        </span>
        <Wifi size={15} className="opacity-85" /><BatteryFull size={18} className="opacity-85" />
        <span className="max-[400px]:hidden">Mon 9:41</span>
      </div>
    </div>
  )
}

function MenuGlyph() {
  const cells = 16, px = 12
  return (
    <div className="grid gap-4 lg:grid-cols-[auto_1fr]">
      <div className="af-card flex flex-col items-center gap-4 p-6">
        <div className="relative" style={{ width: cells * px, height: cells * px }}>
          <div className="absolute inset-0 grid place-items-center"><Mark size={cells * px} variant="mono" style={{ color: '#111' }} /></div>
          <div className="absolute inset-0" style={{ backgroundImage: 'linear-gradient(rgba(90,162,255,.35) 1px, transparent 1px), linear-gradient(90deg, rgba(90,162,255,.35) 1px, transparent 1px)', backgroundSize: `${px}px ${px}px`, boxShadow: 'inset 0 0 0 1px rgba(90,162,255,.5)' }} />
        </div>
        <div className="text-center"><div className="text-[15px] font-semibold">16 × 16 template</div><Spec>black + alpha · macOS tints it</Spec></div>
      </div>
      <div className="af-card flex flex-col gap-4 p-4 sm:p-6">
        <div className="grid gap-4 md:grid-cols-2">
          {[false, true].map((dark) => (
            <div key={String(dark)} className="flex flex-col gap-2 rounded-[16px] p-3" style={{ background: dark ? 'linear-gradient(160deg,#2B2B2B,#0E0E0E)' : 'linear-gradient(160deg,#FCE6D2,#F7C79C 60%,#EE9B5C)' }}>
              <div className={`px-1 text-[12px] font-medium ${dark ? 'text-white/60' : 'text-[#55524F]'}`}>{dark ? 'Dark menu bar' : 'Light menu bar'}</div>
              {[16, 18, 22].map((s) => <MenuBarStrip key={s} dark={dark} size={s} open={s === 18} />)}
            </div>
          ))}
        </div>
        <p className="text-[14px] leading-relaxed text-[#55524F]">The menu-bar glyph is the mark as a template image: one colour, no gloss, so macOS can draw it black, white or highlighted. 18 px is the default; 16 and 22 cover compact and large menu bars. The middle row shows the open state.</p>
      </div>
    </div>
  )
}

function DockIcon({ bg, children, label }: { bg: string; children: ReactNode; label: string }) {
  return (
    <div aria-label={label} className="grid size-[64px] place-items-center rounded-[15px] text-white"
      style={{ background: bg, boxShadow: 'inset 0 1px 0 rgba(255,255,255,.35), inset 0 -2px 6px rgba(0,0,0,.12), 0 6px 14px -6px rgba(0,0,0,.45), 0 0 0 .5px rgba(0,0,0,.12)' }}>
      {children}
    </div>
  )
}

function Dock() {
  const icons: { label: string; bg: string; node: ReactNode; on?: boolean }[] = [
    { label: 'Files', bg: 'linear-gradient(180deg,#6CB4FF,#2F7BE8)', node: <Folder size={30} strokeWidth={1.8} />, on: true },
    { label: 'Browser', bg: 'linear-gradient(180deg,#5FE0C8,#1C9C8A)', node: <Globe size={30} strokeWidth={1.8} />, on: true },
    { label: 'Mail', bg: 'linear-gradient(180deg,#8FD3FF,#3D8BD9)', node: <Mail size={30} strokeWidth={1.8} /> },
    { label: 'Calendar', bg: 'linear-gradient(180deg,#FF9A8B,#E2574C)', node: <CalendarDays size={30} strokeWidth={1.8} /> },
    { label: 'Music', bg: 'linear-gradient(180deg,#FF8FC1,#D9417F)', node: <Music size={30} strokeWidth={1.8} /> },
    { label: 'Photos', bg: 'linear-gradient(180deg,#C7A6FF,#7A4FD9)', node: <ImageIcon size={30} strokeWidth={1.8} /> },
    { label: 'Terminal', bg: 'linear-gradient(180deg,#3A3A3A,#141414)', node: <span className="af-mono text-[17px] font-bold text-white/90">&gt;_</span>, on: true },
  ]
  return (
    <div className="af-card p-2">
      <Fit w={1180} h={320}>
        <div className="relative h-[320px] w-[1180px] overflow-hidden rounded-[14px]"
          style={{ background: 'radial-gradient(80% 70% at 30% 20%, #FFD9B5 0%, transparent 60%), radial-gradient(70% 80% at 90% 90%, #F29A55 0%, transparent 60%), linear-gradient(160deg,#FCE6D2,#F7C79C 55%,#EE9B5C)' }}>
          <svg className="absolute inset-0 h-full w-full opacity-70" viewBox="0 0 1180 320" preserveAspectRatio="none" aria-hidden>
            <defs><filter id="bk-dock-b"><feGaussianBlur stdDeviation="14" /></filter></defs>
            <path d="M-50 260 C 200 160, 420 320, 960 80" stroke="#fff" strokeWidth="50" fill="none" opacity=".45" filter="url(#bk-dock-b)" />
          </svg>
          {/* tooltip */}
          <div className="absolute left-1/2 top-[106px] z-10 -translate-x-1/2 translate-x-[173px] rounded-[8px] bg-[#F7F7F7]/90 px-3 py-1 text-[13px] font-medium text-[#111] shadow-[0_0_0_1px_rgba(17,17,17,.1),0_6px_16px_-6px_rgba(0,0,0,.35)] backdrop-blur">anyfmt</div>
          <div className="absolute bottom-5 left-1/2 flex -translate-x-1/2 items-end gap-2.5 rounded-[24px] bg-white/35 px-3 pb-2.5 pt-2.5 shadow-[inset_0_0_0_1px_rgba(255,255,255,.55),0_20px_40px_-20px_rgba(90,30,0,.5)] backdrop-blur-2xl">
            {icons.map((ic) => (
              <div key={ic.label} className="relative flex flex-col items-center">
                <DockIcon bg={ic.bg} label={ic.label}>{ic.node}</DockIcon>
                <span className={`mt-1 size-1 rounded-full ${ic.on ? 'bg-[#111]/60' : 'bg-transparent'}`} />
              </div>
            ))}
            <div className="relative flex flex-col items-center">
              <AppIcon size={84} style={{ marginTop: -20 }} />
              <span className="mt-1 size-1 rounded-full bg-[#111]/60" />
            </div>
            <div className="mx-1 mb-3 h-[56px] w-px bg-[#111]/15" />
            <div className="relative flex flex-col items-center">
              <DockIcon bg="linear-gradient(180deg,rgba(255,255,255,.75),rgba(255,255,255,.4))" label="Bin"><Trash2 size={28} strokeWidth={1.6} className="text-[#55524F]" /></DockIcon>
              <span className="mt-1 size-1 rounded-full bg-transparent" />
            </div>
          </div>
        </div>
      </Fit>
      <p className="px-3 pb-3 pt-4 text-[14px] leading-relaxed text-[#55524F]">In the Dock, magnified and running. Neighbours are drawn generic on purpose: the icon has to hold its own next to anything. anyfmt only shows in the Dock while its Settings window is open.</p>
    </div>
  )
}

export function Icon() {
  return (
    <Section id="icon" n="03" eyebrow="App icon and glyphs" title={<>Lit from above,<br /><span className="text-[#8C8884]">at every size.</span></>}
      intro="The app icon is the mark in its gloss form on a white squircle. The glass tile is its hero cousin. The menu-bar glyph is the mark with everything taken away but the shape.">
      <Sub title="App icon" note="Exported from one source at the five sizes macOS asks for.">
        <IconSizes />
      </Sub>
      <Sub title="The glass tile">
        <GlassHero />
      </Sub>
      <Sub title="Menu-bar glyph">
        <MenuGlyph />
      </Sub>
      <Sub title="In the Dock">
        <Dock />
      </Sub>
    </Section>
  )
}
