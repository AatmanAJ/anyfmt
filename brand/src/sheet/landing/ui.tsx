import { useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { cn } from '../../shared/cn'

/** The 1200 px column every section aligns to. */
export function Wrap({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('mx-auto w-full max-w-[1232px] px-4 sm:px-6', className)}>{children}</div>
}

export function Eyebrow({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('sh-mono text-[13px] sm:text-[14px]', className)}>{children}</div>
}

/** Centred section header: mono eyebrow, a headline with one highlight, a graphite subtitle. */
export function SectionHead({ eyebrow, title, sub, className }: { eyebrow: ReactNode; title: ReactNode; sub?: ReactNode; className?: string }) {
  return (
    <div className={cn('mx-auto flex max-w-[760px] flex-col items-center text-center', className)}>
      <Eyebrow>{eyebrow}</Eyebrow>
      <h2 className="sh-display mt-5 text-[34px] sm:text-[45px]">{title}</h2>
      {sub && <p className="mt-4 max-w-[560px] text-[17px] text-[var(--sh-graphite)]">{sub}</p>}
    </div>
  )
}

/** A flat Mac window: hairline edge, slate title bar, three hairline lights. No shadow. */
export function Window({ title, children, className, style, bar = 'var(--sh-slate)', bodyClassName }: {
  title?: ReactNode; children: ReactNode; className?: string; style?: CSSProperties; bar?: string; bodyClassName?: string
}) {
  return (
    <div className={cn('overflow-hidden rounded-[6px] border border-black bg-white', className)} style={style}>
      <div className="relative flex h-[30px] items-center gap-[6px] border-b border-black px-3" style={{ background: bar }}>
        {[0, 1, 2].map((i) => <span key={i} className="size-[9px] rounded-full border border-black" style={{ background: i === 0 ? '#000' : 'transparent' }} />)}
        {title && <span className="sh-code absolute inset-x-14 truncate text-center text-[11.5px]">{title}</span>}
      </div>
      <div className={cn('relative', bodyClassName)}>{children}</div>
    </div>
  )
}

/** A flat file icon: hairline page, folded corner, a mono format badge. */
export function FileIcon({ ext, size = 56, hot }: { ext: string; size?: number; hot?: boolean }) {
  return (
    <svg width={size} height={size * 1.22} viewBox="0 0 46 56" aria-hidden style={{ display: 'block', overflow: 'visible' }}>
      <path d="M1 1h31l13 13v41H1z" fill="#fff" stroke="#000" strokeWidth="1" />
      <path d="M32 1v13h13" fill="none" stroke="#000" strokeWidth="1" />
      {[22, 27, 32].map((y) => <rect key={y} x="7" y={y} width={y === 32 ? 18 : 28} height="1.4" fill="#000" opacity=".18" />)}
      <rect x="5" y="39" width={ext.length * 6.2 + 7} height="11" fill={hot ? '#FF4500' : '#000'} />
      <text x="8.5" y="47.6" fontSize="8.4" fontFamily='"Geist Mono Variable", ui-monospace, monospace' fontWeight="600" fill={hot ? '#000' : '#fff'} letterSpacing=".3">{ext}</text>
    </svg>
  )
}

/** A pixel arrow pointer. */
export function Pointer({ size = 22 }: { size?: number }) {
  const rows = [
    'k.........', 'kk........', 'kwk.......', 'kwwk......', 'kwwwk.....', 'kwwwwk....', 'kwwwwwk...', 'kwwwwwwk..',
    'kwwwwwwwk.', 'kwwwwkkkkk', 'kwwkwk....', 'kwk.kwk...', 'kk..kwk...', 'k....kwk..', '.....kwk..', '......kk..',
  ]
  return (
    <svg width={size} height={size * 1.6} viewBox="0 0 10 16" shapeRendering="crispEdges" aria-hidden>
      {rows.flatMap((r, y) => [...r].map((c, x) => (c === '.' ? null : <rect key={`${x}-${y}`} x={x} y={y} width={1.02} height={1.02} fill={c === 'k' ? '#000' : '#fff'} />)))}
    </svg>
  )
}

/** A fixed-size stage scaled to the container's width (never above `max`). */
export function Scaled({ width, height, max = 1, children, className }: { width: number; height: number; max?: number; children: ReactNode; className?: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const [k, setK] = useState(1)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const fit = () => setK(Math.min(max, el.clientWidth / width))
    fit()
    const ro = new ResizeObserver(fit)
    ro.observe(el)
    return () => ro.disconnect()
  }, [width, max])
  return (
    <div ref={ref} className={className} style={{ width: '100%', height: height * k, position: 'relative' }}>
      <div style={{ width, height, transform: `scale(${k})`, transformOrigin: '0 0', position: 'absolute', left: '50%', marginLeft: -(width * k) / 2, top: 0 }}>
        {children}
      </div>
    </div>
  )
}

/** In-page jump that leaves the hash router alone. */
export function Jump({ to, children, className, onClick }: { to: string; children: ReactNode; className?: string; onClick?: () => void }) {
  return (
    <a href={to} className={className} onClick={(e) => {
      if (!to.startsWith('#') || to.startsWith('#/')) return
      e.preventDefault()
      onClick?.()
      document.getElementById(to.slice(1))?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
    }}>{children}</a>
  )
}
