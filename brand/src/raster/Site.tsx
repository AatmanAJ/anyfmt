/**
 * anyfmt landing page, following dovetail.com's section structure and interaction patterns
 * (giant mixed-type headlines with inline objects, a live product mock, a sticky globe walkthrough,
 * a card grid, a stories row) with anyfmt's own copy, objects, photos, type and code.
 */

import { AnimatePresence, motion, useScroll, useTransform } from 'motion/react'
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { ASSETS } from './assets'
import { AsciiField, C, Dither, DitherButton, DotIcon, FrameButton, Mark, Pixel, RasterStyles, reducedMotion, useInView } from './kit'
import { ClosingSection, Ctas, Footer, FormatStrip, KeysSection, Obj, ProofSection, WheelCard, Wrap } from './Sections'
import { STORIES } from './stories'

/** Fixed-size artboard scaled to its container width. */
function Stage({ w, h, children, className = '' }: { w: number; h: number; children: ReactNode; className?: string }) {
  const box = useRef<HTMLDivElement>(null)
  const [k, setK] = useState(1)
  useEffect(() => {
    const el = box.current
    if (!el) return
    const fit = () => setK(el.offsetWidth / w)
    fit()
    const ro = new ResizeObserver(fit)
    ro.observe(el)
    window.addEventListener('resize', fit)
    return () => { ro.disconnect(); window.removeEventListener('resize', fit) }
  }, [w])
  return (
    <div ref={box} className={`relative w-full overflow-hidden ${className}`} style={{ aspectRatio: `${w} / ${h}` }}>
      <div className="absolute left-0 top-0 origin-top-left" style={{ width: w, height: h, transform: `scale(${k})` }}>{children}</div>
    </div>
  )
}

const H2 = 'text-[clamp(44px,8vw,128px)] font-semibold leading-[0.98] tracking-[-0.055em] text-white [text-wrap:balance]'

/* ───────────────────────────── Nav ───────────────────────────── */

const PRODUCT_MENU = [
  { i: 'shift', t: 'Convert', d: '793 routes on the Shift wheel' },
  { i: 'command', t: 'Edit', d: '26 tools on the Command wheel' },
  { i: 'control', t: 'Act', d: 'AirDrop, Float, copy path' },
  { i: 'copy', t: 'CLI', d: 'anyfmt convert, in any script' },
]

