import NumberFlow from '@number-flow/react'
import { Dithering, GrainGradient, SmokeRing } from '@paper-design/shaders-react'
import confetti from 'canvas-confetti'
import { AnimatePresence, motion, useInView, useScroll, useSpring, useTransform, useVelocity } from 'motion/react'
import {
  ArrowRight, Check, Copy, Crop, Download, Eraser, FolderInput, Link2, Lock, Minimize2, Pin, Plus, Scissors, Send, SquareTerminal, Wand2,
} from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { toast } from 'sonner'
import { isShot } from '../shared/kit'
import { product } from '../shared/product'
import { Mark, Wordmark } from './Logo'
import { NovaWheel, type Wedge } from './fx/NovaWheel'
import { Button, GlowCard, LiveKey, Rise, scrollToId } from './fx/ui'
import { FileIcon } from './Story'

function Eyebrow({ children }: { children: ReactNode }) {
  return <div className="nv-mono mb-5 flex items-center gap-2 text-[12px] uppercase text-[var(--nv-ember)]"><span className="h-px w-6 [background:var(--nv-molten)]" />{children}</div>
}

/* ------------------------------------------------------------------ marquee */

export function FormatsMarquee() {
  const { scrollY } = useScroll()
  const vel = useVelocity(scrollY)
  const skew = useSpring(useTransform(vel, [-2500, 0, 2500], [8, 0, -8]), { stiffness: 200, damping: 30 })
  const row = product.conversions
  return (
    <section aria-label="Conversions" className="relative overflow-hidden py-16">
      <motion.div style={{ skewX: isShot ? 0 : skew }} className="flex flex-col gap-4 [mask-image:linear-gradient(90deg,transparent,#000_12%,#000_88%,transparent)]">
        {[0, 1].map((r) => (
          <div key={r} className="flex overflow-hidden">
            <div className="flex shrink-0 gap-4 pr-4" style={{ animation: isShot ? 'none' : `nv-marquee ${r ? 55 : 45}s linear infinite ${r ? 'reverse' : ''}` }}>
              {[...row, ...row].map((c, i) => {
                const [a, b] = c.split(/ [→←] /)
                return (
                  <span key={i} className="nv-display group flex shrink-0 items-center gap-4 rounded-[18px] bg-white/[.03] px-6 py-4 text-[clamp(22px,2.6vw,38px)] shadow-[inset_0_0_0_1px_var(--nv-line)] transition-colors duration-300 hover:bg-white/[.07]">
                    <span className="text-[var(--nv-mute)] transition-colors group-hover:text-white">{a}</span>
                    <ArrowRight className="text-[var(--nv-ember)] transition-transform duration-300 group-hover:translate-x-1" size={22} />
                    <span className="nv-molten-text">{b}</span>
                  </span>
                )
              })}
            </div>
          </div>
        ))}
      </motion.div>
    </section>
  )
}

/* ------------------------------------------------------------------ bento */

function Beams() {
  const targets = ['GIF', 'MP4', 'WEBP', 'PDF', 'MP3', 'HEIC']
  const W = 560, H = 260, sx = 90, sy = H / 2
  return (
    <div className="relative">
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" aria-hidden>
        <defs>
          <linearGradient id="beam" x1="0" x2="1"><stop offset="0" stopColor="#FFC24B" stopOpacity="0" /><stop offset=".4" stopColor="#FFC24B" /><stop offset=".7" stopColor="#FF5A1F" /><stop offset="1" stopColor="#FF2E63" stopOpacity="0" /></linearGradient>
        </defs>
        {targets.map((t, i) => {
          const ty = 22 + i * ((H - 44) / (targets.length - 1)), tx = W - 96
          const d = `M${sx},${sy} C${sx + 160},${sy} ${tx - 160},${ty} ${tx},${ty}`
          return (
            <g key={t}>
              <path d={d} fill="none" stroke="rgba(255,255,255,.08)" strokeWidth="1.5" />
              <motion.path d={d} fill="none" stroke="url(#beam)" strokeWidth="2.2" strokeLinecap="round" strokeDasharray="70 600"
                initial={{ strokeDashoffset: 670 }} animate={{ strokeDashoffset: isShot ? 300 : [670, 0] }}
                transition={isShot ? { duration: 0 } : { duration: 2.4, repeat: Infinity, ease: 'easeInOut', delay: i * 0.28, repeatDelay: 0.6 }} />
            </g>
          )
        })}
      </svg>
      <div className="absolute left-[3%] top-1/2 -translate-y-1/2"><FileIcon ext="MOV" size={52} /></div>
      {targets.map((t, i) => (
        <div key={t} className="nv-mono absolute right-[2%] -translate-y-1/2 rounded-[8px] bg-white/[.05] px-2.5 py-1 text-[11px] text-white/85 shadow-[inset_0_0_0_1px_var(--nv-line-2)]"
          style={{ top: `${((22 + i * ((H - 44) / (targets.length - 1))) / H) * 100}%` }}>{t}</div>
      ))}
    </div>
  )
}

