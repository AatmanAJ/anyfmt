import { animate, motion, useInView, useMotionValue, useReducedMotion, useSpring, useTransform } from 'motion/react'
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { cn } from './cn'

/** `?shot` in the URL: render everything in its final state (offscreen screenshots don't fire in-view observers). */
export const isShot = typeof location !== 'undefined' && new URLSearchParams(location.search).has('shot')

/** macOS window chrome. `shape="stadium"` gives the pill-shaped onboarding window. */
export function MacWindow({
  children, className, style, title, shape = 'rect', lights = 'colour', titleClassName,
}: {
  children: ReactNode; className?: string; style?: CSSProperties; title?: ReactNode
  shape?: 'rect' | 'stadium'; lights?: 'colour' | 'mono' | 'none'; titleClassName?: string
}) {
  return (
    <div className={cn('relative overflow-hidden', shape === 'stadium' ? 'rounded-[999px]' : 'rounded-[14px]', className)} style={style}>
      {lights !== 'none' && (
        <div className={cn('absolute z-20 flex gap-2', shape === 'stadium' ? 'left-[9%] top-[11%]' : 'left-4 top-4')}>
          {(lights === 'colour' ? ['#FF5F57', '#FEBC2E', '#28C840'] : ['currentColor', 'currentColor', 'currentColor']).map((c, i) => (
            <span key={i} className={cn('block size-3 rounded-full', lights === 'mono' && 'opacity-25')} style={{ background: c }} />
          ))}
        </div>
      )}
      {title && <div className={cn('absolute inset-x-0 top-3 z-10 text-center text-xs font-medium', titleClassName)}>{title}</div>}
      {children}
    </div>
  )
}

/** A file icon: page with a folded corner and a format badge. */
export function FileGlyph({
  ext = 'MOV', size = 64, paper = '#fff', ink = '#111', badge = '#111', badgeText = '#fff', className, thumb,
}: { ext?: string; size?: number; paper?: string; ink?: string; badge?: string; badgeText?: string; className?: string; thumb?: ReactNode }) {
  const w = size, h = size * 1.25
  return (
    <div className={cn('relative', className)} style={{ width: w, height: h }}>
      <svg width={w} height={h} viewBox="0 0 64 80" className="absolute inset-0 drop-shadow-[0_8px_18px_rgba(0,0,0,.25)]" aria-hidden>
        <path d="M6 2h38l16 16v56a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V6a4 4 0 0 1 4-4z" fill={paper} />
        <path d="M44 2v12a4 4 0 0 0 4 4h12" fill="none" stroke={ink} strokeOpacity=".18" strokeWidth="1.5" />
        {!thumb && [30, 38, 46, 54].map((y) => <rect key={y} x="12" y={y} width={y === 54 ? 24 : 40} height="3" rx="1.5" fill={ink} opacity=".12" />)}
      </svg>
      {thumb && <div className="absolute inset-x-[10%] top-[26%] bottom-[22%] overflow-hidden rounded-[3px]">{thumb}</div>}
      <span className="absolute bottom-[10%] left-1/2 -translate-x-1/2 rounded-[4px] px-1.5 py-0.5 text-[9px] font-bold tracking-wide"
            style={{ background: badge, color: badgeText }}>{ext}</span>
    </div>
  )
}

/** A physical keycap. */
export function Keycap({
  symbol, label, pressed, className, style,
}: { symbol: string; label?: string; pressed?: boolean; className?: string; style?: CSSProperties }) {
  return (
    <motion.div
      animate={{ y: pressed ? 3 : 0, boxShadow: pressed ? '0 1px 0 rgba(0,0,0,.35)' : '0 4px 0 rgba(0,0,0,.35)' }}
      transition={{ type: 'spring', stiffness: 700, damping: 30 }}
      className={cn('inline-flex min-w-[64px] flex-col items-start justify-between rounded-[10px] px-2.5 py-1.5 text-left', className)}
      style={style}
    >
      <span className="text-lg leading-none">{symbol}</span>
      {label && <span className="text-[10px] font-medium opacity-70">{label}</span>}
    </motion.div>
  )
}

/** Fade + rise into view once. */
export function Reveal({ children, delay = 0, y = 18, className }: { children: ReactNode; delay?: number; y?: number; className?: string }) {
  const reduce = useReducedMotion()
  if (isShot) return <div className={className}>{children}</div>
  return (
    <motion.div className={className}
      initial={{ opacity: 0, y: reduce ? 0 : y, filter: reduce ? 'none' : 'blur(6px)' }}
      whileInView={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
      viewport={{ once: true, margin: '-60px' }}
      transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1], delay }}>
      {children}
    </motion.div>
  )
}

