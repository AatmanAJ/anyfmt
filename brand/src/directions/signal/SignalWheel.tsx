import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useMemo, useRef, useState, type ReactNode } from 'react'
import { isShot } from '../../shared/kit'
import type { WheelSegment } from '../../shared/Wheel'
import { cn } from '../../shared/cn'
import { C } from './tokens'

const TAU = Math.PI * 2

function sectorPath(c: number, r0: number, r1: number, a0: number, a1: number, gapPx: number) {
  const g0 = gapPx / 2 / r0, g1 = gapPx / 2 / r1
  const pt = (r: number, a: number) => [c + r * Math.sin(a), c - r * Math.cos(a)]
  const [x0, y0] = pt(r1, a0 + g1), [x1, y1] = pt(r1, a1 - g1), [x2, y2] = pt(r0, a1 - g0), [x3, y3] = pt(r0, a0 + g0)
  const large = a1 - a0 > Math.PI ? 1 : 0
  return `M${x0},${y0} A${r1},${r1} 0 ${large} 1 ${x1},${y1} L${x2},${y2} A${r0},${r0} 0 ${large} 0 ${x3},${y3} Z`
}

type Props = {
  segments: readonly WheelSegment[]
  size?: number
  hoverIndex?: number | null
  interactive?: boolean
  open?: boolean
  onPick?: (s: WheelSegment, i: number) => void
  onHover?: (i: number | null) => void
  hub?: ReactNode
  className?: string
  /** Show the LED ring round the disc. */
  ring?: boolean
  /** Show channel numbers. */
  channels?: boolean
  /** Wedge shown lit while the pointer is away (uncontrolled mode). */
  restIndex?: number | null
}

/**
 * The Signal wheel. Matte carbon wedges, the aimed one lights solar. A ring of 72 LEDs round the disc
 * mirrors the aim like a tuner's scale.
 */
