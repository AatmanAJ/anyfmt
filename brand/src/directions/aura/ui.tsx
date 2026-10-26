import {
  ArrowRightLeft, Clipboard, Crop, Eraser, FolderInput, ImagePlus, Info, Minimize2, Paintbrush, PenLine,
  Scissors, Send, Square, TerminalSquare, Link2,
} from 'lucide-react'
import { animate, motion, useInView, useReducedMotion } from 'motion/react'
import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { isShot } from '../../shared/kit'
import { cn } from '../../shared/cn'
import { product } from '../../shared/product'
import type { AuraSegment } from './AuraWheel'

/* ------------------------------------------------------------------ data */

const ic = (Icon: typeof Crop, s = 15) => <Icon size={s} strokeWidth={1.7} />

export const convertSegs: AuraSegment[] = [
  { id: 'gif', label: 'GIF', sub: '15 fps' },
  { id: 'mp4', label: 'MP4', sub: 'H.264' },
  { id: 'webm', label: 'WEBM', sub: 'VP9' },
  { id: 'mov', label: 'MOV', sub: 'HEVC' },
  { id: 'm4v', label: 'M4V' },
  { id: 'mkv', label: 'MKV' },
  { id: 'mp3', label: 'MP3', sub: 'audio' },
  { id: 'png', label: 'PNG', sub: 'frames' },
]
const toolIcons = [Minimize2, Crop, PenLine, Paintbrush, ImagePlus, Eraser, Info, Scissors]
export const toolSegs: AuraSegment[] = product.tools.map((t, i) => ({ id: t, label: t, icon: ic(toolIcons[i]) }))
const actIcons = [Send, Square, Clipboard, FolderInput, Link2, TerminalSquare]
export const actionSegs: AuraSegment[] = product.actions.map((t, i) => ({ id: t, label: t, icon: ic(actIcons[i]) }))

export const WHEELS = [
  { key: '⇧', name: 'Shift', wheel: 'Convert', segs: convertSegs, tone: 'apricot' as const, blurb: product.keys[0].blurb, icon: ArrowRightLeft },
  { key: '⌘', name: 'Command', wheel: 'Tools', segs: toolSegs, tone: 'peri' as const, blurb: product.keys[1].blurb, icon: Scissors },
  { key: '⌃', name: 'Control', wheel: 'Actions', segs: actionSegs, tone: 'butter' as const, blurb: product.keys[2].blurb, icon: Send },
]

/* ------------------------------------------------------------------ marks */

/** The Halo mark: a ring of light with a gap where the dragged file sits, like a sun clearing the horizon. */
export function Mark({ size = 40, tone = 'glow', className, title }: { size?: number; tone?: 'glow' | 'ink' | 'paper' | 'mono'; className?: string; title?: string }) {
  const id = `m${size}${tone}`
  const stroke = tone === 'glow' ? `url(#${id}g)` : tone === 'ink' ? '#1E1B18' : tone === 'paper' ? '#FBF7F0' : 'currentColor'
  const dot = tone === 'glow' ? `url(#${id}d)` : stroke
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" className={className} role={title ? 'img' : undefined} aria-label={title} aria-hidden={title ? undefined : true}>
      <defs>
        <linearGradient id={`${id}g`} x1="8" y1="56" x2="56" y2="8" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#9DB4FF" />
          <stop offset=".55" stopColor="#FFB27A" />
          <stop offset="1" stopColor="#FF9858" />
        </linearGradient>
        <radialGradient id={`${id}d`} cx=".4" cy=".35" r=".7">
          <stop offset="0" stopColor="#FFD9BC" />
          <stop offset="1" stopColor="#FF9858" />
        </radialGradient>
      </defs>
      {/* ring with a 64° opening at 1–2 o'clock */}
      <path d="M37.2 7.55 A25 25 0 1 0 56.45 26.8" fill="none" stroke={stroke} strokeWidth="8.5" strokeLinecap="round" />
      <circle cx="49.68" cy="14.32" r="5.3" fill={dot} />
    </svg>
  )
}

