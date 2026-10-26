import { ArrowUpRight } from 'lucide-react'
import type { CSSProperties, ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { C } from './tokens'

/** Tiny mono uppercase label. The instrument's silkscreen. */
export function Label({ children, className, style, dim }: { children: ReactNode; className?: string; style?: CSSProperties; dim?: boolean }) {
  return (
    <span className={cn('font-mono text-[10.5px] uppercase leading-none tracking-[0.18em]', className)} style={{ color: dim ? C.ash2 : C.ash, ...style }}>
      {children}
    </span>
  )
}

/** Section header: channel index, mono kicker, hairline, serif title. */
export function SectionHead({ ch, kicker, title, lede, className, align = 'left' }: { ch: string; kicker: string; title: ReactNode; lede?: ReactNode; className?: string; align?: 'left' | 'center' }) {
  return (
    <div className={cn('flex flex-col', align === 'center' && 'items-center text-center', className)}>
      <div className={cn('flex w-full items-center gap-3', align === 'center' && 'justify-center')}>
        <Label style={{ color: C.solar }}>CH {ch}</Label>
        <Label>{kicker}</Label>
        {align === 'left' && <span className="h-px flex-1" style={{ background: C.graphite }} />}
      </div>
      <h2 className="mt-6 max-w-[18ch] font-serif text-[44px] leading-[0.95] tracking-[-0.025em] sm:text-[64px] md:text-[80px]" style={{ color: C.bone }}>{title}</h2>
      {lede && <p className="mt-5 max-w-[52ch] font-geist text-[16px] leading-[1.6] md:text-[17px]" style={{ color: C.ash }}>{lede}</p>}
    </div>
  )
}

export function Button({ children, variant = 'live', href = '#', className, icon = true }: { children: ReactNode; variant?: 'live' | 'ghost'; href?: string; className?: string; icon?: boolean }) {
  return (
    <a href={href}
      className={cn('group inline-flex h-11 items-center gap-2 rounded-full pl-5 pr-4 font-mono text-[12px] font-semibold uppercase tracking-[0.14em] transition-[transform,box-shadow,background] duration-200 active:scale-[0.98] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#D7FF3A]', className)}
      style={variant === 'live'
        ? { background: C.solar, color: C.void, boxShadow: '0 0 0 1px rgba(215,255,58,.4), 0 0 32px -6px rgba(215,255,58,.55)' }
        : { color: C.bone, boxShadow: `inset 0 0 0 1px ${C.graphite2}` }}>
      {children}
      {icon && <ArrowUpRight size={15} strokeWidth={2.2} className="transition-transform duration-200 group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />}
    </a>
  )
}

/** Hairline rule with optional tick marks, like a scale. */
export function Scale({ className, ticks = 48 }: { className?: string; ticks?: number }) {
  return (
    <div className={cn('relative h-3 w-full', className)} aria-hidden>
      <span className="absolute inset-x-0 bottom-0 h-px" style={{ background: C.graphite }} />
      <div className="absolute inset-x-0 bottom-0 flex justify-between">
        {Array.from({ length: ticks + 1 }, (_, i) => (
          <span key={i} className="block w-px" style={{ height: i % 8 === 0 ? 10 : i % 4 === 0 ? 6 : 3, background: i % 8 === 0 ? C.graphite2 : C.graphite }} />
        ))}
      </div>
    </div>
  )
}

/** A styled terminal. Lines starting with `$` are commands. */
export function Terminal({ lines, title = 'zsh — halo', className }: { lines: string[]; title?: string; className?: string }) {
  return (
    <div className={cn('overflow-hidden rounded-[14px]', className)}
      style={{ background: 'rgba(12,12,14,.92)', boxShadow: `inset 0 0 0 1px ${C.graphite}, inset 0 1px 0 rgba(255,255,255,.05), 0 30px 80px -30px rgba(0,0,0,.9)` }}>
      <div className="flex items-center gap-2 px-4 py-3" style={{ borderBottom: `1px solid ${C.graphite}` }}>
        {[0, 1, 2].map((i) => <span key={i} className="size-[10px] rounded-full" style={{ background: C.graphite2 }} />)}
        <span className="ml-3 font-mono text-[11px]" style={{ color: C.ash2 }}>{title}</span>
      </div>
      <pre className="no-scrollbar overflow-x-auto p-5 font-mono text-[12px] leading-[1.75] md:text-[13px]">
        {lines.map((l, i) => {
          if (l.startsWith('$')) {
            const [cmd, ...rest] = l.slice(2).split(' ')
            return (
              <div key={i}><span style={{ color: C.solar }}>❯ </span><span style={{ color: C.bone }}>{cmd}</span>{' '}
                {rest.map((r, j) => <span key={j} style={{ color: r.startsWith('--') ? C.solar : '#C9C9C2' }}>{r}{' '}</span>)}
              </div>
            )
          }
          if (l.startsWith('{')) return <div key={i} style={{ color: '#9C9C95' }}>{colorJson(l)}</div>
          return <div key={i} style={{ color: C.ash2 }}>{l || ' '}</div>
        })}
      </pre>
    </div>
  )
}

function colorJson(l: string) {
  const parts = l.split(/("[^"]*"\s*:|"[^"]*"|[\d.]+)/g)
  return parts.map((p, i) => {
    if (/^"[^"]*"\s*:$/.test(p)) return <span key={i} style={{ color: '#7E7E78' }}>{p}</span>
    if (/^"/.test(p)) return <span key={i} style={{ color: C.bone }}>{p}</span>
    if (/^[\d.]+$/.test(p)) return <span key={i} style={{ color: C.solar }}>{p}</span>
    return <span key={i}>{p}</span>
  })
}

/** The page wrapper: tokens as CSS variables, void background, selection in solar. */
export function SignalRoot({ children, className, vars }: { children: ReactNode; className?: string; vars: Record<string, string> }) {
  return (
    <div className={cn('min-h-screen overflow-x-clip font-geist antialiased selection:bg-[#D7FF3A] selection:text-[#050506]', className)}
      style={{ ...(vars as CSSProperties), background: C.void, color: C.bone }}>
      {children}
    </div>
  )
}
