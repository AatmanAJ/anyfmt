import { motion, useInView, useReducedMotion } from 'motion/react'
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'

/** Grid tokens. One colour. Everything else is paper and ink. */
export const C = {
  sheet: '#F4F4F1',
  white: '#FFFFFF',
  rule: '#D6D6D0',
  ink: '#0B0B0B',
  ink2: '#5C5C56',
  red: '#FF3D2E',
} as const

/** The one easing curve. Mechanical: fast in, hard stop. */
export const EASE = [0.7, 0, 0.2, 1] as const
export const SNAP = { duration: 0.24, ease: EASE }

export const wrap = 'mx-auto w-full max-w-[1440px] px-4 md:px-10'
export const grid = 'grid grid-cols-4 gap-x-4 md:grid-cols-12 md:gap-x-6'

export function useMedia(q: string) {
  const [m, setM] = useState(() => typeof window !== 'undefined' && window.matchMedia(q).matches)
  useEffect(() => {
    const mq = window.matchMedia(q)
    const f = () => setM(mq.matches)
    f()
    mq.addEventListener('change', f)
    return () => mq.removeEventListener('change', f)
  }, [q])
  return m
}

/** The visible 12-column grid, drawn in hairlines behind everything. */
export function GridOverlay({ fixed = true, tone = 'rgba(214,214,208,.55)' }: { fixed?: boolean; tone?: string }) {
  return (
    <div aria-hidden className={cn('pointer-events-none inset-0 z-0', fixed ? 'fixed' : 'absolute')}>
      <div className={cn(wrap, grid, 'h-full')}>
        {Array.from({ length: 12 }).map((_, i) => (
          <div key={i} className={cn('h-full border-x', i >= 4 && 'hidden md:block')} style={{ borderColor: tone }} />
        ))}
      </div>
    </div>
  )
}

/** Small uppercase mono label. */
export function Mono({ children, className, style }: { children: ReactNode; className?: string; style?: CSSProperties }) {
  return <span className={cn('font-mono text-[11px] font-medium uppercase leading-none tracking-[0.08em]', className)} style={style}>{children}</span>
}

/** "■ 02" — the index marker. The square carries the colour, the number stays ink (contrast). */
export function Idx({ n, className, light }: { n: string; className?: string; light?: boolean }) {
  return (
    <span className={cn('inline-flex items-center gap-2 font-mono text-[11px] font-semibold leading-none tracking-[0.08em]', className)}>
      <span className="block size-2" style={{ background: C.red }} />
      <span style={{ color: light ? C.sheet : C.ink }}>{n}</span>
    </span>
  )
}

/** Printer's registration mark. */
export function RegMark({ size = 18, color = C.ink, className, style }: { size?: number; color?: string; className?: string; style?: CSSProperties }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" className={className} style={style} aria-hidden>
      <circle cx="10" cy="10" r="5.2" fill="none" stroke={color} strokeWidth="1" />
      <path d="M10 0v20M0 10h20" stroke={color} strokeWidth="1" />
    </svg>
  )
}

/** Hairline crop marks at the four corners of a box. */
export function CropMarks({ color = C.ink, inset = -10 }: { color?: string; inset?: number }) {
  const s = 12
  const pos: CSSProperties[] = [
    { left: inset, top: inset }, { right: inset, top: inset, transform: 'scaleX(-1)' },
    { left: inset, bottom: inset, transform: 'scaleY(-1)' }, { right: inset, bottom: inset, transform: 'scale(-1,-1)' },
  ]
  return (
    <>
      {pos.map((p, i) => (
        <svg key={i} aria-hidden width={s} height={s} viewBox="0 0 12 12" className="pointer-events-none absolute" style={p}>
          <path d="M0 0.5H12M0.5 0V12" stroke={color} strokeWidth="1" fill="none" />
        </svg>
      ))}
    </>
  )
}

/** A horizontal wipe in from the left. No fades. */
export function Wipe({ children, className, delay = 0, dir = 'x', style }: { children: ReactNode; className?: string; delay?: number; dir?: 'x' | 'y'; style?: CSSProperties }) {
  const reduce = useReducedMotion()
  if (isShot || reduce) return <div className={className} style={style}>{children}</div>
  return (
    <motion.div className={className} style={style}
      initial={{ clipPath: dir === 'x' ? 'inset(0 100% 0 0)' : 'inset(0 0 100% 0)' }}
      whileInView={{ clipPath: 'inset(0 0% 0% 0)' }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.7, ease: EASE, delay }}>
      {children}
    </motion.div>
  )
}