export function Wordmark({ className, style }: { className?: string; style?: CSSProperties }) {
  return (
    <span className={cn('aura-display select-none', className)}
          style={{ fontWeight: 520, letterSpacing: '-0.045em', fontVariationSettings: '"opsz" 144, "SOFT" 100, "WONK" 1', ...style }}>
      halo
    </span>
  )
}

export function Lockup({ size = 28, className, tone = 'glow' }: { size?: number; className?: string; tone?: 'glow' | 'ink' | 'paper' }) {
  return (
    <span className={cn('inline-flex items-center', className)} style={{ gap: size * 0.28 }}>
      <Mark size={size} tone={tone} />
      <Wordmark style={{ fontSize: size * 1.12, lineHeight: 1, color: tone === 'paper' ? '#FBF7F0' : '#1E1B18', marginTop: -size * 0.12 }} />
    </span>
  )
}

/** macOS app icon: a squircle of warm paper with the ring glowing on it. Drawn at 1024 and scaled. */
export function AppIcon({ size = 128, variant = 'paper' }: { size?: number; variant?: 'paper' | 'night' }) {
  const id = `ai${size}${variant}`
  const night = variant === 'night'
  // macOS icon grid: 824 body on a 1024 canvas, 100 inset, ~186 corner radius.
  return (
    <svg width={size} height={size} viewBox="0 0 1024 1024" aria-hidden>
      <defs>
        <linearGradient id={`${id}bg`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={night ? '#2A2520' : '#FFFDF9'} />
          <stop offset="1" stopColor={night ? '#16130F' : '#F3E9DB'} />
        </linearGradient>
        <radialGradient id={`${id}glow`} cx="512" cy="532" r="400" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#FFB27A" stopOpacity={night ? 0.55 : 0.6} />
          <stop offset=".55" stopColor="#FFB27A" stopOpacity=".18" />
          <stop offset="1" stopColor="#9DB4FF" stopOpacity="0" />
        </radialGradient>
        <radialGradient id={`${id}cool`} cx="380" cy="700" r="300" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#9DB4FF" stopOpacity=".55" />
          <stop offset="1" stopColor="#9DB4FF" stopOpacity="0" />
        </radialGradient>
        <linearGradient id={`${id}ring`} x1="250" y1="800" x2="780" y2="240" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#9DB4FF" />
          <stop offset=".55" stopColor="#FFB27A" />
          <stop offset="1" stopColor="#FF8F4D" />
        </linearGradient>
        <radialGradient id={`${id}dot`} cx=".38" cy=".32" r=".75">
          <stop offset="0" stopColor="#FFE6D2" />
          <stop offset="1" stopColor="#FF8F4D" />
        </radialGradient>
        <filter id={`${id}blur`} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="34" /></filter>
        <filter id={`${id}sh`} x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="18" stdDeviation="22" floodColor="#5A3010" floodOpacity=".28" /></filter>
        <clipPath id={`${id}clip`}><rect x="100" y="100" width="824" height="824" rx="186" /></clipPath>
      </defs>
      <g filter={`url(#${id}sh)`}>
        <rect x="100" y="100" width="824" height="824" rx="186" fill={`url(#${id}bg)`} />
      </g>
      <g clipPath={`url(#${id}clip)`}>
        <rect width="1024" height="1024" fill={`url(#${id}glow)`} />
        <rect width="1024" height="1024" fill={`url(#${id}cool)`} />
        {/* ring glow */}
        <path d="M568.1 267.9 A270 270 0 1 0 776.1 475.9" fill="none" stroke="#FFB27A" strokeWidth="110" strokeLinecap="round" opacity=".7" filter={`url(#${id}blur)`} />
        <path d="M568.1 267.9 A270 270 0 1 0 776.1 475.9" fill="none" stroke={`url(#${id}ring)`} strokeWidth="92" strokeLinecap="round" />
        {/* highlight on the ring */}
        <path d="M258.3 439.7 A270 270 0 0 1 377 298.2" fill="none" stroke="#fff" strokeOpacity=".45" strokeWidth="18" strokeLinecap="round" />
        <circle cx="702.9" cy="341.1" r="56" fill={`url(#${id}dot)`} />
        <circle cx="688" cy="324" r="17" fill="#fff" opacity=".6" />
        <rect x="100" y="100" width="824" height="824" rx="186" fill="none" stroke={night ? 'rgba(255,255,255,.12)' : 'rgba(120,80,40,.12)'} strokeWidth="3" />
      </g>
    </svg>
  )
}

/** Monochrome template icon for the menu bar (16/18 px). Pure shape, no gradients. */
export function MenuGlyph({ size = 18, className }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" className={className} aria-hidden>
      <path d="M10.37 2.54 A6.6 6.6 0 1 0 15.46 7.63" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      <circle cx="13.67" cy="4.33" r="1.8" fill="currentColor" />
    </svg>
  )
}

