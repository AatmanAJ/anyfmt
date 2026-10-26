import { AnimatePresence, motion, useInView, useReducedMotion, useScroll, useTransform } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { isShot, Marquee } from '../../shared/kit'
import { product } from '../../shared/product'
import { Diagram } from './Diagram'
import { GridWheel, SETS } from './GridWheel'
import { Lockup, Mark } from './Logo'
import { GridDemo } from './Surfaces'
import {
  Arrow, Btn, C, CropMarks, DrawRule, EASE, GridOverlay, grid, Idx, Mono, Odometer, RegMark, SectionHead, ShiftGlyph, SwissKey, Wipe, wrap, useMedia,
} from './ui'

const go = (id: string) => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })

const NAV = [
  ['how', 'How'], ['wheel', 'Wheel'], ['features', 'Features'], ['privacy', 'Privacy'], ['agents', 'Agents'], ['pricing', 'Pricing'], ['faq', 'FAQ'],
] as const

/* ───────────────────────── Nav ───────────────────────── */

export function Nav({ sticky = true }: { sticky?: boolean }) {
  return (
    <header className={cn('z-50 border-b border-[#0B0B0B] bg-[#F4F4F1]', sticky && 'sticky top-0')}>
      <div className={cn(wrap, 'flex h-16 items-center justify-between gap-6')}>
        <button type="button" onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })} aria-label="Halo, top of page"><Lockup h={24} /></button>
        <nav className="hidden items-center gap-1 lg:flex" aria-label="Sections">
          {NAV.map(([id, label], i) => (
            <button key={id} type="button" onClick={() => go(id)}
              className="group flex items-center gap-1.5 px-2.5 py-2 font-mono text-[11px] font-medium uppercase tracking-[0.08em] text-[#0B0B0B] hover:bg-[#0B0B0B] hover:text-[#F4F4F1]">
              <span className="text-[#5C5C56] group-hover:text-[#FF3D2E]">{String(i + 2).padStart(2, '0')}</span>{label}
            </button>
          ))}
        </nav>
        <div className="flex items-center gap-4">
          <Mono className="hidden text-[#5C5C56] xl:block">v1.0 · macOS 13+</Mono>
          <Btn size="sm">Download <Arrow /></Btn>
        </div>
      </div>
    </header>
  )
}

/* ───────────────────────── Hero ───────────────────────── */

