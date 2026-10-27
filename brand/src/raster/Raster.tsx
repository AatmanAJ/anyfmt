import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { AppDemo } from './Demo'
import { ASSETS } from './assets'
import { AsciiField, C, Dither, DotIcon, Eyebrow, Nav, Pixel, RasterStyles, reducedMotion, useInView } from './kit'
import { ClosingSection, Ctas, EngineSection, FilesSection, Footer, FormatStrip, KeysSection, Obj, ProofSection, Wrap } from './Sections'

const HERO_H1 = 'text-[clamp(54px,10.6vw,180px)] font-semibold leading-[0.93] tracking-[-0.062em] text-white'

/* ───────────── 1 · Resample ───────────── */

function HeroResample() {
  return (
    <section className="relative flex min-h-[100svh] flex-col overflow-hidden">
      <AsciiField focus={{ x: 0.5, y: 0.66, r: 0.3, boost: 0.6 }} />
      <Nav />
      <Wrap className="relative flex flex-1 flex-col pb-14 pt-32 sm:pt-40">
        <div className="flex flex-wrap items-start justify-between gap-10">
          <div className="max-w-[640px]">
            <p className="text-[clamp(20px,1.9vw,27px)] leading-[1.38] tracking-[-0.02em] text-[#A7A7A7]">
              <span className="text-white"><span className="font-serif text-[1.2em] leading-none tracking-[-0.01em]">The format layer</span> for macOS</span> that turns every drag into a conversion, an edit or a share. No uploads, no installs.
            </p>
            <Ctas className="mt-8" />
          </div>
          <dl className="grid grid-cols-3 gap-8 sm:gap-12">
            {[['793', 'routes'], ['26', 'tools'], ['0', 'uploads']].map(([n, l]) => (
              <div key={l}>
                <dt className="text-[40px] leading-none text-white"><Pixel cell={0.1}>{n}</Pixel></dt>
                <dd className="mt-3 font-mono text-[12px] uppercase tracking-[0.14em] text-[#A7A7A7]">{l}</dd>
              </div>
            ))}
          </dl>
        </div>
        <h1 className={`${HERO_H1} mt-auto pt-[10vh]`}>
          Any file <Obj a="floppy" h="1em" rot={-9} alt="A floppy disk" /> in.<br />
          Every <Pixel cell={0.03} auto={5600}>format</Pixel> out.
        </h1>
        <div className="mt-12"><FormatStrip /></div>
      </Wrap>
    </section>
  )
}

/* ───────────── 2 · Reels ───────────── */

const PAIRS: { from: string; to: string; a: keyof typeof ASSETS; file: string }[] = [
  { from: 'MOV', to: 'GIF', a: 'film', file: 'clip' },
  { from: 'HEIC', to: 'JPG', a: 'photo', file: 'IMG_2041' },
  { from: 'DOCX', to: 'PDF', a: 'folder', file: 'invoice' },
  { from: 'M4A', to: 'MP3', a: 'cassette', file: 'memo' },
]

/** A slot-machine reel of pixel-serif words, one line tall. Only the neighbours of the current
 *  word are mounted; each slides by its offset from `n`. */
