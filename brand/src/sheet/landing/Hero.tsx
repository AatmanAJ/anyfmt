import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { ArrowDown, Check, Download } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { isShot } from '../../shared/kit'
import { Pixels, Wordmark } from '../Mark'
import { SheetWheel } from '../SheetWheel'
import { NAV, convertVideo } from './data'
import { buildScene, SCENE_PALETTE } from './scene'
import './landing.css'
import { Eyebrow, FileIcon, Jump, Pointer, Scaled, Window } from './ui'

/* ───────────────────────── Nav ───────────────────────── */

export function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b border-black/10 bg-white">
      <div className="mx-auto flex h-[60px] max-w-[1232px] items-center justify-between gap-6 px-4 sm:px-6">
        <Jump to="#top" className="shrink-0"><Wordmark size={21} /></Jump>
        <nav className="hidden items-center gap-7 md:flex" aria-label="Sections">
          {NAV.map((l) => <Jump key={l.href} to={l.href} className="text-[15px] text-black hover:underline hover:underline-offset-4">{l.label}</Jump>)}
        </nav>
        <div className="flex items-center gap-4">
          <a href="#/sheet/book" className="sh-link hidden text-[15px] lg:inline">Brand book</a>
          <Jump to="#pricing" className="sh-btn sh-btn-ink h-[34px] px-[18px] text-[15px]"><Download size={15} strokeWidth={2} />Download</Jump>
        </div>
      </div>
    </header>
  )
}

/* ───────────────────────── Demo ───────────────────────── */

const DW = 680, DH = 440 // window
const BODY_H = DH - 30
const FILE = { x: 44, y: 34 } // clip.mov icon, top-left
const OUT = { x: 140, y: 34 } // where clip.gif lands, next to the original
const P = { x: 410, y: 196 } // pointer where Shift is pressed: the wheel's centre
const WHEEL = 264
const AIM = { x: P.x + 2, y: P.y - (WHEEL / 2) * 0.66 } // the GIF wedge, straight up
const SHOT_AIM = { x: P.x + 10, y: P.y - (P.y - AIM.y) * 0.58 }
const REST = { x: FILE.x + 34, y: FILE.y + 40 }

// rest, drag, press, open, aim, drop
const DUR = [1000, 1150, 380, 520, 1000, 2700]
type Phase = 0 | 1 | 2 | 3 | 4 | 5

function useLoop(): Phase {
  const reduce = useReducedMotion()
  const frozen = isShot || !!reduce
  const [phase, setPhase] = useState<Phase>(frozen ? 4 : 0)
  useEffect(() => {
    if (frozen) return
    const t = setTimeout(() => setPhase((p) => ((p + 1) % 6) as Phase), DUR[phase])
    return () => clearTimeout(t)
  }, [phase, frozen])
  return phase
}

const STEPS = ['Drag', 'Press ⇧', 'Aim', 'Drop']
const stepOf = (p: Phase) => (p <= 1 ? 0 : p <= 3 ? 1 : p === 4 ? 2 : 3)

const DESKTOP = [
  { name: 'clip.mov', ext: 'MOV', ...FILE },
  { name: 'photo.heic', ext: 'HEIC', x: 44, y: 150 },
  { name: 'notes.pdf', ext: 'PDF', x: 44, y: 266 },
]

function Label({ children, hot }: { children: string; hot?: boolean }) {
  return <span className={`sh-code mt-1.5 block w-[76px] -translate-x-[10px] text-center text-[11px] ${hot ? 'text-black' : 'text-black/80'}`}>{children}</span>
}