function SiteNav() {
  const [open, setOpen] = useState(false)
  const [hidden, setHidden] = useState(false)
  const [solid, setSolid] = useState(false)
  useEffect(() => {
    let last = window.scrollY
    const on = () => {
      const y = window.scrollY
      setHidden(y > last && y > 400)
      setSolid(y > 40)
      last = y
    }
    window.addEventListener('scroll', on, { passive: true })
    return () => window.removeEventListener('scroll', on)
  }, [])
  return (
    <motion.header animate={{ y: hidden && !open ? -96 : 0 }} transition={{ duration: 0.3, ease: [0.2, 0.9, 0.2, 1] }}
      className={`fixed inset-x-0 top-0 z-50 transition-colors duration-300 ${solid ? 'bg-[#0A0A0A]/80 backdrop-blur-xl' : ''}`}>
      <nav className="mx-auto flex h-[76px] max-w-[1320px] items-center justify-between px-5 sm:px-10">
        <div className="flex items-center gap-8">
          <a href="#" onClick={(e) => e.preventDefault()} className="flex items-center gap-2.5 text-[19px] font-semibold tracking-[-0.03em] text-white"><Mark />anyfmt</a>
          <div className="hidden items-center gap-1 md:flex">
            <div className="relative" onPointerEnter={() => setOpen(true)} onPointerLeave={() => setOpen(false)}>
              <button type="button" aria-expanded={open} onClick={() => setOpen((o) => !o)} onFocus={() => setOpen(true)}
                className="nav-pixel relative flex items-center gap-1.5 rounded-full px-3.5 py-2 text-[15px] font-medium text-white/85 outline-none hover:text-white">
                Product <span className={`transition-transform duration-200 ${open ? 'rotate-90' : ''}`}><DotIcon name="arrow" size={8} /></span>
              </button>
              <AnimatePresence>
                {open && (
                  <motion.div initial={{ opacity: 0, y: 6, clipPath: 'inset(0 0 100% 0)' }} animate={{ opacity: 1, y: 0, clipPath: 'inset(0 0 0% 0)' }} exit={{ opacity: 0, y: 4 }}
                    transition={{ duration: 0.22, ease: [0.2, 0.9, 0.2, 1] }}
                    className="absolute left-0 top-full mt-2 grid w-[460px] grid-cols-2 gap-1 rounded-lg bg-[#141414] p-2 ring-1 ring-[#313131]">
                    {PRODUCT_MENU.map((m) => (
                      <a key={m.t} href="#" onClick={(e) => e.preventDefault()} className="group flex gap-3 rounded-md p-3 transition-colors hover:bg-[#1E1E1E]">
                        <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-md bg-[#1E1E1E] text-[#FF5A1F] ring-1 ring-[#313131] group-hover:bg-[#0A0A0A]"><DotIcon name={m.i} size={13} /></span>
                        <span><span className="block text-[14px] font-medium text-white">{m.t}</span><span className="block text-[12.5px] text-[#A7A7A7]">{m.d}</span></span>
                      </a>
                    ))}
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
            {['Formats', 'Tools', 'Guides', 'Pricing'].map((l) => (
              <a key={l} href="#" onClick={(e) => e.preventDefault()} className="nav-pixel relative rounded-full px-3.5 py-2 text-[15px] font-medium text-white/85 hover:text-white">{l}</a>
            ))}
          </div>
        </div>
        <div className="flex items-center gap-5">
          <a href="#" onClick={(e) => e.preventDefault()} className="hidden text-[15px] font-medium text-white/85 hover:text-white sm:block">GitHub</a>
          <DitherButton size="sm">Download</DitherButton>
        </div>
      </nav>
    </motion.header>
  )
}

/* ───────────────────────────── Hero ───────────────────────────── */

function Hero() {
  return (
    <section className="relative overflow-hidden">
      <AsciiField focus={{ x: 0.5, y: 0.72, r: 0.3, boost: 0.6 }} />
      <Wrap className="relative pb-14 pt-36 sm:pt-44">
        <div className="flex flex-wrap items-start justify-between gap-10">
          <div className="max-w-[660px]">
            <p className="text-[clamp(20px,1.9vw,27px)] leading-[1.38] tracking-[-0.02em] text-[#A7A7A7]">
              <span className="text-white"><span className="font-serif text-[1.2em] leading-none tracking-[-0.01em]">The format layer for macOS</span> that turns every drag into a conversion,</span> an edit or a share, with each of 793 routes checked on a real file.
            </p>
            <Ctas className="mt-8" />
          </div>
          <dl className="grid grid-cols-3 gap-8 sm:gap-12">
            {[['shift', 'Shift', 'Convert'], ['command', 'Cmd', 'Edit'], ['control', 'Ctrl', 'Act']].map(([i, k, l]) => (
              <div key={l} className="group">
                <dt className="flex h-11 w-11 items-center justify-center rounded-md text-white ring-1 ring-[#313131] transition-colors group-hover:bg-white group-hover:text-black"><DotIcon name={i} size={16} /></dt>
                <dd className="mt-3 font-mono text-[12px] uppercase tracking-[0.14em] text-[#A7A7A7]"><span className="text-white">{k}</span> · {l}</dd>
              </div>
            ))}
          </dl>
        </div>
        <h1 className="mt-[12vh] text-[clamp(54px,11vw,190px)] font-semibold leading-[0.92] tracking-[-0.062em] text-white">
          Any file <Obj a="floppy" h="1em" rot={-9} alt="A floppy disk" /> in.<br />
          Every <Pixel cell={0.03} auto={5600}>format</Pixel> out.
        </h1>
        <div className="mt-14 flex flex-wrap items-center gap-x-10 gap-y-4">
          <span className="font-mono text-[12px] uppercase tracking-[0.14em] text-[#7C7C7C]">Reads and writes</span>
          <FormatStrip />
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────────── Product mock ───────────────────────────── */

const MONTHS = ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct']
const JOBS = [
  { t: 'Bug report recording', from: 'clip.mov', to: 'GIF', eng: 'ffmpeg', n: '1 file', size: '48.2 MB → 6.1 MB', cmd: 'anyfmt convert clip.mov --to gif' },
  { t: 'Receipts for the accountant', from: '23 photos', to: 'PDF', eng: 'Quartz', n: '23 files', size: '23 PDFs, 4.8 MB', cmd: 'anyfmt convert receipts/*.heic --to pdf' },
  { t: 'Holiday photos for a PC', from: '412 photos', to: 'JPG', eng: 'ImageIO', n: '412 files', size: '1.9 GB → 1.1 GB', cmd: 'anyfmt convert *.heic --to jpg --opt quality=85' },
]
const TERMINAL = [
  { k: 'cmd', t: '$ anyfmt convert IMG_0042.heic --to jpg --opt quality=85' },
  { k: 'out', t: '  route   heic → jpg   ImageIO' },
  { k: 'bar', t: '' },
  { k: 'ok', t: '  ✓ IMG_0042.jpg   saved beside the original' },
  { k: 'cmd', t: '$ anyfmt tool image.compress *.png --opt sizeMode=size --opt targetSize=500000' },
  { k: 'ok', t: '  ✓ 12 files, each under 500 KB' },
]

function Heatmap() {
  const cells = useMemo(() => {
    let s = 7
    const r = () => { s = (s * 16807) % 2147483647; return s / 2147483647 }
    return Array.from({ length: 52 * 7 }, (_, i) => { const v = r(); const w = Math.floor(i / 7); return v > 0.62 - (w > 40 ? 0.2 : 0) ? Math.ceil(r() * 4) : 0 })
  }, [])
  const [tip, setTip] = useState<{ i: number; x: number; y: number } | null>(null)
  const events: Record<number, { icon: string; t: string }> = { [7 * 23 + 2]: { icon: 'bolt', t: 'Batch: 412 photos → JPG' }, [7 * 44 + 4]: { icon: 'check', t: '23 receipts → PDF' } }
  return (
    <div className="relative">
      <div className="ml-9 flex justify-between font-mono text-[10px] text-[#7C7C7C]">{MONTHS.map((m) => <span key={m}>{m}</span>)}</div>
      <div className="mt-2 flex">
        <div className="flex w-9 flex-col justify-around py-0.5 font-mono text-[10px] text-[#7C7C7C]"><span>Mon</span><span>Wed</span><span>Fri</span></div>
        <div className="grid grid-flow-col grid-rows-7 gap-[3px]" onPointerLeave={() => setTip(null)}>
          {cells.map((v, i) => {
            const ev = events[i]
            return (
              <span key={i} onPointerEnter={(e) => { const r = (e.currentTarget.parentElement as HTMLElement).getBoundingClientRect(); const c = e.currentTarget.getBoundingClientRect(); setTip({ i, x: (c.left - r.left) / (r.width / 693), y: (c.top - r.top) / (r.height / 88) }) }}
                className={`relative h-[10px] w-[10px] rounded-[2px] transition-transform hover:scale-150 ${ev ? 'z-10' : ''}`}
                style={{ background: v ? `rgba(255,90,31,${0.18 + v * 0.2})` : C.iron }}>
                {ev && <span className="absolute -left-[7px] -top-[7px] flex h-6 w-6 items-center justify-center rounded-full bg-white text-black ring-2 ring-[#141414]"><DotIcon name={ev.icon} size={10} /></span>}
              </span>
            )
          })}
        </div>
      </div>
      <AnimatePresence>
        {tip && (
          <motion.div initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.12 }}
            className="pointer-events-none absolute z-20 whitespace-nowrap rounded-md bg-[#0A0A0A] px-2.5 py-1.5 text-[12px] text-white ring-1 ring-[#313131]"
            style={{ left: 36 + tip.x, top: 24 + tip.y + 16 }}>
            {events[tip.i]?.t ?? `${cells[tip.i] * 9 + (tip.i % 5)} conversions`}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

function TerminalPanel() {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, '0px')
  const [line, setLine] = useState(0)
  const [chars, setChars] = useState(0)
  const [pct, setPct] = useState(0)
  useEffect(() => {
    if (!inView) return
    if (reducedMotion()) { setLine(TERMINAL.length); return }
    const cur = TERMINAL[line]
    if (!cur) { const id = window.setTimeout(() => { setLine(0); setChars(0); setPct(0) }, 3200); return () => clearTimeout(id) }
    if (cur.k === 'cmd' && chars < cur.t.length) { const id = window.setTimeout(() => setChars((c) => c + 1), 28); return () => clearTimeout(id) }
    if (cur.k === 'bar' && pct < 1) { const id = window.setTimeout(() => setPct((p) => Math.min(1, p + 0.07)), 60); return () => clearTimeout(id) }
    const id = window.setTimeout(() => { setLine((l) => l + 1); setChars(0) }, cur.k === 'cmd' ? 420 : 260)
    return () => clearTimeout(id)
  }, [inView, line, chars, pct])
  const bar = (p: number) => `  ${'█'.repeat(Math.round(p * 24))}${'░'.repeat(24 - Math.round(p * 24))} ${Math.round(p * 100)}%`
  return (
    <div ref={ref} className="w-[470px] overflow-hidden rounded-lg bg-[#0A0A0A] ring-1 ring-[#313131] shadow-[0_40px_80px_-30px_rgba(0,0,0,.9)]">
      <div className="flex items-center justify-between border-b border-[#1E1E1E] px-4 py-3">
        <span className="flex items-center gap-2 text-[14px] font-medium text-white"><span className="text-[#FF5A1F]"><DotIcon name="copy" size={13} /></span>anyfmt in Terminal</span>
        <span className="font-mono text-[10.5px] uppercase tracking-[0.12em] text-[#7C7C7C]">zsh</span>
      </div>
      <div className="h-[200px] px-4 py-3 font-mono text-[12px] leading-[1.75]">
        {TERMINAL.slice(0, line + 1).map((l, i) => {
          if (i > line) return null
          const done = i < line
          const text = l.k === 'cmd' ? (done ? l.t : l.t.slice(0, chars)) : l.k === 'bar' ? bar(done ? 1 : pct) : l.t
          if (!done && l.k !== 'cmd' && l.k !== 'bar') return null
          return <div key={i} className={l.k === 'cmd' ? 'text-white' : l.k === 'ok' ? 'text-[#FF5A1F]' : 'text-[#A7A7A7]'}>{text}{i === line && l.k === 'cmd' && <span className="ml-px inline-block h-[13px] w-[7px] translate-y-[2px] animate-pulse bg-white" />}</div>
        })}
      </div>
    </div>
  )
}

function ProductMock() {
  const [tab, setTab] = useState<'jobs' | 'formats'>('jobs')
  const [sel, setSel] = useState(0)
  const [copied, setCopied] = useState(-1)
  const job = JOBS[sel]
  const copy = async (i: number) => {
    try { await navigator.clipboard.writeText(JOBS[i].cmd) } catch { /* clipboard refused: the label still confirms intent */ }
    setCopied(i)
    window.setTimeout(() => setCopied(-1), 1400)
  }
  return (
    <div className="relative h-[700px] w-[1240px] rounded-xl bg-[#0F0F0F] ring-1 ring-[#1E1E1E]">
      {/* toolbar */}
      <div className="flex h-16 items-center gap-4 border-b border-[#1E1E1E] px-6">
        <span className="flex h-8 w-8 items-center justify-center rounded-md bg-[#FF5A1F] text-black"><Mark size={18} /></span>
        <span className="text-[17px] font-medium text-white">Library</span>
        <div className="mx-auto flex gap-1 rounded-lg bg-[#141414] p-1 ring-1 ring-[#1E1E1E]">
          {(['jobs', 'formats'] as const).map((t) => (
            <button key={t} type="button" onClick={() => setTab(t)} className={`relative rounded-md px-4 py-1.5 text-[14px] font-medium capitalize ${tab === t ? 'text-white' : 'text-[#7C7C7C] hover:text-white'}`}>
              {tab === t && <motion.span layoutId="mock-tab" className="absolute inset-0 rounded-md bg-[#1E1E1E] ring-1 ring-[#313131]" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
              <span className="relative">{t}</span>
            </button>
          ))}
        </div>
        {['plus', 'route', 'copy'].map((i) => <span key={i} className="flex h-8 w-8 items-center justify-center rounded-md text-[#A7A7A7] ring-1 ring-[#1E1E1E] hover:text-white"><DotIcon name={i} size={12} /></span>)}
      </div>
      {tab === 'jobs' ? (
        <div className="grid grid-cols-[750px_1fr] gap-6 p-6">
          <div className="flex flex-col gap-4">
            <div className="rounded-lg bg-[#141414] p-4 ring-1 ring-[#1E1E1E]"><Heatmap /></div>
            {JOBS.map((j, i) => (
              <button key={j.t} type="button" onClick={() => setSel(i)}
                className={`group relative rounded-lg p-5 text-left ring-1 transition-[background,box-shadow] ${sel === i ? 'bg-[#141414] ring-[#FF5A1F]/60' : 'bg-[#121212] ring-[#1E1E1E] hover:ring-[#313131]'} ${i === 2 ? 'opacity-50' : ''}`}>
                <div className="flex items-start justify-between">
                  <span className="text-[19px] font-medium text-white">{j.t}</span>
                  <span onClick={(e) => { e.stopPropagation(); copy(i) }} role="button" tabIndex={-1}
                    className="relative flex h-8 items-center gap-1.5 rounded-md bg-[#1E1E1E] px-2.5 font-mono text-[11px] text-[#A7A7A7] opacity-0 ring-1 ring-[#313131] transition-opacity hover:text-white group-hover:opacity-100">
                    <DotIcon name={copied === i ? 'check' : 'copy'} size={10} />{copied === i ? 'Copied' : 'Copy command'}
                  </span>
                </div>
                <div className="mt-3 flex flex-wrap items-center gap-2 text-[13px]">
                  <span className="rounded bg-[#FF5A1F]/15 px-2 py-0.5 text-[#FF8A5C]">Done</span>
                  <span className="rounded bg-[#1E1E1E] px-2 py-0.5 font-mono text-[12px] text-white">{j.from} → {j.to}</span>
                  <span className="rounded bg-[#1E1E1E] px-2 py-0.5 font-mono text-[12px] text-[#A7A7A7]">{j.eng}</span>
                </div>
                <div className="mt-3 flex gap-5 text-[13.5px] text-[#A7A7A7]"><span><b className="font-medium text-white">Files</b> {j.n}</span><span><b className="font-medium text-white">Size</b> {j.size}</span></div>
              </button>
            ))}
          </div>
          <AnimatePresence mode="wait">
            <motion.div key={sel} initial={{ opacity: 0, x: 8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -8 }} transition={{ duration: 0.2 }}
              className="rounded-lg bg-[#141414] p-6 ring-1 ring-[#1E1E1E]">
              <p className="text-[20px] font-medium leading-snug text-white">{job.t}</p>
              <div className="mt-6 flex h-14 items-end gap-[3px]">
                {Array.from({ length: 34 }, (_, i) => <span key={i} className="w-[6px] rounded-t-[2px] bg-[#FF5A1F]" style={{ height: `${18 + Math.abs(Math.sin(i * 1.7 + sel)) * 80}%`, opacity: i > 26 ? 0.25 : 0.9 }} />)}
              </div>
              <dl className="mt-6 grid grid-cols-[96px_1fr] gap-y-3 text-[14px]">
                {[['Status', 'Done'], ['Route', `${job.from.split('.').pop()?.toUpperCase()} → ${job.to}`], ['Engine', job.eng], ['Output', 'Beside the original'], ['Original', 'Untouched']].map(([k, v]) => (
                  <div key={k} className="contents"><dt className="text-[#7C7C7C]">{k}</dt><dd className="text-white">{v}</dd></div>
                ))}
              </dl>
              <p className="mt-6 border-t border-[#1E1E1E] pt-5 font-mono text-[11.5px] leading-relaxed text-[#7C7C7C]">{job.cmd}</p>
            </motion.div>
          </AnimatePresence>
        </div>
      ) : (
        <div className="grid grid-cols-6 gap-3 p-6">
          {['MOV', 'MP4', 'GIF', 'WEBM', 'MKV', 'AVI', 'HEIC', 'JPG', 'PNG', 'WEBP', 'TIFF', 'AVIF', 'PDF', 'DOCX', 'MD', 'EPUB', 'HTML', 'RTF', 'MP3', 'M4A', 'WAV', 'FLAC', 'OGG', 'OPUS'].map((f, i) => (
            <div key={f} className="group flex h-24 flex-col justify-between rounded-lg bg-[#141414] p-3 ring-1 ring-[#1E1E1E] transition-colors hover:bg-white">
              <span className="font-mono text-[11px] text-[#7C7C7C] group-hover:text-black/50">{String(i + 1).padStart(2, '0')}</span>
              <span className="font-mono text-[20px] font-medium text-white group-hover:text-black">{f}</span>
            </div>
          ))}
        </div>
      )}
      <div className="absolute -right-10 bottom-10"><TerminalPanel /></div>
    </div>
  )
}

function ProductSection() {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'center center'] })
  const rotateX = useTransform(scrollYProgress, [0, 1], [16, 0])
  const scale = useTransform(scrollYProgress, [0, 1], [0.92, 1])
  return (
    <section className="relative pb-24">
      <Wrap>
        <motion.div ref={ref} style={{ rotateX, scale, transformPerspective: 1600 }} className="origin-top">
          <Stage w={1290} h={760}><div className="pt-2"><ProductMock /></div></Stage>
        </motion.div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────────── Formats ───────────────────────────── */

const CLOUD = ['MOV', 'HEIC', 'PDF', 'MP3', 'DOCX', 'GIF', 'PNG', 'EPUB', 'WAV', 'MKV', 'JPG', 'SRT', 'WEBP', 'MD', 'M4A', 'TIFF', 'ZIP', 'FLAC', 'AVIF', 'HTML', 'MP4', 'RTF', 'OGG', 'VTT', 'BMP', 'WEBM', 'SVG', 'AIFF', 'PPTX', 'XLSX']
const FORMAT_TABS = [
  { t: 'Every format a file can become', d: 'Drag a video and the wheel offers what video can turn into. Drag a scan and it offers PDF and image formats. Only routes that work for that file appear.' },
  { t: 'A whole folder in one drop', d: 'Drag fifty files and the wheel shows the formats every one of them can reach, then converts them as a batch, each copy beside its original.' },
  { t: 'Favourites at the top of the ring', d: 'Reorder the wheel per file type and hide what you never use, so the format you want is always one short flick away.' },
  { t: 'The same engine, from a script', d: 'anyfmt convert and anyfmt tool run the exact routes the wheel runs, so a shell script, a Shortcut or an agent gets identical results.' },
]

function FormatsSection() {
  const [t, setT] = useState(0)
  return (
    <section className="relative py-28 sm:py-40">
      <Wrap>
        <div className="grid items-center gap-14 lg:grid-cols-[minmax(0,6fr)_minmax(0,6fr)]">
          <div>
            <h2 className="text-[clamp(44px,6.2vw,100px)] font-semibold leading-[0.98] tracking-[-0.055em] text-white">Teach your Mac <span className="whitespace-nowrap"><Pixel>every</Pixel> <Obj a="folder" alt="A folder of documents" rot={6} /> format</span></h2>
            <p className="mt-10 max-w-[520px] text-[clamp(18px,1.6vw,23px)] leading-[1.5] text-[#A7A7A7]">Screen recordings, phone photos, scanned contracts, voice memos, ebooks, subtitles. anyfmt reads them all and writes what you actually need.</p>
            <Ctas className="mt-9" />
          </div>
          <div className="relative aspect-square w-full [mask-image:radial-gradient(circle_at_center,black_38%,transparent_72%)]">
            <div className="grid h-full grid-cols-6 gap-2.5">
              {CLOUD.slice(0, 36).concat(CLOUD.slice(0, 6)).slice(0, 36).map((f, i) => (
                <motion.div key={i} initial={{ opacity: 0, scale: 0.85 }} whileInView={{ opacity: 1, scale: 1 }} viewport={{ once: true }} transition={{ delay: (i % 6) * 0.04 + Math.floor(i / 6) * 0.05 }}
                  className="group flex items-center justify-center rounded-lg bg-[#141414] ring-1 ring-[#1E1E1E] transition-colors duration-200 hover:bg-[#FF5A1F]">
                  <span className="font-mono text-[clamp(10px,1.1vw,14px)] font-medium tracking-[0.06em] text-[#A7A7A7] transition-colors group-hover:text-black">{f}</span>
                </motion.div>
              ))}
            </div>
          </div>
        </div>
        <div className="mt-24 grid gap-12 lg:grid-cols-[minmax(0,6fr)_minmax(0,6fr)]">
          <div className="flex flex-col">
            {FORMAT_TABS.map((x, i) => (
              <button key={x.t} type="button" onClick={() => setT(i)} onPointerEnter={() => setT(i)}
                className={`relative py-4 text-left text-[clamp(20px,2.1vw,30px)] font-medium tracking-[-0.03em] transition-colors ${i === t ? 'text-white' : 'text-[#7C7C7C] hover:text-[#A7A7A7]'}`}>
                {x.t}
                {i === t && <motion.span layoutId="fmt-tab" className="absolute bottom-0 left-0 h-px w-1/4 bg-white" />}
              </button>
            ))}
            <span className="h-px w-full bg-[#1E1E1E]" />
          </div>
          <div className="flex flex-col justify-end">
            <AnimatePresence mode="wait">
              <motion.p key={t} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }} transition={{ duration: 0.22 }}
                className="max-w-[560px] text-[clamp(18px,1.6vw,22px)] leading-[1.5] text-[#A7A7A7]">{FORMAT_TABS[t].d}</motion.p>
            </AnimatePresence>
            <a href="#" onClick={(e) => e.preventDefault()} className="group mt-8 flex w-fit items-center gap-2 text-[17px] font-medium text-white">
              See the format matrix<span className="transition-transform group-hover:translate-x-1"><DotIcon name="arrow" size={12} /></span>
            </a>
          </div>
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────────── Pipeline orbit ───────────────────────────── */

const STEPS_ORBIT = [
  { t: 'TRANSCODE', x: 20, y: 22 }, { t: 'RESIZE', x: 78, y: 10 }, { t: 'COMPRESS', x: 86, y: 44 }, { t: 'TRIM', x: 10, y: 50 },
  { t: 'STRIP METADATA', x: 74, y: 76 }, { t: 'NORMALISE', x: 26, y: 82 }, { t: 'MERGE', x: 54, y: 96 }, { t: 'READ QR', x: 40, y: 6 },
]

function PipelineSection() {
  const [hot, setHot] = useState<string | null>(null)
  return (
    <section className="relative overflow-hidden py-28 sm:py-36">
      <Wrap className="relative z-10 text-center">
        <h2 className={`${H2} mx-auto max-w-[13ch]`}>The hard part <Obj a="chrome" alt="A chrome document" rot={-8} /> happens <Pixel>out of sight</Pixel></h2>
        <p className="mx-auto mt-9 max-w-[640px] text-[clamp(18px,1.6vw,22px)] leading-[1.5] text-[#A7A7A7]">
          ffmpeg, pandoc, ImageIO, AVFoundation, VideoToolbox, Vision and Quartz ship inside the app and pick the fastest route for each file. You never see a settings page unless you want one.
        </p>
        <Ctas className="mt-9 justify-center" />
      </Wrap>
      <div className="relative mx-auto mt-10 aspect-[16/9] w-full max-w-[1320px]">
        <svg viewBox="0 0 1600 900" className="absolute inset-0 h-full w-full" aria-hidden>
          {[{ rx: 720, ry: 240, r: -8 }, { rx: 560, ry: 340, r: 16 }, { rx: 420, ry: 190, r: 34 }].map((e, i) => (
            <g key={i} transform={`translate(800 460) rotate(${e.r})`}>
              <ellipse rx={e.rx} ry={e.ry} fill="none" stroke="#4A4A4A" strokeWidth="1.5" strokeDasharray="4 9" />
              {[0, 1, 2, 3, 4].map((k) => (
                <rect key={k} width="9" height="9" x="-4.5" y="-4.5" fill={C.accent}>
                  <animateMotion dur={`${18 + i * 6}s`} begin={`${-k * (3.6 + i)}s`} repeatCount="indefinite" path={`M ${e.rx} 0 A ${e.rx} ${e.ry} 0 1 1 ${-e.rx} 0 A ${e.rx} ${e.ry} 0 1 1 ${e.rx} 0`} />
                </rect>
              ))}
            </g>
          ))}
        </svg>
        <div className="absolute left-1/2 top-[51%] w-[15%] -translate-x-1/2 -translate-y-1/2">
          <div className="pointer-events-none absolute inset-[-55%] rounded-full bg-[radial-gradient(circle,rgba(255,90,31,.35),transparent_60%)] blur-2xl" />
          <Dither src={ASSETS.cassette.src} ratio={ASSETS.cassette.ratio} alt="" className="w-full" pixel={3} levels={4} resolved={hot !== null} />
          <p className="mt-4 text-center font-mono text-[11px] uppercase tracking-[0.16em] text-[#A7A7A7]">{hot ?? 'on-device'}</p>
        </div>
        {STEPS_ORBIT.map((e) => (
          <button key={e.t} type="button" onPointerEnter={() => setHot(e.t)} onPointerLeave={() => setHot(null)} onFocus={() => setHot(e.t)} onBlur={() => setHot(null)}
            className="group absolute flex -translate-x-1/2 -translate-y-1/2 items-center gap-2 rounded-md bg-[#0A0A0A] px-2.5 py-1.5 font-mono text-[11px] tracking-[0.14em] text-white ring-1 ring-[#313131] transition-colors hover:bg-white hover:text-black hover:ring-white sm:px-3.5 sm:py-2 sm:text-[14px]"
            style={{ left: `${e.x}%`, top: `${e.y}%` }}>
            {e.t}<DotIcon name="plus" size={9} className="transition-transform duration-300 group-hover:rotate-90" />
          </button>
        ))}
      </div>
    </section>
  )
}

/* ───────────────────────────── Second proof row ───────────────────────────── */

function ProofRow() {
  return (
    <section className="pb-28 sm:pb-36">
      <Wrap className="grid gap-5 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
        <div className="relative overflow-hidden rounded-lg bg-[#FF5A1F] p-8 text-black sm:p-12">
          <div className="absolute inset-0 opacity-[0.3]"><AsciiField cell={13} density={0.22} ink="#000" /></div>
          <div className="relative">
            <DotIcon name="route" size={22} />
            <p className="mt-8 max-w-[24ch] text-[clamp(26px,3vw,40px)] font-medium leading-[1.1] tracking-[-0.035em]">If two formats can meet, anyfmt finds the road: direct, or through up to three steps.</p>
            <p className="mt-8 max-w-[46ch] text-[16px] leading-relaxed text-black/70">Routed conversions are tested end to end like direct ones, so a DOCX to EPUB to MOBI hop is as dependable as JPG to PNG.</p>
          </div>
        </div>
        <div className="flex flex-col justify-between rounded-lg bg-[#141414] p-8 ring-1 ring-inset ring-[#1E1E1E] sm:p-12">
          <div className="flex items-start gap-2 text-[clamp(84px,10vw,150px)] leading-[0.9] text-white">
            <span className="mt-[0.18em] text-[#FF5A1F]"><DotIcon name="plus" size={26} /></span><Pixel cell={0.04} auto={6800}>516</Pixel>
          </div>
          <div className="mt-10">
            <p className="text-[18px] font-medium">On the wheel by default</p>
            <p className="mt-1.5 text-[15px] leading-relaxed text-[#A7A7A7]">The rest are a settings toggle away.</p>
          </div>
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────────── Sticky globe walkthrough ───────────────────────────── */

const GLOBE_FORMATS: { t: string; lat: number; lon: number }[] = [
  { t: 'MOV', lat: 28, lon: -40 }, { t: 'GIF', lat: -10, lon: 30 }, { t: 'HEIC', lat: 48, lon: 70 }, { t: 'JPG', lat: 10, lon: 120 },
  { t: 'DOCX', lat: -36, lon: -100 }, { t: 'PDF', lat: 18, lon: -150 }, { t: 'M4A', lat: -50, lon: 10 }, { t: 'MP3', lat: 60, lon: -110 },
  { t: 'PNG', lat: -20, lon: 170 }, { t: 'EPUB', lat: 36, lon: 160 }, { t: 'WEBM', lat: -64, lon: -60 }, { t: 'FLAC', lat: 4, lon: -80 },
]
const WALK = [
  { from: 0, to: 1, n: '01', t: 'Pick up any file', d: 'From Finder, the desktop, Mail or a download bar. anyfmt notices the drag the moment it starts; there is no app to open first.' },
  { from: 2, to: 3, n: '02', t: 'Tap a key', d: 'Shift for formats, Command for tools, Control for actions. Tap it and let go; the wheel stays open until you drop or cancel.' },
  { from: 4, to: 5, n: '03', t: 'Aim at what you want', d: 'Only the formats that file can become appear, favourites first. Move toward one and it lights up. Arrow keys work too.' },
  { from: 6, to: 7, n: '04', t: 'Let go', d: 'A small progress window counts down and the new copy lands beside the original, named so you can find it, with the original untouched.' },
]

function Globe({ step }: { step: number }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const stepRef = useRef(step)
  const stepAt = useRef(0)
  useEffect(() => { stepRef.current = step; stepAt.current = performance.now() }, [step])
  const visible = useInView(ref)
  useEffect(() => {
    const c = ref.current
    if (!c || !visible) return
    const ctx = c.getContext('2d')!
    let raf = 0, size = 0
    let rot = 0
    const reduced = reducedMotion()
    const resize = () => { const dpr = Math.min(2, window.devicePixelRatio || 1); size = c.getBoundingClientRect().width; c.width = c.height = Math.round(size * dpr); ctx.setTransform(dpr, 0, 0, dpr, 0, 0) }
    const tilt = 0.32
    const proj = (lat: number, lon: number, R: number, lift = 1) => {
      const p = (lat * Math.PI) / 180, l = (lon * Math.PI) / 180 + rot
      const x = Math.cos(p) * Math.sin(l), y = Math.sin(p), z = Math.cos(p) * Math.cos(l)
      const y2 = y * Math.cos(tilt) - z * Math.sin(tilt), z2 = y * Math.sin(tilt) + z * Math.cos(tilt)
      return { x: size / 2 + x * R * lift, y: size / 2 - y2 * R * lift, z: z2 }
    }
    const draw = (now: number) => {
      const R = size * 0.42
      const w = WALK[stepRef.current]
      const a = GLOBE_FORMATS[w.from], b = GLOBE_FORMATS[w.to]
      const target = -(((a.lon + b.lon) / 2) * Math.PI) / 180
      let d = target - rot
      d = Math.atan2(Math.sin(d), Math.cos(d))
      rot += reduced ? d : d * 0.04 + 0.0006
      ctx.clearRect(0, 0, size, size)
      ctx.lineWidth = 1
      const line = (pts: { x: number; y: number; z: number }[]) => {
        for (let i = 1; i < pts.length; i++) {
          ctx.strokeStyle = pts[i].z > 0 ? 'rgba(255,255,255,.22)' : 'rgba(255,255,255,.06)'
          ctx.beginPath(); ctx.moveTo(pts[i - 1].x, pts[i - 1].y); ctx.lineTo(pts[i].x, pts[i].y); ctx.stroke()
        }
      }
      for (let lat = -60; lat <= 60; lat += 30) line(Array.from({ length: 73 }, (_, i) => proj(lat, i * 5 - 180, R)))
      for (let lon = -180; lon < 180; lon += 30) line(Array.from({ length: 37 }, (_, i) => proj(i * 5 - 90, lon, R)))
      ctx.strokeStyle = 'rgba(255,255,255,.35)'
      ctx.beginPath(); ctx.arc(size / 2, size / 2, R, 0, Math.PI * 2); ctx.stroke()
      // arc between the step's two formats
      const k = Math.min(1, (now - stepAt.current) / 900)
      const arc: { x: number; y: number; z: number }[] = []
      for (let i = 0; i <= 40 * k; i++) {
        const t = i / 40
        arc.push(proj(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t, R, 1 + Math.sin(Math.PI * t) * 0.22))
      }
      ctx.setLineDash([3, 6]); ctx.strokeStyle = C.accent; ctx.lineWidth = 1.6
      ctx.beginPath(); arc.forEach((p, i) => (i ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y))); ctx.stroke(); ctx.setLineDash([])
      if (arc.length) { const head = arc[arc.length - 1]; ctx.fillStyle = C.accent; ctx.fillRect(head.x - 5, head.y - 5, 10, 10) }
      ctx.font = '600 12px "JetBrains Mono Variable", monospace'; ctx.textAlign = 'center'
      GLOBE_FORMATS.forEach((f, i) => {
        const p = proj(f.lat, f.lon, R)
        const on = i === w.from || i === w.to
        if (p.z < -0.15 && !on) return
        ctx.globalAlpha = p.z < 0 ? 0.35 : 1
        ctx.fillStyle = on ? C.accent : '#3a3a3a'
        ctx.fillRect(p.x - (on ? 6 : 4), p.y - (on ? 6 : 4), on ? 12 : 8, on ? 12 : 8)
        if (on || p.z > 0.55) { ctx.fillStyle = on ? '#fff' : '#7C7C7C'; ctx.fillText(f.t, p.x, p.y - 14) }
        ctx.globalAlpha = 1
      })
      if (!reduced) raf = requestAnimationFrame(draw)
    }
    resize()
    raf = requestAnimationFrame(draw)
    const ro = new ResizeObserver(resize)
    ro.observe(c)
    return () => { cancelAnimationFrame(raf); ro.disconnect() }
  }, [visible])
  return <canvas ref={ref} aria-hidden className="aspect-square w-full" />
}

function StepCard({ i }: { i: number }) {
  if (i === 0) return (
    <div className="rounded-lg bg-[#141414] p-4 ring-1 ring-[#1E1E1E]">
      {['Screen Recording 2026-10-21.mov', 'contract-signed.pdf', 'IMG_2041.heic', 'interview.m4a'].map((f, k) => (
        <div key={f} className={`flex items-center justify-between rounded-md px-3 py-2.5 font-mono text-[13px] ${k === 0 ? 'bg-[#FF5A1F] text-black' : 'text-[#A7A7A7]'}`}>
          <span className="flex items-center gap-2.5"><DotIcon name={k === 0 ? 'play' : 'copy'} size={10} />{f}</span><span>{['48.2 MB', '1.2 MB', '3.4 MB', '22 MB'][k]}</span>
        </div>
      ))}
    </div>
  )
  if (i === 1) return (
    <div className="flex items-center gap-3 rounded-lg bg-[#141414] p-6 ring-1 ring-[#1E1E1E]">
      {[['shift', 'shift', true], ['command', '⌘ cmd', false], ['control', 'ctrl', false]].map(([ic, l, on]) => (
        <motion.span key={String(l)} animate={on ? { y: [0, 3, 0] } : {}} transition={{ duration: 0.5, repeat: Infinity, repeatDelay: 1.2 }}
          className={`flex h-16 flex-1 items-end justify-between rounded-md p-3 font-mono text-[13px] ring-1 ${on ? 'bg-white text-black ring-white shadow-[0_3px_0_#7C7C7C]' : 'text-[#A7A7A7] ring-[#313131] shadow-[0_3px_0_#1E1E1E]'}`}>
          {l}<DotIcon name={String(ic)} size={12} />
        </motion.span>
      ))}
    </div>
  )
  if (i === 2) return <WheelCard sub="CONVERT" center="clip.mov" items={['GIF', 'MP4', 'WEBM', 'MKV', 'MP3', 'M4A', 'AVI', 'WMV']} />
  return (
    <div className="rounded-lg bg-[#141414] p-5 ring-1 ring-[#1E1E1E]">
      <div className="flex justify-between font-mono text-[13px]"><span className="text-white">clip.mov → clip.gif</span><span className="text-[#FF5A1F]">done</span></div>
      <div className="mt-3 flex gap-[3px]">{Array.from({ length: 36 }, (_, k) => <span key={k} className="h-2.5 flex-1 rounded-[1px] bg-[#FF5A1F]" />)}</div>
      <div className="mt-5 flex items-center gap-3 rounded-md bg-[#0A0A0A] p-3 ring-1 ring-[#1E1E1E]">
        <Dither src={ASSETS.film.src} ratio={ASSETS.film.ratio} alt="" style={{ height: 44 }} interactive={false} pixel={2} levels={4} />
        <div className="font-mono text-[12.5px]"><p className="text-white">clip.gif</p><p className="text-[#7C7C7C]">6.1 MB · beside clip.mov</p></div>
        <span className="ml-auto text-[#FF5A1F]"><DotIcon name="check" size={14} /></span>
      </div>
    </div>
  )
}

function WalkSection() {
  const [step, setStep] = useState(0)
  const [wide, setWide] = useState(() => typeof window !== 'undefined' && window.matchMedia('(min-width: 1024px)').matches)
  useEffect(() => {
    const mq = window.matchMedia('(min-width: 1024px)')
    const on = () => setWide(mq.matches)
    mq.addEventListener('change', on)
    return () => mq.removeEventListener('change', on)
  }, [])
  const refs = useRef<(HTMLDivElement | null)[]>([])
  useEffect(() => {
    const io = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) setStep(Number((e.target as HTMLElement).dataset.i)) }), { rootMargin: '-45% 0px -45% 0px' })
    refs.current.forEach((r) => r && io.observe(r))
    return () => io.disconnect()
  }, [])
  return (
    <section className="relative">
      <Wrap className="pb-10 pt-24 text-center sm:pt-32">
        <h2 className={`${H2} mx-auto max-w-[12ch]`}>Your Mac, <Obj a="film" alt="A film canister" rot={-6} /> fluent in <Pixel>files</Pixel></h2>
        <p className="mx-auto mt-9 max-w-[600px] text-[clamp(18px,1.6vw,22px)] leading-[1.5] text-[#A7A7A7]">Four moves, a second or two, and no window to manage. Here is the whole thing.</p>
        <Ctas className="mt-9 justify-center" />
      </Wrap>
      <Wrap className="grid gap-10 lg:grid-cols-[minmax(0,6fr)_minmax(0,5fr)]">
        <div className="sticky top-0 hidden h-[100svh] items-center lg:flex"><div className="w-full max-w-[640px] -translate-x-[8%]"><Globe step={step} /></div></div>
        <div>
          {WALK.map((w, i) => (
            <div key={w.n} ref={(el) => { refs.current[i] = el }} data-i={i} className="flex flex-col justify-center py-12 lg:min-h-[80svh] lg:py-10">
              <motion.div animate={{ opacity: !wide || step === i ? 1 : 0.35 }} transition={{ duration: 0.4 }}>
                <StepCard i={i} />
                <h3 className="mt-10 flex items-baseline gap-4 text-[clamp(28px,3vw,44px)] font-medium tracking-[-0.035em] text-white">
                  <span className="font-serif text-[0.9em] text-[#FF5A1F]">{w.n}</span>{w.t}
                </h3>
                <p className="mt-4 max-w-[520px] text-[clamp(17px,1.4vw,21px)] leading-[1.5] text-[#A7A7A7]">{w.d}</p>
              </motion.div>
            </div>
          ))}
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────────── Privacy grid ───────────────────────────── */

function Vignette({ i }: { i: number }) {
  const box = 'h-full w-full rounded-md bg-[#0F0F0F] p-5 ring-1 ring-[#1E1E1E]'
  switch (i) {
    case 0: return (
      <div className={box}>
        <div className="flex items-center justify-between text-[14px] text-white"><span>Wi-Fi</span><span className="flex h-6 w-11 items-center rounded-full bg-[#313131] p-0.5"><span className="h-5 w-5 rounded-full bg-[#7C7C7C]" /></span></div>
        <div className="mt-5 rounded-md bg-[#141414] p-3 font-mono text-[12px] ring-1 ring-[#1E1E1E]"><span className="text-white">interview.m4a → mp3</span><div className="mt-2 h-1.5 overflow-hidden rounded bg-[#1E1E1E]"><motion.span className="block h-full bg-[#FF5A1F]" animate={{ width: ['10%', '100%'] }} transition={{ duration: 2.4, repeat: Infinity }} /></div></div>
      </div>
    )
    case 1: return (
      <div className={`${box} flex flex-col justify-center gap-2 font-mono text-[13px]`}>
        <div className="flex justify-between rounded-md px-3 py-2.5 text-[#A7A7A7] ring-1 ring-[#1E1E1E]"><span>photo.heic</span><span>original</span></div>
        <motion.div initial={{ opacity: 0, x: -8 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true }} transition={{ delay: 0.3 }} className="flex justify-between rounded-md bg-white px-3 py-2.5 text-black"><span>photo.jpg</span><span>new copy</span></motion.div>
      </div>
    )
    case 2: return (
      <div className={`${box} font-mono text-[12.5px]`}>
        {[['Camera', 'iPhone 16 Pro'], ['Taken', '21 Oct 2026, 09:14'], ['GPS', '51.5072, -0.1276'], ['Owner', 'Your name']].map(([k, v], n) => (
          <div key={k} className="flex justify-between border-b border-[#1E1E1E] py-2 last:border-0"><span className="text-[#7C7C7C]">{k}</span>
            <span className="relative text-white">{v}{n >= 2 && <motion.span className="absolute inset-0 bg-[#FF5A1F]" initial={{ scaleX: 0 }} whileInView={{ scaleX: 1 }} viewport={{ once: true }} style={{ originX: 0 }} transition={{ delay: 0.4 + n * 0.15 }} />}</span></div>
        ))}
      </div>
    )
    case 3: return (
      <div className={box}>
        <div className="flex justify-between font-mono text-[12.5px]"><span className="text-white">142 files → JPG</span><span className="text-[#A7A7A7]">87 / 142</span></div>
        <div className="mt-4 grid grid-cols-[repeat(24,1fr)] gap-[3px]">{Array.from({ length: 144 }, (_, k) => <span key={k} className="aspect-square rounded-[1px]" style={{ background: k < 87 ? C.accent : C.iron }} />)}</div>
      </div>
    )
    case 4: return (
      <div className={`${box} flex flex-col justify-center gap-3 text-[14px]`}>
        {[['Convert', '⇧ Shift'], ['Edit', '⌘ Command'], ['Act', '⌃ Control']].map(([k, v], n) => (
          <div key={k} className="flex items-center justify-between"><span className="text-[#A7A7A7]">{k}</span><span className={`flex items-center gap-2 rounded-md px-3 py-1.5 font-mono text-[12.5px] ring-1 ${n === 0 ? 'text-white ring-[#FF5A1F]' : 'text-white ring-[#313131]'}`}>{v}<DotIcon name="arrow" size={8} className="rotate-90" /></span></div>
        ))}
      </div>
    )
    default: return (
      <div className={`${box} flex items-center justify-around`}>
        {[['AGPL', '3.0'], ['NO', 'ACCOUNT'], ['OFF', 'LINE']].map(([a, b]) => (
          <div key={a} className="flex h-[88px] w-[88px] flex-col items-center justify-center rounded-full font-mono text-[15px] font-semibold leading-tight text-white border border-dashed border-[#7C7C7C]"><span>{a}</span><span className="text-[11px] text-[#A7A7A7]">{b}</span></div>
        ))}
      </div>
    )
  }
}

const PRIVACY = [
  { t: 'Works with Wi-Fi off', d: 'Every conversion, edit and action runs on this Mac. Pull the plug and nothing changes.' },
  { t: 'Never overwrites', d: 'Conversions and edits always write a new copy. The file you started with is never touched.' },
  { t: 'Strip what you share', d: 'View and edit EXIF, IPTC, ID3 and PDF info, or strip it all before a file leaves your hands.' },
  { t: 'Batch without babysitting', d: 'Drop a folder and walk away. Jobs run in parallel across your cores, each in its own progress window.' },
  { t: 'Your keys, your way', d: 'Remap the three trigger keys and the tap threshold if Shift, Command and Control clash with your flow.' },
  { t: 'Free and open source', d: 'AGPL-3.0, no account, no paywall on anything that runs on your Mac, commercial use included.' },
]

function PrivacySection() {
  return (
    <section className="py-28 sm:py-40">
      <Wrap>
        <h2 className={`${H2} max-w-[11ch]`}>Private <Obj a="photo" alt="An instant photo" rot={8} /> by default, at <Pixel>any</Pixel> volume</h2>
        <p className="mt-9 max-w-[640px] text-[clamp(18px,1.6vw,22px)] leading-[1.5] text-[#A7A7A7]">Built for files you would rather not upload: contracts, medical scans, family photos, unreleased work.</p>
        <Ctas className="mt-9" />
        <div className="mt-20 grid gap-x-8 gap-y-14 sm:grid-cols-2 lg:grid-cols-3">
          {PRIVACY.map((p, i) => (
            <div key={p.t} className="group">
              <div className="h-[230px] rounded-lg bg-[#141414] p-6 ring-1 ring-inset ring-[#1E1E1E] transition-colors group-hover:bg-[#171717]"><Vignette i={i} /></div>
              <h3 className="mt-7 text-[24px] font-medium tracking-[-0.025em] text-white">{p.t}</h3>
              <p className="mt-2.5 text-[16.5px] leading-relaxed text-[#A7A7A7]">{p.d}</p>
            </div>
          ))}
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────────── Stories ───────────────────────────── */

function MosaicCard({ s }: { s: (typeof STORIES)[number] }) {
  const [on, setOn] = useState(false)
  const cells = useMemo(() => {
    const h = (n: number) => { const v = Math.sin(n * 12.9898 + 78.233) * 43758.5453; return v - Math.floor(v) }
    return Array.from({ length: 12 * 14 }, (_, i) => ({ i, show: h(i) > 0.45, delay: h(i + 999) }))
  }, [])
  return (
    <a href="#" onClick={(e) => e.preventDefault()} onPointerEnter={() => setOn(true)} onPointerLeave={() => setOn(false)} onFocus={() => setOn(true)} onBlur={() => setOn(false)}
      className="group block w-[min(78vw,400px)] shrink-0 snap-start">
      <div className="relative aspect-[3/4] overflow-hidden rounded-lg bg-[#141414]">
        <img src={s.src} alt="" className="absolute inset-0 h-full w-full object-cover transition-[filter,transform] duration-700" style={{ filter: on ? 'grayscale(0) brightness(1)' : 'grayscale(1) brightness(.55)', transform: on ? 'scale(1.04)' : 'scale(1)' }} />
        <div className="absolute inset-0 grid grid-cols-12 grid-rows-[repeat(14,1fr)]">
          {cells.map((c) => <span key={c.i} className="bg-[#FF5A1F] transition-opacity duration-200" style={{ opacity: c.show && !on ? 0.92 : 0, transitionDelay: `${c.delay * (on ? 260 : 420)}ms` }} />)}
        </div>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="font-mono text-[clamp(30px,3vw,44px)] font-semibold tracking-[-0.02em] text-white mix-blend-difference">{s.route}</span>
        </div>
        <span className="absolute bottom-4 left-4 rounded bg-[#0A0A0A]/80 px-2.5 py-1.5 font-mono text-[11px] uppercase tracking-[0.14em] text-white opacity-0 transition-opacity group-hover:opacity-100">Read the guide</span>
      </div>
      <p className="mt-6 text-[clamp(20px,1.7vw,24px)] font-medium leading-snug tracking-[-0.02em] text-white">{s.t}</p>
    </a>
  )
}

function StoriesSection() {
  const row = useRef<HTMLDivElement>(null)
  const nudge = (d: number) => row.current?.scrollBy({ left: d * 420, behavior: reducedMotion() ? 'auto' : 'smooth' })
  return (
    <section className="py-24 sm:py-32">
      <Wrap className="flex flex-wrap items-end justify-between gap-6">
        <h2 className="text-[clamp(40px,5.6vw,84px)] font-semibold leading-[1] tracking-[-0.05em] text-white">Files people drag every day</h2>
        <div className="flex gap-2">
          <button type="button" aria-label="Previous" onClick={() => nudge(-1)} className="group flex h-11 w-11 items-center justify-center rounded-lg text-white ring-1 ring-[#454545] hover:bg-white hover:text-black"><DotIcon name="arrow" size={12} className="rotate-180" /></button>
          <button type="button" aria-label="Next" onClick={() => nudge(1)} className="group flex h-11 w-11 items-center justify-center rounded-lg text-white ring-1 ring-[#454545] hover:bg-white hover:text-black"><DotIcon name="arrow" size={12} /></button>
          <FrameButton>All guides</FrameButton>
        </div>
      </Wrap>
      <div ref={row} className="mt-14 flex snap-x snap-mandatory scroll-pl-5 gap-6 overflow-x-auto px-5 pb-4 [scrollbar-width:none] sm:scroll-pl-10 sm:px-10 lg:scroll-pl-[max(40px,calc((100vw-1240px)/2))] lg:px-[max(40px,calc((100vw-1240px)/2))]">
        {STORIES.map((s) => <MosaicCard key={s.t} s={s} />)}
      </div>
    </section>
  )
}

/* ───────────────────────────── Page ───────────────────────────── */

export default function SitePage() {
  useEffect(() => { document.title = 'anyfmt · Drag, tap Shift, drop' }, [])
  return (
    <div className="raster min-h-screen overflow-x-clip">
      <RasterStyles />
      <SiteNav />
      <Hero />
      <ProductSection />
      <FormatsSection />
      <ProofSection />
      <PipelineSection />
      <KeysSection className="pb-20 pt-10 sm:pb-28" title={<h2 className={`${H2} max-w-[12ch]`}>A converter in <Obj a="shift" h="0.8em" alt="A shift keycap" rot={-6} /> <Pixel>every</Pixel> drag</h2>} />
      <ProofRow />
      <WalkSection />
      <PrivacySection />
      <StoriesSection />
      <ClosingSection />
      <div className="relative h-36 overflow-hidden border-t border-[#1E1E1E]"><AsciiField density={0.32} cell={13} /></div>
      <Footer />
    </div>
  )
}

