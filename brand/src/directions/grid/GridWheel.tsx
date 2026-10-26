import { motion, useReducedMotion } from 'motion/react'
import { useRef, useState, type ReactNode } from 'react'
import { product } from '../../shared/product'
import { isShot } from '../../shared/kit'
import { C } from './ui'

export type Seg = { id: string; label: string }
const TAU = Math.PI * 2

export const SETS = {
  convert: product.formatsVideo.map((f) => ({ id: f, label: f })),
  image: product.formatsImage.map((f) => ({ id: f, label: f })),
  tools: product.tools.map((t) => ({ id: t, label: t })),
  actions: product.actions.map((a) => ({ id: a, label: a })),
} satisfies Record<string, Seg[]>

/** Annular sector, clock angles (0 = 12 o'clock, clockwise), constant-width gaps. */
export function sector(cx: number, cy: number, r0: number, r1: number, a0: number, a1: number, gap: number) {
  const g0 = gap / 2 / r0, g1 = gap / 2 / r1
  const pt = (r: number, a: number) => `${(cx + r * Math.sin(a)).toFixed(2)},${(cy - r * Math.cos(a)).toFixed(2)}`
  const large = a1 - a0 > Math.PI ? 1 : 0
  return `M${pt(r1, a0 + g1)} A${r1},${r1} 0 ${large} 1 ${pt(r1, a1 - g1)} L${pt(r0, a1 - g0)} A${r0},${r0} 0 ${large} 0 ${pt(r0, a0 + g0)} Z`
}

export function geom(n: number) {
  const step = TAU / n
  const offset = -step / 2
  return { step, offset, mid: (i: number) => offset + (i + 0.5) * step }
}

/** Which wedge an offset from the centre lands on, with the app's sticky hysteresis. */
export function hit(dx: number, dy: number, n: number, r0: number, r1: number, current: number | null) {
  const d = Math.hypot(dx, dy)
  if (d < r0 * 0.8 || d > r1 * 1.12) return null
  const { step, offset } = geom(n)
  let a = Math.atan2(dx, -dy) - offset
  a = ((a % TAU) + TAU) % TAU
  const idx = Math.floor(a / step)
  if (current !== null && current !== idx) {
    const cm = (current + 0.5) * step
    let delta = Math.abs(a - cm)
    delta = Math.min(delta, TAU - delta)
    if (delta < step / 2 + Math.max(step * 0.12, (6 * Math.PI) / 180)) return current
  }
  return idx
}

export const RATIO = { inner: 0.34, disc: 1.045, gap: 0.026 }

