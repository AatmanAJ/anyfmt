import { AnimatePresence, motion } from 'motion/react'
import { useCallback, useMemo, useRef, useState, type ReactNode } from 'react'
import {
  Copy, Crop, EyeOff, FolderInput, ImagePlus, Link2, Minimize2, PenLine, Pin, Radio, Scissors, SlidersHorizontal, SquareTerminal, Tag,
} from 'lucide-react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { HaloRing, P } from './theme'

export type PSeg = { id: string; label: string; sub?: string; icon?: ReactNode }

const ic = (C: typeof Copy) => <C size={15} strokeWidth={1.9} />
export const SEG = {
  convert: [
    { id: 'gif', label: 'GIF', sub: '4.1 MB' }, { id: 'mp4', label: 'MP4', sub: '1.8 MB' }, { id: 'webm', label: 'WEBM', sub: '1.2 MB' },
    { id: 'm4v', label: 'M4V', sub: '1.9 MB' }, { id: 'mp3', label: 'MP3', sub: '0.3 MB' }, { id: 'png', label: 'PNG', sub: 'frame' },
  ] as PSeg[],
  tools: [
    { id: 'compress', label: 'Compress', icon: ic(Minimize2) }, { id: 'metadata', label: 'Metadata', icon: ic(Tag) },
    { id: 'edit', label: 'Edit', icon: ic(SlidersHorizontal) }, { id: 'annotate', label: 'Annotate', icon: ic(PenLine) },
    { id: 'addbg', label: 'Add BG', icon: ic(ImagePlus) }, { id: 'trim', label: 'Trim', icon: ic(Scissors) },
    { id: 'crop', label: 'Crop', icon: ic(Crop) }, { id: 'redact', label: 'Redact', icon: ic(EyeOff) },
  ] as PSeg[],
  actions: [
    { id: 'airdrop', label: 'AirDrop', icon: ic(Radio) }, { id: 'float', label: 'Float', icon: ic(Pin) },
    { id: 'copy', label: 'Copy', icon: ic(Copy) }, { id: 'move', label: 'Move', icon: ic(FolderInput) },
    { id: 'path', label: 'Copy Path', icon: ic(Link2) }, { id: 'terminal', label: 'Terminal', icon: ic(SquareTerminal) },
  ] as PSeg[],
}

const TAU = Math.PI * 2

/** Annular sector with rounded corners (clock angles: 0 = 12 o'clock). Constant-width gaps. */
export function roundedSector(c: number, r0: number, r1: number, a0: number, a1: number, gap: number, ro: number, ri: number) {
  const g0 = gap / 2 / r0, g1 = gap / 2 / r1
  const pt = (r: number, a: number): [number, number] => [c + r * Math.sin(a), c - r * Math.cos(a)]
  const lerp = (p: [number, number], q: [number, number], d: number): [number, number] => {
    const L = Math.hypot(q[0] - p[0], q[1] - p[1])
    const t = Math.min(0.45, d / L)
    return [p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]
  }
  const O0 = pt(r1, a0 + g1), O1 = pt(r1, a1 - g1), I1 = pt(r0, a1 - g0), I0 = pt(r0, a0 + g0)
  const s = pt(r1, a0 + g1 + ro / r1), e = pt(r1, a1 - g1 - ro / r1)
  const o1b = lerp(O1, I1, ro), i1a = lerp(I1, O1, ri)
  const i1b = pt(r0, a1 - g0 - ri / r0), i0a = pt(r0, a0 + g0 + ri / r0)
  const i0b = lerp(I0, O0, ri), o0a = lerp(O0, I0, ro)
  const large = a1 - a0 > Math.PI ? 1 : 0
  const f = (p: [number, number]) => `${p[0].toFixed(2)},${p[1].toFixed(2)}`
  return `M${f(s)} A${r1},${r1} 0 ${large} 1 ${f(e)} Q${f(O1)} ${f(o1b)} L${f(i1a)} Q${f(I1)} ${f(i1b)} A${r0},${r0} 0 ${large} 0 ${f(i0a)} Q${f(I0)} ${f(i0b)} L${f(o0a)} Q${f(O0)} ${f(s)} Z`
}

type Props = {
  segments: readonly PSeg[]
  size?: number
  tone?: 'light' | 'dark'
  hubLabel?: ReactNode
  hubSub?: ReactNode
  hoverIndex?: number | null
  interactive?: boolean
  open?: boolean
  onPick?: (s: PSeg, i: number) => void
  onHover?: (i: number | null) => void
  rim?: boolean
  className?: string
}

