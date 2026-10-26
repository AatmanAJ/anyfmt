import { AnimatePresence, motion, useScroll, useTransform } from 'motion/react'
import {
  ArrowRight, Check, Copy, Crop, Download, FolderInput, Link2, Minimize2, Minus, Pin, Plus, Send, ShieldCheck,
  SquareTerminal, Scissors, EyeOff, PenLine, WifiOff, X,
} from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { isShot, NumberTicker, Reveal } from '../shared/kit'
import { product } from '../shared/product'
import { AnyWheel, type Wedge } from './AnyWheel'
import { actionWedges, brand, convertWedges, faqs, pricing, stats, toolWedges } from './copy'
import { DesktopDemo, FileTile } from './Demo'
import { AppIcon, GlassTile, Mark, Wordmark } from './Mark'
import './anyfmt.css'

/* ---------- small pieces ---------- */

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [w, setW] = useState(1100)
  useEffect(() => {
    if (!ref.current) return
    const ro = new ResizeObserver(([e]) => setW(e.contentRect.width))
    ro.observe(ref.current)
    return () => ro.disconnect()
  }, [])
  return [ref, w] as const
}

export function Streaks({ className }: { className?: string }) {
  return (
    <svg className={`af-streak ${className ?? ''}`} viewBox="0 0 1200 800" preserveAspectRatio="none" aria-hidden>
      <defs>
        <filter id="afs1"><feGaussianBlur stdDeviation="22" /></filter>
        <filter id="afs2"><feGaussianBlur stdDeviation="5" /></filter>
        <linearGradient id="afsg" x1="0" x2="1"><stop offset="0" stopColor="#fff" stopOpacity="0" /><stop offset=".5" stopColor="#fff" /><stop offset="1" stopColor="#fff" stopOpacity="0" /></linearGradient>
      </defs>
      <path d="M-100 700 C 250 520, 520 820, 1300 260" stroke="#FFD2A8" strokeWidth="140" fill="none" opacity=".35" filter="url(#afs1)" />
      <path d="M760 -60 C 880 160, 1020 280, 1320 340" stroke="url(#afsg)" strokeWidth="18" fill="none" opacity=".55" filter="url(#afs2)" />
      <path d="M820 -60 C 930 140, 1060 250, 1320 300" stroke="url(#afsg)" strokeWidth="4" fill="none" opacity=".8" filter="url(#afs2)" />
      <path d="M-80 140 C 160 80, 300 220, 520 120" stroke="url(#afsg)" strokeWidth="10" fill="none" opacity=".35" filter="url(#afs2)" />
    </svg>
  )
}

export function Eyebrow({ children, tone = 'paper' }: { children: ReactNode; tone?: 'paper' | 'stage' }) {
  return (
    <span className={`inline-flex h-7 items-center gap-2 rounded-full px-3 text-[12.5px] font-medium ${tone === 'stage' ? 'bg-white/15 text-white ring-1 ring-white/35 backdrop-blur' : 'bg-white text-[#55524F] ring-1 ring-[#E7E5E2]'}`}>
      <span className={`size-1.5 rounded-full ${tone === 'stage' ? 'bg-white' : 'bg-[#EA7C25]'}`} />{children}
    </span>
  )
}

function SectionHead({ eyebrow, title, body, center }: { eyebrow: string; title: ReactNode; body?: ReactNode; center?: boolean }) {
  return (
    <Reveal className={`flex max-w-[720px] flex-col gap-4 ${center ? 'mx-auto items-center text-center' : 'items-start'}`}>
      <Eyebrow>{eyebrow}</Eyebrow>
      <h2 className="text-[38px] font-semibold leading-[1.02] tracking-[-0.045em] text-balance sm:text-[56px]">{title}</h2>
      {body && <p className="max-w-[560px] text-[17px] leading-relaxed text-[#55524F]">{body}</p>}
    </Reveal>
  )
}

export function Key({ k, label, on }: { k: string; label: string; on?: boolean }) {
  return (
    <span className="af-key" style={on ? { boxShadow: 'inset 0 1px 0 #fff, inset 0 -1px 0 #E2E0DC, 0 0 0 1.5px #E5701E, 0 2px 4px -2px rgba(17,17,17,.3)', transform: 'translateY(2px)' } : undefined}>
      <span className="text-[19px] leading-none" style={{ color: on ? '#E5701E' : '#111' }}>{k}</span>
      <span className="text-[10px] font-medium text-[#8C8884]">{label}</span>
    </span>
  )
}

export const iconFor: Record<string, ReactNode> = {
  Compress: <Minimize2 size={15} />, Crop: <Crop size={15} />, Edit: <PenLine size={15} />, Annotate: <PenLine size={15} />,
  'Add BG': <Plus size={15} />, Redact: <EyeOff size={15} />, Trim: <Scissors size={15} />,
  AirDrop: <Send size={15} />, Float: <Pin size={15} />, Copy: <Copy size={15} />, Move: <FolderInput size={15} />,
  'Copy Path': <Link2 size={15} />, Terminal: <SquareTerminal size={15} />,
}
const withIcons = (ws: readonly Wedge[]) => ws.map((w) => ({ ...w, icon: iconFor[w.label] }))

