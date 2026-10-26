import { AnimatePresence, motion, useReducedMotion, useScroll, useTransform } from 'motion/react'
import { ArrowRight, Check, Download } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { isShot } from '../../shared/kit'
import { product } from '../../shared/product'
import { BlockWheel } from '../BlockWheel'
import { IsoBlock, IsoKeycap, IsoLeftText, IsoScene, type Faces } from '../Iso'
import { Wordmark } from '../Mark'
import { heroWedges, NAV } from './data'
import { Scaled } from './Scaled'
import { Cursor, Eyebrow, FileTile, Jump } from './ui'

/* ───────────────────────── Nav ───────────────────────── */

export function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b border-[var(--bk-line)] bg-[var(--bk-ink)]/92 backdrop-blur-md">
      <div className="mx-auto flex h-[68px] max-w-[1440px] items-center justify-between gap-6 px-4 sm:px-6">
        <Jump to="#top" className="shrink-0" ><Wordmark size={22} /></Jump>
        <nav className="hidden items-center gap-1 lg:flex">
          {NAV.map((l) => (
            <Jump key={l.href} to={l.href} className="rounded-[4px] px-3 py-2 text-[14.5px] font-medium text-[var(--bk-cream)]/70 transition-colors hover:bg-[var(--bk-ink-3)] hover:text-[var(--bk-cream)]">{l.label}</Jump>
          ))}
        </nav>
        <div className="flex items-center gap-3">
          <span className="bk-mono hidden text-[11px] uppercase tracking-[0.06em] text-[var(--bk-mute)] xl:inline">macOS 13+ · Apple silicon</span>
          <a href="#" onClick={(e) => e.preventDefault()} className="bk-btn bk-btn-cream h-[42px] px-4 text-[15px]"><Download size={16} strokeWidth={2.4} />Download</a>
        </div>
      </div>
    </header>
  )
}

/* ───────────────────────── Demo ───────────────────────── */

const W = 760, H = 540
const START = { x: 92, y: 118 } // file tile top-left
const P = { x: 430, y: 292 } // where the key is pressed (wheel centre)
const WHEEL = 300
const AIM = { x: P.x, y: P.y - WHEEL / 2 * 0.65 } // GIF wedge, straight up
const SHOT_AIM = { x: P.x - 4, y: P.y - (P.y - AIM.y) * 0.8 }

// rest → drag → press → open → aim → drop
const DUR = [900, 1150, 380, 520, 1050, 2600]
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