function Reel({ word, widest, n, delay = 0 }: { word: (j: number) => string; widest: string; n: number; delay?: number }) {
  return (
    <span className="relative inline-flex h-[1.12em] items-center justify-center overflow-hidden align-[-0.14em]">
      <span aria-hidden className="invisible px-[0.04em] font-serif text-[1.1em] leading-none">{widest}</span>
      {[n - 1, n, n + 1].filter((j) => j >= 0).map((j) => (
        <motion.span key={j} className="absolute inset-x-0 top-0 flex h-[1.12em] items-center justify-center"
          initial={{ y: '1.12em' }} animate={{ y: `${(j - n) * 1.12}em` }} transition={{ type: 'spring', stiffness: 170, damping: 19, delay }}>
          <Pixel cell={0.032}>{word(j)}</Pixel>
        </motion.span>
      ))}
      <span aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-[0.16em] bg-gradient-to-b from-[#0A0A0A] to-transparent" />
      <span aria-hidden className="pointer-events-none absolute inset-x-0 bottom-0 h-[0.16em] bg-gradient-to-t from-[#0A0A0A] to-transparent" />
    </span>
  )
}

function HeroReels() {
  const [n, setN] = useState(0)
  const box = useRef<HTMLElement>(null)
  const inView = useInView(box, '0px')
  const i = n % PAIRS.length
  useEffect(() => {
    if (!inView || reducedMotion()) return
    const id = window.setTimeout(() => setN((v) => v + 1), 2800)
    return () => clearTimeout(id)
  }, [n, inView])
  const pair = PAIRS[i]

  return (
    <section ref={box} className="relative overflow-hidden pb-10">
      <AsciiField focus={{ x: 0.5, y: 0.98, r: 0.55, boost: 0.5 }} />
      <Nav />
      <Wrap className="relative pt-36 text-center sm:pt-44">
        <Eyebrow>Free and open source · for macOS</Eyebrow>
        <h1 className={`${HERO_H1} mx-auto mt-8 text-[clamp(42px,10.6vw,180px)]!`}>
          <button type="button" onClick={() => setN((v) => v + 1)} className="cursor-pointer outline-none" aria-label="Show another conversion">
            <span className="whitespace-nowrap">Turn <span className="relative inline-block h-[0.95em] w-[0.95em] align-[-0.1em]">
              <AnimatePresence mode="popLayout">
                <motion.span key={pair.a} className="absolute inset-0 flex items-center justify-center"
                  initial={{ opacity: 0, scale: 0.7, rotate: -20 }} animate={{ opacity: 1, scale: 1, rotate: -8 }} exit={{ opacity: 0, scale: 0.7, rotate: 12 }}
                  transition={{ type: 'spring', stiffness: 260, damping: 20 }}>
                  <Dither src={ASSETS[pair.a].src} ratio={ASSETS[pair.a].ratio} alt="" className="max-h-full max-w-full" style={{ height: ASSETS[pair.a].ratio > 1 ? undefined : '100%', width: ASSETS[pair.a].ratio > 1 ? '100%' : undefined }} />
                </motion.span>
              </AnimatePresence>
            </span> <Reel word={(j) => PAIRS[j % PAIRS.length].from} widest="DOCX" n={n} /></span><br />
            <span className="whitespace-nowrap">into <Reel word={(j) => PAIRS[j % PAIRS.length].to} widest="MP3" n={n} delay={0.16} /></span>
          </button>
        </h1>
        <div className="mx-auto mt-10 flex w-fit items-center gap-3 rounded-lg bg-[#141414] px-4 py-2.5 font-mono text-[13px] ring-1 ring-[#1E1E1E]">
          <span className="text-[#A7A7A7]">{pair.file}.{pair.from.toLowerCase()}</span>
          <span className="flex gap-1">{[0, 1, 2].map((k) => <motion.span key={`${n}-${k}`} className="h-1.5 w-1.5 bg-[#FF5A1F]" initial={{ opacity: 0.15 }} animate={{ opacity: [0.15, 1, 0.15] }} transition={{ duration: 0.6, delay: k * 0.12 }} />)}</span>
          <span className="text-white">{pair.file}.{pair.to.toLowerCase()}</span>
          <span className="ml-2 hidden border-l border-[#313131] pl-3 text-[#7C7C7C] sm:inline">one gesture</span>
        </div>
        <Ctas className="mt-10 justify-center" />
        <p className="mt-5 font-mono text-[11px] uppercase tracking-[0.14em] text-[#7C7C7C]">Click the headline to spin it</p>
      </Wrap>
      <Wrap className="relative mt-20">
        <motion.div initial={{ opacity: 0, y: 60, rotateX: 14 }} whileInView={{ opacity: 1, y: 0, rotateX: 0 }} viewport={{ once: true, amount: 0.2 }}
          transition={{ duration: 1, ease: [0.2, 0.9, 0.2, 1] }} style={{ transformPerspective: 1400 }} className="mx-auto max-w-[1040px]">
          <AppDemo />
        </motion.div>
      </Wrap>
    </section>
  )
}

/* ───────────── 3 · Wheel ───────────── */

const IMG_OUT = ['JPG', 'PNG', 'WEBP', 'PDF', 'TIFF', 'AVIF', 'GIF', 'BMP']
const GLYPHS = '01+=%<>|/*:.-#'

/** The format wheel drawn as a field of characters. The pointer aims (anywhere on the page, like the
 *  real wheel); a click drops the file on the aimed format. */
function AsciiWheel({ hot, flash }: { hot: number; flash: number }) {
  const ref = useRef<HTMLCanvasElement>(null)
  const state = useRef({ hot, flash, flashAt: 0, hotAt: 0 })
  useEffect(() => { state.current.hotAt = performance.now(); state.current.hot = hot }, [hot])
  useEffect(() => { if (flash) state.current.flashAt = performance.now(); state.current.flash = flash }, [flash])
  const visible = useInView(ref)

  useEffect(() => {
    const c = ref.current
    if (!c || !visible) return
    const ctx = c.getContext('2d')!
    let raf = 0, size = 0, cols = 0, cell = 12
    let seed = new Uint8Array(0)
    const reduced = reducedMotion()
    const resize = () => {
      const dpr = Math.min(2, window.devicePixelRatio || 1)
      size = c.getBoundingClientRect().width
      cell = Math.max(9, Math.round(size / 52))
      c.width = c.height = Math.round(size * dpr)
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      ctx.font = `${cell * 0.8}px "JetBrains Mono Variable", monospace`
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle'
      cols = Math.ceil(size / cell)
      seed = new Uint8Array(cols * cols).map(() => (Math.random() * GLYPHS.length) | 0)
    }
    const N = IMG_OUT.length
    const draw = (now: number) => {
      ctx.clearRect(0, 0, size, size)
      const R = size / 2, r0 = R * 0.36, r1 = R * 0.96
      const { hot: h, hotAt, flashAt } = state.current
      const sweep = Math.min(1, (now - hotAt) / 380)
      const fl = Math.max(0, 1 - (now - flashAt) / 700)
      for (let k = 0; k < 6; k++) seed[(Math.random() * seed.length) | 0] = (Math.random() * GLYPHS.length) | 0
      for (let gy = 0; gy < cols; gy++) for (let gx = 0; gx < cols; gx++) {
        const x = gx * cell + cell / 2 - R, y = gy * cell + cell / 2 - R
        const r = Math.hypot(x, y)
        if (r < r0 || r > r1) continue
        let a = Math.atan2(y, x) + Math.PI / 2 + Math.PI / N
        a = ((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)
        const seg = Math.floor(a / ((Math.PI * 2) / N))
        const local = a - seg * ((Math.PI * 2) / N)
        if (local < 0.07 || local > (Math.PI * 2) / N - 0.07) continue
        const rn = (r - r0) / (r1 - r0)
        const isHot = seg === h
        let alpha = 0.24 + 0.3 * (1 - rn)
        if (isHot) alpha = rn < sweep ? 0.95 : 0.3
        if (isHot && fl > 0) alpha = 1
        ctx.globalAlpha = alpha
        ctx.fillStyle = isHot ? (fl > 0 && Math.random() < fl ? '#fff' : C.accent) : '#E8E8E8'
        ctx.fillText(GLYPHS[seed[gy * cols + gx]], gx * cell + cell / 2, gy * cell + cell / 2)
      }
      ctx.globalAlpha = 1
      if (!reduced) raf = requestAnimationFrame(draw)
    }
    resize()
    raf = requestAnimationFrame(draw)
    const ro = new ResizeObserver(resize)
    ro.observe(c)
    return () => { cancelAnimationFrame(raf); ro.disconnect() }
  }, [visible])

  return <canvas ref={ref} aria-hidden className="absolute inset-0 h-full w-full" />
}

function HeroWheel() {
  const wheel = useRef<HTMLDivElement>(null)
  const [hot, setHot] = useState(0)
  const [flash, setFlash] = useState(0)
  const [made, setMade] = useState<string | null>(null)

  const aim = useCallback((x: number, y: number) => {
    const el = wheel.current
    if (!el) return -1
    const r = el.getBoundingClientRect()
    if (y > r.bottom + 200) return -1
    const a = Math.atan2(y - (r.top + r.height / 2), x - (r.left + r.width / 2)) + Math.PI / 2 + Math.PI / IMG_OUT.length
    const seg = Math.floor((((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)) / ((Math.PI * 2) / IMG_OUT.length))
    setHot(seg)
    return seg
  }, [])
  useEffect(() => {
    const onMove = (e: PointerEvent) => { if (e.pointerType === 'mouse') aim(e.clientX, e.clientY) }
    window.addEventListener('pointermove', onMove, { passive: true })
    return () => window.removeEventListener('pointermove', onMove)
  }, [aim])

  const drop = useCallback((seg: number) => {
    setFlash((f) => f + 1)
    setMade(IMG_OUT[seg])
  }, [])
  useEffect(() => {
    if (!made) return
    const id = window.setTimeout(() => setMade(null), 2600)
    return () => clearTimeout(id)
  }, [made, flash])

  return (
    <section className="relative min-h-[100svh] overflow-hidden" onPointerDown={(e) => {
      if ((e.target as HTMLElement).closest('button,a')) return
      const seg = e.pointerType === 'mouse' ? hot : aim(e.clientX, e.clientY)
      if (seg >= 0) drop(seg)
    }}>
      <AsciiField density={0.05} />
      <Nav />
      <Wrap className="relative grid min-h-[100svh] items-center gap-6 pb-16 pt-28 lg:grid-cols-[minmax(0,6fr)_minmax(0,6fr)]">
        <div className="relative z-10">
          <Eyebrow>Aim, don’t browse</Eyebrow>
          <h1 className="mt-7 text-[clamp(52px,7.6vw,128px)] font-semibold leading-[0.95] tracking-[-0.06em] text-white">
            Every format is one <Pixel cell={0.032} auto={6400}>flick</Pixel> away.
          </h1>
          <p className="mt-8 max-w-[480px] text-[clamp(17px,1.4vw,20px)] leading-relaxed text-[#A7A7A7]">
            Drag a file, tap Shift, and the formats it can become open around your pointer. Aim, let go, done. The original stays put.
          </p>
          <Ctas className="mt-9" />
          <p className="mt-6 flex items-center gap-2 font-mono text-[11px] uppercase tracking-[0.14em] text-[#7C7C7C]">
            <span className="text-[#FF5A1F]"><DotIcon name="arrow" size={10} /></span><span className="hidden sm:inline">Move your pointer to aim. Click to drop.</span><span className="sm:hidden">Tap a format on the wheel.</span>
          </p>
        </div>
        <div ref={wheel} className="relative mx-auto aspect-square w-full max-w-[640px] select-none">
          <AsciiWheel hot={hot} flash={flash} />
          {IMG_OUT.map((f, i) => {
            const a = (i / IMG_OUT.length) * Math.PI * 2 - Math.PI / 2
            return (
              <span key={f} className="absolute -translate-x-1/2 -translate-y-1/2 rounded px-2 py-1 font-mono text-[12px] font-medium tracking-[0.1em] transition-colors duration-150 sm:text-[14px]"
                style={{ left: `${50 + Math.cos(a) * 33}%`, top: `${50 + Math.sin(a) * 33}%`, background: i === hot ? '#fff' : C.canvas, color: i === hot ? '#000' : '#fff', boxShadow: `inset 0 0 0 1px ${i === hot ? '#fff' : C.edge}` }}>
                {f}
              </span>
            )
          })}
          <div className="absolute left-1/2 top-1/2 flex w-[30%] -translate-x-1/2 -translate-y-1/2 flex-col items-center">
            <Dither src={ASSETS.photo.src} ratio={ASSETS.photo.ratio} alt="A photo being converted" className="w-[62%]" pixel={3} levels={3} resolved={!!made} />
            <AnimatePresence mode="wait">
              <motion.span key={made ?? 'src'} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -4 }}
                className={`mt-3 whitespace-nowrap font-mono text-[11px] sm:text-[12.5px] ${made ? 'text-[#FF5A1F]' : 'text-white'}`}>
                {made ? `IMG_2041.${made.toLowerCase()} ✓` : 'IMG_2041.heic'}
              </motion.span>
            </AnimatePresence>
          </div>
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────── Page ───────────── */

export const IDEAS = [
  { n: 1, name: 'Resample', Hero: HeroResample },
  { n: 2, name: 'Reels', Hero: HeroReels },
  { n: 3, name: 'Wheel', Hero: HeroWheel },
]

function Switcher({ current }: { current: number }) {
  return (
    <div className="fixed inset-x-0 bottom-4 z-[60] flex justify-center px-3" style={{ paddingBottom: 'env(safe-area-inset-bottom, 0px)' }}>
      <div className="flex items-center gap-1 rounded-lg bg-[#141414]/90 p-1 font-mono text-[12px] uppercase tracking-[0.1em] text-[#A7A7A7] ring-1 ring-[#313131] backdrop-blur-xl">
        <span className="px-2.5 text-[#7C7C7C]">Idea</span>
        {IDEAS.map((h) => (
          <Link key={h.n} to={`/raster/${h.n}`} className={`relative rounded-md px-3 py-1.5 transition-colors ${current === h.n ? 'text-black' : 'hover:text-white'}`}>
            {current === h.n && <motion.span layoutId="raster-switch" className="absolute inset-0 rounded-md bg-white" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
            <span className="relative">{h.n} {h.name}</span>
          </Link>
        ))}
      </div>
    </div>
  )
}

export default function RasterPage() {
  const { n = '1' } = useParams()
  const idx = Math.min(3, Math.max(1, parseInt(n, 10) || 1))
  const { Hero, name } = IDEAS[idx - 1]
  useEffect(() => { document.title = `anyfmt · ${name}`; window.scrollTo(0, 0) }, [name])
  return (
    <div className="raster min-h-screen overflow-x-clip">
      <RasterStyles />
      <Hero key={idx} />
      <KeysSection />
      <EngineSection />
      <ProofSection />
      <FilesSection />
      <ClosingSection />
      <Footer />
      <Switcher current={idx} />
    </div>
  )
}