export const WHEELS = [
  { key: '⇧', name: 'shift', wheel: 'Convert', blurb: product.keys[0].blurb, wedges: convertWedges as readonly Wedge[], hub: 'MOV' },
  { key: '⌘', name: 'command', wheel: 'Tools', blurb: product.keys[1].blurb, wedges: withIcons(toolWedges), hub: 'Tools' },
  { key: '⌃', name: 'control', wheel: 'Actions', blurb: product.keys[2].blurb, wedges: withIcons(actionWedges), hub: 'Share' },
]

/* ---------- sections ---------- */

function Nav() {
  const { scrollY } = useScroll()
  const bg = useTransform(scrollY, [0, 80], ['rgba(255,255,255,.72)', 'rgba(255,255,255,.86)'])
  const ring = useTransform(scrollY, [0, 80], ['rgba(255,255,255,.6)', 'rgba(17,17,17,.08)'])
  return (
    <div className="fixed inset-x-0 top-0 z-50 px-3 pt-3 sm:px-5">
      <motion.nav className="mx-auto flex h-14 max-w-[1240px] items-center justify-between rounded-[16px] px-3 backdrop-blur-xl sm:px-4"
        style={{ background: bg, boxShadow: useTransform(ring, (c) => `0 0 0 1px ${c}`) }}>
        <a href="#top" className="rounded-lg" aria-label="anyfmt home"><Wordmark size={20} /></a>
        <div className="hidden items-center gap-1 text-[14px] font-medium text-[#55524F] md:flex">
          {[['How it works', 'how'], ['Features', 'features'], ['Agents', 'agents'], ['Pricing', 'pricing'], ['FAQ', 'faq']].map(([l, h]) => (
            <a key={h} href={`#${h}`} onClick={(e) => { e.preventDefault(); document.getElementById(h)?.scrollIntoView({ behavior: 'smooth' }) }}
               className="rounded-lg px-3 py-2 hover:bg-black/[.04] hover:text-[#111]">{l}</a>
          ))}
        </div>
        <a className="af-btn af-btn-primary !h-10 !px-4 !text-[14px]" href="#download"><Download size={16} />Download</a>
      </motion.nav>
    </div>
  )
}

function Hero() {
  const [ref, w] = useWidth<HTMLDivElement>()
  const { scrollY } = useScroll()
  const tilt = useTransform(scrollY, [0, 500], [10, 0])
  const lift = useTransform(scrollY, [0, 500], [0, -40])
  const wheel = Math.round(Math.min(380, Math.max(220, w * 0.42)))
  return (
    <section id="top" className="px-2 pt-2 sm:px-3 sm:pt-3">
      <div className="af-stage relative overflow-hidden rounded-[28px] sm:rounded-[36px]">
        <Streaks className="inset-0 h-full w-full" />
        {/* giant ghost wordmark */}
        <div aria-hidden className="pointer-events-none absolute inset-x-0 top-[600px] select-none text-center font-semibold leading-none tracking-[-0.07em] text-white/[.13] sm:top-[640px]"
             style={{ fontSize: 'clamp(140px, 30vw, 460px)' }}>anyfmt</div>

        <div className="relative mx-auto flex max-w-[1240px] flex-col items-center px-4 pb-0 pt-28 text-center sm:px-6 sm:pt-36">
          <motion.div initial={isShot ? false : { opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6 }}>
            <Eyebrow tone="stage">Free and open source · for Mac</Eyebrow>
          </motion.div>
          <motion.h1 className="mt-6 max-w-[980px] text-[52px] font-semibold leading-[0.95] tracking-[-0.055em] text-balance sm:text-[84px] lg:text-[104px]"
            initial={isShot ? false : { opacity: 0, y: 24, filter: 'blur(8px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
            transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1], delay: 0.05 }}>
            Any file. Any format.<br /><span className="text-white/75">Mid‑drag.</span>
          </motion.h1>
          <motion.p className="mt-6 max-w-[560px] text-[17px] leading-relaxed text-white/85 sm:text-[19px]"
            initial={isShot ? false : { opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, delay: 0.15 }}>
            Drag a file, press Shift, and drop it on the format you want. anyfmt converts, edits and shares files right where you are working, without anything leaving your Mac.
          </motion.p>
          <motion.div className="mt-8 flex flex-wrap items-center justify-center gap-3"
            initial={isShot ? false : { opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.8, delay: 0.25 }}>
            <a href="#download" className="af-btn af-btn-light !h-12 !px-6 !text-[16px]"><Download size={18} />Download for Mac</a>
            <a href="#how" onClick={(e) => { e.preventDefault(); document.getElementById('how')?.scrollIntoView({ behavior: 'smooth' }) }} className="af-btn af-btn-ghost !h-12 !px-6 !text-[16px]">See how it works<ArrowRight size={17} /></a>
          </motion.div>
          <p className="mt-4 text-[13px] text-white/70">{brand.platform} · No account</p>

          {/* the product */}
          <motion.div ref={ref} className="relative mt-14 w-full max-w-[1080px] sm:mt-16"
            style={{ perspective: 1600 }}
            initial={isShot ? false : { opacity: 0, y: 60 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 1.1, ease: [0.16, 1, 0.3, 1], delay: 0.3 }}>
            <motion.div style={{ rotateX: isShot ? 0 : tilt, y: isShot ? 0 : lift, transformOrigin: '50% 100%' }}
              className="relative overflow-hidden rounded-t-[18px] bg-white/30 p-[6px] pb-0 ring-1 ring-white/50 backdrop-blur-sm sm:rounded-t-[22px] sm:p-2 sm:pb-0">
              <div className="relative overflow-hidden rounded-t-[13px] sm:rounded-t-[16px]" style={{ height: Math.max(380, Math.min(600, w * 0.56)) }}>
                <DesktopDemo wheel={wheel} />
              </div>
            </motion.div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}

