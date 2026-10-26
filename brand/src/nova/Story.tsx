import { MeshGradient } from '@paper-design/shaders-react'
import { AnimatePresence, motion, useMotionValueEvent, useScroll, useSpring, useTransform } from 'motion/react'
import { Check } from 'lucide-react'
import { useRef, useState } from 'react'
import { isShot } from '../shared/kit'
import { NovaWheel } from './fx/NovaWheel'

const WEDGES = ['GIF', 'MP4', 'WEBM', 'M4V', 'MKV', 'MP3', 'WAV', 'PNG'].map((f) => ({ id: f, label: f }))
const STEPS = [
  { n: '01', t: 'Drag', d: 'Pick up any file, anywhere: Finder, the desktop, Mail, Photos.' },
  { n: '02', t: 'Tap ⇧', d: 'The wheel blooms around your pointer, mid-drag. 43 ms.' },
  { n: '03', t: 'Aim', d: 'Every format the file can become, one flick away. Sticky, forgiving.' },
  { n: '04', t: 'Drop', d: 'A new file lands next to the original. Nothing is overwritten.' },
]

export function FileIcon({ ext, tone = 'ember', size = 56 }: { ext: string; tone?: 'ember' | 'ion'; size?: number }) {
  return (
    <div className="relative" style={{ width: size, height: size * 1.22 }}>
      <svg viewBox="0 0 50 61" width={size} height={size * 1.22} aria-hidden>
        <defs><linearGradient id={`fi-${ext}`} x1="0" x2="0" y1="0" y2="1"><stop offset="0" stopColor="#2a2a36" /><stop offset="1" stopColor="#15151d" /></linearGradient></defs>
        <path d="M5 1h28l16 16v39a4 4 0 0 1-4 4H5a4 4 0 0 1-4-4V5a4 4 0 0 1 4-4z" fill={`url(#fi-${ext})`} stroke="rgba(255,255,255,.14)" />
        <path d="M33 1v12a4 4 0 0 0 4 4h12" fill="none" stroke="rgba(255,255,255,.14)" />
      </svg>
      <span className="nv-mono absolute bottom-[14%] left-1/2 -translate-x-1/2 rounded-[4px] px-1.5 py-[1px] text-[9px] font-semibold text-black"
        style={{ background: tone === 'ion' ? 'var(--nv-ion)' : 'var(--nv-molten)' }}>{ext}</span>
    </div>
  )
}

