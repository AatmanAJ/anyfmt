import { motion } from 'motion/react'
import { useCallback, useId, useMemo, useRef, useState, type ReactNode } from 'react'
import { isShot } from '../../shared/kit'

export type Wedge = { id: string; label: string; sub?: string; icon?: ReactNode }

const TAU = Math.PI * 2

function sector(c: number, r0: number, r1: number, a0: number, a1: number, gap: number) {
  const g0 = gap / 2 / r0, g1 = gap / 2 / r1
  const p = (r: number, a: number) => `${(c + r * Math.sin(a)).toFixed(2)},${(c - r * Math.cos(a)).toFixed(2)}`
  return `M${p(r1, a0 + g1)} A${r1},${r1} 0 0 1 ${p(r1, a1 - g1)} L${p(r0, a1 - g0)} A${r0},${r0} 0 0 0 ${p(r0, a0 + g0)} Z`
}

/**
 * The wheel as SVG light: glassy wedges with molten edges; the aimed wedge lifts, fills with
 * molten light and burns a cyan rim. `open` (0..1) scales it out of the hub.
 */
export function NovaWheel({ wedges, size = 380, active, onAim, onPick, open = 1, hub, className }: {
  wedges: readonly Wedge[]; size?: number; active?: number | null; onAim?: (i: number | null) => void
  onPick?: (w: Wedge, i: number) => void; open?: number; hub?: ReactNode; className?: string
}) {
  const id = useId().replace(/:/g, '')
  const n = wedges.length
  const half = size / 2
  const r0 = half * 0.42, r1 = half * 0.93
  const step = TAU / n, offset = -step / 2
  const [hover, setHover] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const aim = active !== undefined ? active : hover

  const geo = useMemo(() => wedges.map((w, i) => {
    const a0 = offset + i * step, a1 = a0 + step
    return { w, i, mid: (a0 + a1) / 2, d: sector(half, r0, r1, a0, a1, size * 0.018) }
  }), [wedges, offset, step, half, r0, r1, size])

  const hit = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half, d = Math.hypot(dx, dy)
    if (d < r0 * 0.75 || d > r1 + 30) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    if (hover !== null && hover !== idx) {
      let delta = Math.abs(a - (hover + 0.5) * step); delta = Math.min(delta, TAU - delta)
      if (delta < step / 2 + step * 0.16) return hover
    }
    return idx
  }, [half, r0, r1, offset, step, hover])

  return (
    <div ref={ref} className={className} role="menu" aria-label="Format wheel"
      style={{ width: size, height: size, position: 'relative', touchAction: 'none' }}
      onPointerMove={(e) => {
        if (active !== undefined) return
        const r = ref.current!.getBoundingClientRect(), k = size / r.width
        const nx = hit((e.clientX - r.left) * k, (e.clientY - r.top) * k)
        if (nx !== hover) { setHover(nx); onAim?.(nx) }
      }}
      onPointerLeave={() => { if (active === undefined) { setHover(null); onAim?.(null) } }}
      onClick={() => aim != null && onPick?.(wedges[aim], aim)}>
      <motion.div style={{ position: 'absolute', inset: 0 }} initial={false}
        animate={{ scale: 0.35 + 0.65 * open, opacity: open, rotate: (1 - open) * -30 }} transition={isShot ? { duration: 0 } : { type: 'spring', stiffness: 220, damping: 20 }}>
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ position: 'absolute', inset: 0, overflow: 'visible' }} aria-hidden>
          <defs>
            <linearGradient id={`${id}m`} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#FFC24B" /><stop offset=".5" stopColor="#FF5A1F" /><stop offset="1" stopColor="#FF2E63" />
            </linearGradient>
            <radialGradient id={`${id}glass`} cx="50%" cy="50%" r="50%">
              <stop offset=".4" stopColor="rgba(255,120,60,.05)" /><stop offset="1" stopColor="rgba(255,90,31,.16)" />
            </radialGradient>
            <filter id={`${id}glow`} x="-40%" y="-40%" width="180%" height="180%">
              <feGaussianBlur stdDeviation={size * 0.02} result="b" />
              <feMerge><feMergeNode in="b" /><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
            </filter>
            <radialGradient id={`${id}core`}><stop offset="0" stopColor="rgba(255,200,140,.5)" /><stop offset="1" stopColor="rgba(255,90,31,0)" /></radialGradient>
          </defs>
          <circle cx={half} cy={half} r={r0 * 0.9} fill={`url(#${id}core)`} />
          {geo.map(({ w, i, mid, d }) => {
            const hot = aim === i
            const lift = hot ? size * 0.035 : 0
            return (
              <motion.g key={w.id} initial={false} animate={{ x: lift * Math.sin(mid), y: -lift * Math.cos(mid) }}
                transition={{ type: 'spring', stiffness: 520, damping: 28 }}>
                <path d={d} fill={hot ? `url(#${id}m)` : `url(#${id}glass)`} stroke={hot ? 'rgba(160,250,255,.95)' : 'rgba(255,140,90,.35)'}
                  strokeWidth={hot ? 1.8 : 1} filter={hot ? `url(#${id}glow)` : undefined} style={{ transition: 'fill .15s' }} />
              </motion.g>
            )
          })}
        </svg>
        {geo.map(({ w, i, mid }) => {
          const hot = aim === i
          const rr = (r0 + r1) / 2 + (hot ? size * 0.035 : 0)
          return (
            <div key={w.id} role="menuitem" aria-label={w.label} className="pointer-events-none absolute flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-1 text-center leading-none transition-[left,top,color] duration-200"
              style={{ left: half + rr * Math.sin(mid), top: half - rr * Math.cos(mid), color: hot ? '#170803' : 'rgba(255,236,226,.72)' }}>
              {w.icon}
              <span className="nv-display" style={{ fontSize: Math.max(11, size * 0.043), letterSpacing: '-0.02em' }}>{w.label}</span>
              {w.sub && <span className="nv-mono" style={{ fontSize: Math.max(8.5, size * 0.024), opacity: 0.7 }}>{w.sub}</span>}
            </div>
          )
        })}
        <div className="absolute left-1/2 top-1/2 grid -translate-x-1/2 -translate-y-1/2 place-items-center rounded-full text-center"
          style={{ width: r0 * 1.55, height: r0 * 1.55, background: 'radial-gradient(circle, #17171f, #0b0b10)', boxShadow: 'inset 0 0 0 1px rgba(255,255,255,.08), 0 0 40px -6px rgba(255,90,31,.5)' }}>
          {hub}
        </div>
      </motion.div>
    </div>
  )
}
