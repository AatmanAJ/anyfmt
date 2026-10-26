import { motion, useReducedMotion } from 'motion/react'
import { useEffect, useId, useState } from 'react'
import { isShot } from '../../shared/kit'
import { cn } from '../../shared/cn'
import { C } from './tokens'

/** Dot positions for a ring of `n` LEDs (index 0 at 12 o'clock, clockwise). */
function ringDots(n: number, r: number, c: number) {
  return Array.from({ length: n }, (_, i) => {
    const a = (i / n) * Math.PI * 2
    return { x: c + r * Math.sin(a), y: c - r * Math.cos(a) }
  })
}

/** The Signal mark: a ring of 24 LEDs, one wedge lit. */
export function Mark({
  size = 40, ink = C.bone, lit = C.solar, dim = 0.4, start = 2, count = 3, glow = true, animate = false, className,
}: {
  size?: number; ink?: string; lit?: string; dim?: number; start?: number; count?: number; glow?: boolean; animate?: boolean; className?: string
}) {
  const id = useId().replace(/:/g, '')
  const reduce = useReducedMotion()
  const [s, setS] = useState(start)
  useEffect(() => {
    if (!animate || reduce || isShot) return
    const t = setInterval(() => setS((v) => (v + 1) % 24), 120)
    return () => clearInterval(t)
  }, [animate, reduce])
  const dots = ringDots(24, 40, 50)
  const isLit = (i: number) => ((i - s + 24) % 24) < count
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className={cn('shrink-0', className)} role="img" aria-label="Halo">
      {glow && (
        <defs>
          <filter id={`g${id}`} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3.2" /></filter>
        </defs>
      )}
      {dots.map((d, i) => !isLit(i) && <circle key={i} cx={d.x} cy={d.y} r={3.7} fill={ink} opacity={dim} />)}
      {glow && dots.map((d, i) => isLit(i) && <circle key={`h${i}`} cx={d.x} cy={d.y} r={7} fill={lit} opacity={0.7} filter={`url(#g${id})`} />)}
      {dots.map((d, i) => isLit(i) && <circle key={`l${i}`} cx={d.x} cy={d.y} r={4.6} fill={lit} />)}
    </svg>
  )
}

/** Wordmark: Instrument Serif, tight. */
export function Wordmark({ className, size = 32, color = C.bone }: { className?: string; size?: number; color?: string }) {
  return <span className={cn('font-serif leading-none tracking-[-0.035em]', className)} style={{ fontSize: size, color }}>Halo</span>
}

/** Horizontal lockup: mark + wordmark, gap = 0.28 × height. */
export function Lockup({ size = 32, ink = C.bone, lit = C.solar, className, glow = true }: { size?: number; ink?: string; lit?: string; className?: string; glow?: boolean }) {
  return (
    <span className={cn('inline-flex items-center', className)} style={{ gap: size * 0.28 }}>
      <Mark size={size} ink={ink} lit={lit} glow={glow} />
      <Wordmark size={size * 1.12} color={ink} className="-mt-[0.06em]" />
    </span>
  )
}

/** Superellipse (n=5) path, the macOS icon silhouette. */
export function squirclePath(s: number, n = 5) {
  const a = s / 2
  const pts: string[] = []
  for (let i = 0; i < 96; i++) {
    const t = (i / 96) * Math.PI * 2
    const c = Math.cos(t), sn = Math.sin(t)
    const x = a + a * Math.sign(c) * Math.abs(c) ** (2 / n)
    const y = a + a * Math.sign(sn) * Math.abs(sn) ** (2 / n)
    pts.push(`${i ? 'L' : 'M'}${x.toFixed(2)},${y.toFixed(2)}`)
  }
  return pts.join('') + 'Z'
}

