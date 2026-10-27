/**
 * Raster: the anyfmt site kit in the black-canvas, ASCII-field style.
 *
 * The one idea running through every piece is resampling, because that is what anyfmt does to
 * files: pixel-serif words sharpen when you touch them, dithered objects resolve into full colour,
 * the primary button fills through a Bayer threshold, icons are dot matrices.
 *
 * AsciiField adapts "Background ASCII Wake" (nikolas-sapa) and Dither adapts "Dither Image"
 * (educalvolpz), both from 21st.dev. DotIcon borrows the per-dot wave from "Anti Metal Button"
 * (smammar).
 */

import { useCallback, useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { cn } from '../shared/cn'

export const C = {
  canvas: '#0A0A0A', card: '#141414', iron: '#1E1E1E', edge: '#313131', smoke: '#454545',
  mist: '#7C7C7C', ash: '#A7A7A7', bone: '#FFFFFF', accent: '#FF5A1F',
} as const

const BAYER4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v + 0.5) / 16)
const bayer = (x: number, y: number) => BAYER4[(y & 3) * 4 + (x & 3)]

export const reducedMotion = () => typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches

/** Runs `cb` only while `el` is on screen. */
function useInView<T extends Element>(ref: React.RefObject<T | null>, margin = '100px') {
  const [seen, setSeen] = useState(false)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(([e]) => setSeen(e.isIntersecting), { rootMargin: margin })
    io.observe(el)
    return () => io.disconnect()
  }, [ref, margin])
  return seen
}
export { useInView }

/* ───────────────────────────── ASCII field ───────────────────────────── */

const RAMP = ' .:-=+*%#'
const NOISE = '01+=%<>|/*:.-'

/** Full-bleed character field: a sparse flickering scatter, denser around `focus`, with a wake that
 *  follows the pointer and burns accent-hot where it lingers. */
