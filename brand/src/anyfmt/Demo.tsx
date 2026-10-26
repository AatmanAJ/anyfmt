import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useState } from 'react'
import { isShot } from '../shared/kit'
import { AnyWheel } from './AnyWheel'
import { convertWedges } from './copy'
import { AppIcon, Mark } from './Mark'

type Phase = 'idle' | 'drag' | 'key' | 'open' | 'aim' | 'drop' | 'done'
const SCRIPT: { p: Phase; ms: number }[] = [
  { p: 'idle', ms: 900 }, { p: 'drag', ms: 900 }, { p: 'key', ms: 350 }, { p: 'open', ms: 450 },
  { p: 'aim', ms: 1500 }, { p: 'drop', ms: 350 }, { p: 'done', ms: 2400 },
]
const SWEEP = [2, 1, 0]
const TARGET = 0

/** A document tile with a video thumbnail, as it looks on the desktop. */
export function FileTile({ name = 'clip.mov', ext = 'MOV', small }: { name?: string; ext?: string; small?: boolean }) {
  const w = small ? 46 : 64
  return (
    <div className="flex flex-col items-center gap-1.5">
      <div className="relative overflow-hidden rounded-[8px] bg-white" style={{ width: w, height: w * 1.22, boxShadow: '0 0 0 1px rgba(17,17,17,.08), 0 10px 22px -8px rgba(90,30,0,.45)' }}>
        <div className="absolute inset-[5px] bottom-[16px] rounded-[4px]" style={{ background: 'linear-gradient(160deg,#FFC08A,#EA7C25 55%,#8E2E0B)' }}>
          <div className="absolute bottom-[18%] left-[12%] h-[32%] w-[46%] rounded-full bg-white/35 blur-[3px]" />
        </div>
        <span className="af-mono absolute bottom-[3px] left-1/2 -translate-x-1/2 text-[8px] font-bold text-[#B4570F]">{ext}</span>
      </div>
      {!small && <span className="rounded-[5px] bg-[#2F6BE0] px-1.5 py-[1px] text-[11px] font-medium text-white">{name}</span>}
    </div>
  )
}

function Cursor() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden className="drop-shadow-[0_2px_3px_rgba(0,0,0,.35)]">
      <path d="M5 3l14 8-6 1.6L10 19z" fill="#111" stroke="#fff" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  )
}

