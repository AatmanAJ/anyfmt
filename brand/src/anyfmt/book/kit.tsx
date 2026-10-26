import { useReducedMotion } from 'motion/react'
import { Check, X } from 'lucide-react'
import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { isShot, Reveal } from '../../shared/kit'
import { Eyebrow } from '../Landing'

/** `?only=logo,colour` renders a subset of the book (for screenshots under the 16 000 px cap). */
export const ONLY = typeof location !== 'undefined' ? new URLSearchParams(location.search).get('only')?.split(',').filter(Boolean) ?? null : null

/** True when live demos may animate on their own. */
export function useLive() {
  const reduce = useReducedMotion()
  return !isShot && !reduce
}

/** Runs `fn` every `ms` while live. */
export function useTick(ms: number, fn: () => void, on = true) {
  const live = useLive()
  const ref = useRef(fn)
  ref.current = fn
  useEffect(() => {
    if (!live || !on) return
    const id = setInterval(() => ref.current(), ms)
    return () => clearInterval(id)
  }, [live, on, ms])
}

/**
 * Lays out a fixed-size mockup at its design size and scales it down to fit
 * narrower containers, so mockups keep their proportions on a phone.
 */
export function Fit({ w, h, children, className, style, align = 'center' }: {
  w: number; h: number; children: ReactNode; className?: string; style?: CSSProperties; align?: 'center' | 'left'
}) {
  const ref = useRef<HTMLDivElement>(null)
  const [cw, setCw] = useState(w)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const update = () => setCw(el.clientWidth)
    update()
    const ro = new ResizeObserver(update)
    ro.observe(el)
    return () => ro.disconnect()
  }, [])
  const s = Math.min(1, cw / w)
  const left = align === 'center' ? Math.max(0, (cw - w * s) / 2) : 0
  return (
    <div ref={ref} className={className} style={{ position: 'relative', width: '100%', height: h * s, ...style }}>
      <div style={{ position: 'absolute', top: 0, left, width: w, height: h, transform: `scale(${s})`, transformOrigin: 'top left' }}>
        {children}
      </div>
    </div>
  )
}

/** One numbered chapter of the book. */
export function Section({ id, n, eyebrow, title, intro, children, className }: {
  id: string; n: string; eyebrow: string; title: ReactNode; intro?: ReactNode; children: ReactNode; className?: string
}) {
  return (
    <section id={id} data-book-section className={`mx-auto max-w-[1240px] scroll-mt-28 px-4 pb-8 pt-20 sm:px-6 sm:pb-12 sm:pt-28 ${className ?? ''}`}>
      <Reveal className="grid gap-6 border-t border-[#D9D6D2] pt-6 lg:grid-cols-[200px_1fr]">
        <div className="flex items-center gap-3 lg:flex-col lg:items-start">
          <span className="af-mono text-[13px] font-medium text-[#EA7C25]">{n}</span>
          <Eyebrow>{eyebrow}</Eyebrow>
        </div>
        <div className="flex max-w-[820px] flex-col gap-4">
          <h2 className="text-[38px] font-semibold leading-[1.02] tracking-[-0.045em] text-balance sm:text-[56px]">{title}</h2>
          {intro && <p className="max-w-[620px] text-[17px] leading-relaxed text-[#55524F]">{intro}</p>}
        </div>
      </Reveal>
      <div className="mt-14 flex flex-col gap-16 sm:mt-16 sm:gap-24">{children}</div>
    </section>
  )
}

/** A sub-chapter: title + note on the left or above, content below. */
export function Sub({ title, note, children, aside }: { title: ReactNode; note?: ReactNode; children: ReactNode; aside?: ReactNode }) {
  return (
    <div className="flex flex-col gap-6">
      <Reveal className="flex flex-col justify-between gap-3 sm:flex-row sm:items-end">
        <div className="max-w-[640px]">
          <h3 className="text-[24px] font-semibold tracking-[-0.035em] sm:text-[28px] sm:tracking-[-0.04em]">{title}</h3>
          {note && <p className="mt-1.5 text-[15px] leading-relaxed text-[#55524F]">{note}</p>}
        </div>
        {aside}
      </Reveal>
      <Reveal>{children}</Reveal>
    </div>
  )
}

/** Small mono caption for specs. */
export function Spec({ children, className, tone = 'ink' }: { children: ReactNode; className?: string; tone?: 'ink' | 'white' }) {
  return <span className={`af-mono text-[11.5px] tracking-[-0.01em] ${tone === 'white' ? 'text-white/55' : 'text-[#8C8884]'} ${className ?? ''}`}>{children}</span>
}

/** Do / Don't badge. */
export function Verdict({ ok, children }: { ok: boolean; children: ReactNode }) {
  return (
    <div className="flex items-start gap-2.5">
      <span className={`mt-[1px] grid size-5 shrink-0 place-items-center rounded-full ${ok ? 'bg-[#E9F7EF] text-[#1F9D55]' : 'bg-[#FDECE6] text-[#BB3F14]'}`}>
        {ok ? <Check size={12} strokeWidth={3} /> : <X size={12} strokeWidth={3} />}
      </span>
      <div className="text-[14px] leading-snug"><span className="font-semibold">{ok ? 'Do. ' : 'Don’t. '}</span><span className="text-[#55524F]">{children}</span></div>
    </div>
  )
}

/** A 1px-hairline dark specimen panel. */
export function InkPanel({ children, className, style }: { children: ReactNode; className?: string; style?: CSSProperties }) {
  return (
    <div className={`relative overflow-hidden rounded-[20px] bg-[#111] text-white ${className ?? ''}`}
      style={{ boxShadow: '0 0 0 1px #000, 0 24px 50px -24px rgba(0,0,0,.55)', ...style }}>
      {children}
    </div>
  )
}

/* ---------- colour maths for the contrast table ---------- */

function lum(hex: string) {
  const n = hex.replace('#', '')
  const c = [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16) / 255)
    .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4))
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}
export function contrast(a: string, b: string) {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p)
  return (x + 0.05) / (y + 0.05)
}
export function grade(r: number) {
  return r >= 7 ? 'AAA' : r >= 4.5 ? 'AA' : r >= 3 ? 'AA Large' : 'Fail'
}
