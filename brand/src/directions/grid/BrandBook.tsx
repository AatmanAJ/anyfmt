import { motion, useReducedMotion } from 'motion/react'
import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { product } from '../../shared/product'
import { GridWheel, SETS, sector } from './GridWheel'
import { Bento, Formats, Hero, Nav } from './Landing'
import { AppIcon, Lockup, Mark, MenuGlyph, Wordmark } from './Logo'
import { meta } from './meta'
import { Onboarding } from './Onboarding'
import { DoneToast, ErrorToast, FloatShelf, MenuBarMenu, OptionsPanel, ProgressHUD } from './Surfaces'
import { Arrow, C, CropMarks, EASE, FileTile, GridOverlay, grid, Idx, Mono, Odometer, RegMark, SectionHead, wrap, useMedia } from './ui'

const SECTIONS = [
  ['cover', 'Cover'], ['logo', 'Logo'], ['colour', 'Colour'], ['type', 'Type'], ['voice', 'Voice'],
  ['motion', 'Motion'], ['landing', 'Landing'], ['onboarding', 'Onboarding'], ['app', 'App'],
] as const

/* ───────────────────────── helpers ───────────────────────── */

function lum(hex: string) {
  const v = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
}
function ratio(a: string, b: string) {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p)
  return (x + 0.05) / (y + 0.05)
}
const grade = (r: number) => (r >= 7 ? 'AAA' : r >= 4.5 ? 'AA' : r >= 3 ? 'AA large' : 'Fail')

function Section({ id, n, kicker, title, caption, children, className, dark }: {
  id: string; n: string; kicker: string; title: ReactNode; caption?: ReactNode; children: ReactNode; className?: string; dark?: boolean
}) {
  return (
    <section id={id} data-sec={id} className={cn('relative scroll-mt-12 py-16 md:py-24', dark && 'z-[1] bg-[#0B0B0B] text-[#F4F4F1]', className)}>
      {dark && <GridOverlay fixed={false} tone="rgba(255,255,255,.06)" />}
      <div className={cn(wrap, 'relative')}>
        <SectionHead n={n} kicker={kicker} title={title} caption={caption} dark={dark} />
        <div className="mt-12 md:mt-16">{children}</div>
      </div>
    </section>
  )
}

function Sub({ n, title, children, note }: { n: string; title: string; children?: ReactNode; note?: ReactNode }) {
  return (
    <div className={cn(grid, 'mb-6 mt-16 items-baseline border-t border-[#D6D6D0] pt-3 first:mt-0')}>
      <Mono className="col-span-1 text-[#5C5C56] md:col-span-2">{n}</Mono>
      <h3 className="col-span-3 font-grotesk text-[24px] font-semibold tracking-[-0.03em] md:col-span-6 md:text-[28px]">{title}{children}</h3>
      {note && <p className="col-span-4 mt-2 text-[13px] leading-snug text-[#5C5C56] md:col-span-4 md:mt-0">{note}</p>}
    </div>
  )
}

function Tile({ children, className, label, bg = C.white, fg }: { children: ReactNode; className?: string; label?: ReactNode; bg?: string; fg?: string }) {
  return (
    <figure className={cn('relative flex flex-col border border-[#D6D6D0]', className)} style={{ background: bg, color: fg }}>
      <div className="grid flex-1 place-items-center p-6">{children}</div>
      {label && <figcaption className="border-t px-3 py-2 font-mono text-[10px] uppercase tracking-[0.08em]" style={{ borderColor: fg ? 'rgba(128,128,128,.3)' : C.rule, color: fg ?? C.ink2 }}>{label}</figcaption>}
    </figure>
  )
}

/* ───────────────────────── sticky nav ───────────────────────── */

function BookNav() {
  const [active, setActive] = useState('cover')
  useEffect(() => {
    const els = [...document.querySelectorAll<HTMLElement>('[data-sec]')]
    const io = new IntersectionObserver((es) => {
      es.forEach((e) => { if (e.isIntersecting) setActive((e.target as HTMLElement).dataset.sec!) })
    }, { rootMargin: '-45% 0px -50% 0px' })
    els.forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [])
  return (
    <nav className="sticky top-0 z-50 border-b border-[#0B0B0B] bg-[#F4F4F1]" aria-label="Brand book sections">
      <div className={cn(wrap, 'flex h-12 items-center gap-4')}>
        <button type="button" onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })} className="shrink-0" aria-label="Top"><Lockup h={18} /></button>
        <span className="hidden h-4 w-px bg-[#D6D6D0] md:block" />
        <div className="flex min-w-0 flex-1 items-center overflow-x-auto no-scrollbar">
          {SECTIONS.map(([id, label], i) => (
            <button key={id} type="button" onClick={() => document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' })}
              className={cn('flex shrink-0 items-center gap-1.5 px-2.5 py-1.5 font-mono text-[11px] uppercase tracking-[0.08em] transition-colors',
                active === id ? 'bg-[#0B0B0B] text-[#F4F4F1]' : 'text-[#0B0B0B] hover:bg-[#E4E4DF]')}>
              <span className={active === id ? 'text-[#FF3D2E]' : 'text-[#5C5C56]'}>{String(i + 1).padStart(2, '0')}</span>{label}
            </button>
          ))}
        </div>
        <Link to="/d/grid/landing" className="hidden shrink-0 items-center gap-2 bg-[#0B0B0B] px-3 py-1.5 font-grotesk text-[13px] font-medium text-[#F4F4F1] hover:bg-[#FF3D2E] hover:text-[#0B0B0B] sm:flex">
          Landing <Arrow />
        </Link>
      </div>
    </nav>
  )
}

/* ───────────────────────── 01 Cover ───────────────────────── */

