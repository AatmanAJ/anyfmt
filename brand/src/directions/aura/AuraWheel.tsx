// Aura's wheel: a frosted warm-white disc, wedges drawn in SVG (so they get a real 1px glass edge),
// an apricot light that pools under the hovered wedge, and a soft halo breathing round the rim.
// Adapted from shared/Wheel.tsx (same geometry and sticky aim) so the shared file stays untouched.
import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useId, useMemo, useRef, useState, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'

export type AuraSegment = { id: string; label: string; sub?: string; icon?: ReactNode }
export type WheelTone = 'apricot' | 'peri' | 'butter'

const TAU = Math.PI * 2
const TONES: Record<WheelTone, { a: string; b: string; c: string; glow: string; ring: string }> = {
  apricot: { a: '#FFF3E8', b: '#FFC9A0', c: '#FFA868', glow: 'rgba(255,160,100,.85)', ring: 'rgba(255,178,122,.55)' },
  peri: { a: '#F1F4FF', b: '#C3D1FF', c: '#97ACFA', glow: 'rgba(140,165,255,.85)', ring: 'rgba(157,180,255,.55)' },
  butter: { a: '#FFFBEA', b: '#FFEBB0', c: '#FFD77A', glow: 'rgba(255,214,120,.9)', ring: 'rgba(255,220,140,.6)' },
}

function sectorPath(c: number, r0: number, r1: number, a0: number, a1: number, gapPx: number, round = 10) {
  const g0 = gapPx / 2 / r0
  const g1 = gapPx / 2 / r1
  const pt = (r: number, a: number) => [c + r * Math.sin(a), c - r * Math.cos(a)] as const
  // Rounded corners: pull each corner in by `round` along the arc and radius, then curve through it.
  const rr = Math.min(round, (r1 - r0) / 3)
  const ar1 = rr / r1, ar0 = rr / r0
  const A = pt(r1, a0 + g1), B = pt(r1, a1 - g1), Cc = pt(r0, a1 - g0), D = pt(r0, a0 + g0)
  const A2 = pt(r1, a0 + g1 + ar1), B1 = pt(r1, a1 - g1 - ar1)
  const B2 = pt(r1 - rr, a1 - g1 * (r1 / (r1 - rr))), C1 = pt(r0 + rr, a1 - g0 * (r0 / (r0 + rr)))
  const C2 = pt(r0, a1 - g0 - ar0), D1 = pt(r0, a0 + g0 + ar0)
  const D2 = pt(r0 + rr, a0 + g0 * (r0 / (r0 + rr))), A1 = pt(r1 - rr, a0 + g1 * (r1 / (r1 - rr)))
  const large = a1 - a0 > Math.PI ? 1 : 0
  return [
    `M${A2[0]},${A2[1]}`,
    `A${r1},${r1} 0 ${large} 1 ${B1[0]},${B1[1]}`,
    `Q${B[0]},${B[1]} ${B2[0]},${B2[1]}`,
    `L${C1[0]},${C1[1]}`,
    `Q${Cc[0]},${Cc[1]} ${C2[0]},${C2[1]}`,
    `A${r0},${r0} 0 ${large} 0 ${D1[0]},${D1[1]}`,
    `Q${D[0]},${D[1]} ${D2[0]},${D2[1]}`,
    `L${A1[0]},${A1[1]}`,
    `Q${A[0]},${A[1]} ${A2[0]},${A2[1]}`,
    'Z',
  ].join(' ')
}

type Props = {
  segments: readonly AuraSegment[]
  size?: number
  hubLabel?: ReactNode
  hubSub?: ReactNode
  hoverIndex?: number | null
  interactive?: boolean
  open?: boolean
  onPick?: (s: AuraSegment, i: number) => void
  onHover?: (i: number | null) => void
  tone?: WheelTone
  className?: string
  /** Show the breathing halo round the rim. */
  halo?: boolean
  labelSize?: number
}