/** The wheel drawn as an SVG group, so diagrams can annotate it in the same coordinates. */
export function WheelG({
  cx, cy, r, segments, active, open = true, hub, hubSub, showIndex = true, labelScale = 1, tone = 'dark',
}: {
  cx: number; cy: number; r: number; segments: readonly Seg[]; active: number | null; open?: boolean
  hub?: string; hubSub?: string; showIndex?: boolean; labelScale?: number; tone?: 'dark' | 'light'
}) {
  const reduce = useReducedMotion()
  const n = segments.length
  const { step, mid } = geom(n)
  const r0 = r * RATIO.inner
  const gap = Math.max(2, r * RATIO.gap * 2)
  const discFill = tone === 'dark' ? C.ink : C.white
  const wedgeFill = tone === 'dark' ? C.sheet : C.sheet
  const fs = Math.min(r * 0.085, (TAU * ((r0 + r) / 2) / n) * 0.16) * labelScale
  const still = isShot || !!reduce
  return (
    <motion.g
      initial={still ? false : { opacity: 0, scale: 0.94 }}
      animate={{ opacity: open ? 1 : 0, scale: open ? 1 : 0.94 }}
      transition={{ duration: open ? 0.14 : 0.1, ease: [0.7, 0, 0.2, 1] }}
      style={{ transformOrigin: `${cx}px ${cy}px`, transformBox: 'view-box' }}>
      <circle cx={cx} cy={cy} r={r * RATIO.disc} fill={discFill} stroke={tone === 'light' ? C.ink : 'none'} strokeWidth={tone === 'light' ? 1.5 : 0} />
      {segments.map((s, i) => {
        const a0 = -step / 2 + i * step
        const hot = active === i
        const m = mid(i)
        const lr = (r0 + r) / 2 + r * 0.02
        const lx = cx + lr * Math.sin(m), ly = cy - lr * Math.cos(m)
        const ir = r * 0.9
        const words = s.label.toUpperCase().split(' ')
        const longest = Math.max(...words.map((w) => w.length))
        const arc = (TAU * lr) / n
        const lfs = Math.min(fs, (arc * 0.74) / (longest * 0.62))
        return (
          <g key={s.id}>
            <motion.path d={sector(cx, cy, r0, r, a0, a0 + step, gap)}
              initial={still ? false : { opacity: 0 }}
              animate={{ opacity: open ? 1 : 0, fill: hot ? C.red : wedgeFill }}
              transition={{ opacity: { duration: 0.05, delay: open && !still ? 0.04 + i * 0.022 : 0 }, fill: { duration: 0 } }} />
            <text x={lx} y={ly} textAnchor="middle" dominantBaseline="central" fill={C.ink}
              style={{ fontFamily: '"Space Grotesk Variable", sans-serif', fontWeight: 700, fontSize: lfs, letterSpacing: '-0.02em' }}>
              {words.length === 1 ? words[0] : words.map((w, k) => (
                <tspan key={k} x={lx} dy={k === 0 ? `${-(words.length - 1) * 0.5}em` : '1em'}>{w}</tspan>
              ))}
            </text>
            {showIndex && (
              <text x={cx + ir * Math.sin(m)} y={cy - ir * Math.cos(m)} textAnchor="middle" dominantBaseline="central"
                fill={hot ? C.ink : C.ink2}
                style={{ fontFamily: '"JetBrains Mono Variable", monospace', fontWeight: 600, fontSize: Math.max(7, fs * 0.5) }}>
                {String(i + 1).padStart(2, '0')}
              </text>
            )}
          </g>
        )
      })}
      {/* Hub: one hairline ring inside, like a bearing. */}
      <circle cx={cx} cy={cy} r={r0 - gap * 1.6} fill={tone === 'dark' ? C.ink : C.ink} />
      <circle cx={cx} cy={cy} r={(r0 - gap * 1.6) * 0.84} fill="none" stroke="#2C2C2A" strokeWidth="1" />
      {hub && (
        <text x={cx} y={cy - (hubSub ? r0 * 0.1 : 0)} textAnchor="middle" dominantBaseline="central" fill={C.sheet}
          style={{ fontFamily: '"JetBrains Mono Variable", monospace', fontWeight: 600, fontSize: Math.max(8, r0 * 0.17) }}>{hub}</text>
      )}
      {hubSub && (
        <text x={cx} y={cy + r0 * 0.22} textAnchor="middle" dominantBaseline="central" fill="#8E8E87"
          style={{ fontFamily: '"JetBrains Mono Variable", monospace', fontWeight: 500, fontSize: Math.max(7, r0 * 0.12), letterSpacing: '0.08em' }}>{hubSub}</text>
      )}
    </motion.g>
  )
}

/** Standalone wheel. Pointer-driven unless `active` is passed. */
export function GridWheel({
  segments, size = 320, active, interactive = true, onPick, onHover, hub, hubSub, open = true, className, showIndex, labelScale, title, rest,
}: {
  segments: readonly Seg[]; size?: number; active?: number | null; interactive?: boolean; onPick?: (i: number) => void
  onHover?: (i: number | null) => void; hub?: string; hubSub?: string; open?: boolean; className?: string; showIndex?: boolean
  labelScale?: number; title?: string; rest?: number
}) {
  const ref = useRef<SVGSVGElement>(null)
  const [hover, setHover] = useState<number | null>(null)
  const pad = size * 0.02
  const r = (size / 2 - pad) / RATIO.disc
  const act = active !== undefined ? active : hover ?? rest ?? null
  const move = (e: React.PointerEvent) => {
    if (!interactive || active !== undefined) return
    const b = ref.current!.getBoundingClientRect()
    const k = size / b.width
    const h = hit((e.clientX - b.left) * k - size / 2, (e.clientY - b.top) * k - size / 2, segments.length, r * RATIO.inner, r, hover)
    if (h !== hover) { setHover(h); onHover?.(h) }
  }
  return (
    <svg ref={ref} viewBox={`0 0 ${size} ${size}`} width={size} height={size} className={className} role="menu" aria-label={title ?? 'Wheel'}
      onPointerMove={move} onPointerLeave={() => { if (active === undefined) { setHover(null); onHover?.(null) } }}
      onClick={() => act != null && onPick?.(act)} style={{ cursor: interactive ? 'pointer' : undefined, maxWidth: '100%', height: 'auto', touchAction: 'manipulation' }}>
      <WheelG cx={size / 2} cy={size / 2} r={r} segments={segments} active={act} open={open} hub={hub} hubSub={hubSub}
        showIndex={showIndex} labelScale={labelScale} />
    </svg>
  )
}

export function WheelCaption({ children }: { children: ReactNode }) {
  return <div className="font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">{children}</div>
}