function Cover() {
  const md = useMedia('(min-width: 768px)')
  return (
    <section id="cover" data-sec="cover" className="relative overflow-hidden">
      <div className={cn(wrap, 'relative pb-16 pt-6 md:min-h-[860px]')}>
        <div className={cn(grid, 'border-b border-[#D6D6D0] pb-3')}>
          <Mono className="col-span-2 md:col-span-3">anyfmt — Brand book</Mono>
          <Mono className="col-span-2 text-right text-[#5C5C56] md:col-span-3 md:text-left">Direction: {meta.name}</Mono>
          <Mono className="hidden text-[#5C5C56] md:col-span-3 md:block">Rev. 1.0 · Oct 2026</Mono>
          <Mono className="hidden text-right text-[#5C5C56] md:col-span-3 md:block">Sheet 01 / 09</Mono>
        </div>
        {md ? (
          <div aria-hidden className="pointer-events-none absolute" style={{ left: '50%', marginLeft: -20, top: 170 }}>
            <Mark size={880} />
          </div>
        ) : (
          <div aria-hidden className="pointer-events-none relative h-[230px]">
            <div className="absolute -right-[130px] top-6"><Mark size={340} /></div>
          </div>
        )}
        <div className="relative z-10 pt-4 md:pt-36">
          <Idx n="00" />
          <h1 className="mt-6 font-grotesk text-[clamp(112px,23vw,360px)] font-semibold leading-[0.78] tracking-[-0.085em]" style={{ marginLeft: '-0.05em' }}>
            Grid.
          </h1>
          <div className={cn(grid, 'mt-12 gap-y-8 md:mt-16')}>
            <p className="col-span-4 font-grotesk text-[28px] font-medium leading-[1.02] tracking-[-0.04em] md:col-span-5 md:text-[40px]">
              {meta.tagline}
            </p>
            <dl className="col-span-4 grid grid-cols-2 border-t border-[#0B0B0B] bg-[#F4F4F1] md:col-span-5 md:col-start-1">
              {[
                ['Lineage', 'Swiss / International style'], ['Colour', '1 — Vermilion'],
                ['Display', meta.fonts.display], ['Text · Data', `${meta.fonts.text} · ${meta.fonts.mono}`],
              ].map(([k, v]) => (
                <div key={k} className="border-b border-[#D6D6D0] py-3 pr-3">
                  <dt className="font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">{k}</dt>
                  <dd className="mt-1.5 text-[14px] font-medium">{v}</dd>
                </div>
              ))}
            </dl>
          </div>
        </div>
        <RegMark className="absolute bottom-6 left-4 md:left-10" />
        <RegMark className="absolute bottom-6 right-4 md:right-10" />
      </div>
    </section>
  )
}

/* ───────────────────────── 02 Logo ───────────────────────── */

function Construction() {
  const n = 6, step = (Math.PI * 2) / n
  const mono = { fontFamily: '"JetBrains Mono Variable", monospace', fontSize: 3.2 }
  return (
    <svg viewBox="-14 -14 128 128" className="h-auto w-full" role="img" aria-label="Mark construction">
      <g fill="none" stroke={C.rule} strokeWidth="0.3">
        {Array.from({ length: 13 }).map((_, i) => <line key={'v' + i} x1={-14 + i * 10.67} y1={-14} x2={-14 + i * 10.67} y2={114} />)}
        {Array.from({ length: 13 }).map((_, i) => <line key={'h' + i} y1={-14 + i * 10.67} x1={-14} y2={-14 + i * 10.67} x2={114} />)}
      </g>
      {Array.from({ length: n }).map((_, i) => {
        const a0 = -step / 2 + i * step
        return <path key={i} d={sector(50, 50, 20, 48, a0, a0 + step, 6)} fill={i === 1 ? C.red : C.ink} />
      })}
      <g fill="none" stroke={C.red} strokeWidth="0.35">
        <circle cx="50" cy="50" r="48" strokeDasharray="1 1" />
        <circle cx="50" cy="50" r="20" strokeDasharray="1 1" />
        {Array.from({ length: n }).map((_, i) => {
          const a = -step / 2 + i * step
          return <line key={i} x1="50" y1="50" x2={50 + 58 * Math.sin(a)} y2={50 - 58 * Math.cos(a)} strokeDasharray="1 1" />
        })}
      </g>
      <g fill={C.ink} style={mono}>
        <line x1="50" y1="50" x2="98" y2="50" stroke={C.ink} strokeWidth="0.4" />
        <text x="76" y="48">R 48</text>
        <line x1="50" y1="50" x2="50" y2="70" stroke={C.ink} strokeWidth="0.4" />
        <text x="51.5" y="66">r 20</text>
        <text x="-10" y="-8">01 · 100 u square</text>
        <text x="64" y="110">6 × 60° · gap 6 u</text>
        <text x="86" y="10" fill={C.ink}>hot wedge</text>
        <line x1="85" y1="11" x2="76" y2="24" stroke={C.ink} strokeWidth="0.4" />
      </g>
    </svg>
  )
}

function Dont({ children, label }: { children: ReactNode; label: string }) {
  return (
    <Tile label={<span className="flex items-center gap-2"><span className="font-bold text-[#0B0B0B]">✕</span>{label}</span>} className="aspect-[4/3.4]">
      <div className="relative">
        {children}
        <svg className="pointer-events-none absolute -inset-4" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden>
          <line x1="0" y1="100" x2="100" y2="0" stroke={C.red} strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
        </svg>
      </div>
    </Tile>
  )
}