export function AsciiField({ cell = 14, density = 0.09, focus, ink = '#E8E8E8', className }: {
  cell?: number; density?: number; focus?: { x: number; y: number; r: number; boost: number }; ink?: string; className?: string
}) {
  const ref = useRef<HTMLCanvasElement>(null)
  const visible = useInView(ref)

  useEffect(() => {
    const canvas = ref.current
    if (!canvas || !visible) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    const reduced = reducedMotion()
    let cols = 0, rows = 0, w = 0, h = 0
    let glyph = new Uint8Array(0), amb = new Float32Array(0), heat = new Float32Array(0), decay = new Float32Array(0)
    let raf = 0, last = 0, acc = 0
    const p = { x: -1e4, y: -1e4, t: 0, on: false }

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      const r = canvas.getBoundingClientRect()
      w = r.width; h = r.height
      canvas.width = Math.max(1, Math.round(w * dpr)); canvas.height = Math.max(1, Math.round(h * dpr))
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      ctx.font = `${cell * 0.78}px "JetBrains Mono Variable", ui-monospace, monospace`
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle'
      cols = Math.ceil(w / cell); rows = Math.ceil(h / cell)
      const n = cols * rows
      glyph = new Uint8Array(n); amb = new Float32Array(n); heat = new Float32Array(n); decay = new Float32Array(n).fill(1.2)
      let s = 0x9e3779b9 ^ n
      const rnd = () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return ((s >>> 0) % 10000) / 10000 }
      for (let i = 0; i < n; i++) {
        const gx = i % cols, gy = (i / cols) | 0
        let prob = density
        if (focus) {
          const dx = gx * cell / w - focus.x, dy = (gy * cell / h - focus.y) * (h / w)
          const d = Math.hypot(dx, dy) / focus.r
          if (d < 1) prob += focus.boost * (1 - d) ** 1.6
        }
        if (rnd() < prob) amb[i] = 0.1 + rnd() * 0.22 + (prob > 0.3 ? 0.2 : 0)
        glyph[i] = (rnd() * NOISE.length) | 0
      }
    }

    const draw = () => {
      ctx.clearRect(0, 0, w, h)
      for (let gy = 0; gy < rows; gy++) {
        for (let gx = 0; gx < cols; gx++) {
          const i = gy * cols + gx
          const hv = heat[i], a = amb[i]
          if (hv < 0.04 && a < 0.04) continue
          let ch: string
          if (hv > a) ch = RAMP[Math.min(RAMP.length - 1, 1 + Math.floor(hv * (RAMP.length - 2)))]
          else ch = NOISE[glyph[i]]
          const lum = Math.max(hv, a)
          ctx.globalAlpha = Math.min(1, 0.1 + lum * 0.75)
          ctx.fillStyle = hv > 0.62 && ink !== '#000' ? C.accent : ink
          ctx.fillText(ch, gx * cell + cell / 2, gy * cell + cell / 2)
        }
      }
      ctx.globalAlpha = 1
    }

    const stamp = (px: number, py: number, rad: number, rate: number) => {
      const cx = px / cell, cy = py / cell
      for (let gy = Math.max(0, Math.floor(cy - rad)); gy <= Math.min(rows - 1, Math.ceil(cy + rad)); gy++) {
        for (let gx = Math.max(0, Math.floor(cx - rad)); gx <= Math.min(cols - 1, Math.ceil(cx + rad)); gx++) {
          const d = Math.hypot(gx + 0.5 - cx, gy + 0.5 - cy)
          if (d > rad) continue
          const f = 1 - d / rad, i = gy * cols + gx
          if (f > heat[i]) { heat[i] = f; decay[i] = rate }
        }
      }
    }

    const onMove = (e: PointerEvent) => {
      const r = canvas.getBoundingClientRect()
      const x = e.clientX - r.left, y = e.clientY - r.top
      if (x < -40 || y < -40 || x > r.width + 40 || y > r.height + 40) { p.on = false; return }
      const now = performance.now()
      if (p.on) {
        const dx = x - p.x, dy = y - p.y, dist = Math.hypot(dx, dy)
        const speed = dist / Math.max(1, now - p.t)
        const rad = Math.max(0.8, Math.min(3, 2.8 / (1 + speed * 1.4)))
        const rate = Math.max(0.7, Math.min(4, 0.9 + speed * 2.6))
        const steps = Math.max(1, Math.ceil(dist / (cell * 0.5)))
        for (let s = 1; s <= steps; s++) stamp(p.x + (dx * s) / steps, p.y + (dy * s) / steps, rad, rate)
      }
      p.x = x; p.y = y; p.t = now; p.on = true
    }

    const loop = (now: number) => {
      const dt = last ? Math.min(64, now - last) / 1000 : 1 / 60
      last = now; acc += dt
      for (let i = 0; i < heat.length; i++) if (heat[i] > 0) heat[i] = Math.max(0, heat[i] - decay[i] * dt)
      // flicker: a handful of ambient cells swap glyphs every frame
      for (let k = 0; k < Math.max(4, (amb.length / 400) | 0); k++) {
        const i = (Math.random() * amb.length) | 0
        if (amb[i] > 0) glyph[i] = (Math.random() * NOISE.length) | 0
      }
      if (acc > 1 / 30) { acc = 0; draw() }
      raf = requestAnimationFrame(loop)
    }

    resize()
    draw()
    const ro = new ResizeObserver(() => { resize(); draw() })
    ro.observe(canvas)
    if (!reduced) {
      window.addEventListener('pointermove', onMove, { passive: true })
      raf = requestAnimationFrame(loop)
    }
    return () => { cancelAnimationFrame(raf); ro.disconnect(); window.removeEventListener('pointermove', onMove) }
  }, [visible, cell, density, focus, ink])

  return <canvas ref={ref} aria-hidden className={cn('pointer-events-none absolute inset-0 h-full w-full', className)} />
}

/* ───────────────────────────── Pixel serif ───────────────────────────── */

/** A word set in Instrument Serif, rasterised to a coarse pixel grid. Hover (or `auto`) resamples it
 *  through finer grids to the true outline and back, like a file being upsampled. */
