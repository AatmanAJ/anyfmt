import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useId, useMemo, useRef, useState, type ReactNode } from 'react'
import { isShot } from '../shared/kit'

export type Wedge = { id: string; label: string; sub?: string; icon?: ReactNode }

const TAU = Math.PI * 2

/** Annular sector shrunk by `inset` px on every side, so a round stroke of 2×inset restores it with soft corners. */
function softSector(c: number, r0: number, r1: number, a0: number, a1: number, gap: number, inset: number) {
  const ri = r0 + inset, ro = r1 - inset
  const e0 = (gap / 2 + inset) / ri, e1 = (gap / 2 + inset) / ro
  const p = (r: number, a: number) => `${(c + r * Math.sin(a)).toFixed(2)},${(c - r * Math.cos(a)).toFixed(2)}`
  const large = a1 - a0 - 2 * e1 > Math.PI ? 1 : 0
  return `M${p(ro, a0 + e1)} A${ro},${ro} 0 ${large} 1 ${p(ro, a1 - e1)} L${p(ri, a1 - e0)} A${ri},${ri} 0 ${large} 0 ${p(ri, a0 + e0)} Z`
}

type Props = {
  wedges: readonly Wedge[]
  size?: number
  /** Controlled aim (autoplay). Leave undefined to let the pointer aim. */
  active?: number | null
  onAim?: (i: number | null) => void
  onPick?: (w: Wedge, i: number) => void
  open?: boolean
  hub?: ReactNode
  /** 'light' on paper, 'stage' on orange. */
  tone?: 'light' | 'stage'
  className?: string
}