export function AuraWheel({
  segments, size = 360, hubLabel, hubSub, hoverIndex, interactive = true, open = true, onPick, onHover,
  tone = 'apricot', className, halo = true, labelSize,
}: Props) {
  const uid = useId().replace(/:/g, '')
  const n = segments.length
  const half = size / 2
  const r0 = half * 0.37
  const r1 = half * 0.95
  const step = TAU / n
  const offset = -step / 2
  const gap = Math.max(4, size * 0.016)
  const lift = size * 0.022
  const t = TONES[tone]
  const [pointerHover, setPointerHover] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const active = hoverIndex !== undefined ? hoverIndex : pointerHover
  const fs = labelSize ?? Math.max(10.5, Math.min(14, size * 0.037))

  const wedges = useMemo(() => segments.map((s, i) => {
    const a0 = offset + i * step, a1 = a0 + step, mid = (a0 + a1) / 2
    return { s, i, mid, path: sectorPath(half, r0, r1, a0, a1, gap, size * 0.03) }
  }), [segments, offset, step, half, r0, r1, gap, size])

  const hitTest = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half
    const d = Math.hypot(dx, dy)
    if (d < r0 * 0.85 || d > r1 + 24) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    if (pointerHover !== null && pointerHover !== idx) {
      const curMid = (pointerHover + 0.5) * step
      let delta = Math.abs(a - curMid)
      delta = Math.min(delta, TAU - delta)
      if (delta < step / 2 + Math.max(step * 0.3, (10 * Math.PI) / 180) * 0.6) return pointerHover
    }
    return idx
  }, [half, r0, r1, offset, step, pointerHover])

  const setHover = (i: number | null) => { setPointerHover(i); onHover?.(i) }
  const onMove = (e: React.PointerEvent) => {
    if (!interactive || hoverIndex !== undefined) return
    const rect = ref.current!.getBoundingClientRect()
    const i = hitTest(e.clientX - rect.left, e.clientY - rect.top)
    if (i !== pointerHover) setHover(i)
  }

  const hotMid = active != null ? wedges[active]?.mid ?? 0 : 0
  const rMid = (r0 + r1) / 2

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          ref={ref}
          className={cn('relative select-none', interactive && 'cursor-pointer', className)}
          style={{ width: size, height: size }}
          initial={isShot ? false : { scale: 0.6, opacity: 0, rotate: -10, filter: 'blur(8px)' }}
          animate={{ scale: 1, opacity: 1, rotate: 0, filter: 'blur(0px)' }}
          exit={{ scale: 0.7, opacity: 0, filter: 'blur(6px)', transition: { duration: 0.18 } }}
          transition={{ type: 'spring', stiffness: 340, damping: 26 }}
          onPointerMove={onMove}
          onPointerLeave={() => hoverIndex === undefined && setHover(null)}
          onClick={() => active != null && onPick?.(segments[active], active)}
          role="menu"
          aria-label="Wheel"
        >
          {/* Halo of light behind the disc */}
          {halo && (
            <div className="pointer-events-none absolute -inset-[22%]" aria-hidden>
              <div className="aura-breathe absolute inset-0 rounded-full"
                   style={{ background: `radial-gradient(closest-side, ${t.ring}, rgba(255,178,122,.18) 62%, transparent 80%)`, filter: 'blur(18px)' }} />
              <div className="aura-drift-b absolute inset-[18%] rounded-full"
                   style={{ background: 'radial-gradient(closest-side at 70% 70%, rgba(157,180,255,.45), transparent 75%)', filter: 'blur(22px)' }} />
            </div>
          )}
          {/* Frosted disc */}
          <div className="absolute inset-0 rounded-full"
               style={{
                 background: 'radial-gradient(circle at 35% 25%, rgba(255,255,255,.92), rgba(255,250,243,.7) 55%, rgba(250,240,228,.62))',
                 WebkitBackdropFilter: 'blur(24px) saturate(1.5)', backdropFilter: 'blur(24px) saturate(1.5)',
                 boxShadow: '0 0 0 .5px rgba(90,60,30,.16), 0 1px 0 rgba(255,255,255,1) inset, 0 -10px 30px rgba(230,200,170,.25) inset, 0 30px 70px -24px rgba(150,80,30,.38), 0 8px 18px -6px rgba(150,80,30,.12)',
               }} />
          {/* Light pooling under the hovered wedge */}
          <motion.div
            className="pointer-events-none absolute rounded-full"
            style={{ width: size * 0.5, height: size * 0.5, left: half - size * 0.25, top: half - size * 0.25,
                     background: `radial-gradient(closest-side, ${t.glow}, transparent)`, filter: `blur(${size * 0.05}px)` }}
            animate={{ x: rMid * 1.02 * Math.sin(hotMid), y: -rMid * 1.02 * Math.cos(hotMid), opacity: active != null ? 1 : 0, scale: active != null ? 1 : 0.6 }}
            transition={{ type: 'spring', stiffness: 300, damping: 30 }}
          />
          <svg className="absolute inset-0 overflow-visible" width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden>
            <defs>
              <radialGradient id={`hot-${uid}`} gradientUnits="userSpaceOnUse" cx={half} cy={half} r={r1}>
                <stop offset={r0 / r1} stopColor={t.a} />
                <stop offset="0.7" stopColor={t.b} />
                <stop offset="1" stopColor={t.c} />
              </radialGradient>
              <linearGradient id={`rest-${uid}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor="#fff" stopOpacity=".78" />
                <stop offset="1" stopColor="#FFF8F0" stopOpacity=".5" />
              </linearGradient>
              <filter id={`soft-${uid}`} x="-30%" y="-30%" width="160%" height="160%">
                <feGaussianBlur stdDeviation={size * 0.018} />
              </filter>
            </defs>
            {wedges.map(({ s, i, mid, path }) => {
              const hot = active === i
              return (
                <motion.g key={s.id}
                  initial={isShot ? false : { opacity: 0 }}
                  animate={{ opacity: 1, x: hot ? lift * Math.sin(mid) : 0, y: hot ? -lift * Math.cos(mid) : 0 }}
                  transition={{ type: 'spring', stiffness: 520, damping: 32, delay: isShot ? 0 : i * 0.014 }}>
                  {hot && <path d={path} fill={t.c} opacity=".75" filter={`url(#soft-${uid})`} />}
                  <path d={path} fill={hot ? `url(#hot-${uid})` : `url(#rest-${uid})`}
                        stroke={hot ? 'rgba(255,255,255,.95)' : 'rgba(255,255,255,.95)'} strokeWidth={1}
                        style={{ transition: 'fill .15s' }} />
                  <path d={path} fill="none" stroke="rgba(90,60,30,.10)" strokeWidth={0.75} transform={`translate(0 .6)`} style={{ mixBlendMode: 'multiply' }} />
                </motion.g>
              )
            })}
          </svg>
          {/* Labels (HTML for crisp text) */}
          {wedges.map(({ s, i, mid }) => {
            const hot = active === i
            const lx = half + rMid * Math.sin(mid) + (hot ? lift * Math.sin(mid) : 0)
            const ly = half - rMid * Math.cos(mid) - (hot ? lift * Math.cos(mid) : 0)
            return (
              <div key={s.id} role="menuitem" aria-label={s.label}
                className="pointer-events-none absolute flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-[3px] text-center leading-none"
                style={{ left: lx, top: ly, color: hot ? '#1E1B18' : '#5B524A', fontSize: fs, transition: 'left .2s, top .2s, color .15s', zIndex: 2 }}>
                {s.icon && <span className={cn('transition-opacity', hot ? 'opacity-100' : 'opacity-75')}>{s.icon}</span>}
                <span className={cn('whitespace-nowrap font-sans tracking-[-0.01em]', hot ? 'font-semibold' : 'font-medium')}>{s.label}</span>
                {s.sub && <span className="whitespace-nowrap font-sans text-[0.72em] font-medium opacity-60">{s.sub}</span>}
              </div>
            )
          })}
          {/* Hub */}
          <div className="absolute left-1/2 top-1/2 z-[3] flex -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center rounded-full text-center"
               style={{ width: r0 * 2 - gap * 2.4, height: r0 * 2 - gap * 2.4,
                        background: 'radial-gradient(circle at 40% 30%, #fff, #FBF5EC)',
                        boxShadow: '0 0 0 .5px rgba(90,60,30,.18), 0 8px 22px -8px rgba(150,80,30,.35), 0 -4px 10px rgba(230,205,175,.35) inset' }}>
            {hubLabel}
            {hubSub}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
