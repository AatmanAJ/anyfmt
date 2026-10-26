import {
  AnimatePresence, motion, useReducedMotion, useScroll, useSpring, useTransform, useVelocity, type MotionValue,
} from 'motion/react'
import {
  AppWindow, ArrowRightLeft, Clipboard, Copy, Crop, Eraser, FileText, FolderInput, Minimize2, PaintBucket, PenLine,
  Scissors, SlidersHorizontal, Terminal, Wifi, X, Check, AlertTriangle,
} from 'lucide-react'
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { NumberTicker, isShot } from '../../shared/kit'
import { product } from '../../shared/product'
import { CobaltWheel, Hub, type Seg } from './CobaltWheel'
import { C } from './tokens'

export const convertSegs: Seg[] = product.formatsVideo.map((f) => ({ id: f, label: f }))
export const imageSegs: Seg[] = product.formatsImage.map((f) => ({ id: f, label: f }))
const toolIcons: Record<string, ReactNode> = {
  Compress: <Minimize2 size={15} strokeWidth={2.4} />, Crop: <Crop size={15} strokeWidth={2.4} />,
  Edit: <SlidersHorizontal size={15} strokeWidth={2.4} />, Annotate: <PenLine size={15} strokeWidth={2.4} />,
  'Add BG': <PaintBucket size={15} strokeWidth={2.4} />, Redact: <Eraser size={15} strokeWidth={2.4} />,
  Metadata: <FileText size={15} strokeWidth={2.4} />, Trim: <Scissors size={15} strokeWidth={2.4} />,
}
export const toolSegs: Seg[] = product.tools.map((t) => ({ id: t, label: t, icon: toolIcons[t] }))
const actIcons: Record<string, ReactNode> = {
  AirDrop: <Wifi size={16} strokeWidth={2.4} />, Float: <AppWindow size={16} strokeWidth={2.4} />,
  Copy: <Copy size={16} strokeWidth={2.4} />, Move: <FolderInput size={16} strokeWidth={2.4} />,
  'Copy Path': <Clipboard size={16} strokeWidth={2.4} />, Terminal: <Terminal size={16} strokeWidth={2.4} />,
}
export const actionSegs: Seg[] = product.actions.map((a) => ({ id: a, label: a, icon: actIcons[a] }))
export const ArrowIcon = ArrowRightLeft

/** Tiny mono label. */
export function Eyebrow({ children, className, style }: { children: ReactNode; className?: string; style?: CSSProperties }) {
  return <div className={cn('font-mono text-[11px] font-medium uppercase tracking-[0.2em]', className)} style={style}>{children}</div>
}

/** A stamped sticker. */
export function Sticker({
  children, tone = 'flame', rotate = -6, className, style,
}: { children: ReactNode; tone?: 'flame' | 'ice' | 'midnight' | 'cobalt'; rotate?: number; className?: string; style?: CSSProperties }) {
  const tones = {
    flame: { background: C.flame, color: C.midnight, boxShadow: `0 0 0 2px ${C.midnight}, 0 8px 0 ${C.midnight}` },
    ice: { background: C.ice, color: C.midnight, boxShadow: `0 0 0 2px ${C.midnight}, 0 8px 0 ${C.midnight}` },
    midnight: { background: C.midnight, color: C.ice, boxShadow: `0 0 0 2px ${C.ice}, 0 8px 0 ${C.ice}` },
    cobalt: { background: C.cobalt, color: C.ice, boxShadow: `0 0 0 2px ${C.ice}, 0 8px 0 ${C.midnight}` },
  }[tone]
  return (
    <span className={cn('inline-flex items-center gap-2 whitespace-nowrap rounded-[10px] px-3 py-1.5 font-anton text-[22px] uppercase leading-none tracking-[0.02em]', className)}
          style={{ ...tones, transform: `rotate(${rotate}deg)`, ...style }}>
      {children}
    </span>
  )
}

/** Racing roundel. */
export function RaceNumber({ n, size = 64, className, tone = 'ice' }: { n: string; size?: number; className?: string; tone?: 'ice' | 'flame' }) {
  const bg = tone === 'ice' ? C.ice : C.flame
  return (
    <span className={cn('inline-grid shrink-0 place-items-center rounded-full font-anton leading-none', className)}
          style={{ width: size, height: size, background: bg, color: C.midnight, fontSize: size * 0.5, boxShadow: `inset 0 0 0 ${Math.max(2, size / 22)}px ${C.midnight}, 0 0 0 ${Math.max(2, size / 28)}px ${bg}` }}>
      <span style={{ transform: 'skewX(-8deg)', marginTop: size * 0.04 }}>{n}</span>
    </span>
  )
}