/** Counts up when scrolled into view. Keeps any prefix/suffix ("43 ms", "793"). */
export function NumberTicker({ value, className, duration = 1.4 }: { value: string; className?: string; duration?: number }) {
  const ref = useRef<HTMLSpanElement>(null)
  const inView = useInView(ref, { once: true }) || isShot
  const m = value.match(/^([^\d]*)([\d.,]+)(.*)$/)
  const target = m ? parseFloat(m[2].replace(/,/g, '')) : 0
  const [shown, setShown] = useState(m && !isShot ? m[1] + '0' + m[3] : value)
  useEffect(() => {
    if (!inView || !m || isShot) return
    const c = animate(0, target, {
      duration: isShot ? 0 : duration, ease: [0.16, 1, 0.3, 1],
      onUpdate: (v) => setShown(m[1] + (Number.isInteger(target) ? Math.round(v).toLocaleString() : v.toFixed(1)) + m[3]),
    })
    return () => c.stop()
  }, [inView]) // eslint-disable-line react-hooks/exhaustive-deps
  return <span ref={ref} className={cn('tabular-nums', className)}>{m ? shown : value}</span>
}

/** Infinite horizontal marquee (pauses on hover). */
export function Marquee({ children, className, duration = 40, reverse }: { children: ReactNode; className?: string; duration?: number; reverse?: boolean }) {
  return (
    <div className={cn('group relative flex overflow-hidden [mask-image:linear-gradient(90deg,transparent,#000_10%,#000_90%,transparent)]', className)}>
      <div className="flex shrink-0 animate-marquee gap-[inherit] group-hover:[animation-play-state:paused]"
           style={{ ['--marquee-duration' as string]: `${duration}s`, animationDirection: reverse ? 'reverse' : 'normal' }}>
        {children}{children}
      </div>
    </div>
  )
}

/** Card with a pointer-following spotlight. */
export function SpotlightCard({ children, className, color = 'rgba(255,255,255,.12)', style }: { children: ReactNode; className?: string; color?: string; style?: CSSProperties }) {
  const x = useMotionValue(-999), y = useMotionValue(-999)
  const bg = useTransform([x, y], ([px, py]) => `radial-gradient(420px circle at ${px}px ${py}px, ${color}, transparent 45%)`)
  return (
    <div className={cn('group relative overflow-hidden', className)} style={style}
         onPointerMove={(e) => { const r = e.currentTarget.getBoundingClientRect(); x.set(e.clientX - r.left); y.set(e.clientY - r.top) }}
         onPointerLeave={() => { x.set(-999); y.set(-999) }}>
      <motion.div className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-300 group-hover:opacity-100" style={{ background: bg }} />
      {children}
    </div>
  )
}

/** Button that leans toward the pointer. */
export function Magnetic({ children, strength = 0.25, className }: { children: ReactNode; strength?: number; className?: string }) {
  const x = useSpring(0, { stiffness: 300, damping: 20 }), y = useSpring(0, { stiffness: 300, damping: 20 })
  return (
    <motion.div className={cn('inline-block', className)} style={{ x, y }}
      onPointerMove={(e) => { const r = e.currentTarget.getBoundingClientRect(); x.set((e.clientX - r.left - r.width / 2) * strength); y.set((e.clientY - r.top - r.height / 2) * strength) }}
      onPointerLeave={() => { x.set(0); y.set(0) }}>
      {children}
    </motion.div>
  )
}

/** Splits text into words that rise in one by one. */
export function WordsReveal({ text, className, wordClassName, delay = 0 }: { text: string; className?: string; wordClassName?: string; delay?: number }) {
  const reduce = useReducedMotion()
  return (
    <span className={className}>
      {text.split(' ').map((w, i) => (
        <span key={i} className="inline-block overflow-hidden pb-[0.08em] align-bottom">
          <motion.span className={cn('inline-block', wordClassName)}
            initial={{ y: reduce || isShot ? 0 : '105%' }} whileInView={{ y: 0 }} viewport={{ once: true }}
            transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1], delay: delay + i * 0.05 }}>
            {w}&nbsp;
          </motion.span>
        </span>
      ))}
    </span>
  )
}

/** Section anchor used by every direction page for the in-page nav. */
export const SECTIONS = [
  { id: 'identity', label: 'Identity' },
  { id: 'landing', label: 'Landing' },
  { id: 'onboarding', label: 'Onboarding' },
  { id: 'app', label: 'App' },
] as const
