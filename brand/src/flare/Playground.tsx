/**
 * The gesture, for real: press a file, drag, tap Shift (or hold still), the format wheel opens
 * around the pointer, let go on a format and a new copy lands in the output tray.
 * Keyboard: focus a file, Enter opens the wheel, arrows choose, Enter applies, Escape cancels.
 */

import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useEffect, useRef, useState } from 'react'

const EASE = [0.22, 1, 0.36, 1] as const

type Kind = 'video' | 'image' | 'audio' | 'doc'
const FILES: { name: string; ext: string; kind: Kind; size: string }[] = [
  { name: 'clip', ext: 'mov', kind: 'video', size: '48.2 MB' },
  { name: 'IMG_2041', ext: 'heic', kind: 'image', size: '3.4 MB' },
  { name: 'interview', ext: 'm4a', kind: 'audio', size: '22.1 MB' },
  { name: 'notes', ext: 'docx', kind: 'doc', size: '184 KB' },
]
const TARGETS: Record<Kind, string[]> = {
  video: ['GIF', 'MP4', 'WEBM', 'MKV', 'AVI', 'MP3', 'M4A', 'WMV'],
  image: ['JPG', 'PNG', 'WEBP', 'PDF', 'TIFF', 'AVIF', 'GIF', 'BMP'],
  audio: ['MP3', 'WAV', 'FLAC', 'OGG', 'OPUS', 'AIFF'],
  doc: ['PDF', 'MD', 'HTML', 'RTF', 'TXT', 'ODT', 'EPUB'],
}
const R0 = 52, R1 = 132

function FileGlyph({ kind, ext, active }: { kind: Kind; ext: string; active?: boolean }) {
  const tint = { video: '#FF4A14', image: '#FF8A2A', audio: '#E8213A', doc: '#0A0A0A' }[kind]
  return (
    <span className={`relative flex h-[92px] w-[74px] flex-col justify-end rounded-[12px] bg-white p-2 shadow-[0_1px_0_rgba(0,0,0,.04),0_10px_24px_-12px_rgba(0,0,0,.25)] ring-1 ring-black/5 transition-transform duration-300 ${active ? 'scale-95 opacity-40' : ''}`}>
      <span aria-hidden className="absolute right-0 top-0 h-5 w-5 rounded-bl-[8px] rounded-tr-[12px] bg-[#F1EEEA]" />
      <span aria-hidden className="absolute left-2 top-3 flex flex-col gap-1">
        {[30, 22, 26].map((w, i) => <span key={i} className="h-[3px] rounded-full bg-black/10" style={{ width: w }} />)}
      </span>
      <span className="w-fit rounded-[5px] px-1.5 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-white" style={{ background: tint }}>{ext}</span>
    </span>
  )
}

function wedge(i: number, n: number) {
  const gap = 0.025, a0 = (i / n) * Math.PI * 2 - Math.PI / 2 - Math.PI / n + gap, a1 = a0 + (Math.PI * 2) / n - gap * 2
  const p = (r: number, a: number) => `${(Math.cos(a) * r).toFixed(2)},${(Math.sin(a) * r).toFixed(2)}`
  return `M${p(R1, a0)} A${R1},${R1} 0 0 1 ${p(R1, a1)} L${p(R0, a1)} A${R0},${R0} 0 0 0 ${p(R0, a0)} Z`
}