/** Chunky keycap. */
export function KeyCap({ sym, name, pressed, size = 'md', tone = 'ice' }: { sym: string; name?: string; pressed?: boolean; size?: 'sm' | 'md' | 'lg' | 'xl'; tone?: 'ice' | 'flame' }) {
  const dims = { sm: [44, 40, 18], md: [72, 64, 26], lg: [112, 100, 44], xl: [150, 132, 60] }[size]
  const face = tone === 'flame' || pressed ? C.flame : C.ice
  return (
    <motion.span
      animate={{ y: pressed ? 5 : 0, boxShadow: pressed ? `0 1px 0 ${C.midnight}, 0 0 0 2px ${C.midnight}` : `0 6px 0 ${C.midnight}, 0 0 0 2px ${C.midnight}` }}
      transition={{ type: 'spring', stiffness: 800, damping: 30 }}
      className="relative inline-flex shrink-0 flex-col justify-between rounded-[14px] p-2.5 text-left"
      style={{ width: dims[0], height: dims[1], background: face, color: C.midnight }}>
      <span className="leading-none" style={{ fontSize: dims[2], fontFamily: '-apple-system, "SF Pro Text", system-ui, sans-serif', fontWeight: 600 }}>{sym}</span>
      {name && size !== 'sm' && <span className="font-mono text-[10px] font-semibold uppercase tracking-[0.12em] opacity-70">{name}</span>}
    </motion.span>
  )
}

/** Skew driven by scroll velocity. */
export function useVelocitySkew(max = 10): MotionValue<number> {
  const reduce = useReducedMotion()
  const { scrollY } = useScroll()
  const v = useVelocity(scrollY)
  const sm = useSpring(v, { damping: 40, stiffness: 300 })
  return useTransform(sm, [-2400, 0, 2400], reduce || isShot ? [0, 0, 0] : [max, 0, -max], { clamp: true })
}

export function SkewOnScroll({ children, className, max = 10 }: { children: ReactNode; className?: string; max?: number }) {
  const skewX = useVelocitySkew(max)
  return <motion.div className={className} style={{ skewX }}>{children}</motion.div>
}

/** Full-bleed vertical bands that slide against each other on scroll. */
export function Bands({ count = 7, className, palette, target }: {
  count?: number; className?: string; palette?: string[]; target?: React.RefObject<HTMLElement | null>
}) {
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll(target ? { target, offset: ['start start', 'end start'] } : undefined)
  const cols = palette ?? [C.ultra, C.cobalt, '#1733F0', C.cobalt, C.ultra, '#0E22B8', C.cobalt]
  return (
    <div className={cn('pointer-events-none absolute inset-0 flex overflow-hidden', className)} aria-hidden>
      {Array.from({ length: count }).map((_, i) => (
        <Band key={i} i={i} color={cols[i % cols.length]} p={scrollYProgress} still={!!reduce || isShot} />
      ))}
    </div>
  )
}

function Band({ i, color, p, still }: { i: number; color: string; p: MotionValue<number>; still: boolean }) {
  const dir = i % 2 === 0 ? 1 : -1
  const amt = 60 + (i % 3) * 50
  const y = useTransform(p, [0, 1], still ? [0, 0] : [0, dir * amt])
  const scaleY = useTransform(p, [0, 1], still ? [1, 1] : [1, 1 + (i % 3) * 0.08])
  return <motion.div className="-my-[160px] flex-1" style={{ background: color, y, scaleY }} />
}

