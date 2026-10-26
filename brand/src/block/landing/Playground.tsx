import { AnimatePresence, motion } from 'motion/react'
import { RotateCcw } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { isShot } from '../../shared/kit'
import { BlockWheel, type Wedge } from '../BlockWheel'
import { actionWedges, convertImage, convertVideo, toolWedges } from './data'
import { Scaled } from './Scaled'
import { Display, Eyebrow } from './ui'

const FILES = [
  { name: 'clip.mov', base: 'clip', ext: 'MOV' },
  { name: 'photo.heic', base: 'photo', ext: 'HEIC' },
] as const

const MODES = [
  { key: '⇧', name: 'Shift', code: 'Shift', wheel: 'Convert', panel: 'var(--bk-orange)', hot: 'lilac' as const },
  { key: '⌘', name: 'Command', code: 'Meta', wheel: 'Tools', panel: 'var(--bk-lilac)', hot: 'orange' as const },
  { key: '⌃', name: 'Control', code: 'Control', wheel: 'Actions', panel: 'var(--bk-pink)', hot: 'lilac' as const },
]

type Line = { id: number; key: string; text: string; out?: string }

function result(mode: number, file: (typeof FILES)[number], w: Wedge): Omit<Line, 'id'> {
  const k = MODES[mode].key
  if (mode === 0) return { key: k, text: `${file.name} → ${w.label}`, out: `${file.base}.${w.label.toLowerCase()}` }
  if (mode === 1) return { key: k, text: `${w.label} ${file.name}`, out: `new copy, original untouched` }
  const out: Record<string, string> = {
    AirDrop: 'AirDrop sheet opened', Float: 'on the Float shelf', Copy: 'copied to the clipboard',
    Move: 'moved to a recent folder', 'Copy Path': `~/Desktop/${file.name}`, Terminal: 'Terminal opened in ~/Desktop',
  }
  return { key: k, text: `${w.label} ${file.name}`, out: out[w.label] }
}

const SEED: Line[] = isShot
  ? [
    { id: -3, key: '⇧', text: 'clip.mov → GIF', out: 'clip.gif' },
    { id: -2, key: '⌘', text: 'Crop clip.mov', out: 'new copy, original untouched' },
    { id: -1, key: '⌃', text: 'AirDrop clip.mov', out: 'AirDrop sheet opened' },
  ]
  : []