function Formats() {
  const rows = [product.conversions.slice(0, 8), product.conversions.slice(8)]
  return (
    <section className="py-16 sm:py-20" aria-label="Conversions">
      <p className="mb-7 text-center text-[14px] font-medium text-[#8C8884]">{stats[0].value} conversion routes between images, video, audio, documents, ebooks and archives</p>
      <div className="flex flex-col gap-3 [mask-image:linear-gradient(90deg,transparent,#000_12%,#000_88%,transparent)]">
        {rows.map((r, i) => (
          <div key={i} className="flex overflow-hidden">
            <div className="af-marquee flex shrink-0 gap-3 pr-3" style={{ animationDirection: i ? 'reverse' : 'normal', animationPlayState: isShot ? 'paused' : undefined }}>
              {[...r, ...r, ...r, ...r].map((c, j) => {
                const [a, b] = c.split(/ [→←] /)
                return (
                  <span key={j} className="af-chip !h-11 !gap-2.5 !px-4 !text-[15px]">
                    <span className="font-semibold">{a}</span><ArrowRight size={14} className="text-[#EA7C25]" /><span className="font-semibold">{b}</span>
                  </span>
                )
              })}
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}

function HowItWorks() {
  return (
    <section id="how" className="mx-auto max-w-[1240px] scroll-mt-24 px-4 py-16 sm:px-6 sm:py-24">
      <SectionHead eyebrow="How it works" title={<>Three keys.<br /><span className="text-[#8C8884]">Everything a file can become.</span></>}
        body="Start dragging any file in Finder, on the desktop or out of an app. Press a key and a wheel opens around your pointer. Drop on a wedge. That's it." />
      <div className="mt-12 grid gap-4 lg:grid-cols-3">
        {WHEELS.map((x, i) => (
          <Reveal key={x.key} delay={i * 0.08}>
            <div className="af-card flex h-full flex-col overflow-hidden">
              <div className="flex items-start justify-between p-6">
                <div>
                  <div className="text-[13px] font-medium text-[#8C8884]">Hold {x.name}</div>
                  <h3 className="mt-1 text-[28px] font-semibold tracking-[-0.04em]">{x.wheel}</h3>
                  <p className="mt-1 max-w-[260px] text-[15px] leading-snug text-[#55524F]">{x.blurb}</p>
                </div>
                <Key k={x.key} label={x.name} on />
              </div>
              <div className="af-well mx-2 mb-2 flex flex-1 items-center justify-center py-8">
                <AnyWheel wedges={x.wedges} size={250} active={i === 0 ? 0 : i === 1 ? 1 : 0}
                  hub={<span className="text-[11px] font-semibold">{x.hub}</span>} />
              </div>
            </div>
          </Reveal>
        ))}
      </div>
    </section>
  )
}

function Playground() {
  const [set, setSet] = useState(0)
  const [held, setHeld] = useState<number | null>(null)
  const [aim, setAim] = useState<number | null>(null)
  const [log, setLog] = useState<{ id: number; text: string }[]>([])
  const [ref, w] = useWidth<HTMLDivElement>()
  useEffect(() => {
    const map: Record<string, number> = { Shift: 0, Meta: 1, Control: 2 }
    const down = (e: KeyboardEvent) => { if (e.key in map) { setSet(map[e.key]); setHeld(map[e.key]) } }
    const up = (e: KeyboardEvent) => { if (e.key in map) setHeld(null) }
    window.addEventListener('keydown', down); window.addEventListener('keyup', up)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up) }
  }, [])
  const x = WHEELS[set]
  const pick = (wd: Wedge) => {
    const text = set === 0 ? `clip.${wd.label.toLowerCase()} saved next to clip.mov` : set === 1 ? `${wd.label} opened for clip.mov` : `${wd.label}: clip.mov`
    setLog((l) => [{ id: Date.now(), text }, ...l].slice(0, 4))
  }
  return (
    <section className="mx-auto max-w-[1240px] px-4 py-8 sm:px-6">
      <div className="af-card grid overflow-hidden lg:grid-cols-[1fr_1.15fr]">
        <div className="flex flex-col justify-between gap-10 p-7 sm:p-10">
          <div>
            <Eyebrow>Try it</Eyebrow>
            <h2 className="mt-4 text-[34px] font-semibold leading-[1.02] tracking-[-0.045em] sm:text-[44px]">Aim, then let go.</h2>
            <p className="mt-3 max-w-[400px] text-[16px] leading-relaxed text-[#55524F]">
              This is the real wheel. Hold <b className="font-semibold text-[#111]">Shift</b>, <b className="font-semibold text-[#111]">Command</b> or <b className="font-semibold text-[#111]">Control</b> on your keyboard to switch wheels, point at a wedge and click it.
            </p>
            <div className="mt-6 flex gap-2.5">
              {WHEELS.map((k, i) => (
                <button key={k.key} onClick={() => setSet(i)} className="rounded-[14px] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#111]" aria-pressed={set === i} aria-label={`${k.wheel} wheel`}>
                  <Key k={k.key} label={k.name} on={held === i || (held === null && set === i)} />
                </button>
              ))}
            </div>
          </div>
          <div className="af-well min-h-[168px] p-3">
            <div className="mb-2 px-1 text-[12px] font-medium text-[#8C8884]">Results</div>
            {log.length === 0 && <div className="px-1 text-[14px] text-[#8C8884]">Nothing yet. Pick a wedge.</div>}
            <ul className="flex flex-col gap-1.5">
              <AnimatePresence initial={false}>
                {log.map((l) => (
                  <motion.li key={l.id} layout initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
                    className="flex items-center gap-2.5 rounded-[10px] bg-white px-3 py-2 text-[14px] shadow-[0_0_0_1px_#E7E5E2]">
                    <span className="grid size-5 place-items-center rounded-full bg-[#E9F7EF] text-[#1F9D55]"><Check size={12} strokeWidth={3} /></span>
                    <span className="truncate">{l.text}</span>
                  </motion.li>
                ))}
              </AnimatePresence>
            </ul>
          </div>
        </div>
        <div ref={ref} className="af-stage relative flex min-h-[420px] items-center justify-center overflow-hidden p-6 sm:min-h-[560px]">
          <Streaks className="inset-0 h-full w-full" />
          <AnimatePresence mode="wait">
            <motion.div key={set} initial={isShot ? false : { opacity: 0, scale: 0.85, rotate: -8 }} animate={{ opacity: 1, scale: 1, rotate: 0 }} exit={{ opacity: 0, scale: 0.9 }} transition={{ type: 'spring', stiffness: 320, damping: 26 }}>
              <AnyWheel wedges={x.wedges} size={Math.min(440, w - 48)} tone="stage" onAim={setAim} onPick={pick}
                hub={aim != null ? <span className="text-[12px] font-semibold">{x.wedges[aim].label}</span> : <FileTile small />} />
            </motion.div>
          </AnimatePresence>
          <span className="absolute bottom-5 left-1/2 -translate-x-1/2 rounded-full bg-white/15 px-3 py-1 text-[12px] font-medium text-white ring-1 ring-white/30 backdrop-blur">{x.wheel} wheel</span>
        </div>
      </div>
    </section>
  )
}

function Features() {
  const [fps, setFps] = useState(15)
  const sizes: Record<number, string> = { 10: '2.8 MB', 15: '4.1 MB', 24: '6.3 MB', 30: '7.9 MB' }
  return (
    <section id="features" className="mx-auto max-w-[1240px] scroll-mt-24 px-4 py-16 sm:px-6 sm:py-24">
      <SectionHead eyebrow="Features" title={<>A whole toolbox,<br /><span className="text-[#8C8884]">one gesture away.</span></>} />
      <div className="mt-12 grid gap-4 md:grid-cols-6">
        {/* Convert */}
        <Reveal className="md:col-span-4">
          <div className="af-card flex h-full flex-col gap-6 p-6 sm:p-8">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h3 className="text-[24px] font-semibold tracking-[-0.035em]">Convert</h3>
                <p className="mt-1 max-w-[420px] text-[15px] leading-snug text-[#55524F]">{product.features[0].body}</p>
              </div>
              <div className="text-right"><div className="text-[44px] font-semibold leading-none tracking-[-0.05em] text-[#EA7C25]"><NumberTicker value="793" /></div><div className="text-[12px] text-[#8C8884]">routes, all tested</div></div>
            </div>
            <div className="af-well grid gap-px overflow-hidden p-1 sm:grid-cols-2">
              {product.conversions.slice(0, 8).map((c) => {
                const [a, b] = c.split(/ [→←] /)
                return (
                  <div key={c} className="flex items-center justify-between rounded-[10px] bg-white/70 px-3 py-2.5 text-[14px]">
                    <span className="flex items-center gap-2 font-medium"><span className="w-12">{a}</span><ArrowRight size={13} className="text-[#8C8884]" /><span>{b}</span></span>
                    <span className="grid size-5 place-items-center rounded-full bg-[#FFF3E6] text-[#E5701E]"><Check size={12} strokeWidth={3} /></span>
                  </div>
                )
              })}
            </div>
          </div>
        </Reveal>
        {/* Presets */}
        <Reveal className="md:col-span-2" delay={0.05}>
          <div className="af-card flex h-full flex-col gap-5 p-6 sm:p-8">
            <div>
              <h3 className="text-[24px] font-semibold tracking-[-0.035em]">Presets</h3>
              <p className="mt-1 text-[15px] leading-snug text-[#55524F]">{product.features[3].body}</p>
            </div>
            <div className="af-well mt-auto p-4">
              <div className="mb-3 flex items-center justify-between text-[13px]"><span className="font-semibold">GIF · frame rate</span><span className="af-mono text-[#8C8884]">clip.mov</span></div>
              <div className="flex flex-wrap gap-2">
                {[10, 15, 24, 30].map((f) => (
                  <button key={f} onClick={() => setFps(f)} className={`af-chip !h-auto flex-col !items-start !gap-0 !rounded-[10px] !px-3 !py-1.5 ${fps === f ? 'af-chip-on' : ''}`}>
                    <span className="text-[14px] font-semibold">{f} fps</span>
                    <span className={`af-mono text-[10px] ${fps === f ? 'text-white/85' : 'text-[#8C8884]'}`}>{sizes[f]}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        </Reveal>
        {/* Tools */}
        <Reveal className="md:col-span-2" delay={0.05}>
          <div className="af-card flex h-full flex-col gap-5 p-6 sm:p-8">
            <div>
              <h3 className="text-[24px] font-semibold tracking-[-0.035em]">Tools</h3>
              <p className="mt-1 text-[15px] leading-snug text-[#55524F]">{product.features[1].body}</p>
            </div>
            <div className="af-well relative mt-auto aspect-[4/3] overflow-hidden">
              <div className="absolute inset-4 rounded-[8px]" style={{ background: 'linear-gradient(160deg,#FFC08A,#EA7C25 55%,#8E2E0B)' }} />
              <div className="absolute inset-x-[22%] inset-y-[20%] rounded-[4px] shadow-[0_0_0_999px_rgba(17,17,17,.45)] ring-2 ring-white">
                {['left-0 top-0', 'right-0 top-0', 'left-0 bottom-0', 'right-0 bottom-0'].map((p) => <span key={p} className={`absolute ${p} -m-1 size-2.5 rounded-[2px] bg-white`} />)}
              </div>
              <span className="af-chip absolute bottom-3 left-1/2 -translate-x-1/2 !h-7 !text-[12px]"><Crop size={13} />1080 × 1080</span>
            </div>
          </div>
        </Reveal>
        {/* Actions */}
        <Reveal className="md:col-span-2" delay={0.1}>
          <div className="af-card flex h-full flex-col gap-5 p-6 sm:p-8">
            <div>
              <h3 className="text-[24px] font-semibold tracking-[-0.035em]">Actions</h3>
              <p className="mt-1 text-[15px] leading-snug text-[#55524F]">{product.features[2].body}</p>
            </div>
            <div className="af-well mt-auto flex flex-col gap-1 p-1.5">
              {product.actions.slice(0, 4).map((a, i) => (
                <div key={a} className={`flex items-center gap-2.5 rounded-[9px] px-3 py-2 text-[14px] ${i === 1 ? 'bg-gradient-to-b from-[#F59248] to-[#E5701E] text-white shadow-[inset_0_1px_0_rgba(255,255,255,.4)]' : 'bg-white/70'}`}>
                  {iconFor[a]}<span className="font-medium">{a}</span>
                  {i === 1 && <span className="ml-auto text-[11px] text-white/85">holds files between drags</span>}
                </div>
              ))}
            </div>
          </div>
        </Reveal>
        {/* Private */}
        <Reveal className="md:col-span-2" delay={0.15}>
          <div className="af-card flex h-full flex-col gap-5 p-6 text-white sm:p-8" style={{ background: '#111', boxShadow: '0 0 0 1px #000, 0 20px 40px -20px rgba(0,0,0,.6)' }}>
            <div>
              <h3 className="text-[24px] font-semibold tracking-[-0.035em]">Private</h3>
              <p className="mt-1 text-[15px] leading-snug text-white/65">{product.features[5].body}</p>
            </div>
            <div className="mt-auto flex items-end justify-between">
              <div><div className="text-[72px] font-semibold leading-none tracking-[-0.06em]">0</div><div className="text-[13px] text-white/55">network calls unless you ask</div></div>
              <WifiOff size={28} className="mb-2 text-[#EA7C25]" />
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  )
}

function MenuBar() {
  const items: (string | null)[] = ['Convert last file…', 'Open Float shelf', null, 'Presets', 'Recent conversions', null, 'Settings…', 'Quit anyfmt']
  return (
    <section className="px-2 sm:px-3">
      <div className="relative overflow-hidden rounded-[28px] bg-[#111] text-white sm:rounded-[36px]">
        <div className="pointer-events-none absolute -right-40 -top-40 size-[640px] rounded-full opacity-60 blur-[60px]" style={{ background: 'radial-gradient(circle, #EA7C25 0%, transparent 60%)' }} />
        <div className="relative mx-auto grid max-w-[1240px] items-center gap-12 px-5 py-16 sm:px-8 sm:py-24 lg:grid-cols-2">
          <div>
            <Eyebrow tone="stage">Lives in your menu bar</Eyebrow>
            <h2 className="mt-5 text-[38px] font-semibold leading-[1.02] tracking-[-0.045em] sm:text-[56px]">Out of the way<br /><span className="text-white/45">until you drag.</span></h2>
            <p className="mt-5 max-w-[460px] text-[17px] leading-relaxed text-white/65">No window to open, no app to switch to. anyfmt waits in the menu bar and shows up the moment a drag needs it. Long jobs get a small progress pill you can cancel.</p>
            <div className="mt-8 flex flex-wrap items-center gap-4">
              {/* progress HUD */}
              <div className="flex items-center gap-3 rounded-full bg-white/10 py-2 pl-2 pr-4 ring-1 ring-white/15 backdrop-blur">
                <svg width="34" height="34" viewBox="0 0 36 36" aria-hidden>
                  <circle cx="18" cy="18" r="15" fill="none" stroke="rgba(255,255,255,.15)" strokeWidth="3.5" />
                  <circle cx="18" cy="18" r="15" fill="none" stroke="#EA7C25" strokeWidth="3.5" strokeLinecap="round" strokeDasharray="94.2" strokeDashoffset="33" transform="rotate(-90 18 18)" />
                </svg>
                <div className="text-[13px] leading-tight"><div className="font-semibold">clip.mov → GIF</div><div className="text-white/55">65% · 3 s left</div></div>
                <span className="ml-1 grid size-6 place-items-center rounded-full bg-white/10"><X size={13} /></span>
              </div>
            </div>
          </div>
          <div className="relative mx-auto w-full max-w-[460px]">
            <div className="flex h-8 items-center justify-end gap-4 rounded-t-[12px] bg-white/10 px-4 text-[12px] text-white/80 backdrop-blur">
              <span className="grid size-6 place-items-center rounded-[6px] bg-white/20"><Mark size={15} variant="white" /></span><span>Mon 9:41</span>
            </div>
            <div className="ml-auto mr-10 mt-2 w-[270px] rounded-[14px] bg-[#F7F7F7]/95 p-1.5 text-[14px] text-[#111] shadow-[0_0_0_1px_rgba(0,0,0,.2),0_30px_60px_-20px_rgba(0,0,0,.7)] backdrop-blur-xl">
              <div className="flex items-center gap-2.5 px-2.5 py-2"><AppIcon size={28} /><div className="leading-tight"><div className="font-semibold">anyfmt</div><div className="text-[12px] text-[#8C8884]">Ready · drag any file</div></div></div>
              <div className="my-1 h-px bg-black/10" />
              {items.map((it, i) => it === null ? <div key={i} className="my-1 h-px bg-black/10" /> : (
                <div key={i} className={`rounded-[8px] px-2.5 py-1.5 ${i === 0 ? 'bg-gradient-to-b from-[#F59248] to-[#E5701E] text-white' : ''}`}>{it}</div>
              ))}
            </div>
            <div className="absolute -bottom-6 -left-4 hidden sm:block" style={{ animation: isShot ? undefined : 'af-float 6s ease-in-out infinite' }}>
              <AppIcon size={104} />
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function Stats() {
  return (
    <section className="mx-auto max-w-[1240px] px-4 py-16 sm:px-6 sm:py-24">
      <div className="grid grid-cols-2 gap-x-6 gap-y-10 lg:grid-cols-4">
        {stats.map((s) => (
          <Reveal key={s.label} className="border-t border-[#D9D6D2] pt-5">
            <div className="text-[56px] font-semibold leading-none tracking-[-0.06em] sm:text-[72px]"><NumberTicker value={s.value} /></div>
            <div className="mt-3 max-w-[220px] text-[15px] text-[#55524F]">{s.label}</div>
          </Reveal>
        ))}
      </div>
    </section>
  )
}

function Agents() {
  const lines: [string, string][] = [
    ['$', 'anyfmt convert clip.mov --to gif --json'],
    ['', '{ "input": "clip.mov", "output": "clip.gif", "bytes": 4300800 }'],
    ['$', 'anyfmt convert ~/Desktop/*.heic --to jpg --ndjson'],
    ['', '{ "event": "progress", "file": "IMG_0412.heic", "done": 0.5 }'],
    ['', '{ "event": "done", "file": "IMG_0412.jpg" }'],
  ]
  return (
    <section id="agents" className="mx-auto grid [&>*]:min-w-0 max-w-[1240px] scroll-mt-24 items-center gap-12 px-4 py-16 sm:px-6 sm:py-24 lg:grid-cols-[1fr_1.2fr]">
      <SectionHead eyebrow="For agents" title={<>Your scripts and agents<br /><span className="text-[#8C8884]">can drop files too.</span></>}
        body={product.features[4].body} />
      <Reveal>
        <div className="overflow-hidden rounded-[20px] bg-[#111] shadow-[0_0_0_1px_#000,0_30px_60px_-24px_rgba(0,0,0,.5)]">
          <div className="flex items-center gap-2 border-b border-white/10 px-4 py-3">
            {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}
            <span className="ml-3 text-[12px] text-white/45">Terminal</span>
          </div>
          <div className="overflow-x-auto p-5">
            <pre className="af-mono text-[13px] leading-[1.9]">
              {lines.map(([p, l], i) => (
                <div key={i}>{p ? <><span className="text-[#EA7C25]">{p}</span> <span className="text-white">{l}</span></> : <span className="text-white/50">{l}</span>}</div>
              ))}
            </pre>
          </div>
          <div className="flex flex-wrap gap-2 border-t border-white/10 px-5 py-3 text-[12px] text-white/60">
            <span className="rounded-full bg-white/10 px-2.5 py-1">JSON</span><span className="rounded-full bg-white/10 px-2.5 py-1">NDJSON progress</span><span className="rounded-full bg-white/10 px-2.5 py-1">MCP server</span>
          </div>
        </div>
      </Reveal>
    </section>
  )
}

function Pricing() {
  const [local, pro] = pricing
  return (
    <section id="pricing" className="mx-auto max-w-[1240px] scroll-mt-24 px-4 py-16 sm:px-6 sm:py-24">
      <SectionHead center eyebrow="Pricing" title="Free where it runs." body="Everything that happens on your Mac is free, forever. Pro adds the few things that need a server." />
      <div className="mx-auto mt-12 grid max-w-[920px] gap-4 md:grid-cols-2">
        <Reveal>
          <div className="af-card flex h-full flex-col p-7 sm:p-8">
            <div className="text-[15px] font-semibold text-[#55524F]">{local.name}</div>
            <div className="mt-3 flex items-baseline gap-2"><span className="text-[56px] font-semibold leading-none tracking-[-0.05em]">{local.price}</span><span className="text-[#8C8884]">{local.period}</span></div>
            <ul className="mt-7 flex flex-col gap-3 text-[15px]">
              {local.points.map((p) => <li key={p} className="flex items-center gap-3"><span className="grid size-5 place-items-center rounded-full bg-[#FFF3E6] text-[#E5701E]"><Check size={12} strokeWidth={3} /></span>{p}</li>)}
            </ul>
            <a href="#download" className="af-btn af-btn-light mt-8 w-full justify-center"><Download size={16} />Download for Mac</a>
          </div>
        </Reveal>
        <Reveal delay={0.06}>
          <div className="af-stage relative flex h-full flex-col overflow-hidden rounded-[20px] p-7 shadow-[0_24px_50px_-20px_rgba(187,63,20,.6)] sm:p-8">
            <Streaks className="inset-0 h-full w-full" />
            <div className="relative flex items-center justify-between"><span className="text-[15px] font-semibold text-white/85">{pro.name}</span><span className="rounded-full bg-white/20 px-2.5 py-1 text-[11px] font-semibold ring-1 ring-white/40">Optional</span></div>
            <div className="relative mt-3 flex items-baseline gap-2"><span className="text-[56px] font-semibold leading-none tracking-[-0.05em]">{pro.price}</span><span className="text-white/75">{pro.period}</span></div>
            <ul className="relative mt-7 flex flex-col gap-3 text-[15px]">
              {pro.points.map((p) => <li key={p} className="flex items-center gap-3"><span className="grid size-5 place-items-center rounded-full bg-white/25"><Check size={12} strokeWidth={3} /></span>{p}</li>)}
            </ul>
            <a href="#download" className="af-btn af-btn-dark relative mt-8 w-full justify-center">Start with Local, add Pro later</a>
          </div>
        </Reveal>
      </div>
    </section>
  )
}

function Faq() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="mx-auto grid max-w-[1240px] scroll-mt-24 gap-10 px-4 py-16 sm:px-6 sm:py-24 lg:grid-cols-[1fr_1.4fr]">
      <SectionHead eyebrow="FAQ" title="Questions, answered." />
      <div className="flex flex-col gap-2.5">
        {faqs.map((f, i) => {
          const on = open === i || isShot && i === 0
          return (
            <div key={f.q} className="af-card overflow-hidden !rounded-[16px]">
              <button id={`faq-${i}`} aria-expanded={on} onClick={() => setOpen(on ? null : i)}
                className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left text-[16px] font-semibold tracking-[-0.015em] focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-[#111]">
                {f.q}
                <span className={`grid size-7 shrink-0 place-items-center rounded-full transition-colors ${on ? 'bg-[#EA7C25] text-white' : 'bg-[#F3F2F0] text-[#55524F]'}`}>{on ? <Minus size={14} /> : <Plus size={14} />}</span>
              </button>
              <AnimatePresence initial={false}>
                {on && (
                  <motion.div initial={isShot ? false : { height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}>
                    <p className="max-w-[620px] px-5 pb-5 text-[15px] leading-relaxed text-[#55524F]">{f.a}</p>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          )
        })}
      </div>
    </section>
  )
}

function FinalCta() {
  return (
    <section id="download" className="scroll-mt-24 px-2 pb-2 sm:px-3 sm:pb-3">
      <div className="af-stage relative overflow-hidden rounded-[28px] sm:rounded-[36px]">
        <Streaks className="inset-0 h-full w-full" />
        <div className="relative mx-auto flex max-w-[1240px] flex-col items-center px-4 pb-[clamp(120px,20vw,300px)] pt-20 text-center sm:pt-28">
          <div style={{ animation: isShot ? undefined : 'af-float 7s ease-in-out infinite' }}>
            <GlassTile size={190} />
          </div>
          <h2 className="mt-12 max-w-[800px] text-[44px] font-semibold leading-[0.98] tracking-[-0.05em] text-balance sm:text-[72px]">Drop it.<br />It's done.</h2>
          <p className="mt-5 max-w-[460px] text-[17px] text-white/85">Free, open source and local. One download, then every file on your Mac is a drag away from any format.</p>
          <div className="mt-8 flex flex-wrap justify-center gap-3">
            <a href="#download" className="af-btn af-btn-light !h-12 !px-6 !text-[16px]"><Download size={18} />Download for Mac</a>
            <a href="#agents" className="af-btn af-btn-ghost !h-12 !px-6 !text-[16px]"><ShieldCheck size={17} />Read the source</a>
          </div>
          <p className="mt-4 text-[13px] text-white/70">{brand.platform}</p>
        </div>
        <div aria-hidden className="pointer-events-none absolute inset-x-0 -bottom-[0.24em] select-none text-center font-semibold leading-none tracking-[-0.07em] text-white/[.14]"
             style={{ fontSize: 'clamp(140px, 30vw, 460px)' }}>anyfmt</div>
      </div>
    </section>
  )
}

function Footer() {
  const cols: [string, string[]][] = [
    ['Product', ['How it works', 'Features', 'Pricing', 'Changelog']],
    ['Developers', ['Command line', 'MCP server', 'Source code', 'AGPL-3.0']],
    ['Company', ['Brand book', 'Privacy', 'Contact', brand.domain]],
  ]
  return (
    <footer className="mx-auto max-w-[1240px] px-4 pb-28 pt-14 sm:px-6">
      <div className="grid gap-10 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div className="flex flex-col gap-3">
          <Wordmark size={22} />
          <p className="max-w-[280px] text-[14px] text-[#8C8884]">{product.oneLiner}</p>
        </div>
        {cols.map(([h, ls]) => (
          <div key={h}>
            <div className="text-[13px] font-semibold">{h}</div>
            <ul className="mt-3 flex flex-col gap-2 text-[14px] text-[#55524F]">{ls.map((l) => <li key={l}>{l === 'Brand book' ? <a href="#/anyfmt/book" className="hover:text-[#111]">{l}</a> : l}</li>)}</ul>
          </div>
        ))}
      </div>
      <div className="mt-12 flex flex-wrap justify-between gap-3 border-t border-[#E7E5E2] pt-6 text-[13px] text-[#8C8884]">
        <span>© 2026 anyfmt. Open source under AGPL-3.0.</span><span>Made for macOS</span>
      </div>
    </footer>
  )
}

export default function Landing() {
  useEffect(() => { document.title = 'anyfmt' }, [])
  return (
    <div className="af min-h-screen overflow-x-clip">
      <Nav />
      <Hero />
      <Formats />
      <HowItWorks />
      <Playground />
      <Features />
      <MenuBar />
      <Stats />
      <Agents />
      <Pricing />
      <Faq />
      <FinalCta />
      <Footer />
    </div>
  )
}
