import { useEffect, useRef, type RefObject } from 'react'
import { isShot } from '../../shared/kit'
import { cn } from '../../shared/cn'

/**
 * The Signal LED field: a canvas of dots on a strict grid. Optional layers:
 *  - ring: a wheel of LEDs (wedges with gaps) centred on an anchor element; one wedge lights solar,
 *          driven by `litRef` (synced to a demo) or an automatic scan.
 *  - glyph: text rasterised into the grid (a giant dot-matrix numeral), revealed column by column.
 *  - wave: an oscilloscope trace.
 * The pointer brightens nearby dots and leaves ripples. Static dots are baked once; only live dots redraw.
 */
export type RingSpec = {
  anchor: RefObject<HTMLElement | null>
  /** Outer / inner radius as a multiple of the anchor's half-width. */
  outer: number
  inner: number
  wedges: number
  /** Gap between wedges, px. */
  gap?: number
  /** Gaps follow the wheel: first wedge centred at 12 o'clock. */
}

export type GlyphSpec = {
  text: string
  /** CSS font weight + family, size is fitted to `height` (fraction of canvas height). */
  family: string
  style?: string
  height: number
  /** Horizontal anchor 0..1 and vertical centre 0..1. */
  x?: number
  y?: number
  align?: CanvasTextAlign
  color?: 'bone' | 'solar'
  /** Brightness of glyph dots. */
  level?: number
  /** Stroke added round the glyph, in pitches. */
  thicken?: number
}

type Props = {
  className?: string
  pitch?: number
  dot?: number
  /** Base brightness of the empty field (0..1). */
  base?: number
  ring?: RingSpec
  litRef?: { current: number | null }
  /** Auto-scan wedges when litRef is null. */
  scanMs?: number
  glyph?: GlyphSpec
  wave?: { y: number; amp: number; cycles: number }
  /** Pointer glow radius in px (0 to disable). */
  glow?: number
  /** Static wedge to light in shot / reduced-motion mode. */
  shotLit?: number
  /** Auto-ping a ripple from the centre every n ms (frozen mid-flight when still). */
  ping?: number
}

const TAU = Math.PI * 2
const BONE = [237, 237, 230]
const SOLAR = [215, 255, 58]

function sprite(rgb: number[], r: number, blur: number, dpr: number) {
  const s = Math.ceil((r + blur) * 2 * dpr) + 2
  const c = document.createElement('canvas')
  c.width = c.height = s
  const g = c.getContext('2d')!
  const grd = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2)
  const [R, G, B] = rgb
  if (blur > 0) {
    grd.addColorStop(0, `rgba(${R},${G},${B},0.55)`)
    grd.addColorStop(0.35, `rgba(${R},${G},${B},0.18)`)
    grd.addColorStop(1, `rgba(${R},${G},${B},0)`)
  } else {
    grd.addColorStop(0, `rgba(${R},${G},${B},1)`)
    grd.addColorStop(0.62, `rgba(${R},${G},${B},1)`)
    grd.addColorStop(1, `rgba(${R},${G},${B},0)`)
  }
  g.fillStyle = grd
  g.fillRect(0, 0, s, s)
  return c
}

