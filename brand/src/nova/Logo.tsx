import { motion } from 'motion/react'
import { useId } from 'react'

/*
 * The mark: an eight-wedge ring with one wedge broken out of orbit, molten.
 * It is the wheel at the instant you aim: everything else holds, one choice flares.
 */
const N = 8
const TAU = Math.PI * 2

function wedge(r0: number, r1: number, a0: number, a1: number, gap: number, c = 50) {
  const p = (r: number, a: number) => `${(c + r * Math.sin(a)).toFixed(2)},${(c - r * Math.cos(a)).toFixed(2)}`
  const g0 = gap / 2 / r0, g1 = gap / 2 / r1
  return `M${p(r1, a0 + g1)} A${r1},${r1} 0 0 1 ${p(r1, a1 - g1)} L${p(r0, a1 - g0)} A${r0},${r0} 0 0 0 ${p(r0, a0 + g0)} Z`
}

export function Mark({ size = 32, hot = 1, animate = false, className }: { size?: number; hot?: number; animate?: boolean; className?: string }) {
  const id = useId().replace(/:/g, '')
  const step = TAU / N
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className={className} role="img" aria-label="anyfmt" style={{ overflow: 'visible' }}>
      <defs>
        <linearGradient id={`${id}m`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#FFC24B" /><stop offset=".5" stopColor="#FF5A1F" /><stop offset="1" stopColor="#FF2E63" />
        </linearGradient>
        <filter id={`${id}g`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="3.2" result="b" /><feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      {Array.from({ length: N }, (_, i) => {
        const a0 = i * step - step / 2, a1 = a0 + step, mid = (a0 + a1) / 2
        const isHot = i === hot
        const lift = isHot ? 9 : 0
        return (
          <motion.path key={i} d={wedge(26, 44, a0, a1, 5.5)} fill={isHot ? `url(#${id}m)` : 'currentColor'}
            fillOpacity={isHot ? 1 : 0.92} filter={isHot ? `url(#${id}g)` : undefined}
            initial={animate ? { opacity: 0, x: 0, y: 0, scale: 0.6 } : false}
            animate={{ opacity: 1, x: lift * Math.sin(mid), y: -lift * Math.cos(mid), scale: 1 }}
            transition={{ type: 'spring', stiffness: 300, damping: 18, delay: animate ? 0.1 + i * 0.05 + (isHot ? 0.35 : 0) : 0 }}
            style={{ transformOrigin: '50px 50px' }} />
        )
      })}
    </svg>
  )
}

export function Wordmark({ size = 22, className }: { size?: number; className?: string }) {
  return (
    <span className={className} style={{ display: 'inline-flex', alignItems: 'center', gap: size * 0.38 }}>
      <Mark size={size * 1.25} />
      <span className="nv-display" style={{ fontSize: size, lineHeight: 1, letterSpacing: '-0.04em' }}>anyfmt</span>
    </span>
  )
}
