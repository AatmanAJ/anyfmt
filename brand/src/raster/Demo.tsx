import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import { C, Dither, DotIcon, reducedMotion, useInView } from './kit'
import { ASSETS } from './assets'

/** The real gesture, replayed: drag clip.mov, tap Shift, the format wheel opens around the pointer,
 *  drop on GIF, a new copy lands beside the original. Drawn on a fixed 880×520 stage that scales. */

const W = 880, H = 520
const DROP = { x: 470, y: 270 }
const FORMATS = ['GIF', 'MP4', 'WEBM', 'MKV', 'AVI', 'M4A', 'MP3', 'WMV']
const PICK = 0
type Phase = 'idle' | 'reach' | 'drag' | 'shift' | 'wheel' | 'aim' | 'drop' | 'done'
const TIMELINE: [Phase, number][] = [['idle', 0], ['reach', 500], ['drag', 1300], ['shift', 2200], ['wheel', 2450], ['aim', 3150], ['drop', 3900], ['done', 5500]]
const LOOP = 8200

const wedge = (i: number, n: number, r0: number, r1: number) => {
  const gap = 0.035, a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap, a1 = a0 + (Math.PI * 2) / n - gap * 2
  const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(2)},${(Math.sin(a) * r).toFixed(2)}`
  return `M${p(r1, a0)} A${r1},${r1} 0 0 1 ${p(r1, a1)} L${p(r0, a1)} A${r0},${r0} 0 0 0 ${p(r0, a0)} Z`
}
const mid = (i: number, n: number, r: number) => {
  const a = (i / n) * Math.PI * 2 - Math.PI / 2
  return { x: Math.cos(a) * r, y: Math.sin(a) * r }
}

function Cursor({ pressed }: { pressed: boolean }) {
  return (
    <svg width="22" height="28" viewBox="0 0 22 28" style={{ transform: `scale(${pressed ? 0.9 : 1})`, transformOrigin: '2px 2px', transition: 'transform .15s' }}>
      <path d="M2 2 L2 22 L7.5 17 L11 25 L14.5 23.5 L11 15.8 L18 15.8 Z" fill="#fff" stroke="#000" strokeWidth="1.4" strokeLinejoin="round" />
    </svg>
  )
}

function FileTile({ name, asset, label }: { name: string; asset: keyof typeof ASSETS; label?: string }) {
  const a = ASSETS[asset]
  return (
    <div className="flex w-[104px] flex-col items-center gap-2">
      <div className="flex h-[78px] w-[92px] items-center justify-center">
        <Dither src={a.src} alt="" ratio={a.ratio} pixel={2} levels={4} interactive={false} style={{ height: 70 }} />
      </div>
      <span className="rounded px-1.5 py-0.5 font-mono text-[11.5px] text-white/85">{name}</span>
      {label && <span className="-mt-1 font-mono text-[10px] uppercase tracking-[0.1em] text-[#FF5A1F]">{label}</span>}
    </div>
  )
}

export function AppDemo({ className }: { className?: string }) {
  const box = useRef<HTMLDivElement>(null)
  const inView = useInView(box, '0px')
  const [scale, setScale] = useState(1)
  const [phase, setPhase] = useState<Phase>('idle')
  const [progress, setProgress] = useState(0)

  useEffect(() => {
    const el = box.current
    if (!el) return
    const fit = () => setScale(el.offsetWidth / W)
    fit()
    const ro = new ResizeObserver(fit)
    ro.observe(el)
    window.addEventListener('resize', fit)
    return () => { ro.disconnect(); window.removeEventListener('resize', fit) }
  }, [])

  useEffect(() => {
    if (!inView) return
    if (reducedMotion()) { setPhase('done'); setProgress(1); return }
    let timers: number[] = []
    const cycle = () => {
      setProgress(0)
      timers = TIMELINE.map(([p, t]) => window.setTimeout(() => setPhase(p), t))
      timers.push(window.setTimeout(cycle, LOOP))
    }
    cycle()
    return () => timers.forEach(clearTimeout)
  }, [inView])

  useEffect(() => {
    if (phase !== 'drop') return
    let raf = 0
    const start = performance.now()
    const tick = (now: number) => {
      const k = Math.min(1, (now - start) / 1300)
      setProgress(1 - (1 - k) ** 2)
      if (k < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [phase])

  const order: Phase[] = ['idle', 'reach', 'drag', 'shift', 'wheel', 'aim', 'drop', 'done']
  const at = (p: Phase) => order.indexOf(phase) >= order.indexOf(p)
  const aimPt = mid(PICK, FORMATS.length, 92)
  const cursor =
    phase === 'idle' ? { x: 720, y: 430 }
      : phase === 'reach' ? { x: 112, y: 140 }
        : phase === 'aim' || phase === 'drop' ? { x: DROP.x + aimPt.x, y: DROP.y + aimPt.y }
          : phase === 'done' ? { x: 640, y: 400 }
            : DROP
  const dragging = at('drag') && !at('drop')
  const wheelOpen = at('wheel') && !at('drop')

  return (
    <div ref={box} className={className} style={{ aspectRatio: `${W} / ${H}`, position: 'relative', overflow: 'hidden', borderRadius: 8 }}>
      <div className="absolute left-0 top-0 origin-top-left overflow-hidden rounded-lg bg-[#141414] ring-1 ring-inset ring-[#1E1E1E]" style={{ width: W, height: H, transform: `scale(${scale})` }}>
        {/* title bar */}
        <div className="flex h-10 items-center gap-2 border-b border-[#1E1E1E] px-4">
          {[0, 1, 2].map((i) => <span key={i} className="h-3 w-3 rounded-full bg-[#313131]" />)}
          <span className="ml-3 font-mono text-[11.5px] uppercase tracking-[0.12em] text-[#7C7C7C]">~/Desktop</span>
          <span className="ml-auto flex items-center gap-2 font-mono text-[11px] text-[#7C7C7C]">
            <span className={`inline-flex h-6 min-w-[52px] items-center justify-center gap-1 rounded-[5px] px-2 ring-1 transition-colors duration-150 ${phase === 'shift' || phase === 'wheel' ? 'bg-white text-black ring-white' : 'text-white/60 ring-[#313131]'}`}>
              <DotIcon name="shift" size={10} />shift
            </span>
            <span className="inline-flex h-6 items-center rounded-[5px] px-2 ring-1 ring-[#313131]">⌘</span>
            <span className="inline-flex h-6 items-center rounded-[5px] px-2 ring-1 ring-[#313131]">ctrl</span>
          </span>
        </div>

        {/* desktop */}
        <div className="absolute inset-x-0 bottom-0 top-10" style={{ backgroundImage: `radial-gradient(${C.iron} 1px, transparent 1px)`, backgroundSize: '22px 22px' }} />
        <div className="absolute left-[60px] top-[80px] flex flex-col gap-6">
          <motion.div animate={{ opacity: dragging ? 0.35 : 1 }}><FileTile name="clip.mov" asset="film" /></motion.div>
          <AnimatePresence>
            {at('done') && (
              <motion.div initial={{ opacity: 0, y: -14, scale: 0.9 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0 }} transition={{ type: 'spring', stiffness: 380, damping: 26 }}>
                <FileTile name="clip.gif" asset="film" label="new copy" />
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        <div className="absolute right-[64px] top-[80px] flex flex-col gap-6">
          <FileTile name="IMG_2041.heic" asset="photo" />
          <FileTile name="Invoices" asset="folder" />
        </div>

        {/* wheel */}
        <AnimatePresence>
          {wheelOpen && (
            <motion.svg key="wheel" width={300} height={300} viewBox="-150 -150 300 300" className="absolute"
              style={{ left: DROP.x - 150, top: DROP.y - 150 }}
              initial={{ scale: 0.55, opacity: 0, rotate: -12 }} animate={{ scale: 1, opacity: 1, rotate: 0 }}
              exit={{ scale: 0.4, opacity: 0, transition: { duration: 0.22 } }} transition={{ type: 'spring', stiffness: 420, damping: 30 }}>
              <circle r={140} fill="rgba(10,10,10,.85)" stroke="rgba(255,90,31,.45)" strokeDasharray="2 5" />
              {FORMATS.map((f, i) => {
                const hot = i === PICK && phase === 'aim'
                const m = mid(i, FORMATS.length, 96)
                return (
                  <g key={f}>
                    <motion.path d={wedge(i, FORMATS.length, 56, 132)} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.025 }}
                      fill={hot ? C.accent : '#2A2A2A'} stroke={hot ? C.accent : '#4F4F4F'} strokeWidth={1} />
                    <text x={m.x} y={m.y} textAnchor="middle" dominantBaseline="central" fontFamily="JetBrains Mono Variable, monospace" fontSize={13} fontWeight={500} fill={hot ? '#000' : '#fff'}>{f}</text>
                  </g>
                )
              })}
              <circle r={48} fill={C.card} stroke={C.edge} />
              <text y={-6} textAnchor="middle" fontFamily="JetBrains Mono Variable, monospace" fontSize={10} fill={C.mist}>CONVERT</text>
              <text y={10} textAnchor="middle" fontFamily="Inter Variable, sans-serif" fontSize={13} fontWeight={600} fill="#fff">clip.mov</text>
            </motion.svg>
          )}
        </AnimatePresence>

        {/* progress */}
        <AnimatePresence>
          {phase === 'drop' && (
            <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }}
              className="absolute w-[240px] rounded-lg bg-[#1E1E1E] p-3 ring-1 ring-[#313131]" style={{ left: DROP.x - 120, top: DROP.y - 34 }}>
              <div className="flex items-center justify-between font-mono text-[11.5px]"><span className="text-white">clip.mov → clip.gif</span><span className="text-[#A7A7A7]">{Math.round(progress * 100)}%</span></div>
              <div className="mt-2.5 flex gap-[2px]">
                {Array.from({ length: 30 }, (_, i) => <span key={i} className="h-2 flex-1 rounded-[1px]" style={{ background: i / 30 < progress ? C.accent : C.edge }} />)}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* dragged ghost + cursor */}
        <motion.div className="pointer-events-none absolute left-0 top-0 z-10" animate={{ x: cursor.x, y: cursor.y }}
          transition={{ type: 'spring', stiffness: phase === 'reach' ? 70 : 90, damping: 18, mass: 1 }}>
          <AnimatePresence>
            {dragging && (
              <motion.div initial={{ opacity: 0, scale: 0.8 }} animate={{ opacity: 0.9, scale: 1 }} exit={{ opacity: 0, scale: 0.6 }}
                className="absolute -left-6 -top-5 flex h-9 items-center gap-1.5 rounded-md bg-white/95 px-2 font-mono text-[11px] text-black shadow-[0_8px_24px_-8px_rgba(0,0,0,.8)]">
                <DotIcon name="play" size={9} />clip.mov
              </motion.div>
            )}
          </AnimatePresence>
          <Cursor pressed={dragging} />
        </motion.div>

        {/* caption */}
        <div className="absolute inset-x-0 bottom-0 flex h-11 items-center justify-between border-t border-[#1E1E1E] bg-[#141414] px-4 font-mono text-[11px] uppercase tracking-[0.12em]">
          <span className="text-[#7C7C7C]">
            {phase === 'idle' || phase === 'reach' ? '01 · pick up a file' : phase === 'drag' ? '02 · drag it anywhere' : phase === 'shift' || phase === 'wheel' ? '03 · tap shift' : phase === 'aim' ? '04 · aim at a format' : phase === 'drop' ? '05 · let go' : '06 · new copy, original untouched'}
          </span>
          <span className="flex items-center gap-1.5 text-[#7C7C7C]"><DotIcon name="lock" size={9} />on this mac</span>
        </div>
      </div>
    </div>
  )
}