export function LedField({
  className, pitch = 10, dot = 1.35, base = 0.07, ring, litRef, scanMs = 650, glyph, wave, glow = 120, shotLit = 0, ping = 0,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')!
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const still = isShot || reduce
    const dpr = Math.min(window.devicePixelRatio || 1, 2)
    const bone = sprite(BONE, dot, 0, dpr)
    const solar = sprite(SOLAR, dot, 0, dpr)
    const halo = sprite(SOLAR, dot, dot * 4.5, dpr)
    const staticLayer = document.createElement('canvas')

    let W = 0, H = 0, cols = 0, rows = 0
    let xs = new Float32Array(0), ys = new Float32Array(0)
    let baseV = new Float32Array(0) // static brightness
    let wedgeOf = new Int16Array(0) // -1 none
    let glyphA = new Float32Array(0)
    let glyphCol = new Float32Array(0)
    let cx = 0, cy = 0, r0 = 0, r1 = 0
    const n = ring?.wedges ?? 0
    const wedgeI = new Float32Array(n)
    const pointer = { x: -9999, y: -9999, on: false, lastX: 0, lastY: 0, lastT: 0 }
    const ripples: { x: number; y: number; t0: number; k: number }[] = []
    const sparks: { i: number; t0: number }[] = []
    let visible = false
    let raf = 0
    const t0 = performance.now()
    let glyphStart = -1
    let lastPing = -1e9

    function layout() {
      const rect = canvas!.getBoundingClientRect()
      W = Math.max(1, Math.round(rect.width)); H = Math.max(1, Math.round(rect.height))
      canvas!.width = W * dpr; canvas!.height = H * dpr
      staticLayer.width = W * dpr; staticLayer.height = H * dpr
      cols = Math.floor(W / pitch) + 1; rows = Math.floor(H / pitch) + 1
      const ox = (W - (cols - 1) * pitch) / 2, oy = (H - (rows - 1) * pitch) / 2
      const N = cols * rows
      xs = new Float32Array(N); ys = new Float32Array(N); baseV = new Float32Array(N)
      wedgeOf = new Int16Array(N).fill(-1); glyphA = new Float32Array(N); glyphCol = new Float32Array(N)

      if (ring?.anchor.current) {
        const a = ring.anchor.current.getBoundingClientRect()
        cx = a.left + a.width / 2 - rect.left; cy = a.top + a.height / 2 - rect.top
        const half = a.width / 2
        r1 = half * ring.outer; r0 = half * ring.inner
      }
      const step = n ? TAU / n : 1
      const offset = -step / 2
      const gap = ring?.gap ?? pitch * 1.4
      const diag = Math.hypot(W, H) / 2

      for (let j = 0; j < rows; j++) for (let i = 0; i < cols; i++) {
        const k = j * cols + i
        const x = ox + i * pitch, y = oy + j * pitch
        xs[k] = x; ys[k] = y
        // Field: faint, falling off from the ring centre (or canvas centre).
        const fx = ring ? cx : W / 2, fy = ring ? cy : H / 2
        const d = Math.hypot(x - fx, y - fy)
        let v = base * (1 - Math.min(1, d / (diag * 1.15)) * 0.75)
        if (ring && d < r1 * 1.25) v *= 0.55
        if (ring && n) {
          if (d >= r0 && d <= r1) {
            let a = Math.atan2(x - cx, -(y - cy)) - offset
            a = ((a % TAU) + TAU) % TAU
            const w = Math.floor(a / step)
            const into = Math.min(a - w * step, (w + 1) * step - a) * d
            if (into > gap / 2) { wedgeOf[k] = w; v = 0.3 + 0.12 * ((d - r0) / (r1 - r0)) }
            else v = 0.02
          } else if (Math.abs(d - (r1 + pitch * 1.6)) < pitch * 0.5) {
            // Outer tick ring: every other dot, like a scale.
            v = (i + j) % 2 ? 0.16 : 0.05
          }
        }
        baseV[k] = v
      }
      if (glyph) rasterGlyph(ox, oy)
      bake()
    }

    function rasterGlyph(ox: number, oy: number) {
      const g = glyph!
      const off = document.createElement('canvas')
      off.width = W; off.height = H
      const gx = off.getContext('2d')!
      const size = H * g.height
      gx.font = `${g.style ?? ''} ${size}px ${g.family}`
      gx.textAlign = g.align ?? 'center'
      gx.textBaseline = 'middle'
      gx.fillStyle = '#fff'
      gx.fillText(g.text, W * (g.x ?? 0.5), H * (g.y ?? 0.5))
      // Thicken hairline serifs so the matrix reads as strokes, not outlines.
      gx.strokeStyle = '#fff'; gx.lineJoin = 'round'; gx.lineWidth = pitch * (g.thicken ?? 0.9)
      gx.strokeText(g.text, W * (g.x ?? 0.5), H * (g.y ?? 0.5))
      const img = gx.getImageData(0, 0, W, H).data
      let minI = cols, maxI = 0
      for (let j = 0; j < rows; j++) for (let i = 0; i < cols; i++) {
        const k = j * cols + i
        const x = Math.min(W - 1, Math.round(ox + i * pitch)), y = Math.min(H - 1, Math.round(oy + j * pitch))
        const a = img[(y * W + x) * 4 + 3] / 255
        glyphA[k] = a
        if (a > 0.4) { minI = Math.min(minI, i); maxI = Math.max(maxI, i) }
      }
      for (let k = 0; k < glyphA.length; k++) glyphCol[k] = ((k % cols) - minI) / Math.max(1, maxI - minI)
    }

    function bake() {
      const g = staticLayer.getContext('2d')!
      g.setTransform(1, 0, 0, 1, 0, 0)
      g.clearRect(0, 0, staticLayer.width, staticLayer.height)
      g.setTransform(dpr, 0, 0, dpr, 0, 0)
      const s = bone.width / dpr
      for (let k = 0; k < baseV.length; k++) {
        const v = baseV[k]
        if (v < 0.015) continue
        g.globalAlpha = Math.min(1, v)
        g.drawImage(bone, xs[k] - s / 2, ys[k] - s / 2, s, s)
      }
      g.globalAlpha = 1
    }

    function frame(now: number) {
      const t = now - t0
      ctx.setTransform(1, 0, 0, 1, 0, 0)
      ctx.clearRect(0, 0, canvas!.width, canvas!.height)
      ctx.drawImage(staticLayer, 0, 0)
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

      // Wedge intensities: fast attack, slow phosphor decay.
      if (n) {
        let target: number | null
        if (still) target = litRef?.current ?? shotLit
        else target = litRef ? litRef.current : null
        if (target == null && !still) target = Math.floor(t / scanMs) % n
        for (let w = 0; w < n; w++) {
          const goal = w === target ? 1 : 0
          if (still) wedgeI[w] = goal
          else wedgeI[w] += (goal - wedgeI[w]) * (goal > wedgeI[w] ? 0.45 : 0.07)
        }
      }
      if (ping) {
        if (still) { if (!ripples.length) ripples.push({ x: W / 2, y: H / 2, t0: t - 380, k: 0.95 }) }
        else if (t - lastPing > ping) { lastPing = t; ripples.push({ x: W / 2, y: H / 2, t0: t, k: 0.95 }) }
      }
      // Ripples age out.
      for (let r = ripples.length - 1; r >= 0; r--) if (t - ripples[r].t0 > 1600) ripples.splice(r, 1)
      // Sparkles: a few random field dots blink.
      if (!still && Math.random() < 0.35 && baseV.length) sparks.push({ i: (Math.random() * baseV.length) | 0, t0: t })
      for (let s = sparks.length - 1; s >= 0; s--) if (t - sparks[s].t0 > 900) sparks.splice(s, 1)

      let reveal = 1.2
      if (glyph && !still) {
        if (glyphStart < 0 && visible) glyphStart = t
        reveal = glyphStart < 0 ? 0 : Math.min(1.2, (t - glyphStart) / 1400)
      }
      const s = bone.width / dpr
      const hs = halo.width / dpr
      const R = glow
      const px = pointer.on ? pointer.x : -9999, py = pointer.on ? pointer.y : -9999
      const hasRipples = ripples.length > 0
      const wave_ = wave
      for (let k = 0; k < baseV.length; k++) {
        const x = xs[k], y = ys[k]
        let v = 0, lime = 0
        const w = wedgeOf[k]
        if (w >= 0 && wedgeI[w] > 0.01) {
          const wi = wedgeI[w]
          v = 0.3 + 0.7 * wi; lime = Math.min(1, wi * 1.25)
        }
        if (glyph) {
          const ga = glyphA[k]
          if (ga > 0.35) {
            const c = glyphCol[k]
            const on = reveal >= 1.2 ? 1 : c < reveal - 0.12 ? 1 : c < reveal ? 1.6 : 0
            const lv = (glyph.level ?? 0.9) * on
            if (lv > v) { v = Math.min(1, lv); lime = glyph.color === 'solar' || on > 1 ? 1 : lime }
          }
        }
        if (wave_) {
          const wy = H * wave_.y + Math.sin((x / W) * TAU * wave_.cycles - t / 700) * H * wave_.amp * (0.6 + 0.4 * Math.sin(t / 1900 + x / 300))
          const dd = Math.abs(y - wy)
          if (dd < pitch * 1.2) { const lv = (1 - dd / (pitch * 1.2)) * 0.95; if (lv > v) { v = lv; lime = 1 } }
        }
        if (R > 0) {
          const dx = x - px, dy = y - py
          const d2 = dx * dx + dy * dy
          if (d2 < R * R) { const f = 1 - Math.sqrt(d2) / R; v = Math.max(v, baseV[k] + 0.55 * f * f) }
        }
        if (hasRipples) {
          for (let r = 0; r < ripples.length; r++) {
            const rp = ripples[r]
            const age = t - rp.t0
            const d = Math.hypot(x - rp.x, y - rp.y)
            const front = age * 0.42
            const band = d - front
            if (band > -26 && band < 26) {
              const amp = rp.k * Math.max(0, 1 - age / 1600) * Math.exp(-(band * band) / 180)
              if (amp > 0.02) { v = Math.max(v, baseV[k] + amp); if (rp.k > 0.8) lime = Math.max(lime, amp * 0.9) }
            }
          }
        }
        if (v <= baseV[k] + 0.01) continue
        v = Math.min(1, v)
        if (lime > 0.02) {
          ctx.globalAlpha = v * lime
          const sz = s * (1 + 0.35 * v)
          ctx.drawImage(solar, x - sz / 2, y - sz / 2, sz, sz)
          if (lime > 0.45) { ctx.globalAlpha = 0.5 * v * lime; ctx.drawImage(halo, x - hs / 2, y - hs / 2, hs, hs) }
          if (lime < 0.98) { ctx.globalAlpha = v * (1 - lime); ctx.drawImage(bone, x - s / 2, y - s / 2, s, s) }
        } else {
          ctx.globalAlpha = v
          const sz = s * (1 + 0.25 * v)
          ctx.drawImage(bone, x - sz / 2, y - sz / 2, sz, sz)
        }
      }
      for (const sp of sparks) {
        const age = (t - sp.t0) / 900
        const a = Math.sin(age * Math.PI) * 0.5
        ctx.globalAlpha = a
        ctx.drawImage(bone, xs[sp.i] - s / 2, ys[sp.i] - s / 2, s, s)
      }
      ctx.globalAlpha = 1
    }

    const loop = (now: number) => { frame(now); raf = visible ? requestAnimationFrame(loop) : 0 }
    const start = () => { if (!raf && !still) raf = requestAnimationFrame(loop) }

    layout()
    frame(performance.now())
    // Fonts may land after first layout (glyph raster).
    document.fonts?.ready.then(() => { layout(); frame(performance.now()) })

    const ro = new ResizeObserver(() => { layout(); frame(performance.now()) })
    ro.observe(canvas)
    if (ring?.anchor.current) ro.observe(ring.anchor.current)
    let io: IntersectionObserver | undefined
    if (!still) {
      io = new IntersectionObserver(([e]) => { visible = e.isIntersecting; if (visible) start() }, { rootMargin: '100px' })
      io.observe(canvas)
      start()
    }
    let stillTimer = 0
    if (still && litRef && !isShot) stillTimer = window.setInterval(() => frame(performance.now()), 300)

    const onMove = (e: PointerEvent) => {
      const r = canvas.getBoundingClientRect()
      const x = e.clientX - r.left, y = e.clientY - r.top
      pointer.on = x >= 0 && y >= 0 && x <= r.width && y <= r.height
      pointer.x = x; pointer.y = y
      if (!pointer.on || still) return
      const now = performance.now() - t0
      if (Math.hypot(x - pointer.lastX, y - pointer.lastY) > 70 && now - pointer.lastT > 140) {
        ripples.push({ x, y, t0: now, k: 0.32 }); pointer.lastX = x; pointer.lastY = y; pointer.lastT = now
        if (ripples.length > 6) ripples.shift()
      }
    }
    const onDown = (e: PointerEvent) => {
      const r = canvas.getBoundingClientRect()
      const x = e.clientX - r.left, y = e.clientY - r.top
      if (x < 0 || y < 0 || x > r.width || y > r.height || still) return
      ripples.push({ x, y, t0: performance.now() - t0, k: 0.95 })
    }
    const onLeave = () => { pointer.on = false }
    window.addEventListener('pointermove', onMove, { passive: true })
    window.addEventListener('pointerdown', onDown, { passive: true })
    document.addEventListener('pointerleave', onLeave)
    return () => {
      cancelAnimationFrame(raf); ro.disconnect(); io?.disconnect(); clearInterval(stillTimer)
      window.removeEventListener('pointermove', onMove)
      window.removeEventListener('pointerdown', onDown)
      document.removeEventListener('pointerleave', onLeave)
    }
  }, [pitch, dot, base, ring?.outer, ring?.inner, ring?.wedges, glyph?.text, glyph?.height, glyph?.x, glyph?.y, wave?.y, glow]) // eslint-disable-line react-hooks/exhaustive-deps

  return <canvas ref={canvasRef} aria-hidden className={cn('pointer-events-none block h-full w-full', className)} />
}