export function Pixel({ children, cell = 0.034, auto, className, style }: {
  children: string; cell?: number; auto?: number; className?: string; style?: CSSProperties
}) {
  const wrap = useRef<HTMLSpanElement>(null)
  const cv = useRef<HTMLCanvasElement>(null)
  const res = useRef(cell)
  const timers = useRef<number[]>([])

  const draw = useCallback(() => {
    const el = wrap.current, c = cv.current
    if (!el || !c) return
    const cs = getComputedStyle(el)
    const fs = parseFloat(cs.fontSize)
    const pad = fs * 0.12
    const w = el.offsetWidth + pad * 2, h = el.offsetHeight
    if (!w || !h) return
    const dpr = Math.min(2, window.devicePixelRatio || 1)
    c.width = Math.round(w * dpr); c.height = Math.round(h * dpr)
    c.style.width = `${w}px`; c.style.height = `${h}px`; c.style.left = `${-pad}px`
    const ctx = c.getContext('2d')!
    const font = (size: number) => `${cs.fontStyle} 400 ${size}px "Instrument Serif", Georgia, serif`
    ctx.font = font(fs)
    const m = ctx.measureText('Hg')
    const baseline = (h - (m.fontBoundingBoxAscent + m.fontBoundingBoxDescent)) / 2 + m.fontBoundingBoxAscent
    ctx.clearRect(0, 0, c.width, c.height)
    ctx.fillStyle = cs.color
    const px = res.current * fs
    if (px <= 1.2) {
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
      ctx.font = font(fs)
      ctx.fillText(children, pad, baseline)
      ctx.setTransform(1, 0, 0, 1, 0, 0)
      return
    }
    const gw = Math.ceil(w / px), gh = Math.ceil(h / px)
    const g = document.createElement('canvas')
    g.width = gw; g.height = gh
    const gc = g.getContext('2d', { willReadFrequently: true })!
    gc.font = font(fs / px)
    gc.fillStyle = '#fff'
    gc.fillText(children, pad / px, baseline / px)
    const img = gc.getImageData(0, 0, gw, gh)
    const d = img.data
    for (let i = 0; i < d.length; i += 4) d[i + 3] = d[i + 3] > 105 ? 255 : 0
    gc.putImageData(img, 0, 0)
    ctx.imageSmoothingEnabled = false
    ctx.drawImage(g, 0, 0, gw * px * dpr, gh * px * dpr)
    ctx.globalCompositeOperation = 'source-in'
    ctx.fillRect(0, 0, c.width, c.height)
    ctx.globalCompositeOperation = 'source-over'
  }, [children])

  const run = useCallback((to: 'sharp' | 'coarse') => {
    timers.current.forEach(clearTimeout)
    timers.current = []
    const seq = to === 'sharp' ? [cell * 0.66, cell * 0.42, cell * 0.24, 0] : [cell * 0.24, cell * 0.42, cell * 0.66, cell]
    seq.forEach((v, i) => timers.current.push(window.setTimeout(() => { res.current = v; draw() }, i * 65)))
  }, [cell, draw])

  useEffect(() => {
    let alive = true
    document.fonts.load('40px "Instrument Serif"').then(() => alive && draw())
    const ro = new ResizeObserver(() => draw())
    if (wrap.current) ro.observe(wrap.current)
    return () => { alive = false; ro.disconnect() }
  }, [draw])

  useEffect(() => {
    if (!auto || reducedMotion()) return
    const id = window.setInterval(() => { run('sharp'); window.setTimeout(() => run('coarse'), 1400) }, auto)
    return () => clearInterval(id)
  }, [auto, run])

  useEffect(() => () => timers.current.forEach(clearTimeout), [])

  return (
    <span ref={wrap} onPointerEnter={() => !reducedMotion() && run('sharp')} onPointerLeave={() => run('coarse')}
      className={cn('relative inline-block whitespace-nowrap align-baseline leading-none', className)}
      style={{ fontFamily: '"Instrument Serif", Georgia, serif', fontWeight: 400, letterSpacing: 0, fontSize: '1.1em', ...style }}>
      <span className="text-transparent">{children}</span>
      <canvas ref={cv} aria-hidden className="pointer-events-none absolute top-0" />
    </span>
  )
}

/* ───────────────────────────── Dithered object ───────────────────────────── */

/** An object image, ordered-dithered in colour onto a coarse grid. Hover resolves it to the real
 *  image (pixel size and tone count step up together); `resolved` forces it. */