function LogoSection() {
  const n = 6, step = (Math.PI * 2) / n
  return (
    <Section id="logo" n="02" kicker="Logo" title={<>A ring, cut<br />into six. One is red.</>}
      caption="The mark is the wheel at rest. Six wedges for the six actions; the vermilion one is where your file lands.">
      <div className={cn(grid, 'gap-y-6')}>
        <div className="relative col-span-4 border border-[#D6D6D0] bg-white p-4 md:col-span-7 md:p-8"><Construction /></div>
        <div className="col-span-4 flex flex-col gap-6 md:col-span-5">
          <Tile className="flex-1" label="Primary lockup · mark + wordmark"><Lockup h={64} /></Tile>
          <div className="grid flex-1 grid-cols-2 gap-6">
            <Tile label="Stacked">
              <div className="flex flex-col items-center gap-3"><Mark size={72} /><Wordmark style={{ fontSize: 36 }} /></div>
            </Tile>
            <Tile label="Wordmark">
              <Wordmark style={{ fontSize: 56 }} />
            </Tile>
          </div>
        </div>
      </div>

      <Sub n="02.1" title="Clear space and minimum size" note="Clear space x = the ring's inner radius. Never smaller than 16 px for the mark, 72 px wide for the lockup." />
      <div className={cn(grid, 'gap-y-6')}>
        <Tile className="col-span-4 md:col-span-6" label="x = inner radius (20 u)">
          <div className="relative p-10">
            <div className="absolute inset-0 border border-dashed border-[#FF3D2E]" />
            <div className="absolute inset-[40px] border border-[#D6D6D0]" />
            {['left-0 top-1/2 -translate-y-1/2 w-10', 'right-0 top-1/2 -translate-y-1/2 w-10', 'top-0 left-1/2 -translate-x-1/2 h-10', 'bottom-0 left-1/2 -translate-x-1/2 h-10'].map((p) => (
              <span key={p} className={cn('absolute grid place-items-center font-mono text-[11px] font-semibold', p)}>x</span>
            ))}
            <Lockup h={56} />
          </div>
        </Tile>
        <Tile className="col-span-4 md:col-span-6" label="Minimum sizes">
          <div className="flex w-full items-end justify-around gap-4">
            {[64, 32, 24, 16].map((s) => (
              <div key={s} className="flex flex-col items-center gap-3">
                <Mark size={s} />
                <span className="font-mono text-[10px] text-[#5C5C56]">{s} px</span>
              </div>
            ))}
            <div className="flex flex-col items-center gap-3">
              <Lockup h={16} />
              <span className="font-mono text-[10px] text-[#5C5C56]">72 px</span>
            </div>
          </div>
        </Tile>
      </div>

      <Sub n="02.2" title="On light, dark and accent" note="On vermilion the hot wedge turns Sheet. Nothing else changes colour, ever." />
      <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
        <Tile bg={C.sheet} label="Sheet · ink + vermilion" className="aspect-[4/3]"><Lockup h={52} /></Tile>
        <Tile bg={C.ink} fg={C.sheet} label="Ink · sheet + vermilion" className="aspect-[4/3]"><Lockup h={52} color={C.sheet} /></Tile>
        <Tile bg={C.red} fg={C.ink} label="Vermilion · ink + sheet" className="aspect-[4/3]"><Lockup h={52} accent={C.sheet} /></Tile>
      </div>

      <Sub n="02.3" title="App icon and menu-bar glyph" note="Icon on Apple's 1024 grid: 824 body, continuous corners, the 12-column grid etched into the sheet. Menu-bar glyph is a template image: one colour, the red wedge becomes the gap." />
      <div className={cn(grid, 'gap-y-6')}>
        <Tile className="col-span-4 md:col-span-4" label="1024 · light">
          <AppIcon size={220} />
        </Tile>
        <Tile className="col-span-4 md:col-span-4" label="1024 · dark" bg="#E9E9E4">
          <AppIcon size={220} dark />
        </Tile>
        <div className="col-span-4 flex flex-col gap-6 md:col-span-4">
          <Tile label="Dock sizes · 128 · 64 · 32" className="flex-1">
            <div className="flex items-end gap-4"><AppIcon size={128} /><AppIcon size={64} /><AppIcon size={32} /></div>
          </Tile>
          <Tile label="Menu bar · 16 / 18 px · light and dark" className="flex-1">
            <div className="w-full space-y-3">
              {[false, true].map((dk) => (
                <div key={String(dk)} className="flex h-7 items-center justify-end gap-4 rounded-[6px] px-3 font-sans text-[12px] font-medium" style={{ background: dk ? '#2B2B2A' : '#ECECE8', color: dk ? '#F4F4F1' : C.ink }}>
                  <span className="opacity-60">100%</span>
                  <MenuGlyph size={16} color={dk ? '#F4F4F1' : '#000'} />
                  <MenuGlyph size={18} color={dk ? '#F4F4F1' : '#000'} />
                  <span>09:41</span>
                </div>
              ))}
            </div>
          </Tile>
        </div>
      </div>
      <div className={cn(grid, 'mt-6 gap-y-6')}>
        <Tile className="col-span-4 md:col-span-4" label="18 px template on the pixel grid">
          <div className="relative" style={{ width: 216, height: 216 }}>
            <svg width="216" height="216" className="absolute inset-0" aria-hidden>
              {Array.from({ length: 19 }).map((_, i) => (
                <g key={i}><line x1={i * 12} y1="0" x2={i * 12} y2="216" stroke={C.rule} /><line y1={i * 12} x1="0" y2={i * 12} x2="216" stroke={C.rule} /></g>
              ))}
            </svg>
            <div className="absolute inset-0"><MenuGlyph size={216} color={C.ink} /></div>
          </div>
        </Tile>
        <div className="col-span-4 grid grid-cols-2 gap-6 md:col-span-8 md:grid-cols-3">
          <Tile label={<span className="flex gap-2"><span className="font-bold text-[#0B0B0B]">✓</span>Ink on sheet</span>} className="aspect-[4/3.4]"><Mark size={84} /></Tile>
          <Tile label={<span className="flex gap-2"><span className="font-bold">✓</span>Sheet on ink</span>} bg={C.ink} fg={C.sheet} className="aspect-[4/3.4]"><Mark size={84} ink={C.sheet} /></Tile>
          <Dont label="Recolour wedges">
            <svg width="84" height="84" viewBox="0 0 100 100" aria-hidden>
              {Array.from({ length: n }).map((_, i) => { const a0 = -step / 2 + i * step; return <path key={i} d={sector(50, 50, 20, 48, a0, a0 + step, 6)} fill={['#FF3D2E', '#2E6BFF', '#18C26B', '#FFC21A', '#A54BFF', '#0B0B0B'][i]} /> })}
            </svg>
          </Dont>
          <Dont label="Add gradients or glow">
            <div style={{ filter: 'drop-shadow(0 0 14px rgba(255,61,46,.9))' }}><Mark size={84} accent="#FF9A3D" ink="#7A3CFF" /></div>
          </Dont>
          <Dont label="Move the red wedge"><Mark size={84} hot={3} /></Dont>
          <Dont label="Stretch or skew"><div style={{ transform: 'scaleX(1.5)' }}><Mark size={84} /></div></Dont>
        </div>
      </div>
    </Section>
  )
}

/* ───────────────────────── 03 Colour ───────────────────────── */

const SWATCH = [
  { name: 'Vermilion', hex: C.red, role: 'The one colour. Armed wedge, the 2 %.', fg: C.ink, span: 'md:col-span-4' },
  { name: 'Sheet', hex: C.sheet, role: 'Canvas. 70 % of every surface.', fg: C.ink, span: 'md:col-span-2' },
  { name: 'White', hex: C.white, role: 'Panels, windows, cards.', fg: C.ink, span: 'md:col-span-2' },
  { name: 'Rule', hex: C.rule, role: 'Hairlines, the grid.', fg: C.ink, span: 'md:col-span-2' },
  { name: 'Black', hex: C.ink, role: 'Type, the wheel disc.', fg: C.sheet, span: 'md:col-span-2' },
]