function Demo() {
  const phase = useLoop()
  const reduce = useReducedMotion()
  const frozen = isShot || !!reduce
  const dragging = phase >= 1 && phase <= 4
  const keyDown = phase >= 2 && phase <= 4
  const wheelOpen = phase === 3 || phase === 4
  const at = phase === 0 ? REST : phase === 4 ? (frozen ? SHOT_AIM : AIM) : phase === 5 ? AIM : P
  const ease = [0.65, 0, 0.35, 1] as const
  const move = phase === 1 ? { duration: 1.0, ease } : phase === 4 ? { duration: 0.7, ease } : phase === 0 ? { duration: 0 } : { duration: 0.2 }
  const step = stepOf(phase)

  return (
    <Window title="Desktop — anyfmt" className="select-none" style={{ width: DW, height: DH }}>
      <div className="relative overflow-hidden" style={{ height: BODY_H }} role="img"
        aria-label="Demo: clip.mov is dragged, Shift opens the Convert wheel, the file drops on GIF and clip.gif is ready.">
        <div className="sh-dots absolute inset-0 opacity-40" />

        {/* desktop files */}
        {DESKTOP.map((f, i) => (
          <div key={f.name} className="absolute" style={{ left: f.x, top: f.y, opacity: i === 0 && dragging ? 0.35 : 1, transition: 'opacity .2s' }}>
            <FileIcon ext={f.ext} size={52} />
            <Label>{f.name}</Label>
          </div>
        ))}

        {/* the result, next to the original */}
        <AnimatePresence>
          {phase === 5 && (
            <motion.div key="out" className="absolute" style={{ left: OUT.x, top: OUT.y }}
              initial={{ opacity: 0, scale: 0.6, y: -8 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, transition: { duration: 0.25 } }}
              transition={{ type: 'spring', stiffness: 420, damping: 24, delay: 0.1 }}>
              <FileIcon ext="GIF" size={52} hot />
              <Label hot>clip.gif</Label>
            </motion.div>
          )}
        </AnimatePresence>

        {/* wheel */}
        <div className="pointer-events-none absolute" style={{ left: P.x - WHEEL / 2, top: P.y - WHEEL / 2, width: WHEEL, height: WHEEL }}>
          <SheetWheel size={WHEEL} wedges={convertVideo} open={wheelOpen} active={phase === 4 ? 0 : null}
            hub={<span className="flex flex-col items-center leading-none"><span className="sh-display text-[22px]">⇧</span><span className="sh-mono mt-1 text-[10px]">MOV</span></span>} />
        </div>

        {/* toast */}
        <AnimatePresence>
          {phase === 5 && (
            <motion.div key="toast" className="absolute right-4 top-4 flex w-[238px] items-start gap-3 rounded-[4px] bg-white p-3"
              style={{ boxShadow: 'inset 0 0 0 1px #000' }}
              initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6, transition: { duration: 0.2 } }}
              transition={{ duration: 0.28, ease: [0.16, 1, 0.3, 1], delay: 0.25 }}>
              <span className="mt-0.5 grid size-5 shrink-0 place-items-center rounded-full bg-black text-white"><Check size={12} strokeWidth={2.5} /></span>
              <span className="min-w-0">
                <span className="block text-[14px] font-medium leading-tight">clip.gif is ready</span>
                <span className="mt-1 block text-[12.5px] leading-snug text-[var(--sh-graphite)]">Saved next to clip.mov. The original is untouched.</span>
              </span>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Shift key */}
        <div className="absolute bottom-4 right-4 flex items-center gap-2.5">
          <AnimatePresence>
            {keyDown && (
              <motion.span key="held" className="sh-mono text-[11px]" initial={frozen ? false : { opacity: 0, x: 6 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0 }}>
                Shift held · Convert
              </motion.span>
            )}
          </AnimatePresence>
          <div className="flex h-[46px] w-[76px] flex-col justify-between rounded-[4px] px-2 py-1.5 transition-colors duration-100"
            style={{ background: keyDown ? '#000' : '#fff', color: keyDown ? '#fff' : '#000', boxShadow: 'inset 0 0 0 1px #000', transform: keyDown ? 'translateY(1px)' : 'none' }}>
            <span className="text-[15px] leading-none">⇧</span>
            <span className="sh-code text-[10px] leading-none">shift</span>
          </div>
        </div>

        {/* steps */}
        <div className="absolute bottom-4 left-4 flex gap-px rounded-[4px] bg-black p-px">
          {STEPS.map((s, i) => (
            <span key={s} className="sh-mono flex h-[26px] items-center gap-1.5 rounded-[3px] px-2 text-[10.5px] transition-colors duration-150"
              style={{ background: i === step ? '#000' : '#fff', color: i === step ? '#fff' : '#000' }}>
              <span className="opacity-50">0{i + 1}</span>{s}
            </span>
          ))}
        </div>

        {/* pointer + the dragged copy */}
        <motion.div className="absolute left-0 top-0 z-10" initial={false} animate={{ x: at.x, y: at.y }} transition={move}>
          <AnimatePresence>
            {dragging && phase !== 5 && (
              <motion.div key="ghost" className="absolute left-[12px] top-[14px] origin-top-left" initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 0.9, scale: 0.72 }} exit={{ opacity: 0, transition: { duration: 0.12 } }}>
                <FileIcon ext="MOV" size={52} />
              </motion.div>
            )}
          </AnimatePresence>
          <Pointer size={15} />
        </motion.div>
      </div>
    </Window>
  )
}