export function Dither({ src, alt, ratio, pixel = 3, levels = 3, resolved, className, style, interactive = true }: {
  src: string; alt: string; ratio: number; pixel?: number; levels?: number; resolved?: boolean
  className?: string; style?: CSSProperties; interactive?: boolean
}) {
  const wrap = useRef<HTMLSpanElement>(null)
  const cv = useRef<HTMLCanvasElement>(null)
  const img = useRef<HTMLImageElement | null>(null)
  const step = useRef(0)
  const timers = useRef<number[]>([])
  const STEPS: [number, number][] = [[pixel, levels], [pixel * 0.7, levels + 2], [pixel * 0.45, levels + 6], [0, 0]]

  const draw = useCallback(() => {
    const el = wrap.current, c = cv.current, im = img.current
    if (!el || !c || !im || !im.complete) return
    const w = el.offsetWidth, h = el.offsetHeight
    if (!w || !h) return
    const dpr = Math.min(2, window.devicePixelRatio || 1)
    c.width = Math.round(w * dpr); c.height = Math.round(h * dpr)
    const ctx = c.getContext('2d')!
    ctx.clearRect(0, 0, c.width, c.height)
    const [p, lv] = STEPS[step.current]
    if (!p) { ctx.imageSmoothingEnabled = true; ctx.drawImage(im, 0, 0, c.width, c.height); return }
    const px = Math.max(1, p)
    const gw = Math.max(1, Math.round(w / px)), gh = Math.max(1, Math.round(h / px))
    const g = document.createElement('canvas')
    g.width = gw; g.height = gh
    const gc = g.getContext('2d', { willReadFrequently: true })!
    gc.drawImage(im, 0, 0, gw, gh)
    const data = gc.getImageData(0, 0, gw, gh)
    const d = data.data, L = lv - 1
    for (let y = 0; y < gh; y++) {
      for (let x = 0; x < gw; x++) {
        const o = (y * gw + x) * 4, t = bayer(x, y)
        d[o + 3] = d[o + 3] / 255 + (t - 0.5) * 0.7 > 0.5 ? 255 : 0
        for (let k = 0; k < 3; k++) d[o + k] = Math.min(255, (Math.floor((d[o + k] / 255) * L + t) / L) * 255)
      }
    }
    gc.putImageData(data, 0, 0)
    ctx.imageSmoothingEnabled = false
    ctx.drawImage(g, 0, 0, c.width, c.height)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pixel, levels])

  const go = useCallback((target: number) => {
    timers.current.forEach(clearTimeout)
    timers.current = []
    const from = step.current, dir = target > from ? 1 : -1
    for (let s = from + dir, i = 0; dir > 0 ? s <= target : s >= target; s += dir, i++) {
      const v = s
      timers.current.push(window.setTimeout(() => { step.current = v; draw() }, i * 80))
    }
  }, [draw])

  useEffect(() => {
    const im = new Image()
    im.decoding = 'async'
    im.onload = () => draw()
    im.src = src
    img.current = im
    const ro = new ResizeObserver(() => draw())
    if (wrap.current) ro.observe(wrap.current)
    return () => { ro.disconnect(); im.onload = null }
  }, [src, draw])

  useEffect(() => { if (resolved !== undefined) go(resolved ? 3 : 0) }, [resolved, go])
  useEffect(() => () => timers.current.forEach(clearTimeout), [])

  return (
    <span ref={wrap} role="img" aria-label={alt}
      onPointerEnter={interactive && resolved === undefined ? () => !reducedMotion() && go(3) : undefined}
      onPointerLeave={interactive && resolved === undefined ? () => go(0) : undefined}
      className={cn('relative inline-block align-middle', className)}
      style={{ aspectRatio: String(ratio), ...style }}>
      <canvas ref={cv} aria-hidden className="absolute inset-0 h-full w-full" style={{ imageRendering: 'pixelated' }} />
    </span>
  )
}

/* ───────────────────────────── Dot-matrix icons ───────────────────────────── */

const ICONS: Record<string, string[]> = {
  arrow: ['.......', '...#...', '....#..', '#######', '....#..', '...#...', '.......'],
  download: ['...#...', '...#...', '...#...', '.#.#.#.', '..###..', '...#...', '#######'],
  shift: ['...#...', '..#.#..', '.#...#.', '##...##', '.#...#.', '.#...#.', '.#####.'],
  command: ['##...##', '#.#.#.#', '.#####.', '..#.#..', '.#####.', '#.#.#.#', '##...##'],
  control: ['.......', '...#...', '..#.#..', '.#...#.', '#.....#', '.......', '.......'],
  check: ['.......', '......#', '.....#.', '#...#..', '.#.#...', '..#....', '.......'],
  lock: ['..###..', '.#...#.', '.#...#.', '#######', '#..#..#', '#..#..#', '#######'],
  bolt: ['....##.', '...##..', '..##...', '.#####.', '...##..', '..##...', '.##....'],
  play: ['.#.....', '.##....', '.###...', '.####..', '.###...', '.##....', '.#.....'],
  plus: ['.......', '...#...', '...#...', '.#####.', '...#...', '...#...', '.......'],
  route: ['#......', '##.....', '.##..#.', '..#.##.', '..###..', '...#...', '...#...'],
  copy: ['.####..', '.#..#..', '.#..###', '.#..#.#', '.####.#', '...#..#', '...####'],
}

