import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { AppDemo } from './Demo'
import { ASSETS } from './assets'
import { AsciiField, C, Dither, DitherButton, DotIcon, Eyebrow, FrameButton, Mark, Pixel, reducedMotion, useInView } from './kit'

export const Wrap = ({ children, className = '' }: { children: ReactNode; className?: string }) =>
  <div className={`mx-auto w-full max-w-[1320px] px-5 sm:px-10 ${className}`}>{children}</div>

/** Inline object sized to the line it sits in. */
export const Obj = ({ a, h = '0.95em', rot = 0, className = '', alt }: { a: keyof typeof ASSETS; h?: string; rot?: number; className?: string; alt: string }) => (
  <Dither src={ASSETS[a].src} ratio={ASSETS[a].ratio} alt={alt} className={`bob mx-[0.06em] -translate-y-[0.04em] ${className}`}
    style={{ height: h, ['--rot' as string]: `${rot}deg`, rotate: `${rot}deg` }} />
)

export const Display = ({ children, className = '' }: { children: ReactNode; className?: string }) => (
  <h2 className={`text-[clamp(44px,8.4vw,132px)] font-semibold leading-[0.98] tracking-[-0.055em] text-white [text-wrap:balance] ${className}`}>{children}</h2>
)

export const Ctas = ({ className = '' }: { className?: string }) => (
  <div className={`flex flex-wrap items-center gap-3 ${className}`}>
    <DitherButton>Download for Mac</DitherButton>
    <FrameButton>Watch it work</FrameButton>
  </div>
)

/* ───────────── Format strip ───────────── */

const STRIP = ['MOV', 'MP4', 'GIF', 'HEIC', 'JPG', 'PNG', 'WEBP', 'PDF', 'DOCX', 'EPUB', 'MP3', 'FLAC', 'SRT', 'ZIP']
export function FormatStrip() {
  return (
    <div className="flex flex-wrap items-center gap-x-7 gap-y-3">
      {STRIP.map((f) => (
        <span key={f} className="group relative cursor-default font-mono text-[15px] font-medium tracking-[0.08em] text-[#7C7C7C] transition-colors hover:text-white">
          {f}<span className="absolute -bottom-1 left-0 h-[2px] w-0 bg-[#FF5A1F] transition-[width] duration-300 [transition-timing-function:steps(4)] group-hover:w-full" />
        </span>
      ))}
    </div>
  )
}

/* ───────────── Keys: Shift / Command / Control ───────────── */

