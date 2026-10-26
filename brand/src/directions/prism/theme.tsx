import { motion } from 'motion/react'
import { useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import interDisplayUrl from '@fontsource-variable/inter/files/inter-latin-opsz-normal.woff2?url'
import { cn } from '../../shared/cn'
import { NumberTicker, isShot } from '../../shared/kit'

/** Prism colour tokens. Pearl canvas, Plum ink, three refractions. */
export const P = {
  pearl: '#F6F4FB',
  pearl2: '#EFEBF8',
  mist: '#E3DDF1',
  plum: '#1C1530',
  plum80: '#3A3152',
  plum60: '#5E5677',
  plum40: '#8E87A6',
  coral: '#FF6B8B',
  lilac: '#B9A7FF',
  aqua: '#5EE7DF',
  iris: '#6B4EFF',
  night: '#0E0A1A',
  night2: '#171126',
  success: '#2FBF9B',
  danger: '#E5486A',
} as const

export const IRIS = `linear-gradient(115deg, ${P.coral} 0%, ${P.lilac} 48%, ${P.aqua} 100%)`
export const IRIS_CONIC = `conic-gradient(from 0deg, ${P.coral}, #FFB3C4, ${P.lilac}, #9FD7FF, ${P.aqua}, ${P.lilac}, ${P.coral})`

/** Glass recipes as inline styles (backdrop-filter needs the -webkit- prefix in Safari). */
export const glass = {
  light: {
    background: 'linear-gradient(180deg, rgba(255,255,255,.78), rgba(255,255,255,.52))',
    backdropFilter: 'blur(28px) saturate(180%)',
    WebkitBackdropFilter: 'blur(28px) saturate(180%)',
    boxShadow: 'inset 0 1px 0 rgba(255,255,255,.95), inset 0 0 0 1px rgba(255,255,255,.55), 0 1px 2px rgba(28,21,48,.06), 0 24px 60px -24px rgba(44,30,90,.32)',
  } as CSSProperties,
  thin: {
    background: 'rgba(255,255,255,.55)',
    backdropFilter: 'blur(18px) saturate(170%)',
    WebkitBackdropFilter: 'blur(18px) saturate(170%)',
    boxShadow: 'inset 0 1px 0 rgba(255,255,255,.9), inset 0 0 0 1px rgba(255,255,255,.45), 0 10px 30px -14px rgba(44,30,90,.28)',
  } as CSSProperties,
  dark: {
    background: 'linear-gradient(180deg, rgba(44,34,74,.72), rgba(24,18,42,.66))',
    backdropFilter: 'blur(28px) saturate(170%)',
    WebkitBackdropFilter: 'blur(28px) saturate(170%)',
    boxShadow: 'inset 0 1px 0 rgba(255,255,255,.16), inset 0 0 0 1px rgba(255,255,255,.08), 0 30px 70px -26px rgba(0,0,0,.7)',
  } as CSSProperties,
}

/** Global CSS this direction needs: the Inter Display cut, keyframes and a few utilities. Scoped by class names. */
export function PrismStyle() {
  return (
    <style>{`
@font-face { font-family: 'Prism Display'; font-style: normal; font-weight: 100 900; font-display: swap;
  src: url(${interDisplayUrl}) format('woff2-variations'); }
.prism { font-family: 'Inter Variable', ui-sans-serif, system-ui, sans-serif; color: ${P.plum}; font-feature-settings: 'cv11','ss01','ss03'; }
.prism ::selection { background: ${P.lilac}; color: ${P.plum}; }
.p-display { font-family: 'Prism Display', 'Inter Variable', sans-serif; font-variation-settings: 'opsz' 32; letter-spacing: -0.045em; font-feature-settings: 'cv11','ss01','ss03','cv05'; }
.p-iris-text { background: ${IRIS}; -webkit-background-clip: text; background-clip: text; color: transparent; }
.p-iris-text-anim { background: linear-gradient(100deg, ${P.coral}, ${P.lilac}, ${P.aqua}, ${P.lilac}, ${P.coral}); background-size: 300% 100%;
  -webkit-background-clip: text; background-clip: text; color: transparent; animation: p-slide 9s linear infinite; }
.p-spin { animation: p-spin 14s linear infinite; }
.p-spin-slow { animation: p-spin 40s linear infinite; }
.p-spin-rev { animation: p-spin 22s linear infinite reverse; }
.p-drift { animation: p-drift 18s ease-in-out infinite alternate; }
.p-drift-2 { animation: p-drift2 22s ease-in-out infinite alternate; }
.p-float { animation: p-float 6s ease-in-out infinite; }
.p-shimmer { position: relative; overflow: hidden; }
.p-shimmer::after { content: ''; position: absolute; inset: 0; background: linear-gradient(105deg, transparent 35%, rgba(255,255,255,.55) 50%, transparent 65%);
  transform: translateX(-120%); animation: p-sheen 4.5s ease-in-out infinite; pointer-events: none; }
.p-grain { background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 0.11 0 0 0 0 0.08 0 0 0 0 0.19 0 0 0 .5 0'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>"); }
.p-focus:focus-visible { outline: 2px solid ${P.iris}; outline-offset: 3px; }
@keyframes p-spin { to { transform: rotate(360deg); } }
@keyframes p-slide { to { background-position: 300% 0; } }
@keyframes p-drift { 0% { transform: translate3d(-4%, -2%, 0) scale(1); } 100% { transform: translate3d(5%, 4%, 0) scale(1.12); } }
@keyframes p-drift2 { 0% { transform: translate3d(4%, 3%, 0) scale(1.08); } 100% { transform: translate3d(-5%, -3%, 0) scale(.95); } }
@keyframes p-float { 0%,100% { transform: translateY(0); } 50% { transform: translateY(-8px); } }
@keyframes p-sheen { 0%, 55% { transform: translateX(-120%); } 85%, 100% { transform: translateX(120%); } }
@keyframes p-dash { to { stroke-dashoffset: 0; } }
@media (prefers-reduced-motion: reduce) { .p-spin, .p-spin-slow, .p-spin-rev, .p-drift, .p-drift-2, .p-float, .p-iris-text-anim, .p-shimmer::after { animation: none !important; } }
`}</style>
  )
}

/** Soft iridescent mesh: three drifting blurred light pools. Pure CSS. */
export function Mesh({ className, intensity = 1, dark }: { className?: string; intensity?: number; dark?: boolean }) {
  const o = (a: number) => Math.min(1, a * intensity)
  return (
    <div aria-hidden className={cn('pointer-events-none absolute inset-0 overflow-hidden', className)}>
      <div className="p-drift absolute -left-[15%] -top-[25%] h-[85%] w-[70%] rounded-full blur-[90px]"
           style={{ background: P.coral, opacity: o(dark ? 0.32 : 0.34) }} />
      <div className="p-drift-2 absolute right-[-15%] top-[-10%] h-[80%] w-[65%] rounded-full blur-[100px]"
           style={{ background: P.aqua, opacity: o(dark ? 0.24 : 0.36) }} />
      <div className="p-drift absolute bottom-[-35%] left-[20%] h-[90%] w-[70%] rounded-full blur-[110px]"
           style={{ background: P.lilac, opacity: o(dark ? 0.4 : 0.5) }} />
    </div>
  )
}

/** The signature: a slowly rotating iridescent ring of light (thin, with a bloom). */
export function FormatRing({ size, thickness = 2, bloom = true, className, speed = 'p-spin', style }: {
  size: number | string; thickness?: number; bloom?: boolean; className?: string; speed?: string; style?: CSSProperties
}) {
  const mask = `radial-gradient(farthest-side, transparent calc(100% - ${thickness}px), #000 calc(100% - ${thickness}px + .5px))`
  return (
    <div aria-hidden className={cn('pointer-events-none absolute rounded-full', className)} style={{ width: size, height: size, ...style }}>
      {bloom && <div className={cn('absolute inset-0 rounded-full opacity-70 blur-[14px]', speed)}
                     style={{ background: IRIS_CONIC, WebkitMask: mask, mask }} />}
      <div className={cn('absolute inset-0 rounded-full', speed)} style={{ background: IRIS_CONIC, WebkitMask: mask, mask }} />
    </div>
  )
}

/** Pill button. `iris` = plum pill with an iridescent rim; `glass` = frosted; `ghost` = text. */
export function Pill({ children, variant = 'iris', className, href, size = 'md', onClick, dark }: {
  children: ReactNode; variant?: 'iris' | 'glass' | 'ghost' | 'white'; className?: string; href?: string; size?: 'sm' | 'md' | 'lg'
  onClick?: () => void; dark?: boolean
}) {
  const pad = size === 'sm' ? 'h-8 px-3.5 text-[13px]' : size === 'lg' ? 'h-12 px-6 text-[15px]' : 'h-10 px-5 text-[14px]'
  const Tag = href ? 'a' : 'button'
  const base = cn('p-focus group relative inline-flex select-none items-center justify-center gap-2 rounded-full font-medium tracking-[-0.01em] transition-[transform,box-shadow] duration-200 active:scale-[.97]', pad, className)
  if (variant === 'iris') {
    return (
      <Tag href={href} onClick={onClick} className={cn(base, 'text-white')}
           style={{ background: P.plum, boxShadow: `0 10px 30px -10px rgba(107,78,255,.55), 0 2px 6px rgba(28,21,48,.25), inset 0 1px 0 rgba(255,255,255,.18)` }}>
        <span aria-hidden className="absolute -inset-px rounded-full opacity-90"
              style={{ padding: 1, background: IRIS, WebkitMask: 'linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)', WebkitMaskComposite: 'xor', maskComposite: 'exclude' }} />
        <span aria-hidden className="absolute inset-0 rounded-full opacity-0 transition-opacity duration-300 group-hover:opacity-100"
              style={{ background: `radial-gradient(120% 140% at 50% 120%, rgba(185,167,255,.55), transparent 60%)` }} />
        <span className="relative inline-flex items-center gap-2">{children}</span>
      </Tag>
    )
  }
  if (variant === 'white') {
    return <Tag href={href} onClick={onClick} className={cn(base, 'bg-white text-[#1C1530] shadow-[0_10px_30px_-12px_rgba(44,30,90,.45),inset_0_-1px_0_rgba(28,21,48,.06)] hover:shadow-[0_14px_36px_-12px_rgba(44,30,90,.55)]')}>{children}</Tag>
  }
  if (variant === 'glass') {
    return <Tag href={href} onClick={onClick} className={cn(base, dark ? 'text-white' : 'text-[#1C1530]', 'hover:-translate-y-px')} style={dark ? glass.dark : glass.thin}>{children}</Tag>
  }
  return <Tag href={href} onClick={onClick} className={cn(base, dark ? 'text-white/75 hover:text-white' : 'text-[#5E5677] hover:text-[#1C1530]')}>{children}</Tag>
}

/** Small eyebrow chip with an iridescent dot. */
export function Eyebrow({ children, className, dark }: { children: ReactNode; className?: string; dark?: boolean }) {
  return (
    <span className={cn('inline-flex items-center gap-2 rounded-full px-3 py-1 text-[12px] font-medium tracking-[-0.005em]', dark ? 'text-white/80' : 'text-[#3A3152]', className)}
          style={dark ? glass.dark : glass.thin}>
      <span className="size-1.5 rounded-full" style={{ background: IRIS, boxShadow: `0 0 10px ${P.lilac}` }} />
      {children}
    </span>
  )
}

/** Simple rise-in that respects ?shot. */
export function Rise({ children, delay = 0, className, y = 16 }: { children: ReactNode; delay?: number; className?: string; y?: number }) {
  return (
    <motion.div className={className}
      initial={isShot ? false : { opacity: 0, y, filter: 'blur(8px)' }}
      whileInView={{ opacity: 1, y: 0, filter: 'blur(0px)' }} viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1], delay }}>
      {children}
    </motion.div>
  )
}

