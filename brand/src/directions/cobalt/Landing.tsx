import { AnimatePresence, motion, useReducedMotion, useScroll, useTransform } from 'motion/react'
import { ArrowDownToLine, ArrowRight, Check, CloudOff, GitFork, Lock, Plus, ShieldCheck, UserX, WifiOff } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { Magnetic, Marquee, SpotlightCard, isShot } from '../../shared/kit'
import { product } from '../../shared/product'
import { CobaltWheel, Hub, type Seg } from './CobaltWheel'
import { Lockup, Mark } from './Logo'
import { C, FLAME_GRAD, cssVars } from './tokens'
import {
  Bands, CobaltDemo, Eyebrow, KeyCap, RaceNumber, SkewOnScroll, Sticker, actionSegs, convertSegs, outline,
  toolSegs, useVelocitySkew, Ticker,
} from './ui'

const W = 'mx-auto w-full max-w-[1320px] px-4 sm:px-6 lg:px-10'

/* ───────────────────────── Nav ───────────────────────── */
export function Nav({ fixed = true }: { fixed?: boolean }) {
  const links = [['How', '#how'], ['Features', '#features'], ['Agents', '#agents'], ['Pricing', '#pricing'], ['FAQ', '#faq']]
  return (
    <div className={cn('inset-x-0 top-3 z-50 px-3', fixed ? 'fixed' : 'absolute')}>
      <nav className="mx-auto flex h-14 max-w-[1320px] items-center justify-between rounded-[16px] pl-4 pr-2 font-geist backdrop-blur-xl"
           style={{ background: 'rgba(5,10,46,.72)', color: C.ice, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14)' }} aria-label="Main">
        <a href="#top" className="flex items-center" aria-label="Halo home"><Lockup size={24} /></a>
        <div className="hidden items-center gap-1 md:flex">
          {links.map(([l, h]) => (
            <a key={l} href={h} onClick={(e) => { e.preventDefault(); document.querySelector(h)?.scrollIntoView({ behavior: 'smooth' }) }}
               className="rounded-[10px] px-3 py-2 font-anton text-[15px] uppercase tracking-[0.06em] text-[#E9EEFF]/75 transition-colors hover:bg-white/10 hover:text-[#E9EEFF]">{l}</a>
          ))}
        </div>
        <div className="flex items-center gap-2">
          <a href="#agents" className="hidden h-10 items-center gap-2 rounded-[11px] px-3 text-[13px] font-semibold text-[#E9EEFF]/85 hover:bg-white/10 sm:flex"><GitFork size={16} /> Source</a>
          <a href="#pricing" className="flex h-10 items-center gap-2 rounded-[11px] px-4 font-anton text-[15px] uppercase tracking-[0.06em] transition-transform hover:-translate-y-0.5"
             style={{ background: C.flame, color: C.midnight, boxShadow: '0 0 24px rgba(255,106,43,.45)' }}>
            <ArrowDownToLine size={16} strokeWidth={2.6} /> Download
          </a>
        </div>
      </nav>
    </div>
  )
}

function CTA({ children, href = '#pricing', ghost }: { children: ReactNode; href?: string; ghost?: boolean }) {
  return (
    <Magnetic strength={0.18}>
      <a href={href}
         className="group inline-flex h-14 items-center gap-3 rounded-[14px] px-6 font-anton text-[19px] uppercase tracking-[0.05em] transition-transform active:translate-y-0.5"
         style={ghost
           ? { color: C.ice, boxShadow: `inset 0 0 0 2px ${C.ice}` }
           : { background: C.flame, color: C.midnight, boxShadow: `0 6px 0 ${C.midnight}, 0 0 40px rgba(255,106,43,.45)` }}>
        {children}
      </a>
    </Magnetic>
  )
}

/* ───────────────────────── Hero ───────────────────────── */
export function Hero({ preview }: { preview?: boolean }) {
  const ref = useRef<HTMLElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const x = useTransform(scrollYProgress, [0, 1], reduce || isShot ? ['0%', '0%'] : ['0%', '-14%'])
  const skewX = useVelocitySkew(14)
  const calc = () => (window.innerWidth < 640 ? Math.min(320, window.innerWidth - 56) : window.innerWidth < 1100 ? 380 : 440)
  const [demoSize, setDemoSize] = useState(preview ? 420 : calc)
  useEffect(() => {
    if (preview) return
    const f = () => setDemoSize(calc())
    window.addEventListener('resize', f); return () => window.removeEventListener('resize', f)
  }, [preview]) // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <section ref={ref} id="top" className="relative isolate overflow-hidden" style={{ background: C.cobalt, color: C.ice }}>
      <Bands target={ref} />
      <div className="pointer-events-none absolute inset-0 opacity-[0.5] mix-blend-soft-light" aria-hidden
           style={{ background: 'radial-gradient(1200px 600px at 70% 30%, rgba(233,238,255,.35), transparent 60%)' }} />
      <div className={cn(W, 'relative z-10 grid items-center gap-8 pb-6 pt-28 lg:grid-cols-[1.05fr_1fr] lg:pt-32')}>
        <div className="flex flex-col items-start">
          <div className="flex flex-wrap items-center gap-2">
            <span className="rounded-full px-3 py-1 font-mono text-[11px] font-semibold uppercase tracking-[0.18em]" style={{ background: C.midnight }}>Open source · AGPL-3.0</span>
            <span className="rounded-full px-3 py-1 font-mono text-[11px] font-semibold uppercase tracking-[0.18em]" style={{ boxShadow: `inset 0 0 0 1px rgba(233,238,255,.5)` }}>{product.platform}</span>
          </div>
          <h1 className="mt-6 font-anton uppercase leading-[0.84] tracking-[-0.005em]" style={{ fontSize: 'clamp(76px, 9.2vw, 150px)' }}>
            <span className="block">Drag.</span>
            <span className="block" style={{ color: C.flame, textShadow: '0 0 40px rgba(255,106,43,.35)' }}>Press.</span>
            <span className="block">Drop.</span>
          </h1>
          <p className="mt-6 max-w-[30rem] font-geist text-[17px] leading-[1.55] sm:text-[19px]" style={{ color: C.ice }}>
            {product.oneLiner} Drag a file in Finder, hit <b>⇧</b>, and a wheel of every format it can become opens under your pointer.
          </p>
          <div className="mt-8 flex flex-wrap items-center gap-4">
            <CTA><ArrowDownToLine size={20} strokeWidth={2.8} /> Download free</CTA>
            <CTA ghost href="#how">See the keys <ArrowRight size={18} strokeWidth={2.8} className="transition-transform group-hover:translate-x-1" /></CTA>
          </div>
        </div>
        <div className="relative flex justify-center lg:justify-end">
          <div className="relative">
            <CobaltDemo size={preview ? 420 : demoSize} />
            <Sticker className="absolute -left-2 top-4 z-20 sm:-left-10" rotate={-10}>0 UPLOADS</Sticker>
            <div className="absolute -right-1 -top-4 z-20 sm:-right-4"><RaceNumber n="43" size={74} /></div>
          </div>
        </div>
      </div>
      {/* The giant wordmark: bleeds off left, right and bottom. */}
      <div className="relative z-0 mt-[1vw] h-[31vw] select-none overflow-hidden" aria-hidden>
        <motion.div className="absolute -left-[4vw] top-0 whitespace-nowrap font-anton leading-[0.8]"
             style={{ fontSize: '64vw', color: C.ice, x, skewX, letterSpacing: '-0.02em', transformOrigin: '50% 100%' }}>
          HALO<span style={{ color: C.flame }}>.</span>
        </motion.div>
        <div className="absolute bottom-[14%] left-[8%] z-10 hidden sm:block"><Sticker tone="midnight" rotate={4}>793 routes</Sticker></div>
        <div className="absolute bottom-[34%] right-[6%] z-10 hidden sm:block"><Sticker tone="flame" rotate={-4}>43 ms to wheel</Sticker></div>
      </div>
    </section>
  )
}