const wedgePath = (i: number, n: number, r0: number, r1: number) => {
  const gap = 0.03, a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap, a1 = a0 + (Math.PI * 2) / n - gap * 2
  const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(2)},${(Math.sin(a) * r).toFixed(2)}`
  return `M${p(r1, a0)} A${r1},${r1} 0 0 1 ${p(r1, a1)} L${p(r0, a1)} A${r0},${r0} 0 0 0 ${p(r0, a0)} Z`
}

/** A wheel you can play with: hover a wedge to light it. */
export function WheelCard({ items, center, sub }: { items: string[]; center: string; sub: string }) {
  const [hot, setHot] = useState(-1)
  const n = items.length
  return (
    <div className="relative flex aspect-[880/520] items-center justify-center overflow-hidden rounded-lg bg-[#141414] ring-1 ring-inset ring-[#1E1E1E]"
      style={{ backgroundImage: `radial-gradient(${C.iron} 1px, transparent 1px)`, backgroundSize: '22px 22px' }}>
      <svg viewBox="-170 -170 340 340" className="h-[86%]" onPointerLeave={() => setHot(-1)}>
        {items.map((t, i) => {
          const a = (i / n) * Math.PI * 2 - Math.PI / 2, m = { x: Math.cos(a) * 112, y: Math.sin(a) * 112 }
          const on = hot === i
          return (
            <g key={t} onPointerEnter={() => setHot(i)} className="cursor-pointer">
              <path d={wedgePath(i, n, 64, 160)} fill={on ? C.accent : C.iron} stroke={on ? C.accent : C.edge} style={{ transition: 'fill .15s' }} />
              <text x={m.x} y={m.y} textAnchor="middle" dominantBaseline="central" fontFamily="JetBrains Mono Variable, monospace" fontSize={n > 7 ? 10.5 : 12} fontWeight={500} fill={on ? '#000' : '#fff'} className="pointer-events-none select-none">{t}</text>
            </g>
          )
        })}
        <circle r={56} fill={C.card} stroke={C.edge} />
        <text y={-7} textAnchor="middle" fontFamily="JetBrains Mono Variable, monospace" fontSize={10} fill={C.mist}>{sub}</text>
        <text y={11} textAnchor="middle" fontFamily="Inter Variable, sans-serif" fontSize={14} fontWeight={600} fill="#fff">{hot >= 0 ? items[hot] : center}</text>
      </svg>
    </div>
  )
}

const KEYS = [
  { key: 'shift', icon: 'shift', title: 'Shift converts', body: 'Mid-drag, tap Shift. A wheel of every format that file can become opens around the pointer. Drop on one; a new copy lands beside the original.' },
  { key: 'command', icon: 'command', title: 'Command edits', body: 'Tap Command instead for 26 tools: compress to a target size, trim, crop, remove a background, normalise loudness, merge PDFs.' },
  { key: 'control', icon: 'control', title: 'Control moves it', body: 'Control opens actions that work on anything, folders included: AirDrop, Float, copy, move, copy path, open in Terminal.' },
]

export function KeysSection() {
  const [active, setActive] = useState(0)
  const [paused, setPaused] = useState(false)
  const box = useRef<HTMLDivElement>(null)
  const inView = useInView(box, '0px')
  useEffect(() => {
    if (paused || !inView || reducedMotion()) return
    const id = window.setTimeout(() => setActive((a) => (a + 1) % 3), 9000)
    return () => clearTimeout(id)
  }, [active, paused, inView])

  return (
    <section ref={box} className="py-28 sm:py-40">
      <Wrap>
        <Display>Three keys. <Pixel>Every</Pixel> file.</Display>
        <div className="mt-16 grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:gap-16" onPointerEnter={() => setPaused(true)} onPointerLeave={() => setPaused(false)}>
          <div className="flex flex-col">
            {KEYS.map((k, i) => (
              <button key={k.key} type="button" onClick={() => setActive(i)}
                className={`group relative border-b border-[#1E1E1E] py-6 text-left outline-none transition-colors focus-visible:bg-white/[0.03] ${i === active ? 'text-white' : 'text-[#7C7C7C] hover:text-[#A7A7A7]'}`}>
                <span className="flex items-center gap-3 text-[clamp(22px,2.2vw,30px)] font-medium tracking-[-0.03em]">
                  <span className={`flex h-9 w-9 items-center justify-center rounded-md ring-1 transition-colors ${i === active ? 'bg-white text-black ring-white' : 'ring-[#313131]'}`}><DotIcon name={k.icon} size={14} /></span>
                  {k.title}
                </span>
                <AnimatePresence initial={false}>
                  {i === active && (
                    <motion.p initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.35, ease: [0.2, 0.9, 0.2, 1] }}
                      className="overflow-hidden pl-12 text-[16px] leading-relaxed text-[#A7A7A7]">
                      <span className="block pt-3">{k.body}</span>
                    </motion.p>
                  )}
                </AnimatePresence>
                {i === active && !paused && (
                  <motion.span key={`bar-${active}`} className="absolute -bottom-px left-0 h-px bg-white" initial={{ width: '0%' }} animate={{ width: '100%' }} transition={{ duration: 9, ease: 'linear' }} />
                )}
              </button>
            ))}
          </div>
          <div className="min-w-0">
            {active === 0 && <AppDemo />}
            {active === 1 && <WheelCard sub="EDIT" center="photo.heic" items={['Compress', 'Resize', 'Crop', 'Adjust', 'Annotate', 'Redact', 'Remove bg', 'Strip meta']} />}
            {active === 2 && <WheelCard sub="ACTIONS" center="Invoices/" items={['AirDrop', 'Float', 'Copy', 'Move', 'Copy path', 'Terminal']} />}
          </div>
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────── Engine orbit ───────────── */

const ENGINES = [
  { t: 'FFMPEG', x: 18, y: 30 }, { t: 'PANDOC', x: 72, y: 12 }, { t: 'IMAGEIO', x: 84, y: 40 }, { t: 'AVFOUNDATION', x: 8, y: 58 },
  { t: 'VIDEOTOOLBOX', x: 76, y: 72 }, { t: 'VISION', x: 30, y: 84 }, { t: 'CORE IMAGE', x: 58, y: 92 }, { t: 'QUARTZ', x: 34, y: 14 },
]

