import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useMemo, useRef, useState, type ReactNode } from 'react'
import { isShot } from '../shared/kit'

export type Wedge = { id: string; label: string; sub?: string; icon?: ReactNode }

const TAU = Math.PI * 2

function sector(c: number, r0: number, r1: number, a0: number, a1: number, gap: number) {
  const e0 = gap / 2 / r0, e1 = gap / 2 / r1
  const p = (r: number, a: number) => `${(c + r * Math.sin(a)).toFixed(2)},${(c - r * Math.cos(a)).toFixed(2)}`
  const large = a1 - a0 > Math.PI ? 1 : 0
  return `M${p(r1, a0 + e1)} A${r1},${r1} 0 ${large} 1 ${p(r1, a1 - e1)} L${p(r0, a1 - e0)} A${r0},${r0} 0 ${large} 0 ${p(r0, a0 + e0)} Z`
}

const TONES = {
  /** On paper or pastel grounds: white wedges, hairline gaps. */
  light: { disc: '#000000', ring: '#000000', rest: '#FFFFFF', restText: '#000000', sub: '#686562', hub: '#F8FAFC', hubText: '#000000' },
  /** On black grounds. */
  dark: { disc: '#3A3A3A', ring: '#3A3A3A', rest: '#111111', restText: '#FFFFFF', sub: '#9A9794', hub: '#FFFFFF', hubText: '#000000' },
}

type Props = {
  wedges: readonly Wedge[]
  size?: number
  active?: number | null
  onAim?: (i: number | null) => void
  onPick?: (w: Wedge, i: number) => void
  open?: boolean
  hub?: ReactNode
  tone?: keyof typeof TONES
  className?: string
}

// The aimed wedge fills black (white on dark); orange only marks it with a thin tick at the rim.
const HOT = {
  light: { fill: '#000000', text: '#FFFFFF' },
  dark: { fill: '#FFFFFF', text: '#000000' },
}

/** The wheel in the Sheet style: flat and monochrome; the aimed wedge fills, an orange tick marks it. */
export function SheetWheel({ wedges, size = 380, active, onAim, onPick, open = true, hub, tone = 'light', className }: Props) {
  const t = TONES[tone], h = HOT[tone]
  const n = wedges.length
  const half = size / 2
  const r0 = half * 0.36, r1 = half * 0.94
  const step = TAU / n, offset = -step / 2
  const gap = Math.max(2, size * 0.006)
  const pop = 0
  const [hover, setHover] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const aim = active !== undefined ? active : hover

  const geo = useMemo(() => wedges.map((w, i) => {
    const a0 = offset + i * step, a1 = a0 + step
    return { w, i, mid: (a0 + a1) / 2, d: sector(half, r0, r1, a0, a1, gap) }
  }), [wedges, offset, step, half, r0, r1, gap])

  const hit = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half, d = Math.hypot(dx, dy)
    if (d < r0 * 0.8 || d > r1 + 28) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    if (hover !== null && hover !== idx) {
      let delta = Math.abs(a - (hover + 0.5) * step)
      delta = Math.min(delta, TAU - delta)
      if (delta < step / 2 + step * 0.18) return hover
    }
    return idx
  }, [half, r0, r1, offset, step, hover])

  const move = (e: React.PointerEvent) => {
    if (active !== undefined) return
    const r = ref.current!.getBoundingClientRect()
    const k = size / r.width // stays right when the wheel is scaled
    const next = hit((e.clientX - r.left) * k, (e.clientY - r.top) * k)
    if (next !== hover) { setHover(next); onAim?.(next) }
  }

  return (
    <AnimatePresence>
      {open && (
        <motion.div ref={ref} className={className} role="menu" aria-label="Format wheel"
          style={{ width: size, height: size, position: 'relative', touchAction: 'none' }}
          initial={isShot ? false : { scale: 0.6, opacity: 0, rotate: -12 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          exit={{ scale: 0.7, opacity: 0, transition: { duration: 0.14 } }}
          transition={{ type: 'spring', stiffness: 420, damping: 28 }}
          onPointerMove={move}
          onPointerLeave={() => { if (active === undefined) { setHover(null); onAim?.(null) } }}
          onClick={() => aim != null && onPick?.(wedges[aim], aim)}>
          <svg width={size} height={size} style={{ position: 'absolute', inset: 0, overflow: 'visible' }} aria-hidden>
            <circle cx={half} cy={half} r={half * 0.99} fill={t.disc} />
            <circle cx={half} cy={half} r={half * 0.99} fill="none" stroke={t.ring} strokeWidth={2} />
            {geo.map(({ w, i, mid, d }) => {
              const isHot = aim === i
              const dx = isHot ? pop * Math.sin(mid) : 0, dy = isHot ? -pop * Math.cos(mid) : 0
              return (
                <motion.g key={w.id} initial={isShot ? false : { opacity: 0 }} animate={{ opacity: 1, x: dx, y: dy }}
                  transition={{ type: 'spring', stiffness: 600, damping: 32, delay: isShot ? 0 : i * 0.012 }}>
                  <path d={d} fill={isHot ? h.fill : t.rest} />
                  {isHot && <path d={sector(half, r1 - size * 0.018, r1, mid - step / 2 + 0.02, mid + step / 2 - 0.02, gap)} fill="#FF4500" />}
                </motion.g>
              )
            })}
          </svg>
          {geo.map(({ w, i, mid }) => {
            const isHot = aim === i
            const rl = (r0 + r1) / 2 + (isHot ? pop : 0)
            return (
              <div key={w.id} role="menuitem" aria-label={w.label}
                style={{
                  position: 'absolute', left: half + rl * Math.sin(mid), top: half - rl * Math.cos(mid), transform: 'translate(-50%,-50%)',
                  textAlign: 'center', pointerEvents: 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, lineHeight: 1,
                  color: isHot ? h.text : t.restText, transition: 'color .12s, left .18s, top .18s',
                }}>
                {w.icon}
                <span className="sh-display" style={{ fontSize: Math.max(11, size * 0.042), fontWeight: 500, letterSpacing: '-0.02em' }}>{w.label}</span>
                {w.sub && <span className="sh-code" style={{ fontSize: Math.max(9, size * 0.026), color: isHot ? h.text : t.sub, opacity: isHot ? 0.75 : 1 }}>{w.sub}</span>}
              </div>
            )
          })}
          <div style={{
            position: 'absolute', left: '50%', top: '50%', width: r0 * 2 - gap * 3, height: r0 * 2 - gap * 3, transform: 'translate(-50%,-50%)',
            borderRadius: '50%', display: 'grid', placeItems: 'center', background: t.hub, color: t.hubText,
          }}>{hub}</div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
