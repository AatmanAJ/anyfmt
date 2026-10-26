import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useState, type ReactNode } from 'react'
import { Wheel, type WheelSegment, type WheelSkin } from './Wheel'
import { cn } from './cn'

export type DemoPhase = 'idle' | 'drag' | 'key' | 'open' | 'aim' | 'drop' | 'done'

type Props = {
  segments: readonly WheelSegment[]
  skin: WheelSkin
  /** Index the demo drops on. */
  target: number
  /** Indexes the pointer sweeps across before landing (sticky aim, so a few). */
  sweep?: number[]
  size?: number
  className?: string
  hubLabel?: ReactNode
  hubSub?: ReactNode
  /** The dragged file (style it per direction). */
  renderFile: (phase: DemoPhase) => ReactNode
  /** The key being pressed (shown during key/open/aim). */
  renderKey?: (pressed: boolean) => ReactNode
  /** Result toast after the drop. */
  renderToast?: () => ReactNode
  /** Cursor colour. */
  cursor?: string
  loop?: boolean
  /** Pause the loop (e.g. off screen). */
  paused?: boolean
}

const SCRIPT: { phase: DemoPhase; ms: number }[] = [
  { phase: 'idle', ms: 900 },
  { phase: 'drag', ms: 700 },
  { phase: 'key', ms: 380 },
  { phase: 'open', ms: 420 },
  { phase: 'aim', ms: 1500 },
  { phase: 'drop', ms: 380 },
  { phase: 'done', ms: 2200 },
]

export function DragDemo({
  segments, skin, target, sweep, size = 340, className, hubLabel, hubSub, renderFile, renderKey, renderToast,
  cursor = '#fff', loop = true, paused,
}: Props) {
  const reduce = useReducedMotion()
  const [step, setStep] = useState(0)
  const [aimIdx, setAimIdx] = useState<number | null>(null)
  const phase = SCRIPT[step].phase
  const path = sweep ?? [target]

  useEffect(() => {
    if (paused) return
    const t = setTimeout(() => {
      if (step === SCRIPT.length - 1 && !loop) return
      setStep((s) => (s + 1) % SCRIPT.length)
    }, SCRIPT[step].ms)
    return () => clearTimeout(t)
  }, [step, loop, paused])

  useEffect(() => {
    if (phase !== 'aim') { if (phase !== 'drop') setAimIdx(null); return }
    let i = 0
    setAimIdx(path[0])
    const each = SCRIPT[4].ms / path.length
    const id = setInterval(() => { i = Math.min(i + 1, path.length - 1); setAimIdx(path[i]) }, each)
    return () => clearInterval(id)
  }, [phase]) // eslint-disable-line react-hooks/exhaustive-deps

  const wheelOpen = phase === 'open' || phase === 'aim' || phase === 'drop'
  const lifted = phase !== 'idle' && phase !== 'done'
  // Pointer: centre, then out toward the aimed wedge.
  const n = segments.length
  const aimAngle = aimIdx != null ? (aimIdx / n) * Math.PI * 2 : 0
  const rAim = size * 0.33
  const px = aimIdx != null ? rAim * Math.sin(aimAngle) : phase === 'drag' ? -18 : 0
  const py = aimIdx != null ? -rAim * Math.cos(aimAngle) : phase === 'drag' ? 10 : 0

  return (
    <div className={cn('relative flex items-center justify-center', className)} style={{ minHeight: size + 40 }}>
      <div className="absolute" style={{ width: size, height: size }}>
        <Wheel segments={segments} skin={skin} size={size} open={wheelOpen} interactive={false}
               hoverIndex={phase === 'drop' ? target : aimIdx} hubLabel={hubLabel} hubSub={hubSub} />
      </div>

      {/* The file + cursor travel together. */}
      <motion.div
        className="absolute z-10"
        animate={{ x: reduce ? 0 : px, y: reduce ? 0 : py, scale: phase === 'drop' ? 0.4 : lifted ? 1.04 : 1,
                   opacity: phase === 'drop' ? 0 : phase === 'done' ? 0 : 1 }}
        transition={{ type: 'spring', stiffness: 260, damping: 24 }}
      >
        <div className={cn('transition-transform', lifted && 'rotate-[-4deg]')}>{renderFile(phase)}</div>
        <svg className="absolute -bottom-3 -right-3 drop-shadow" width="22" height="22" viewBox="0 0 24 24" aria-hidden>
          <path d="M5 3l14 8-6 1.6L10 19z" fill={cursor} stroke="rgba(0,0,0,.6)" strokeWidth="1.2" strokeLinejoin="round" />
        </svg>
      </motion.div>

      {renderKey && (
        <div className="absolute bottom-0 right-2 z-20">
          {renderKey(phase === 'key' || phase === 'open' || phase === 'aim')}
        </div>
      )}

      <AnimatePresence>
        {phase === 'done' && renderToast && (
          <motion.div className="absolute left-1/2 top-1/2 z-30"
            initial={{ opacity: 0, y: 14, x: '-50%', scale: 0.96 }} animate={{ opacity: 1, y: '-50%', x: '-50%', scale: 1 }}
            exit={{ opacity: 0, y: '-60%', x: '-50%' }} transition={{ type: 'spring', stiffness: 300, damping: 26 }}>
            {renderToast()}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