/** App icon, drawn on a 1024 grid (824 body inside the 1024 canvas, like macOS). */
export function AppIcon({ size = 160, className }: { size?: number; className?: string }) {
  const id = useId().replace(/:/g, '')
  const body = 824, off = 100
  const dots = ringDots(24, 250, 512)
  const lit = new Set([2, 3, 4])
  // Faint dot-matrix behind the ring.
  const grid: { x: number; y: number; o: number }[] = []
  for (let y = 150; y <= 874; y += 36) for (let x = 150; x <= 874; x += 36) {
    const d = Math.hypot(x - 512, y - 512)
    if (d > 330) continue
    grid.push({ x, y, o: 0.09 * (1 - d / 330) + 0.02 })
  }
  return (
    <svg width={size} height={size} viewBox="0 0 1024 1024" className={className} role="img" aria-label="Halo app icon">
      <defs>
        <linearGradient id={`b${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#1E1E22" /><stop offset="0.55" stopColor="#0E0E10" /><stop offset="1" stopColor="#060607" />
        </linearGradient>
        <radialGradient id={`v${id}`} cx="0.66" cy="0.3" r="0.6">
          <stop offset="0" stopColor={C.solar} stopOpacity="0.16" /><stop offset="1" stopColor={C.solar} stopOpacity="0" />
        </radialGradient>
        <linearGradient id={`e${id}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.22" /><stop offset="0.12" stopColor="#fff" stopOpacity="0.04" /><stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <filter id={`g${id}`} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="26" /></filter>
        <filter id={`s${id}`} x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="18" stdDeviation="22" floodColor="#000" floodOpacity="0.55" /></filter>
        <clipPath id={`c${id}`}><path d={squirclePath(body)} transform={`translate(${off} ${off})`} /></clipPath>
      </defs>
      <g filter={`url(#s${id})`}>
        <path d={squirclePath(body)} transform={`translate(${off} ${off})`} fill={`url(#b${id})`} />
      </g>
      <g clipPath={`url(#c${id})`}>
        <rect x="0" y="0" width="1024" height="1024" fill={`url(#v${id})`} />
        {grid.map((g, i) => <circle key={i} cx={g.x} cy={g.y} r="4.5" fill={C.bone} opacity={g.o} />)}
        {dots.map((d, i) => !lit.has(i) && <circle key={i} cx={d.x} cy={d.y} r="23" fill={C.bone} opacity="0.3" />)}
        {dots.map((d, i) => lit.has(i) && <circle key={`h${i}`} cx={d.x} cy={d.y} r="46" fill={C.solar} opacity="0.85" filter={`url(#g${id})`} />)}
        {dots.map((d, i) => lit.has(i) && <circle key={`l${i}`} cx={d.x} cy={d.y} r="29" fill={C.solar} />)}
        <path d={squirclePath(body)} transform={`translate(${off} ${off})`} fill="none" stroke={`url(#e${id})`} strokeWidth="5" />
      </g>
    </svg>
  )
}

/** Menu-bar template glyph: monochrome, alpha only. Designed on a 16 px grid. */
export function MenuGlyph({ size = 16, color = 'currentColor' }: { size?: number; color?: string }) {
  const dots = ringDots(12, 5.9, 8)
  const lit = new Set([1, 2])
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" role="img" aria-label="Halo menu bar icon">
      {dots.map((d, i) => <circle key={i} cx={d.x} cy={d.y} r={lit.has(i) ? 1.55 : 1.05} fill={color} opacity={lit.has(i) ? 1 : 0.5} />)}
    </svg>
  )
}

/** Tiny LED: a lit (or dark) dot with optional blink. */
export function Led({ on = true, color = C.solar, blink = false, size = 6, className }: { on?: boolean; color?: string; blink?: boolean; size?: number; className?: string }) {
  const reduce = useReducedMotion()
  return (
    <motion.span
      className={cn('inline-block shrink-0 rounded-full', className)}
      style={{ width: size, height: size, background: on ? color : C.graphite2, boxShadow: on ? `0 0 ${size * 1.6}px ${color}aa` : 'none' }}
      animate={blink && !reduce && !isShot ? { opacity: [1, 0.25, 1] } : { opacity: 1 }}
      transition={blink ? { duration: 1.1, repeat: Infinity, ease: 'easeInOut' } : undefined}
    />
  )
}