function Demo() {
  const phase = useLoop()
  const frozen = isShot
  const pointer = phase === 0 ? { x: START.x + 52, y: START.y + 58 }
    : phase === 4 ? (frozen ? SHOT_AIM : AIM)
      : phase === 5 ? AIM
        : P
  const dragging = phase >= 1 && phase <= 4
  const keyDown = phase >= 2 && phase <= 4
  const wheelOpen = phase === 3 || phase === 4
  const ease = [0.65, 0, 0.35, 1] as const
  const move = phase === 1 ? { duration: 1.0, ease } : phase === 4 ? { duration: 0.75, ease } : phase === 0 ? { duration: 0.5, ease } : { duration: 0.2 }
  const step = stepOf(phase)

  return (
    <div className="relative select-none overflow-hidden" style={{ width: W, height: H }} aria-label="Demo: a file is dragged, Shift opens the wheel, the pointer drops on GIF" role="img">
      {/* dot-matrix ground */}
      <div className="absolute inset-0" style={{ backgroundImage: 'radial-gradient(#3A3A42 1.3px, transparent 1.6px)', backgroundSize: '16px 16px' }} />
      <div className="absolute inset-0" style={{ background: 'radial-gradient(60% 55% at 57% 54%, transparent 0%, rgba(28,28,33,.0) 40%, var(--bk-ink-2) 100%)' }} />

      {/* steps */}
      <div className="absolute left-1/2 top-5 flex -translate-x-1/2 gap-1.5">
        {STEPS.map((s, i) => (
          <span key={s} className="bk-mono flex h-7 items-center gap-1.5 px-2.5 text-[11px] font-semibold uppercase tracking-[0.05em] transition-colors duration-200"
            style={{ background: i === step ? 'var(--bk-orange)' : 'var(--bk-ink-3)', color: i === step ? 'var(--bk-ink)' : 'var(--bk-mute)' }}>
            <span className="opacity-60">0{i + 1}</span>{s}
          </span>
        ))}
      </div>
      
      {/* the ghost of where the file came from */}
      <div className="absolute border-2 border-dashed border-[var(--bk-ink-3)]" style={{ left: START.x - 10, top: START.y - 10, width: 112, height: 150, opacity: dragging ? 1 : 0, transition: 'opacity .2s' }} />

      {/* keycap */}
      <div className="absolute" style={{ left: 52, top: 352, width: 210 }}>
        <IsoScene width={210} height={170} unit={92} anchor={[0.5, 0.42]}>
          {(ctx) => (<>
            <IsoBlock ctx={ctx} x={-0.75} y={-0.75} z={-0.12} w={1.5} d={1.5} h={0.12} material="wine" />
            <IsoKeycap ctx={ctx} x={-0.5} y={-0.5} legend="⇧" sub="shift" material="orange" pressed={keyDown} />
          </>)}
        </IsoScene>
      </div>
      <AnimatePresence>
        {keyDown && (
          <motion.div className="absolute flex h-9 items-center gap-2 rounded-full bg-[var(--bk-cream)] pl-3 pr-4 text-[14px] font-semibold text-[var(--bk-ink)]"
            style={{ left: 218, top: 412 }}
            initial={frozen ? false : { opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -8 }} transition={{ duration: 0.18 }}>
            <span className="flex gap-[3px]">{[0, 1, 2].map((i) => <span key={i} className="size-[5px] rounded-full bg-[var(--bk-orange)]" style={{ opacity: 0.4 + i * 0.3 }} />)}</span>
            Shift held · Convert
          </motion.div>
        )}
      </AnimatePresence>

      {/* wheel */}
      <div className="pointer-events-none absolute" style={{ left: P.x - WHEEL / 2, top: P.y - WHEEL / 2, width: WHEEL, height: WHEEL }}>
        <BlockWheel size={WHEEL} wedges={heroWedges} open={wheelOpen} active={phase === 4 ? 0 : null}
          hub={<span className="bk-mono text-[13px] font-bold">MOV</span>} />
      </div>

      {/* the result landing */}
      <AnimatePresence>
        {phase === 5 && (
          <motion.div className="absolute" style={{ left: P.x - 44, top: P.y - 40 }}
            initial={{ opacity: 0, scale: 0.5, y: -30 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, transition: { duration: 0.2 } }}
            transition={{ type: 'spring', stiffness: 420, damping: 20 }}>
            <FileTile name="clip.gif" ext="GIF" tone="orange" size={80} />
          </motion.div>
        )}
      </AnimatePresence>

      {/* the dragged file */}
      <motion.div className="absolute left-0 top-0"
        animate={{
          x: dragging ? pointer.x + 20 : START.x, y: dragging ? pointer.y + 4 : START.y,
          scale: dragging ? 0.46 : 1, opacity: phase === 5 ? 0 : dragging ? 0.92 : 1,
        }}
        initial={false}
        transition={phase === 5 ? { duration: 0.15 } : phase === 0 ? { duration: 0, opacity: { duration: 0.35 } } : move}
        style={{ transformOrigin: '0 0' }}>
        <FileTile name="clip.mov" ext="MOV" />
      </motion.div>

      {/* pointer */}
      <motion.div className="absolute left-0 top-0 z-10" initial={false} animate={{ x: pointer.x - 3, y: pointer.y - 2 }} transition={move}>
        <Cursor />
      </motion.div>

      {/* toast */}
      <AnimatePresence>
        {phase === 5 && (
          <motion.div className="absolute flex items-center gap-3 border-l-4 border-[var(--bk-orange)] bg-[var(--bk-ink)] py-3 pl-3 pr-5 shadow-[6px_6px_0_var(--bk-orange)]"
            style={{ right: 56, bottom: 30 }}
            initial={{ opacity: 0, y: 24 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 12 }} transition={{ type: 'spring', stiffness: 380, damping: 26, delay: 0.25 }}>
            <span className="grid size-9 place-items-center bg-[var(--bk-orange)] text-[var(--bk-ink)]"><Check size={20} strokeWidth={3} /></span>
            <span>
              <span className="block text-[15px] font-semibold text-[var(--bk-cream)]">clip.gif is ready</span>
              <span className="bk-mono block text-[11px] text-[var(--bk-mute)]">4.1 MB · saved next to clip.mov</span>
            </span>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

/* ───────────────────────── Hero ───────────────────────── */

const SLAB: Faces = { top: 'stripe:pink:top', left: '#FF6B1A', right: '#D9500A' }
const SLAB_HOT: Faces = { top: '#FFFFFF', left: '#F4F1EC', right: '#DEDAD3' }

const STEP_ROWS: [string, Faces, string][] = [
  ['Drag it', SLAB, '#0E0E10'],
  ['Press it', { top: 'stripe:lilac:top', left: '#0E0E10', right: '#1C1C21' }, '#F4F1EC'],
  ['Drop it', SLAB_HOT, '#0E0E10'],
]
function StepStack() {
  // Each slab steps back (−y) so the label on every front face stays visible, like stairs.
  return (
    <IsoScene width={440} height={420} unit={60} anchor={[0.5, 0.7]} title="Drag it, press it, drop it">
      {(ctx) => STEP_ROWS.map(([label, faces, ink], i) => {
        const x = -2.1 + (i === 1 ? 0.35 : 0), y = -0.6 - i * 0.62, z = i * 0.9
        return (
          <g key={label}>
            <IsoBlock ctx={ctx} x={x} y={y} z={z} w={3.6} d={1.9} h={0.9} material={faces} />
            <IsoLeftText ctx={ctx} x={x + 0.3} y={y + 1.9} z={z + 0.27} size={27} fill={ink}>{label}</IsoLeftText>
          </g>
        )
      })}
    </IsoScene>
  )
}

function Pyramid() {
  return (
    <IsoScene width={300} height={240} unit={34} anchor={[0.5, 0.72]}>
      {(ctx) => (<>
        <IsoBlock ctx={ctx} x={-2.5} y={-2.5} z={0} w={5} d={5} h={0.6} material="stripeLilac" />
        <IsoBlock ctx={ctx} x={-1.8} y={-1.8} z={0.6} w={3.6} d={3.6} h={0.6} material="ink" />
        <IsoBlock ctx={ctx} x={-1.1} y={-1.1} z={1.2} w={2.2} d={2.2} h={0.6} material="stripeLilac" />
        <IsoBlock ctx={ctx} x={-0.45} y={-0.45} z={1.8} w={0.9} d={0.9} h={0.9} material="cream" />
      </>)}
    </IsoScene>
  )
}

export function Hero() {
  const ref = useRef<HTMLElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const lift = useTransform(scrollYProgress, [0, 1], [0, isShot || reduce ? 0 : -90])
  const sink = useTransform(scrollYProgress, [0, 1], [0, isShot || reduce ? 0 : 60])

  return (
    <section id="top" ref={ref} className="mx-auto max-w-[1440px] p-2">
      <div className="grid gap-2 lg:grid-cols-12">
        {/* headline */}
        <div className="relative overflow-hidden bg-[var(--bk-cream)] px-5 pb-8 pt-10 text-[var(--bk-ink)] sm:px-10 sm:pb-12 sm:pt-14 lg:col-span-8">
          <Eyebrow n="anyfmt.app" className="text-[var(--bk-ink)]">Open source · free forever</Eyebrow>
          <h1 className="bk-display mt-7 font-semibold leading-[0.84] tracking-[-0.06em]" style={{ fontSize: 'clamp(60px, 10.6vw, 158px)' }}>
            <span className="block">Any file,</span>
            <span className="block text-[var(--bk-orange)]">any format.</span>
          </h1>
          <div className="mt-8 flex flex-col gap-7 sm:mt-10 md:flex-row md:items-end md:justify-between">
            <p className="max-w-[440px] text-[18px] leading-[1.45] text-[var(--bk-ink)]/75 sm:text-[19px]">
              Drag a file. Press a key. A wheel of everything it can become opens around your pointer. <b className="font-semibold text-[var(--bk-ink)]">Drop.</b>
            </p>
            <div className="flex flex-wrap gap-3">
              <a href="#" onClick={(e) => e.preventDefault()} className="bk-btn bk-btn-orange h-[54px] px-6 text-[17px]"><Download size={18} strokeWidth={2.4} />Download for Mac</a>
              <Jump to="#play" className="bk-btn bk-btn-line h-[54px] px-5 text-[17px]">Try the wheel<ArrowRight size={18} /></Jump>
            </div>
          </div>
        </div>

        {/* labelled stack */}
        <div className="relative flex min-h-[340px] flex-col justify-between overflow-hidden bg-[var(--bk-lilac)] p-5 text-[var(--bk-ink)] sm:p-7 lg:col-span-4">
          <div className="flex items-start justify-between">
            <Eyebrow className="text-[var(--bk-ink)]" dot="var(--bk-ink)">How it works</Eyebrow>
            <span className="bk-mono text-[11px] uppercase">3 moves</span>
          </div>
          <motion.div style={{ y: lift }} className="mx-auto w-full max-w-[400px]"><StepStack /></motion.div>
        </div>

        {/* demo stage */}
        <div className="relative overflow-hidden bg-[var(--bk-ink-2)] lg:col-span-8">
          <Scaled width={W} height={H} max={1.3} min={0.6}><Demo /></Scaled>
        </div>

        {/* side column */}
        <div className="grid gap-2 sm:grid-cols-2 lg:col-span-4 lg:grid-cols-1">
          <div className="relative flex flex-col justify-between overflow-hidden bg-[var(--bk-orange)] p-5 text-[var(--bk-ink)] sm:p-7">
            <Eyebrow className="text-[var(--bk-ink)]" dot="var(--bk-ink)">Convert</Eyebrow>
            <div className="mt-6">
              <div className="bk-display font-semibold leading-[0.8] tracking-[-0.07em]" style={{ fontSize: 'clamp(88px, 9vw, 132px)' }}>793<span className="text-[var(--bk-wine-2)]">.</span></div>
              <p className="mt-3 max-w-[260px] text-[15.5px] font-medium leading-snug">{product.stats[0].label}. Images, video, audio, documents, ebooks, archives.</p>
            </div>
          </div>
          <div className="relative flex min-h-[260px] flex-col justify-between overflow-hidden bg-[var(--bk-wine)] p-5 sm:p-7">
            <div className="relative z-10 flex items-start justify-between gap-3">
              <Eyebrow className="text-[var(--bk-cream)]" dot="var(--bk-pink)">Local only</Eyebrow>
              <span className="bk-mono text-right text-[11px] uppercase text-[var(--bk-pink)]">0 network calls</span>
            </div>
            <motion.div style={{ y: sink }} className="absolute inset-x-0 bottom-[-18px] mx-auto w-[300px] max-w-full"><Pyramid /></motion.div>
          </div>
        </div>
      </div>
    </section>
  )
}