/** A rule that draws itself left to right. */
export function DrawRule({ className, color = C.ink, delay = 0 }: { className?: string; color?: string; delay?: number }) {
  const reduce = useReducedMotion()
  return (
    <motion.div aria-hidden className={cn('h-px origin-left', className)} style={{ background: color }}
      initial={isShot || reduce ? false : { scaleX: 0 }} whileInView={{ scaleX: 1 }} viewport={{ once: true }}
      transition={{ duration: 0.9, ease: EASE, delay }} />
  )
}

/** Mechanical counter: every digit is a drum that rolls into place. */
export function Odometer({ value, className, delay = 0, replay = 0 }: { value: string; className?: string; delay?: number; replay?: number }) {
  const ref = useRef<HTMLSpanElement>(null)
  const inView = useInView(ref, { once: true, margin: '-40px' })
  const reduce = useReducedMotion()
  const still = isShot || !!reduce
  const go = still || inView
  let di = 0
  return (
    <span ref={ref} className={cn('inline-flex leading-none tabular-nums', className)} aria-label={value} role="img">
      {value.split('').map((ch, i) => {
        if (!/\d/.test(ch)) return <span key={i} aria-hidden style={{ whiteSpace: 'pre' }}>{ch}</span>
        const d = +ch
        const k = di++
        const target = 10 + d
        return (
          <span key={`${i}-${replay}`} aria-hidden className="relative inline-block" style={{ height: '1em', lineHeight: 1, overflowX: 'visible', overflowY: 'clip' }}>
            <span className="invisible block" style={{ height: '1em', lineHeight: 1 }}>{ch}</span>
            <motion.span className="absolute left-0 top-0 flex flex-col"
              initial={still ? false : { y: '0em' }}
              animate={{ y: go ? `${-target}em` : '0em' }}
              transition={{ duration: 1.1 + k * 0.22, ease: EASE, delay }}>
              {Array.from({ length: 20 }, (_, j) => <span key={j} className="block" style={{ height: '1em', lineHeight: 1 }}>{j % 10}</span>)}
            </motion.span>
          </span>
        )
      })}
    </span>
  )
}

/** Square buttons. Primary is ink; hover turns it vermilion with ink text (5.6:1). */
export function Btn({ children, kind = 'primary', className, onClick, size = 'md' }: {
  children: ReactNode; kind?: 'primary' | 'ghost' | 'red' | 'light'; className?: string; onClick?: () => void; size?: 'sm' | 'md' | 'lg'
}) {
  const k = {
    primary: 'bg-[#0B0B0B] text-[#F4F4F1] hover:bg-[#FF3D2E] hover:text-[#0B0B0B]',
    red: 'bg-[#FF3D2E] text-[#0B0B0B] hover:bg-[#0B0B0B] hover:text-[#F4F4F1]',
    ghost: 'border border-[#0B0B0B] text-[#0B0B0B] hover:bg-[#0B0B0B] hover:text-[#F4F4F1]',
    light: 'border border-[#F4F4F1]/40 text-[#F4F4F1] hover:bg-[#F4F4F1] hover:text-[#0B0B0B]',
  }[kind]
  const s = { sm: 'h-8 px-3 text-[13px]', md: 'h-11 px-5 text-[15px]', lg: 'h-14 px-7 text-[17px]' }[size]
  return (
    <button type="button" onClick={onClick}
      className={cn('group/btn inline-flex shrink-0 items-center gap-3 font-grotesk font-medium tracking-[-0.01em] transition-colors duration-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#FF3D2E]', k, s, className)}>
      {children}
    </button>
  )
}

export function Arrow({ className }: { className?: string }) {
  return (
    <svg width="16" height="12" viewBox="0 0 16 12" className={cn('transition-transform duration-150 group-hover/btn:translate-x-1', className)} aria-hidden>
      <path d="M0 6h14M9 1l5 5-5 5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="square" />
    </svg>
  )
}