/** Renders children at a fixed design size and scales them down to fit the available width. */
export function Scaled({ w, h, children, className, max = 1 }: { w: number; h: number; children: ReactNode; className?: string; max?: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const [s, setS] = useState(1)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const fit = () => setS(Math.min(max, el.clientWidth / w))
    fit()
    const ro = new ResizeObserver(fit)
    ro.observe(el)
    return () => ro.disconnect()
  }, [w, max])
  return (
    <div ref={ref} className={cn('relative w-full', className)} style={{ height: h * s }}>
      <div className="absolute left-1/2 top-0" style={{ width: w, height: h, transform: `translateX(-50%) scale(${s})`, transformOrigin: 'top center' }}>
        {children}
      </div>
    </div>
  )
}

/** Desktop-ish backdrop for app surfaces: an iridescent wallpaper. */
export function Wallpaper({ dark, className, children, style }: { dark?: boolean; className?: string; children?: ReactNode; style?: CSSProperties }) {
  return (
    <div className={cn('relative overflow-hidden', className)} style={{ background: dark ? P.night : '#EDE7FA', ...style }}>
      <div aria-hidden className="absolute inset-0" style={{
        background: dark
          ? `radial-gradient(60% 70% at 15% 10%, rgba(255,107,139,.35), transparent 60%), radial-gradient(55% 60% at 90% 20%, rgba(94,231,223,.22), transparent 60%), radial-gradient(70% 80% at 60% 100%, rgba(107,78,255,.45), transparent 60%)`
          : `radial-gradient(60% 70% at 12% 8%, rgba(255,107,139,.55), transparent 60%), radial-gradient(55% 60% at 92% 18%, rgba(94,231,223,.55), transparent 62%), radial-gradient(75% 80% at 55% 105%, rgba(185,167,255,.85), transparent 62%), linear-gradient(160deg, #FBE9F1, #EDE7FA 45%, #E2F6F7)`,
      }} />
      <div aria-hidden className="p-grain absolute inset-0 opacity-[.18] mix-blend-overlay" />
      <div className="relative">{children}</div>
    </div>
  )
}

/** NumberTicker that renders the final value directly in screenshot mode. */
export function Ticker({ value, className }: { value: string; className?: string }) {
  if (isShot) return <span className={cn('tabular-nums', className)}>{value}</span>
  return <NumberTicker value={value} className={className} />
}