export function Playground() {
  const [mode, setMode] = useState(0)
  const [held, setHeld] = useState<number | null>(null)
  const [file, setFile] = useState(0)
  const [log, setLog] = useState<Line[]>(SEED)
  const n = useRef(0)

  useEffect(() => {
    const idx = (e: KeyboardEvent) => MODES.findIndex((m) => m.code === e.key)
    const down = (e: KeyboardEvent) => {
      const i = idx(e)
      if (i < 0 || e.repeat) return
      setHeld(i)
      setMode(i)
    }
    const up = (e: KeyboardEvent) => { if (idx(e) >= 0) setHeld(null) }
    const clear = () => setHeld(null)
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    window.addEventListener('blur', clear)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up); window.removeEventListener('blur', clear) }
  }, [])

  const f = FILES[file]
  const m = MODES[mode]
  const wedges = mode === 0 ? (file === 0 ? convertVideo : convertImage) : mode === 1 ? toolWedges : actionWedges
  const pick = (w: Wedge) => setLog((l) => [...l, { id: n.current++, ...result(mode, f, w) }].slice(-6))

  return (
    <section id="play" className="mx-auto max-w-[1440px] scroll-mt-20 px-2 pt-2">
      <div className="grid gap-2 lg:grid-cols-12">
        {/* controls + log */}
        <div className="flex flex-col gap-8 bg-[var(--bk-ink-2)] px-5 py-10 sm:px-10 sm:py-12 lg:col-span-5">
          <div>
            <Eyebrow n="02" className="mb-6 text-[var(--bk-cream)]">Playground</Eyebrow>
            <Display a="Go on," b="hold a key." bColor="var(--bk-lilac)" className="text-[clamp(48px,6vw,92px)] tracking-[-0.06em]" />
            <p className="mt-5 max-w-[420px] text-[17px] leading-[1.5] text-[var(--bk-cream)]/70">
              Press <b className="text-[var(--bk-cream)]">Shift</b>, <b className="text-[var(--bk-cream)]">Command</b> or <b className="text-[var(--bk-cream)]">Control</b> on your keyboard. The wheel switches. Aim at a wedge and click to drop.
            </p>
          </div>

          <div className="grid gap-5">
            <div>
              <div className="bk-mono mb-2.5 text-[11px] uppercase tracking-[0.08em] text-[var(--bk-mute)]">Dragging</div>
              <div className="flex flex-wrap gap-2">
                {FILES.map((x, i) => (
                  <button key={x.name} onClick={() => setFile(i)} aria-pressed={file === i}
                    className="bk-mono flex h-10 items-center gap-2 px-3.5 text-[13px] font-semibold transition-colors"
                    style={{ background: file === i ? 'var(--bk-cream)' : 'var(--bk-ink-3)', color: file === i ? 'var(--bk-ink)' : 'var(--bk-cream)' }}>
                    <span className="px-1 py-px text-[10px]" style={{ background: file === i ? 'var(--bk-orange)' : 'var(--bk-ink)', color: file === i ? 'var(--bk-ink)' : 'var(--bk-mute)' }}>{x.ext}</span>{x.name}
                  </button>
                ))}
              </div>
            </div>
            <div>
              <div className="bk-mono mb-2.5 text-[11px] uppercase tracking-[0.08em] text-[var(--bk-mute)]">Holding <span className="normal-case opacity-70">(or tap)</span></div>
              <div className="flex gap-2.5">
                {MODES.map((x, i) => {
                  const on = mode === i, down = held === i
                  return (
                    <button key={x.code} onClick={() => setMode(i)} aria-pressed={on} aria-label={`${x.name}: ${x.wheel}`}
                      className="flex h-[74px] w-[92px] flex-col items-start justify-between p-2.5 text-left transition-[transform,box-shadow,background] duration-100"
                      style={{
                        background: on ? x.panel : 'var(--bk-ink-3)', color: on ? 'var(--bk-ink)' : 'var(--bk-cream)',
                        boxShadow: down ? '0 0 0 var(--bk-ink)' : `4px 4px 0 ${on ? 'var(--bk-wine)' : 'var(--bk-ink)'}`,
                        transform: down ? 'translate(4px,4px)' : 'none',
                      }}>
                      <span className="bk-display text-[26px] font-bold leading-none">{x.key}</span>
                      <span className="bk-mono text-[10.5px] font-semibold uppercase tracking-[0.04em] opacity-75">{x.wheel}</span>
                    </button>
                  )
                })}
              </div>
            </div>
          </div>

          <div className="mt-auto border-t-4 border-[var(--bk-orange)] bg-[var(--bk-ink)] p-4" aria-live="polite">
            <div className="bk-mono mb-3 flex items-center justify-between text-[11px] uppercase tracking-[0.08em] text-[var(--bk-mute)]">
              <span>Results</span>
              {log.length > 0 && <button onClick={() => setLog([])} className="flex items-center gap-1 hover:text-[var(--bk-cream)]"><RotateCcw size={12} />clear</button>}
            </div>
            <div className="bk-mono min-h-[132px] text-[13px] leading-[1.75]">
              {log.length === 0 && <div className="text-[var(--bk-mute)]">Nothing dropped yet. Aim at a wedge and click.<span className="bkl-caret ml-1 inline-block h-[14px] w-[7px] translate-y-[2px] bg-[var(--bk-orange)]" /></div>}
              <AnimatePresence initial={false}>
                {log.map((l) => (
                  <motion.div key={l.id} initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} className="flex min-w-0 gap-2.5">
                    <span className="text-[var(--bk-orange)]">{l.key}</span>
                    <span className="shrink-0 text-[var(--bk-cream)]">{l.text}</span>
                    {l.out && <span className="truncate text-[var(--bk-mute)]">· {l.out}</span>}
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          </div>
        </div>

        {/* the wheel */}
        <div className="relative flex min-h-[520px] flex-col overflow-hidden transition-[background] duration-300 lg:col-span-7" style={{ background: m.panel }}>
          <div className="relative z-10 flex items-start justify-between p-5 text-[var(--bk-ink)] sm:p-7">
            <Eyebrow className="text-[var(--bk-ink)]" dot="var(--bk-ink)">{m.name} · {m.wheel}</Eyebrow>
            <span className="bk-mono text-[11px] uppercase tracking-[0.08em]">{wedges.length} wedges</span>
          </div>
          <div aria-hidden className="bk-display pointer-events-none absolute -bottom-[0.18em] left-3 font-bold leading-none tracking-[-0.07em] text-[var(--bk-ink)]/[0.08]" style={{ fontSize: 'clamp(96px, 12.5vw, 184px)' }}>{m.wheel}</div>
          <div className="relative flex flex-1 items-center justify-center px-4 pb-10">
            <div className="w-full max-w-[460px]">
              <Scaled width={460} height={460}>
                  <BlockWheel key={`${mode}-${file}`} size={460} wedges={wedges} hot={m.hot} tone="dark" onPick={pick}
                    active={isShot ? 0 : undefined}
                    hub={<span className="flex flex-col items-center gap-1"><span className="bk-display text-[34px] font-bold leading-none">{m.key}</span><span className="bk-mono text-[12px] font-bold">{f.ext}</span></span>} />
              </Scaled>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
