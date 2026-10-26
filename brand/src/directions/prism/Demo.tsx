import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useState } from 'react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { FileTile, Toast } from './AppSurfaces'
import { Hub, PrismWheel, SEG, type PSeg } from './PrismWheel'
import { P } from './theme'

type Phase = 'idle' | 'drag' | 'key' | 'open' | 'aim' | 'drop' | 'done'
const SCRIPT: { phase: Phase; ms: number }[] = [
  { phase: 'idle', ms: 800 }, { phase: 'drag', ms: 650 }, { phase: 'key', ms: 380 }, { phase: 'open', ms: 420 },
  { phase: 'aim', ms: 1500 }, { phase: 'drop', ms: 360 }, { phase: 'done', ms: 2100 },
]

const MODES: { key: string; name: string; segs: PSeg[]; target: number; sweep: number[]; toast: [string, string] }[] = [
  { key: '⇧', name: 'shift', segs: SEG.convert, target: 0, sweep: [2, 1, 0], toast: ['clip.gif is ready', '4.1 MB · saved next to clip.mov'] },
  { key: '⌘', name: 'command', segs: SEG.tools, target: 0, sweep: [6, 7, 0], toast: ['Compressed to 6.2 MB', 'clip-small.mov · 66% smaller'] },
  { key: '⌃', name: 'control', segs: SEG.actions, target: 1, sweep: [0, 1], toast: ['On your Float shelf', 'Drag it out whenever you like'] },
]

export function GlassKey({ k, label, pressed, dark }: { k: string; label: string; pressed?: boolean; dark?: boolean }) {
  return (
    <motion.div animate={{ y: pressed ? 3 : 0 }} transition={{ type: 'spring', stiffness: 700, damping: 30 }}
      className={cn('relative flex h-[58px] w-[74px] flex-col items-start justify-between rounded-[14px] px-2.5 py-2', dark ? 'text-white' : 'text-[#1C1530]')}
      style={{
        background: dark ? 'linear-gradient(180deg, rgba(255,255,255,.16), rgba(255,255,255,.06))' : 'linear-gradient(180deg, #FFFFFF, #F1EDFA)',
        boxShadow: pressed
          ? `0 1px 0 rgba(28,21,48,.25), inset 0 1px 0 rgba(255,255,255,.9), 0 0 0 1.5px ${P.lilac}, 0 0 26px rgba(185,167,255,.8)`
          : '0 4px 0 rgba(28,21,48,.16), inset 0 1px 0 #fff, 0 0 0 .5px rgba(28,21,48,.14), 0 14px 26px -12px rgba(44,30,90,.45)',
        backdropFilter: 'blur(16px)', WebkitBackdropFilter: 'blur(16px)',
      }}>
      <span className="text-[19px] leading-none">{k}</span>
      <span className="text-[10px] font-medium leading-none opacity-60">{label}</span>
    </motion.div>
  )
}

/** Autoplaying drag → key → wheel → drop loop that cycles through all three wheels. */
export function PrismDemo({ size = 340, className, paused }: { size?: number; className?: string; paused?: boolean }) {
  const reduce = useReducedMotion()
  const [step, setStep] = useState(isShot ? 4 : 0)
  const [loopN, setLoopN] = useState(0)
  const [aim, setAim] = useState<number | null>(isShot ? 0 : null)
  const phase = SCRIPT[step].phase
  const mode = MODES[loopN % 3]

  useEffect(() => {
    if (paused || isShot) return
    const t = setTimeout(() => {
      setStep((s) => {
        if (s === SCRIPT.length - 1) { setLoopN((l) => l + 1); return 0 }
        return s + 1
      })
    }, SCRIPT[step].ms)
    return () => clearTimeout(t)
  }, [step, paused])

  useEffect(() => {
    if (isShot) return
    if (phase !== 'aim') { if (phase !== 'drop') setAim(null); return }
    let i = 0
    setAim(mode.sweep[0])
    const id = setInterval(() => { i = Math.min(i + 1, mode.sweep.length - 1); setAim(mode.sweep[i]) }, SCRIPT[4].ms / mode.sweep.length)
    return () => clearInterval(id)
  }, [phase]) // eslint-disable-line react-hooks/exhaustive-deps

  const open = phase === 'open' || phase === 'aim' || phase === 'drop'
  const lifted = phase !== 'idle' && phase !== 'done'
  const n = mode.segs.length
  const shownAim = phase === 'drop' ? mode.target : aim
  const ang = shownAim != null ? ((shownAim + 0) / n) * Math.PI * 2 : 0
  const rr = size * 0.34
  const px = shownAim != null ? rr * Math.sin(ang) : phase === 'drag' ? -26 : -size * 0.32
  const py = shownAim != null ? -rr * Math.cos(ang) : phase === 'drag' ? 18 : size * 0.26

  return (
    <div className={cn('relative flex items-center justify-center', className)} style={{ width: size + 40, height: size + 40 }}>
      <div className="absolute" style={{ width: size, height: size }}>
        <PrismWheel segments={mode.segs} size={size} open={open} interactive={false} hoverIndex={shownAim}
                    hubLabel={<Hub size={loopN % 3 === 2 ? '1 file' : '18.4 MB'} name="clip.mov" />} />
      </div>
      <motion.div className="absolute z-10" initial={false}
        animate={{ x: reduce ? 0 : px, y: reduce ? 0 : py, scale: phase === 'drop' ? 0.35 : lifted ? 1.06 : 1, opacity: phase === 'drop' || phase === 'done' ? 0 : 1, rotate: lifted ? -5 : 0 }}
        transition={{ type: 'spring', stiffness: 240, damping: 24 }}>
        <FileTile ext="MOV" size={44} />
        <svg className="absolute -bottom-1 right-0 drop-shadow-[0_2px_3px_rgba(0,0,0,.3)]" width="22" height="22" viewBox="0 0 24 24" aria-hidden>
          <path d="M5 3l14 8-6 1.6L10 19z" fill="#fff" stroke={P.plum} strokeWidth="1.4" strokeLinejoin="round" />
        </svg>
      </motion.div>
      <div className="absolute -bottom-2 right-0 z-20">
        <GlassKey k={mode.key} label={mode.name} pressed={phase === 'key' || phase === 'open' || phase === 'aim'} />
      </div>
      <AnimatePresence>
        {phase === 'done' && (
          <motion.div className="absolute left-1/2 top-1/2 z-30" key={loopN}
            initial={{ opacity: 0, y: '-30%', x: '-50%', scale: 0.94, filter: 'blur(6px)' }}
            animate={{ opacity: 1, y: '-50%', x: '-50%', scale: 1, filter: 'blur(0px)' }}
            exit={{ opacity: 0, y: '-70%', x: '-50%', filter: 'blur(6px)' }} transition={{ type: 'spring', stiffness: 300, damping: 26 }}>
            <Toast title={mode.toast[0]} body={mode.toast[1]} className="w-[300px]" />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