export function EngineSection() {
  const [hot, setHot] = useState<string | null>(null)
  return (
    <section className="relative overflow-hidden py-28 sm:py-40">
      <Wrap className="relative z-10 text-center">
        <Display className="mx-auto max-w-[14ch]">Every engine, <Obj a="chrome" alt="A chrome document" rot={-8} /> already on <Pixel>your Mac</Pixel></Display>
        <p className="mx-auto mt-8 max-w-[600px] text-[clamp(17px,1.5vw,21px)] leading-relaxed text-[#A7A7A7]">
          The converters ship inside the app, so nothing needs installing and nothing gets uploaded. Apple frameworks first, bundled engines for the rest.
        </p>
        <Ctas className="mt-9 justify-center" />
      </Wrap>
      <div className="relative mx-auto mt-14 aspect-[16/9] w-full max-w-[1320px] sm:mt-6">
        <svg viewBox="0 0 1600 900" className="absolute inset-0 h-full w-full" aria-hidden>
          {[{ rx: 700, ry: 230, r: -8 }, { rx: 560, ry: 330, r: 14 }, { rx: 420, ry: 180, r: 30 }].map((e, i) => (
            <g key={i} transform={`translate(800 470) rotate(${e.r})`}>
              <ellipse rx={e.rx} ry={e.ry} fill="none" stroke="#4A4A4A" strokeWidth="1.5" strokeDasharray="4 9" />
              {[0, 1, 2, 3].map((k) => (
                <rect key={k} width="8" height="8" x="-4" y="-4" fill={C.accent}>
                  <animateMotion dur={`${16 + i * 5}s`} begin={`${-k * (4 + i)}s`} repeatCount="indefinite"
                    path={`M ${e.rx} 0 A ${e.rx} ${e.ry} 0 1 1 ${-e.rx} 0 A ${e.rx} ${e.ry} 0 1 1 ${e.rx} 0`} />
                </rect>
              ))}
            </g>
          ))}
        </svg>
        <div className="absolute left-1/2 top-[52%] w-[16%] -translate-x-1/2 -translate-y-1/2">
          <div className="pointer-events-none absolute inset-[-40%] rounded-full bg-[radial-gradient(circle,rgba(255,90,31,.28),transparent_62%)] blur-2xl" />
          <Dither src={ASSETS.chrome.src} ratio={ASSETS.chrome.ratio} alt="" className="w-full" pixel={3} levels={4} resolved={hot !== null} />
          <p className="mt-3 text-center font-mono text-[11px] uppercase tracking-[0.14em] text-[#A7A7A7]">{hot ?? 'one app'}</p>
        </div>
        {ENGINES.map((e) => (
          <button key={e.t} type="button" onPointerEnter={() => setHot(e.t)} onPointerLeave={() => setHot(null)} onFocus={() => setHot(e.t)} onBlur={() => setHot(null)}
            className="group absolute flex -translate-x-1/2 -translate-y-1/2 items-center gap-2 rounded-md bg-[#0A0A0A] px-2.5 py-1.5 font-mono text-[11px] tracking-[0.12em] text-white ring-1 ring-[#313131] transition-colors hover:bg-white hover:text-black hover:ring-white sm:px-3 sm:py-2 sm:text-[13px]"
            style={{ left: `${e.x}%`, top: `${e.y}%` }}>
            {e.t}<DotIcon name="plus" size={9} className="transition-transform group-hover:rotate-45" />
          </button>
        ))}
      </div>
    </section>
  )
}

/* ───────────── Proof ───────────── */

export function ProofSection() {
  return (
    <section className="py-24 sm:py-32">
      <Wrap className="grid gap-5 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
        <div className="relative overflow-hidden rounded-lg bg-[#FF5A1F] p-8 text-black sm:p-12">
          <div className="absolute inset-0 opacity-[0.3]"><AsciiField cell={13} density={0.22} ink="#000" /></div>
          <div className="relative">
            <DotIcon name="lock" size={22} />
            <p className="mt-8 max-w-[22ch] text-[clamp(28px,3.2vw,44px)] font-medium leading-[1.08] tracking-[-0.035em]">Your files stay on your Mac. Not the file, not its name, not a thumbnail.</p>
            <p className="mt-8 max-w-[46ch] text-[16px] leading-relaxed text-black/70">Every conversion and edit runs on-device, offline. Sharing a link is opt-in. And it always writes a new copy, so the original is never touched.</p>
          </div>
        </div>
        <div className="flex flex-col justify-between rounded-lg bg-[#141414] p-8 ring-1 ring-inset ring-[#1E1E1E] sm:p-12">
          <div className="flex items-start gap-2 text-[clamp(84px,10vw,150px)] leading-[0.9] text-white">
            <span className="mt-[0.18em] text-[#FF5A1F]"><DotIcon name="plus" size={26} /></span><Pixel cell={0.04} auto={6000}>793</Pixel>
          </div>
          <div className="mt-10">
            <p className="text-[18px] font-medium">Conversion routes</p>
            <p className="mt-1.5 text-[15px] leading-relaxed text-[#A7A7A7]">Each one run on a real file and checked before it ships.</p>
          </div>
        </div>
      </Wrap>
      <Wrap className="mt-5 grid gap-5 sm:grid-cols-3">
        {[{ i: 'command', n: '26', l: 'Editing tools', d: 'Compress, trim, crop, redact, merge.' }, { i: 'bolt', n: '0', l: 'Installs, accounts, uploads', d: 'Open it and drag. That is the setup.' }, { i: 'check', n: '$0', l: 'For everything on your Mac', d: 'Commercial use included.' }].map((s) => (
          <div key={s.l} className="group rounded-lg bg-[#141414] p-7 ring-1 ring-inset ring-[#1E1E1E] transition-colors hover:bg-[#1E1E1E]">
            <span className="text-[#FF5A1F]"><DotIcon name={s.i} size={18} /></span>
            <p className="mt-6 text-[clamp(44px,4.4vw,64px)] leading-none text-white"><Pixel cell={0.06}>{s.n}</Pixel></p>
            <p className="mt-5 text-[16px] font-medium">{s.l}</p>
            <p className="mt-1 text-[14px] text-[#A7A7A7]">{s.d}</p>
          </div>
        ))}
      </Wrap>
    </section>
  )
}