/* ------------------------------------------------------------------ light + paper */

/** Layered, breathing radial light. Put it behind product UI. */
export function Glow({ className, intensity = 1, style }: { className?: string; intensity?: number; style?: CSSProperties }) {
  return (
    <div className={cn('pointer-events-none absolute', className)} style={style} aria-hidden>
      <div className="aura-breathe absolute inset-0 rounded-full"
           style={{ background: 'radial-gradient(closest-side, rgba(255,178,122,.9), rgba(255,178,122,.4) 45%, rgba(255,200,160,0) 75%)', opacity: intensity, filter: 'blur(30px)' }} />
      <div className="aura-drift-a absolute left-[30%] top-[25%] h-[75%] w-[75%] rounded-full"
           style={{ background: 'radial-gradient(closest-side, rgba(157,180,255,.85), rgba(157,180,255,0) 72%)', opacity: intensity, filter: 'blur(34px)' }} />
      <div className="aura-drift-b absolute left-[-5%] top-[5%] h-[60%] w-[60%] rounded-full"
           style={{ background: 'radial-gradient(closest-side, rgba(255,226,170,.9), rgba(255,226,170,0) 72%)', opacity: intensity * 0.9, filter: 'blur(30px)' }} />
    </div>
  )
}

export function Grain({ className }: { className?: string }) {
  return <div className={cn('aura-grain absolute inset-0', className)} aria-hidden />
}

/** A hand-drawn underline. Sits under a word; draws itself in once. */
export function Scribble({ className, color = '#FF9858', width = 220, variant = 0 }: { className?: string; color?: string; width?: number; variant?: 0 | 1 | 2 }) {
  const reduce = useReducedMotion()
  const d = [
    'M3 14 C 40 6, 90 4, 140 7 S 205 12, 217 8',
    'M4 10 C 60 16, 120 2, 216 9 M 30 16 C 80 12, 150 13, 190 15',
    'M5 12 C 50 4, 100 18, 150 8 S 200 6, 215 12',
  ][variant]
  return (
    <svg className={cn('pointer-events-none overflow-visible', className)} width={width} height={width * 0.09} viewBox="0 0 220 20" preserveAspectRatio="none" aria-hidden>
      <motion.path d={d} fill="none" stroke={color} strokeWidth="3.4" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke"
        initial={isShot || reduce ? false : { pathLength: 0 }} animate={{ pathLength: 1 }}
        transition={{ duration: 1.3, ease: [0.65, 0, 0.35, 1], delay: 0.5 }} />
    </svg>
  )
}

/** A keyboard symbol set in the UI face, for use inside serif or hand-written text (Fraunces has no ⇧ ⌘ ⌃). */
export function K({ children }: { children: ReactNode }) {
  return <span className="mx-[0.08em] inline-block font-sans text-[0.92em] font-semibold not-italic" style={{ fontVariationSettings: 'normal' }}>{children}</span>
}