/** File glyph in Cobalt style. */
export function CobaltFile({ ext = 'MOV', name = 'clip.mov', size = 76, thumb = true }: { ext?: string; name?: string; size?: number; thumb?: boolean }) {
  const w = size, h = size * 1.22
  return (
    <div className="flex flex-col items-center gap-1.5">
      <div className="relative" style={{ width: w, height: h }}>
        <svg width={w} height={h} viewBox="0 0 64 78" className="absolute inset-0 drop-shadow-[0_10px_20px_rgba(2,5,22,.5)]" aria-hidden>
          <path d="M6 1h36l20 20v51a5 5 0 0 1-5 5H6a5 5 0 0 1-5-5V6a5 5 0 0 1 5-5z" fill={C.ice} />
          <path d="M42 1v14a6 6 0 0 0 6 6h14" fill="#C9D2FF" />
          {thumb && (
            <g>
              <rect x="9" y="26" width="46" height="30" rx="3" fill={C.cobalt} />
              <rect x="9" y="26" width="15" height="30" fill={C.ultra} />
              <rect x="40" y="26" width="15" height="30" fill={C.ultra} />
              <path d="M28 34v14l11-7z" fill={C.ice} />
            </g>
          )}
        </svg>
        <span className="absolute bottom-[9%] left-1/2 -translate-x-1/2 rounded-[4px] px-1.5 py-[3px] font-anton text-[11px] leading-none tracking-[0.06em]"
              style={{ background: C.flame, color: C.midnight }}>{ext}</span>
      </div>
      {name && <span className="rounded-[5px] px-1.5 py-0.5 font-geist text-[11px] font-medium" style={{ background: 'rgba(5,10,46,.6)', color: C.ice }}>{name}</span>}
    </div>
  )
}

export function DoneToast({ title = 'CLIP.GIF', body = 'Saved next to the original.', action = 'Show in Finder', compact }: { title?: string; body?: string; action?: string; compact?: boolean }) {
  return (
    <div className="flex max-w-full items-center gap-3 rounded-[18px] p-2 pr-3 font-geist backdrop-blur-xl"
         style={{ background: 'rgba(5,10,46,.92)', color: C.ice, boxShadow: `inset 0 0 0 1px rgba(233,238,255,.14), 0 24px 60px -12px rgba(2,5,22,.8)` }}>
      <span className="grid size-10 shrink-0 place-items-center rounded-[12px]" style={{ background: C.flame, color: C.midnight, boxShadow: '0 0 22px rgba(255,106,43,.6)' }}>
        <Check size={22} strokeWidth={3.2} />
      </span>
      <div className="min-w-0">
        <div className="whitespace-nowrap font-anton text-[19px] uppercase leading-none tracking-[0.02em]">{title} <span style={{ color: C.flame }}>DONE.</span></div>
        {!compact && <div className="mt-1 text-[12px] opacity-70">{body}</div>}
      </div>
      {!compact && <span className="ml-2 whitespace-nowrap rounded-full px-3 py-1.5 text-[12px] font-semibold" style={{ background: 'rgba(233,238,255,.1)' }}>{action}</span>}
    </div>
  )
}

export function ErrorToast({ title = "CAN'T READ IT.", body = 'clip.mov looks damaged. Nothing was changed.' }: { title?: string; body?: string }) {
  return (
    <div className="flex max-w-full items-center gap-3 rounded-[18px] p-2 pr-3 font-geist backdrop-blur-xl"
         style={{ background: 'rgba(5,10,46,.92)', color: C.ice, boxShadow: `inset 0 0 0 1.5px ${C.flame}, 0 24px 60px -12px rgba(2,5,22,.8)` }}>
      <span className="grid size-10 shrink-0 place-items-center rounded-[12px]" style={{ background: C.ice, color: C.midnight }}>
        <AlertTriangle size={20} strokeWidth={2.6} />
      </span>
      <div className="min-w-0">
        <div className="font-anton text-[19px] uppercase leading-none tracking-[0.02em]">{title}</div>
        <div className="mt-1 text-[12px] opacity-75">{body}</div>
      </div>
      <span className="ml-2 whitespace-nowrap rounded-full px-3 py-1.5 text-[12px] font-semibold" style={{ background: C.flame, color: C.midnight }}>Try again</span>
      <X size={14} className="opacity-50" />
    </div>
  )
}

type Phase = 'idle' | 'drag' | 'key' | 'open' | 'aim' | 'drop' | 'done'
const SCRIPT: { phase: Phase; ms: number }[] = [
  { phase: 'idle', ms: 800 }, { phase: 'drag', ms: 650 }, { phase: 'key', ms: 320 }, { phase: 'open', ms: 380 },
  { phase: 'aim', ms: 1500 }, { phase: 'drop', ms: 360 }, { phase: 'done', ms: 2200 },
]

