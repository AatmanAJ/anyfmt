import { AnimatePresence, motion, useReducedMotion, useScroll, useTransform } from 'motion/react'
import {
  ArrowRight, Check, CloudOff, Cpu, Code2, Download, Lock, Minus, Plus, ShieldCheck, UserX, WifiOff,
} from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { isShot, Marquee, SpotlightCard } from '../../shared/kit'
import { product } from '../../shared/product'
import { AuraWheel } from './AuraWheel'
import { AuraDemo, DoneToast } from './Demo'
import {
  AuraKey, Eyebrow, Fit, Glow, Grain, HandArrow, K, Lockup, Mark, PaperFile, Scribble, Sticky, Ticker, WHEELS, convertSegs,
} from './ui'
import './aura.css'

const NAV = [
  { id: 'how', label: 'How it works' },
  { id: 'features', label: 'Features' },
  { id: 'agents', label: 'Agents' },
  { id: 'pricing', label: 'Pricing' },
  { id: 'faq', label: 'FAQ' },
]

const go = (id: string) => (e: React.MouseEvent) => {
  e.preventDefault()
  document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

export function Nav() {
  const [scrolled, setScrolled] = useState(false)
  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 24)
    on(); window.addEventListener('scroll', on, { passive: true })
    return () => window.removeEventListener('scroll', on)
  }, [])
  return (
    <header className="fixed inset-x-0 top-0 z-50 px-3 pt-3 md:px-6 md:pt-4">
      <nav className={cn('mx-auto flex max-w-[1180px] items-center justify-between rounded-full py-2 pl-4 pr-2 transition-all duration-500',
        scrolled ? 'aura-frost' : 'bg-transparent')} aria-label="Main">
        <a href="#" onClick={(e) => { e.preventDefault(); window.scrollTo({ top: 0, behavior: 'smooth' }) }} aria-label="anyfmt home"><Lockup size={24} /></a>
        <div className="hidden items-center gap-1 lg:flex">
          {NAV.map((n) => (
            <a key={n.id} href={`#${n.id}`} onClick={go(n.id)} className="rounded-full px-3.5 py-2 text-[14px] font-medium text-[#5B524A] transition hover:bg-white/70 hover:text-[#1E1B18]">{n.label}</a>
          ))}
        </div>
        <div className="flex items-center gap-1.5">
          <a href="#agents" onClick={go('agents')} className="hidden items-center gap-1.5 rounded-full px-3.5 py-2 text-[14px] font-medium text-[#5B524A] hover:text-[#1E1B18] sm:flex"><Code2 size={15} /> Source</a>
          <a href="#download" onClick={go('download')} className="aura-btn aura-btn-ink px-4 py-2.5 text-[14px]"><Download size={15} /> Download</a>
        </div>
      </nav>
    </header>
  )
}

/* ------------------------------------------------------------------ hero */