/** A 7×7 dot-matrix glyph. Inside a `.group`, hovering runs a diagonal wave through the dots. */
export function DotIcon({ name, size = 16, className }: { name: keyof typeof ICONS | string; size?: number; className?: string }) {
  const rows = ICONS[name] ?? ICONS.plus
  return (
    <svg width={size} height={size} viewBox="0 0 7 7" aria-hidden className={cn('dot-icon shrink-0', className)}>
      {rows.flatMap((r, y) => [...r].map((ch, x) => ch === '#'
        ? <rect key={`${x}-${y}`} x={x + 0.1} y={y + 0.1} width={0.8} height={0.8} rx={0.15} fill="currentColor" style={{ animationDelay: `${(x + y) * 40}ms` }} />
        : null))}
    </svg>
  )
}

/* ───────────────────────────── Buttons ───────────────────────────── */

/** Primary: accent fill. On hover a white fill floods in through a Bayer threshold sweep, cell by
 *  cell, left to right; the arrow's dots wave. */
export function DitherButton({ children, icon = 'download', className, onClick, size = 'md' }: {
  children: ReactNode; icon?: string; className?: string; onClick?: () => void; size?: 'sm' | 'md'
}) {
  const btn = useRef<HTMLButtonElement>(null)
  const cv = useRef<HTMLCanvasElement>(null)
  const t = useRef(0)
  const raf = useRef(0)

  const paint = () => {
    const b = btn.current, c = cv.current
    if (!b || !c) return
    const w = b.offsetWidth, h = b.offsetHeight, cell = 3
    const dpr = Math.min(2, window.devicePixelRatio || 1)
    if (c.width !== Math.round(w * dpr)) { c.width = Math.round(w * dpr); c.height = Math.round(h * dpr) }
    const ctx = c.getContext('2d')!
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, w, h)
    ctx.fillStyle = '#FFFFFF'
    const cols = Math.ceil(w / cell), rows = Math.ceil(h / cell), k = t.current * 1.7
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      if (bayer(x, y) * 0.7 + (x / cols) * 0.7 < k) ctx.fillRect(x * cell, y * cell, cell, cell)
    }
  }
  const animate = (to: number) => {
    cancelAnimationFrame(raf.current)
    if (reducedMotion()) { t.current = to; paint(); return }
    const from = t.current, start = performance.now(), dur = 420
    const tick = (now: number) => {
      const k = Math.min(1, (now - start) / dur)
      t.current = from + (to - from) * (1 - (1 - k) ** 3)
      paint()
      if (k < 1) raf.current = requestAnimationFrame(tick)
    }
    raf.current = requestAnimationFrame(tick)
  }
  useEffect(() => () => cancelAnimationFrame(raf.current), [])

  return (
    <button ref={btn} type="button" onClick={onClick}
      onPointerEnter={() => animate(1)} onPointerLeave={() => animate(0)} onFocus={() => animate(1)} onBlur={() => animate(0)}
      className={cn('group relative inline-flex items-center gap-2.5 overflow-hidden rounded-lg bg-[#FF5A1F] font-medium text-[#0A0A0A] outline-none transition-transform active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-[#0A0A0A]',
        size === 'sm' ? 'h-9 px-3.5 text-[13.5px]' : 'h-12 px-5 text-[15px]', className)}>
      <canvas ref={cv} aria-hidden className="pointer-events-none absolute inset-0 h-full w-full" style={{ imageRendering: 'pixelated' }} />
      <DotIcon name={icon} size={size === 'sm' ? 13 : 15} className="relative" />
      <span className="relative">{children}</span>
    </button>
  )
}

/** Secondary: hairline ghost. On hover the border dissolves and four registration marks snap out to
 *  the corners, framing the label like a crop. */