export function SignalWheel({
  segments, size = 320, hoverIndex, interactive = true, open = true, onPick, onHover, hub, className, ring = true, channels = true, restIndex = null,
}: Props) {
  const n = segments.length
  const half = size / 2
  const r0 = half * 0.35, r1 = half * (ring ? 0.85 : 0.97)
  const step = TAU / n
  const offset = -step / 2
  const gap = Math.max(3, size / 90)
  const [ptr, setPtr] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const active = hoverIndex !== undefined ? hoverIndex : (ptr ?? restIndex)
  const fs = Math.max(9, Math.min(12, size / 29))

  const wedges = useMemo(() => segments.map((s, i) => {
    const a0 = offset + i * step, a1 = a0 + step
    return { s, i, mid: (a0 + a1) / 2, path: sectorPath(half, r0, r1, a0, a1, gap) }
  }), [segments, offset, step, half, r0, r1, gap])

  const dots = useMemo(() => {
    const N = 72, rr = half * 0.935
    return Array.from({ length: N }, (_, i) => {
      const a = (i / N) * TAU
      let rel = a - offset
      rel = ((rel % TAU) + TAU) % TAU
      return { x: half + rr * Math.sin(a), y: half - rr * Math.cos(a), w: Math.floor(rel / step), major: i % 3 === 0 }
    })
  }, [half, offset, step])

  const hit = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half, d = Math.hypot(dx, dy)
    if (d < r0 * 0.85 || d > half + 16) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    if (ptr !== null && ptr !== idx) {
      const mid = (ptr + 0.5) * step
      let delta = Math.abs(a - mid); delta = Math.min(delta, TAU - delta)
      if (delta < step / 2 + Math.max(step * 0.3, (10 * Math.PI) / 180) * 0.6) return ptr
    }
    return idx
  }, [half, r0, offset, step, ptr])

  const set = (v: number | null) => { if (v !== ptr) { setPtr(v); onHover?.(v) } }
  const onMove = (e: React.PointerEvent) => {
    if (!interactive || hoverIndex !== undefined) return
    const r = ref.current!.getBoundingClientRect()
    set(hit(e.clientX - r.left, e.clientY - r.top))
  }

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          ref={ref}
          className={cn('relative select-none', interactive && hoverIndex === undefined && 'cursor-crosshair', className)}
          style={{ width: size, height: size }}
          initial={isShot ? false : { scale: 0.6, opacity: 0, rotate: -10 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          exit={{ scale: 0.7, opacity: 0, rotate: 6, transition: { duration: 0.14 } }}
          transition={{ type: 'spring', stiffness: 420, damping: 28 }}
          onPointerMove={onMove}
          onPointerLeave={() => hoverIndex === undefined && set(null)}
          onClick={() => active != null && onPick?.(segments[active], active)}
          role="menu" aria-label="Wheel"
        >
          {/* Disc: vibrancy carbon with a hairline. */}
          <div className="absolute inset-0 rounded-full" style={{
            background: `radial-gradient(circle at 50% 38%, rgba(32,32,36,.92), rgba(10,10,12,.94) 70%)`,
            boxShadow: `inset 0 0 0 1px ${C.graphite}, inset 0 1px 0 rgba(255,255,255,.07), 0 30px 70px -20px rgba(0,0,0,.9), 0 0 0 0.5px rgba(0,0,0,.9)`,
            backdropFilter: 'blur(24px) saturate(150%)', WebkitBackdropFilter: 'blur(24px) saturate(150%)',
          }} />
          {ring && (
            <svg className="pointer-events-none absolute inset-0" width={size} height={size} aria-hidden>
              <defs>
                <filter id="sgw-glow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation={size / 160} /></filter>
              </defs>
              {dots.map((d, i) => {
                const on = active === d.w
                return (
                  <g key={i}>
                    {on && <circle cx={d.x} cy={d.y} r={size / 110} fill={C.solar} opacity={0.8} filter="url(#sgw-glow)" />}
                    <circle cx={d.x} cy={d.y} r={size / (d.major ? 230 : 300)} fill={on ? C.solar : d.major ? '#4A4A50' : '#2E2E33'}
                      style={{ transition: 'fill 120ms' }} />
                  </g>
                )
              })}
            </svg>
          )}
          {wedges.map(({ s, i, mid, path }) => {
            const hot = active === i
            const rm = (r0 + r1) / 2
            const lx = half + rm * Math.sin(mid), ly = half - rm * Math.cos(mid)
            const lift = size / 64
            return (
              <motion.div key={s.id} role="menuitem" aria-label={s.label} className="absolute inset-0"
                initial={isShot ? false : { opacity: 0, scale: 0.7 }}
                animate={{ opacity: 1, scale: hot ? 1.03 : 1, x: hot ? lift * Math.sin(mid) : 0, y: hot ? -lift * Math.cos(mid) : 0 }}
                transition={{ type: 'spring', stiffness: 560, damping: 32, delay: i * 0.014 }}
                style={{ transformOrigin: `${half}px ${half}px`, zIndex: hot ? 2 : 1 }}>
                <div className="absolute inset-0" style={{
                  clipPath: `path('${path}')`, WebkitClipPath: `path('${path}')`,
                  background: hot
                    ? `radial-gradient(circle at 50% 50%, #F2FFA8 ${r0}px, ${C.solar} ${r0 + (r1 - r0) * 0.6}px, #BFE81C ${r1}px)`
                    : `radial-gradient(circle at 50% 50%, #232327 ${r0}px, #141416 ${r1}px)`,
                  transition: 'background 120ms',
                }} />
                <svg className="pointer-events-none absolute inset-0" width={size} height={size} aria-hidden>
                  <path d={path} fill="none" stroke={hot ? 'rgba(255,255,255,.55)' : 'rgba(255,255,255,.06)'} strokeWidth={1} />
                </svg>
                <div className="pointer-events-none absolute flex -translate-x-1/2 -translate-y-1/2 flex-col items-center text-center font-mono uppercase leading-none"
                  style={{ left: lx, top: ly, color: hot ? C.void : C.bone, fontSize: fs }}>
                  {channels && <span className="mb-[0.5em] text-[0.72em] font-medium tracking-[0.1em]" style={{ color: hot ? 'rgba(5,5,6,.55)' : C.ash2 }}>{String(i + 1).padStart(2, '0')}</span>}
                  {s.icon && <span className="mb-1">{s.icon}</span>}
                  <span className="whitespace-nowrap font-semibold tracking-[0.08em]">{s.label}</span>
                  {s.sub && <span className="mt-[0.45em] whitespace-nowrap text-[0.74em] font-medium normal-case tracking-[0.02em]" style={{ color: hot ? 'rgba(5,5,6,.7)' : C.ash }}>{s.sub}</span>}
                </div>
              </motion.div>
            )
          })}
          {/* Hub */}
          <div className="absolute left-1/2 top-1/2 z-[3] flex -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center rounded-full text-center"
            style={{ width: r0 * 2 - gap * 2.5, height: r0 * 2 - gap * 2.5, background: `radial-gradient(circle at 50% 30%, #1A1A1D, ${C.void} 75%)`, color: C.bone, boxShadow: `inset 0 0 0 1px ${C.graphite}, inset 0 1px 0 rgba(255,255,255,.06)` }}>
            {hub}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

/** Standard hub content: file stem in serif italic, extension + size in mono. */
export function FileHub({ stem, ext, meta, size = 320 }: { stem: string; ext: string; meta?: string; size?: number }) {
  return (
    <>
      <span className="font-serif italic leading-none tracking-[-0.02em]" style={{ fontSize: size / 11 }}>{stem}</span>
      <span className="mt-1 font-mono uppercase tracking-[0.14em]" style={{ fontSize: Math.max(8, size / 36), color: C.ash }}>{ext}{meta ? ` · ${meta}` : ''}</span>
    </>
  )
}
