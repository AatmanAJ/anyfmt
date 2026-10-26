import type { CSSProperties, ReactNode } from 'react'
import { Check, X } from 'lucide-react'
import { cn } from '../../shared/cn'

/** A section opener: a black rule, the folio line in mono, a headline with one highlight, a graphite lede. */
export function Section({ id, n, label, title, lede, children, className }: {
  id: string; n: number; label: string; title: ReactNode; lede?: ReactNode; children: ReactNode; className?: string
}) {
  return (
    <section id={id} data-sec={id} className={cn('scroll-mt-[64px] pt-20 md:pt-24', className)}>
      <div className="shb-rule flex items-baseline justify-between pt-3">
        <span className="shb-lbl">§{String(n).padStart(2, '0')} · {label}</span>
        <span className="shb-lbl text-[var(--sh-graphite)]"><span className="hidden sm:inline">anyfmt brand book · </span>p.{String(n * 4).padStart(2, '0')}</span>
      </div>
      <div className="mt-8 grid gap-6 md:grid-cols-12 md:gap-8">
        <h2 className="sh-display text-[34px] md:col-span-7 md:text-[45px]">{title}</h2>
        {lede && <p className="text-[17px] leading-[1.55] text-[var(--sh-graphite)] md:col-span-5 md:pt-2">{lede}</p>}
      </div>
      <div className="mt-12">{children}</div>
    </section>
  )
}

/** A numbered sub-part: mono label on a quiet hairline, an optional note to the right. */
export function Sub({ n, title, note, children, className }: { n: string; title: string; note?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <div className={cn('mt-16 first:mt-0', className)}>
      <div className="shb-rule-q flex flex-col gap-2 pt-3 md:flex-row md:items-baseline md:justify-between md:gap-8">
        <span className="shb-lbl"><span className="text-[var(--sh-graphite)]">{n}</span>&nbsp;&nbsp;{title}</span>
        {note && <span className="max-w-[560px] text-[14px] leading-[1.5] text-[var(--sh-graphite)] md:text-right">{note}</span>}
      </div>
      <div className="mt-6">{children}</div>
    </div>
  )
}

export function Lbl({ children, className, style }: { children: ReactNode; className?: string; style?: CSSProperties }) {
  return <span className={cn('shb-lbl text-[var(--sh-graphite)]', className)} style={style}>{children}</span>
}

/** Do / don't: a tick or a cross in a mono header, the example in a tinted plate. */
export function DoDont({ ok, children, note, className, plate = 'var(--sh-slate)' }: {
  ok: boolean; children: ReactNode; note: ReactNode; className?: string; plate?: string
}) {
  return (
    <figure className={cn('flex flex-col', className)}>
      <div className="relative grid min-h-[150px] flex-1 place-items-center overflow-hidden rounded-[4px] p-6" style={{ background: plate }}>
        {children}
        {!ok && <svg className="pointer-events-none absolute inset-0 h-full w-full" preserveAspectRatio="none" viewBox="0 0 100 100" aria-hidden><line x1="0" y1="100" x2="100" y2="0" stroke="#000" strokeWidth="0.4" vectorEffect="non-scaling-stroke" /></svg>}
      </div>
      <figcaption className="mt-3 flex gap-2 text-[14px] leading-[1.45]">
        <span className={cn('mt-[1px] grid size-[18px] flex-none place-items-center rounded-full', ok ? 'bg-black text-white' : 'shb-hair-ink')}>
          {ok ? <Check size={12} strokeWidth={2.5} /> : <X size={12} strokeWidth={2.5} />}
        </span>
        <span><b className="font-[600]">{ok ? 'Do.' : 'Don’t.'}</b> <span className="text-[var(--sh-graphite)]">{note}</span></span>
      </figcaption>
    </figure>
  )
}