export function Story() {
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress: p } = useScroll({ target: ref, offset: ['start start', 'end end'] })
  const { scrollYProgress: enter } = useScroll({ target: ref, offset: ['start end', 'start start'] })
  const tilt = useTransform(enter, [0, 1], [24, 0])
  const scaleIn = useTransform(enter, [0, 1], [0.86, 1])
  const sp = useSpring(p, { stiffness: 120, damping: 24 })

  // Continuous: the file's path across the desktop.
  const fx = useTransform(sp, [0, 0.2, 0.42, 0.7, 0.8], ['-34%', '0%', '0%', '17%', '17%'])
  const fy = useTransform(sp, [0, 0.2, 0.42, 0.7, 0.8], ['22%', '0%', '0%', '-16%', '-16%'])
  const fs = useTransform(sp, [0, 0.2, 0.72, 0.8], [1, 0.9, 0.8, 0.15])
  const fo = useTransform(sp, [0.76, 0.82], [1, 0])

  const [state, setState] = useState(isShot ? { step: 2, open: 1, aim: 0, done: false } : { step: 0, open: 0, aim: null as number | null, done: false })
  useMotionValueEvent(sp, 'change', (v) => {
    const step = v < 0.2 ? 0 : v < 0.42 ? 1 : v < 0.72 ? 2 : 3
    const open = v < 0.24 ? 0 : v < 0.8 ? Math.min(1, (v - 0.24) / 0.12) : Math.max(0, 1 - (v - 0.8) / 0.06)
    const aimSweep = [3, 2, 1, 0]
    const aim = v < 0.42 ? null : v < 0.72 ? aimSweep[Math.min(3, Math.floor(((v - 0.42) / 0.3) * 4))] : 0
    const done = v > 0.84
    setState((s) => (s.step === step && Math.abs(s.open - open) < 0.01 && s.aim === aim && s.done === done ? s : { step, open, aim, done }))
  })

  return (
    <section ref={ref} id="story" className="relative" style={{ height: isShot ? 'auto' : '360vh' }}>
      <div className={isShot ? 'relative py-24' : 'sticky top-0 flex h-screen items-center overflow-hidden'}>
        <div className="mx-auto grid w-full max-w-[1240px] items-center gap-10 px-5 sm:px-8 lg:grid-cols-[0.8fr_1.2fr]">
          <div>
            <div className="nv-mono mb-5 text-[12px] uppercase text-[var(--nv-ember)]">How it works</div>
            <h2 className="nv-display text-[clamp(40px,5.2vw,76px)]">One gesture.<br /><span className="text-[var(--nv-dim)]">Every format.</span></h2>
            <ol className="mt-10 space-y-2">
              {STEPS.map((s, i) => {
                const on = state.step === i
                return (
                  <li key={s.n} className="relative overflow-hidden rounded-[16px] p-4 pl-5 transition-colors duration-300" style={{ background: on ? 'rgba(255,255,255,.045)' : 'transparent' }}>
                    {on && <motion.span layoutId="nv-step" className="absolute inset-y-3 left-0 w-[3px] rounded-full [background:var(--nv-molten)]" transition={{ type: 'spring', stiffness: 400, damping: 34 }} />}
                    <div className="flex items-baseline gap-4">
                      <span className={`nv-mono text-[12px] transition-colors ${on ? 'text-[var(--nv-ember)]' : 'text-[var(--nv-dim)]'}`}>{s.n}</span>
                      <div>
                        <div className={`nv-display text-[24px] transition-colors ${on ? 'text-[var(--nv-text)]' : 'text-[var(--nv-dim)]'}`}>{s.t}</div>
                        <AnimatePresence initial={false}>
                          {on && <motion.p initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="max-w-[340px] overflow-hidden pt-1 text-[15px] leading-relaxed text-[var(--nv-mute)]">{s.d}</motion.p>}
                        </AnimatePresence>
                      </div>
                    </div>
                  </li>
                )
              })}
            </ol>
          </div>

          <div style={{ perspective: 1600 }}>
            <motion.div style={{ rotateX: isShot ? 0 : tilt, scale: isShot ? 1 : scaleIn, transformOrigin: '50% 100%' }}
              className="relative overflow-hidden rounded-[20px] bg-[var(--nv-ink-1)] shadow-[0_0_0_1px_var(--nv-line-2),0_60px_120px_-40px_rgba(255,90,31,.35),0_30px_80px_-30px_rgba(0,0,0,.9)]">
              <div className="flex h-9 items-center gap-2 border-b border-white/[.06] bg-white/[.03] px-4">
                {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}
                <span className="nv-mono ml-3 text-[11px] text-[var(--nv-dim)]">~/Desktop</span>
              </div>
              <div className="relative aspect-[16/11]">
                <MeshGradient className="absolute inset-0 h-full w-full" colors={['#08080c', '#2b0c18', '#3d1507', '#0a0a12']} distortion={0.8} swirl={0.4} speed={isShot ? 0 : 0.25} />
                <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,transparent,rgba(5,5,7,.6))]" />
                {/* Original file stays at its spot. */}
                <div className="absolute left-[8%] top-[10%] flex flex-col items-center gap-1.5 opacity-60">
                  <FileIcon ext="MOV" /><span className="nv-mono text-[10px] text-white/70">clip.mov</span>
                </div>
                {/* Result. */}
                <AnimatePresence>
                  {state.done && (
                    <motion.div initial={{ opacity: 0, scale: 0.6, y: 10 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ type: 'spring', stiffness: 380, damping: 22 }}
                      className="absolute left-[8%] top-[42%] flex flex-col items-center gap-1.5">
                      <FileIcon ext="GIF" tone="ion" /><span className="nv-mono text-[10px] text-white">clip.gif</span>
                    </motion.div>
                  )}
                </AnimatePresence>
                {/* Wheel. */}
                <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
                  <NovaWheel wedges={WEDGES} size={320} open={state.open} active={state.aim} hub={<span className="nv-mono text-[11px] text-white/80">MOV</span>} />
                </div>
                {/* Dragged file + pointer. */}
                <motion.div className="absolute left-1/2 top-1/2 z-10" style={{ x: fx, y: fy, scale: fs, opacity: fo, translateX: '-50%', translateY: '-50%' }}>
                  <div className="rotate-[-6deg] drop-shadow-[0_20px_30px_rgba(0,0,0,.6)]"><FileIcon ext="MOV" /></div>
                  <svg className="absolute -bottom-3 -right-4" width="22" height="22" viewBox="0 0 24 24" aria-hidden><path d="M5 3l14 8-6 1.6L10 19z" fill="#fff" stroke="#000" strokeWidth="1.2" strokeLinejoin="round" /></svg>
                </motion.div>
                {/* Key. */}
                <div className="absolute bottom-5 right-5 flex items-center gap-2">
                  <AnimatePresence>{state.step >= 1 && state.step < 3 && <motion.span initial={{ opacity: 0, x: 8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0 }} className="nv-mono rounded-full bg-black/50 px-2.5 py-1 text-[10.5px] text-white/80 backdrop-blur">Convert</motion.span>}</AnimatePresence>
                  <motion.div animate={{ y: state.step === 1 || state.step === 2 ? 3 : 0 }}
                    className="grid h-12 w-14 place-items-center rounded-[10px] text-[18px] transition-[background,box-shadow,color] duration-200"
                    style={state.step === 1 || state.step === 2
                      ? { background: 'var(--nv-molten)', color: '#170803', boxShadow: '0 0 30px -4px rgba(255,90,31,.9)' }
                      : { background: 'linear-gradient(180deg,#24242f,#16161e)', color: '#fff', boxShadow: 'inset 0 1px 0 rgba(255,255,255,.12), inset 0 -3px 0 rgba(0,0,0,.5)' }}>⇧</motion.div>
                </div>
                {/* Toast. */}
                <AnimatePresence>
                  {state.done && (
                    <motion.div initial={{ opacity: 0, y: -14, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0 }}
                      className="absolute right-4 top-4 flex items-center gap-3 rounded-[14px] bg-[rgba(16,16,24,.85)] p-2.5 pr-4 shadow-[inset_0_0_0_1px_var(--nv-line-2)] backdrop-blur-xl">
                      <span className="grid size-8 place-items-center rounded-[9px] text-black [background:var(--nv-molten)]"><Check size={16} strokeWidth={3} /></span>
                      <div className="text-[12.5px] leading-tight"><div className="font-medium text-white">clip.gif is ready</div><div className="text-[var(--nv-mute)]">4.1 MB · next to clip.mov</div></div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </motion.div>
            {!isShot && (
              <div className="mx-auto mt-5 h-[3px] w-48 overflow-hidden rounded-full bg-white/[.08]">
                <motion.div className="h-full origin-left [background:var(--nv-molten)]" style={{ scaleX: sp }} />
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  )
}