function Hero() {
  const ref = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const glowScale = useTransform(scrollYProgress, [0, 1], [1, reduce ? 1 : 1.35])
  const tilt = useTransform(scrollYProgress, [0, 0.5], [reduce ? 0 : 0, reduce ? 0 : -4])
  const lift = useTransform(scrollYProgress, [0, 1], [0, reduce ? 0 : -60])

  return (
    <section ref={ref} className="relative px-5 pb-16 pt-32 md:pt-40">
      <div className="mx-auto max-w-[1180px] text-center">
        <Fade><Eyebrow className="justify-center">Free · open source · for macOS</Eyebrow></Fade>
        <Fade delay={0.05}>
          <h1 className="aura-display mx-auto mt-6 max-w-[11ch] text-[clamp(56px,10.5vw,148px)] text-[#1E1B18]">
            Convert anything <span className="relative inline-block whitespace-nowrap"><em>mid-drag</em>
              <Scribble className="absolute -bottom-[0.06em] left-[2%] h-[0.16em] w-[96%]" width={400} /></span>.
          </h1>
        </Fade>
        <Fade delay={0.12}>
          <p className="mx-auto mt-7 max-w-[34rem] text-[17px] leading-[1.6] text-[#5B524A] md:text-[19px]">
            Drag a file. Press a key. A soft wheel of everything that file can become opens right under your pointer. Drop it, and you’re done.
          </p>
        </Fade>
        <Fade delay={0.18}>
          <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
            <a href="#download" onClick={go('download')} className="aura-btn aura-btn-ink px-6 py-3.5 text-[15.5px]"><Download size={17} /> Download for Mac</a>
            <a href="#how" onClick={go('how')} className="aura-btn aura-btn-soft px-6 py-3.5 text-[15.5px]">See how it works <ArrowRight size={16} /></a>
          </div>
          <p className="mt-4 text-[13px] text-[#8A7F74]">{product.platform} · No account needed</p>
        </Fade>
      </div>

      {/* Stage */}
      <motion.div className="relative mx-auto mt-16 max-w-[1100px] md:mt-20" style={{ y: lift }}>
        <motion.div className="pointer-events-none absolute inset-x-[-10%] -top-[10%] bottom-[-10%]" style={{ scale: glowScale }}>
          <Glow className="inset-0" intensity={1} />
        </motion.div>
        <motion.div className="relative" style={{ rotateX: tilt, transformPerspective: 1400 }}>
          <div className="relative overflow-hidden rounded-[34px] border border-white/80 bg-white/45 shadow-[0_40px_120px_-40px_rgba(150,80,30,.45)] backdrop-blur-[2px]">
            {/* faux Finder window top bar */}
            <div className="flex items-center gap-2 border-b border-[#1E1B18]/[.06] bg-white/60 px-5 py-3.5">
              {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}
              <span className="ml-4 text-[13px] font-medium text-[#5B524A]">Desktop</span>
            </div>
            <div className="relative grid min-h-[380px] place-items-center px-4 py-8 md:min-h-[600px] md:py-10">
              <div className="pointer-events-none absolute left-6 top-6 hidden gap-6 opacity-80 md:flex">
                <PaperFile ext="PDF" name="lease.pdf" size={40} thumb={false} />
                <PaperFile ext="HEIC" name="IMG_2041" size={40} />
              </div>
              <div className="pointer-events-none absolute bottom-6 right-6 hidden md:block opacity-80"><PaperFile ext="WAV" name="memo.wav" size={40} thumb={false} /></div>
              <Fit width={480} height={480} className="max-w-[480px]">
                <div className="grid h-full place-items-center">
                  <AuraDemo segments={convertSegs} target={0} sweep={[2, 1, 0]} size={440} />
                </div>
              </Fit>
              <Sticky className="absolute left-[4%] top-[42%] hidden lg:block" rotate={-4}>
                Hold <K>⇧</K> mid-drag. The wheel opens right where you are.
              </Sticky>
              <HandArrow className="absolute left-[19%] top-[54%] hidden rotate-[-6deg] lg:block" />
              <Sticky className="absolute right-[5%] top-[18%] hidden lg:block" rotate={3}>
                Drop on GIF. That’s it. Really.
              </Sticky>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </section>
  )
}

function Fade({ children, delay = 0, className }: { children: ReactNode; delay?: number; className?: string }) {
  const reduce = useReducedMotion()
  return (
    <motion.div className={className}
      initial={isShot ? false : { opacity: 0, y: reduce ? 0 : 16, filter: 'blur(6px)' }}
      animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
      transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1], delay: 0.1 + delay }}>
      {children}
    </motion.div>
  )
}

/** Scroll-in reveal (shot-safe). */
export function In({ children, delay = 0, className, y = 22 }: { children: ReactNode; delay?: number; className?: string; y?: number }) {
  const reduce = useReducedMotion()
  if (isShot) return <div className={className}>{children}</div>
  return (
    <motion.div className={className}
      initial={{ opacity: 0, y: reduce ? 0 : y, filter: reduce ? 'none' : 'blur(8px)' }}
      whileInView={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
      viewport={{ once: true, margin: '-70px' }}
      transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1], delay }}>
      {children}
    </motion.div>
  )
}

function SectionHead({ eyebrow, title, body, center }: { eyebrow: string; title: ReactNode; body?: ReactNode; center?: boolean }) {
  return (
    <In className={cn('max-w-[760px]', center && 'mx-auto text-center')}>
      <Eyebrow className={cn(center && 'justify-center')}>{eyebrow}</Eyebrow>
      <h2 className="aura-display mt-5 text-[clamp(42px,6.4vw,84px)] text-[#1E1B18]">{title}</h2>
      {body && <p className={cn('mt-5 max-w-[36rem] text-[17px] leading-[1.6] text-[#5B524A]', center && 'mx-auto')}>{body}</p>}
    </In>
  )
}

/* ------------------------------------------------------------------ marquee */