/** A sealed ring of light: the loop your files stay inside. */
function SealedRing() {
  return (
    <div className="relative mx-auto aspect-square w-full max-w-[360px]">
      <SmokeRing className="absolute inset-0 h-full w-full" colorBack="#0A0A0F" colors={['#4DF0FF', '#FF5A1F', '#FF2E63']} noiseScale={1.6} thickness={0.42} radius={0.32} innerShape={0.75} noiseIterations={8} speed={isShot ? 0 : 0.6} />
      <div className="absolute inset-0 grid place-items-center">
        <div className="grid size-16 place-items-center rounded-full bg-black/60 shadow-[inset_0_0_0_1px_rgba(77,240,255,.4),0_0_40px_-6px_rgba(77,240,255,.6)] backdrop-blur"><Lock size={24} className="text-[var(--nv-ion)]" /></div>
      </div>
    </div>
  )
}

function Orbit() {
  const icons = [Send, Pin, Copy, FolderInput, Link2, SquareTerminal]
  const spin = isShot ? 'none' : 'nv-spin-slow 26s linear infinite'
  return (
    <div className="relative mx-auto aspect-square w-full max-w-[220px]">
      <div className="absolute inset-[10%] rounded-full border border-dashed border-white/[.1]" />
      <div className="absolute inset-[32%] rounded-full border border-dashed border-white/[.07]" />
      <div className="absolute inset-[10%]" style={{ animation: spin }}>
        {icons.map((I, i) => {
          const a = (i / icons.length) * Math.PI * 2
          return (
            <div key={i} className="absolute grid size-10 -translate-x-1/2 -translate-y-1/2 place-items-center rounded-[12px] bg-[var(--nv-ink-3)] text-white shadow-[inset_0_0_0_1px_var(--nv-line-2),0_8px_20px_-8px_rgba(0,0,0,.8)] transition-colors hover:text-[var(--nv-ember)]"
              style={{ left: `${50 + 50 * Math.sin(a)}%`, top: `${50 - 50 * Math.cos(a)}%` }}>
              <span style={{ animation: isShot ? 'none' : 'nv-spin-slow 26s linear infinite reverse', display: 'grid' }}><I size={17} /></span>
            </div>
          )
        })}
      </div>
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"><FileIcon ext="ZIP" size={44} /></div>
      <style>{'@keyframes nv-spin-slow{to{transform:rotate(360deg)}}'}</style>
    </div>
  )
}

function Latency() {
  const [bars, setBars] = useState(() => Array.from({ length: 28 }, (_, i) => 30 + ((i * 37) % 18)))
  const [now, setNow] = useState(43)
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref)
  useEffect(() => {
    if (!inView || isShot) return
    const id = setInterval(() => {
      const v = Math.round(34 + Math.random() * 14)
      setNow(v)
      setBars((b) => [...b.slice(1), v])
    }, 650)
    return () => clearInterval(id)
  }, [inView])
  return (
    <div ref={ref}>
      <div className="flex items-baseline gap-2">
        <span className="nv-display text-[64px] leading-none"><NumberFlow value={now} /></span><span className="nv-mono text-[var(--nv-mute)]">ms</span>
        <span className="nv-mono ml-auto rounded-full bg-[rgba(77,240,255,.1)] px-2 py-0.5 text-[10.5px] text-[var(--nv-ion)]">● live</span>
      </div>
      <div className="relative mt-5 flex h-20 items-end gap-[3px]">
        <div className="absolute inset-x-0 border-t border-dashed border-white/20" style={{ bottom: `${(50 / 60) * 100}%` }}><span className="nv-mono absolute -top-4 right-0 text-[9px] text-[var(--nv-dim)]">50 ms budget</span></div>
        {bars.map((b, i) => (
          <motion.div key={i} layout className="flex-1 rounded-t-[2px]" animate={{ height: `${(b / 60) * 100}%` }} transition={{ type: 'spring', stiffness: 300, damping: 30 }}
            style={{ background: i === bars.length - 1 ? 'var(--nv-ion)' : 'linear-gradient(180deg,#FF5A1F,rgba(255,46,99,.25))', opacity: 0.35 + (i / bars.length) * 0.65 }} />
        ))}
      </div>
    </div>
  )
}

