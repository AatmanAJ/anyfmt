/**
 * anyfmt landing page in the illustrated hero style of Elaya's landing pages, built to the
 * `landing-page-design` and `design-to-motion` skills (github.com/elayadesign/ai-design-skills).
 *
 * Visual system (skill Part B): Geist only (Geist Mono for data), Tailwind type scale, spacing on
 * the 2/4/8/12/16/24/32/40/48/64/80/96 steps, flat dark surfaces, gradient only on the hero heading
 * text, Phosphor icons, base curve cubic-bezier(0.22,1,0.36,1). Art generated with Higgsfield.
 */

import '@fontsource-variable/geist-mono'
import {
  AppleLogo, ArrowRight, ArrowUpRight, Check, CloudSlash, Command, Copy, FolderSimple, GithubLogo, Minus, Plus, Stack, WifiSlash,
} from '@phosphor-icons/react'
import { AnimatePresence, motion, useInView, useReducedMotion, useScroll, useTransform, type MotionValue } from 'motion/react'
import { Fragment, useEffect, useRef, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import hero from './art/hero.webp'
import lost from './art/lost.webp'
import night from './art/night.webp'
import step1 from './art/step1.webp'
import step2 from './art/step2.webp'
import step3 from './art/step3.webp'

const EASE = [0.22, 1, 0.36, 1] as const
const BG = '#131209'

/* ───────────────────────────── shared ───────────────────────────── */

function Shell({ children }: { children: ReactNode }) {
  useEffect(() => { document.documentElement.style.background = BG; return () => { document.documentElement.style.background = '' } }, [])
  return (
    <div className="min-h-screen bg-[#131209] font-['Geist_Variable',ui-sans-serif,system-ui,sans-serif] text-white antialiased [font-synthesis:none]">
      <a href="#main" onClick={(e) => { e.preventDefault(); document.getElementById('main')?.focus() }}
        className="fixed left-4 top-4 z-[100] -translate-y-24 rounded-full bg-white px-4 py-2 text-sm font-semibold text-black transition-transform duration-300 focus:translate-y-0">Skip to content</a>
      {children}
    </div>
  )
}

const scrollTo = (id: string) => document.getElementById(id)?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' })

const DOWNLOAD = 'https://anyfmt.app'

function PrimaryButton({ children = 'Download for Mac', className = '' }: { children?: ReactNode; className?: string }) {
  return (
    <a href={DOWNLOAD} className={`group inline-flex items-center gap-2 rounded-full bg-white py-2 pl-4 pr-3 text-base font-semibold text-black outline-none transition-[transform,background-color] duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] hover:bg-[#E9E9E9] active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-[#131209] ${className}`}>
      <AppleLogo size={18} weight="fill" />
      {children}
      <span className="flex h-6 w-6 items-center justify-center rounded-full bg-black text-white transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:translate-x-0.5"><ArrowRight size={14} weight="bold" /></span>
    </a>
  )
}

function QuietButton({ children, onClick }: { children: ReactNode; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick}
      className="group inline-flex items-center gap-2 rounded-full bg-white/10 px-4 py-2 text-base font-semibold text-white outline-none backdrop-blur-md transition-[transform,background-color] duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] hover:bg-white/20 active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-white">
      {children}
      <ArrowRight size={16} weight="bold" className="transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:translate-x-0.5" />
    </button>
  )
}

/** Section scroll reveal (landing-page-design B7): rise 32px, fade, once. */
function Reveal({ children, className = '', delay = 0 }: { children: ReactNode; className?: string; delay?: number }) {
  const reduce = useReducedMotion()
  return (
    <motion.div className={className} initial={reduce ? { opacity: 0 } : { opacity: 0, y: 32 }} whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.25 }} transition={{ duration: 0.7, ease: EASE, delay }}>
      {children}
    </motion.div>
  )
}

/** Story clock (design-to-motion B4): seconds since the visual came on screen, paused off screen. */
function useStoryClock(ref: React.RefObject<Element | null>, period: number) {
  const inView = useInView(ref, { amount: 0.3 })
  const reduce = useReducedMotion()
  const [t, setT] = useState(0)
  const acc = useRef(0)
  useEffect(() => {
    if (!inView || reduce) return
    let raf = 0, last = performance.now()
    const tick = (now: number) => {
      acc.current = (acc.current + (now - last) / 1000) % period
      last = now
      setT(acc.current)
      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [inView, reduce, period])
  return { t, started: inView || !!reduce, reduce: !!reduce }
}

/* ───────────────────────────── Nav ───────────────────────────── */

const LINKS: [string, string][] = [['How it works', 'how'], ['Features', 'features'], ['FAQ', 'faq']]

function Mark() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" aria-hidden>
      {Array.from({ length: 8 }, (_, i) => {
        const a = (i / 8) * Math.PI * 2 - Math.PI / 2, r = i === 1 ? 10.4 : 8
        return <circle key={i} cx={12 + Math.cos(a) * r} cy={12 + Math.sin(a) * r} r={2} fill={i === 1 ? '#F08A4B' : 'currentColor'} />
      })}
    </svg>
  )
}

