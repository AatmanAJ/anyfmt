import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useState } from 'react'
import { isShot } from '../../shared/kit'
import type { WheelSegment } from '../../shared/Wheel'
import { cn } from '../../shared/cn'
import { FileHub, SignalWheel } from './SignalWheel'
import { C } from './tokens'
import { Led } from './Mark'

type Phase = 'idle' | 'drag' | 'key' | 'open' | 'aim' | 'drop' | 'done'
const SCRIPT: { phase: Phase; ms: number }[] = [
  { phase: 'idle', ms: 900 }, { phase: 'drag', ms: 700 }, { phase: 'key', ms: 380 }, { phase: 'open', ms: 420 },
  { phase: 'aim', ms: 1600 }, { phase: 'drop', ms: 380 }, { phase: 'done', ms: 2300 },
]

/** A dark file tile with a mono badge, Signal style. */
export function SignalFile({ ext = 'MOV', name = 'clip.mov', size = 64, lit = false }: { ext?: string; name?: string; size?: number; lit?: boolean }) {
  const w = size, h = size * 1.22
  return (
    <div className="flex flex-col items-center gap-1.5">
      <div className="relative" style={{ width: w, height: h }}>
        <svg width={w} height={h} viewBox="0 0 64 78" className="absolute inset-0 drop-shadow-[0_14px_24px_rgba(0,0,0,.6)]" aria-hidden>
          <defs>
            <linearGradient id="sgf" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#2A2A2F" /><stop offset="1" stopColor="#151517" /></linearGradient>
          </defs>
          <path d="M6 1.5h36l20.5 20.5V72a4.5 4.5 0 0 1-4.5 4.5H6A4.5 4.5 0 0 1 1.5 72V6A4.5 4.5 0 0 1 6 1.5z" fill="url(#sgf)" stroke="rgba(255,255,255,.14)" />
          <path d="M42 1.5V16a6 6 0 0 0 6 6h14.5" fill="none" stroke="rgba(255,255,255,.18)" />
          {[0, 1, 2, 3, 4].map((r) => [0, 1, 2, 3, 4, 5].map((c) => (
            <circle key={`${r}${c}`} cx={13 + c * 7.6} cy={30 + r * 6.4} r={1.25} fill={lit && r === 2 ? C.solar : C.bone} opacity={lit && r === 2 ? 1 : 0.12 + ((r + c) % 3) * 0.06} />
          )))}
        </svg>
        <span className="absolute bottom-[9%] left-1/2 -translate-x-1/2 rounded-[3px] px-1.5 py-[3px] font-mono text-[8.5px] font-bold leading-none tracking-[0.12em]"
          style={{ background: C.solar, color: C.void }}>{ext}</span>
      </div>
      {name && <span className="rounded-[4px] bg-black/50 px-1.5 py-0.5 font-geist text-[11px] text-white/85">{name}</span>}
    </div>
  )
}

export function KeyCap({ symbol, label, pressed, size = 'md', onClick, active }: { symbol: string; label?: string; pressed?: boolean; size?: 'sm' | 'md' | 'lg'; onClick?: () => void; active?: boolean }) {
  const dims = size === 'lg' ? 'h-[84px] min-w-[96px] px-3.5 py-3 text-[30px]' : size === 'sm' ? 'h-[44px] min-w-[52px] px-2 py-1.5 text-[17px]' : 'h-[58px] min-w-[68px] px-2.5 py-2 text-[22px]'
  const Comp = onClick ? motion.button : motion.div
  return (
    <Comp onClick={onClick} type={onClick ? 'button' : undefined}
      animate={{ y: pressed ? 3 : 0 }}
      transition={{ type: 'spring', stiffness: 700, damping: 30 }}
      className={cn('relative inline-flex flex-col items-start justify-between rounded-[10px] text-left font-geist outline-none focus-visible:ring-2 focus-visible:ring-[#D7FF3A]', dims)}
      style={{
        background: pressed || active ? 'linear-gradient(180deg,#26262A,#1A1A1D)' : 'linear-gradient(180deg,#2A2A2F,#1C1C1F)',
        color: C.bone,
        boxShadow: pressed
          ? `inset 0 1px 0 rgba(255,255,255,.06), 0 1px 0 #000, 0 0 0 1px ${active ? C.solar : '#000'}`
          : `inset 0 1px 0 rgba(255,255,255,.12), 0 4px 0 #000, 0 0 0 1px ${active ? C.solar : '#000'}, 0 10px 20px -6px rgba(0,0,0,.8)`,
      }}>
      <span className="leading-none">{symbol}</span>
      {label && <span className="font-mono text-[9px] uppercase leading-none tracking-[0.14em]" style={{ color: C.ash }}>{label}</span>}
      <span className="absolute right-2 top-2"><Led on={!!(pressed || active)} size={4} /></span>
    </Comp>
  )
}