function CropDemo() {
  const tools = [{ i: Crop, t: 'Crop 16:9' }, { i: Minimize2, t: 'Compress to 5 MB' }, { i: Eraser, t: 'Redact faces' }, { i: Scissors, t: 'Trim 0:04–0:12' }, { i: Wand2, t: 'Remove background' }]
  const [k, setK] = useState(0)
  useEffect(() => { if (isShot) return; const id = setInterval(() => setK((n) => (n + 1) % tools.length), 1800); return () => clearInterval(id) }, [tools.length])
  const T = tools[k]
  return (
    <div className="relative">
      <div className="relative aspect-[4/3] overflow-hidden rounded-[14px]" style={{ background: 'radial-gradient(circle at 30% 30%, #FFC24B, #FF5A1F 40%, #7a1430 75%, #120810)' }}>
        <motion.div className="absolute rounded-[6px] shadow-[0_0_0_9999px_rgba(5,5,7,.6)] ring-2 ring-white"
          animate={isShot ? { left: '16%', top: '18%', right: '22%', bottom: '24%' } : { left: ['16%', '10%', '24%', '16%'], top: ['18%', '26%', '12%', '18%'], right: ['22%', '14%', '18%', '22%'], bottom: ['24%', '16%', '30%', '24%'] }}
          transition={{ duration: 6, repeat: Infinity, ease: 'easeInOut' }}>
          {['-left-1.5 -top-1.5', '-right-1.5 -top-1.5', '-left-1.5 -bottom-1.5', '-right-1.5 -bottom-1.5'].map((p) => <span key={p} className={`absolute ${p} size-3 rounded-[3px] bg-white`} />)}
        </motion.div>
      </div>
      <div className="absolute bottom-3 left-1/2 -translate-x-1/2">
        <AnimatePresence mode="popLayout">
          <motion.div key={T.t} initial={{ y: 12, opacity: 0, filter: 'blur(4px)' }} animate={{ y: 0, opacity: 1, filter: 'blur(0px)' }} exit={{ y: -12, opacity: 0, filter: 'blur(4px)' }}
            className="flex items-center gap-2 whitespace-nowrap rounded-full bg-black/70 px-3 py-1.5 text-[12.5px] text-white shadow-[inset_0_0_0_1px_rgba(255,255,255,.15)] backdrop-blur"><T.i size={14} />{T.t}</motion.div>
        </AnimatePresence>
      </div>
    </div>
  )
}