/** A file as a drawn object: sheet with a cut corner and a format box. */
export function FileTile({ ext, name, size = 56, className, dark }: { ext: string; name?: string; size?: number; className?: string; dark?: boolean }) {
  const w = size, h = size * 1.25, fold = size * 0.28
  return (
    <div className={cn('inline-flex flex-col items-center gap-1.5', className)}>
      <div className="relative" style={{ width: w, height: h }}>
        <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} className="absolute inset-0" aria-hidden>
          <path d={`M0.75 0.75H${w - fold}L${w - 0.75} ${fold}V${h - 0.75}H0.75Z`} fill={C.white} stroke={C.ink} strokeWidth="1.5" />
          <path d={`M${w - fold} 0.75V${fold}H${w - 0.75}`} fill="none" stroke={C.ink} strokeWidth="1.5" />
          {[0.36, 0.48, 0.6].map((y, i) => <rect key={y} x={w * 0.14} y={h * y} width={w * (i === 2 ? 0.4 : 0.72)} height="1.5" fill={C.rule} />)}
        </svg>
        <span className="absolute bottom-[9%] left-[12%] bg-[#0B0B0B] px-1 py-[2px] font-mono font-bold leading-none text-[#F4F4F1]"
          style={{ fontSize: Math.max(8, size * 0.16) }}>{ext}</span>
      </div>
      {name && <span className={cn('font-mono text-[10px] leading-none tracking-tight', dark ? 'text-[#F4F4F1]' : 'text-[#0B0B0B]')}>{name}</span>}
    </div>
  )
}

/** A Swiss keycap: square, hairline, symbol top-left, name bottom-left. */
export function SwissKey({ symbol, name, pressed, size = 64, className, onClick, tone = 'light' }: {
  symbol: string; name?: string; pressed?: boolean; size?: number; className?: string; onClick?: () => void; tone?: 'light' | 'dark'
}) {
  const reduce = useReducedMotion()
  const Tag = onClick ? motion.button : motion.div
  const idle = tone === 'light' ? { bg: C.white, fg: C.ink, edge: C.ink } : { bg: '#1A1A1A', fg: C.sheet, edge: '#3A3A38' }
  return (
    <Tag type={onClick ? 'button' : undefined} onClick={onClick} aria-pressed={onClick ? !!pressed : undefined}
      className={cn('relative flex shrink-0 flex-col justify-between border-[1.5px] p-2 text-left', className)}
      style={{ width: size, height: size, borderColor: pressed ? C.ink : idle.edge }}
      initial={false} animate={{ y: pressed && !reduce ? 3 : 0, backgroundColor: pressed ? C.ink : idle.bg, color: pressed ? C.sheet : idle.fg,
                 boxShadow: pressed ? `0 0 0 ${C.ink}` : `0 3px 0 ${tone === 'light' ? C.ink : '#000'}` }}
      transition={{ duration: 0.08, ease: 'linear' }}>
      <span className="font-grotesk font-medium leading-none" style={{ fontSize: size * 0.36 }}>{symbol}</span>
      {name && <span className="font-mono font-semibold uppercase leading-none tracking-[0.06em]" style={{ fontSize: Math.max(8, size * 0.13) }}>{name}</span>}
    </Tag>
  )
}

/** Big section head: index, kicker, caption, and the title on the grid. */
export function SectionHead({ n, kicker, title, caption, dark, className }: {
  n: string; kicker: string; title: ReactNode; caption?: ReactNode; dark?: boolean; className?: string
}) {
  const fg = dark ? C.sheet : C.ink
  return (
    <div className={className}>
      <div className={cn(grid, 'border-t pt-3')} style={{ borderColor: fg }}>
        <div className="col-span-1 md:col-span-2"><Idx n={n} light={dark} /></div>
        <Mono className="col-span-3 md:col-span-4" style={{ color: fg }}>{kicker}</Mono>
        {caption && <div className="col-span-4 mt-3 hidden font-sans text-[14px] leading-snug md:col-span-4 md:col-start-9 md:mt-0 md:block" style={{ color: dark ? '#A9A9A2' : C.ink2 }}>{caption}</div>}
      </div>
      <Wipe>
        <h2 className="mt-6 font-grotesk text-[clamp(44px,8.4vw,132px)] font-semibold leading-[0.86] tracking-[-0.058em] md:mt-10" style={{ color: fg }}>
          {title}
        </h2>
      </Wipe>
      {caption && <p className="mt-5 max-w-[46ch] font-sans text-[15px] leading-snug md:hidden" style={{ color: dark ? '#A9A9A2' : C.ink2 }}>{caption}</p>}
    </div>
  )
}

/** Shift-arrow glyph as a path, so it renders identically everywhere (fonts lack ⇧ at this size). */
export function ShiftGlyph({ className, style, fill = C.red }: { className?: string; style?: CSSProperties; fill?: string }) {
  return (
    <svg viewBox="0 0 100 104" className={className} style={style} aria-hidden>
      <path d="M50 0 L100 54 H73 V104 H27 V54 H0 Z" fill={fill} />
    </svg>
  )
}

export function cx(...a: (string | false | undefined | null)[]) { return cn(...a) }
