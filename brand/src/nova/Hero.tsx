import confetti from 'canvas-confetti'
import { animate, AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { ArrowDown, Download } from 'lucide-react'
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { toast } from 'sonner'
import { isShot } from '../shared/kit'
import { LightWheel, type WheelInput } from './fx/LightWheel'
import { Button, Letters, LiveKey, Morph, scrollToId } from './fx/ui'

const TARGETS = [
  { f: 'GIF', s: '4.1 MB' }, { f: 'MP4', s: '1.8 MB' }, { f: 'WEBM', s: '1.2 MB' }, { f: 'M4V', s: '1.9 MB' },
  { f: 'MKV', s: '2.0 MB' }, { f: 'MP3', s: 'audio' }, { f: 'WAV', s: 'audio' }, { f: 'PNG', s: 'frame' },
]
const N = TARGETS.length
const TAU = Math.PI * 2
const R_OUT = 0.62, R_IN = 0.30

export function Hero() {
  const stage = useRef<HTMLDivElement>(null)
  const input = useRef<WheelInput>({ cx: 0, cy: 0, unit: 300, open: 0, aim: -1, pulseAt: 0, mx: -9999, my: -9999 })
  const [geo, setGeo] = useState({ cx: 0, cy: 0, unit: 300 })
  const [aim, setAim] = useState(-1)
  const [file, setFile] = useState('clip.mov')
  const [open, setOpen] = useState(isShot ? 1 : 0)
  const pointerNear = useRef(false)
  const reduce = useReducedMotion()

  // Wheel placement: right side on desktop, centred under the copy on phones.
  useLayoutEffect(() => {
    const el = stage.current!
    const place = () => {
      const w = el.clientWidth, h = el.clientHeight
      const wide = w >= 1024
      const R = wide ? Math.min(h * 0.35, w * 0.21) : Math.min(w * 0.42, 220)
      const g = { cx: wide ? w * 0.73 : w / 2, cy: wide ? h * 0.52 : h - R - 70, unit: R / R_OUT }
      Object.assign(input.current, g)
      setGeo(g)
    }
    place()
    const ro = new ResizeObserver(place)
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const setOpenAnimated = useCallback((to: number, opts?: { duration?: number; from?: number }) => {
    if (isShot || reduce) { input.current.open = to; setOpen(to); return }
    return animate(opts?.from ?? input.current.open, to, {
      type: 'spring', stiffness: 70, damping: 12, mass: 1,
      onUpdate: (v) => { input.current.open = v; setOpen(v) },
    })
  }, [reduce])

  // Intro: the core ignites, then the wheel blooms.
  useEffect(() => {
    if (isShot) { input.current.open = 1; input.current.aim = 0; setAim(0); return }
    const t = setTimeout(() => setOpenAnimated(1), 450)
    return () => clearTimeout(t)
  }, [setOpenAnimated])

  // Idle aim drifts around the wheel when the pointer is elsewhere.
  useEffect(() => {
    if (isShot) return
    let k = 0
    const id = setInterval(() => {
      if (pointerNear.current) return
      k = (k + 1) % N
      input.current.aim = k; setAim(k)
    }, 1400)
    return () => clearInterval(id)
  }, [])

  // ⇧ re-blooms the wheel, like pressing Shift mid-drag.
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key !== 'Shift' || e.repeat) return
      const r = stage.current?.getBoundingClientRect()
      if (!r || r.bottom < 0) return
      setOpenAnimated(1, { from: 0.08 })
    }
    window.addEventListener('keydown', down)
    return () => window.removeEventListener('keydown', down)
  }, [setOpenAnimated])

  const onMove = (e: React.PointerEvent) => {
    const r = stage.current!.getBoundingClientRect()
    const x = e.clientX - r.left, y = e.clientY - r.top
    input.current.mx = x; input.current.my = y
    const dx = (x - geo.cx) / geo.unit, dy = (geo.cy - y) / geo.unit
    const d = Math.hypot(dx, dy)
    if (d > R_IN * 0.7 && d < R_OUT * 1.35) {
      let a = Math.atan2(dx, dy) + TAU / (2 * N)
      a = ((a % TAU) + TAU) % TAU
      const i = Math.floor(a / (TAU / N))
      pointerNear.current = true
      if (i !== input.current.aim) { input.current.aim = i; setAim(i) }
      stage.current!.style.cursor = 'pointer'
    } else {
      pointerNear.current = false
      stage.current!.style.cursor = ''
    }
  }

  const drop = () => {
    if (!pointerNear.current || aim < 0) return
    const t = TARGETS[aim]
    input.current.pulseAt = performance.now()
    const name = `clip.${t.f.toLowerCase()}`
    setFile(name)
    const r = stage.current!.getBoundingClientRect()
    const mid = (aim / N) * TAU
    const px = r.left + geo.cx + geo.unit * 0.47 * Math.sin(mid), py = r.top + geo.cy - geo.unit * 0.47 * Math.cos(mid)
    if (!reduce) confetti({ particleCount: 70, spread: 70, startVelocity: 32, gravity: 0.9, scalar: 0.8, ticks: 140,
      origin: { x: px / window.innerWidth, y: py / window.innerHeight }, colors: ['#FFC24B', '#FF5A1F', '#FF2E63', '#4DF0FF'], disableForReducedMotion: true })
    toast(`${name} is ready`, { description: `${t.s} · saved next to clip.mov` })
    setTimeout(() => setFile('clip.mov'), 2600)
  }

  const labelR = (R_IN + R_OUT) / 2

  return (
    <section ref={stage} id="top" onPointerMove={onMove} onPointerLeave={() => { pointerNear.current = false; input.current.mx = -9999 }} onClick={drop}
      className="relative min-h-[1060px] overflow-hidden lg:h-[100svh] lg:min-h-[720px]">
      <LightWheel input={input} still={isShot} />

      {/* Format labels ride the wheel. */}
      <div aria-hidden className="pointer-events-none absolute inset-0">
        {TARGETS.map((t, i) => {
          const mid = (i / N) * TAU
          const hot = i === aim
          const lift = hot ? 0.055 : 0
          const rr = (labelR + lift) * open
          return (
            <div key={t.f} className="absolute -translate-x-1/2 -translate-y-1/2 text-center transition-[color,transform] duration-200"
              style={{ left: geo.cx + geo.unit * rr * Math.sin(mid), top: geo.cy - geo.unit * rr * Math.cos(mid), opacity: Math.max(0, open * 1.4 - 0.4),
                color: hot ? '#fff' : 'rgba(255,240,230,.62)', transform: `translate(-50%,-50%) scale(${hot ? 1.12 : 1})` }}>
              <div className="nv-display text-[clamp(13px,1.35vw,19px)] tracking-[-0.02em]" style={{ textShadow: hot ? '0 0 18px rgba(77,240,255,.9)' : 'none' }}>{t.f}</div>
              <div className="nv-mono mt-0.5 text-[9.5px] opacity-70">{t.s}</div>
            </div>
          )
        })}
        {/* The file in the hub. */}
        <div className="absolute -translate-x-1/2 -translate-y-1/2" style={{ left: geo.cx, top: geo.cy }}>
          <AnimatePresence mode="popLayout">
            <motion.div key={file} initial={{ scale: 0.6, opacity: 0, filter: 'blur(6px)' }} animate={{ scale: 1, opacity: open > 0.5 ? 1 : 0, filter: 'blur(0px)' }}
              exit={{ scale: 1.3, opacity: 0, filter: 'blur(6px)' }} transition={{ type: 'spring', stiffness: 400, damping: 26 }}
              className="nv-mono rounded-full bg-black/60 px-3 py-1.5 text-[11px] text-white shadow-[0_0_0_1px_rgba(255,255,255,.15)] backdrop-blur">{file}</motion.div>
          </AnimatePresence>
        </div>
      </div>

      {/* Copy. */}
      <div className="pointer-events-none relative z-10 mx-auto flex h-full max-w-[1320px] flex-col px-5 pt-32 sm:px-8 lg:justify-center lg:pt-0">
        <div className="pointer-events-auto max-w-[620px]">
          <motion.div initial={isShot ? false : { opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2, duration: 0.8 }}
            className="mb-7 inline-flex items-center gap-2 rounded-full bg-white/[.05] py-1 pl-1 pr-3.5 text-[12.5px] text-[var(--nv-mute)] shadow-[inset_0_0_0_1px_var(--nv-line)] backdrop-blur">
            <span className="rounded-full px-2 py-0.5 text-[11px] font-semibold text-black [background:var(--nv-molten)]">New</span>
            Free and open source for macOS
          </motion.div>
          <h1 className="nv-display text-[clamp(54px,8.6vw,124px)]">
            <Letters text="Any file." delay={0.25} /><br />
            <span className="whitespace-nowrap"><Letters text="Into " delay={0.55} /><Morph className="nv-molten-text inline-block min-w-[3.2ch] pr-[0.06em]" words={['GIF.', 'WEBP.', 'PDF.', 'MP3.', 'HEIC.', 'MP4.']} /></span>
          </h1>
          <motion.p initial={isShot ? false : { opacity: 0, y: 14, filter: 'blur(6px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} transition={{ delay: 0.9, duration: 0.9 }}
            className="mt-7 max-w-[470px] text-[clamp(16px,1.25vw,18.5px)] leading-[1.55] text-[var(--nv-mute)]">
            Drag a file, tap <b className="font-medium text-[var(--nv-text)]">Shift</b>, and a wheel of everything it can become opens around your pointer. Let go on one. It happens on your Mac, in milliseconds, and nothing gets uploaded.
          </motion.p>
          <motion.div initial={isShot ? false : { opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 1.05, duration: 0.8 }}
            className="mt-9 flex flex-wrap items-center gap-3" onClick={(e) => e.stopPropagation()}>
            <Button variant="molten" size="lg" beam onClick={() => toast('Download starts soon', { description: 'anyfmt is in private beta. This button is a placeholder.' })}>
              <Download size={18} strokeWidth={2.4} />Download for Mac
            </Button>
            <Button variant="glass" size="lg" onClick={() => scrollToId('story')}>See it work<ArrowDown size={16} /></Button>
          </motion.div>
          <motion.div initial={isShot ? false : { opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 1.4, duration: 1 }}
            className="mt-10 hidden items-center gap-3 text-[13px] text-[var(--nv-dim)] lg:flex">
            <LiveKey k="⇧" label="shift" code="Shift" />
            <span>Press Shift to re-open the wheel. Aim at a format and click to drop.</span>
          </motion.div>
        </div>
      </div>

      <div aria-hidden className="pointer-events-none absolute inset-x-0 bottom-0 h-40 bg-gradient-to-b from-transparent to-[var(--nv-void)]" />
    </section>
  )
}
