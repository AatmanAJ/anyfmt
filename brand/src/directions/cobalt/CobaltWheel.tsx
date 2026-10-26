import { motion, AnimatePresence } from 'motion/react'
import { useCallback, useId, useMemo, useRef, useState, type ReactNode } from 'react'
import { isShot } from '../../shared/kit'
import { cn } from '../../shared/cn'
import { C } from './tokens'

export type Seg = { id: string; label: string; sub?: string; icon?: ReactNode }

const TAU = Math.PI * 2

function sector(c: number, r0: number, r1: number, a0: number, a1: number, gap: number) {
  const g0 = gap / 2 / r0, g1 = gap / 2 / r1
  const pt = (r: number, a: number) => `${(c + r * Math.sin(a)).toFixed(2)},${(c - r * Math.cos(a)).toFixed(2)}`
  const large = a1 - a0 > Math.PI ? 1 : 0
  return `M${pt(r1, a0 + g1)} A${r1},${r1} 0 ${large} 1 ${pt(r1, a1 - g1)} L${pt(r0, a1 - g0)} A${r0},${r0} 0 ${large} 0 ${pt(r0, a0 + g0)} Z`
}

/**
 * The Cobalt wheel. Deep-blue glass disc with speedometer ticks, wedges in cobalt glass,
 * the hovered wedge in flame with a hard glow, labels in Anton.
 */