export function FrameButton({ children, className, onClick, size = 'md' }: { children: ReactNode; className?: string; onClick?: () => void; size?: 'sm' | 'md' }) {
  const corner = 'pointer-events-none absolute h-2.5 w-2.5 border-white opacity-0 transition-all duration-300 ease-[cubic-bezier(.2,.9,.2,1)] group-hover:opacity-100 group-focus-visible:opacity-100'
  return (
    <button type="button" onClick={onClick}
      className={cn('group relative inline-flex items-center gap-2 rounded-lg font-medium text-white outline-none ring-1 ring-inset ring-[#454545] transition-[box-shadow,background-color] duration-300 hover:bg-white/[0.03] hover:ring-transparent focus-visible:ring-transparent',
        size === 'sm' ? 'h-9 px-3.5 text-[13.5px]' : 'h-12 px-5 text-[15px]', className)}>
      <span className={cn(corner, 'left-2 top-2 border-l border-t group-hover:-left-1 group-hover:-top-1 group-focus-visible:-left-1 group-focus-visible:-top-1')} />
      <span className={cn(corner, 'right-2 top-2 border-r border-t group-hover:-right-1 group-hover:-top-1 group-focus-visible:-right-1 group-focus-visible:-top-1')} />
      <span className={cn(corner, 'bottom-2 left-2 border-b border-l group-hover:-bottom-1 group-hover:-left-1 group-focus-visible:-bottom-1 group-focus-visible:-left-1')} />
      <span className={cn(corner, 'bottom-2 right-2 border-b border-r group-hover:-bottom-1 group-hover:-right-1 group-focus-visible:-bottom-1 group-focus-visible:-right-1')} />
      <span className="relative">{children}</span>
      <DotIcon name="play" size={11} className="relative text-[#A7A7A7] transition-colors group-hover:text-[#FF5A1F]" />
    </button>
  )
}

/* ───────────────────────────── Chrome ───────────────────────────── */

/** The mark: eight dots in a ring, one lifted out, i.e. the wheel with a format chosen. */
export function Mark({ size = 22 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden>
      {Array.from({ length: 8 }, (_, i) => {
        const a = (i / 8) * Math.PI * 2 - Math.PI / 2, lift = i === 1 ? 2.6 : 0, r = 8 + lift
        return <rect key={i} x={12 + Math.cos(a) * r - 1.6} y={12 + Math.sin(a) * r - 1.6} width={3.2} height={3.2} rx={0.5}
          fill={i === 1 ? C.accent : 'currentColor'} />
      })}
    </svg>
  )
}

export function Eyebrow({ children, className }: { children: ReactNode; className?: string }) {
  return <p className={cn('font-mono text-[12px] uppercase tracking-[0.12em] text-[#A7A7A7]', className)}>{children}</p>
}

export function Nav() {
  return (
    <header className="absolute inset-x-0 top-0 z-50">
      <nav className="mx-auto flex h-20 max-w-[1320px] items-center justify-between px-5 sm:px-10">
        <a href="#" onClick={(e) => e.preventDefault()} className="flex items-center gap-2.5 text-[19px] font-semibold tracking-[-0.03em] text-white"><Mark />anyfmt</a>
        <div className="hidden items-center gap-1 md:flex">
          {['How it works', 'Formats', 'Tools', 'Agents', 'Pricing'].map((l) => (
            <a key={l} href="#" onClick={(e) => e.preventDefault()} className="nav-pixel relative rounded-full px-3.5 py-2 text-[15px] font-medium text-white/85 transition-colors hover:text-white">{l}</a>
          ))}
        </div>
        <div className="flex items-center gap-4">
          <a href="#" onClick={(e) => e.preventDefault()} className="hidden text-[15px] font-medium text-white/85 hover:text-white sm:block">GitHub</a>
          <DitherButton size="sm">Download</DitherButton>
        </div>
      </nav>
    </header>
  )
}

/** Global CSS the kit relies on: dot-icon wave, nav pixel underline, float. */
export function RasterStyles() {
  return (
    <style>{`
      .raster { background:${C.canvas}; color:${C.bone}; font-family:"Inter Variable",ui-sans-serif,system-ui,sans-serif; font-feature-settings:"liga","cv11","ss01"; }
      .raster ::selection { background:${C.accent}; color:#000 }
      @keyframes dot-wave { 0%,100% { opacity:1 } 40% { opacity:.25 } }
      .group:hover .dot-icon rect, .group:focus-visible .dot-icon rect { animation: dot-wave .9s steps(3) infinite }
      .nav-pixel::after { content:""; position:absolute; left:14px; right:14px; bottom:4px; height:2px;
        background: repeating-linear-gradient(90deg, ${C.accent} 0 2px, transparent 2px 4px);
        clip-path: inset(0 100% 0 0); transition: clip-path .32s steps(8) }
      .nav-pixel:hover::after { clip-path: inset(0 0 0 0) }
      @keyframes bob { 0%,100% { transform: translateY(0) rotate(var(--rot,0deg)) } 50% { transform: translateY(-6%) rotate(calc(var(--rot,0deg) + 2deg)) } }
      .bob { animation: bob 6s ease-in-out infinite }
      @media (prefers-reduced-motion: reduce) { .bob, .group:hover .dot-icon rect { animation:none } .nav-pixel::after { transition:none } }
    `}</style>
  )
}