export function Hero({ embedded }: { embedded?: boolean }) {
  const md = useMedia('(min-width: 768px)')
  const reduce = useReducedMotion()
  const { scrollY } = useScroll()
  const gy = useTransform(scrollY, [0, 900], [0, embedded || reduce ? 0 : -160])
  const gw = md ? 1120 : 600
  const size = md ? 380 : 296
  return (
    <section className="relative overflow-hidden">
      <div className={wrap}>
        {/* Meta row */}
        <div className={cn(grid, 'gap-y-2 border-b border-[#D6D6D0] py-3')}>
          <Mono className="col-span-2 md:col-span-3">Halo / 1.0</Mono>
          <Mono className="col-span-2 text-right text-[#5C5C56] md:col-span-3 md:text-left">{product.platform}</Mono>
          <Mono className="col-span-2 hidden text-[#5C5C56] md:col-span-3 md:block">AGPL-3.0 · No account</Mono>
          <Mono className="col-span-2 hidden text-right text-[#5C5C56] md:col-span-3 md:block">Fig. 01 — the drag</Mono>
        </div>

        <div className={cn(grid, 'relative pb-14 pt-10 md:min-h-[760px] md:pb-24 md:pt-16')}>
          <div className="relative z-10 col-span-4 md:col-span-7">
            <Idx n="01" />
            <h1 className="mt-6 font-grotesk text-[clamp(84px,13.4vw,200px)] font-semibold leading-[0.8] tracking-[-0.072em] text-[#0B0B0B]">
              <Wipe>Drag.</Wipe>
              <Wipe delay={0.12}>Press.</Wipe>
              <Wipe delay={0.24}>Drop.</Wipe>
            </h1>
            <div className="mt-10 grid max-w-[620px] grid-cols-1 gap-6 md:grid-cols-[1fr_auto]">
              <p className="max-w-[36ch] text-[18px] leading-[1.42] text-[#0B0B0B] md:text-[19px]">{product.how}</p>
            </div>
            <div className="mt-8 flex flex-wrap gap-3">
              <Btn size="lg">Download for macOS <Arrow /></Btn>
              <Btn size="lg" kind="ghost">Read the source</Btn>
            </div>
            <div className="mt-8 flex flex-wrap gap-x-6 gap-y-2">
              {['Free, open source', '0 network calls', '793 routes'].map((t) => (
                <span key={t} className="flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.08em]"><span className="size-1.5 bg-[#0B0B0B]" />{t}</span>
              ))}
            </div>
          </div>

          <div className="relative col-span-4 mt-14 h-[420px] md:col-span-5 md:mt-0 md:h-auto">
            <motion.div aria-hidden className="pointer-events-none absolute left-1/2" style={{ width: gw, top: md ? -40 : -36, x: '-50%', y: gy }}>
              <ShiftGlyph className="block h-auto w-full" />
            </motion.div>
            <div className="absolute left-1/2 -translate-x-1/2" style={{ top: md ? 182 : 46 }}>
              <div className="relative">
                <GridDemo segments={SETS.convert} target={0} sweep={[2, 1, 0]} size={size} hub="clip.mov" hubSub="8 FORMATS"
                  ext="MOV" name="clip.mov — 6.2 s" keySym="⇧" keyName="Shift" result="clip.gif" resultMeta="2.4 MB · 15 FPS · 0.9 S" />
                <CropMarks inset={-22} />
              </div>
            </div>
            {md && (
              <div className="absolute right-0 top-[600px] z-10 bg-[#0B0B0B] px-3 py-2 font-mono text-[10px] uppercase tracking-[0.08em] text-[#F4F4F1]">
                ⇧ Shift → Convert · 8 targets
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Format marquee ───────────────────────── */

export function Formats() {
  return (
    <section className="relative z-[1] overflow-hidden border-y border-[#0B0B0B] bg-[#0B0B0B] py-5 text-[#F4F4F1]" aria-label="Conversions">
      <Marquee duration={50} className="gap-0">
        {product.conversions.map((c) => (
          <span key={c} className="flex shrink-0 items-center gap-8 pr-8 font-grotesk text-[34px] font-medium leading-none tracking-[-0.04em] md:text-[44px]">
            {c}<span className="block size-3 bg-[#FF3D2E]" />
          </span>
        ))}
      </Marquee>
      <Marquee duration={36} reverse className="mt-4 gap-0">
        {[...product.formatsImage, ...product.formatsVideo, ...product.tools].map((c, i) => (
          <span key={c + i} className="shrink-0 pr-6 font-mono text-[11px] uppercase tracking-[0.1em] text-[#8E8E87]">
            {String(i + 1).padStart(3, '0')} {c} <span className="text-[#3A3A38]">/</span>
          </span>
        ))}
      </Marquee>
    </section>
  )
}

/* ───────────────────────── How it works ───────────────────────── */

const HOW = [
  { ...product.keys[0], set: SETS.convert, hub: 'clip.mov', sub: '8 FORMATS' },
  { ...product.keys[1], set: SETS.tools, hub: 'photo.heic', sub: '8 TOOLS' },
  { ...product.keys[2], set: SETS.actions, hub: 'report.pdf', sub: '6 ACTIONS' },
]

export function How() {
  const [hot, setHot] = useState<number | null>(null)
  return (
    <section id="how" className="relative scroll-mt-16 py-16 md:py-24">
      <div className={wrap}>
        <SectionHead n="02" kicker="How it works" title={<>Three keys.<br />Three wheels.</>} caption={product.how} />
        <div className={cn(grid, 'mt-14 gap-y-12 md:mt-20')}>
          {HOW.map((k, i) => (
            <div key={k.key} className="col-span-4 border-t border-[#0B0B0B] pt-4"
              onPointerEnter={() => setHot(i)} onPointerLeave={() => setHot(null)}>
              <div className="flex items-start justify-between">
                <Mono className="text-[#5C5C56]">{String(i + 1).padStart(2, '0')} / 03</Mono>
                <SwissKey symbol={k.key} name={k.name} pressed={hot === i} size={60} />
              </div>
              <div className="mt-6 font-grotesk text-[56px] font-semibold leading-[0.9] tracking-[-0.055em]">{k.wheel}</div>
              <p className="mt-3 max-w-[30ch] text-[15px] leading-snug text-[#5C5C56]">Hold {k.name}. {k.blurb}</p>
              <div className="mt-8 flex justify-center">
                <GridWheel segments={k.set} size={300} hub={k.hub} hubSub={k.sub} title={`${k.wheel} wheel`} />
              </div>
              <div className="mt-4 flex justify-between border-t border-[#D6D6D0] pt-2 font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">
                <span>{k.set.length} wedges</span><span>{k.key} + drag</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Interactive diagram ───────────────────────── */

export function WheelSection() {
  return (
    <section id="wheel" className="relative scroll-mt-16 py-16 md:py-24">
      <div className={wrap}>
        <SectionHead n="03" kicker="Fig. 02 — Interactive" title={<>Point at it.</>}
          caption="Move your pointer round the ring. The readout says exactly what a drop would do. Click to drop." />
        <div className="mt-12"><Diagram /></div>
      </div>
    </section>
  )
}

/* ───────────────────────── Features bento ───────────────────────── */

function Cell({ n, title, children, className, dark }: { n: string; title: string; children: ReactNode; className?: string; dark?: boolean }) {
  return (
    <div className={cn('group relative overflow-hidden p-5 md:p-7', dark ? 'bg-[#0B0B0B] text-[#F4F4F1]' : 'bg-[#F4F4F1] text-[#0B0B0B]', className)}>
      <span aria-hidden className="absolute inset-x-0 top-0 h-[3px] origin-left scale-x-0 bg-[#FF3D2E] transition-transform duration-300 ease-[cubic-bezier(.7,0,.2,1)] group-hover:scale-x-100" />
      <div className="flex items-start justify-between">
        <Idx n={n} light={dark} />
        <Mono className={dark ? 'text-[#8E8E87]' : 'text-[#5C5C56]'}>{title}</Mono>
      </div>
      <h3 className="mt-6 font-grotesk text-[40px] font-semibold leading-[0.9] tracking-[-0.05em] md:text-[52px]">{title}</h3>
      {children}
    </div>
  )
}

export function Bento() {
  const f = product.features
  const rows = product.conversions.slice(0, 9).map((c) => {
    const [a, b] = c.includes('→') ? c.split(' → ') : c.split(' ← ').reverse()
    return [a, b]
  })
  return (
    <section id="features" className="relative scroll-mt-16 py-16 md:py-24">
      <div className={wrap}>
        <SectionHead n="04" kicker="Features" title={<>Six things.<br />Each one exact.</>} caption="Every line below is a thing Halo does today. Nothing here is a roadmap." />
        <div className="mt-14 grid grid-cols-1 gap-px border border-[#0B0B0B] bg-[#0B0B0B] md:mt-20 md:grid-cols-12">
          <Cell n="01" title={f[0].title} dark className="md:col-span-7 md:row-span-2">
            <div className="mt-4 flex items-end justify-between gap-6">
              <p className="max-w-[34ch] text-[15px] leading-snug text-[#BDBDB6]">{f[0].body}</p>
              <div className="shrink-0 text-right font-grotesk text-[72px] font-semibold leading-none tracking-[-0.06em] text-[#FF3D2E] md:text-[96px]"><Odometer value="793" /></div>
            </div>
            <table className="mt-8 w-full border-collapse font-mono text-[12px] md:text-[13px]">
              <thead>
                <tr className="border-y border-[#3A3A38] text-left text-[10px] uppercase tracking-[0.08em] text-[#8E8E87]">
                  <th className="py-2 pr-3 font-medium">No.</th><th className="py-2 pr-3 font-medium">From</th><th className="py-2 pr-3 font-medium">To</th><th className="py-2 text-right font-medium">Wheel</th>
                </tr>
              </thead>
              <tbody>
                {rows.map(([a, b], i) => (
                  <tr key={i} className="border-b border-[#262624] transition-colors hover:bg-[#FF3D2E] hover:text-[#0B0B0B]">
                    <td className="py-[7px] pr-3 text-[#8E8E87]">{String(i + 1).padStart(3, '0')}</td>
                    <td className="py-[7px] pr-3">{a}</td>
                    <td className="py-[7px] pr-3">→ {b}</td>
                    <td className="py-[7px] text-right">⇧</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="mt-3 font-mono text-[10px] uppercase tracking-[0.08em] text-[#8E8E87]">009 of 793 shown</div>
          </Cell>
          <Cell n="02" title={f[1].title} className="md:col-span-5">
            <p className="mt-4 max-w-[40ch] text-[15px] leading-snug text-[#5C5C56]">{f[1].body}</p>
            <ol className="mt-6 grid grid-cols-2 gap-x-6 border-t border-[#D6D6D0] font-mono text-[12px]">
              {product.tools.map((t, i) => (
                <li key={t} className="flex justify-between border-b border-[#D6D6D0] py-1.5"><span>{t}</span><span className="text-[#5C5C56]">⌘{String(i + 1).padStart(2, '0')}</span></li>
              ))}
            </ol>
          </Cell>
          <Cell n="03" title={f[2].title} className="md:col-span-5">
            <p className="mt-4 max-w-[40ch] text-[15px] leading-snug text-[#5C5C56]">{f[2].body}</p>
            <div className="mt-6 flex flex-wrap gap-1.5">
              {product.actions.map((a) => (
                <span key={a} className="border border-[#0B0B0B] px-2 py-1 font-mono text-[11px] uppercase tracking-[0.04em]">⌃ {a}</span>
              ))}
            </div>
          </Cell>
          <Cell n="04" title={f[3].title} className="md:col-span-4">
            <p className="mt-4 text-[15px] leading-snug text-[#5C5C56]">{f[3].body}</p>
            <div className="mt-6 flex gap-1.5">
              {[['GIF', '15 fps'], ['JPG', '80 %']].map(([a, b], i) => (
                <span key={a} className={cn('flex items-baseline gap-1.5 rounded-[4px] border px-2.5 py-1.5', i === 0 ? 'border-[#0B0B0B] bg-[#0B0B0B] text-[#F4F4F1]' : 'border-[#0B0B0B]')}>
                  <span className="font-grotesk text-[15px] font-semibold">{a}</span><span className="font-mono text-[11px] opacity-70">{b}</span>
                </span>
              ))}
            </div>
          </Cell>
          <Cell n="05" title={f[4].title} className="md:col-span-4">
            <p className="mt-4 text-[15px] leading-snug text-[#5C5C56]">{f[4].body}</p>
            <div className="mt-6 overflow-x-auto bg-[#0B0B0B] px-3 py-2.5 font-mono text-[12px] text-[#F4F4F1] no-scrollbar">
              <span className="text-[#FF3D2E]">$</span> halo convert clip.mov --to gif --json
            </div>
          </Cell>
          <Cell n="06" title={f[5].title} className="md:col-span-4">
            <p className="mt-4 text-[15px] leading-snug text-[#5C5C56]">{f[5].body}</p>
            <div className="mt-6 flex items-baseline gap-3">
              <span className="font-grotesk text-[64px] font-semibold leading-[0.8] tracking-[-0.06em]">0</span>
              <Mono className="text-[#5C5C56]">network calls<br />unless you ask</Mono>
            </div>
          </Cell>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Stats ───────────────────────── */

const sentence = (t: string) => t[0].toUpperCase() + t.slice(1) + (/[.…]$/.test(t) ? '' : '.')

export function Stats() {
  const [lead, ...rest] = product.stats
  return (
    <section id="numbers" className="relative scroll-mt-16 overflow-hidden py-16 md:py-24">
      <div className={wrap}>
        <div className={cn(grid, 'border-t border-[#0B0B0B] pt-3')}>
          <div className="col-span-1 md:col-span-2"><Idx n="05" /></div>
          <Mono className="col-span-3 md:col-span-4">Numbers</Mono>
          <Mono className="col-span-4 mt-2 text-[#5C5C56] md:col-span-4 md:col-start-9 md:mt-0">Measured on the shipping build</Mono>
        </div>
        <div className="mt-6 md:mt-4">
          <div className="font-grotesk text-[clamp(150px,40vw,620px)] font-semibold leading-[0.8] tracking-[-0.085em] text-[#0B0B0B]" style={{ marginLeft: '-0.04em' }}>
            <Odometer value={lead.value} />
          </div>
          <div className={cn(grid, 'mt-6 items-start gap-y-3 border-t border-[#0B0B0B] pt-3')}>
            <div className="col-span-1 md:col-span-2"><span className="mt-1 block h-3 w-12 bg-[#FF3D2E]" /></div>
            <p className="col-span-3 font-grotesk text-[28px] font-medium leading-[1] tracking-[-0.04em] md:col-span-6 md:text-[40px]">{sentence(lead.label)}</p>
            <p className="col-span-4 text-[14px] leading-snug text-[#5C5C56] md:col-span-4">Images, video, audio, documents, ebooks and archives. Multi-hop routes picked for quality.</p>
          </div>
        </div>
        <div className="mt-16 grid grid-cols-1 border-t border-[#0B0B0B] md:grid-cols-3">
          {rest.map((s, i) => (
            <div key={s.label} className={cn('py-6 md:px-6', i > 0 && 'border-t border-[#D6D6D0] md:border-l md:border-t-0', i === 0 && 'md:pl-0')}>
              <Mono className="text-[#5C5C56]">{String(i + 2).padStart(2, '0')}</Mono>
              <div className="mt-4 font-grotesk text-[88px] font-semibold leading-[0.85] tracking-[-0.06em]"><Odometer value={s.value} delay={0.1 * i} /></div>
              <p className="mt-3 text-[15px] text-[#5C5C56]">{sentence(s.label)}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Privacy ───────────────────────── */

const LEAVES = [
  ['Your files', 'Stay on your disk'], ['Account', 'None'], ['Upload', 'None'], ['Telemetry', 'None'],
  ['Network calls', '0, unless you ask'], ['Pro cloud', 'Opt-in, per file'],
] as const

export function Privacy() {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const reduce = useReducedMotion()
  const rot = useTransform(scrollYProgress, [0, 1], [-30, 60])
  return (
    <section id="privacy" className="relative scroll-mt-16 py-16 md:py-24">
      <div className={wrap}>
        <SectionHead n="06" kicker="Privacy · local" title={<>Nothing leaves.<br />Unless you ask.</>} caption={product.features[5].body} />
        <div ref={ref} className={cn(grid, 'mt-14 items-center gap-y-10 md:mt-20')}>
          <div className="relative col-span-4 flex justify-center md:col-span-6">
            <div className="relative aspect-square w-full max-w-[520px]">
              <svg viewBox="0 0 400 400" className="absolute inset-0 h-full w-full" aria-hidden>
                <circle cx="200" cy="200" r="168" fill="none" stroke={C.ink} strokeWidth="58" />
                <circle cx="200" cy="200" r="200" fill="none" stroke={C.rule} strokeWidth="1" />
                <circle cx="200" cy="200" r="132" fill="none" stroke={C.rule} strokeWidth="1" strokeDasharray="4 6" />
                <line x1="0" y1="200" x2="400" y2="200" stroke={C.rule} strokeDasharray="4 6" />
                <line x1="200" y1="0" x2="200" y2="400" stroke={C.rule} strokeDasharray="4 6" />
              </svg>
              <motion.svg viewBox="0 0 400 400" className="absolute inset-0 h-full w-full" style={{ rotate: reduce || isShot ? 0 : rot }} aria-hidden>
                <path d="M200 3 A197 197 0 0 1 270 16 L250 70 A140 140 0 0 0 200 61 Z" fill={C.red} />
              </motion.svg>
              <div className="absolute inset-0 grid place-items-center text-center">
                <div>
                  <div className="font-grotesk text-[88px] font-semibold leading-none tracking-[-0.06em] md:text-[120px]">0</div>
                  <Mono className="mt-2 block text-[#5C5C56]">network calls</Mono>
                </div>
              </div>
              <RegMark className="absolute -left-2 -top-2" />
              <RegMark className="absolute -bottom-2 -right-2" />
            </div>
          </div>
          <div className="col-span-4 md:col-span-5 md:col-start-8">
            <Mono className="text-[#5C5C56]">Table 06.1 — What leaves your Mac</Mono>
            <table className="mt-4 w-full border-collapse">
              <tbody>
                {LEAVES.map(([k, v], i) => (
                  <tr key={k} className="border-t border-[#0B0B0B] last:border-b">
                    <td className="w-10 py-4 align-top font-mono text-[11px] text-[#5C5C56]">{String(i + 1).padStart(2, '0')}</td>
                    <td className="py-4 pr-4 align-top font-grotesk text-[20px] font-medium tracking-[-0.02em] md:text-[22px]">{k}</td>
                    <td className="py-4 text-right align-top font-mono text-[13px]">{v === 'None' ? <span className="inline-flex items-center gap-2">None <span className="size-2 bg-[#0B0B0B]" /></span> : v}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="mt-6 max-w-[44ch] text-[14px] leading-relaxed text-[#5C5C56]">{product.licence} Read every line that touches your files.</p>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Agents / CLI ───────────────────────── */

const TERM = [
  { p: '$', t: 'halo convert clip.mov --to gif --json' },
  { t: '{"event":"start","input":"clip.mov","to":"gif"}' },
  { t: '{"event":"progress","pct":34}' },
  { t: '{"event":"progress","pct":78}' },
  { t: '{"event":"done","output":"clip.gif","bytes":2516582}' },
  { p: '$', t: 'halo mcp' },
  { t: 'MCP server on stdio · tools: convert, tools, actions' },
  { p: '$', t: ' ' },
]

function Terminal() {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: true, margin: '-80px' })
  const reduce = useReducedMotion()
  const total = TERM.reduce((a, l) => a + l.t.length, 0)
  const [chars, setChars] = useState(isShot || reduce ? total : 0)
  useEffect(() => {
    if (!inView || isShot || reduce) return
    const id = setInterval(() => setChars((c) => (c >= total ? c : c + 3)), 16)
    return () => clearInterval(id)
  }, [inView, total, reduce])
  let left = chars
  return (
    <div ref={ref} className="relative border border-[#3A3A38] bg-[#000] font-mono text-[12px] leading-[1.9] md:text-[13px]">
      <div className="flex items-center justify-between border-b border-[#2A2A28] px-4 py-2.5 text-[10px] uppercase tracking-[0.08em] text-[#8E8E87]">
        <span>zsh — ~/Desktop</span><span>NDJSON</span>
      </div>
      <div className="min-h-[264px] overflow-x-auto px-4 py-4 no-scrollbar">
        {TERM.map((l, i) => {
          const show = Math.max(0, Math.min(l.t.length, left))
          left -= l.t.length
          if (show === 0 && i > 0 && left < 0) return <div key={i} className="whitespace-pre">&nbsp;</div>
          const typing = show < l.t.length
          return (
            <div key={i} className={cn('whitespace-pre', l.p ? 'text-[#F4F4F1]' : 'text-[#A9A9A2]')}>
              {l.p && <span className="mr-2 text-[#FF3D2E]">{l.p}</span>}
              {l.t.slice(0, show).replace(/"done"/, '"done"')}
              {(typing || i === TERM.length - 1) && <span className="ml-px inline-block h-[1em] w-[0.6em] translate-y-[2px] bg-[#FF3D2E]" />}
            </div>
          )
        })}
      </div>
    </div>
  )
}

export function Agents() {
  const specs = [
    ['CLI', 'Every route and every tool, from any shell or script.'],
    ['JSON', 'One result object, or NDJSON progress while it runs.'],
    ['MCP', 'A server Claude can call. It converts your files, locally.'],
    ['Same engine', 'The wheel and the CLI run the same code.'],
  ]
  return (
    <section id="agents" className="relative z-[1] scroll-mt-16 overflow-hidden bg-[#0B0B0B] py-20 text-[#F4F4F1] md:py-28">
      <GridOverlay fixed={false} tone="rgba(255,255,255,.06)" />
      <div className={cn(wrap, 'relative')}>
        <SectionHead dark n="07" kicker="Agents · CLI · MCP" title={<>Your agent<br />can drag too.</>} caption={product.features[4].body} />
        <div className={cn(grid, 'mt-14 gap-y-10 md:mt-20')}>
          <div className="col-span-4 md:col-span-7"><Terminal /></div>
          <ol className="col-span-4 md:col-span-4 md:col-start-9">
            {specs.map(([k, v], i) => (
              <li key={k} className="grid grid-cols-[40px_1fr] border-t border-[#3A3A38] py-4 last:border-b">
                <span className="font-mono text-[11px] text-[#8E8E87]">{String(i + 1).padStart(2, '0')}</span>
                <div>
                  <div className="font-grotesk text-[22px] font-semibold tracking-[-0.03em]">{k}</div>
                  <div className="mt-1 text-[14px] leading-snug text-[#A9A9A2]">{v}</div>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Pricing ───────────────────────── */

export function Pricing() {
  return (
    <section id="pricing" className="relative scroll-mt-16 py-16 md:py-24">
      <div className={wrap}>
        <SectionHead n="08" kicker="Pricing" title={<>Two plans.<br />One is free.</>} caption="Every local feature is free, forever. Pro adds things that need a server." />
        <div className={cn(grid, 'mt-14 gap-y-6 md:mt-20')}>
          {product.pricing.map((p, i) => (
            <div key={p.name} className={cn('relative col-span-4 flex flex-col border border-[#0B0B0B] md:col-span-6', i === 0 ? 'bg-white' : 'bg-[#F4F4F1]')}>
              {i === 1 && <span className="absolute inset-x-0 top-0 h-2 bg-[#FF3D2E]" />}
              <div className="flex items-start justify-between border-b border-[#0B0B0B] px-5 pb-4 pt-6 md:px-8">
                <div>
                  <Mono className="text-[#5C5C56]">Plan {String(i + 1).padStart(2, '0')}</Mono>
                  <div className="mt-3 font-grotesk text-[32px] font-semibold leading-none tracking-[-0.04em]">{p.name}</div>
                </div>
                <div className="text-right">
                  <div className="font-grotesk text-[72px] font-semibold leading-[0.8] tracking-[-0.06em] md:text-[96px]">{p.price}</div>
                  <Mono className="mt-2 block text-[#5C5C56]">{p.period}</Mono>
                </div>
              </div>
              <ol className="flex-1 px-5 py-4 md:px-8">
                {p.points.map((pt, k) => (
                  <li key={pt} className="flex items-baseline gap-4 border-b border-[#D6D6D0] py-3 last:border-0">
                    <span className="font-mono text-[11px] text-[#5C5C56]">{String(k + 1).padStart(2, '0')}</span>
                    <span className="text-[16px]">{pt}</span>
                  </li>
                ))}
              </ol>
              <div className="px-5 pb-6 md:px-8">
                {i === 0 ? <Btn className="w-full justify-between">Download for macOS <Arrow /></Btn> : <Btn kind="ghost" className="w-full justify-between">Start Pro <Arrow /></Btn>}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── FAQ ───────────────────────── */

const QA = [
  ['What does Halo do?', product.how],
  ['Is it free?', `Yes. ${product.licence} Pro is $4 a month and adds features that need a server.`],
  ['Does anything leave my Mac?', 'No. Zero network calls unless you ask. No account, no upload, no telemetry. Pro cloud is opt-in.'],
  ['Which Macs does it run on?', 'macOS 13 or later, on Apple silicon.'],
  ['How many formats?', '793 conversion routes across images, video, audio, documents, ebooks and archives. Every one is tested.'],
  ['Can my agent use it?', 'Yes. A CLI with JSON and NDJSON progress, plus an MCP server. Claude can convert your files, locally.'],
] as const

export function FAQ() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="relative scroll-mt-16 py-16 md:py-24">
      <div className={wrap}>
        <SectionHead n="09" kicker="FAQ" title="Questions." caption="Six of them. Short answers." />
        <div className="mt-12 border-b border-[#0B0B0B] md:mt-16">
          {QA.map(([q, a], i) => {
            const on = open === i
            return (
              <div key={q} className="border-t border-[#0B0B0B]">
                <button type="button" onClick={() => setOpen(on ? null : i)} aria-expanded={on}
                  className={cn(grid, 'w-full items-center py-5 text-left transition-colors hover:bg-white md:py-6')}>
                  <span className="hidden font-mono text-[11px] text-[#5C5C56] md:col-span-2 md:block">{String(i + 1).padStart(2, '0')}</span>
                  <span className="col-span-3 font-grotesk text-[22px] font-medium leading-tight tracking-[-0.03em] md:col-span-8 md:text-[32px]">{q}</span>
                  <span className="col-span-1 flex justify-end md:col-span-2">
                    <span className={cn('grid size-9 place-items-center border transition-colors duration-100', on ? 'border-[#FF3D2E] bg-[#FF3D2E]' : 'border-[#0B0B0B]')}>
                      <motion.svg width="14" height="14" viewBox="0 0 14 14" animate={{ rotate: on ? 45 : 0 }} transition={{ duration: 0.18, ease: EASE }} aria-hidden>
                        <path d="M7 0v14M0 7h14" stroke={C.ink} strokeWidth="1.8" />
                      </motion.svg>
                    </span>
                  </span>
                </button>
                <AnimatePresence initial={false}>
                  {on && (
                    <motion.div initial={isShot ? false : { height: 0 }} animate={{ height: 'auto' }} exit={{ height: 0 }} transition={{ duration: 0.24, ease: EASE }} className="overflow-hidden">
                      <div className={cn(grid, 'pb-7')}>
                        <p className="col-span-4 max-w-[60ch] text-[16px] leading-relaxed text-[#3A3A38] md:col-span-7 md:col-start-3 md:text-[18px]">{a}</p>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Final CTA + footer ───────────────────────── */

export function FinalCTA() {
  return (
    <section className="relative z-[1] overflow-hidden bg-[#FF3D2E] text-[#0B0B0B]">
      <GridOverlay fixed={false} tone="rgba(11,11,11,.12)" />
      <div className={cn(wrap, 'relative pt-16 md:pt-24')}>
        <div className={cn(grid, 'border-t border-[#0B0B0B] pt-3')}>
          <div className="col-span-1 md:col-span-2"><span className="font-mono text-[11px] font-semibold">10</span></div>
          <Mono className="col-span-3 md:col-span-4">Download</Mono>
          <Mono className="col-span-4 mt-2 md:col-span-4 md:col-start-9 md:mt-0">{product.platform} · Free</Mono>
        </div>
        <div className={cn(grid, 'mt-10 items-end gap-y-8')}>
          <p className="col-span-4 font-grotesk text-[28px] font-medium leading-[1.05] tracking-[-0.04em] md:col-span-6 md:text-[40px]">{product.oneLiner}</p>
          <div className="col-span-4 flex flex-wrap gap-3 md:col-span-5 md:col-start-8 md:justify-end">
            <Btn size="lg">Download for macOS <Arrow /></Btn>
            <Btn size="lg" kind="ghost">GitHub</Btn>
          </div>
        </div>
        <div aria-hidden className="mt-10 select-none font-grotesk text-[clamp(140px,34vw,520px)] font-semibold leading-[0.74] tracking-[-0.085em] md:mt-6" style={{ marginBottom: '-0.12em', marginLeft: '-0.05em' }}>
          Drop.
        </div>
      </div>
    </section>
  )
}

export function Footer() {
  const cols = [
    ['Product', ['Convert', 'Tools', 'Actions', 'Presets', 'Pricing']],
    ['Build', ['Source (AGPL-3.0)', 'CLI reference', 'MCP server', 'Changelog']],
    ['Colophon', ['Space Grotesk', 'Inter', 'JetBrains Mono', '12 columns, 24 px gutter']],
  ] as const
  return (
    <footer className="relative z-[1] bg-[#F4F4F1] pb-28 pt-14">
      <div className={wrap}>
        <div className={cn(grid, 'gap-y-10')}>
          <div className="col-span-4 md:col-span-3">
            <Lockup h={28} />
            <p className="mt-4 max-w-[30ch] text-[14px] leading-snug text-[#5C5C56]">{product.oneLiner}</p>
          </div>
          {cols.map(([h, items]) => (
            <div key={h} className="col-span-2 md:col-span-3">
              <Mono className="text-[#5C5C56]">{h}</Mono>
              <ul className="mt-4 space-y-2 text-[14px]">{items.map((x) => <li key={x}><span className="cursor-default hover:underline">{x}</span></li>)}</ul>
            </div>
          ))}
        </div>
        <DrawRule className="mt-14" />
        <div className="mt-3 flex flex-wrap justify-between gap-3 font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">
          <span>© 2026 Halo · AGPL-3.0</span>
          <span className="flex items-center gap-2"><Mark size={12} /> Set on a 12-column grid</span>
        </div>
      </div>
    </footer>
  )
}

function ScrollBar() {
  const { scrollYProgress } = useScroll()
  return <motion.div aria-hidden className="fixed inset-x-0 top-0 z-[60] h-[3px] origin-left bg-[#FF3D2E]" style={{ scaleX: scrollYProgress }} />
}

export function Landing() {
  return (
    <div className="relative min-h-screen overflow-x-clip bg-[#F4F4F1] font-sans text-[#0B0B0B] selection:bg-[#FF3D2E] selection:text-[#0B0B0B]">
      <GridOverlay />
      <ScrollBar />
      <div className="relative z-[1]">
        <Nav />
        <main>
          <Hero />
          <Formats />
          <How />
          <WheelSection />
          <Bento />
          <Stats />
          <Privacy />
          <Agents />
          <Pricing />
          <FAQ />
          <FinalCTA />
        </main>
        <Footer />
      </div>
    </div>
  )
}