export function CobaltWheel({
  segments, size = 340, hoverIndex, interactive = true, open = true, onPick, hubLabel, hubSub, className, labelSize,
}: {
  segments: readonly Seg[]; size?: number; hoverIndex?: number | null; interactive?: boolean; open?: boolean
  onPick?: (s: Seg, i: number) => void; hubLabel?: ReactNode; hubSub?: ReactNode; className?: string; labelSize?: number
}) {
  const uid = useId().replace(/:/g, '')
  const n = segments.length
  const half = size / 2
  const r0 = half * 0.35, r1 = half * 0.86, rt0 = half * 0.9, rt1 = half * 0.97
  const step = TAU / n
  const offset = -step / 2
  const gap = Math.max(3, size / 90)
  const lift = size / 30
  const [ph, setPh] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const active = hoverIndex !== undefined ? hoverIndex : ph
  const ls = labelSize ?? Math.max(11, Math.round(size / 22))

  const wedges = useMemo(() => segments.map((s, i) => {
    const a0 = offset + i * step, a1 = a0 + step, mid = (a0 + a1) / 2
    return { s, i, mid, path: sector(half, r0, r1, a0, a1, gap) }
  }), [segments, offset, step, half, r0, r1, gap])

  const ticks = useMemo(() => {
    const out: { x1: number; y1: number; x2: number; y2: number; major: boolean }[] = []
    const count = 72
    for (let k = 0; k < count; k++) {
      const a = (k / count) * TAU
      const major = k % (count / 8) === 0
      const ra = major ? rt0 - 2 : rt0 + 2
      out.push({ x1: half + ra * Math.sin(a), y1: half - ra * Math.cos(a), x2: half + rt1 * Math.sin(a), y2: half - rt1 * Math.cos(a), major })
    }
    return out
  }, [half, rt0, rt1])

  const hit = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half, d = Math.hypot(dx, dy)
    if (d < r0 * 0.85 || d > half + 20) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    if (ph !== null && ph !== idx) {
      const cm = (ph + 0.5) * step
      let dd = Math.abs(a - cm); dd = Math.min(dd, TAU - dd)
      if (dd < step / 2 + step * 0.12) return ph
    }
    return idx
  }, [half, r0, offset, step, ph])

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          ref={ref}
          className={cn('relative shrink-0 select-none', interactive && 'cursor-crosshair', className)}
          style={{ width: size, height: size }}
          initial={isShot ? false : { scale: 0.5, opacity: 0, rotate: -20 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          exit={{ scale: 0.6, opacity: 0, rotate: 10, transition: { duration: 0.14 } }}
          transition={{ type: 'spring', stiffness: 520, damping: 28 }}
          onPointerMove={(e) => {
            if (!interactive || hoverIndex !== undefined) return
            const r = ref.current!.getBoundingClientRect()
            setPh(hit(e.clientX - r.left, e.clientY - r.top))
          }}
          onPointerLeave={() => hoverIndex === undefined && setPh(null)}
          onClick={() => active != null && onPick?.(segments[active], active)}
          role="menu" aria-label="Halo wheel"
        >
          <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="absolute inset-0 overflow-visible" aria-hidden>
            <defs>
              <radialGradient id={`disc${uid}`} cx="50%" cy="42%" r="60%">
                <stop offset="0" stopColor="#13238F" />
                <stop offset=".62" stopColor={C.midnight} />
                <stop offset="1" stopColor={C.deep} />
              </radialGradient>
              <linearGradient id={`seg${uid}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor="#3653FF" stopOpacity=".62" />
                <stop offset="1" stopColor={C.ultra} stopOpacity=".72" />
              </linearGradient>
              <linearGradient id={`hot${uid}`} x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stopColor={C.flameHot} />
                <stop offset=".5" stopColor={C.flame} />
                <stop offset="1" stopColor={C.flameDeep} />
              </linearGradient>
              <filter id={`glow${uid}`} x="-60%" y="-60%" width="220%" height="220%">
                <feGaussianBlur stdDeviation={size / 34} />
              </filter>
            </defs>
            {/* disc + rim */}
            <circle cx={half} cy={half} r={half} fill={`url(#disc${uid})`} />
            <circle cx={half} cy={half} r={half - 0.75} fill="none" stroke={C.ice} strokeOpacity=".16" strokeWidth="1.5" />
            {ticks.map((t, k) => (
              <line key={k} x1={t.x1} y1={t.y1} x2={t.x2} y2={t.y2} stroke={t.major ? C.ice : C.steel}
                    strokeOpacity={t.major ? 0.85 : 0.35} strokeWidth={t.major ? 2 : 1} />
            ))}
            {wedges.map(({ s, i, mid, path }) => {
              const hot = active === i
              return (
                <motion.g key={s.id}
                  initial={isShot ? false : { opacity: 0 }}
                  animate={{ opacity: 1, x: hot ? lift * Math.sin(mid) : 0, y: hot ? -lift * Math.cos(mid) : 0 }}
                  transition={{ type: 'spring', stiffness: 700, damping: 30, delay: i * 0.015 }}>
                  {hot && <path d={path} fill={C.flame} filter={`url(#glow${uid})`} opacity=".95" />}
                  <path d={path} fill={hot ? `url(#hot${uid})` : `url(#seg${uid})`} />
                  <path d={path} fill="none" stroke={hot ? '#FFD2BC' : C.ice} strokeOpacity={hot ? 0.9 : 0.12} strokeWidth={hot ? 1.5 : 1} />
                </motion.g>
              )
            })}
          </svg>
          {/* labels */}
          {wedges.map(({ s, i, mid }) => {
            const hot = active === i
            const rm = (r0 + r1) / 2
            return (
              <div key={s.id} role="menuitem" aria-label={s.label}
                className="pointer-events-none absolute -translate-x-1/2 -translate-y-1/2"
                style={{ left: half + rm * Math.sin(mid), top: half - rm * Math.cos(mid) }}>
                <motion.div initial={false} animate={{ x: hot ? lift * Math.sin(mid) : 0, y: hot ? -lift * Math.cos(mid) : 0 }}
                  transition={{ type: 'spring', stiffness: 700, damping: 30 }}
                  className="flex flex-col items-center gap-[3px] text-center font-anton uppercase leading-none tracking-[0.03em] transition-colors duration-150"
                  style={{ color: hot ? C.midnight : C.ice, fontSize: ls }}>
                  {s.icon}
                  <span className="whitespace-nowrap">{s.label}</span>
                  {s.sub && <span className="font-mono text-[0.58em] font-semibold tracking-normal opacity-75">{s.sub}</span>}
                </motion.div>
              </div>
            )
          })}
          {/* hub */}
          <div className="absolute left-1/2 top-1/2 z-[3] flex -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center rounded-full text-center"
               style={{ width: r0 * 2 - gap * 3, height: r0 * 2 - gap * 3, background: `radial-gradient(circle at 50% 30%, #0E1B6E, ${C.midnight} 70%)`, color: C.ice, boxShadow: `inset 0 0 0 1.5px rgba(233,238,255,.2), 0 0 0 ${gap}px ${C.deep}` }}>
            {hubLabel}
            {hubSub}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

export function Hub({ top, bottom, size = 340 }: { top: string; bottom?: string; size?: number }) {
  return (
    <>
      <span className="font-anton leading-none" style={{ fontSize: Math.round(size / 15) }}>{top}</span>
      {bottom && <span className="mt-1 font-mono uppercase tracking-[0.14em] opacity-60" style={{ fontSize: Math.max(8, Math.round(size / 40)) }}>{bottom}</span>}
    </>
  )
}