function Formats() {
  const half = Math.ceil(product.conversions.length / 2)
  const row = (items: readonly string[]) => items.map((c) => {
    const [a, b] = c.split(/ ?[→←] ?/)
    const arrow = c.includes('←') ? '←' : '→'
    return (
      <span key={c} className="flex shrink-0 items-center gap-3 rounded-full bg-white px-5 py-3 text-[15px] font-semibold text-[#1E1B18] shadow-[0_0_0_1px_rgba(30,27,24,.05),0_10px_24px_-14px_rgba(120,70,30,.35)]">
        {a}<span className="aura-em aura-serif text-[20px] font-normal leading-none text-[#B04E1B]">{arrow}</span>{b}
      </span>
    )
  })
  return (
    <section className="relative py-10" aria-label="Formats">
      <p className="mb-6 text-center text-[13px] font-medium text-[#8A7F74]">{product.stats[0].value} {product.stats[0].label}. A few favourites:</p>
      <div className="space-y-3">
        <Marquee className="gap-3" duration={46}>{row(product.conversions.slice(0, half))}</Marquee>
        <Marquee className="gap-3" duration={52} reverse>{row(product.conversions.slice(half))}</Marquee>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ how it works */

const RESULT = [
  (l: string) => ({ name: `clip.${l.toLowerCase()}`, meta: 'saved next to clip.mov' }),
  (l: string) => ({ name: 'shot.png', meta: `${l} done · saved as a new copy` }),
  (l: string) => ({ name: '3 files', meta: l === 'Float' ? 'resting on your Float shelf' : `${l} · done` }),
]

export function HowItWorks() {
  const [k, setK] = useState(0)
  const [picked, setPicked] = useState<string | null>(null)
  const [pressed, setPressed] = useState<number | null>(null)
  useEffect(() => {
    const map: Record<string, number> = { Shift: 0, Meta: 1, Control: 2 }
    const down = (e: KeyboardEvent) => { if (e.key in map) { setK(map[e.key]); setPressed(map[e.key]); setPicked(null) } }
    const up = () => setPressed(null)
    window.addEventListener('keydown', down); window.addEventListener('keyup', up)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up) }
  }, [])
  useEffect(() => { if (!picked) return; const t = setTimeout(() => setPicked(null), 2600); return () => clearTimeout(t) }, [picked])
  const w = WHEELS[k]
  const res = picked ? RESULT[k](picked) : null

  return (
    <section id="how" className="relative scroll-mt-24 px-5 py-24 md:py-32">
      <div className="mx-auto max-w-[1180px]">
        <SectionHead eyebrow="How it works" title={<>Three keys. <em>Three</em> wheels.</>}
          body="You already know the gesture: pick something up, put it somewhere. anyfmt just adds one key in the middle, and the right wheel opens." />

        <div className="mt-16 grid grid-cols-1 items-center gap-12 lg:grid-cols-[0.9fr_1.1fr]">
          <div className="space-y-3">
            {WHEELS.map((x, i) => (
              <button key={x.wheel} type="button" onClick={() => { setK(i); setPicked(null) }}
                className={cn('group flex w-full items-center gap-5 rounded-[26px] p-4 text-left transition-all duration-300',
                  k === i ? 'aura-card' : 'hover:bg-white/60')}>
                <AuraKey symbol={x.key} label={x.name.toLowerCase()} pressed={pressed === i} active={k === i} />
                <span className="flex-1">
                  <span className="aura-serif block text-[28px] leading-none text-[#1E1B18]" style={{ fontWeight: 420 }}>{x.wheel}</span>
                  <span className="mt-1.5 block text-[15px] text-[#5B524A]">{x.blurb}</span>
                </span>
                <ArrowRight size={18} className={cn('shrink-0 text-[#B04E1B] transition', k === i ? 'translate-x-0 opacity-100' : '-translate-x-2 opacity-0 group-hover:opacity-60')} />
              </button>
            ))}
            <p className="aura-hand pl-4 pt-3 text-[17px] text-[#B04E1B]">psst: press <K>⇧</K> <K>⌘</K> or <K>⌃</K> on your keyboard, then click a wedge.</p>
          </div>

          <div className="relative grid place-items-center">
            <Glow className="inset-[-8%]" intensity={0.9} />
            <Fit width={460} height={460} className="max-w-[460px]">
              <div className="grid h-full place-items-center">
                <AnimatePresence mode="wait">
                  <motion.div key={w.wheel} initial={isShot ? false : { opacity: 0, scale: 0.9, rotate: -8 }} animate={{ opacity: 1, scale: 1, rotate: 0 }}
                    exit={{ opacity: 0, scale: 0.92, rotate: 6 }} transition={{ type: 'spring', stiffness: 260, damping: 24 }}>
                    <AuraWheel segments={w.segs} size={420} tone={w.tone} onPick={(s) => setPicked(s.label)}
                      {...(isShot ? { hoverIndex: 0 } : {})}
                      hubLabel={<span className="aura-serif text-[15px] italic text-[#5B524A]">{w.wheel}</span>}
                      hubSub={<span className="mt-0.5 text-[11.5px] font-semibold">{k === 0 ? 'clip.mov' : k === 1 ? 'shot.png' : '3 files'}</span>} />
                  </motion.div>
                </AnimatePresence>
              </div>
            </Fit>
            <div className="absolute bottom-[-8px] left-1/2 h-14 -translate-x-1/2">
              <AnimatePresence>
                {res && (
                  <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }}>
                    <DoneToast name={res.name} meta={res.meta} action="" />
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ bento */

function Bento() {
  const f = product.features
  const Card = ({ className, children, i }: { className?: string; children: ReactNode; i: number }) => (
    <In delay={i * 0.05} className={className}>
      <SpotlightCard className="aura-card h-full" color="rgba(255,178,122,.22)">
        <div className="relative flex h-full flex-col p-7 md:p-8">{children}</div>
      </SpotlightCard>
    </In>
  )
  const H = ({ t, b }: { t: string; b: string }) => (
    <div className="mt-auto pt-6">
      <h3 className="aura-serif text-[30px] leading-none text-[#1E1B18]" style={{ fontWeight: 430 }}>{t}</h3>
      <p className="mt-2.5 max-w-[30rem] text-[15px] leading-[1.55] text-[#5B524A]">{b}</p>
    </div>
  )
  return (
    <section id="features" className="relative scroll-mt-24 px-5 py-24 md:py-32">
      <div className="mx-auto max-w-[1180px]">
        <SectionHead eyebrow="What’s inside" title={<>A power tool that’s <em>nice</em> to you.</>} />
        <div className="mt-14 grid grid-cols-1 auto-rows-[minmax(300px,auto)] gap-5 md:grid-cols-6">
          <Card i={0} className="md:col-span-4">
            <div className="relative -mx-2 flex flex-wrap gap-2">
              {[...product.formatsVideo, ...product.formatsImage.filter((x) => !product.formatsVideo.includes(x as never)), 'MP3', 'DOCX', 'EPUB', 'FLAC', 'SVG', 'ZIP'].slice(0, 22).map((x, i) => (
                <span key={x + i} className={cn('rounded-full px-3 py-1.5 text-[13px] font-semibold',
                  i === 0 ? 'bg-gradient-to-br from-[#FFD9BC] to-[#FFB27A] text-[#1E1B18] shadow-[0_0_20px_rgba(255,160,100,.55)]' : 'bg-[#F1EADF] text-[#5B524A]')}>{x}</span>
              ))}
            </div>
            <H t={f[0].title} b={f[0].body} />
          </Card>
          <Card i={1} className="md:col-span-2">
            <div className="relative mx-auto mt-2 h-[120px] w-[170px] overflow-hidden rounded-[14px]"
                 style={{ background: 'radial-gradient(circle at 70% 30%, #FFE2C2, transparent 60%), linear-gradient(160deg,#FFC79C,#9DB4FF)' }}>
              <div className="absolute inset-[16px_26px_22px_18px] rounded-[6px] border-2 border-white shadow-[0_0_0_999px_rgba(251,247,240,.55)]" />
              {[[18, 16], [144, 16], [18, 98], [144, 98]].map(([x, y]) => <span key={`${x}${y}`} className="absolute size-2.5 rounded-full border-2 border-[#1E1B18] bg-white" style={{ left: x - 5, top: y - 5 }} />)}
            </div>
            <H t={f[1].title} b={f[1].body} />
          </Card>
          <Card i={2} className="md:col-span-2">
            <div className="flex flex-wrap gap-2">
              {WHEELS[2].segs.map((s) => (
                <span key={s.id} className="flex items-center gap-1.5 rounded-full bg-[#F1EADF] px-3 py-1.5 text-[13px] font-medium text-[#1E1B18]">{s.icon}{s.label}</span>
              ))}
            </div>
            <H t={f[2].title} b={f[2].body} />
          </Card>
          <Card i={3} className="md:col-span-2">
            <div className="flex items-center gap-2">
              {['10', '15', '24', '30'].map((x) => (
                <span key={x} className={cn('rounded-[14px] px-3 py-2 text-center text-[14px] font-semibold', x === '15' ? 'bg-gradient-to-b from-[#FFE9D6] to-[#FFCBA2] shadow-[0_0_0_1px_rgba(255,150,90,.5),0_8px_18px_-8px_rgba(255,140,80,.7)]' : 'bg-[#F1EADF] text-[#5B524A]')}>
                  {x}<span className="block text-[10px] font-medium opacity-70">fps</span>
                </span>
              ))}
            </div>
            <Sticky className="absolute right-6 top-6 text-[13px]" rotate={5}>your usual</Sticky>
            <H t={f[3].title} b={f[3].body} />
          </Card>
          <Card i={4} className="md:col-span-2">
            <div className="rounded-[16px] bg-[#1E1B18] p-4 font-mono text-[12px] leading-[1.7] text-[#EDE3D6]">
              <div><span className="text-[#FFB27A]">❯</span> anyfmt convert clip.mov --to gif --json</div>
              <div className="text-[#9DB4FF]">{'{"ok":true,"out":"clip.gif"}'}</div>
            </div>
            <H t={f[4].title} b={f[4].body} />
          </Card>
          <Card i={5} className="md:col-span-6">
            <div className="grid grid-cols-1 items-center gap-8 md:grid-cols-[1fr_auto]">
              <div>
                <div className="flex flex-wrap gap-2">
                  {[{ i: UserX, t: 'No account' }, { i: CloudOff, t: 'No upload' }, { i: WifiOff, t: 'No telemetry' }].map(({ i: I, t }) => (
                    <span key={t} className="flex items-center gap-2 rounded-full bg-[#F1EADF] px-3.5 py-2 text-[13.5px] font-medium text-[#1E1B18]"><I size={15} className="text-[#B04E1B]" />{t}</span>
                  ))}
                </div>
                <H t={f[5].title} b={f[5].body} />
              </div>
              <div className="hidden items-end gap-3 pr-4 md:flex">
                <span className="aura-display text-[150px] leading-[.78] text-[#1E1B18]">0</span>
                <span className="aura-hand pb-2 text-[20px] leading-[1.1] text-[#B04E1B]">network calls,<br />unless you ask</span>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ stats */

function Stats() {
  return (
    <section className="relative px-5 py-20">
      <div className="relative mx-auto max-w-[1180px]">
      <Glow className="inset-x-[10%] inset-y-[-30%]" intensity={0.45} />
      <div className="aura-card relative grid grid-cols-1 gap-px overflow-hidden bg-[#1E1B18]/[.06] sm:grid-cols-2 lg:grid-cols-4">
        {product.stats.map((s, i) => (
          <In key={s.label} delay={i * 0.06} className="bg-white p-8 md:p-10">
            <div className="aura-display text-[clamp(64px,7vw,96px)] text-[#1E1B18]"><Ticker value={s.value} /></div>
            <p className="mt-3 max-w-[14rem] text-[15px] leading-[1.5] text-[#5B524A]">{s.label}</p>
          </In>
        ))}
      </div>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ privacy */

function Privacy() {
  const files = ['HEIC', 'MOV', 'PDF', 'WAV', 'PNG', 'DOCX']
  return (
    <section className="relative px-5 py-24 md:py-32">
      <div className="relative mx-auto max-w-[1180px] overflow-hidden rounded-[40px] bg-[#F1EADF] px-6 py-16 md:px-16 md:py-24">
        <Grain />
        <div className="relative grid grid-cols-1 items-center gap-14 lg:grid-cols-2">
          <div>
            <Eyebrow>Private by default</Eyebrow>
            <h2 className="aura-display mt-5 text-[clamp(42px,6vw,80px)] text-[#1E1B18]">Your files never leave the <em>room</em>.</h2>
            <p className="mt-6 max-w-[30rem] text-[17px] leading-[1.6] text-[#5B524A]">
              Every conversion runs on your Mac, with your Mac’s own muscles. There’s no account to make, nothing to upload, and nothing quietly phoning home.
              Pro’s cloud features are there if you switch them on, and not before.
            </p>
            <ul className="mt-8 grid grid-cols-1 gap-3 sm:grid-cols-2">
              {[{ i: Cpu, t: 'Runs on Apple silicon' }, { i: ShieldCheck, t: 'Open source, AGPL-3.0' }, { i: Lock, t: 'One permission, explained' }, { i: WifiOff, t: '0 network calls by default' }].map(({ i: I, t }) => (
                <li key={t} className="flex items-center gap-3 text-[15px] font-medium text-[#1E1B18]"><span className="grid size-9 place-items-center rounded-full bg-white shadow-[0_6px_14px_-8px_rgba(120,70,30,.4)]"><I size={16} className="text-[#B04E1B]" /></span>{t}</li>
              ))}
            </ul>
          </div>
          <div className="relative mx-auto grid aspect-square w-full max-w-[460px] place-items-center">
            <Glow className="inset-[8%]" intensity={0.8} />
            <div className="absolute inset-[6%] rounded-full border border-dashed border-[#1E1B18]/15" />
            <div className="aura-spin-slow absolute inset-[6%]">
              {files.map((f, i) => {
                const a = (i / files.length) * Math.PI * 2
                return (
                  <div key={f} className="absolute -translate-x-1/2 -translate-y-1/2" style={{ left: `${50 + 50 * Math.sin(a)}%`, top: `${50 - 50 * Math.cos(a)}%` }}>
                    <div className="aura-spin-slow-rev"><PaperFile ext={f} size={34} thumb={i % 2 === 0} /></div>
                  </div>
                )
              })}
            </div>
            <div className="relative grid place-items-center">
              <div className="aura-card grid h-[110px] w-[150px] place-items-center rounded-[20px] sm:h-[150px] sm:w-[210px] sm:rounded-[22px]">
                <div className="flex flex-col items-center gap-2"><Mark size={44} /><span className="text-[13px] font-semibold text-[#1E1B18]">Your Mac</span></div>
              </div>
              <div className="mx-auto h-3 w-[90px] rounded-b-[10px] bg-[#E2D7C8] sm:w-[120px]" />
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ agents */

function Agents() {
  const lines: { t: ReactNode; c?: string }[] = [
    { t: <><span className="text-[#FFB27A]">~/Desktop ❯</span> anyfmt convert clip.mov --to gif --json</> },
    { t: '{"event":"progress","pct":0.31,"stage":"encode"}', c: 'text-[#A79C8F]' },
    { t: '{"event":"progress","pct":0.78,"stage":"encode"}', c: 'text-[#A79C8F]' },
    { t: <><span className="text-[#9DB4FF]">{'{'}</span>"ok":<span className="text-[#FFB27A]">true</span>,"input":"clip.mov","output":"clip.gif",</> },
    { t: <>&nbsp;"route":["mov","gif"],"bytes":<span className="text-[#FFB27A]">2516582</span>,"network":<span className="text-[#FFB27A]">false</span><span className="text-[#9DB4FF]">{'}'}</span></> },
  ]
  return (
    <section id="agents" className="relative scroll-mt-24 px-5 py-24 md:py-32">
      <div className="mx-auto grid max-w-[1180px] grid-cols-1 items-center gap-14 lg:grid-cols-[1fr_1.15fr]">
        <div>
          <Eyebrow>For agents</Eyebrow>
          <h2 className="aura-display mt-5 text-[clamp(42px,6vw,80px)] text-[#1E1B18]">Your agents can drag files <em>too</em>.</h2>
          <p className="mt-6 max-w-[30rem] text-[17px] leading-[1.6] text-[#5B524A]">{product.features[4].body} Same engine as the wheel, so whatever you can drop, a script can ask for.</p>
          <div className="mt-8 flex flex-wrap gap-2">
            {['--json', 'NDJSON progress', 'MCP server', 'exit codes that mean things'].map((x) => (
              <span key={x} className="rounded-full bg-white px-3.5 py-2 font-mono text-[12.5px] text-[#1E1B18] shadow-[0_0_0_1px_rgba(30,27,24,.06)]">{x}</span>
            ))}
          </div>
        </div>
        <In className="relative">
          <Glow className="inset-[-12%]" intensity={0.7} />
          <div className="relative overflow-hidden rounded-[26px] bg-[#1E1B18] shadow-[0_50px_100px_-40px_rgba(80,40,10,.7)]">
            <div className="flex items-center gap-2 border-b border-white/[.06] px-5 py-3.5">
              {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full opacity-90" style={{ background: c }} />)}
              <span className="ml-3 font-mono text-[12px] text-[#A79C8F]">zsh — halo</span>
            </div>
            <div className="overflow-x-auto p-6 font-mono text-[12.5px] leading-[1.9] text-[#EDE3D6] md:p-8 md:text-[13.5px]">
              {lines.map((l, i) => <div key={i} className={cn('whitespace-pre', l.c)}>{l.t}</div>)}
              <div className="mt-1"><span className="text-[#FFB27A]">~/Desktop ❯</span> <span className="inline-block h-[1.1em] w-[.55em] translate-y-[3px] animate-pulse bg-[#FFB27A]" /></div>
            </div>
          </div>
          <Sticky className="absolute -bottom-6 -right-2 md:-right-6" rotate={-4}>"network": false. We check.</Sticky>
        </In>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ pricing */

function Pricing() {
  return (
    <section id="pricing" className="relative scroll-mt-24 px-5 py-24 md:py-32">
      <div className="mx-auto max-w-[1000px]">
        <SectionHead center eyebrow="Pricing" title={<>Free, and <em>meant</em> it.</>} body={product.licence} />
        <div className="mt-14 grid grid-cols-1 gap-5 md:grid-cols-2">
          {product.pricing.map((p, i) => {
            const pro = i === 1
            return (
              <In key={p.name} delay={i * 0.08} className="relative">
                {pro && <Glow className="inset-[-6%]" intensity={0.55} />}
                <div className={cn('aura-card relative flex h-full flex-col p-8 md:p-10', pro && 'bg-[linear-gradient(180deg,#FFFFFF,#FFF6EE)]')}>
                  <div className="flex items-center justify-between">
                    <h3 className="aura-serif text-[28px] text-[#1E1B18]" style={{ fontWeight: 450 }}>{p.name}</h3>
                    {pro ? <span className="rounded-full bg-[#1E1B18] px-3 py-1 text-[12px] font-semibold text-[#FFF8F0]">Optional</span>
                      : <span className="rounded-full bg-[#F1EADF] px-3 py-1 text-[12px] font-semibold text-[#5B524A]">Most people</span>}
                  </div>
                  <div className="mt-6 flex items-baseline gap-2">
                    <span className="aura-display text-[84px] text-[#1E1B18]">{p.price}</span>
                    <span className="text-[16px] text-[#5B524A]">{p.period}</span>
                  </div>
                  <ul className="mt-6 space-y-3">
                    {p.points.map((x) => (
                      <li key={x} className="flex items-start gap-3 text-[15.5px] text-[#1E1B18]">
                        <span className={cn('mt-0.5 grid size-5 shrink-0 place-items-center rounded-full', pro ? 'bg-gradient-to-br from-[#FFD2AE] to-[#FFA868]' : 'bg-[#F1EADF]')}><Check size={12} strokeWidth={3} /></span>{x}
                      </li>
                    ))}
                  </ul>
                  <div className="mt-auto pt-9">
                    <a href="#download" onClick={go('download')} className={cn('aura-btn w-full justify-center px-5 py-3.5 text-[15px]', pro ? 'aura-btn-ink' : 'aura-btn-soft')}>
                      {pro ? 'Add Pro later, from the app' : 'Download anyfmt'}
                    </a>
                  </div>
                </div>
              </In>
            )
          })}
        </div>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ faq */

const FAQ = [
  { q: 'Is anyfmt really free?', a: 'Yes. Every local feature, all 793 conversions, 26 tools and 6 actions, plus the CLI and MCP server, is free and open source under AGPL-3.0. Pro only covers things that genuinely need a server.' },
  { q: 'Does anything leave my Mac?', a: 'No. anyfmt makes zero network calls unless you ask for a Pro cloud feature. No account, no upload, no telemetry.' },
  { q: 'Which Macs does it run on?', a: 'macOS 13 or later, on Apple silicon.' },
  { q: 'Why does it want Accessibility permission?', a: 'So it can notice ⇧ ⌘ or ⌃ while you’re mid-drag. That’s the only thing it’s used for, and setup shows you exactly where the switch is.' },
  { q: 'Can Claude or my scripts use it?', a: 'Yes. There’s a real CLI with JSON and NDJSON progress, and an MCP server, so an agent can convert your files on your Mac.' },
  { q: 'What if I don’t like the keys?', a: 'Pick different ones during setup, or change them any time in Settings. The wheels don’t mind.' },
]

function Faq() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="relative scroll-mt-24 px-5 py-24 md:py-32">
      <div className="mx-auto grid max-w-[1180px] grid-cols-1 gap-12 lg:grid-cols-[0.8fr_1.2fr]">
        <div>
          <SectionHead eyebrow="Questions" title={<>Fair <em>questions</em>.</>} />
          <Sticky className="mt-10 hidden lg:block" rotate={-3}>Still stuck? The source is open. Have a look around.</Sticky>
        </div>
        <div className="space-y-3">
          {FAQ.map((f, i) => {
            const on = open === i
            return (
              <div key={f.q} className={cn('rounded-[24px] transition-all duration-300', on ? 'aura-card' : 'bg-white/50 shadow-[0_0_0_1px_rgba(30,27,24,.05)]')}>
                <button type="button" aria-expanded={on} onClick={() => setOpen(on ? null : i)} className="flex w-full items-center justify-between gap-6 px-6 py-5 text-left md:px-7">
                  <span className="aura-serif text-[20px] text-[#1E1B18] md:text-[22px]" style={{ fontWeight: 430 }}>{f.q}</span>
                  <span className={cn('grid size-9 shrink-0 place-items-center rounded-full transition-all duration-300', on ? 'rotate-180 bg-gradient-to-br from-[#FFD2AE] to-[#FFA868] shadow-[0_0_16px_rgba(255,160,100,.5)]' : 'bg-[#F1EADF]')}>
                    {on ? <Minus size={16} /> : <Plus size={16} />}
                  </span>
                </button>
                <AnimatePresence initial={false}>
                  {on && (
                    <motion.div initial={isShot ? false : { height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }} className="overflow-hidden">
                      <p className="max-w-[40rem] px-6 pb-6 text-[16px] leading-[1.6] text-[#5B524A] md:px-7">{f.a}</p>
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

/* ------------------------------------------------------------------ final CTA + footer */

function FinalCta() {
  return (
    <section id="download" className="relative scroll-mt-24 overflow-hidden px-5 pb-28 pt-24 md:pb-40 md:pt-36">
      <Glow className="left-1/2 top-1/2 h-[720px] w-[min(1100px,140vw)] -translate-x-1/2 -translate-y-1/2" intensity={1} />
      <div className="relative mx-auto max-w-[900px] text-center">
        <In><div className="mx-auto grid size-28 place-items-center"><div className="aura-breathe absolute size-40 rounded-full bg-[#FFB27A]/50 blur-3xl" /><Mark size={96} /></div></In>
        <In delay={0.05}>
          <h2 className="aura-display mt-8 text-[clamp(56px,9.5vw,136px)] text-[#1E1B18]">Go on, drag <span className="relative inline-block"><em>something</em><Scribble className="absolute -bottom-[0.04em] left-0 h-[0.14em] w-full" width={500} variant={2} /></span>.</h2>
        </In>
        <In delay={0.1}>
          <p className="mx-auto mt-7 max-w-[30rem] text-[17px] leading-[1.6] text-[#5B524A]">Two minutes to set up. Then it stays out of your way until you pick something up.</p>
          <div className="mt-9 flex flex-wrap justify-center gap-3">
            <a href="#download" onClick={(e) => e.preventDefault()} className="aura-btn aura-btn-ink px-7 py-4 text-[16px]"><Download size={18} /> Download for Mac</a>
            <a href="#agents" onClick={go('agents')} className="aura-btn aura-btn-soft px-7 py-4 text-[16px]"><Code2 size={17} /> Read the source</a>
          </div>
          <p className="mt-4 text-[13px] text-[#8A7F74]">{product.platform}</p>
        </In>
      </div>
    </section>
  )
}

function Footer() {
  const cols = [
    { h: 'Product', l: ['How it works', 'Features', 'Pricing', 'Changelog'] },
    { h: 'Developers', l: ['CLI', 'MCP server', 'Source', 'Licence'] },
    { h: 'Help', l: ['FAQ', 'Permissions', 'Contact'] },
  ]
  return (
    <footer className="relative border-t border-[#1E1B18]/[.07] px-5 pb-28 pt-16">
      <div className="mx-auto grid grid-cols-1 max-w-[1180px] gap-12 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div>
          <Lockup size={28} />
          <p className="mt-4 max-w-[18rem] text-[14.5px] leading-[1.6] text-[#5B524A]">{product.oneLiner}</p>
          <p className="aura-hand mt-4 text-[16px] text-[#B04E1B]">Made with care, and a lot of test files.</p>
        </div>
        {cols.map((c) => (
          <div key={c.h}>
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">{c.h}</div>
            <ul className="mt-4 space-y-2.5">
              {c.l.map((x) => <li key={x}><a href="#" onClick={(e) => e.preventDefault()} className="aura-link text-[14.5px] text-[#1E1B18]">{x}</a></li>)}
            </ul>
          </div>
        ))}
      </div>
      <div className="mx-auto mt-14 flex max-w-[1180px] flex-wrap items-center justify-between gap-3 text-[13px] text-[#8A7F74]">
        <span>© 2026 anyfmt · Open source, AGPL-3.0</span>
        <span>{product.platform}</span>
      </div>
    </footer>
  )
}

/* ------------------------------------------------------------------ page */

export { Hero, Bento, Agents, Pricing, Stats }

export default function Landing() {
  return (
    <div className="aura-root relative min-h-screen">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-[1400px] overflow-hidden" aria-hidden>
        <div className="absolute left-1/2 top-[-380px] h-[900px] w-[1400px] -translate-x-1/2 rounded-full opacity-60"
             style={{ background: 'radial-gradient(closest-side, rgba(255,214,180,.8), rgba(251,247,240,0))' }} />
      </div>
      <Grain className="fixed z-[1]" />
      <Nav />
      <main className="relative z-[2]">
        <Hero />
        <Formats />
        <HowItWorks />
        <Bento />
        <Stats />
        <Privacy />
        <Agents />
        <Pricing />
        <Faq />
        <FinalCta />
      </main>
      <div className="relative z-[2]"><Footer /></div>
    </div>
  )
}