/* ───────────── Files you have ───────────── */

const FILES: { a: keyof typeof ASSETS; t: string; from: string; to: string[] }[] = [
  { a: 'film', t: 'Screen recordings', from: '.mov', to: ['GIF', 'MP4', 'WEBM', 'MP3'] },
  { a: 'photo', t: 'iPhone photos', from: '.heic', to: ['JPG', 'PNG', 'WEBP', 'PDF'] },
  { a: 'folder', t: 'Documents and scans', from: '.docx', to: ['PDF', 'MD', 'EPUB', 'HTML'] },
  { a: 'cassette', t: 'Voice memos', from: '.m4a', to: ['MP3', 'WAV', 'FLAC', 'OPUS'] },
]

export function FilesSection() {
  return (
    <section className="py-24 sm:py-32">
      <Wrap>
        <div className="flex flex-wrap items-end justify-between gap-6">
          <Display className="max-w-[12ch]">The files you <Pixel>actually</Pixel> have</Display>
          <FrameButton>See all formats</FrameButton>
        </div>
        <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {FILES.map((f) => <FileCard key={f.t} {...f} />)}
        </div>
      </Wrap>
    </section>
  )
}

function FileCard({ a, t, from, to }: (typeof FILES)[number]) {
  const [on, setOn] = useState(false)
  return (
    <div onPointerEnter={() => setOn(true)} onPointerLeave={() => setOn(false)} className="group">
      <div className="relative flex aspect-[4/5] items-center justify-center overflow-hidden rounded-lg bg-[#141414] ring-1 ring-inset ring-[#1E1E1E] transition-colors group-hover:bg-[#161616]">
        <div className="absolute inset-0 opacity-50"><AsciiField cell={12} density={0.05} focus={{ x: 0.5, y: 0.5, r: 0.5, boost: 0.5 }} /></div>
        <Dither src={ASSETS[a].src} ratio={ASSETS[a].ratio} alt={t} resolved={on} pixel={4} levels={3} className="relative w-[62%] transition-transform duration-500 group-hover:scale-105" />
        <span className="absolute left-4 top-4 rounded bg-[#0A0A0A] px-2 py-1 font-mono text-[11px] tracking-[0.1em] text-[#A7A7A7] ring-1 ring-[#313131]">{from}</span>
      </div>
      <p className="mt-5 text-[19px] font-medium tracking-[-0.02em]">{t}</p>
      <div className="mt-3 flex flex-wrap gap-1.5">
        {to.map((x, i) => (
          <span key={x} className="rounded bg-[#1E1E1E] px-2 py-1 font-mono text-[11px] tracking-[0.08em] text-[#A7A7A7] transition-colors duration-200 group-hover:bg-white group-hover:text-black"
            style={{ transitionDelay: `${i * 60}ms` }}>{x}</span>
        ))}
      </div>
    </div>
  )
}

/* ───────────── Closing ───────────── */

const BUBBLES = [
  { t: 'GIF', x: 14, y: 18, s: 120 }, { t: 'PDF', x: 88, y: 22, s: 140, hot: true }, { t: 'HEIC', x: 8, y: 62, s: 104 },
  { t: 'MP4', x: 90, y: 56, s: 116 }, { t: 'DOCX', x: 26, y: 88, s: 96 }, { t: 'WEBP', x: 72, y: 90, s: 108 }, { t: 'MP3', x: 50, y: 6, s: 88 },
]

