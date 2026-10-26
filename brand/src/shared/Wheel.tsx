import { motion, AnimatePresence } from 'motion/react'
import { useCallback, useMemo, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { cn } from './cn'
import { isShot } from './kit'

/** How a direction dresses the wheel. Every colour is plain CSS, so gradients and glass work. */
export type WheelSkin = {
  /** Disc behind the wedges (CSS background). */
  disc: string
  discClassName?: string
  discStyle?: CSSProperties
  /** Wedge at rest / hovered (CSS backgrounds; gradients welcome). */
  segment: string
  segmentHover: string
  /** Optional extra style on every wedge (e.g. backdrop-filter for glass). */
  segmentStyle?: CSSProperties
  segmentHoverStyle?: CSSProperties
  label: string
  labelHover: string
  labelClassName?: string
  /** Hub circle. */
  hub: string
  hubText: string
  hubClassName?: string
  hubStyle?: CSSProperties
  /** Gap between wedges in px at the inner radius. */
  gap?: number
  /** Inner/outer radius as a fraction of the half-size. */
  inner?: number
  outer?: number
  /** Hovered wedge lifts outward by this many px. */
  lift?: number
  /** Ring outline drawn round the hovered wedge (e.g. a lock). */
  hoverRing?: string
}

export type WheelSegment = { id: string; label: string; sub?: string; icon?: ReactNode }

type Props = {
  segments: readonly WheelSegment[]
  skin: WheelSkin
  size?: number
  hubLabel?: ReactNode
  hubSub?: ReactNode
  /** Controlled hover index (autoplay). When undefined the pointer drives it. */
  hoverIndex?: number | null
  /** Pointer drives hover. */
  interactive?: boolean
  open?: boolean
  onPick?: (segment: WheelSegment, index: number) => void
  className?: string
  /** Rotate so the first wedge is centred at 12 o'clock. */
  startAngle?: number
}

const TAU = Math.PI * 2

/** Annular sector path (clock angles: 0 = 12 o'clock, clockwise), in px, origin top-left. */
function sectorPath(c: number, r0: number, r1: number, a0: number, a1: number, gapPx: number) {
  // Constant-width gap: shrink each edge by gap/2 measured as an arc at each radius.
  const g0 = gapPx / 2 / r0
  const g1 = gapPx / 2 / r1
  const pt = (r: number, a: number) => [c + r * Math.sin(a), c - r * Math.cos(a)]
  const [x0, y0] = pt(r1, a0 + g1)
  const [x1, y1] = pt(r1, a1 - g1)
  const [x2, y2] = pt(r0, a1 - g0)
  const [x3, y3] = pt(r0, a0 + g0)
  const large = a1 - a0 > Math.PI ? 1 : 0
  return `M${x0},${y0} A${r1},${r1} 0 ${large} 1 ${x1},${y1} L${x2},${y2} A${r0},${r0} 0 ${large} 0 ${x3},${y3} Z`
}

export function Wheel({
  segments, skin, size = 360, hubLabel, hubSub, hoverIndex, interactive = true, open = true, onPick, className, startAngle,
}: Props) {
  const n = segments.length
  const half = size / 2
  const r0 = half * (skin.inner ?? 0.36)
  const r1 = half * (skin.outer ?? 0.97)
  const step = TAU / n
  const offset = startAngle ?? -step / 2
  const gap = skin.gap ?? 6
  const lift = skin.lift ?? 8
  const [pointerHover, setPointerHover] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const active = hoverIndex !== undefined ? hoverIndex : pointerHover

  const wedges = useMemo(() => segments.map((s, i) => {
    const a0 = offset + i * step
    const a1 = a0 + step
    const mid = (a0 + a1) / 2
    return { s, i, a0, a1, mid, path: sectorPath(half, r0, r1, a0, a1, gap) }
  }), [segments, offset, step, half, r0, r1, gap])

  const hitTest = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half
    const d = Math.hypot(dx, dy)
    if (d < r0 * 0.85 || d > r1 + 24) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    // Sticky selection: stay on the current wedge until clearly past its edge (like the app).
    if (pointerHover !== null && pointerHover !== idx) {
      const curMid = (pointerHover + 0.5) * step
      let delta = Math.abs(a - curMid)
      delta = Math.min(delta, TAU - delta)
      if (delta < step / 2 + Math.max(step * 0.3, (10 * Math.PI) / 180) * 0.6) return pointerHover
    }
    return idx
  }, [half, r0, r1, offset, step, pointerHover])

  const onMove = (e: React.PointerEvent) => {
    if (!interactive || hoverIndex !== undefined) return
    const rect = ref.current!.getBoundingClientRect()
    setPointerHover(hitTest(e.clientX - rect.left, e.clientY - rect.top))
  }

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          ref={ref}
          className={cn('relative select-none', className)}
          style={{ width: size, height: size }}
          initial={isShot ? false : { scale: 0.55, opacity: 0, rotate: -12 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          exit={{ scale: 0.6, opacity: 0, rotate: 8, transition: { duration: 0.16 } }}
          transition={{ type: 'spring', stiffness: 380, damping: 26 }}
          onPointerMove={onMove}
          onPointerLeave={() => hoverIndex === undefined && setPointerHover(null)}
          onClick={() => active != null && onPick?.(segments[active], active)}
          role="menu"
          aria-label="Wheel"
        >
          {/* Disc */}
          <div className={cn('absolute inset-0 rounded-full', skin.discClassName)}
               style={{ background: skin.disc, ...skin.discStyle }} />
          {/* Wedges */}
          {wedges.map(({ s, i, mid, path }) => {
            const hot = active === i
            const lx = half + ((r0 + r1) / 2) * Math.sin(mid)
            const ly = half - ((r0 + r1) / 2) * Math.cos(mid)
            return (
              <motion.div
                key={s.id}
                role="menuitem"
                aria-label={s.label}
                className="absolute inset-0"
                initial={isShot ? false : { opacity: 0, scale: 0.6 }}
                animate={{
                  opacity: 1,
                  scale: hot ? 1.035 : 1,
                  x: hot ? lift * Math.sin(mid) : 0,
                  y: hot ? -lift * Math.cos(mid) : 0,
                }}
                transition={{ type: 'spring', stiffness: 520, damping: 30, delay: open ? i * 0.012 : 0 }}
                style={{ transformOrigin: `${half}px ${half}px`, zIndex: hot ? 2 : 1 }}
              >
                <div
                  className="absolute inset-0 transition-[background] duration-150"
                  style={{
                    clipPath: `path('${path}')`,
                    WebkitClipPath: `path('${path}')`,
                    background: hot ? skin.segmentHover : skin.segment,
                    ...(hot ? { ...skin.segmentStyle, ...skin.segmentHoverStyle } : skin.segmentStyle),
                  }}
                />
                {hot && skin.hoverRing && (
                  <svg className="pointer-events-none absolute inset-0" width={size} height={size}>
                    <path d={path} fill="none" stroke={skin.hoverRing} strokeWidth={2.5} />
                  </svg>
                )}
                <div
                  className={cn('pointer-events-none absolute flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-0.5 text-center leading-none transition-colors duration-150', skin.labelClassName)}
                  style={{ left: lx, top: ly, color: hot ? skin.labelHover : skin.label }}
                >
                  {s.icon}
                  <span>{s.label}</span>
                  {s.sub && <span className="text-[0.55em] font-medium opacity-70">{s.sub}</span>}
                </div>
              </motion.div>
            )
          })}
          {/* Hub */}
          <div
            className={cn('absolute left-1/2 top-1/2 flex -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center rounded-full text-center', skin.hubClassName)}
            style={{ width: r0 * 2 - 10, height: r0 * 2 - 10, background: skin.hub, color: skin.hubText, zIndex: 3, ...skin.hubStyle }}
          >
            {hubLabel}
            {hubSub}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