export function Playground() {
  const box = useRef<HTMLDivElement>(null)
  const [drag, setDrag] = useState<{ i: number; x: number; y: number } | null>(null)
  const [wheel, setWheel] = useState<{ x: number; y: number; i: number } | null>(null)
  const [hot, setHot] = useState(-1)
  const wheelRef = useRef<typeof wheel>(null)
  wheelRef.current = wheel
  const [busy, setBusy] = useState<{ x: number; y: number; label: string } | null>(null)
  const [out, setOut] = useState<{ id: number; name: string; kind: Kind; ext: string }[]>([])
  const still = useRef<number>(0)
  const last = useRef({ x: 0, y: 0 })
  const idRef = useRef(0)

  const rel = (e: { clientX: number; clientY: number }) => {
    const r = box.current!.getBoundingClientRect()
    return { x: e.clientX - r.left, y: e.clientY - r.top }
  }
  const clampCenter = (x: number, y: number) => {
    const r = box.current!.getBoundingClientRect()
    return { x: Math.min(Math.max(x, R1 + 8), r.width - R1 - 8), y: Math.min(Math.max(y, R1 + 8), r.height - R1 - 8) }
  }
  const openWheel = useCallback((i: number, x: number, y: number) => {
    clearTimeout(still.current)                          // a pending hold-still must not reopen and reset the aim
    const c = clampCenter(x, y)
    setWheel({ i, ...c })
    setHot(-1)
  }, [])
  const aim = (x: number, y: number, w: { x: number; y: number; i: number }) => {
    const n = TARGETS[FILES[w.i].kind].length
    const dx = x - w.x, dy = y - w.y
    if (Math.hypot(dx, dy) < R0 * 0.6) { setHot(-1); return }
    const a = Math.atan2(dy, dx) + Math.PI / 2 + Math.PI / n
    setHot(Math.floor((((a % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)) / ((Math.PI * 2) / n)))
  }
  const convert = useCallback((i: number, fmt: string, at: { x: number; y: number }) => {
    const f = FILES[i]
    setBusy({ ...at, label: `${f.name}.${f.ext} → ${fmt.toLowerCase()}` })
    window.setTimeout(() => {
      setBusy(null)
      setOut((o) => [{ id: ++idRef.current, name: `${f.name}.${fmt.toLowerCase()}`, kind: f.kind, ext: fmt.toLowerCase() }, ...o].slice(0, 4))
    }, 1100)
  }, [])

  // Shift opens the wheel mid drag, like the app
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Shift' && drag && !wheel) openWheel(drag.i, drag.x, drag.y)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [drag, wheel, openWheel])

  const down = (i: number) => (e: React.PointerEvent) => {
    if (busy) return
    e.preventDefault()
    try { box.current!.setPointerCapture(e.pointerId) } catch { /* pointer already gone: the drag still works without capture */ }
    const p = rel(e)
    last.current = p
    setDrag({ i, ...p })
    setWheel(null)
    clearTimeout(still.current)
    still.current = window.setTimeout(() => setDrag((d) => { if (d && !wheelRef.current) openWheel(d.i, d.x, d.y); return d }), 750)
  }
  const move = (e: React.PointerEvent) => {
    if (!drag) return
    const p = rel(e)
    setDrag({ ...drag, ...p })
    if (wheel) aim(p.x, p.y, wheel)
    else if (Math.hypot(p.x - last.current.x, p.y - last.current.y) > 6) {
      last.current = p
      clearTimeout(still.current)
      still.current = window.setTimeout(() => setDrag((d) => { if (d && !wheelRef.current) openWheel(d.i, d.x, d.y); return d }), 750)
    }
  }
  const up = () => {
    clearTimeout(still.current)
    if (drag && wheel && hot >= 0) convert(drag.i, TARGETS[FILES[drag.i].kind][hot], { x: wheel.x, y: wheel.y })
    setDrag(null)
    setWheel(null)
    setHot(-1)
  }

  // keyboard path
  const keyOn = (i: number) => (e: React.KeyboardEvent<HTMLButtonElement>) => {
    const n = TARGETS[FILES[i].kind].length
    if (!wheel && (e.key === 'Enter' || e.key === ' ')) {
      e.preventDefault()
      const r = e.currentTarget.getBoundingClientRect(), b = box.current!.getBoundingClientRect()
      openWheel(i, r.left - b.left + r.width / 2, r.top - b.top + r.height / 2)
      setHot(0)
    } else if (wheel && wheel.i === i) {
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') { e.preventDefault(); setHot((h) => (h + 1) % n) }
      else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') { e.preventDefault(); setHot((h) => (h - 1 + n) % n) }
      else if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); if (hot >= 0) convert(i, TARGETS[FILES[i].kind][hot], { x: wheel.x, y: wheel.y }); setWheel(null); setHot(-1) }
      else if (e.key === 'Escape') { setWheel(null); setHot(-1) }
    }
  }

  const targets = wheel ? TARGETS[FILES[wheel.i].kind] : []
  const dragging = drag ? FILES[drag.i] : null

  return (
    <div ref={box} onPointerMove={move} onPointerUp={up} onPointerCancel={up}
      className="relative h-[620px] w-full select-none overflow-hidden rounded-[32px] bg-[#F4F2EF] [touch-action:none] md:h-[560px]"
      style={{ backgroundImage: 'radial-gradient(rgba(10,10,10,.07) 1px, transparent 1px)', backgroundSize: '24px 24px' }}>
      {/* desktop files */}
      <div className="absolute left-6 top-6 grid grid-cols-2 gap-x-6 gap-y-5 md:left-10 md:top-10">
        {FILES.map((f, i) => (
          <button key={f.name} type="button" onPointerDown={down(i)} onKeyDown={keyOn(i)}
            aria-label={`${f.name}.${f.ext}, ${f.size}. Press Enter to choose a format.`}
            className="group flex cursor-grab flex-col items-center gap-2 rounded-2xl p-2 outline-none transition-colors duration-300 hover:bg-black/[0.03] focus-visible:ring-2 focus-visible:ring-[#FF4A14] active:cursor-grabbing">
            <FileGlyph kind={f.kind} ext={f.ext} active={drag?.i === i} />
            <span className="text-center text-[13px] font-medium leading-tight text-[#0A0A0A]">{f.name}.{f.ext}<span className="block text-[11px] font-normal text-black/40">{f.size}</span></span>
          </button>
        ))}
      </div>

      {/* output tray */}
      <div className="absolute bottom-6 right-6 w-[220px] rounded-[24px] bg-white/70 p-4 ring-1 ring-black/5 backdrop-blur-md md:right-10 md:top-10 md:bottom-auto md:w-[240px]">
        <p className="text-xs font-medium uppercase tracking-[0.12em] text-black/40">New copies</p>
        <ul className="mt-3 flex min-h-[44px] flex-col gap-2">
          <AnimatePresence initial={false}>
            {out.length === 0 && (
              <motion.li key="empty" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="text-[13px] leading-snug text-black/45">Converted files land here, beside their originals.</motion.li>
            )}
            {out.map((o) => (
              <motion.li key={o.id} layout initial={{ opacity: 0, y: -10, filter: 'blur(6px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0 }}
                transition={{ duration: 0.5, ease: EASE }} className="flex items-center justify-between rounded-xl bg-white px-3 py-2 text-[13px] font-medium text-[#0A0A0A] ring-1 ring-black/5">
                <span className="truncate">{o.name}</span>
                <span className="ml-2 rounded-md bg-[#E4FF3A] px-1.5 py-0.5 text-[10px] font-semibold uppercase">new</span>
              </motion.li>
            ))}
          </AnimatePresence>
        </ul>
      </div>

      {/* hint */}
      <p className="pointer-events-none absolute bottom-6 left-6 max-w-[46%] text-[13px] leading-snug text-black/50 md:left-10 md:max-w-none">
        Press a file and drag. Tap <kbd className="rounded-md bg-white px-1.5 py-0.5 font-sans text-[12px] font-semibold text-black shadow-[0_1px_0_rgba(0,0,0,.12)] ring-1 ring-black/10">⇧ Shift</kbd> or hold still, then let go on a format.
      </p>

      {/* wheel */}
      <AnimatePresence>
        {wheel && (
          <motion.svg key="wheel" width={R1 * 2 + 16} height={R1 * 2 + 16} viewBox={`${-R1 - 8} ${-R1 - 8} ${R1 * 2 + 16} ${R1 * 2 + 16}`}
            className="pointer-events-none absolute z-10" style={{ left: wheel.x - R1 - 8, top: wheel.y - R1 - 8 }}
            initial={{ scale: 0.6, opacity: 0, rotate: -14 }} animate={{ scale: 1, opacity: 1, rotate: 0 }} exit={{ scale: 0.5, opacity: 0, transition: { duration: 0.2 } }}
            transition={{ type: 'spring', stiffness: 420, damping: 28 }}>
            <defs>
              <linearGradient id="hot" x1="0" y1="1" x2="1" y2="0">
                <stop offset="0" stopColor="#E8160C" /><stop offset="0.6" stopColor="#FF4A14" /><stop offset="1" stopColor="#FF9A3C" />
              </linearGradient>
            </defs>
            <circle r={R1 + 6} fill="rgba(255,255,255,.55)" />
            {targets.map((t, i) => {
              const n = targets.length, a = (i / n) * Math.PI * 2 - Math.PI / 2, on = i === hot
              return (
                <motion.g key={t} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.02 }}>
                  <path d={wedge(i, n)} fill={on ? 'url(#hot)' : '#FFFFFF'} stroke={on ? 'none' : 'rgba(10,10,10,.08)'} style={{ transition: 'fill .2s' }} />
                  <text x={Math.cos(a) * ((R0 + R1) / 2)} y={Math.sin(a) * ((R0 + R1) / 2)} textAnchor="middle" dominantBaseline="central"
                    fontSize="14" fontWeight="600" fontFamily="Inter Tight Variable, sans-serif" fill={on ? '#FFFFFF' : '#0A0A0A'}>{t}</text>
                </motion.g>
              )
            })}
            <circle r={R0 - 6} fill="#0A0A0A" />
            <text y="-6" textAnchor="middle" fontSize="10" fill="rgba(255,255,255,.55)" fontFamily="Inter Tight Variable, sans-serif">convert to</text>
            <text y="10" textAnchor="middle" fontSize="13" fontWeight="600" fill="#fff" fontFamily="Inter Tight Variable, sans-serif">{hot >= 0 ? targets[hot] : '…'}</text>
          </motion.svg>
        )}
      </AnimatePresence>

      {/* dragged ghost */}
      {drag && dragging && (
        <div className="pointer-events-none absolute z-20 -translate-x-1/2 -translate-y-[60%]" style={{ left: drag.x, top: drag.y }}>
          <div className="rotate-[-6deg] scale-90 drop-shadow-[0_18px_30px_rgba(0,0,0,.25)]"><FileGlyph kind={dragging.kind} ext={dragging.ext} /></div>
          {!wheel && (
            <motion.span initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} className="mt-2 block whitespace-nowrap rounded-full bg-[#0A0A0A] px-3 py-1 text-center text-[12px] font-medium text-white">Tap ⇧ Shift</motion.span>
          )}
        </div>
      )}

      {/* progress */}
      <AnimatePresence>
        {busy && (
          <motion.div initial={{ opacity: 0, y: 8, filter: 'blur(4px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.35, ease: EASE }}
            className="absolute z-20 w-[240px] -translate-x-1/2 -translate-y-1/2 rounded-2xl bg-[#0A0A0A] p-3 text-white" style={{ left: busy.x, top: busy.y }}>
            <p className="text-[12.5px] font-medium">{busy.label}</p>
            <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-white/15">
              <motion.div className="h-full rounded-full bg-gradient-to-r from-[#E8160C] via-[#FF4A14] to-[#FF9A3C]" initial={{ width: '0%' }} animate={{ width: '100%' }} transition={{ duration: 1, ease: [0.65, 0, 0.35, 1] }} />
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