function Nav() {
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState('')
  useEffect(() => {
    const io = new IntersectionObserver((es) => es.forEach((e) => e.isIntersecting && setActive(e.target.id)), { rootMargin: '-45% 0px -50% 0px' })
    LINKS.forEach(([, id]) => { const el = document.getElementById(id); if (el) io.observe(el) })
    return () => io.disconnect()
  }, [])
  useEffect(() => { document.body.style.overflow = open ? 'hidden' : ''; return () => { document.body.style.overflow = '' } }, [open])
  const go = (id: string) => { setOpen(false); scrollTo(id) }
  return (
    <>
      <motion.header initial={{ opacity: 0, y: -6, filter: 'blur(2px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} transition={{ duration: 0.6, ease: EASE }}
        className="fixed inset-x-0 top-4 z-50 flex justify-center px-4">
        <nav aria-label="Main" className="flex items-center gap-2 rounded-full bg-[#131209]/60 p-2 pl-4 ring-1 ring-white/10 backdrop-blur-xl">
          <Link to="/elaya" className="mr-2 flex items-center gap-2 text-base font-semibold"><Mark />anyfmt</Link>
          <div className="hidden items-center md:flex">
            {LINKS.map(([l, id]) => (
              <button key={id} type="button" onClick={() => go(id)} aria-current={active === id ? 'true' : undefined}
                className={`relative rounded-full px-3 py-2 text-sm font-medium outline-none transition-colors duration-300 focus-visible:ring-2 focus-visible:ring-white ${active === id ? 'text-white' : 'text-white/60 hover:text-white'}`}>
                {active === id && <motion.span layoutId="nav-active" className="absolute inset-0 rounded-full bg-white/10" transition={{ duration: 0.5, ease: EASE }} />}
                <span className="relative">{l}</span>
              </button>
            ))}
          </div>
          <a href={DOWNLOAD} className="hidden rounded-full bg-white px-4 py-2 text-sm font-semibold text-black transition-[transform,background-color] duration-300 hover:bg-[#E9E9E9] active:scale-[0.98] sm:block">Download</a>
          <button type="button" aria-label={open ? 'Close menu' : 'Open menu'} aria-expanded={open} onClick={() => setOpen((o) => !o)}
            className="relative flex h-10 w-10 items-center justify-center rounded-full bg-white/10 outline-none focus-visible:ring-2 focus-visible:ring-white md:hidden">
            <span className="absolute h-0.5 w-4 rounded-full bg-white transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)]" style={{ transform: open ? 'rotate(45deg)' : 'translateY(-4px)' }} />
            <span className="absolute h-0.5 w-4 rounded-full bg-white transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)]" style={{ transform: open ? 'rotate(-45deg)' : 'translateY(4px)' }} />
          </button>
        </nav>
      </motion.header>
      <AnimatePresence>
        {open && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.3, ease: EASE }}
            className="fixed inset-0 z-40 flex flex-col justify-center gap-2 bg-[#131209]/90 px-8 backdrop-blur-2xl md:hidden">
            {[...LINKS, ['Download', 'download'] as [string, string]].map(([l, id], i) => (
              <motion.button key={id} type="button" initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, ease: EASE, delay: Math.min(i * 0.06, 0.4) }}
                onClick={() => (id === 'download' ? (window.location.href = DOWNLOAD) : go(id))} className="py-2 text-left text-4xl font-semibold">{l}</motion.button>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </>
  )
}

/* ───────────────────────────── Hero ───────────────────────────── */

/** design-to-motion hero appear: each element rises 6px from a 2px blur, 60ms apart. */
const appear = (i: number) => ({
  initial: { opacity: 0, y: 6, filter: 'blur(2px)' },
  animate: { opacity: 1, y: 0, filter: 'blur(0px)' },
  transition: { duration: 0.7, ease: EASE, delay: 0.15 + i * 0.06 },
})

function Hero() {
  return (
    <section aria-labelledby="hero-title" className="relative flex min-h-[100svh] flex-col overflow-hidden">
      <img src={hero} alt="A wooden signpost on a hill at dusk with arrows labelled GIF, PDF, MP4, JPG, MP3, PNG, DOCX and WEBP, the PDF arrow glowing" className="absolute inset-0 hidden h-full w-full object-cover object-[72%_center] md:block" />
      <div className="relative mx-auto flex w-full max-w-7xl flex-1 flex-col px-4 pb-8 pt-24 sm:px-8 md:pt-40 lg:px-16">
        <motion.p {...appear(0)} className="w-fit rounded-full bg-white/10 px-3 py-1 text-xs font-medium text-white/80 backdrop-blur-md">Free and open source for macOS</motion.p>
        <h1 id="hero-title" className="mt-6 max-w-[680px] text-5xl font-semibold tracking-tight [text-wrap:balance] md:text-7xl">
          <motion.span {...appear(1)} className="block bg-gradient-to-r from-white to-[#9B9B9B] bg-clip-text pb-1 text-transparent">Every file knows</motion.span>
          <motion.span {...appear(2)} className="block bg-gradient-to-r from-white to-[#9B9B9B] bg-clip-text pb-2 text-transparent">where it can go</motion.span>
        </h1>
        <motion.p {...appear(3)} className="mt-6 max-w-[680px] text-lg text-white/75 [text-wrap:pretty]">
          Drag a file, tap Shift, and drop it on the format you want. anyfmt converts it on your Mac and leaves the original exactly where it was.
        </motion.p>
        <motion.div {...appear(4)} className="mt-8 flex flex-wrap items-center gap-3">
          <PrimaryButton />
          <QuietButton onClick={() => scrollTo('how')}>How it works</QuietButton>
        </motion.div>
        <motion.p {...appear(5)} className="mt-4 text-sm text-white/60">Apple silicon, macOS 13 or later. No account.</motion.p>
        <motion.img {...appear(6)} src={hero} alt="" aria-hidden className="mt-8 aspect-[4/5] w-full rounded-3xl object-cover object-[80%_center] md:hidden" />

        <motion.div {...appear(6)} className="mt-auto flex flex-wrap items-end justify-between gap-8 pt-16">
          <dl className="flex gap-8 sm:gap-12">
            {[['793', 'Conversion routes'], ['516', 'On the wheel by default'], ['0', 'Uploads']].map(([n, l]) => (
              <div key={l}>
                <dt className="font-['Geist_Mono_Variable',ui-monospace,monospace] text-3xl font-medium">{n}</dt>
                <dd className="mt-1 text-xs text-white/60">{l}</dd>
              </div>
            ))}
          </dl>
          <div className="hidden text-right sm:block">
            <p className="text-xs text-white/60">Engines inside</p>
            <ul className="mt-2 grid grid-cols-3 gap-x-6 gap-y-1 text-sm text-white/80">
              {['ffmpeg', 'pandoc', 'ImageIO', 'AVFoundation', 'Vision', 'Quartz'].map((e) => <li key={e}>{e}</li>)}
            </ul>
          </div>
        </motion.div>
      </div>
    </section>
  )
}

/* ───────────────────────────── Problem → solution ───────────────────────────── */

const OLD_WAY = ['Search for a converter site', 'Upload the file to a stranger', 'Wait in a queue', 'Pick a format from a dropdown', 'Download the result', 'Find it in Downloads', 'Rename it and move it back']

function ProblemSection() {
  return (
    <section aria-labelledby="problem-title" className="mx-auto max-w-7xl px-4 py-24 sm:px-8 lg:px-16">
      <Reveal className="max-w-[680px]">
        <h2 id="problem-title" className="text-4xl font-semibold tracking-tight [text-wrap:balance] md:text-5xl">Converting a file should not take seven steps</h2>
        <p className="mt-6 text-lg text-white/60 [text-wrap:pretty]">Most of the time you already know the format you need. The work is everything around it.</p>
      </Reveal>
      <div className="mt-12 grid gap-4 md:grid-cols-2">
        <Reveal className="rounded-3xl bg-[#1F1F1F] p-8">
          <p className="text-sm font-medium text-white/60">The usual way</p>
          <ol className="mt-6 flex flex-col gap-3">
            {OLD_WAY.map((s, i) => (
              <li key={s} className="flex items-center gap-4 text-base text-white/60">
                <span className="w-6 font-['Geist_Mono_Variable',monospace] text-sm text-white/40">{String(i + 1).padStart(2, '0')}</span>{s}
              </li>
            ))}
          </ol>
        </Reveal>
        <Reveal delay={0.08} className="flex flex-col rounded-3xl bg-white p-8 text-black">
          <p className="text-sm font-medium text-black/60">With anyfmt</p>
          <p className="mt-6 text-3xl font-semibold tracking-tight [text-wrap:balance]">Drag, tap Shift, let go.</p>
          <p className="mt-4 max-w-[400px] text-base text-black/70 [text-wrap:pretty]">The new file lands beside the original with a sensible name. The original is never touched, and nothing leaves your Mac.</p>
          <div className="mt-auto flex flex-wrap gap-2 pt-8">
            {['One gesture', 'Offline', 'New copy every time'].map((c) => (
              <span key={c} className="flex items-center gap-2 rounded-full bg-black/5 px-3 py-1 text-sm font-medium"><Check size={14} weight="bold" />{c}</span>
            ))}
          </div>
        </Reveal>
      </div>
    </section>
  )
}

/* ───────────────────────────── Tagline reveal (B11) ───────────────────────────── */

const TAGLINE = 'Converter websites want your file before they help you. anyfmt does the work right where the file already lives.'

function Word({ children, progress, i, n }: { children: string; progress: MotionValue<number>; i: number; n: number }) {
  const start = (i / n) * 0.85
  const opacity = useTransform(progress, [start, start + 0.08], [0.3, 1], { ease: (x) => 1 - (1 - x) ** 3 })
  return <motion.span style={{ opacity }} aria-hidden>{children}</motion.span>
}

function TaglineSection() {
  const ref = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 80%', 'end 45%'] })
  const words = TAGLINE.split(' ')
  return (
    <section aria-label="Why anyfmt" className="mx-auto max-w-7xl px-4 py-24 sm:px-8 lg:px-16">
      <div ref={ref}>
        <p aria-label={TAGLINE} className="max-w-[880px] text-4xl font-semibold leading-tight tracking-tight [text-wrap:balance] md:text-6xl">
          {words.map((w, i) => (
            <Fragment key={i}>{reduce ? <span aria-hidden>{w}</span> : <Word progress={scrollYProgress} i={i} n={words.length}>{w}</Word>}{i < words.length - 1 ? ' ' : ''}</Fragment>
          ))}
        </p>
      </div>
    </section>
  )
}

/* ───────────────────────────── Features (bento with stories) ───────────────────────────── */

const card = {
  initial: { opacity: 0, y: 24, scale: 0.985, filter: 'blur(6px)' },
  whileInView: { opacity: 1, y: 0, scale: 1, filter: 'blur(0px)' },
  viewport: { once: true, amount: 0.3 },
}

function FeatureCard({ title, body, icon, children, className = '', i }: { title: string; body: string; icon: ReactNode; children: ReactNode; className?: string; i: number }) {
  return (
    <motion.article {...card} transition={{ duration: 0.9, ease: EASE, delay: i * 0.085 }} className={`flex flex-col rounded-3xl bg-[#1F1F1F] p-2 ${className}`}>
      <div className="relative min-h-[240px] flex-1 overflow-hidden rounded-2xl bg-[#272727]">{children}</div>
      <div className="p-6">
        <h3 className="flex items-center gap-2 text-xl font-semibold">{icon}{title}</h3>
        <p className="mt-2 text-base text-white/60 [text-wrap:pretty]">{body}</p>
      </div>
    </motion.article>
  )
}

const lerp = (a: number, b: number, k: number) => a + (b - a) * Math.max(0, Math.min(1, k))
const io = (k: number) => (k < 0.5 ? 4 * k * k * k : 1 - (-2 * k + 2) ** 3 / 2)
const seg = (t: number, a: number, b: number) => io(Math.max(0, Math.min(1, (t - a) / (b - a))))

/** Story: the pointer sweeps the wheel, wedges light as it passes, it settles on GIF and the file lands. */
function WheelStory() {
  const ref = useRef<HTMLDivElement>(null)
  const { t, reduce } = useStoryClock(ref, 6)
  const F = ['GIF', 'MP4', 'WEBM', 'MKV', 'MP3', 'M4A', 'AVI', 'MOV']
  const angle = reduce ? 0 : lerp(225, 360, seg(t, 0.4, 2.4)) % 360
  const hot = reduce || (t > 0.4 && t < 4.2) ? Math.round(angle / 45) % 8 : -1
  const done = !reduce && t > 2.8 && t < 4.6
  const wedge = (i: number) => {
    const a0 = ((i * 45 - 90 - 22.5 + 2) * Math.PI) / 180, a1 = ((i * 45 - 90 + 22.5 - 2) * Math.PI) / 180, r0 = 46, r1 = 104
    const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(1)},${(Math.sin(a) * r).toFixed(1)}`
    return `M${p(r1, a0)} A${r1},${r1} 0 0 1 ${p(r1, a1)} L${p(r0, a1)} A${r0},${r0} 0 0 0 ${p(r0, a0)} Z`
  }
  const pa = ((angle - 90) * Math.PI) / 180
  return (
    <div ref={ref} className="absolute inset-0 flex items-center justify-center">
      <svg viewBox="-120 -120 240 240" className="h-[88%] max-h-[300px]">
        {F.map((f, i) => {
          const m = (((i * 45 - 90) * Math.PI) / 180)
          return (
            <g key={f}>
              <path d={wedge(i)} fill={i === hot ? '#F08A4B' : '#313131'} style={{ transition: 'fill .3s cubic-bezier(.22,1,.36,1)' }} />
              <text x={Math.cos(m) * 75} y={Math.sin(m) * 75} textAnchor="middle" dominantBaseline="central" fontSize="11" fontWeight="600" fontFamily="Geist Mono Variable, monospace" fill={i === hot ? '#131209' : '#fff'}>{f}</text>
            </g>
          )
        })}
        <circle r="40" fill="#1F1F1F" />
        <text y="-4" textAnchor="middle" fontSize="10" fill="#9B9B9B" fontFamily="Geist Variable, sans-serif">{done ? 'saved' : 'convert'}</text>
        <text y="12" textAnchor="middle" fontSize="12" fontWeight="600" fill="#fff" fontFamily="Geist Mono Variable, monospace">{done ? 'clip.gif' : 'clip.mov'}</text>
        {!reduce && hot >= 0 && (
          <g transform={`translate(${Math.cos(pa) * 112} ${Math.sin(pa) * 112})`}>
            <path d="M0 0 L0 15 L4 11 L7 17 L9.5 16 L6.5 10 L11.5 10 Z" fill="#fff" stroke="#131209" strokeWidth="1" />
          </g>
        )}
      </svg>
    </div>
  )
}

/** Story: a new copy lands on top with a blur, the others step back, the last one leaves. */
function StackStory() {
  const ref = useRef<HTMLDivElement>(null)
  const { t, reduce } = useStoryClock(ref, 5)
  const landed = reduce || (t > 0.8 && t < 4.3)
  const rows = [{ n: 'photo.heic', s: 'original' }, { n: 'scan.pdf', s: '2 days ago' }, { n: 'notes.docx', s: 'last week' }]
  return (
    <div ref={ref} className="absolute inset-0 flex flex-col justify-center gap-2 px-6">
      <AnimatePresence initial={false}>
        {landed && (
          <motion.div key="new" initial={{ opacity: 0, y: -12, filter: 'blur(4px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.6, ease: EASE }} className="flex items-center justify-between rounded-xl bg-white px-4 py-3 text-sm font-medium text-black">
            <span className="flex items-center gap-2"><Copy size={14} weight="bold" />photo.jpg</span><span className="text-black/60">new copy</span>
          </motion.div>
        )}
      </AnimatePresence>
      {rows.map((r, i) => (
        <motion.div key={r.n} layout transition={{ duration: 0.6, ease: EASE }} animate={{ opacity: landed && i === 2 ? 0.35 : 1 }}
          className="flex items-center justify-between rounded-xl bg-[#313131] px-4 py-3 text-sm">
          <span className="font-['Geist_Mono_Variable',monospace] text-white">{r.n}</span><span className="text-white/60">{r.s}</span>
        </motion.div>
      ))}
    </div>
  )
}

/** Story: the network is off and a conversion fills to done anyway. */
function OfflineStory() {
  const ref = useRef<HTMLDivElement>(null)
  const { t, reduce } = useStoryClock(ref, 5)
  const p = reduce ? 1 : seg(t, 0.4, 3.2)
  return (
    <div ref={ref} className="absolute inset-0 flex flex-col justify-center gap-4 px-6">
      <div className="flex items-center justify-between rounded-xl bg-[#313131] px-4 py-3 text-sm">
        <span className="flex items-center gap-2"><WifiSlash size={16} />Network</span>
        <span className="flex h-6 w-10 items-center rounded-full bg-[#1F1F1F] p-1"><span className="h-4 w-4 rounded-full bg-white/40" /></span>
      </div>
      <div className="rounded-xl bg-[#313131] px-4 py-3">
        <div className="flex items-center justify-between font-['Geist_Mono_Variable',monospace] text-sm"><span>interview.m4a → mp3</span><span className="text-white/60">{Math.round(p * 100)}%</span></div>
        <div className="mt-3 h-2 overflow-hidden rounded-full bg-[#1F1F1F]">
          <div className="h-full rounded-full bg-[#F08A4B]" style={{ clipPath: `inset(0 ${100 - p * 100}% 0 0 round 999px)` }} />
        </div>
      </div>
    </div>
  )
}

/** Story: a folder of 72 files converts cell by cell while the counter counts. */
function BatchStory() {
  const ref = useRef<HTMLDivElement>(null)
  const { t, reduce } = useStoryClock(ref, 6)
  const n = 72, k = reduce ? n : Math.round(seg(t, 0.4, 4) * n)
  return (
    <div ref={ref} className="absolute inset-0 flex flex-col justify-center gap-4 px-6">
      <div className="flex items-center justify-between text-sm"><span className="flex items-center gap-2"><FolderSimple size={16} />Holiday 2026</span><span className="font-['Geist_Mono_Variable',monospace] text-white/60">{k} / {n}</span></div>
      <div className="grid grid-cols-12 gap-1">
        {Array.from({ length: n }, (_, i) => <span key={i} className="aspect-square rounded-sm transition-colors duration-300" style={{ background: i < k ? '#F08A4B' : '#313131' }} />)}
      </div>
    </div>
  )
}

/** Story: a highlight steps down the tool list and each row's result loads beside it. */
function ToolsStory() {
  const ref = useRef<HTMLDivElement>(null)
  const { t, reduce } = useStoryClock(ref, 6)
  const tools: [string, string][] = [['Compress', '4.8 MB → 1.3 MB'], ['Trim', '0:42 kept'], ['Crop', '1080 × 1080'], ['Remove background', 'PNG'], ['Strip metadata', '14 tags removed']]
  const at = reduce ? -1 : Math.floor(t / 1.1)
  return (
    <div ref={ref} className="absolute inset-0 flex flex-col justify-center gap-1 px-6">
      {tools.map(([n, r], i) => (
        <div key={n} className={`flex items-center justify-between rounded-xl px-4 py-2 text-sm transition-colors duration-300 ${i === at ? 'bg-white text-black' : 'text-white/80'}`}>
          <span className="font-medium">{n}</span>
          <AnimatePresence>{i <= at && i >= 0 && <motion.span initial={{ opacity: 0, filter: 'blur(4px)' }} animate={{ opacity: 1, filter: 'blur(0px)' }} transition={{ duration: 0.5, ease: EASE }} className={`font-['Geist_Mono_Variable',monospace] text-xs ${i === at ? 'text-black/60' : 'text-white/40'}`}>{r}</motion.span>}</AnimatePresence>
        </div>
      ))}
    </div>
  )
}

function FeaturesSection() {
  return (
    <section id="features" aria-labelledby="features-title" className="mx-auto max-w-7xl scroll-mt-24 px-4 py-24 sm:px-8 lg:px-16">
      <Reveal className="max-w-[680px]">
        <h2 id="features-title" className="text-4xl font-semibold tracking-tight [text-wrap:balance] md:text-5xl">Everything happens in the drag you were already making</h2>
      </Reveal>
      <div className="mt-12 grid gap-4 md:grid-cols-6">
        <FeatureCard i={0} className="md:col-span-4" icon={<Command size={20} />} title="Convert mid drag" body="Tap Shift and the formats this file can become open around your pointer. Only routes that work for it appear.">
          <WheelStory />
        </FeatureCard>
        <FeatureCard i={1} className="md:col-span-2" icon={<Copy size={20} />} title="Originals stay put" body="Every conversion and edit writes a new copy beside the file you started with.">
          <StackStory />
        </FeatureCard>
        <FeatureCard i={2} className="md:col-span-2" icon={<CloudSlash size={20} />} title="Works offline" body="The engines ship inside the app, so a plane seat is as good as a fibre line.">
          <OfflineStory />
        </FeatureCard>
        <FeatureCard i={3} className="md:col-span-2" icon={<Stack size={20} />} title="A folder at a time" body="Drop fifty files and the wheel shows only the formats all of them can reach.">
          <BatchStory />
        </FeatureCard>
        <FeatureCard i={4} className="md:col-span-2" icon={<Command size={20} />} title="26 tools on Command" body="Compress to a target size, trim, crop, remove a background, strip metadata.">
          <ToolsStory />
        </FeatureCard>
      </div>
    </section>
  )
}

/* ───────────────────────────── How it works ───────────────────────────── */

const STEPS = [
  { img: step1, alt: 'A hand lifting one photo off a tall stack of papers on a hill', t: 'Pick up any file', d: 'From Finder, the desktop, Mail or a browser download. There is no window to open first.' },
  { img: step2, alt: 'A giant glowing Shift key standing on a hill like a monument', t: 'Tap Shift', d: 'The formats it can become open around your pointer. Command opens tools, Control opens actions.' },
  { img: step3, alt: 'A sheet of paper folding itself into a paper plane over a hill', t: 'Let go on a format', d: 'A new copy lands beside the original, named so you can find it. That is the whole thing.' },
]

function HowSection() {
  return (
    <section id="how" aria-labelledby="how-title" className="mx-auto max-w-7xl scroll-mt-24 px-4 py-24 sm:px-8 lg:px-16">
      <Reveal className="max-w-[680px]">
        <h2 id="how-title" className="text-4xl font-semibold tracking-tight [text-wrap:balance] md:text-5xl">Three moves, no settings</h2>
      </Reveal>
      <ol className="mt-12 grid gap-4 md:grid-cols-3">
        {STEPS.map((s, i) => (
          <Reveal key={s.t} delay={i * 0.08}>
            <li className="group list-none rounded-3xl bg-[#1F1F1F] p-2">
              <div className="overflow-hidden rounded-2xl">
                <img src={s.img} alt={s.alt} loading="lazy" className="aspect-[4/3] w-full object-cover transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:scale-[1.03]" />
              </div>
              <div className="p-6">
                <p className="font-['Geist_Mono_Variable',monospace] text-sm text-[#F08A4B]">{String(i + 1).padStart(2, '0')}</p>
                <h3 className="mt-2 text-xl font-semibold">{s.t}</h3>
                <p className="mt-2 text-base text-white/60 [text-wrap:pretty]">{s.d}</p>
              </div>
            </li>
          </Reveal>
        ))}
      </ol>
    </section>
  )
}

/* ───────────────────────────── Proof ───────────────────────────── */

const MATRIX = ['Images', 'Video', 'Audio', 'Documents', 'PDF', 'Ebooks', 'Subtitles', 'Archives']

function ProofSection() {
  return (
    <section aria-labelledby="proof-title" className="mx-auto max-w-7xl px-4 py-24 sm:px-8 lg:px-16">
      <div className="grid gap-4 md:grid-cols-6">
        <Reveal className="rounded-3xl bg-[#1F1F1F] p-8 md:col-span-4">
          <h2 id="proof-title" className="max-w-[680px] text-3xl font-semibold tracking-tight [text-wrap:balance]">Every route is run on a real file before it ships</h2>
          <p className="mt-4 max-w-[560px] text-base text-white/60 [text-wrap:pretty]">793 input and output pairs, direct or routed through up to three steps, each converted and checked by the test matrix. 516 of them sit on the wheel by default.</p>
          <div className="mt-8 grid grid-cols-2 gap-2 sm:grid-cols-4">
            {MATRIX.map((k) => (
              <div key={k} className="flex items-center gap-2 rounded-xl bg-[#272727] px-4 py-3 text-sm"><Check size={14} weight="bold" className="text-[#F08A4B]" />{k}</div>
            ))}
          </div>
        </Reveal>
        <Reveal delay={0.08} className="flex flex-col justify-between rounded-3xl bg-[#1F1F1F] p-8 md:col-span-2">
          <GithubLogo size={28} />
          <div className="mt-12">
            <p className="text-3xl font-semibold tracking-tight">Open source</p>
            <p className="mt-2 text-base text-white/60 [text-wrap:pretty]">AGPL 3.0. Read every line that touches your files, or build it yourself.</p>
          </div>
        </Reveal>
      </div>
    </section>
  )
}

/* ───────────────────────────── FAQ ───────────────────────────── */

const FAQ: [string, string][] = [
  ['Is anyfmt really free?', 'Yes. Every conversion, tool and action that runs on your Mac is free, commercial use included. Optional cloud extras such as share links may cost money later; nothing local ever will.'],
  ['Does it upload my files?', 'No. Conversions and edits run on your Mac, offline. The only thing that ever sends a file anywhere is a share link, and you have to ask for one.'],
  ['Which formats does it handle?', 'Images, video, audio, PDF, documents, slides, spreadsheets, ebooks, subtitles and archives: 793 conversion routes in total, with 516 on the wheel by default.'],
  ['Will it overwrite my original?', 'Never. Every conversion and edit writes a new copy beside the original, with a name you can recognise.'],
  ['Which Macs does it run on?', 'A Mac with Apple silicon on macOS 13 Ventura or later.'],
  ['Do I need ffmpeg or anything else installed?', 'No. The engines ship inside the app, so it works the moment you open it.'],
  ['Can I use a key other than Shift?', 'Yes. All three trigger keys and the tap threshold can be remapped in Settings.'],
  ['Can I script it?', 'Yes. The anyfmt command in Terminal runs the same routes the wheel runs, so a script, a Shortcut or an agent gets identical results.'],
]

function FaqSection() {
  const [open, setOpen] = useState(0)
  return (
    <section id="faq" aria-labelledby="faq-title" className="mx-auto grid max-w-7xl scroll-mt-24 gap-12 px-4 py-24 sm:px-8 md:grid-cols-[minmax(0,2fr)_minmax(0,3fr)] lg:px-16">
      <Reveal>
        <h2 id="faq-title" className="text-4xl font-semibold tracking-tight [text-wrap:balance] md:text-5xl">Questions, answered</h2>
        <p className="mt-6 max-w-[400px] text-lg text-white/60 [text-wrap:pretty]">Anything else, open an issue on GitHub and a person will answer.</p>
      </Reveal>
      <Reveal delay={0.08}>
        <ul className="flex flex-col gap-2">
          {FAQ.map(([q, a], i) => {
            const on = open === i
            return (
              <li key={q} className="rounded-2xl bg-[#1F1F1F]">
                <h3>
                  <button type="button" aria-expanded={on} aria-controls={`faq-${i}`} id={`faq-q-${i}`} onClick={() => setOpen(on ? -1 : i)}
                    className="flex w-full items-center justify-between gap-4 rounded-2xl px-6 py-4 text-left text-base font-semibold outline-none transition-colors duration-300 hover:bg-white/5 focus-visible:ring-2 focus-visible:ring-white">
                    {q}
                    <span className="relative flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[#313131]">
                      <Plus size={12} weight="bold" className="absolute transition-[transform,opacity] duration-500 ease-[cubic-bezier(0.22,1,0.36,1)]" style={{ transform: on ? 'rotate(90deg)' : 'none', opacity: on ? 0 : 1 }} />
                      <Minus size={12} weight="bold" className="absolute transition-[transform,opacity] duration-500 ease-[cubic-bezier(0.22,1,0.36,1)]" style={{ transform: on ? 'none' : 'rotate(-90deg)', opacity: on ? 1 : 0 }} />
                    </span>
                  </button>
                </h3>
                <AnimatePresence initial={false}>
                  {on && (
                    <motion.div id={`faq-${i}`} role="region" aria-labelledby={`faq-q-${i}`} initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.5, ease: EASE }} className="overflow-hidden">
                      <p className="px-6 pb-6 text-base text-white/60 [text-wrap:pretty]">{a}</p>
                    </motion.div>
                  )}
                </AnimatePresence>
              </li>
            )
          })}
        </ul>
      </Reveal>
    </section>
  )
}

/* ───────────────────────────── Final CTA + footer ───────────────────────────── */

function FinalCta() {
  return (
    <section id="download" aria-labelledby="cta-title" className="px-2 pb-2">
      <div className="relative overflow-hidden rounded-3xl">
        <img src={night} alt="The signpost at night under a sky full of stars, one arrow glowing like a lantern" loading="lazy" className="absolute inset-0 h-full w-full object-cover object-[20%_center]" />
        <Reveal className="relative flex min-h-[560px] flex-col items-center justify-center px-4 py-24 text-center">
          <h2 id="cta-title" className="max-w-[680px] text-4xl font-semibold tracking-tight [text-wrap:balance] md:text-6xl">
            <span className="bg-gradient-to-r from-white to-[#9B9B9B] bg-clip-text text-transparent">Every file knows where it can go</span>
          </h2>
          <p className="mt-6 max-w-[520px] text-lg text-white/75 [text-wrap:pretty]">Free, no account, open source. Install it once and your next drag already works.</p>
          <div className="mt-8"><PrimaryButton /></div>
          <p className="mt-4 text-sm text-white/60">Apple silicon, macOS 13 or later.</p>
        </Reveal>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-6 px-4 py-12 text-sm text-white/60 sm:px-8 lg:px-16">
      <span className="flex items-center gap-2 text-white"><Mark />anyfmt</span>
      <nav aria-label="Footer" className="flex flex-wrap gap-6">
        <button type="button" onClick={() => scrollTo('faq')} className="transition-colors duration-300 hover:text-white">FAQ</button>
        <Link to="/elaya/legal" className="transition-colors duration-300 hover:text-white">Privacy</Link>
        <Link to="/elaya/legal" className="transition-colors duration-300 hover:text-white">Terms</Link>
        <a href={DOWNLOAD} className="flex items-center gap-1 transition-colors duration-300 hover:text-white">anyfmt.app<ArrowUpRight size={12} /></a>
      </nav>
    </footer>
  )
}

/* ───────────────────────────── Pages ───────────────────────────── */

export default function ElayaLanding() {
  useEffect(() => {
    document.title = 'anyfmt: convert any file in the middle of a drag'
    const meta = document.querySelector('meta[name="description"]') ?? Object.assign(document.head.appendChild(document.createElement('meta')), { name: 'description' })
    meta.setAttribute('content', 'Drag a file, tap Shift and drop it on the format you want. anyfmt converts 793 routes on your Mac, offline, and never touches the original.')
  }, [])
  return (
    <Shell>
      <Nav />
      <main id="main" tabIndex={-1} className="outline-none">
        <Hero />
        <ProblemSection />
        <TaglineSection />
        <FeaturesSection />
        <HowSection />
        <ProofSection />
        <FaqSection />
        <FinalCta />
      </main>
      <Footer />
    </Shell>
  )
}

export function ElayaLegal() {
  useEffect(() => { document.title = 'anyfmt: privacy and terms' }, [])
  return (
    <Shell>
      <Nav />
      <main id="main" tabIndex={-1} className="mx-auto max-w-[680px] px-4 pb-24 pt-40 outline-none">
        <h1 className="text-4xl font-semibold tracking-tight">Privacy and terms</h1>
        <p className="mt-6 text-lg text-white/75 [text-wrap:pretty]">anyfmt runs on your Mac. It converts and edits files locally, offline, and does not upload them. Share links are the one exception, and only when you create one.</p>
        <p className="mt-4 text-base text-white/60 [text-wrap:pretty]">The full privacy policy and terms of use will be published here with the first public release.</p>
        <Link to="/elaya" className="mt-8 inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 text-base font-semibold text-black">Back to anyfmt<ArrowRight size={16} weight="bold" /></Link>
      </main>
    </Shell>
  )
}

export function ElayaNotFound() {
  useEffect(() => { document.title = 'anyfmt: page not found' }, [])
  return (
    <Shell>
      <main id="main" tabIndex={-1} className="relative flex min-h-[100svh] items-center justify-center overflow-hidden outline-none">
        <img src={lost} alt="A signpost on a hill with blank arrows pointing every way, one fallen in the grass" className="absolute inset-0 h-full w-full object-cover object-[40%_center]" />
        <div className="relative px-4 text-center">
          <p className="font-['Geist_Mono_Variable',monospace] text-8xl font-medium">404</p>
          <p className="mt-4 text-lg text-white/75">This page took a wrong turn. The signs are blank here.</p>
          <Link to="/elaya" className="mt-8 inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 text-base font-semibold text-black transition-[transform,background-color] duration-300 hover:bg-[#E9E9E9] active:scale-[0.98]">Back to the start<ArrowRight size={16} weight="bold" /></Link>
        </div>
      </main>
    </Shell>
  )
}