/* ───────────────────────── Hero ───────────────────────── */

export function Hero() {
  const rows = useMemo(buildScene, [])
  return (
    <section id="top" className="sh-dots relative overflow-hidden bg-[var(--sh-mist)]">
      <div className="mx-auto max-w-[1232px] px-4 pt-14 sm:px-6 sm:pt-20">
        <div className="flex flex-wrap items-center gap-3">
          <span className="sh-tag sh-mono bg-white/60 text-[12px]">AGPL-3.0</span>
          <Eyebrow>Open source · a menu-bar app for macOS</Eyebrow>
        </div>
        <div className="relative">
          <h1 className="sh-display-xl shl-xl mt-7 text-[clamp(60px,16.5vw,184px)]">
            Any file,<br /><span className="sh-hl">mid-drag.</span>
          </h1>
          <div className="mt-8 max-w-[440px] lg:absolute lg:bottom-[0.4em] lg:right-0 lg:mt-0 lg:w-[360px]">
            <p className="text-[17px] leading-[1.5] text-[var(--sh-graphite)] sm:text-[18px]">
              Drag a file in Finder and press a key. A wheel of everything that file can become opens around your pointer. Drop.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Jump to="#pricing" className="sh-btn sh-btn-ink"><Download size={16} strokeWidth={2} />Download for Mac</Jump>
              <Jump to="#demo" className="sh-btn sh-btn-ghost">See it work<ArrowDown size={15} strokeWidth={1.75} /></Jump>
            </div>
            <div className="sh-mono mt-5 text-[12px] text-[var(--sh-graphite)]">macOS 13+ · Apple silicon · Free</div>
          </div>
        </div>
      </div>

      {/* stage: pixel landscape, the window resting in it */}
      <div id="demo" className="relative mt-12 scroll-mt-16 lg:mt-16">
        <div className="relative h-[360px] overflow-hidden lg:h-[576px]" aria-hidden>
          <div className="absolute top-0 left-[calc(50%-400px)] w-[1300px] lg:left-[calc(50%-1040px)] lg:w-[2080px]">
            <Pixels rows={rows} palette={SCENE_PALETTE} px={8} style={{ width: '100%', maxWidth: 'none' }} />
          </div>
        </div>
        <div className="relative -mt-[80px] bg-[linear-gradient(transparent_80px,#000_80px)] px-4 pb-10 sm:px-6 lg:absolute lg:inset-x-0 lg:top-[36px] lg:mt-0 lg:bg-none lg:p-0">
          <div className="mx-auto max-w-[1232px] lg:px-6">
            <div className="mx-auto max-w-[680px] lg:mr-0">
              <Scaled width={DW} height={DH}><Demo /></Scaled>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