/** The hero demo: drag → ⇧ → wheel blooms → aim → drop → done. Reports aim so the LED field can follow. */
export function SignalDemo({
  segments, target, sweep, size = 340, onAim, className,
}: { segments: readonly WheelSegment[]; target: number; sweep?: number[]; size?: number; onAim?: (i: number | null) => void; className?: string }) {
  const reduce = useReducedMotion()
  const [step, setStep] = useState(isShot ? 4 : 0)
  const [aim, setAim] = useState<number | null>(isShot ? target : null)
  const phase = SCRIPT[step].phase
  const path = sweep ?? [target]

  useEffect(() => {
    if (isShot) return
    const t = setTimeout(() => setStep((s) => (s + 1) % SCRIPT.length), SCRIPT[step].ms)
    return () => clearTimeout(t)
  }, [step])

  useEffect(() => {
    if (isShot) return
    if (phase !== 'aim') { if (phase !== 'drop') setAim(null); return }
    let i = 0
    setAim(path[0])
    const each = SCRIPT[4].ms / path.length
    const id = setInterval(() => { i = Math.min(i + 1, path.length - 1); setAim(path[i]) }, each)
    return () => clearInterval(id)
  }, [phase]) // eslint-disable-line react-hooks/exhaustive-deps

  const hover = phase === 'drop' ? target : aim
  useEffect(() => { onAim?.(hover) }, [hover]) // eslint-disable-line react-hooks/exhaustive-deps

  const open = phase === 'open' || phase === 'aim' || phase === 'drop'
  const lifted = phase !== 'idle' && phase !== 'done'
  const n = segments.length
  const ang = aim != null ? (aim / n) * Math.PI * 2 : 0
  const rAim = size * 0.3
  const px = aim != null ? rAim * Math.sin(ang) : phase === 'drag' ? -22 : 0
  const py = aim != null ? -rAim * Math.cos(ang) : phase === 'drag' ? 12 : 0
  const keyDown = phase === 'key' || phase === 'open' || phase === 'aim'

  return (
    <div className={cn('relative flex items-center justify-center', className)} style={{ width: size, height: size }}>
      <div className="absolute inset-0">
        <SignalWheel segments={segments} size={size} open={open} interactive={false} hoverIndex={hover}
          hub={<FileHub stem="clip" ext="MOV" meta="48 MB" size={size} />} />
      </div>
      <motion.div className="absolute z-10" initial={false}
        animate={{ x: px, y: py, scale: phase === 'drop' ? 0.4 : lifted ? 1.05 : 1, opacity: phase === 'drop' || phase === 'done' ? 0 : 1 }}
        transition={reduce ? { duration: 0 } : { type: 'spring', stiffness: 260, damping: 24 }}>
        <div className={cn('transition-transform duration-300', lifted && 'rotate-[-5deg]')}>
          <SignalFile size={size / 6} name={lifted ? '' : 'clip.mov'} />
        </div>
        <svg className="absolute -bottom-2 -right-3" width="22" height="22" viewBox="0 0 24 24" aria-hidden>
          <path d="M5 3l14 8-6 1.6L10 19z" fill={C.bone} stroke="#000" strokeWidth="1.2" strokeLinejoin="round" />
        </svg>
      </motion.div>
      <div className="absolute -bottom-6 -right-2 z-20 sm:-right-10">
        <KeyCap symbol="⇧" label="Shift" pressed={keyDown} active={keyDown} size="sm" />
      </div>
      <AnimatePresence>
        {phase === 'done' && (
          <motion.div className="absolute left-1/2 top-1/2 z-30"
            initial={{ opacity: 0, y: 14, x: '-50%', scale: 0.96 }} animate={{ opacity: 1, y: '-50%', x: '-50%', scale: 1 }}
            exit={{ opacity: 0, y: '-60%', x: '-50%' }} transition={{ type: 'spring', stiffness: 320, damping: 26 }}>
            <DoneToast name="clip.gif" detail="4.1 MB · 1.8 s" />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

/** Done toast: dark vibrancy pill, one lit LED. */
export function DoneToast({ name, detail, action = 'Reveal' }: { name: string; detail: string; action?: string }) {
  return (
    <div className="flex items-center gap-3 whitespace-nowrap rounded-full py-2 pl-3 pr-2 font-geist text-[13px]"
      style={{ background: 'rgba(22,22,25,.82)', backdropFilter: 'blur(24px) saturate(160%)', WebkitBackdropFilter: 'blur(24px) saturate(160%)', color: C.bone, boxShadow: 'inset 0 0.5px 0 rgba(255,255,255,.16), 0 0 0 0.5px rgba(0,0,0,.9), 0 18px 40px -12px rgba(0,0,0,.9)' }}>
      <Led size={7} />
      <span className="font-medium">{name}</span>
      <span className="font-mono text-[11px] tracking-[0.04em]" style={{ color: C.ash }}>{detail}</span>
      <span className="rounded-full px-2.5 py-1 font-mono text-[10px] font-semibold uppercase tracking-[0.12em]" style={{ background: C.solar, color: C.void }}>{action}</span>
    </div>
  )
}