/** Counts up once in view; shows the final value in ?shot and reduced motion. */
export function Ticker({ value, className }: { value: string; className?: string }) {
  const ref = useRef<HTMLSpanElement>(null)
  const reduce = useReducedMotion()
  const inView = useInView(ref, { once: true, margin: '-40px' })
  const m = value.match(/^([^\d]*)([\d.,]+)(.*)$/)
  const target = m ? parseFloat(m[2].replace(/,/g, '')) : 0
  const [n, setN] = useState<number | null>(isShot || reduce || !m ? null : 0)
  useEffect(() => {
    if (!inView || n === null) return
    const c = animate(0, target, { duration: 1.6, ease: [0.16, 1, 0.3, 1], onUpdate: (v) => setN(v) })
    return () => c.stop()
  }, [inView]) // eslint-disable-line react-hooks/exhaustive-deps
  if (!m || n === null) return <span ref={ref} className={cn('tabular-nums', className)}>{value}</span>
  return <span ref={ref} className={cn('tabular-nums', className)}>{m[1]}{Math.round(n).toLocaleString()}<span className="aura-em">{m[3]}</span></span>
}

/** Hand-drawn arrow, for sticky-note callouts. */
export function HandArrow({ className, color = '#5B524A', flip }: { className?: string; color?: string; flip?: boolean }) {
  return (
    <svg className={cn('pointer-events-none', className)} width="70" height="46" viewBox="0 0 70 46" aria-hidden style={{ transform: flip ? 'scaleX(-1)' : undefined }}>
      <path d="M4 6 C 18 30, 38 40, 62 34" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" />
      <path d="M52 27 L 63 34 L 52 41" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

/** A butter-yellow sticky note with a strip of tape. */
export function Sticky({ children, className, rotate = -3, style }: { children: ReactNode; className?: string; rotate?: number; style?: CSSProperties }) {
  return (
    <div className={cn('aura-hand relative w-max max-w-[220px] px-4 pb-3.5 pt-4 text-[15px] leading-[1.25] text-[#3A332C]', className)}
         style={{ background: 'linear-gradient(180deg,#FFEDB0,#FFE597)', transform: `rotate(${rotate}deg)`,
                  boxShadow: '0 1px 1px rgba(80,60,20,.1), 0 14px 24px -12px rgba(120,80,20,.35)', borderRadius: '3px 3px 14px 3px', ...style }}>
      <span className="absolute -top-2 left-1/2 h-4 w-14 -translate-x-1/2 rotate-[2deg] rounded-[2px] bg-white/55 shadow-[0_1px_2px_rgba(0,0,0,.08)]" />
      {children}
    </div>
  )
}

/* ------------------------------------------------------------------ layout helpers */

/** Renders children at a fixed design size and scales it down to fit the column (never up). */
export function Fit({ width, height, children, className, max = 1 }: { width: number; height: number; children: ReactNode; className?: string; max?: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const [s, setS] = useState(1)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const measure = () => setS(Math.min(max, el.getBoundingClientRect().width / width))
    measure()
    const ro = new ResizeObserver(measure)
    ro.observe(el)
    return () => ro.disconnect()
  }, [width, max])
  return (
    <div ref={ref} className={cn('w-full min-w-0', className)} style={{ contain: 'inline-size' }}>
      <div className="relative mx-auto" style={{ width: width * s, height: height * s }}>
        <div className="absolute left-0 top-0" style={{ width, height, transform: `scale(${s})`, transformOrigin: 'top left' }}>{children}</div>
      </div>
    </div>
  )
}

export function Eyebrow({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn('inline-flex items-center gap-2 text-[12.5px] font-semibold uppercase tracking-[0.14em] text-[#B04E1B]', className)}>
      <span className="size-1.5 rounded-full bg-[#FFB27A] shadow-[0_0_10px_3px_rgba(255,178,122,.7)]" />
      {children}
    </div>
  )
}

