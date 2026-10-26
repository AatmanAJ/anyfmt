import { useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { Reveal } from '../../shared/kit'
import { cn } from '../../shared/cn'

/** The Block palette, as plain values for SVG and inline styles. */
export const C = {
  orange: '#FF6B1A', orangeHi: '#FF8F4D', orangeLo: '#D9500A',
  ink: '#0E0E10', ink2: '#1C1C21', ink3: '#2C2C33',
  wine: '#3A0E1E', wine2: '#561629',
  lilac: '#B8B3FF', lilacLo: '#8E87F2',
  pink: '#FF4FA0', cream: '#F4F1EC', white: '#FFFFFF',
  mute: '#8A8790', line: '#2A2A30', lineLight: '#DEDAD3',
} as const

/** WCAG 2.x contrast ratio between two hex colours. */
export function contrast(a: string, b: string) {
  const lum = (hex: string) => {
    const n = hex.replace('#', '')
    const [r, g, bl] = [0, 2, 4].map((i) => parseInt(n.slice(i, i + 2), 16) / 255)
      .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * bl
  }
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p)
  return (x + 0.05) / (y + 0.05)
}
/** Mix two hex colours: t = 0 gives a, 1 gives b. */
export function mix(a: string, b: string, t: number) {
  const p = (h: string) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16))
  const [x, y] = [p(a), p(b)]
  return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('')
}
export const grade = (r: number) => (r >= 7 ? 'AAA' : r >= 4.5 ? 'AA' : r >= 3 ? 'AA Large' : 'Fail')

/** A chapter of the book. Header: mono number, giant two-tone title, a short intro. */
export function Section({ id, num, title, accent, intro, children, tone = C.orange }: {
  id: string; num: string; title: string; accent?: string; intro?: ReactNode; children: ReactNode; tone?: string
}) {
  return (
    <section id={id} data-sec={id} className="scroll-mt-20 pt-24 md:scroll-mt-6 md:pt-32">
      <Reveal>
        <header className="mb-8 grid gap-6 border-t border-[#2A2A30] pt-6 md:mb-10 md:grid-cols-12">
          <div className="md:col-span-7">
            <div className="bk-mono mb-4 flex items-center gap-2 text-[12px] uppercase tracking-[.08em] text-[#8A8790]">
              <span className="inline-block size-2.5" style={{ background: tone }} />{num} / {(title + (accent ?? '')).replace(/\.$/, '')}
            </div>
            <h2 className="bk-display text-[56px] font-[640] leading-[.88] md:text-[104px]">
              {title}{accent && <span style={{ color: tone }}>{accent}</span>}
            </h2>
          </div>
          {intro && <p className="self-end text-[17px] leading-[1.5] text-[#F4F1EC]/75 md:col-span-5 md:pb-2">{intro}</p>}
        </header>
      </Reveal>
      {children}
    </section>
  )
}

/** A flat colour panel. Optional mono label in the corner. */
export function Tile({ bg = C.ink2, fg, label, labelTone, className, style, children, id }: {
  bg?: string; fg?: string; label?: ReactNode; labelTone?: string; className?: string; style?: CSSProperties; children?: ReactNode; id?: string
}) {
  return (
    <div id={id} className={cn('relative overflow-hidden rounded-[6px]', bg === C.ink && 'ring-1 ring-inset ring-[#2A2A30]', className)} style={{ ...(bg ? { background: bg } : {}), color: fg, ...style }}>
      {label && (
        <div className="bk-mono absolute left-4 top-4 z-10 text-[11px] uppercase tracking-[.08em]" style={{ color: labelTone ?? fg, opacity: 0.7 }}>{label}</div>
      )}
      {children}
    </div>
  )
}

/** The case-study caption row under a group of panels: label left, text right. */
export function Caption({ label, children, className }: { label: ReactNode; children: ReactNode; className?: string }) {
  return (
    <div className={cn('mb-14 mt-5 grid gap-3 md:grid-cols-12 md:gap-6', className)}>
      <div className="bk-mono text-[12px] uppercase tracking-[.08em] text-[#8A8790] md:col-span-4">{label}</div>
      <div className="max-w-[60ch] text-[15px] leading-[1.6] text-[#F4F1EC]/70 md:col-span-8">{children}</div>
    </div>
  )
}

/** Small sub-heading inside a section. */
export function Sub({ children, n }: { children: ReactNode; n?: string }) {
  return (
    <h3 className="bk-display mb-4 mt-4 flex items-baseline gap-3 text-[28px] font-[620] leading-none md:text-[36px]">
      {n && <span className="bk-mono text-[12px] font-medium tracking-normal text-[#FF6B1A]">{n}</span>}{children}
    </h3>
  )
}

/** Scales one line of display type to fill its container exactly. */
export function FitText({ children, className, style, max = 2000 }: { children: ReactNode; className?: string; style?: CSSProperties; max?: number }) {
  const box = useRef<HTMLDivElement>(null)
  const txt = useRef<HTMLSpanElement>(null)
  const [size, setSize] = useState(100)
  useLayoutEffect(() => {
    const fit = () => {
      if (!box.current || !txt.current) return
      txt.current.style.fontSize = '100px'
      const w = txt.current.getBoundingClientRect().width
      const cs = getComputedStyle(box.current)
      const inner = box.current.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight)
      const next = w > 0 ? Math.min(max, (inner / w) * 100 * 0.99) : 100
      txt.current.style.fontSize = `${next}px`
      setSize(next)
    }
    fit()
    const ro = new ResizeObserver(fit)
    if (box.current) ro.observe(box.current)
    document.fonts?.ready.then(fit)
    return () => ro.disconnect()
  }, [max])
  return (
    <div ref={box} className={cn('w-full', className)} style={style}>
      <span ref={txt} className="inline-block whitespace-nowrap" style={{ fontSize: size }}>{children}</span>
    </div>
  )
}

/** A do / don't marker. */
export function Verdict({ ok, children }: { ok: boolean; children?: ReactNode }) {
  return (
    <span className="bk-tag self-start" style={{ background: ok ? C.lilac : C.pink, color: C.ink }}>
      <span className="text-[13px] leading-none">{ok ? '✓' : '×'}</span>{children ?? (ok ? 'Do' : "Don't")}
    </span>
  )
}

/** macOS traffic lights. */
export function Lights({ mono }: { mono?: string }) {
  return (
    <div className="flex gap-[7px]">
      {(mono ? [mono, mono, mono] : ['#FF5F57', '#FEBC2E', '#28C840']).map((c, i) => <span key={i} className="block size-[11px] rounded-full" style={{ background: c, opacity: mono ? 0.35 : 1 }} />)}
    </div>
  )
}

/** Renders children at a fixed design size and scales them to fit the container's width. */
export function Scaled({ w, h, children, className, max = 1 }: { w: number; h: number; children: ReactNode; className?: string; max?: number }) {
  const box = useRef<HTMLDivElement>(null)
  const [k, setK] = useState(1)
  useLayoutEffect(() => {
    const fit = () => { if (box.current) setK(Math.min(max, box.current.clientWidth / w)) }
    fit()
    const ro = new ResizeObserver(fit)
    if (box.current) ro.observe(box.current)
    return () => ro.disconnect()
  }, [w, max])
  return (
    <div ref={box} className={cn('w-full', className)} style={{ height: h * k }}>
      <div style={{ width: w, height: h, transform: `scale(${k})`, transformOrigin: 'top left', margin: k >= max ? '0 auto' : 0 }}>{children}</div>
    </div>
  )
}