export function Features() {
  const card = 'p-7 sm:p-8'
  return (
    <section id="features" className="mx-auto max-w-[1240px] scroll-mt-24 px-5 py-28 sm:px-8">
      <Rise>
        <Eyebrow>Everything a file can do</Eyebrow>
        <h2 className="nv-display max-w-[900px] text-[clamp(40px,5.6vw,84px)]">Convert, edit, share.<br /><span className="text-[var(--nv-dim)]">Without opening a thing.</span></h2>
      </Rise>
      <div className="mt-16 grid gap-4 lg:grid-cols-12">
        <Rise className="lg:col-span-7"><GlowCard className={`${card} h-full`}>
          <div className="flex items-start justify-between gap-6">
            <div><h3 className="nv-display text-[30px]">Convert</h3><p className="mt-2 max-w-[380px] text-[15px] leading-relaxed text-[var(--nv-mute)]">{product.features[0].body}</p></div>
            <div className="text-right"><div className="nv-display text-[56px] leading-none text-[var(--nv-ember)] [text-shadow:0_0_30px_rgba(255,90,31,.5)]"><NumberFlow value={793} /></div><div className="nv-mono mt-1 text-[11px] text-[var(--nv-dim)]">routes, all tested</div></div>
          </div>
          <div className="mt-8"><Beams /></div>
        </GlowCard></Rise>
        <Rise className="lg:col-span-5" delay={0.05}><GlowCard className={`${card} h-full`} glow="rgba(77,240,255,.5)">
          <div className="flex items-center gap-2"><Lock size={16} className="text-[var(--nv-ion)]" /><h3 className="nv-display text-[30px]">Private</h3></div>
          <p className="mt-2 text-[15px] leading-relaxed text-[var(--nv-mute)]">{product.features[5].body}</p>
          <div className="relative mt-4">
            <SealedRing />
            <div className="text-center"><div className="nv-display text-[56px] leading-none">0</div><div className="nv-mono mt-1 text-[11px] uppercase text-[var(--nv-mute)]">network calls unless you ask</div></div>
          </div>
        </GlowCard></Rise>
        <Rise className="lg:col-span-4" delay={0.05}><GlowCard className={`${card} h-full`}>
          <h3 className="nv-display text-[26px]">Tools</h3>
          <p className="mb-6 mt-2 text-[15px] leading-relaxed text-[var(--nv-mute)]">Hold ⌘ instead. {product.stats[1].value} tools that each save a new copy.</p>
          <CropDemo />
        </GlowCard></Rise>
        <Rise className="lg:col-span-4" delay={0.1}><GlowCard className={`${card} h-full`}>
          <h3 className="nv-display text-[26px]">Actions</h3>
          <p className="mb-4 mt-2 text-[15px] leading-relaxed text-[var(--nv-mute)]">Hold ⌃. AirDrop, a Float shelf, copy, move, path, Terminal. Works on folders too.</p>
          <Orbit />
        </GlowCard></Rise>
        <Rise className="lg:col-span-4" delay={0.15}><GlowCard className={`${card} h-full`} glow="rgba(77,240,255,.5)">
          <h3 className="nv-display text-[26px]">Instant</h3>
          <p className="mb-6 mt-2 text-[15px] leading-relaxed text-[var(--nv-mute)]">Key press to wheel on screen. Measured, not promised.</p>
          <Latency />
        </GlowCard></Rise>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ playground */

const ico = (I: typeof Crop) => <I size={15} />
const SETS: { key: string; code: 'Shift' | 'Meta' | 'Control'; name: string; wedges: Wedge[] }[] = [
  { key: '⇧', code: 'Shift', name: 'Convert', wedges: ['GIF', 'MP4', 'WEBM', 'M4V', 'MKV', 'MP3', 'WAV', 'PNG'].map((f) => ({ id: f, label: f })) },
  { key: '⌘', code: 'Meta', name: 'Tools', wedges: [['Compress', Minimize2], ['Crop', Crop], ['Trim', Scissors], ['Redact', Eraser], ['Remove BG', Wand2], ['Add BG', Plus]].map(([l, I]) => ({ id: l as string, label: l as string, icon: ico(I as typeof Crop) })) },
  { key: '⌃', code: 'Control', name: 'Actions', wedges: [['AirDrop', Send], ['Float', Pin], ['Copy', Copy], ['Move', FolderInput], ['Path', Link2], ['Terminal', SquareTerminal]].map(([l, I]) => ({ id: l as string, label: l as string, icon: ico(I as typeof Crop) })) },
]

export function Playground() {
  const [set, setSet] = useState(0)
  const [log, setLog] = useState<{ id: number; t: string }[]>([])
  const [size, setSize] = useState(440)
  const box = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const m: Record<string, number> = { Shift: 0, Meta: 1, Control: 2 }
    const d = (e: KeyboardEvent) => { if (e.key in m) setSet(m[e.key]) }
    window.addEventListener('keydown', d)
    return () => window.removeEventListener('keydown', d)
  }, [])
  useEffect(() => {
    const el = box.current; if (!el) return
    const ro = new ResizeObserver(() => setSize(Math.min(460, el.clientWidth - 32)))
    ro.observe(el); return () => ro.disconnect()
  }, [])
  const S = SETS[set]
  const pick = (w: Wedge) => {
    const t = set === 0 ? `clip.${w.label.toLowerCase()} saved next to clip.mov` : set === 1 ? `${w.label} opened for clip.mov` : `${w.label}: clip.mov`
    setLog((l) => [{ id: Date.now(), t }, ...l].slice(0, 5))
    confetti({ particleCount: 28, spread: 50, startVelocity: 22, scalar: 0.7, ticks: 90, origin: { y: 0.6 }, colors: ['#FFC24B', '#FF5A1F', '#FF2E63', '#4DF0FF'], disableForReducedMotion: true })
  }
  return (
    <section id="play" className="relative scroll-mt-24 overflow-hidden py-28">
      <div className="mx-auto grid max-w-[1240px] items-center gap-12 px-5 sm:px-8 lg:grid-cols-[1fr_1.1fr]">
        <Rise>
          <Eyebrow>Playground</Eyebrow>
          <h2 className="nv-display text-[clamp(40px,5.2vw,76px)]">Go on.<br /><span className="nv-molten-text">Hold a key.</span></h2>
          <p className="mt-6 max-w-[420px] text-[17px] leading-relaxed text-[var(--nv-mute)]">This is the real wheel. Hold Shift, Command or Control on your keyboard to switch sets, aim with your pointer, click to drop.</p>
          <div className="relative mt-8 inline-flex rounded-[16px] bg-white/[.04] p-1 shadow-[inset_0_0_0_1px_var(--nv-line)]">
            {SETS.map((s, i) => (
              <button key={s.name} onClick={() => setSet(i)} className="relative flex items-center gap-2 rounded-[12px] px-4 py-2.5 text-[14px] outline-none focus-visible:ring-2 focus-visible:ring-[var(--nv-ion)]">
                {set === i && <motion.span layoutId="nv-set" className="absolute inset-0 rounded-[12px] bg-white/[.09] shadow-[inset_0_0_0_1px_var(--nv-line-2)]" transition={{ type: 'spring', stiffness: 500, damping: 36 }} />}
                <span className="relative"><LiveKey k={s.key} label={s.code === 'Meta' ? 'cmd' : s.code.toLowerCase()} code={s.code} /></span>
                <span className={`relative ${set === i ? 'text-white' : 'text-[var(--nv-mute)]'}`}>{s.name}</span>
              </button>
            ))}
          </div>
          <div className="mt-8 min-h-[190px] max-w-[440px] space-y-2">
            {log.length === 0 && <p className="nv-mono text-[12px] text-[var(--nv-dim)]">→ Nothing dropped yet.</p>}
            <AnimatePresence initial={false}>
              {log.map((l) => (
                <motion.div key={l.id} layout initial={{ opacity: 0, x: -16, filter: 'blur(4px)' }} animate={{ opacity: 1, x: 0, filter: 'blur(0px)' }} exit={{ opacity: 0 }}
                  className="flex items-center gap-3 rounded-[12px] bg-white/[.04] px-3.5 py-2.5 text-[14px] shadow-[inset_0_0_0_1px_var(--nv-line)]">
                  <span className="grid size-5 place-items-center rounded-full text-black [background:var(--nv-molten)]"><Check size={12} strokeWidth={3} /></span>{l.t}
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </Rise>
        <div ref={box} className="relative grid aspect-square w-full place-items-center overflow-hidden rounded-[32px] shadow-[inset_0_0_0_1px_var(--nv-line)]">
          <GrainGradient className="absolute inset-0 h-full w-full" colorBack="#050507" colors={['#FF5A1F', '#FF2E63', '#3a0d1c', '#FFC24B']} softness={0.7} intensity={0.35} noise={0.35} shape="blob" speed={isShot ? 0 : 0.6} />
          <div className="absolute inset-0 bg-[radial-gradient(circle,rgba(5,5,7,.2),rgba(5,5,7,.75))]" />
          <AnimatePresence mode="wait">
            <motion.div key={set} className="relative" initial={{ scale: 0.6, opacity: 0, rotate: -40 }} animate={{ scale: 1, opacity: 1, rotate: 0 }} exit={{ scale: 0.7, opacity: 0, rotate: 30 }} transition={{ type: 'spring', stiffness: 260, damping: 22 }}>
              <NovaWheel wedges={S.wedges} size={size} onPick={pick} hub={<div className="text-center"><div className="nv-display text-[18px]">{S.name}</div><div className="nv-mono text-[10px] text-[var(--nv-mute)]">clip.mov</div></div>} />
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ agents */

const LINES: [string, string][] = [
  ['cmd', 'anyfmt convert clip.mov --to gif --ndjson'],
  ['out', '{"event":"start","input":"clip.mov","target":"gif"}'],
  ['out', '{"event":"progress","done":0.42}'],
  ['out', '{"event":"progress","done":0.91}'],
  ['ok', '{"event":"done","output":"clip.gif","bytes":4300800}'],
]

export function Agents() {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: true, margin: '-120px' })
  const [n, setN] = useState(isShot ? LINES.length : 0)
  const [typed, setTyped] = useState(isShot ? LINES[0][1] : '')
  const [copied, setCopied] = useState(false)
  useEffect(() => {
    if (!inView || isShot) return
    let i = 0
    const t = setInterval(() => { i++; setTyped(LINES[0][1].slice(0, i)); if (i >= LINES[0][1].length) { clearInterval(t); let k = 1; const o = setInterval(() => { k++; setN(k); if (k >= LINES.length) clearInterval(o) }, 420) } }, 28)
    return () => clearInterval(t)
  }, [inView])
  const copy = async () => {
    try { await navigator.clipboard.writeText('claude mcp add anyfmt -- anyfmt mcp') } catch { /* selection fallback not needed for a demo */ }
    setCopied(true); setTimeout(() => setCopied(false), 1600)
  }
  return (
    <section id="agents" className="mx-auto grid max-w-[1240px] scroll-mt-24 items-center gap-12 px-5 py-28 sm:px-8 lg:grid-cols-[1fr_1.15fr]">
      <Rise>
        <Eyebrow>For agents</Eyebrow>
        <h2 className="nv-display text-[clamp(40px,5vw,72px)]">Your agent can<br /><span className="nv-molten-text">drop files too.</span></h2>
        <p className="mt-6 max-w-[440px] text-[17px] leading-relaxed text-[var(--nv-mute)]">{product.features[4].body}</p>
        <button onClick={copy} className="group mt-8 flex items-center gap-3 rounded-[14px] bg-white/[.04] py-2 pl-4 pr-2 text-left shadow-[inset_0_0_0_1px_var(--nv-line)] outline-none transition-colors hover:bg-white/[.07] focus-visible:ring-2 focus-visible:ring-[var(--nv-ion)]">
          <span className="nv-mono text-[13px] text-white/85"><span className="text-[var(--nv-ember)]">$</span> claude mcp add anyfmt -- anyfmt mcp</span>
          <span className="grid size-8 place-items-center rounded-[10px] bg-white/[.06]">
            <AnimatePresence mode="wait" initial={false}>
              <motion.span key={copied ? 'c' : 'k'} initial={{ scale: 0.4, opacity: 0, rotate: -45 }} animate={{ scale: 1, opacity: 1, rotate: 0 }} exit={{ scale: 0.4, opacity: 0 }} transition={{ type: 'spring', stiffness: 600, damping: 26 }}>
                {copied ? <Check size={15} className="text-[var(--nv-ion)]" /> : <Copy size={15} />}
              </motion.span>
            </AnimatePresence>
          </span>
        </button>
      </Rise>
      <Rise delay={0.1}>
        <div ref={ref} className="nv-beam overflow-hidden rounded-[22px] bg-[#07070b] shadow-[0_40px_100px_-40px_rgba(255,90,31,.4)]" style={{ ['--nv-beam-a' as string]: '#4DF0FF', ['--nv-beam-b' as string]: '#FF5A1F' }}>
          <div className="flex items-center gap-2 border-b border-white/[.06] px-4 py-3">
            {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}
            <span className="nv-mono ml-3 text-[11px] text-[var(--nv-dim)]">zsh — anyfmt</span>
          </div>
          <div className="nv-mono min-h-[250px] overflow-x-auto p-6 text-[13px] leading-[2]">
            <div className="whitespace-pre"><span className="text-[var(--nv-ember)]">❯ </span><span className="text-white">{typed}</span>{n === 0 && <span className="ml-0.5 inline-block h-4 w-2 translate-y-0.5 bg-white" style={{ animation: 'nv-caret 1s steps(1) infinite' }} />}</div>
            {LINES.slice(1, n).map(([k, l], i) => (
              <motion.div key={i} initial={{ opacity: 0, x: -6 }} animate={{ opacity: 1, x: 0 }} className="whitespace-pre" style={{ color: k === 'ok' ? 'var(--nv-ion)' : 'rgba(243,241,247,.5)' }}>{l}</motion.div>
            ))}
          </div>
        </div>
      </Rise>
    </section>
  )
}

/* ------------------------------------------------------------------ pricing */

export function Pricing() {
  const [local, pro] = product.pricing
  return (
    <section id="pricing" className="mx-auto max-w-[1240px] scroll-mt-24 px-5 py-28 sm:px-8">
      <Rise className="text-center">
        <div className="flex justify-center"><Eyebrow>Pricing</Eyebrow></div>
        <h2 className="nv-display text-[clamp(40px,5.6vw,84px)]">Free where it runs.</h2>
        <p className="mx-auto mt-5 max-w-[520px] text-[17px] text-[var(--nv-mute)]">Everything on your Mac is free, forever. Pro only adds what needs a server.</p>
      </Rise>
      <div className="mx-auto mt-16 grid max-w-[980px] gap-5 md:grid-cols-2">
        <Rise><GlowCard className="h-full p-8">
          <div className="text-[15px] text-[var(--nv-mute)]">{local.name}</div>
          <div className="mt-3 flex items-baseline gap-2"><span className="nv-display text-[72px] leading-none">{local.price}</span><span className="text-[var(--nv-dim)]">{local.period}</span></div>
          <ul className="mt-8 space-y-3.5">{local.points.map((p) => <li key={p} className="flex items-center gap-3 text-[15px]"><Check size={16} className="text-[var(--nv-ember)]" />{p}</li>)}</ul>
          <div className="mt-10"><Button variant="glass" size="lg" className="w-full" onClick={() => toast('Download starts soon', { description: 'This button is a placeholder.' })}><Download size={17} />Download for Mac</Button></div>
        </GlowCard></Rise>
        <Rise delay={0.08}>
          <div className="relative h-full">
            <motion.div aria-hidden className="absolute -inset-3 rounded-[30px] opacity-60 blur-2xl [background:var(--nv-molten)]"
              animate={isShot ? undefined : { opacity: [0.35, 0.6, 0.35] }} transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }} />
            <div className="nv-beam relative h-full overflow-hidden rounded-[22px] bg-[var(--nv-ink-1)]" style={{ ['--nv-beam-a' as string]: '#FFC24B', ['--nv-beam-b' as string]: '#4DF0FF' }}>
            <div className="relative p-8">
              <div className="flex items-center justify-between"><span className="text-[15px] text-[var(--nv-mute)]">{pro.name}</span><span className="nv-mono rounded-full bg-white/[.06] px-2.5 py-1 text-[10.5px] uppercase text-[var(--nv-solar)] shadow-[inset_0_0_0_1px_var(--nv-line-2)]">Optional</span></div>
              <div className="mt-3 flex items-baseline gap-2"><span className="nv-display nv-molten-text text-[72px] leading-none">{pro.price}</span><span className="text-[var(--nv-dim)]">{pro.period}</span></div>
              <ul className="mt-8 space-y-3.5">{pro.points.map((p) => <li key={p} className="flex items-center gap-3 text-[15px]"><Check size={16} className="text-[var(--nv-ion)]" />{p}</li>)}</ul>
              <div className="mt-10"><Button variant="molten" size="lg" className="w-full" onClick={() => toast('Pro is coming', { description: 'Local stays free either way.' })}>Get Pro<ArrowRight size={17} /></Button></div>
            </div>
            </div>
          </div>
        </Rise>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ faq */

const FAQ = [
  ['Is it really free?', 'Yes. Every conversion, tool and action runs on your Mac and is free forever, open source under the AGPL. Pro only adds things that need a server, like share links and cloud conversions for huge files.'],
  ['Does it upload my files?', 'No. anyfmt makes zero network calls unless you turn on a Pro cloud feature yourself. No account, no telemetry.'],
  ['Will it overwrite my original?', 'Never. Every result is a new file saved next to the original.'],
  ['What permissions does it need?', 'None for the wheel. Dragging works out of the box. Two optional permissions add one extra: select a file in Finder and press Return to open the wheel.'],
  ['Which Macs?', 'Apple silicon Macs on macOS 13 Ventura or later.'],
  ['Can my AI agent use it?', 'Yes. There is a real command line with JSON and NDJSON progress, plus an MCP server, so Claude and other agents can convert files locally.'],
]

export function Faq() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="mx-auto grid max-w-[1240px] gap-12 px-5 py-28 sm:px-8 lg:grid-cols-[0.8fr_1.2fr]">
      <Rise><Eyebrow>Questions</Eyebrow><h2 className="nv-display text-[clamp(40px,5vw,72px)]">Asked.<br /><span className="text-[var(--nv-dim)]">Answered.</span></h2></Rise>
      <div className="space-y-2">
        {FAQ.map(([q, a], i) => {
          const on = open === i
          return (
            <motion.div key={q} layout className={`overflow-hidden rounded-[18px] transition-colors duration-300 ${on ? 'bg-white/[.05]' : 'bg-white/[.02] hover:bg-white/[.035]'}`} style={{ boxShadow: 'inset 0 0 0 1px var(--nv-line)' }}>
              <button onClick={() => setOpen(on ? null : i)} aria-expanded={on} className="flex w-full items-center justify-between gap-6 px-6 py-5 text-left text-[17px] font-medium outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[var(--nv-ion)]">
                {q}
                <motion.span animate={{ rotate: on ? 45 : 0 }} transition={{ type: 'spring', stiffness: 500, damping: 28 }}
                  className={`grid size-8 shrink-0 place-items-center rounded-full ${on ? 'text-black [background:var(--nv-molten)]' : 'bg-white/[.06]'}`}><Plus size={16} /></motion.span>
              </button>
              <AnimatePresence initial={false}>
                {(on || isShot && i === 0) && (
                  <motion.div initial={{ height: 0, opacity: 0, filter: 'blur(4px)' }} animate={{ height: 'auto', opacity: 1, filter: 'blur(0px)' }} exit={{ height: 0, opacity: 0 }} transition={{ type: 'spring', stiffness: 260, damping: 30 }}>
                    <p className="max-w-[620px] px-6 pb-6 text-[15.5px] leading-relaxed text-[var(--nv-mute)]">{a}</p>
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
          )
        })}
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ cta + footer */

export function Cta() {
  return (
    <section className="relative mx-3 mb-3 overflow-hidden rounded-[36px] sm:mx-5">
      <Dithering className="absolute inset-0 h-full w-full" colorBack="#050507" colorFront="#FF5A1F" shape="sphere" type="4x4" size={2.5} speed={isShot ? 0 : 0.5} />
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(5,5,7,.15),rgba(5,5,7,.85)_70%)]" />
      <div className="relative flex flex-col items-center px-5 py-32 text-center sm:py-44">
        <motion.div animate={isShot ? undefined : { y: [0, -10, 0] }} transition={{ duration: 6, repeat: Infinity, ease: 'easeInOut' }}><Mark size={84} animate /></motion.div>
        <h2 className="nv-display mt-10 max-w-[900px] text-[clamp(48px,8vw,128px)]">Stop opening apps<br /><span className="nv-molten-text">to change a file.</span></h2>
        <p className="mt-6 max-w-[460px] text-[17px] text-[var(--nv-mute)]">Free, open source, and it stays on your Mac. {product.platform}.</p>
        <div className="mt-10 flex flex-wrap justify-center gap-3">
          <Button variant="molten" size="lg" beam onClick={() => toast('Download starts soon', { description: 'This button is a placeholder.' })}><Download size={18} strokeWidth={2.4} />Download for Mac</Button>
          <Button variant="glass" size="lg" onClick={() => scrollToId('play')}>Try the wheel</Button>
        </div>
      </div>
    </section>
  )
}

export function Footer() {
  const cols: [string, string[]][] = [['Product', ['How it works', 'Features', 'Pricing', 'Changelog']], ['Developers', ['Command line', 'MCP server', 'Source code', 'AGPL-3.0']], ['anyfmt', ['Privacy', 'Brand', 'Contact']]]
  return (
    <footer className="mx-auto max-w-[1240px] px-5 pb-16 pt-20 sm:px-8">
      <div className="grid gap-12 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div><Wordmark size={24} /><p className="mt-4 max-w-[280px] text-[14px] text-[var(--nv-dim)]">{product.oneLiner}</p>
          <div className="nv-mono mt-6 inline-flex items-center gap-2 rounded-full bg-white/[.04] px-3 py-1.5 text-[11px] text-[var(--nv-mute)] shadow-[inset_0_0_0_1px_var(--nv-line)]"><span className="size-1.5 animate-pulse rounded-full bg-[var(--nv-ion)]" />0 servers needed to convert</div></div>
        {cols.map(([h, ls]) => (
          <div key={h}><div className="text-[13px] font-medium text-white">{h}</div>
            <ul className="mt-4 space-y-2.5">{ls.map((l) => (
              <li key={l}><a href="#" onClick={(e) => e.preventDefault()} className="group relative text-[14px] text-[var(--nv-mute)] transition-colors hover:text-white">{l}<span className="absolute -bottom-0.5 left-0 h-px w-full origin-left scale-x-0 transition-transform duration-300 group-hover:scale-x-100 [background:var(--nv-molten)]" /></a></li>
            ))}</ul></div>
        ))}
      </div>
      <div className="mt-16 flex flex-wrap justify-between gap-4 border-t border-white/[.06] pt-6 text-[13px] text-[var(--nv-dim)]"><span>© 2026 anyfmt · Open source under AGPL-3.0</span><span>anyfmt.app</span></div>
    </footer>
  )
}