/** The hero drag demo, rebuilt on the Cobalt wheel. In ?shot it freezes on the aim. */
export function CobaltDemo({ size = 380, segments = convertSegs, target = 0, sweep = [3, 2, 1, 0], className }: {
  size?: number; segments?: Seg[]; target?: number; sweep?: number[]; className?: string
}) {
  const reduce = useReducedMotion()
  const [step, setStep] = useState(isShot ? 4 : 0)
  const [aim, setAim] = useState<number | null>(isShot ? target : null)
  const ref = useRef<HTMLDivElement>(null)
  const phase = SCRIPT[step].phase

  useEffect(() => {
    if (isShot) return
    const t = setTimeout(() => setStep((s) => (s + 1) % SCRIPT.length), SCRIPT[step].ms)
    return () => clearTimeout(t)
  }, [step])
  useEffect(() => {
    if (isShot) return
    if (phase !== 'aim') { if (phase !== 'drop') setAim(null); return }
    let i = 0
    setAim(sweep[0])
    const id = setInterval(() => { i = Math.min(i + 1, sweep.length - 1); setAim(sweep[i]) }, SCRIPT[4].ms / sweep.length)
    return () => clearInterval(id)
  }, [phase]) // eslint-disable-line react-hooks/exhaustive-deps

  const open = phase === 'open' || phase === 'aim' || phase === 'drop'
  const lifted = phase !== 'idle' && phase !== 'done'
  const n = segments.length
  const ang = aim != null ? (aim / n) * Math.PI * 2 : 0
  const rA = size * 0.37
  // While aiming, the file rides up-left of the pointer so the wedge label stays readable.
  const px = aim != null ? rA * Math.sin(ang) - size * 0.07 : phase === 'drag' ? -26 : 0
  const py = aim != null ? -rA * Math.cos(ang) - size * 0.1 : phase === 'drag' ? 14 : 0
  const keyDown = phase === 'key' || phase === 'open' || phase === 'aim'

  return (
    <div ref={ref} className={cn('relative flex items-center justify-center', className)} style={{ width: size, height: size }}>
      <div className="absolute inset-0">
        <CobaltWheel segments={segments} size={size} open={open} interactive={false} hoverIndex={phase === 'drop' ? target : aim}
          hubLabel={<Hub top="MOV" bottom="clip.mov" size={size} />} />
      </div>
      <motion.div className="absolute z-10" initial={false}
        animate={{ x: reduce ? 0 : px, y: reduce ? 0 : py, scale: phase === 'drop' ? 0.3 : open ? 0.52 : lifted ? 1.05 : 1, opacity: phase === 'drop' || phase === 'done' ? 0 : 1 }}
        transition={{ type: 'spring', stiffness: 300, damping: 24 }}>
        <div className={cn('transition-transform duration-200', lifted && 'rotate-[-6deg]')}>
          <CobaltFile size={76} name={open ? '' : 'clip.mov'} />
        </div>
        <svg className="absolute -bottom-2 -right-3" width="24" height="24" viewBox="0 0 24 24" aria-hidden>
          <path d="M5 3l14 8-6 1.6L10 19z" fill={C.ice} stroke={C.midnight} strokeWidth="1.4" strokeLinejoin="round" />
        </svg>
      </motion.div>
      <div className="absolute -bottom-2 -right-2 z-20 sm:-right-6"><KeyCap sym="⇧" name="shift" pressed={keyDown} size="md" /></div>
      <AnimatePresence>
        {phase === 'done' && (
          <motion.div className="absolute left-1/2 top-1/2 z-30" initial={{ opacity: 0, y: 20, x: '-50%', scale: 0.9 }}
            animate={{ opacity: 1, y: '-50%', x: '-50%', scale: 1 }} exit={{ opacity: 0, y: '-70%', x: '-50%' }}
            transition={{ type: 'spring', stiffness: 400, damping: 26 }}>
            <DoneToast compact />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

/** Outline text helper (Anton with an ice stroke). */
export const outline = (color: string = C.ice, w = 2): CSSProperties => ({ WebkitTextStroke: `${w}px ${color}`, color: 'transparent' })

/** NumberTicker that renders its final value in ?shot (offscreen WebKit never ticks rAF). */
export function Ticker({ value, className }: { value: string; className?: string }) {
  if (isShot) return <span className={cn('tabular-nums', className)}>{value}</span>
  return <NumberTicker value={value} className={className} />
}