/** The Prism wheel: a frosted pearl disc, rounded glass wedges, an iridescent hovered wedge, a turning halo rim. */
export function PrismWheel({
  segments, size = 340, tone = 'light', hubLabel, hubSub, hoverIndex, interactive = true, open = true, onPick, onHover, rim = true, className,
}: Props) {
  const dark = tone === 'dark'
  const n = segments.length
  const half = size / 2
  const pad = Math.max(5, size * 0.022)
  const r1 = half - pad
  const r0 = half * 0.37
  const step = TAU / n
  const offset = -step / 2
  const gap = Math.max(3.5, size * 0.016)
  const ro = Math.max(6, size * 0.05), ri = Math.max(4, size * 0.03)
  const lift = size * 0.018
  const [ph, setPh] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const active = hoverIndex !== undefined ? hoverIndex : ph
  const compact = size < 260
  const iconsOnly = size < 200

  const wedges = useMemo(() => segments.map((s, i) => {
    const a0 = offset + i * step, a1 = a0 + step, mid = (a0 + a1) / 2
    return { s, i, mid, path: roundedSector(half, r0, r1, a0, a1, gap, ro, ri) }
  }), [segments, offset, step, half, r0, r1, gap, ro, ri])

  const hit = useCallback((x: number, y: number) => {
    const dx = x - half, dy = y - half, d = Math.hypot(dx, dy)
    if (d < r0 * 0.8 || d > r1 + 28) return null
    let a = Math.atan2(dx, -dy) - offset
    a = ((a % TAU) + TAU) % TAU
    const idx = Math.floor(a / step)
    if (ph !== null && ph !== idx) {
      const cm = (ph + 0.5) * step
      let dd = Math.abs(a - cm); dd = Math.min(dd, TAU - dd)
      if (dd < step / 2 + Math.max(step * 0.3, (10 * Math.PI) / 180) * 0.6) return ph
    }
    return idx
  }, [half, r0, r1, offset, step, ph])

  const setHover = (i: number | null) => { setPh(i); onHover?.(i) }

  const segFill = dark
    ? 'linear-gradient(180deg, rgba(255,255,255,.13), rgba(255,255,255,.05))'
    : 'linear-gradient(180deg, rgba(255,255,255,.86), rgba(255,255,255,.55))'
  const label = dark ? 'rgba(255,255,255,.82)' : P.plum80

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          ref={ref}
          className={cn('relative shrink-0 select-none', interactive && 'cursor-pointer', className)}
          style={{ width: size, height: size }}
          initial={isShot ? false : { scale: 0.6, opacity: 0, filter: 'blur(10px)' }}
          animate={{ scale: 1, opacity: 1, filter: 'blur(0px)' }}
          exit={{ scale: 0.7, opacity: 0, filter: 'blur(8px)', transition: { duration: 0.16 } }}
          transition={{ type: 'spring', stiffness: 420, damping: 30 }}
          onPointerMove={(e) => {
            if (!interactive || hoverIndex !== undefined) return
            const r = ref.current!.getBoundingClientRect()
            setHover(hit(e.clientX - r.left, e.clientY - r.top))
          }}
          onPointerLeave={() => hoverIndex === undefined && setHover(null)}
          onClick={() => active != null && onPick?.(segments[active], active)}
          role="menu" aria-label="Halo wheel"
        >
          {/* Halo rim */}
          {rim && <HaloRing size={size + 10} thickness={1.6} className="left-[-5px] top-[-5px] opacity-80" speed="p-spin-slow" bloom={!compact} />}
          {/* Disc */}
          <div className="absolute inset-0 rounded-full" style={{
            background: dark
              ? 'radial-gradient(circle at 30% 18%, rgba(90,70,150,.55), rgba(22,16,40,.72) 70%)'
              : 'radial-gradient(circle at 30% 15%, rgba(255,255,255,.85), rgba(240,235,252,.55) 55%, rgba(225,216,248,.5))',
            backdropFilter: 'blur(26px) saturate(190%)', WebkitBackdropFilter: 'blur(26px) saturate(190%)',
            boxShadow: dark
              ? 'inset 0 1px 0 rgba(255,255,255,.22), inset 0 0 0 1px rgba(255,255,255,.1), 0 40px 90px -30px rgba(0,0,0,.8), 0 0 0 .5px rgba(0,0,0,.4)'
              : 'inset 0 1.5px 0 rgba(255,255,255,1), inset 0 0 0 1px rgba(255,255,255,.7), inset 0 -10px 30px rgba(185,167,255,.18), 0 40px 80px -30px rgba(44,30,90,.5), 0 12px 24px -14px rgba(44,30,90,.3), 0 0 0 .5px rgba(28,21,48,.08)',
          }} />
          {/* Caustic: a soft iridescent film inside the disc */}
          <div aria-hidden className="p-spin-slow absolute inset-[6%] rounded-full opacity-40 blur-[18px]"
               style={{ background: `conic-gradient(from 90deg, ${P.coral}55, transparent 25%, ${P.aqua}55, transparent 60%, ${P.lilac}66, transparent 85%)` }} />

          {wedges.map(({ s, i, mid, path }) => {
            const hot = active === i
            const lr = (r0 + r1) / 2 + (s.icon ? 0 : 0)
            const lx = half + lr * Math.sin(mid), ly = half - lr * Math.cos(mid)
            const d0 = ((mid - step / 2) * 180) / Math.PI, sd = (step * 180) / Math.PI
            return (
              <motion.div key={s.id} role="menuitem" aria-label={s.label} className="absolute inset-0"
                initial={isShot ? false : { opacity: 0, scale: 0.7 }}
                animate={{ opacity: 1, scale: hot ? 1.04 : 1, x: hot ? lift * Math.sin(mid) : 0, y: hot ? -lift * Math.cos(mid) : 0 }}
                transition={{ type: 'spring', stiffness: 520, damping: 30, delay: isShot ? 0 : i * 0.014 }}
                style={{ transformOrigin: `${half}px ${half}px`, zIndex: hot ? 2 : 1,
                         filter: hot ? `drop-shadow(0 ${size * 0.03}px ${size * 0.05}px rgba(255,107,139,.35)) drop-shadow(0 0 ${size * 0.03}px rgba(185,167,255,.6))` : 'none' }}>
                <div className="absolute inset-0" style={{
                  clipPath: `path('${path}')`, WebkitClipPath: `path('${path}')`,
                  background: hot
                    ? `conic-gradient(from ${d0}deg at 50% 50%, ${P.coral} 0deg, #FF8FB0 ${sd * 0.22}deg, ${P.lilac} ${sd * 0.5}deg, #8FCFFF ${sd * 0.76}deg, ${P.aqua} ${sd}deg, ${P.coral} 360deg)`
                    : segFill,
                }} />
                {hot && (
                  <div className="absolute inset-0" style={{
                    clipPath: `path('${path}')`, WebkitClipPath: `path('${path}')`,
                    background: `radial-gradient(circle at ${lx}px ${ly - size * 0.06}px, rgba(255,255,255,.55), transparent ${size * 0.16}px)`,
                  }} />
                )}
                <svg className="pointer-events-none absolute inset-0 overflow-visible" width={size} height={size} aria-hidden>
                  <path d={path} fill="none" stroke={hot ? 'rgba(255,255,255,.9)' : dark ? 'rgba(255,255,255,.14)' : 'rgba(255,255,255,.95)'} strokeWidth={1} />
                  {!dark && !hot && <path d={path} fill="none" stroke="rgba(28,21,48,.06)" strokeWidth={.5} transform={`translate(0 .6)`} />}
                </svg>
                <div className={cn('pointer-events-none absolute flex -translate-x-1/2 -translate-y-1/2 flex-col items-center text-center leading-none transition-colors duration-150',
                                   s.icon ? 'gap-1' : 'gap-[3px]')}
                     style={{ left: lx, top: ly, color: hot ? P.plum : label, textShadow: hot ? '0 1px 10px rgba(255,255,255,.7)' : 'none' }}>
                  {s.icon && <span className={cn(hot ? 'opacity-100' : 'opacity-85')}>{s.icon}</span>}
                  {!iconsOnly && (
                    <span className={cn('font-semibold uppercase', s.icon ? 'text-[9.5px] tracking-[.06em]' : compact ? 'text-[12px] tracking-[.02em]' : 'text-[14px] tracking-[.01em]')}
                          style={{ whiteSpace: 'nowrap' }}>{s.label}</span>
                  )}
                  {s.sub && !compact && <span className="font-mono text-[9.5px] font-medium tabular-nums opacity-70">{s.sub}</span>}
                </div>
              </motion.div>
            )
          })}

          {/* Hub */}
          <div className="absolute left-1/2 top-1/2 z-[3] flex -translate-x-1/2 -translate-y-1/2 flex-col items-center justify-center rounded-full text-center"
               style={{
                 width: r0 * 2 - gap * 2.2, height: r0 * 2 - gap * 2.2,
                 background: dark ? 'radial-gradient(circle at 35% 25%, rgba(255,255,255,.2), rgba(255,255,255,.06))' : 'radial-gradient(circle at 35% 25%, #fff, rgba(255,255,255,.72))',
                 color: dark ? '#fff' : P.plum,
                 boxShadow: dark ? 'inset 0 1px 0 rgba(255,255,255,.25), inset 0 0 0 1px rgba(255,255,255,.08)' : 'inset 0 1px 0 #fff, inset 0 0 0 1px rgba(255,255,255,.8), 0 6px 18px -8px rgba(44,30,90,.35)',
               }}>
            {hubLabel}
            {hubSub}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}

/** Standard hub content: file size + name. */
export function Hub({ size = '2.4 MB', name, small }: { size?: string; name?: string; small?: boolean }) {
  return (
    <>
      <span className={cn('font-semibold tabular-nums tracking-[-0.02em]', small ? 'text-[11px]' : 'text-[15px]')}>{size}</span>
      {name && !small && <span className="mt-0.5 max-w-[80%] truncate text-[10px] font-medium opacity-55">{name}</span>}
    </>
  )
}
