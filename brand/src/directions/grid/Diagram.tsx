import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { geom, hit, RATIO, SETS, WheelG } from './GridWheel'
import { C, EASE, Mono, SwissKey, useMedia } from './ui'

const WHEELS = [
  { key: '⇧', name: 'Shift', wheel: 'Convert', set: SETS.convert, file: 'clip.mov', sub: '8 FORMATS', run: (t: string) => `clip.mov → clip.${t.toLowerCase()}` },
  { key: '⌘', name: 'Command', wheel: 'Tools', set: SETS.tools, file: 'photo.heic', sub: '8 TOOLS', run: (t: string) => `${t} photo.heic → new copy` },
  { key: '⌃', name: 'Control', wheel: 'Actions', set: SETS.actions, file: 'report.pdf', sub: '6 ACTIONS', run: (t: string) => `${t} report.pdf` },
] as const

const W = 1200, H = 720, CX = 600, CY = 372, R = 268
const mono = { fontFamily: '"JetBrains Mono Variable", monospace' }
const grot = { fontFamily: '"Space Grotesk Variable", sans-serif' }

/** Fig. 02 — the wheel, annotated like a technical drawing. Point at it. Press ⇧ ⌘ ⌃. */
export function Diagram({ dark = false }: { dark?: boolean }) {
  const md = useMedia('(min-width: 900px)')
  const [w, setW] = useState(0)
  const [hover, setHover] = useState<number | null>(isShot ? 2 : null)
  const [done, setDone] = useState<string | null>(null)
  const ref = useRef<SVGSVGElement>(null)
  const wh = WHEELS[w]
  const n = wh.set.length
  const act = hover ?? 2 % n
  const { mid, step } = geom(n)
  const r0 = R * RATIO.inner
  const fg = dark ? C.sheet : C.ink
  const dim = dark ? '#8E8E87' : C.ink2

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === 'Shift') setW(0)
      else if (e.key === 'Meta') setW(1)
      else if (e.key === 'Control') setW(2)
    }
    window.addEventListener('keydown', down)
    return () => window.removeEventListener('keydown', down)
  }, [])
  useEffect(() => { setHover(isShot ? 2 : null) }, [w])
  useEffect(() => { if (!done) return; const t = setTimeout(() => setDone(null), 2200); return () => clearTimeout(t) }, [done])

  const toLocal = (e: React.PointerEvent) => {
    const svg = ref.current!
    const pt = svg.createSVGPoint()
    pt.x = e.clientX; pt.y = e.clientY
    const p = pt.matrixTransform(svg.getScreenCTM()!.inverse())
    return { dx: p.x - CX, dy: p.y - CY }
  }
  const onMove = (e: React.PointerEvent) => {
    const { dx, dy } = toLocal(e)
    const h = hit(dx, dy, n, r0, R, hover)
    if (h !== null) setHover(h)
  }

  const at = (r: number, a: number) => [CX + r * Math.sin(a), CY - r * Math.cos(a)] as const
  const [ax, ay] = at(R * 0.82, mid(act))
  const target = wh.set[act].label
  const deg = Math.round(((mid(act) * 180) / Math.PI + 360) % 360)

  // Fixed anchors.
  const gapA = -step / 2 + step * 1 // boundary between wedge 0 and 1
  const [gx, gy] = at(R * 0.99, gapA)
  const [ix, iy] = at(R * 0.9, mid(0))
  const bIdx = Math.floor(n * 0.62)
  const [bx, by] = at(R * 0.6, mid(bIdx === act ? (bIdx + 1) % n : bIdx))
  const [ex, ey] = at(R * RATIO.disc, Math.PI * 0.82)

  const notes = [
    { k: 'A', t: 'Hub', d: `The file you're dragging and what it can become: ${wh.sub.toLowerCase()}.`, from: [CX - r0 * 0.55, CY - r0 * 0.35], to: [250, 150], side: 'l' as const },
    { k: 'B', t: 'Wedge', d: 'One target. Release the file on it to run.', from: [bx, by], to: [250, 380], side: 'l' as const },
    { k: 'C', t: 'Armed', d: 'Vermilion means release now. Aim is sticky across edges.', from: [ax, ay], to: [950, ay < CY ? 168 : 540], side: 'r' as const, live: true },
    { k: 'D', t: 'Index', d: 'Wedges count clockwise from 12 o\'clock.', from: [ix, iy], to: [950, 90], side: 'r' as const },
    { k: 'E', t: 'Gap', d: 'Constant width at every radius.', from: [gx, gy], to: [950, ay < CY ? 400 : 330], side: 'r' as const },
    { k: 'F', t: '43 ms', d: 'Key press to wheel on screen.', from: [ex, ey], to: [250, 600], side: 'l' as const },
  ]

  const vb = md ? `0 0 ${W} ${H}` : `${CX - R - 40} ${CY - R - 40} ${2 * R + 80} ${2 * R + 80}`

  return (
    <div className="relative">
      {/* Key selector */}
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div className="flex items-end gap-2">
          {WHEELS.map((x, i) => (
            <SwissKey key={x.key} symbol={x.key} name={x.name} pressed={i === w} onClick={() => setW(i)} size={md ? 64 : 56} tone={dark ? 'dark' : 'light'} />
          ))}
          <div className="ml-3 hidden pb-1 font-mono text-[11px] leading-relaxed sm:block" style={{ color: dim }}>
            CLICK A KEY,<br />OR PRESS ⇧ ⌘ ⌃.
          </div>
        </div>
        <Mono style={{ color: dim }}>Fig. 02 — {wh.wheel} wheel · scale 1 : 1.6</Mono>
      </div>

      <div className="relative mt-6 border-y" style={{ borderColor: dark ? '#2A2A28' : C.rule }}>
        <svg ref={ref} viewBox={vb} className="block h-auto w-full touch-manipulation select-none" role="img"
          aria-label={`${wh.wheel} wheel diagram. Armed: ${target}.`}
          onPointerMove={onMove} onClick={() => setDone(wh.run(target))}>
          {/* Construction lines */}
          <g stroke={dark ? '#2A2A28' : C.rule} strokeWidth="1" fill="none">
            <line x1={CX} y1={CY - R - 70} x2={CX} y2={CY + R + 70} strokeDasharray="6 6" />
            <line x1={CX - R - 70} y1={CY} x2={CX + R + 70} y2={CY} strokeDasharray="6 6" />
            <circle cx={CX} cy={CY} r={R * RATIO.disc + 22} />
            {Array.from({ length: 72 }).map((_, i) => {
              const a = (i / 72) * Math.PI * 2
              const r1 = R * RATIO.disc + 22, r2 = r1 + (i % 6 === 0 ? 12 : 6)
              const [x1, y1] = at(r1, a), [x2, y2] = at(r2, a)
              return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke={dark ? '#3A3A38' : '#BDBDB6'} />
            })}
          </g>
          {/* Angle ticks text */}
          {[0, 90, 180, 270].map((d) => {
            const [x, y] = at(R * RATIO.disc + 50, (d * Math.PI) / 180)
            return <text key={d} x={x} y={y} textAnchor="middle" dominantBaseline="central" fill={dim} style={{ ...mono, fontSize: 12 }}>{String(d).padStart(3, '0')}°</text>
          })}

          <WheelG cx={CX} cy={CY} r={R} segments={wh.set} active={act} hub={wh.file} hubSub={wh.sub} />

          {/* Aim ray */}
          <motion.line x1={CX} y1={CY} initial={false} animate={{ x2: ax, y2: ay }} transition={{ duration: 0.14, ease: EASE }}
            stroke={C.red} strokeWidth="1.5" strokeDasharray="3 4" />
          <motion.circle initial={false} r="6" fill={C.red} stroke={C.ink} strokeWidth="1.5" animate={{ cx: ax, cy: ay }} transition={{ duration: 0.14, ease: EASE }} />

          {/* Leader lines + notes */}
          {notes.map((nt) => {
            const [x0, y0] = nt.from
            const [x1, y1] = nt.to
            const elbowX = nt.side === 'l' ? x1 + 40 : x1 - 40
            const pts = `${x0},${y0} ${elbowX},${y1} ${x1},${y1}`
            const col = nt.live ? C.red : fg
            return (
              <g key={nt.k}>
                {md && (
                  <polyline points={pts} fill="none" stroke={col} strokeWidth="1" />
                )}
                <motion.circle initial={false} r="3.5" animate={{ cx: x0, cy: y0 }} transition={{ duration: 0.14, ease: EASE }}
                  fill={dark ? C.ink : C.sheet} stroke={col} strokeWidth="1.5" />
                {!md && (
                  <g>
                    <motion.rect initial={false} width="22" height="22" animate={{ x: x0 + 6, y: y0 - 28 }} transition={{ duration: 0.14 }} fill={nt.live ? C.red : C.ink} />
                    <motion.text initial={false} animate={{ x: x0 + 17, y: y0 - 17 }} transition={{ duration: 0.14 }} textAnchor="middle" dominantBaseline="central"
                      fill={nt.live ? C.ink : C.sheet} style={{ ...mono, fontSize: 13, fontWeight: 700 }}>{nt.k}</motion.text>
                  </g>
                )}
                {md && (
                  <motion.g initial={false} animate={{ y: y1 }} transition={{ duration: 0.14, ease: EASE }}>
                    <g transform={`translate(${nt.side === 'l' ? x1 - 210 : x1 + 10}, 0)`}>
                      <rect x="0" y="-12" width="24" height="24" fill={nt.live ? C.red : fg} />
                      <text x="12" y="0.5" textAnchor="middle" dominantBaseline="central" fill={nt.live ? C.ink : dark ? C.ink : C.sheet} style={{ ...mono, fontSize: 13, fontWeight: 700 }}>{nt.k}</text>
                      <text x="34" y="0.5" dominantBaseline="central" fill={fg} style={{ ...grot, fontSize: 20, fontWeight: 600, letterSpacing: '-0.02em' }}>{nt.t}</text>
                      <foreignObject x="0" y="16" width="200" height="60">
                        <div style={{ font: '13px/1.35 "Inter Variable", sans-serif', color: dim }}>{nt.d}</div>
                      </foreignObject>
                    </g>
                  </motion.g>
                )}
              </g>
            )
          })}
          {md && (
            <g>
              <text x={40} y={H - 22} fill={dim} style={{ ...mono, fontSize: 11, letterSpacing: 1 }}>DWG HALO-W-0{w + 1} · R {R} · INNER {RATIO.inner.toFixed(2)} R</text>
              <text x={W - 40} y={H - 22} textAnchor="end" fill={dim} style={{ ...mono, fontSize: 11, letterSpacing: 1 }}>CLICK TO DROP</text>
            </g>
          )}
        </svg>

        <AnimatePresence>
          {done && (
            <motion.div className="absolute left-1/2 top-4 z-10 -translate-x-1/2"
              initial={{ clipPath: 'inset(0 100% 0 0)' }} animate={{ clipPath: 'inset(0 0% 0 0)' }} exit={{ clipPath: 'inset(0 0 0 100%)' }}
              transition={{ duration: 0.24, ease: EASE }}>
              <div className="flex items-center gap-3 bg-[#0B0B0B] px-4 py-2.5 font-mono text-[12px] text-[#F4F4F1]">
                <span className="block size-2 bg-[#FF3D2E]" />DONE · {done}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Mobile notes */}
      {!md && (
        <ol className="mt-4 grid grid-cols-1 gap-px border" style={{ borderColor: dark ? '#2A2A28' : C.rule, background: dark ? '#2A2A28' : C.rule }}>
          {notes.map((nt) => (
            <li key={nt.k} className="flex gap-3 p-3" style={{ background: dark ? C.ink : C.sheet }}>
              <span className="grid size-6 shrink-0 place-items-center font-mono text-[12px] font-bold" style={{ background: nt.live ? C.red : fg, color: nt.live ? C.ink : dark ? C.ink : C.sheet }}>{nt.k}</span>
              <div>
                <div className="font-grotesk text-[16px] font-semibold tracking-[-0.02em]" style={{ color: fg }}>{nt.t}</div>
                <div className="text-[13px] leading-snug" style={{ color: dim }}>{nt.d}</div>
              </div>
            </li>
          ))}
        </ol>
      )}

      {/* Readout */}
      <div className="mt-4 grid grid-cols-2 border-l border-t md:grid-cols-6" style={{ borderColor: dark ? '#2A2A28' : C.rule }}>
        {[
          ['Key', `${wh.key} ${wh.name}`], ['Wheel', wh.wheel], ['Wedge', `${String(act + 1).padStart(2, '0')} / ${String(n).padStart(2, '0')}`],
          ['Target', target], ['Angle', `${String(deg).padStart(3, '0')}°`], ['Runs', wh.run(target)],
        ].map(([k, v]) => (
          <div key={k} className={cn('border-b border-r px-3 py-3')} style={{ borderColor: dark ? '#2A2A28' : C.rule }}>
            <Mono className="block text-[10px]" style={{ color: dim }}>{k}</Mono>
            <div className="mt-2 truncate font-mono text-[13px] font-semibold tabular-nums" style={{ color: k === 'Target' ? undefined : fg }}>
              {k === 'Target' ? <span className="bg-[#FF3D2E] px-1 text-[#0B0B0B]">{v}</span> : v}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
