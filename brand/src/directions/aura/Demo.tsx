// The autoplaying drag → key → wheel → drop loop, in Aura's materials.
// Adapted from shared/DragDemo.tsx to drive AuraWheel; in ?shot mode it freezes on the aimed wheel.
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useState } from 'react'
import { isShot } from '../../shared/kit'
import { AuraWheel, type AuraSegment, type WheelTone } from './AuraWheel'
import { AuraKey, PaperFile } from './ui'
import { Check } from 'lucide-react'

type Phase = 'idle' | 'drag' | 'key' | 'open' | 'aim' | 'drop' | 'done'
const SCRIPT: { phase: Phase; ms: number }[] = [
  { phase: 'idle', ms: 1000 }, { phase: 'drag', ms: 750 }, { phase: 'key', ms: 380 }, { phase: 'open', ms: 450 },
  { phase: 'aim', ms: 1700 }, { phase: 'drop', ms: 380 }, { phase: 'done', ms: 2300 },
]

export function AuraDemo({
  segments, target, sweep, size = 420, tone = 'apricot', keySym = '⇧', keyLabel = 'shift', file = { ext: 'MOV', name: 'clip.mov' },
  hub = 'Convert', result = { name: 'clip.gif', meta: '2.4 MB · saved next to clip.mov' }, paused,
}: {
  segments: readonly AuraSegment[]; target: number; sweep?: number[]; size?: number; tone?: WheelTone
  keySym?: string; keyLabel?: string; file?: { ext: string; name: string }; hub?: string
  result?: { name: string; meta: string }; paused?: boolean
}) {
  const reduce = useReducedMotion()
  const [step, setStep] = useState(isShot ? 4 : 0)
  const [aim, setAim] = useState<number | null>(isShot ? target : null)
  const phase = SCRIPT[step].phase
  const path = sweep ?? [target]

  useEffect(() => {
    if (isShot || paused) return
    const t = setTimeout(() => setStep((s) => (s + 1) % SCRIPT.length), SCRIPT[step].ms)
    return () => clearTimeout(t)
  }, [step, paused])

  useEffect(() => {
    if (isShot) return
    if (phase !== 'aim') { if (phase !== 'drop') setAim(null); return }
    let i = 0
    setAim(path[0])
    const id = setInterval(() => { i = Math.min(i + 1, path.length - 1); setAim(path[i]) }, SCRIPT[4].ms / path.length)
    return () => clearInterval(id)
  }, [phase]) // eslint-disable-line react-hooks/exhaustive-deps

  const open = phase === 'open' || phase === 'aim' || phase === 'drop'
  const lifted = phase !== 'idle' && phase !== 'done'
  const n = segments.length
  const a = aim != null ? (aim / n) * Math.PI * 2 : 0
  const rAim = size * 0.34
  const px = aim != null ? rAim * Math.sin(a) : phase === 'drag' ? -26 : -10
  const py = aim != null ? -rAim * Math.cos(a) : phase === 'drag' ? 16 : 30

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <div className="absolute inset-0">
        <AuraWheel segments={segments} size={size} open={open} interactive={false} tone={tone}
          hoverIndex={phase === 'drop' ? target : aim}
          hubLabel={<span className="aura-serif text-[13px] font-medium italic text-[#5B524A]">{hub}</span>}
          hubSub={<span className="mt-0.5 text-[11px] font-semibold text-[#1E1B18]">{file.name}</span>} />
      </div>

      <motion.div className="absolute z-10" initial={false}
        animate={{ x: reduce ? 0 : px, y: reduce ? 0 : py, scale: phase === 'drop' ? 0.35 : lifted ? 1.06 : 1, opacity: phase === 'drop' || phase === 'done' ? 0 : 1, rotate: lifted ? -5 : 0 }}
        transition={{ type: 'spring', stiffness: 240, damping: 24 }}>
        <PaperFile ext={file.ext} size={52} />
        <svg className="absolute -bottom-2 -right-3" width="24" height="24" viewBox="0 0 24 24" aria-hidden style={{ filter: 'drop-shadow(0 2px 3px rgba(0,0,0,.25))' }}>
          <path d="M5 3l14 8-6 1.6L10 19z" fill="#1E1B18" stroke="#fff" strokeWidth="1.4" strokeLinejoin="round" />
        </svg>
      </motion.div>

      <div className="absolute -bottom-2 right-0 z-20 sm:right-2">
        <AuraKey symbol={keySym} label={keyLabel} pressed={phase === 'key' || phase === 'open' || phase === 'aim'} />
      </div>

      <AnimatePresence>
        {phase === 'done' && (
          <motion.div className="absolute left-1/2 top-1/2 z-30"
            initial={{ opacity: 0, y: 14, x: '-50%', scale: 0.96 }} animate={{ opacity: 1, y: '-50%', x: '-50%', scale: 1 }}
            exit={{ opacity: 0, y: '-70%', x: '-50%' }} transition={{ type: 'spring', stiffness: 300, damping: 26 }}>
            <DoneToast name={result.name} meta={result.meta} />
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

export function DoneToast({ name, meta, action = 'Show in Finder' }: { name: string; meta: string; action?: string }) {
  return (
    <div className="aura-frost flex w-max items-center gap-3 rounded-full py-2 pl-2 pr-4">
      <span className="relative grid size-9 place-items-center rounded-full bg-gradient-to-br from-[#FFD2AE] to-[#FFA868] text-[#1E1B18] shadow-[0_0_18px_rgba(255,160,100,.6)]">
        <Check size={17} strokeWidth={2.6} />
      </span>
      <span className="flex flex-col leading-tight">
        <span className="text-[13.5px] font-semibold text-[#1E1B18]">{name} is ready</span>
        <span className="text-[11.5px] text-[#5B524A]">{meta}</span>
      </span>
      {action && <span className="ml-2 rounded-full bg-[#1E1B18]/[.06] px-2.5 py-1 text-[11.5px] font-semibold text-[#1E1B18]">{action}</span>}
    </div>
  )
}