/** Small paper file tile used across demos. */
export function PaperFile({ ext = 'MOV', name, size = 56, thumb = true }: { ext?: string; name?: string; size?: number; thumb?: boolean }) {
  const w = size, h = size * 1.24
  return (
    <div className="flex flex-col items-center gap-1.5">
      <div className="relative" style={{ width: w, height: h }}>
        <svg width={w} height={h} viewBox="0 0 64 80" className="absolute inset-0 drop-shadow-[0_10px_16px_rgba(120,70,30,.28)]" aria-hidden>
          <path d="M8 2h34l20 20v50a6 6 0 0 1-6 6H8a6 6 0 0 1-6-6V8a6 6 0 0 1 6-6z" fill="#fff" />
          <path d="M42 2v14a6 6 0 0 0 6 6h14" fill="#F4ECE1" />
          {!thumb && [34, 42, 50].map((y) => <rect key={y} x="12" y={y} width={y === 50 ? 22 : 38} height="3" rx="1.5" fill="#1E1B18" opacity=".12" />)}
        </svg>
        {thumb && (
          <div className="absolute overflow-hidden rounded-[4px]" style={{ left: w * 0.13, right: w * 0.13, top: h * 0.3, bottom: h * 0.24,
               background: 'radial-gradient(circle at 70% 30%, #FFE2C2, transparent 60%), linear-gradient(160deg,#FFC79C,#9DB4FF)' }}>
            <div className="absolute bottom-[18%] left-[12%] h-[34%] w-[46%] rounded-[50%_50%_0_0] bg-white/45" />
          </div>
        )}
        <span className="absolute bottom-[8%] left-1/2 -translate-x-1/2 rounded-full bg-[#1E1B18] px-1.5 py-[1px] text-[8.5px] font-bold tracking-wide text-[#FFF8F0]">{ext}</span>
      </div>
      {name && <span className="rounded-full bg-white/70 px-2 py-0.5 text-[11px] font-medium text-[#3A332C] shadow-[0_1px_2px_rgba(0,0,0,.06)]">{name}</span>}
    </div>
  )
}

/** Paper-toned keycap with a warm glow when pressed. */
export function AuraKey({ symbol, label, pressed, size = 'md', onClick, active }: { symbol: string; label?: string; pressed?: boolean; size?: 'xs' | 'sm' | 'md' | 'lg'; onClick?: () => void; active?: boolean }) {
  const dims = size === 'xs' ? 'h-[32px] min-w-[38px] text-[14px] !px-2 !py-1 !rounded-[10px] !justify-center' : size === 'lg' ? 'h-[84px] min-w-[96px] text-[30px]' : size === 'sm' ? 'h-[44px] min-w-[48px] text-[17px]' : 'h-[64px] min-w-[72px] text-[24px]'
  const Tag = onClick ? 'button' : 'div'
  return (
    <Tag onClick={onClick} type={onClick ? 'button' : undefined}
      className={cn('relative inline-flex flex-col items-start justify-between rounded-[16px] px-3 py-2 text-left text-[#1E1B18] transition-all duration-200', dims,
        onClick && 'cursor-pointer')}
      style={{
        background: active || pressed ? 'linear-gradient(180deg,#FFF6EE,#FFE3CB)' : 'linear-gradient(180deg,#FFFFFF,#F6EFE5)',
        transform: pressed ? 'translateY(3px)' : undefined,
        boxShadow: pressed
          ? '0 0 0 .5px rgba(90,60,30,.25), 0 1px 0 #E2D4C2, 0 0 28px 4px rgba(255,178,122,.55)'
          : active
            ? '0 0 0 .5px rgba(90,60,30,.25), 0 4px 0 #E8CBB0, 0 10px 20px -6px rgba(150,80,30,.3), 0 0 24px 2px rgba(255,178,122,.45)'
            : '0 0 0 .5px rgba(90,60,30,.22), 0 4px 0 #E2D4C2, 0 10px 20px -8px rgba(120,70,30,.28)',
      }}>
      <span className="leading-none">{symbol}</span>
      {label && <span className="text-[10.5px] font-semibold tracking-wide text-[#5B524A]">{label}</span>}
    </Tag>
  )
}