function ColourSection() {
  const pairs: [string, string, string, string][] = [
    ['Black on Sheet', C.ink, C.sheet, 'Body, display'],
    ['Ink 2 on Sheet', C.ink2, C.sheet, 'Captions, secondary'],
    ['Black on Vermilion', C.ink, C.red, 'Armed wedge label, red buttons'],
    ['Sheet on Black', C.sheet, C.ink, 'Dark panels, HUD'],
    ['Vermilion on Sheet', C.red, C.sheet, 'Graphic only, ≥ 24 px'],
    ['White on Vermilion', C.white, C.red, 'Avoid for text'],
  ]
  const tokens = [
    ['--anyfmt-bg', C.sheet, 'Page and window canvas'], ['--anyfmt-surface', C.white, 'Panels, menus, toasts'],
    ['--anyfmt-ink', C.ink, 'Primary text, disc, primary button'], ['--anyfmt-ink-2', C.ink2, 'Secondary text, indices'],
    ['--anyfmt-rule', C.rule, 'Hairlines, grid, dividers'], ['--anyfmt-accent', C.red, 'Armed wedge, progress, focus ring'],
    ['--anyfmt-on-accent', C.ink, 'Text on vermilion (5.6 : 1)'], ['--anyfmt-wedge', C.sheet, 'Wheel wedge at rest'],
    ['--anyfmt-danger', C.red, 'Errors use the one colour + "!"'], ['--anyfmt-success', C.ink, 'Success is a black check, not green'],
  ]
  return (
    <Section id="colour" n="03" kicker="Colour" title={<>Paper, ink,<br />one red.</>} caption="Colour is information. If something is vermilion, it is the thing you are about to do.">
      <div className="grid grid-cols-2 gap-px border border-[#0B0B0B] bg-[#0B0B0B] md:grid-cols-12">
        {SWATCH.map((s, i) => (
          <div key={s.name} className={cn('flex min-h-[240px] flex-col justify-between p-4 md:min-h-[360px]', i === 0 ? 'col-span-2' : 'col-span-1', s.span)} style={{ background: s.hex, color: s.fg }}>
            <div className="flex items-start justify-between">
              <span className="font-mono text-[11px] font-semibold">{String(i + 1).padStart(2, '0')}</span>
              {i === 0 && <span className="font-mono text-[11px] font-semibold">≤ 2 %</span>}
            </div>
            <div>
              <div className="font-grotesk text-[28px] font-semibold leading-none tracking-[-0.04em] md:text-[34px]">{s.name}</div>
              <div className="mt-3 font-mono text-[12px] font-semibold">{s.hex}</div>
              <div className="mt-1 font-mono text-[10px] opacity-80">RGB {[1, 3, 5].map((k) => parseInt(s.hex.slice(k, k + 2), 16)).join(' ')}</div>
              <p className="mt-3 text-[12px] leading-snug opacity-80">{s.role}</p>
            </div>
          </div>
        ))}
      </div>

      <Sub n="03.1" title="Proportion" note="Measured by area on any page or window. If red passes 2 %, take some away." />
      <div className="flex h-14 w-full border border-[#0B0B0B]">
        {[[C.sheet, 70, 'Sheet 70'], [C.white, 12, 'White 12'], [C.ink, 10, 'Black 10'], [C.rule, 6, 'Rule 6'], [C.red, 2, '']].map(([c, w, l]) => (
          <div key={c as string} className="flex items-end p-2 font-mono text-[10px]" style={{ width: `${w}%`, background: c as string, color: c === C.ink ? C.sheet : C.ink }}>{l}</div>
        ))}
      </div>
      <div className="mt-2 text-right font-mono text-[10px] text-[#5C5C56]">VERMILION 2 ↑</div>

      <Sub n="03.2" title="Contrast" note="Computed with WCAG 2.2 relative luminance. Vermilion never carries small text; text on vermilion is black." />
      <div className="grid grid-cols-1 gap-px border border-[#D6D6D0] bg-[#D6D6D0] md:grid-cols-3">
        {pairs.map(([n, fg, bg, use]) => {
          const r = ratio(fg, bg)
          return (
            <div key={n} className="flex items-center gap-4 bg-white p-4">
              <div className="grid size-16 shrink-0 place-items-center border border-[#D6D6D0] font-grotesk text-[26px] font-semibold" style={{ background: bg, color: fg }}>Aa</div>
              <div className="min-w-0 flex-1">
                <div className="text-[14px] font-medium">{n}</div>
                <div className="mt-0.5 text-[12px] text-[#5C5C56]">{use}</div>
              </div>
              <div className="text-right">
                <div className="font-mono text-[18px] font-semibold tabular-nums">{r.toFixed(2)}</div>
                <div className={cn('mt-1 inline-block px-1 font-mono text-[10px] font-semibold', grade(r) === 'Fail' || grade(r) === 'AA large' ? 'bg-[#FF3D2E] text-[#0B0B0B]' : 'bg-[#0B0B0B] text-[#F4F4F1]')}>{grade(r)}</div>
              </div>
            </div>
          )
        })}
      </div>

      <Sub n="03.3" title="Semantic tokens" note="CSS variables. The app reads the same names from its asset catalogue." />
      <div className="overflow-x-auto border-t border-[#0B0B0B]">
        <table className="w-full min-w-[560px] border-collapse font-mono text-[12px]">
          <thead><tr className="text-left text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]"><th className="py-2 font-medium">Token</th><th className="py-2 font-medium">Value</th><th className="py-2 font-medium">Use</th></tr></thead>
          <tbody>
            {tokens.map(([t, v, u]) => (
              <tr key={t} className="border-t border-[#D6D6D0] hover:bg-white">
                <td className="py-2.5 pr-4 font-semibold">{t}</td>
                <td className="py-2.5 pr-4"><span className="inline-flex items-center gap-2"><span className="size-3.5 border border-[#D6D6D0]" style={{ background: v }} />{v}</span></td>
                <td className="py-2.5 font-sans text-[13px] text-[#3A3A38]">{u}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Section>
  )
}

/* ───────────────────────── 04 Type ───────────────────────── */

const SCALE = [
  ['Display XL', 'font-grotesk font-semibold', 'clamp(64px,10vw,160px)', 0.8, '-0.07em', '160 / 0.80 / −7 %', 'Drop.'],
  ['Display', 'font-grotesk font-semibold', 'clamp(48px,6.6vw,96px)', 0.86, '-0.058em', '96 / 0.86 / −5.8 %', 'Three wheels.'],
  ['Heading', 'font-grotesk font-semibold', '40px', 0.95, '-0.045em', '40 / 0.95 / −4.5 %', 'Allow Accessibility.'],
  ['Title', 'font-grotesk font-medium', '22px', 1.1, '-0.03em', '22 / 1.10 / −3 %', 'Saved clip.gif'],
  ['Body', 'font-sans', '17px', 1.45, '-0.005em', '17 / 1.45 / −0.5 %', 'Drag a file in Finder. Press a key. Drop.'],
  ['Small', 'font-sans', '13px', 1.4, '0', '13 / 1.40 / 0', "It's password-protected. Unlock it, then drop again."],
  ['Label', 'font-mono font-medium uppercase', '11px', 1, '0.08em', '11 / 1.00 / +8 %', 'Fig. 02 — Convert wheel'],
  ['Data', 'font-mono tabular-nums', '13px', 1.5, '0', '13 / 1.50 / tnum', 'MOV → GIF  2.4 MB  15 fps  0.9 s'],
] as const

function TypeSection() {
  return (
    <Section id="type" n="04" kicker="Type" title={<>Grotesk for saying.<br />Mono for counting.</>} caption="Three faces, three jobs. Display is set tight and large; data is always mono and tabular.">
      <div className="grid grid-cols-1 gap-px border border-[#0B0B0B] bg-[#0B0B0B] md:grid-cols-3">
        {[
          ['Display', 'Space Grotesk', 'font-grotesk font-semibold tracking-[-0.06em]', '500 · 600 · 700'],
          ['Text', 'Inter', 'font-sans font-medium tracking-[-0.03em]', '400 · 500 · 600'],
          ['Data', 'JetBrains Mono', 'font-mono font-medium tracking-[-0.04em]', '400 · 500 · 600 · 700'],
        ].map(([role, name, cls, w], i) => (
          <div key={name} className={cn('flex flex-col justify-between p-5 md:min-h-[420px] md:p-7', i === 0 ? 'bg-[#0B0B0B] text-[#F4F4F1]' : 'bg-[#F4F4F1]')}>
            <div className="flex justify-between"><Mono className="opacity-70">{role}</Mono><Mono className="opacity-70">{w}</Mono></div>
            <div className={cn('my-8 text-[150px] leading-[0.8] md:text-[180px]', cls)}>Aa</div>
            <div>
              <div className="font-grotesk text-[28px] font-semibold tracking-[-0.04em]">{name}</div>
              <div className={cn('mt-3 break-all text-[15px] leading-snug opacity-80', cls.split(' ')[0])}>ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 → ⇧ ⌘ ⌃ %</div>
            </div>
          </div>
        ))}
      </div>

      <Sub n="04.1" title="Scale" note="Sizes in px at 1×. Display tracking tightens as size grows; labels open up." />
      <div className="border-b border-[#0B0B0B]">
        {SCALE.map(([name, cls, size, lh, tr, spec, sample]) => (
          <div key={name} className={cn(grid, 'items-baseline gap-y-2 border-t border-[#D6D6D0] py-5 first:border-[#0B0B0B]')}>
            <Mono className="col-span-2 md:col-span-2">{name}</Mono>
            <Mono className="col-span-2 text-right text-[#5C5C56] md:order-last md:col-span-2">{spec}</Mono>
            <div className={cn('col-span-4 min-w-0 overflow-hidden text-ellipsis pb-[0.14em] md:col-span-8', cls)} style={{ fontSize: size, lineHeight: lh, letterSpacing: tr }}>{sample}</div>
          </div>
        ))}
      </div>

      <Sub n="04.2" title="Pairing rules" />
      <ol className={cn(grid, 'gap-y-0')}>
        {[
          ['Big or small, never medium.', 'Display jumps from 40 to 96. The gap is the hierarchy.'],
          ['Numbers are mono.', 'Sizes, times, counts and indices use JetBrains Mono with tabular figures.'],
          ['Tracking follows size.', 'Above 40 px tighten to −4.5 % or more. Mono labels open to +8 %.'],
          ['Flush left, ragged right.', 'Never centre a paragraph. Centre only inside a wheel or icon.'],
          ['One weight change per line.', 'Contrast comes from size and colour, not from bolding words.'],
          ['Uppercase is for labels.', 'Never set a sentence in caps. Labels are 11 px mono.'],
        ].map(([t, d], i) => (
          <li key={t} className="col-span-4 border-t border-[#D6D6D0] py-4 md:col-span-4">
            <div className="flex gap-4">
              <span className="font-mono text-[11px] text-[#5C5C56]">{String(i + 1).padStart(2, '0')}</span>
              <div><div className="font-grotesk text-[20px] font-semibold tracking-[-0.03em]">{t}</div><p className="mt-1 text-[14px] leading-snug text-[#5C5C56]">{d}</p></div>
            </div>
          </li>
        ))}
      </ol>
    </Section>
  )
}

/* ───────────────────────── 05 Voice ───────────────────────── */

const VOICE = [
  ['Say what it does.', 'Converted to GIF. 2.4 MB.', 'Your masterpiece is ready to shine!'],
  ['Number things.', '793 routes. 43 ms to open.', 'Tons of formats, blazing fast.'],
  ['Use the imperative.', 'Drag a file. Press ⇧. Drop.', 'anyfmt empowers you to effortlessly…'],
  ['Name the file.', "Can't open locked.pdf.", 'Oops! Something went wrong.'],
  ['No adjective we can\'t measure.', 'Runs on your Mac. 0 network calls.', 'Seamless, secure, next-gen privacy.'],
]

const MICRO = [
  ['Toast · done', 'Saved clip.gif', '2.4 MB · 15 fps · 0.9 s'],
  ['Toast · batch', 'Converted 12 files to JPG', '38.1 MB → 9.4 MB'],
  ['Error', "Can't convert locked.pdf", "It's password-protected. Unlock it, then drop again."],
  ['Error · disk', 'Not enough space for clip.mp4', 'Needs 1.2 GB. Free some space or pick another folder.'],
  ['Empty · Float', 'Float is empty.', 'Drag a file here to hold it.'],
  ['Empty · presets', 'No presets yet.', 'Set options on any wedge, then press ⌘S.'],
  ['Permission', 'anyfmt needs Accessibility.', 'It reads which key you press while you drag. Nothing else.'],
  ['Button', 'Convert ⏎', 'Not “Let\'s go!”, not “Magic”.'],
]

function VoiceSection() {
  return (
    <Section id="voice" n="05" kicker="Voice" title={<>Factual.<br />Numbered.<br />Imperative.</>} caption="Write like a label on a machine. If a sentence would survive on a museum caption, keep it.">
      <div className="border-b border-[#0B0B0B]">
        {VOICE.map(([p, d, x], i) => (
          <div key={p} className={cn(grid, 'gap-y-3 border-t border-[#0B0B0B] py-6')}>
            <span className="col-span-1 font-mono text-[11px] text-[#5C5C56] md:col-span-1">{String(i + 1).padStart(2, '0')}</span>
            <div className="col-span-3 font-grotesk text-[26px] font-semibold leading-none tracking-[-0.04em] md:col-span-4 md:text-[34px]">{p}</div>
            <div className="col-span-4 flex items-start gap-3 md:col-span-4">
              <span className="mt-0.5 grid size-5 shrink-0 place-items-center bg-[#0B0B0B] font-mono text-[10px] font-bold text-[#F4F4F1]">✓</span>
              <span className="text-[17px] font-medium">{d}</span>
            </div>
            <div className="col-span-4 flex items-start gap-3 md:col-span-3">
              <span className="mt-0.5 grid size-5 shrink-0 place-items-center bg-[#FF3D2E] font-mono text-[10px] font-bold text-[#0B0B0B]">✕</span>
              <span className="text-[15px] text-[#5C5C56] line-through decoration-[#FF3D2E] decoration-[1.5px]">{x}</span>
            </div>
          </div>
        ))}
      </div>
      <Sub n="05.1" title="Microcopy" note="Title says what happened to which file. Second line says what to do next, or the numbers." />
      <div className="grid grid-cols-1 gap-px border border-[#D6D6D0] bg-[#D6D6D0] sm:grid-cols-2 lg:grid-cols-4">
        {MICRO.map(([k, t, s]) => (
          <div key={k} className="bg-white p-4">
            <Mono className="text-[10px] text-[#5C5C56]">{k}</Mono>
            <div className="mt-4 font-grotesk text-[17px] font-semibold tracking-[-0.02em]">{t}</div>
            <div className="mt-1 text-[13px] leading-snug text-[#5C5C56]">{s}</div>
          </div>
        ))}
      </div>
    </Section>
  )
}

/* ───────────────────────── 06 Motion ───────────────────────── */

function useLoop(ms: number) {
  const reduce = useReducedMotion()
  const [t, setT] = useState(0)
  useEffect(() => {
    if (isShot || reduce) return
    const id = setInterval(() => setT((x) => x + 1), ms)
    return () => clearInterval(id)
  }, [ms, reduce])
  return t
}

function DemoWipe() {
  const t = useLoop(2200)
  return (
    <div className="relative h-full w-full overflow-hidden">
      <motion.div key={t} className="absolute inset-0 grid place-items-center bg-[#0B0B0B]"
        initial={isShot ? false : { clipPath: 'inset(0 100% 0 0)' }} animate={{ clipPath: 'inset(0 0% 0 0)' }} transition={{ duration: 0.7, ease: EASE }}>
        <span className="font-grotesk text-[44px] font-semibold tracking-[-0.06em] text-[#F4F4F1]">Wipe.</span>
      </motion.div>
    </div>
  )
}
function DemoSnap() {
  const t = useLoop(520)
  return <GridWheel segments={SETS.actions} size={180} active={isShot ? 1 : t % 6} interactive={false} showIndex={false} hub="⌃" />
}
function DemoCount() {
  const t = useLoop(3000)
  const vals = ['793', '043', '026']
  return <div className="font-grotesk text-[84px] font-semibold leading-none tracking-[-0.06em]"><Odometer key={t} value={vals[t % 3]} replay={t} /></div>
}
function DemoDraw() {
  const t = useLoop(2600)
  return (
    <svg key={t} viewBox="0 0 200 140" className="h-full w-full" aria-hidden>
      {[20, 50, 80, 110].map((y, i) => (
        <motion.line key={y} x1="10" x2="190" y1={y} y2={y} stroke={i === 2 ? C.red : C.ink} strokeWidth={i === 2 ? 3 : 1}
          initial={isShot ? false : { pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.6, ease: EASE, delay: i * 0.12 }} />
      ))}
      {[40, 100, 160].map((x, i) => (
        <motion.line key={x} y1="10" y2="130" x1={x} x2={x} stroke={C.rule}
          initial={isShot ? false : { pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.5, ease: EASE, delay: 0.5 + i * 0.1 }} />
      ))}
    </svg>
  )
}

function Curve() {
  const [x1, y1, x2, y2] = EASE
  const P = (x: number, y: number) => `${20 + x * 260},${280 - y * 260}`
  return (
    <svg viewBox="0 0 300 300" className="h-auto w-full max-w-[320px]" role="img" aria-label="Easing curve cubic-bezier(0.7, 0, 0.2, 1)">
      <rect x="20" y="20" width="260" height="260" fill="none" stroke={C.rule} />
      {[0.25, 0.5, 0.75].map((k) => <g key={k}><line x1={20 + k * 260} x2={20 + k * 260} y1="20" y2="280" stroke={C.rule} strokeDasharray="2 4" /><line y1={20 + k * 260} y2={20 + k * 260} x1="20" x2="280" stroke={C.rule} strokeDasharray="2 4" /></g>)}
      <line x1="20" y1="280" x2={20 + x1 * 260} y2={280 - y1 * 260} stroke={C.ink2} />
      <line x1="280" y1="20" x2={20 + x2 * 260} y2={280 - y2 * 260} stroke={C.ink2} />
      <path d={`M${P(0, 0)} C${P(x1, y1)} ${P(x2, y2)} ${P(1, 1)}`} fill="none" stroke={C.red} strokeWidth="3" />
      <rect x={20 + x1 * 260 - 4} y={280 - y1 * 260 - 4} width="8" height="8" fill={C.ink} />
      <rect x={20 + x2 * 260 - 4} y={280 - y2 * 260 - 4} width="8" height="8" fill={C.ink} />
      <text x="20" y="298" style={{ fontFamily: '"JetBrains Mono Variable", monospace', fontSize: 11 }} fill={C.ink}>cubic-bezier(.7, 0, .2, 1)</text>
    </svg>
  )
}

function MotionSection() {
  const demos: [string, string, ReactNode][] = [
    ['M1 · Wipe', 'Things enter by wiping in from the left. No fades, no blur, no float.', <DemoWipe />],
    ['M2 · Snap', 'Selection jumps wedge to wedge. 0 ms colour change; the pointer is the animation.', <DemoSnap />],
    ['M3 · Count', 'Numbers roll on drums, each digit a little slower than the last.', <DemoCount />],
    ['M4 · Draw', 'Rules draw themselves, then the grid. Construction before content.', <DemoDraw />],
  ]
  return (
    <Section id="motion" n="06" kicker="Motion & materials" title={<>Mechanical.<br />Exact. Then still.</>} caption="One curve for everything. Fast in, hard stop. Nothing bounces, nothing drifts, nothing glows.">
      <div className="grid grid-cols-1 gap-px border border-[#0B0B0B] bg-[#0B0B0B] sm:grid-cols-2 lg:grid-cols-4">
        {demos.map(([k, d, node]) => (
          <div key={k} className="flex flex-col bg-[#F4F4F1]">
            <div className="grid h-[220px] place-items-center overflow-hidden border-b border-[#D6D6D0] bg-white">{node}</div>
            <div className="p-4">
              <Mono>{k}</Mono>
              <p className="mt-2 text-[13px] leading-snug text-[#5C5C56]">{d}</p>
            </div>
          </div>
        ))}
      </div>
      <div className={cn(grid, 'mt-6 gap-y-6')}>
        <div className="col-span-4 flex justify-center border border-[#D6D6D0] bg-white p-6 md:col-span-4"><Curve /></div>
        <div className="col-span-4 md:col-span-4">
          <Mono className="text-[#5C5C56]">Table 06.1 — Durations</Mono>
          <table className="mt-3 w-full border-collapse font-mono text-[12px]">
            <tbody>
              {[['Key press', '80 ms', 'linear'], ['Wheel open', '140 ms', 'ease'], ['Wedge stagger', '22 ms', 'per wedge'], ['UI state', '240 ms', 'ease'], ['Section wipe', '700 ms', 'ease'], ['Counter', '1.1 s + 0.22 s', 'per digit']].map(([a, b, c]) => (
                <tr key={a} className="border-t border-[#D6D6D0]"><td className="py-2.5">{a}</td><td className="py-2.5 text-right font-semibold tabular-nums">{b}</td><td className="py-2.5 pl-4 text-right text-[#5C5C56]">{c}</td></tr>
              ))}
            </tbody>
          </table>
          <p className="mt-4 text-[13px] leading-snug text-[#5C5C56]">Reduced motion: wipes, drums and draws render in their final state. The wheel still snaps; it was never animated.</p>
        </div>
        <div className="col-span-4 grid grid-cols-2 gap-px border border-[#D6D6D0] bg-[#D6D6D0] md:col-span-4">
          {[
            ['Paper', <div className="size-14 bg-[#F4F4F1]" />, 'Matte. No texture, no noise.'],
            ['Hairline', <div className="h-px w-14 bg-[#0B0B0B]" />, '1 px ink or rule. Never 2.'],
            ['Panel', <div className="size-14 rounded-[10px] border border-[#D6D6D0] bg-white shadow-[0_24px_48px_-24px_rgba(0,0,0,.28)]" />, 'White, 1 px rule, one soft drop.'],
            ['No glass', <div className="relative size-14 border border-dashed border-[#BDBDB6]"><span className="absolute inset-0 grid place-items-center text-[18px] font-bold text-[#FF3D2E]">✕</span></div>, 'No blur, glow or gradient.'],
          ].map(([k, node, d]) => (
            <div key={k as string} className="flex flex-col bg-white p-4">
              <div className="grid h-16 place-items-center">{node}</div>
              <Mono className="mt-3">{k as string}</Mono>
              <p className="mt-1 text-[12px] leading-snug text-[#5C5C56]">{d as string}</p>
            </div>
          ))}
        </div>
      </div>
    </Section>
  )
}

/* ───────────────────────── 07 Landing preview ───────────────────────── */

function Scaled({ children, w = 1440, h = 900 }: { children: ReactNode; w?: number; h?: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const [k, setK] = useState(0.5)
  useLayoutEffect(() => {
    const el = ref.current!
    const f = () => setK(el.clientWidth / w)
    f()
    const ro = new ResizeObserver(f)
    ro.observe(el)
    return () => ro.disconnect()
  }, [w])
  return (
    <div ref={ref} className="relative w-full overflow-hidden" style={{ height: h * k }}>
      <div className="pointer-events-none absolute left-0 top-0 origin-top-left" style={{ width: w, height: h, transform: `scale(${k})` }}>{children}</div>
    </div>
  )
}

function LandingSection() {
  return (
    <section id="landing" data-sec="landing" className="relative scroll-mt-12 pt-16 md:pt-24">
      <div className={wrap}>
        <SectionHead n="07" kicker="Landing" title={<>The page,<br />on the grid.</>} caption="The full page lives on its own route. Below: the first screen in a frame, then the marquee and the features at full size." />
        <div className={cn(grid, 'mt-12 gap-y-6 md:mt-16')}>
          <div className="group relative col-span-4 md:col-span-9">
            <Link to="/d/grid/landing" className="absolute inset-0 z-20" aria-label="Open the landing page" />
            <div className="relative border border-[#0B0B0B] bg-white">
              <div className="flex items-center justify-between border-b border-[#0B0B0B] px-3 py-2">
                <div className="flex gap-1.5">{[0, 1, 2].map((i) => <span key={i} className="size-2.5 rounded-full border border-[#0B0B0B]" />)}</div>
                <span className="font-mono text-[10px] text-[#5C5C56]">halo.app</span>
                <span className="flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.08em] group-hover:text-[#FF3D2E]">Open <Arrow /></span>
              </div>
              <Scaled w={1440} h={880}>
                <div className="relative h-full overflow-hidden bg-[#F4F4F1]">
                  <GridOverlay fixed={false} />
                  <div className="relative z-[1]"><Nav sticky={false} /><Hero embedded /></div>
                </div>
              </Scaled>
            </div>
            <CropMarks inset={-14} />
            <div className="mt-3 flex justify-between font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">
              <span>Fig. 07.1 — First screen, 1440 × 880</span><span className="hidden sm:inline">/#/d/grid/landing</span>
            </div>
          </div>
          <div className="col-span-4 flex flex-col md:col-span-3">
            <Mono className="text-[#5C5C56]">Table 07.1 — Page order</Mono>
            <ol className="mt-3 border-b border-[#0B0B0B] font-mono text-[12px]">
              {['Hero · live drag', 'Format marquee', 'Three keys, three wheels', 'Fig. 02 · annotated wheel', 'Features', 'Numbers · 793', 'Privacy table', 'Agents · terminal', 'Pricing', 'FAQ', 'Drop. · CTA'].map((t, i) => (
                <li key={t} className="flex gap-3 border-t border-[#D6D6D0] py-2 first:border-[#0B0B0B]"><span className="text-[#5C5C56]">{String(i + 1).padStart(2, '0')}</span>{t}</li>
              ))}
            </ol>
            <Link to="/d/grid/landing" className="group/btn mt-6 inline-flex h-11 items-center justify-between gap-3 bg-[#0B0B0B] px-5 font-grotesk text-[15px] font-medium text-[#F4F4F1] transition-colors hover:bg-[#FF3D2E] hover:text-[#0B0B0B]">Open the landing <Arrow /></Link>
          </div>
        </div>
      </div>
      <div className="mt-16"><Formats /></div>
      <Bento />
    </section>
  )
}

/* ───────────────────────── 09 App surfaces ───────────────────────── */

function Desk({ children, className, label }: { children: ReactNode; className?: string; label: string }) {
  return (
    <figure className={cn('relative flex flex-col border border-[#D6D6D0] bg-[#E9E9E4]', className)}>
      <div className="absolute inset-0 opacity-70" style={{ backgroundImage: `linear-gradient(${C.rule} 1px, transparent 1px), linear-gradient(90deg, ${C.rule} 1px, transparent 1px)`, backgroundSize: '24px 24px' }} />
      <div className="relative grid flex-1 grid-cols-[minmax(0,1fr)] place-items-center p-4 md:p-8">{children}</div>
      <figcaption className="relative border-t border-[#D6D6D0] bg-[#F4F4F1] px-3 py-2 font-mono text-[10px] uppercase tracking-[0.08em] text-[#5C5C56]">{label}</figcaption>
    </figure>
  )
}

function AppSection() {
  const wheels = [
    { k: '⇧', w: 'Convert', set: SETS.convert, hub: 'clip.mov', sub: '8 FORMATS', a: 0 },
    { k: '⌘', w: 'Tools', set: SETS.tools, hub: 'photo.heic', sub: '8 TOOLS', a: 1 },
    { k: '⌃', w: 'Actions', set: SETS.actions, hub: 'report.pdf', sub: '6 ACTIONS', a: 1 },
  ]
  return (
    <Section id="app" n="09" kicker="App surfaces" title={<>The app,<br />at 1 : 1.</>} caption="Native macOS wearing the brand: flat paper, black disc, one red. Point at the wheels; click the chips.">
      <Sub n="09.1" title="The three wheels" note="Real size: 320 pt. Paper wedges on a black disc. The armed wedge is vermilion with black text (5.6 : 1). Labels never rotate." />
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {wheels.map((x) => (
          <Desk key={x.w} label={`${x.k} ${x.w} · ${x.set.length} wedges · 320 pt`}>
            <div className="relative">
              <GridWheel segments={x.set} size={320} hub={x.hub} hubSub={x.sub} title={`${x.w} wheel`} rest={x.a} />
              <div className="absolute -left-2 -top-2"><FileTile ext={x.hub.split('.')[1].toUpperCase().slice(0, 4)} size={30} /></div>
            </div>
          </Desk>
        ))}
      </div>

      <Sub n="09.2" title="Options panel" note="Opens beside the armed wedge on a long hover. Every chip shows its own size estimate; the total updates instantly." />
      <Desk label="GIF options · chips 10 / 15 / 24 / 30 fps with per-chip estimate">
        <div className="flex flex-col items-center gap-6 md:flex-row md:items-start">
          <GridWheel segments={SETS.convert} size={300} active={0} interactive={false} hub="clip.mov" hubSub="8 FORMATS" />
          <OptionsPanel />
        </div>
      </Desk>

      <Sub n="09.3" title="Progress, Float, menu bar" />
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-12">
        <Desk className="lg:col-span-7" label="Progress HUD · bottom centre of the active screen">
          <div className="flex w-full flex-col items-center gap-4">
            <ProgressHUD />
            <ProgressHUD fixed={0.18} />
          </div>
        </Desk>
        <Desk className="lg:col-span-5" label="Float shelf · holds files between drags">
          <FloatShelf />
        </Desk>
        <Desk className="lg:col-span-7" label="Menu-bar menu">
          <MenuBarMenu />
        </Desk>
        <Desk className="lg:col-span-5" label="Toasts · done and error">
          <div className="flex w-full flex-col items-center gap-4">
            <DoneToast />
            <ErrorToast />
          </div>
        </Desk>
      </div>
      <div className="mt-6 flex flex-wrap items-center justify-between gap-4 border-t border-[#0B0B0B] pt-4">
        <Mono className="text-[#5C5C56]">{product.platform} · {product.licence}</Mono>
        <Link to="/d/grid/landing" className="group/btn inline-flex h-11 items-center gap-3 bg-[#0B0B0B] px-5 font-grotesk text-[15px] font-medium text-[#F4F4F1] transition-colors hover:bg-[#FF3D2E] hover:text-[#0B0B0B]">See the landing page <Arrow /></Link>
      </div>
    </Section>
  )
}

/* ───────────────────────── Book ───────────────────────── */

const only = typeof location !== 'undefined' ? new URLSearchParams(location.search).get('only')?.split(',') : undefined
const show = (id: string) => !only || only.includes(id)

export function BrandBook() {
  return (
    <div className="relative min-h-screen overflow-x-clip bg-[#F4F4F1] pb-24 font-sans text-[#0B0B0B] selection:bg-[#FF3D2E] selection:text-[#0B0B0B]">
      <GridOverlay />
      <div className="relative z-[1]">
        <BookNav />
        {show('cover') && <Cover />}
        {show('logo') && <LogoSection />}
        {show('colour') && <ColourSection />}
        {show('type') && <TypeSection />}
        {show('voice') && <VoiceSection />}
        {show('motion') && <MotionSection />}
        {show('landing') && <LandingSection />}
        {show('onboarding') && <Section id="onboarding" n="08" kicker="Onboarding" title={<>Six windows.<br />Five decisions.</>} caption="Square-cornered windows, numbered steps, one action per screen. The bar at the bottom always says where you are.">
          <Onboarding />
        </Section>}
        {show('app') && <AppSection />}
      </div>
    </div>
  )
}