/** The hero demo: a macOS desktop where a file is dragged, Shift is pressed and the wheel converts it. */
export function DesktopDemo({ wheel = 360 }: { wheel?: number }) {
  const [step, setStep] = useState(isShot ? 4 : 0)
  const [aim, setAim] = useState<number | null>(isShot ? TARGET : null)
  const phase = SCRIPT[step].p

  useEffect(() => {
    if (isShot) return
    const t = setTimeout(() => setStep((s) => (s + 1) % SCRIPT.length), SCRIPT[step].ms)
    return () => clearTimeout(t)
  }, [step])

  useEffect(() => {
    if (isShot) return
    if (phase !== 'aim') { if (phase !== 'drop') setAim(null); return }
    let i = 0
    setAim(SWEEP[0])
    const id = setInterval(() => { i = Math.min(i + 1, SWEEP.length - 1); setAim(SWEEP[i]) }, SCRIPT[4].ms / SWEEP.length)
    return () => clearInterval(id)
  }, [phase])

  const open = phase === 'open' || phase === 'aim' || phase === 'drop'
  const pressed = phase === 'key' || open
  const carrying = phase !== 'idle' && phase !== 'done'
  const n = convertWedges.length
  const a = aim != null ? (aim / n) * Math.PI * 2 : 0
  const rr = wheel * 0.34
  const fx = phase === 'idle' || phase === 'done' ? -wheel * 0.95 : aim != null ? rr * Math.sin(a) : 0
  const fy = phase === 'idle' || phase === 'done' ? wheel * 0.05 : aim != null ? -rr * Math.cos(a) : 0

  return (
    <div className="relative h-full w-full overflow-hidden">
      {/* wallpaper */}
      <div className="absolute inset-0" style={{ background: 'radial-gradient(80% 70% at 30% 20%, #FFD9B5 0%, transparent 60%), radial-gradient(70% 80% at 90% 90%, #F29A55 0%, transparent 60%), linear-gradient(160deg,#FCE6D2,#F7C79C 55%,#EE9B5C)' }} />
      <svg className="absolute inset-0 h-full w-full opacity-70" viewBox="0 0 800 500" preserveAspectRatio="none" aria-hidden>
        <defs><filter id="dsb"><feGaussianBlur stdDeviation="14" /></filter></defs>
        <path d="M-50 420 C 200 300, 380 520, 860 160" stroke="#fff" strokeWidth="60" fill="none" opacity=".45" filter="url(#dsb)" />
        <path d="M-40 120 C 240 40, 520 260, 860 60" stroke="#fff" strokeWidth="26" fill="none" opacity=".35" filter="url(#dsb)" />
      </svg>

      {/* menu bar */}
      <div className="absolute inset-x-0 top-0 z-30 flex h-7 items-center justify-between bg-white/45 px-4 text-[12px] font-medium text-[#111] backdrop-blur-xl">
        <div className="flex items-center gap-4"><span className="font-semibold">Finder</span><span className="hidden opacity-70 sm:inline">File</span><span className="hidden opacity-70 sm:inline">Edit</span><span className="hidden opacity-70 sm:inline">View</span></div>
        <div className="flex items-center gap-3"><Mark size={15} variant="mono" /><span className="opacity-80">Mon 9:41</span></div>
      </div>

      {/* stage centre */}
      <div className="absolute left-1/2 top-[54%] -translate-x-1/2 -translate-y-1/2" style={{ width: wheel, height: wheel }}>
        <AnyWheel wedges={convertWedges} size={wheel} open={open} active={phase === 'drop' ? TARGET : aim}
          hub={<span className="text-[12px] font-semibold leading-tight text-[#111]">MOV<br /><span className="af-mono text-[9px] font-normal text-[#8C8884]">48 MB</span></span>} />
        <motion.div className="absolute left-1/2 top-1/2 z-10"
          initial={false}
          animate={{ x: fx - 32, y: fy - 40, scale: phase === 'drop' ? 0.35 : carrying ? 0.82 : 1, opacity: phase === 'drop' ? 0 : 1, rotate: carrying ? -5 : 0 }}
          transition={isShot ? { duration: 0 } : { type: 'spring', stiffness: 220, damping: 24 }}>
          <FileTile />
          <div className="absolute -bottom-1 right-1"><Cursor /></div>
        </motion.div>
      </div>

      {/* key */}
      <div className="absolute bottom-5 right-5 z-20 flex items-center gap-2">
        <AnimatePresence>{pressed && <motion.span initial={{ opacity: 0, x: 6 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0 }} className="rounded-full bg-white/70 px-2.5 py-1 text-[11px] font-medium text-[#55524F] backdrop-blur">Convert</motion.span>}</AnimatePresence>
        <motion.div className="af-key" animate={{ y: pressed ? 3 : 0, boxShadow: pressed ? 'inset 0 1px 0 #fff, inset 0 -1px 0 #E2E0DC, 0 0 0 1px #E5701E, 0 2px 4px -2px rgba(17,17,17,.3)' : 'inset 0 1px 0 #fff, inset 0 -3px 0 #E2E0DC, 0 0 0 1px #D9D6D2, 0 6px 14px -6px rgba(17,17,17,.3)' }}
          transition={{ type: 'spring', stiffness: 700, damping: 30 }}>
          <span className="text-[18px] leading-none" style={{ color: pressed ? '#E5701E' : '#111' }}>⇧</span>
          <span className="text-[10px] font-medium text-[#8C8884]">shift</span>
        </motion.div>
      </div>

      {/* result notification */}
      <AnimatePresence>
        {phase === 'done' && (
          <motion.div className="absolute right-4 top-10 z-30 flex w-[min(300px,80%)] items-center gap-3 rounded-[16px] bg-white/80 p-3 pr-4 backdrop-blur-xl"
            style={{ boxShadow: '0 0 0 1px rgba(17,17,17,.06), 0 18px 40px -16px rgba(90,30,0,.45)' }}
            initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 40 }} transition={{ type: 'spring', stiffness: 300, damping: 28 }}>
            <AppIcon size={36} />
            <div className="min-w-0 text-[12px] leading-snug">
              <div className="font-semibold text-[#111]">clip.gif is ready</div>
              <div className="truncate text-[#55524F]">4.1 MB · saved next to clip.mov</div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