export function AnyWheel({ wedges, size = 380, active, onAim, onPick, open = true, hub, tone = 'light', className }: Props) {
  const id = useId().replace(/:/g, '')
  const n = wedges.length
  const half = size / 2
  const r0 = half * 0.37, r1 = half * 0.96
  const step = TAU / n, offset = -step / 2
  const gap = Math.max(4, size * 0.016), inset = size * 0.022
  const [hover, setHover] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const aim = active !== undefined ? active : hover

  const geo = useMemo(() => wedges.map((w, i) => {
    const a0 = offset + i * step, a1 = a0 + step, mid = (a0 + a1) / 2
    return { w, i, mid, d: softSector(half, r0, r1, a0, a1, gap, inset) }
  }), [wedges, offset, step, half, r0, r1, gap, inset])

  const hit = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half, d = Math.hypot(dx, dy)
    if (d < r0 * 0.8 || d > r1 + 28) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    if (hover !== null && hover !== idx) {
      // Stay on the current wedge until the pointer is clearly past its edge.
      let delta = Math.abs(a - (hover + 0.5) * step)
      delta = Math.min(delta, TAU - delta)
      if (delta < step / 2 + step * 0.18) return hover
    }
    return idx
  }, [half, r0, r1, offset, step, hover])

  const move = (e: React.PointerEvent) => {
    if (active !== undefined) return
    const r = ref.current!.getBoundingClientRect()
    const next = hit(e.clientX - r.left, e.clientY - r.top)
    if (next !== hover) { setHover(next); onAim?.(next) }
  }

  const discBg = tone === 'stage'
    ? 'radial-gradient(circle at 50% 35%, rgba(255,255,255,.55), rgba(255,255,255,.22) 70%)'
    : 'radial-gradient(circle at 50% 30%, rgba(255,255,255,.95), rgba(245,243,240,.85) 75%)'

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          ref={ref}
          className={className}
          style={{ width: size, height: size, position: 'relative', touchAction: 'none' }}
          initial={isShot ? false : { scale: 0.6, opacity: 0, rotate: -10 }}
          animate={{ scale: 1, opacity: 1, rotate: 0 }}
          exit={{ scale: 0.7, opacity: 0, transition: { duration: 0.15 } }}
          transition={{ type: 'spring', stiffness: 380, damping: 28 }}
          onPointerMove={move}
          onPointerLeave={() => { if (active === undefined) { setHover(null); onAim?.(null) } }}
          onClick={() => aim != null && onPick?.(wedges[aim], aim)}
          role="menu" aria-label="Format wheel"
        >
          {/* glass disc */}
          <div style={{
            position: 'absolute', inset: 0, borderRadius: '50%', background: discBg,
            backdropFilter: 'blur(20px) saturate(1.3)', WebkitBackdropFilter: 'blur(20px) saturate(1.3)',
            boxShadow: tone === 'stage'
              ? 'inset 0 1px 0 rgba(255,255,255,.8), inset 0 0 0 1px rgba(255,255,255,.45), 0 30px 60px -20px rgba(110,30,0,.55)'
              : 'inset 0 1px 0 #fff, 0 0 0 1px rgba(17,17,17,.06), 0 30px 60px -24px rgba(90,40,10,.35)',
          }} />
          <svg width={size} height={size} style={{ position: 'absolute', inset: 0, overflow: 'visible' }} aria-hidden>
            <defs>
              <linearGradient id={`${id}rest`} x1="0" y1="0" x2="0" y2={size} gradientUnits="userSpaceOnUse">
                <stop offset="0" stopColor="#FFFFFF" />
                <stop offset="1" stopColor="#F4F2EF" />
              </linearGradient>
              <linearGradient id={`${id}hot`} x1="0" y1="0" x2="0" y2={size} gradientUnits="userSpaceOnUse">
                <stop offset="0" stopColor="#FFA45C" />
                <stop offset=".5" stopColor="#EE7F2C" />
                <stop offset="1" stopColor="#D2581B" />
              </linearGradient>
              <filter id={`${id}glow`} x="-30%" y="-30%" width="160%" height="160%">
                <feDropShadow dx="0" dy="8" stdDeviation="10" floodColor="#E5701E" floodOpacity=".55" />
              </filter>
              <filter id={`${id}soft`} x="-10%" y="-10%" width="120%" height="120%">
                <feDropShadow dx="0" dy="1.5" stdDeviation="1.5" floodColor="#5A2A0A" floodOpacity=".14" />
              </filter>
            </defs>
            {geo.map(({ w, i, mid, d }) => {
              const hot = aim === i
              const lift = hot ? size * 0.018 : 0
              return (
                <motion.g key={w.id}
                  initial={isShot ? false : { opacity: 0, scale: 0.7 }}
                  animate={{ opacity: 1, scale: 1, x: lift * Math.sin(mid), y: -lift * Math.cos(mid) }}
                  transition={{ type: 'spring', stiffness: 520, damping: 32, delay: isShot ? 0 : i * 0.015 }}
                  style={{ transformOrigin: `${half}px ${half}px` }}
                  filter={hot ? `url(#${id}glow)` : `url(#${id}soft)`}>
                  <path d={d} fill={`url(#${id}${hot ? 'hot' : 'rest'})`} stroke={`url(#${id}${hot ? 'hot' : 'rest'})`}
                        strokeWidth={inset * 2} strokeLinejoin="round" />
                  {hot && <path d={d} fill="none" stroke="rgba(255,255,255,.55)" strokeWidth={1} strokeLinejoin="round" transform="translate(0 -1)" style={{ mixBlendMode: 'screen' }} />}
                </motion.g>
              )
            })}
          </svg>
          {/* labels */}
          {geo.map(({ w, i, mid }) => {
            const hot = aim === i
            const rl = (r0 + r1) / 2 + (hot ? size * 0.018 : 0)
            return (
              <div key={w.id} role="menuitem" aria-label={w.label}
                style={{
                  position: 'absolute', left: half + rl * Math.sin(mid), top: half - rl * Math.cos(mid),
                  transform: 'translate(-50%,-50%)', textAlign: 'center', pointerEvents: 'none',
                  color: hot ? '#fff' : '#111', transition: 'color .15s, left .2s, top .2s',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, lineHeight: 1,
                }}>
                {w.icon && <span style={{ opacity: hot ? 1 : 0.75 }}>{w.icon}</span>}
                <span style={{ fontSize: Math.max(11, size * 0.037), fontWeight: 650, letterSpacing: '-0.01em' }}>{w.label}</span>
                {w.sub && <span className="af-mono" style={{ fontSize: Math.max(9, size * 0.025), opacity: hot ? 0.9 : 0.5 }}>{w.sub}</span>}
              </div>
            )
          })}
          {/* hub */}
          <div style={{
            position: 'absolute', left: '50%', top: '50%', width: r0 * 2 - inset * 2, height: r0 * 2 - inset * 2,
            transform: 'translate(-50%,-50%)', borderRadius: '50%', display: 'grid', placeItems: 'center',
            background: 'linear-gradient(180deg, #FFFFFF, #F3F1EE)',
            boxShadow: 'inset 0 1px 0 #fff, 0 0 0 1px rgba(17,17,17,.06), 0 8px 20px -8px rgba(90,40,10,.35)',
          }}>{hub}</div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