export function ClosingSection() {
  const box = useRef<HTMLDivElement>(null)
  const [p, setP] = useState({ x: -1, y: -1 })
  return (
    <section className="relative overflow-hidden py-24 sm:py-36">
      <AsciiField density={0.08} />
      <div ref={box} className="relative mx-auto max-w-[1320px] px-5 sm:px-10"
        onPointerMove={(e) => { const r = box.current!.getBoundingClientRect(); setP({ x: (e.clientX - r.left) / r.width * 100, y: (e.clientY - r.top) / r.height * 100 }) }}
        onPointerLeave={() => setP({ x: -1, y: -1 })}>
        <div className="relative py-16 text-center sm:py-24">
          {BUBBLES.map((b, i) => {
            const dx = b.x - p.x, dy = b.y - p.y, d = Math.hypot(dx, dy), push = p.x < 0 ? 0 : Math.max(0, 18 - d) * 1.4
            return (
              <motion.span key={b.t} aria-hidden className="absolute hidden items-center justify-center rounded-full font-mono font-medium tracking-[0.06em] sm:flex"
                style={{ left: `${b.x}%`, top: `${b.y}%`, width: b.s, height: b.s, marginLeft: -b.s / 2, marginTop: -b.s / 2, fontSize: b.s / 5.5,
                  background: b.hot ? C.accent : C.iron, color: b.hot ? '#000' : '#fff', boxShadow: `inset 0 0 0 1px ${b.hot ? C.accent : C.edge}` }}
                animate={{ x: d ? (dx / d) * push : 0, y: [d ? (dy / d) * push : 0, (d ? (dy / d) * push : 0) - 8, d ? (dy / d) * push : 0] }}
                transition={{ x: { type: 'spring', stiffness: 120, damping: 14 }, y: { duration: 5 + i, repeat: Infinity, ease: 'easeInOut' } }}>
                {b.t}
              </motion.span>
            )
          })}
          <Display className="relative mx-auto max-w-[11ch]">Stop uploading files to <Pixel auto={5200}>strangers</Pixel></Display>
          <p className="relative mx-auto mt-8 max-w-[520px] text-[clamp(17px,1.5vw,20px)] leading-relaxed text-[#A7A7A7]">Converter websites want your file first. anyfmt does the work right here, offline, in the time it takes to let go.</p>
          <Ctas className="relative mt-10 justify-center" />
        </div>
      </div>
    </section>
  )
}

/* ───────────── Footer ───────────── */

const COLS: [string, string[]][] = [
  ['Product', ['Formats', 'Tools', 'Actions', 'Float', 'CLI', 'Changelog']],
  ['Keys', ['Shift: convert', 'Command: edit', 'Control: act', 'Remap keys']],
  ['Resources', ['Docs', 'Format matrix', 'Privacy', 'Licences']],
  ['Project', ['GitHub', 'Releases', 'Report a bug', 'Contact']],
]

export function Footer() {
  return (
    <footer className="relative border-t border-[#1E1E1E] pb-14 pt-20">
      <Wrap>
        <div className="grid gap-12 sm:grid-cols-2 lg:grid-cols-[minmax(0,4fr)_repeat(4,minmax(0,2fr))]">
          <div>
            <div className="flex items-center gap-2.5 text-[20px] font-semibold tracking-[-0.03em]"><Mark />anyfmt</div>
            <p className="mt-4 max-w-[30ch] text-[14px] leading-relaxed text-[#A7A7A7]">Drag a file, tap Shift, drop it on the format you want. Free and open source, for macOS.</p>
          </div>
          {COLS.map(([h, links]) => (
            <div key={h}>
              <Eyebrow>{h}</Eyebrow>
              <ul className="mt-5 flex flex-col gap-3">
                {links.map((l) => <li key={l}><a href="#" onClick={(e) => e.preventDefault()} className="nav-pixel relative -ml-3.5 rounded px-3.5 py-1 text-[15px] text-white/90 hover:text-white">{l}</a></li>)}
              </ul>
            </div>
          ))}
        </div>
        <div className="mt-20 flex flex-wrap items-center justify-between gap-4 font-mono text-[12px] uppercase tracking-[0.12em] text-[#7C7C7C]">
          <span>anyfmt.app · AGPL-3.0</span>
          <span>Made for macOS 13 and later</span>
        </div>
      </Wrap>
    </footer>
  )
}