/* ───────────────────────── Ticker band ───────────────────────── */
function TickerBand() {
  const items = ['⇧ Convert', '⌘ Tools', '⌃ Actions', 'No account', 'No upload', '793 routes', '26 tools', 'CLI + MCP', 'AGPL-3.0']
  return (
    <div className="relative z-10 -my-5 -rotate-[1.6deg] py-3" style={{ background: C.flame, color: C.midnight, boxShadow: `0 0 0 3px ${C.midnight}` }}>
      <Marquee duration={30} className="gap-8 [mask-image:none]">
        {items.map((t) => (
          <span key={t} className="flex shrink-0 items-center gap-8 font-anton text-[22px] uppercase leading-none tracking-[0.06em]">
            {t}<span className="inline-block size-2.5 rotate-45" style={{ background: C.midnight }} />
          </span>
        ))}
      </Marquee>
    </div>
  )
}

/* ───────────────────────── Format marquee ───────────────────────── */
function Formats() {
  const a = product.conversions.slice(0, 8), b = product.conversions.slice(8)
  return (
    <section className="relative overflow-hidden pb-16 pt-24 sm:pb-20 sm:pt-32" style={{ background: C.midnight, color: C.ice }}>
      <div className={cn(W, 'mb-10 flex flex-wrap items-end justify-between gap-4')}>
        <Eyebrow style={{ color: C.flame }}>Nº 02 · The formats</Eyebrow>
        <p className="max-w-sm font-geist text-[15px] leading-relaxed text-[#E9EEFF]/70">Images, video, audio, documents, ebooks, archives. Multi-hop routes picked for quality. Scroll fast, watch it lean.</p>
      </div>
      <SkewOnScroll max={16}>
        <Marquee duration={50} className="gap-10 [mask-image:none]">
          {a.map((c) => <Route key={c} r={c} />)}
        </Marquee>
        <Marquee duration={44} reverse className="mt-2 gap-10 [mask-image:none]">
          {b.map((c) => <Route key={c} r={c} hollow />)}
        </Marquee>
      </SkewOnScroll>
    </section>
  )
}
function Route({ r, hollow }: { r: string; hollow?: boolean }) {
  const [x, arrow, y] = r.split(' ')
  return (
    <span className="flex shrink-0 items-center gap-6 whitespace-nowrap font-anton uppercase leading-[0.9]" style={{ fontSize: 'clamp(64px, 10vw, 168px)' }}>
      <span style={hollow ? outline(C.ice, 2) : undefined}>{x}</span>
      <span style={{ color: C.flame }}>{arrow}</span>
      <span style={hollow ? outline(C.ice, 2) : undefined}>{y}</span>
      <span className="mx-4 inline-block size-4 rotate-45" style={{ background: C.cobalt }} />
    </span>
  )
}