/** A flat Mac window: hairline edge, quiet title bar, monochrome lights. No shadow, ever. */
export function Win({ title, children, dark, className, style, bar = true, right }: {
  title?: ReactNode; children: ReactNode; dark?: boolean; className?: string; style?: CSSProperties; bar?: boolean; right?: ReactNode
}) {
  return (
    <div className={cn('overflow-hidden rounded-[10px]', dark ? 'shb-hair-d bg-[var(--shb-d-bg)] text-white' : 'shb-hair bg-white text-black', className)} style={style}>
      {bar && (
        <div className={cn('relative flex h-[34px] items-center gap-[7px] px-3', dark ? 'border-b border-[var(--shb-d-line)]' : 'border-b border-[var(--shb-line)]')}>
          {[0, 1, 2].map((i) => <span key={i} className="size-[11px] rounded-full" style={{ background: dark ? '#333' : '#DCE1E8' }} />)}
          {title && <span className={cn('absolute inset-x-16 truncate text-center text-[12px] font-[500]', dark ? 'text-[var(--shb-d-mute)]' : 'text-[var(--sh-graphite)]')}>{title}</span>}
          {right && <span className="ml-auto">{right}</span>}
        </div>
      )}
      {children}
    </div>
  )
}

/** WCAG relative-luminance contrast, computed live from the hex values on the page. */
export function lum(hex: string) {
  const v = hex.replace('#', '')
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(v.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}
export function contrast(a: string, b: string) {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p)
  return (x + 0.05) / (y + 0.05)
}
export function grade(r: number) {
  return r >= 7 ? 'AAA' : r >= 4.5 ? 'AA' : r >= 3 ? 'AA large' : 'Fail'
}

export const C = {
  ink: '#000000', paper: '#FFFFFF', slate: '#F8FAFC', lavender: '#E2E9F3', mist: '#C5D3E8',
  cream: '#FFFDE6', sky: '#C4EDFF', graphite: '#686562', orange: '#FF4500',
  green: '#2FB36B', yellow: '#FFD23F', forest: '#1F7A48',
} as const

/** The pixel palette: imagery only. */
export const PX: Record<string, string> = {
  k: C.ink, w: C.paper, o: C.orange, g: C.green, G: C.forest, y: C.yellow, m: C.mist, s: C.sky, l: C.lavender, c: C.cream, r: C.graphite,
}

/** A keycap in the Sheet style: white, hairline, mono glyph. */
export function Key({ children, dark, size = 30, className }: { children: ReactNode; dark?: boolean; size?: number; className?: string }) {
  return (
    <span className={cn('inline-grid place-items-center rounded-[6px] font-[500]', dark ? 'shb-hair-d bg-[var(--shb-d-2)] text-white' : 'shb-hair-ink bg-white text-black', className)}
      style={{ minWidth: size, height: size, padding: '0 6px', fontSize: size * 0.5, boxShadow: dark ? 'inset 0 0 0 1px #3a3a3a, inset 0 -2px 0 #3a3a3a' : 'inset 0 0 0 1px #000, inset 0 -2px 0 #000' }}>
      {children}
    </span>
  )
}

/** A small flat file icon for UI (not pixel art): page, folded corner, mono extension. */
export function FileTile({ ext, size = 40, dark, tint }: { ext: string; size?: number; dark?: boolean; tint?: string }) {
  const h = size * 1.22
  const stroke = dark ? '#5A5A5A' : '#000'
  return (
    <svg width={size} height={h} viewBox="0 0 40 49" aria-hidden className="flex-none">
      <path d="M2.5 2.5h24l11 11v33h-35z" fill={tint ?? (dark ? '#1C1C1C' : '#fff')} stroke={stroke} strokeWidth="1" vectorEffect="non-scaling-stroke" />
      <path d="M26.5 2.5v11h11" fill="none" stroke={stroke} strokeWidth="1" vectorEffect="non-scaling-stroke" />
      <text x="20" y="38" textAnchor="middle" fontFamily="Geist Mono Variable, monospace" fontSize="8.5" fontWeight="600" fill={dark ? '#fff' : '#000'} letterSpacing=".04em">{ext}</text>
    </svg>
  )
}
