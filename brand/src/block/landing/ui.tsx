import type { CSSProperties, MouseEvent, ReactNode } from 'react'
import { cn } from '../../shared/cn'

/** In-page link. The app uses a hash router, so plain #anchors would change the route. */
export function Jump({ to, children, className, style, onClick }: { to: string; children: ReactNode; className?: string; style?: CSSProperties; onClick?: () => void }) {
  const go = (e: MouseEvent) => {
    e.preventDefault()
    onClick?.()
    document.getElementById(to.replace('#', ''))?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
  return <a href={to} onClick={go} className={className} style={style}>{children}</a>
}

/** Small mono label that opens most blocks: a square bullet plus an index. */
export function Eyebrow({ n, children, className, dot = 'var(--bk-orange)' }: { n?: string; children: ReactNode; className?: string; dot?: string }) {
  return (
    <div className={cn('bk-mono flex items-center gap-2.5 text-[11.5px] font-medium uppercase tracking-[0.08em]', className)}>
      <span className="inline-block size-2.5" style={{ background: dot }} />
      {n && <span className="opacity-55">{n}</span>}
      <span>{children}</span>
    </div>
  )
}

/** A flat file tile in the Block style: square corners, hard shadow, a format slab. */
export function FileTile({ name, ext, tone = 'cream', size = 92, style, className }: {
  name: string; ext: string; tone?: 'cream' | 'orange' | 'lilac'; size?: number; style?: CSSProperties; className?: string
}) {
  const bg = tone === 'orange' ? 'var(--bk-orange)' : tone === 'lilac' ? 'var(--bk-lilac)' : 'var(--bk-cream)'
  return (
    <div className={cn('flex flex-col items-center gap-2', className)} style={style}>
      <div className="relative" style={{ width: size, height: size * 1.18, background: bg, boxShadow: '5px 5px 0 var(--bk-wine)', clipPath: 'polygon(0 0, 72% 0, 100% 22%, 100% 100%, 0 100%)' }}>
        <div className="absolute right-0 top-0" style={{ width: size * 0.28, height: size * 0.26, background: 'rgba(14,14,16,.18)' }} />
        <div className="absolute inset-x-[12%] top-[34%] h-[30%] bk-stripe-pink" style={{ backgroundSize: '100% 100%', opacity: tone === 'cream' ? 1 : 0.9 }} />
        <span className="bk-mono absolute bottom-[9%] left-[12%] bg-[var(--bk-ink)] px-1.5 py-0.5 text-[10px] font-bold tracking-wide text-[var(--bk-cream)]">{ext}</span>
      </div>
      <span className="bk-mono whitespace-nowrap bg-[var(--bk-ink)]/80 px-1.5 text-[11px] text-[var(--bk-cream)]">{name}</span>
    </div>
  )
}

/** macOS-ish arrow cursor, ink with a cream outline. */
export function Cursor({ size = 26 }: { size?: number }) {
  return (
    <svg width={size} height={size * 1.3} viewBox="0 0 20 26" aria-hidden style={{ filter: 'drop-shadow(2px 2px 0 rgba(14,14,16,.35))' }}>
      <path d="M2 1.5 L2 20.5 L6.8 16.2 L10 23.6 L13.3 22.2 L10.2 15 L16.6 15 Z" fill="#0E0E10" stroke="#F4F1EC" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  )
}

/** Section heading: giant two-tone display type. */
export function Display({ a, b, className, bColor = 'var(--bk-orange)' }: { a: ReactNode; b?: ReactNode; className?: string; bColor?: string }) {
  return (
    <h2 className={cn('bk-display font-semibold', className)} style={{ lineHeight: 0.9 }}>
      <span className="block">{a}</span>
      {b && <span className="block" style={{ color: bColor }}>{b}</span>}
    </h2>
  )
}