/* ───────────────────────── How it works ───────────────────────── */
function How() {
  const wheels: Seg[][] = [convertSegs, toolSegs, actionSegs]
  const bgs = [C.cobalt, C.ultra, C.midnight]
  return (
    <section id="how" className="relative" style={{ background: C.midnight, color: C.ice }}>
      <div className={cn(W, 'pb-12 pt-24 sm:pt-28')}>
        <Eyebrow style={{ color: C.flame }}>Nº 03 · How it works</Eyebrow>
        <h2 className="mt-4 max-w-[20ch] font-anton uppercase leading-[0.88]" style={{ fontSize: 'clamp(52px, 7vw, 112px)' }}>Three keys. That's the whole app.</h2>
      </div>
      <div className="grid lg:grid-cols-3">
        {product.keys.map((k, i) => (
          <div key={k.key} className="relative flex flex-col overflow-hidden px-6 pb-12 pt-10 sm:px-10" style={{ background: bgs[i] }}>
            <div className="flex items-start justify-between">
              <RaceNumber n={`0${i + 1}`} size={52} tone={i === 0 ? 'flame' : 'ice'} />
              <span className="font-mono text-[11px] uppercase tracking-[0.18em] text-[#E9EEFF]/70">Hold while dragging</span>
            </div>
            <div className="mt-10 flex items-center gap-5">
              <KeyCap sym={k.key} name={k.name} size="lg" />
              <ArrowRight size={34} strokeWidth={2.6} style={{ color: C.flame }} />
              <span className="font-anton text-[54px] uppercase leading-none">{k.wheel}</span>
            </div>
            <p className="mt-5 max-w-xs font-geist text-[16px] leading-relaxed text-[#E9EEFF]/85">{k.blurb}</p>
            <div className="mt-10 flex justify-center">
              <CobaltWheel segments={wheels[i]} size={280} hoverIndex={i === 0 ? 0 : 1} hubLabel={<Hub top="MOV" bottom={k.wheel} size={280} />} interactive={false} />
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}

/* ───────────────────────── Playground ───────────────────────── */
function Playground() {
  const modes = [
    { key: '⇧', name: 'Shift', title: 'Convert', segs: convertSegs, code: 'Shift' },
    { key: '⌘', name: 'Command', title: 'Tools', segs: toolSegs, code: 'Meta' },
    { key: '⌃', name: 'Control', title: 'Actions', segs: actionSegs, code: 'Control' },
  ]
  const [m, setM] = useState(0)
  const [held, setHeld] = useState<number | null>(null)
  const [hits, setHits] = useState<string[]>(isShot ? ['GIF', 'Trim', 'AirDrop'] : [])
  const calc = () => (window.innerWidth < 640 ? Math.min(340, window.innerWidth - 40) : 440)
  const [size, setSize] = useState(calc)
  useEffect(() => {
    const f = () => setSize(calc())
    window.addEventListener('resize', f); return () => window.removeEventListener('resize', f)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => {
    const down = (e: KeyboardEvent) => { const i = modes.findIndex((x) => x.code === e.key); if (i >= 0) { setM(i); setHeld(i) } }
    const up = () => setHeld(null)
    window.addEventListener('keydown', down); window.addEventListener('keyup', up)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up) }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps
  const mode = modes[m]
  return (
    <section className="relative overflow-hidden py-24 sm:py-32" style={{ background: C.ultra, color: C.ice }}>
      <Bands count={9} palette={[C.ultra, '#0D1E9E', C.ultra, '#0A1780']} className="opacity-90" />
      <div className={cn(W, 'relative grid items-center gap-12 lg:grid-cols-[1fr_auto]')}>
        <div>
          <Eyebrow style={{ color: C.flame }}>Nº 04 · Your turn</Eyebrow>
          <h2 className="mt-4 font-anton uppercase leading-[0.88]" style={{ fontSize: 'clamp(52px, 7vw, 112px)' }}>Take the wheel.</h2>
          <p className="mt-5 max-w-md font-geist text-[17px] leading-relaxed text-[#E9EEFF]/85">
            Hold <b>⇧</b>, <b>⌘</b> or <b>⌃</b> on your keyboard, or tap a key below. Aim at a wedge. Click to drop.
          </p>
          <div className="mt-8 flex gap-3">
            {modes.map((x, i) => (
              <button key={x.key} type="button" onClick={() => setM(i)} aria-pressed={m === i} className="rounded-[14px] outline-none focus-visible:ring-2 focus-visible:ring-[#FF6A2B]">
                <KeyCap sym={x.key} name={x.name} pressed={m === i || held === i} />
              </button>
            ))}
          </div>
          <div className="mt-10 max-w-md rounded-[18px] p-4" style={{ background: 'rgba(5,10,46,.6)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14)' }}>
            <div className="flex items-center justify-between">
              <Eyebrow className="text-[#E9EEFF]/70">Lap log</Eyebrow>
              <span className="font-anton text-[28px] leading-none tabular-nums" style={{ color: C.flame }}>{String(hits.length).padStart(2, '0')}</span>
            </div>
            <div className="mt-3 flex min-h-[34px] flex-wrap gap-1.5">
              {hits.length === 0 && <span className="font-geist text-[13px] text-[#E9EEFF]/60">No hits yet. Go.</span>}
              <AnimatePresence initial={false}>
                {hits.slice(-8).map((h, i) => (
                  <motion.span key={`${h}${i}${hits.length}`} initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }}
                    className="rounded-[8px] px-2 py-1 font-anton text-[14px] uppercase leading-none" style={{ background: C.ice, color: C.midnight }}>{h}</motion.span>
                ))}
              </AnimatePresence>
            </div>
          </div>
        </div>
        <div className="relative mx-auto">
          <div className="pointer-events-none absolute inset-[-12%] rounded-full opacity-60" style={{ background: 'radial-gradient(circle, rgba(31,59,255,.8), transparent 65%)' }} />
          <AnimatePresence mode="wait">
            <motion.div key={m} initial={isShot ? false : { rotate: -30, scale: 0.8, opacity: 0 }} animate={{ rotate: 0, scale: 1, opacity: 1 }}
              exit={{ rotate: 30, scale: 0.85, opacity: 0 }} transition={{ type: 'spring', stiffness: 420, damping: 28 }}>
              <CobaltWheel segments={mode.segs} size={size} hoverIndex={isShot ? 2 : undefined}
                hubLabel={<Hub top={mode.title.toUpperCase()} bottom={`${mode.key} ${mode.name}`} size={size} />}
                onPick={(s) => setHits((h) => [...h, s.label])} />
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Bento ───────────────────────── */
function Card({ children, className, n, title, flame }: { children?: ReactNode; className?: string; n: string; title: string; flame?: boolean }) {
  return (
    <SpotlightCard className={cn('flex flex-col rounded-[24px] p-6 sm:p-7', className)} color={flame ? 'rgba(5,10,46,.18)' : 'rgba(255,106,43,.22)'}
      style={flame
        ? { background: FLAME_GRAD, color: C.midnight }
        : { background: 'linear-gradient(180deg, rgba(19,35,143,.65), rgba(5,10,46,.95))', color: C.ice, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.12)' }}>
      <div className="relative flex items-center justify-between">
        <span className="font-anton text-[30px] uppercase leading-none">{title}</span>
        <span className="font-mono text-[11px] font-semibold opacity-60">{n}</span>
      </div>
      <div className="relative mt-auto">{children}</div>
    </SpotlightCard>
  )
}
function Bento() {
  const f = Object.fromEntries(product.features.map((x) => [x.title, x.body]))
  return (
    <section id="features" className="relative py-24 sm:py-32" style={{ background: C.midnight, color: C.ice }}>
      <div className={W}>
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <Eyebrow style={{ color: C.flame }}>Nº 05 · The kit</Eyebrow>
            <h2 className="mt-4 font-anton uppercase leading-[0.88]" style={{ fontSize: 'clamp(52px, 7vw, 112px)' }}>Everything, mid-drag.</h2>
          </div>
          <p className="max-w-sm font-geist text-[15px] leading-relaxed text-[#E9EEFF]/70">Six things Halo does without opening a window. Each saves a new copy. Your original stays put.</p>
        </div>
        <div className="mt-12 grid gap-3 md:grid-cols-2 lg:grid-cols-3">
          <Card n="01" title="Convert" className="min-h-[340px] lg:col-span-2">
            <div className="mt-8 flex flex-wrap items-end gap-x-8 gap-y-4">
              <span className="font-anton leading-[0.8]" style={{ fontSize: 'clamp(110px, 14vw, 200px)', color: C.flame, textShadow: '0 0 50px rgba(255,106,43,.35)' }}><Ticker value="793" /></span>
              <div className="mb-2 max-w-sm">
                <p className="font-geist text-[15px] leading-relaxed text-[#E9EEFF]/80">{f.Convert}</p>
                <div className="mt-4 flex flex-wrap gap-1.5">
                  {product.conversions.slice(0, 6).map((c) => (
                    <span key={c} className="rounded-[8px] px-2 py-1 font-mono text-[11px] font-semibold" style={{ background: 'rgba(31,59,255,.35)' }}>{c}</span>
                  ))}
                </div>
              </div>
            </div>
          </Card>
          <Card n="02" title="Tools" className="min-h-[340px]">
            <div className="mt-6 grid grid-cols-4 gap-1.5">
              {toolSegs.map((t) => (
                <div key={t.id} className="flex aspect-square flex-col items-center justify-center gap-1.5 rounded-[12px] text-center transition-colors hover:bg-[#FF6A2B] hover:text-[#050A2E]" style={{ background: 'rgba(31,59,255,.25)' }}>
                  {t.icon}<span className="font-anton text-[11px] uppercase leading-none">{t.label}</span>
                </div>
              ))}
            </div>
            <p className="mt-4 font-geist text-[14px] leading-relaxed text-[#E9EEFF]/75">{f.Tools}</p>
          </Card>
          <Card n="03" title="Actions" className="min-h-[300px]">
            <div className="mt-6 flex flex-col gap-1">
              {actionSegs.map((a) => (
                <div key={a.id} className="flex items-center gap-3 rounded-[10px] px-3 py-2 transition-colors hover:bg-[#1F3BFF]" style={{ background: 'rgba(233,238,255,.05)' }}>
                  {a.icon}<span className="font-anton text-[16px] uppercase leading-none">{a.label}</span>
                  <span className="ml-auto font-mono text-[10px] opacity-50">⌃</span>
                </div>
              ))}
            </div>
          </Card>
          <Card n="04" title="Presets" className="min-h-[300px]">
            <div className="mt-8 flex flex-col items-start gap-2">
              <Sticker rotate={-3} className="text-[26px]">GIF · 15 fps</Sticker>
              <Sticker tone="ice" rotate={2} className="ml-6 text-[26px]">JPG · 80 %</Sticker>
              <Sticker tone="cobalt" rotate={-1} className="ml-2 text-[26px]">WEBP · 1080</Sticker>
            </div>
            <p className="mt-8 font-geist text-[14px] leading-relaxed text-[#E9EEFF]/75">{f.Presets}</p>
          </Card>
          <Card n="05" title="Agents" className="min-h-[300px]">
            <div className="mt-6 rounded-[12px] p-3 font-mono text-[11.5px] leading-[1.7]" style={{ background: C.deep, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}>
              <div><span style={{ color: C.flame }}>$</span> halo convert clip.mov --to gif --json</div>
              <div className="text-[#E9EEFF]/45">{'{"event":"progress","pct":64}'}</div>
              <div className="text-[#E9EEFF]/60">{'{"event":"done","output":"clip.gif"}'}</div>
              <div className="mt-2 text-[#E9EEFF]/45"># or let Claude call it over MCP</div>
            </div>
            <p className="mt-4 font-geist text-[14px] leading-relaxed text-[#E9EEFF]/75">{f.Agents}</p>
          </Card>
          <Card n="06" title="Private" flame className="min-h-[200px] md:col-span-2 lg:col-span-3">
            <div className="mt-6 flex flex-wrap items-end justify-between gap-6">
              <p className="max-w-lg font-geist text-[16px] font-medium leading-relaxed">{f.Private}</p>
              <span className="font-anton text-[64px] uppercase leading-[0.85] sm:text-[96px]">0 network calls</span>
            </div>
          </Card>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Scoreboard ───────────────────────── */
export function Scoreboard() {
  return (
    <section className="relative overflow-hidden py-20 sm:py-28" style={{ background: C.cobalt, color: C.ice }}>
      <Bands count={5} />
      <div className={cn(W, 'relative')}>
        <div className="flex items-center justify-between">
          <Eyebrow>Nº 06 · Scoreboard</Eyebrow>
          <span className="flex items-center gap-2 font-mono text-[11px] font-semibold uppercase tracking-[0.18em]">
            <span className="size-2 animate-pulse rounded-full" style={{ background: C.flame, boxShadow: '0 0 10px #FF6A2B' }} /> Measured<span className="hidden sm:inline"> on the real app</span>
          </span>
        </div>
        <div className="mt-8 grid grid-cols-2 overflow-hidden rounded-[24px] lg:grid-cols-4" style={{ background: 'rgba(5,10,46,.86)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14)' }}>
          {product.stats.map((s, i) => (
            <div key={s.label} className={cn('relative flex flex-col justify-between gap-6 p-5 sm:p-8', i % 2 === 1 && 'border-l', i >= 2 && 'border-t lg:border-t-0', i === 2 && 'lg:border-l')}
                 style={{ borderColor: 'rgba(233,238,255,.12)' }}>
              <span className="font-mono text-[11px] font-semibold uppercase tracking-[0.18em] text-[#E9EEFF]/55">P{i + 1}</span>
              <div className="font-anton leading-[0.82]" style={{ fontSize: 'clamp(64px, 8vw, 128px)', color: i === 3 ? C.flame : C.ice }}>
                <Ticker value={s.value.split(' ')[0]} />{s.value.includes(' ') && <span className="ml-1 text-[0.42em]">{s.value.split(' ')[1]}</span>}
              </div>
              <span className="max-w-[16ch] font-geist text-[14px] leading-snug text-[#E9EEFF]/80">{s.label}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Privacy ───────────────────────── */
function Privacy() {
  const points = [
    { i: <UserX size={22} strokeWidth={2.4} />, t: 'No account', b: 'Install it. Use it. That is the whole sign-up.' },
    { i: <CloudOff size={22} strokeWidth={2.4} />, t: 'No upload', b: 'Every route runs on your Mac, on your silicon.' },
    { i: <WifiOff size={22} strokeWidth={2.4} />, t: 'No telemetry', b: 'Zero network calls unless you ask for one.' },
    { i: <ShieldCheck size={22} strokeWidth={2.4} />, t: 'Pro is opt-in', b: 'Cloud features only run when you pick them.' },
  ]
  return (
    <section className="relative overflow-hidden py-24 sm:py-32" style={{ background: C.flame, color: C.midnight }}>
      <div className="pointer-events-none absolute inset-0 opacity-30" aria-hidden
           style={{ background: `repeating-linear-gradient(90deg, transparent 0 120px, rgba(5,10,46,.08) 120px 240px)` }} />
      <div className={cn(W, 'relative grid gap-14 lg:grid-cols-[1.1fr_1fr]')}>
        <div>
          <Eyebrow>Nº 07 · Local by default</Eyebrow>
          <h2 className="mt-4 font-anton uppercase leading-[0.86]" style={{ fontSize: 'clamp(56px, 8vw, 132px)' }}>Your files never leave the Mac.</h2>
          <div className="mt-10 grid gap-3 sm:grid-cols-2">
            {points.map((p) => (
              <div key={p.t} className="rounded-[18px] p-5" style={{ background: 'rgba(5,10,46,.08)', boxShadow: 'inset 0 0 0 2px rgba(5,10,46,.85)' }}>
                {p.i}
                <div className="mt-3 font-anton text-[24px] uppercase leading-none">{p.t}</div>
                <p className="mt-2 font-geist text-[14.5px] font-medium leading-snug">{p.b}</p>
              </div>
            ))}
          </div>
        </div>
        <div className="relative grid place-items-center">
          {/* The garage: a Mac with the wheel inside, cloud cut off. */}
          <div className="relative w-full max-w-[460px]">
            <div className="rounded-[26px] p-3" style={{ background: C.midnight, boxShadow: `0 10px 0 ${C.midnight}` }}>
              <div className="relative grid aspect-[16/10] place-items-center overflow-hidden rounded-[16px]" style={{ background: C.cobalt }}>
                <Bands count={6} />
                <div className="relative"><Mark size={150} glow /></div>
                <span className="absolute bottom-3 left-3 rounded-[6px] px-2 py-1 font-mono text-[10px] font-semibold uppercase tracking-[0.14em]" style={{ background: C.midnight, color: C.ice }}>On-device</span>
              </div>
            </div>
            <div className="mx-auto h-4 w-[38%] rounded-b-[10px]" style={{ background: C.midnight }} />
            <div className="absolute -right-2 -top-8 sm:-right-8"><Sticker tone="midnight" rotate={8} className="text-[34px]"><Lock size={24} strokeWidth={2.6} /> 0 uploads</Sticker></div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── CLI / agents ───────────────────────── */
export function Agents() {
  const lines = [
    { t: '{"event":"start","input":"clip.mov","to":"gif"}', d: 0 },
    { t: '{"event":"progress","pct":37}', d: 1 },
    { t: '{"event":"progress","pct":82}', d: 2 },
    { t: '{"event":"done","output":"clip.gif"}', d: 3 },
  ]
  return (
    <section id="agents" className="relative overflow-hidden py-24 sm:py-32" style={{ background: C.midnight, color: C.ice }}>
      <div className="pointer-events-none absolute inset-y-0 left-0 w-[38%]" style={{ background: `linear-gradient(90deg, ${C.ultra}, transparent)` }} aria-hidden />
      <div className={cn(W, 'relative grid items-center gap-12 lg:grid-cols-[0.9fr_1.1fr]')}>
        <div>
          <Eyebrow style={{ color: C.flame }}>Nº 08 · Agents & CLI</Eyebrow>
          <h2 className="mt-4 font-anton uppercase leading-[0.88]" style={{ fontSize: 'clamp(52px, 7vw, 112px)' }}>Same engine. No mouse.</h2>
          <p className="mt-5 max-w-md font-geist text-[17px] leading-relaxed text-[#E9EEFF]/80">
            A real CLI with JSON and NDJSON progress, plus an MCP server. Claude can convert your files, locally. Script it, pipe it, ship it.
          </p>
          <div className="mt-8 flex flex-wrap gap-2">
            {['--json', '--ndjson', 'MCP server', 'on-device'].map((t) => (
              <span key={t} className="rounded-[9px] px-3 py-1.5 font-mono text-[12px] font-semibold" style={{ boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.25)' }}>{t}</span>
            ))}
          </div>
        </div>
        <div className="relative min-w-0">
          <div className="overflow-hidden rounded-[18px]" style={{ background: C.deep, boxShadow: `inset 0 0 0 1px rgba(233,238,255,.14), 0 40px 80px -30px ${C.cobalt}` }}>
            <div className="flex items-center gap-2 border-b px-4 py-3" style={{ borderColor: 'rgba(233,238,255,.1)' }}>
              {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}
              <span className="ml-3 font-mono text-[11px] text-[#E9EEFF]/50">~/Desktop — zsh</span>
              <span className="ml-auto rounded-[5px] px-1.5 py-0.5 font-anton text-[11px] leading-none" style={{ background: C.flame, color: C.midnight }}>NDJSON</span>
            </div>
            <div className="overflow-x-auto p-5 font-mono text-[12.5px] leading-[1.9] sm:text-[14px]">
              <div className="whitespace-nowrap"><span style={{ color: C.flame }}>❯</span> <span className="font-semibold">halo</span> convert clip.mov <span style={{ color: C.steel }}>--to</span> gif <span style={{ color: C.steel }}>--json</span></div>
              {lines.map((l) => (
                <motion.div key={l.t} className="whitespace-nowrap text-[#E9EEFF]/70"
                  initial={isShot ? false : { opacity: 0, x: -8 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }}
                  transition={{ delay: 0.3 + l.d * 0.35 }}>
                  {l.t.replace(/("[a-z]+":)/g, '\u0000$1\u0000').split('\u0000').map((p, j) => (
                    <span key={j} style={p.endsWith(':') ? { color: C.steel } : p.includes('done') ? { color: C.flame } : undefined}>{p}</span>
                  ))}
                </motion.div>
              ))}
              <div className="mt-3 whitespace-nowrap"><span style={{ color: C.flame }}>❯</span> <span className="inline-block h-4 w-2 translate-y-0.5 animate-pulse" style={{ background: C.ice }} /></div>
            </div>
          </div>
          <div className="relative -mt-6 ml-auto w-[88%] rounded-[16px] p-4 sm:w-[70%]" style={{ background: C.cobalt, boxShadow: `0 0 0 2px ${C.midnight}, 0 8px 0 ${C.midnight}` }}>
            <div className="font-mono text-[10px] font-semibold uppercase tracking-[0.16em] text-[#E9EEFF]/80">MCP · halo</div>
            <div className="mt-2 font-geist text-[14px] leading-snug">“Turn the screen recording on my desktop into a GIF.”</div>
            <div className="mt-2 flex items-center gap-2 font-mono text-[12px]"><Check size={14} strokeWidth={3} style={{ color: C.flame }} /> halo.convert → clip.gif · on-device</div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Pricing ───────────────────────── */
export function Pricing() {
  const [local, pro] = product.pricing
  return (
    <section id="pricing" className="relative overflow-hidden py-24 sm:py-32" style={{ background: C.cobalt, color: C.ice }}>
      <Bands count={7} />
      <div className={cn(W, 'relative')}>
        <Eyebrow>Nº 09 · Pricing</Eyebrow>
        <h2 className="mt-4 font-anton uppercase leading-[0.88]" style={{ fontSize: 'clamp(52px, 7vw, 112px)' }}>Free to race. Pro to go further.</h2>
        <div className="mt-12 grid gap-4 lg:grid-cols-2">
          <div className="flex flex-col rounded-[26px] p-7 sm:p-9" style={{ background: C.midnight, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.16)' }}>
            <div className="flex items-center justify-between">
              <span className="font-anton text-[36px] uppercase leading-none">{local.name}</span>
              <RaceNumber n="L" size={46} />
            </div>
            <div className="mt-8 flex items-end gap-3"><span className="font-anton text-[110px] uppercase leading-[0.8]">{local.price}</span><span className="mb-2 font-mono text-[12px] uppercase tracking-[0.16em] text-[#E9EEFF]/60">{local.period}</span></div>
            <ul className="mt-8 grid gap-2.5 font-geist text-[15px]">
              {local.points.map((p) => <li key={p} className="flex items-center gap-3"><Check size={17} strokeWidth={3} style={{ color: C.flame }} />{p}</li>)}
            </ul>
            <div className="mt-auto pt-10"><CTA><ArrowDownToLine size={20} strokeWidth={2.8} /> Download for Mac</CTA></div>
          </div>
          <div className="relative flex flex-col overflow-hidden rounded-[26px] p-7 sm:p-9" style={{ background: FLAME_GRAD, color: C.midnight, boxShadow: `0 0 80px -10px rgba(255,106,43,.6)` }}>
            <div className="flex items-center justify-between">
              <span className="font-anton text-[36px] uppercase leading-none">{pro.name}</span>
              <Sticker tone="midnight" rotate={4} className="text-[17px]">Opt-in cloud</Sticker>
            </div>
            <div className="mt-8 flex items-end gap-3"><span className="font-anton text-[110px] uppercase leading-[0.8]">{pro.price}</span><span className="mb-2 font-mono text-[12px] font-semibold uppercase tracking-[0.16em] opacity-70">{pro.period}</span></div>
            <ul className="mt-8 grid gap-2.5 font-geist text-[15px] font-medium">
              {pro.points.map((p) => <li key={p} className="flex items-center gap-3"><Plus size={17} strokeWidth={3} />{p}</li>)}
            </ul>
            <div className="mt-auto pt-10">
              <a href="#pricing" className="inline-flex h-14 items-center gap-3 rounded-[14px] px-6 font-anton text-[19px] uppercase tracking-[0.05em]" style={{ background: C.midnight, color: C.ice }}>Go Pro <ArrowRight size={18} strokeWidth={2.8} /></a>
            </div>
          </div>
        </div>
        <p className="mt-6 font-mono text-[11px] uppercase tracking-[0.16em] text-[#E9EEFF]/80">{product.licence}</p>
      </div>
    </section>
  )
}

/* ───────────────────────── FAQ ───────────────────────── */
const FAQS = [
  { q: 'Is it really free?', a: 'Yes. Halo is open source under AGPL-3.0, and every local feature is free, forever: all 793 conversions, all 26 tools, the six actions, the CLI and the MCP server. Pro only adds cloud extras.' },
  { q: 'Does anything leave my Mac?', a: 'No. Conversions run on your Mac. Halo makes zero network calls unless you ask for a Pro cloud feature, and there is no account and no telemetry.' },
  { q: 'Which Macs does it run on?', a: 'macOS 13 or later on Apple silicon. It lives in the menu bar and wakes up when you drag.' },
  { q: 'Why does it need Accessibility access?', a: 'To see that you are dragging and which modifier you pressed, so it can open the wheel under your pointer. It does not read your screen or your keystrokes otherwise.' },
  { q: 'What happens to my original file?', a: 'Nothing. Every conversion and tool saves a new copy next to it. Undo is just the trash.' },
  { q: 'Can my agent drive it?', a: 'Yes. Run halo from the terminal with --json or --ndjson progress, or connect the MCP server so Claude can convert files for you, locally.' },
]
function FAQ() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="relative py-24 sm:py-32" style={{ background: C.midnight, color: C.ice }}>
      <div className={cn(W, 'grid gap-12 lg:grid-cols-[0.8fr_1.2fr]')}>
        <div>
          <Eyebrow style={{ color: C.flame }}>Nº 10 · Pit stop</Eyebrow>
          <h2 className="mt-4 font-anton uppercase leading-[0.88]" style={{ fontSize: 'clamp(52px, 7vw, 112px)' }}>Questions, fast.</h2>
        </div>
        <div className="flex flex-col gap-2">
          {FAQS.map((f, i) => {
            const on = open === i
            return (
              <div key={f.q} className="overflow-hidden rounded-[18px] transition-colors" style={{ background: on ? C.ultra : 'rgba(233,238,255,.04)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}>
                <button type="button" onClick={() => setOpen(on ? null : i)} aria-expanded={on}
                  className="flex w-full items-center justify-between gap-6 px-5 py-5 text-left sm:px-6">
                  <span className="font-anton text-[22px] uppercase leading-tight sm:text-[26px]">{f.q}</span>
                  <motion.span animate={{ rotate: on ? 45 : 0 }} className="grid size-9 shrink-0 place-items-center rounded-[10px]"
                    style={{ background: on ? C.flame : 'rgba(233,238,255,.08)', color: on ? C.midnight : C.ice }}><Plus size={18} strokeWidth={3} /></motion.span>
                </button>
                <AnimatePresence initial={false}>
                  {on && (
                    <motion.div initial={isShot ? false : { height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                      transition={{ type: 'spring', stiffness: 400, damping: 36 }}>
                      <p className="max-w-[60ch] px-5 pb-6 font-geist text-[15.5px] leading-relaxed text-[#E9EEFF]/85 sm:px-6">{f.a}</p>
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
function Final() {
  const ref = useRef<HTMLElement>(null)
  const skewX = useVelocitySkew(12)
  return (
    <section ref={ref} className="relative overflow-hidden" style={{ background: C.cobalt, color: C.ice }}>
      <Bands target={ref} count={9} />
      <div className={cn(W, 'relative z-10 flex flex-col items-center pb-10 pt-28 text-center')}>
        <Eyebrow>Nº 11 · Lights out</Eyebrow>
        <p className="mt-5 max-w-lg font-geist text-[18px] leading-relaxed">Free, local, open source. Install it, drag something, press a key.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-4"><CTA><ArrowDownToLine size={20} strokeWidth={2.8} /> Download Halo</CTA><CTA ghost href="#agents"><GitFork size={18} /> Read the source</CTA></div>
      </div>
      <div className="relative h-[29vw] select-none overflow-hidden" aria-hidden>
        <motion.div className="absolute left-1/2 top-0 whitespace-nowrap font-anton uppercase leading-[0.8]" style={{ fontSize: '38vw', skewX, x: '-50%' }}>
          Drop in<span style={{ color: C.flame }}>.</span>
        </motion.div>
      </div>
    </section>
  )
}

function Footer() {
  const cols = [
    { h: 'Product', l: ['Download', 'Pricing', 'Changelog', 'Formats'] },
    { h: 'Build', l: ['Source code', 'CLI docs', 'MCP server', 'Licence'] },
    { h: 'Halo', l: ['Privacy', 'Press kit', 'Contact'] },
  ]
  return (
    <footer className="pb-28 pt-16" style={{ background: C.deep, color: C.ice }}>
      <div className={cn(W, 'grid gap-12 md:grid-cols-[1.3fr_2fr]')}>
        <div>
          <Lockup size={34} />
          <p className="mt-5 max-w-xs font-geist text-[14px] leading-relaxed text-[#E9EEFF]/65">{product.how}</p>
        </div>
        <div className="grid grid-cols-2 gap-8 sm:grid-cols-3">
          {cols.map((c) => (
            <div key={c.h}>
              <div className="font-anton text-[15px] uppercase tracking-[0.06em] text-[#E9EEFF]">{c.h}</div>
              <ul className="mt-4 grid gap-2.5 font-geist text-[14px] text-[#E9EEFF]/65">{c.l.map((l) => <li key={l}><a href="#top" className="hover:text-[#FF6A2B]">{l}</a></li>)}</ul>
            </div>
          ))}
        </div>
      </div>
      <div className={cn(W, 'mt-14 flex flex-wrap items-center justify-between gap-4 border-t pt-6 font-mono text-[11px] uppercase tracking-[0.16em] text-[#E9EEFF]/55')} style={{ borderColor: 'rgba(233,238,255,.1)' }}>
        <span>AGPL-3.0 · {product.platform}</span>
        <span>Made to be dragged</span>
      </div>
    </footer>
  )
}

export function Landing() {
  return (
    <div className="min-h-screen overflow-x-clip font-geist selection:bg-[#FF6A2B] selection:text-[#050A2E]" style={{ ...cssVars, background: C.midnight }}>
      <Nav />
      <Hero />
      <TickerBand />
      <Formats />
      <How />
      <Playground />
      <Bento />
      <Scoreboard />
      <Privacy />
      <Agents />
      <Pricing />
      <FAQ />
      <Final />
      <Footer />
    </div>
  )
}
