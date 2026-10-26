import { motion, useReducedMotion } from 'motion/react'
import { ArrowUpRight, Check, X } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../../shared/cn'
import { Reveal, isShot } from '../../shared/kit'
import { AppSurfaces } from './AppSurfacesSection'
import { CobaltWheel, Hub } from './CobaltWheel'
import { Agents, Hero, Nav, Scoreboard } from './Landing'
import { AppIcon, Lockup, Mark, MenuGlyph, SpeedLines, Wordmark, arc } from './Logo'
import { Onboarding } from './Onboarding'
import { C, FLAME_GRAD, cssVars, tokenTable } from './tokens'
import { Bands, Eyebrow, RaceNumber, SkewOnScroll, Sticker, convertSegs, outline } from './ui'
import { meta } from './meta'

const W = 'mx-auto w-full max-w-[1280px] px-4 sm:px-6 lg:px-10'

const NAV = [
  ['cover', 'Cover'], ['logo', 'Logo'], ['colour', 'Colour'], ['type', 'Type'], ['voice', 'Voice'],
  ['motion', 'Motion'], ['landing', 'Landing'], ['onboarding', 'Onboarding'], ['app', 'App'],
] as const

function BookNav() {
  const [active, setActive] = useState('cover')
  useEffect(() => {
    const els = NAV.map(([id]) => document.getElementById(id)).filter(Boolean) as HTMLElement[]
    const io = new IntersectionObserver((es) => es.forEach((e) => e.isIntersecting && setActive(e.target.id)), { rootMargin: '-45% 0px -50% 0px' })
    els.forEach((e) => io.observe(e))
    return () => io.disconnect()
  }, [])
  return (
    <div className="sticky top-0 z-50 border-b font-geist backdrop-blur-xl" style={{ background: 'rgba(5,10,46,.82)', borderColor: 'rgba(233,238,255,.1)' }}>
      <div className={cn(W, 'flex h-14 items-center gap-4')}>
        <a href="#cover" onClick={(e) => { e.preventDefault(); document.getElementById('cover')?.scrollIntoView({ behavior: 'smooth' }) }} className="shrink-0"><Lockup size={20} /></a>
        <span className="hidden shrink-0 font-mono text-[10px] uppercase tracking-[0.18em] text-[#E9EEFF]/50 md:block">Brand book · Cobalt</span>
        <nav className="no-scrollbar -mr-4 ml-auto flex items-center gap-0.5 overflow-x-auto pr-4" aria-label="Sections">
          {NAV.map(([id, l], i) => (
            <a key={id} href={`#${id}`} onClick={(e) => { e.preventDefault(); document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' }) }}
               className="flex shrink-0 items-center gap-1.5 rounded-[9px] px-2.5 py-1.5 font-anton text-[13px] uppercase tracking-[0.06em] transition-colors"
               style={active === id ? { background: C.flame, color: C.midnight } : { color: 'rgba(233,238,255,.7)' }}>
              <span className="font-mono text-[9px] opacity-60">{String(i).padStart(2, '0')}</span>{l}
            </a>
          ))}
        </nav>
      </div>
    </div>
  )
}

function SectionHead({ n, id, title, kicker, children, light }: { n: string; id: string; title: ReactNode; kicker: string; children?: ReactNode; light?: boolean }) {
  return (
    <div id={id} className="scroll-mt-14 pt-24 sm:pt-32">
      <div className="flex items-center gap-4">
        <RaceNumber n={n} size={46} tone="flame" />
        <Eyebrow style={{ color: light ? C.midnight : C.ice, opacity: 0.7 }}>{kicker}</Eyebrow>
      </div>
      <h2 className="mt-5 max-w-[16ch] font-anton uppercase leading-[0.86]" style={{ fontSize: 'clamp(54px, 8vw, 128px)' }}>{title}</h2>
      {children && <div className="mt-6 max-w-[56ch] font-geist text-[17px] leading-relaxed text-[#E9EEFF]/80">{children}</div>}
    </div>
  )
}

function Panel({ children, className, style, label }: { children: ReactNode; className?: string; style?: React.CSSProperties; label?: string }) {
  return (
    <div className={cn('relative overflow-hidden rounded-[22px]', className)} style={{ boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)', ...style }}>
      {label && <div className="absolute left-4 top-4 z-10 font-mono text-[10px] font-semibold uppercase tracking-[0.18em] opacity-60">{label}</div>}
      {children}
    </div>
  )
}

/* ───────────── Cover ───────────── */
function Cover() {
  const ref = useRef<HTMLElement>(null)
  return (
    <section ref={ref} id="cover" className="relative isolate overflow-hidden" style={{ background: C.cobalt, color: C.ice }}>
      <Bands target={ref} />
      <div className={cn(W, 'relative z-10 flex flex-wrap items-start justify-between gap-6 pt-16')}>
        <div className="font-mono text-[11px] uppercase leading-[1.9] tracking-[0.18em]">
          <div>anyfmt · Brand direction 04</div>
          <div className="opacity-70">{meta.lineage}</div>
        </div>
        <div className="flex gap-2">
          {meta.palette.map((p) => <span key={p.hex} className="size-6 rounded-[6px]" style={{ background: p.hex, boxShadow: 'inset 0 0 0 1.5px rgba(233,238,255,.35)' }} />)}
        </div>
      </div>
      <div className="relative z-10 h-[40vw] min-h-[180px] select-none overflow-hidden">
        <SkewOnScroll max={14} className="absolute -left-[3vw] top-[2vw]">
          <div className="whitespace-nowrap font-anton uppercase leading-[0.8]" style={{ fontSize: '42vw', letterSpacing: '-0.02em' }}>
            Cobalt<span style={{ color: C.flame }}>.</span>
          </div>
        </SkewOnScroll>
      </div>
      <div className={cn(W, 'relative z-10 grid gap-10 pb-20 pt-8 lg:grid-cols-[1.4fr_1fr] lg:items-end')}>
        <div>
          <p className="font-anton uppercase leading-[0.9]" style={{ fontSize: 'clamp(36px, 4.6vw, 72px)' }}>Loud, fast, kinetic.<br />Conversion as a <span style={{ color: C.flame }}>sport.</span></p>
          <p className="mt-6 max-w-[52ch] font-geist text-[17px] leading-relaxed">
            anyfmt turns a drag into a hit: press a key, a wheel opens, you take the wedge. Cobalt dresses that moment like a race:
            full-bleed blue bands that slide as you scroll, a condensed wordmark too big for the page, and one flame-orange hit per view.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-4 lg:justify-end">
          <Sticker rotate={-8} className="text-[30px]">0 uploads</Sticker>
          <Sticker tone="midnight" rotate={5} className="text-[30px]">43 ms</Sticker>
          <RaceNumber n="04" size={88} />
        </div>
      </div>
    </section>
  )
}

/* ───────────── Logo ───────────── */
function LogoSection() {
  const dos = [
    { ok: true, t: 'Ice ring, flame notch, on blue or midnight.', el: <div className="grid h-full place-items-center" style={{ background: C.cobalt }}><Mark size={90} /></div> },
    { ok: true, t: 'Midnight ring on flame. The notch turns ice.', el: <div className="grid h-full place-items-center" style={{ background: C.flame }}><Mark size={90} ring={C.midnight} notch={C.ice} /></div> },
    { ok: false, t: 'No second flame. The ring is never the hit.', el: <div className="grid h-full place-items-center" style={{ background: C.ultra }}><Mark size={90} ring={C.flame} notch={C.flame} /></div> },
    { ok: false, t: 'Never stand it up straight or spin it.', el: <div className="grid h-full place-items-center" style={{ background: C.cobalt }}><Mark size={90} slant={false} style={{ transform: 'rotate(140deg)' }} /></div> },
    { ok: false, t: 'No outlines, no gradients on the mark.', el: <div className="grid h-full place-items-center" style={{ background: C.ultra }}><svg width="90" height="90" viewBox="0 0 100 100"><g transform="translate(50 50) skewX(-12) translate(-50 -50)"><path d={arc(50, 50, 25, 41, 72, 378)} fill="none" stroke={C.ice} strokeWidth="2" /><path d={arc(55, 45, 25, 41, 26, 64)} fill="none" stroke={C.flame} strokeWidth="2" /></g></svg></div> },
    { ok: false, t: 'No flame on cobalt for anything small.', el: <div className="grid h-full place-items-center" style={{ background: C.cobalt }}><Lockup size={30} color={C.flame} notch={C.flame} /></div> },
  ]
  return (
    <div className={W}>
      <SectionHead n="01" id="logo" kicker="Mark, wordmark, lockups" title={<>The ring <span style={{ color: C.flame }}>takes the hit.</span></>}>
        The mark is the wheel seen at speed: a ring slanted 12° forward, with one wedge knocked out and lifted, exactly the way the hovered wedge
        jumps out in the app. The wordmark is Anton, slanted 8°, finished with a flame cut instead of a full stop.
      </SectionHead>

      <div className="mt-12 grid gap-3 lg:grid-cols-[1.25fr_1fr]">
        <Panel className="min-h-[460px]" style={{ background: C.cobalt }} label="Primary mark">
          <Bands count={5} />
          <div className="relative grid h-full min-h-[460px] place-items-center">
            <Mark size={300} glow />
          </div>
        </Panel>
        <Panel className="min-h-[460px] p-6" style={{ background: C.midnight }} label="Construction">
          <svg viewBox="0 0 300 300" className="mx-auto mt-6 w-full max-w-[340px]" aria-label="Mark construction">
            <g stroke={C.steel} strokeOpacity=".35" fill="none">
              <circle cx="150" cy="150" r="75" strokeDasharray="3 4" /><circle cx="150" cy="150" r="123" strokeDasharray="3 4" />
              <line x1="150" y1="10" x2="150" y2="290" /><line x1="10" y1="150" x2="290" y2="150" />
              <line x1="150" y1="150" x2="255" y2="45" strokeDasharray="2 3" />
            </g>
            <g transform="translate(150 150) skewX(-12) translate(-150 -150)">
              <path d={arc(150, 150, 75, 123, 72, 378)} fill={C.ice} fillOpacity=".92" />
              <path d={arc(150 + 21 * Math.sin(Math.PI / 4), 150 - 21 * Math.cos(Math.PI / 4), 75, 123, 26, 64)} fill={C.flame} />
            </g>
            <g fontFamily="JetBrains Mono Variable, monospace" fontSize="9" fill={C.ice} fillOpacity=".75">
              <text x="12" y="22">SLANT 12°</text><text x="206" y="22">LIFT 7u</text>
              <text x="12" y="286">RING 25–41u</text><text x="204" y="286">GAP 72°→18°</text>
            </g>
          </svg>
          <ul className="mt-6 grid gap-1.5 font-geist text-[13px] text-[#E9EEFF]/75">
            <li><b className="text-[#E9EEFF]">Ring</b>: the wheel. 100u grid, radii 25u and 41u.</li>
            <li><b className="text-[#E9EEFF]">Notch</b>: one 38° wedge, lifted 7u along its bisector at 45°.</li>
            <li><b className="text-[#E9EEFF]">Slant</b>: 12° skew. Speed, not rotation.</li>
          </ul>
        </Panel>
      </div>

      <div className="mt-3 grid gap-3 md:grid-cols-3">
        <Panel className="grid min-h-[220px] place-items-center p-8" style={{ background: C.midnight }} label="Wordmark"><Wordmark size={110} /></Panel>
        <Panel className="grid min-h-[220px] place-items-center p-8" style={{ background: C.ultra }} label="Horizontal lockup"><Lockup size={58} /></Panel>
        <Panel className="grid min-h-[220px] place-items-center p-8" style={{ background: C.cobalt }} label="Motion lockup">
          <div className="flex items-center"><SpeedLines size={92} /><Mark size={92} /><span className="ml-3"><Wordmark size={64} /></span></div>
        </Panel>
      </div>

      <div className="mt-3 grid gap-3 md:grid-cols-4">
        {[
          { bg: C.ice, ring: C.midnight, notch: C.flame, l: 'On ice' },
          { bg: C.midnight, ring: C.ice, notch: C.flame, l: 'On midnight' },
          { bg: C.cobalt, ring: C.ice, notch: C.flame, l: 'On cobalt' },
          { bg: C.flame, ring: C.midnight, notch: C.ice, l: 'On flame' },
        ].map((v) => (
          <Panel key={v.l} className="grid min-h-[200px] place-items-center p-6" style={{ background: v.bg, color: v.ring }} label={v.l}>
            <div className="mt-4"><Lockup size={40} color={v.ring} notch={v.notch} /></div>
          </Panel>
        ))}
      </div>

      <div className="mt-3 grid gap-3 lg:grid-cols-2">
        <Panel className="p-6" style={{ background: C.midnight }} label="Clear space & minimum size">
          <div className="mt-8 flex flex-wrap items-center justify-center gap-10">
            <div className="relative p-[38px]" style={{ outline: `1px dashed ${C.flame}`, outlineOffset: -1 }}>
              <div className="absolute left-0 top-1/2 h-px w-[38px]" style={{ background: C.flame }} />
              <span className="absolute left-1 top-[calc(50%-14px)] font-mono text-[9px]" style={{ color: C.flame }}>½ h</span>
              <div style={{ outline: '1px solid rgba(233,238,255,.2)' }}><Lockup size={44} /></div>
            </div>
            <div className="flex items-end gap-6">
              {[16, 24, 32].map((s) => (
                <div key={s} className="flex flex-col items-center gap-2"><Mark size={s} /><span className="font-mono text-[10px] opacity-60">{s}px</span></div>
              ))}
              <div className="flex flex-col items-center gap-2"><Lockup size={14} /><span className="font-mono text-[10px] opacity-60">lockup 72px min</span></div>
            </div>
          </div>
          <p className="mt-6 font-geist text-[13px] text-[#E9EEFF]/70">Keep half the wordmark's height clear on every side. Mark alone: 16px minimum. Below 24px drop the slant (see the menu bar glyph).</p>
        </Panel>
        <Panel className="p-6" style={{ background: 'linear-gradient(180deg, #0B1A8C, #050A2E)' }} label="App icon · 1024">
          <div className="mt-6 flex flex-wrap items-end justify-center gap-6">
            <AppIcon size={230} />
            <div className="flex items-end gap-4">
              {[128, 64, 32].map((s) => <div key={s} className="flex flex-col items-center gap-2"><AppIcon size={s} /><span className="font-mono text-[10px] opacity-60">{s}</span></div>)}
            </div>
          </div>
        </Panel>
      </div>

      <div className="mt-3 grid gap-3 lg:grid-cols-[1fr_1.4fr]">
        <Panel className="p-6" style={{ background: C.midnight }} label="Menu bar glyph · template">
          <div className="mt-8 grid gap-3">
            {[{ bg: '#ECECF0', fg: '#000', l: 'Light menu bar' }, { bg: '#1C1C22', fg: '#fff', l: 'Dark menu bar' }].map((m) => (
              <div key={m.l} className="flex h-8 items-center justify-end gap-4 rounded-[8px] px-3 font-geist text-[12px]" style={{ background: m.bg, color: m.fg }}>
                <span className="mr-auto font-mono text-[10px] opacity-50">{m.l}</span>
                <span className="opacity-60">Wi-Fi</span>
                <MenuGlyph size={16} color={m.fg} />
                <span className="grid h-[22px] place-items-center rounded-[5px] px-1" style={{ background: m.fg === '#000' ? 'rgba(0,0,0,.12)' : 'rgba(255,255,255,.2)' }}><MenuGlyph size={18} color={m.fg} /></span>
                <span className="opacity-60">9:41</span>
              </div>
            ))}
            <div className="mt-3 flex items-end justify-center gap-8">
              {[16, 18].map((s) => (
                <div key={s} className="flex flex-col items-center gap-2">
                  <div className="grid place-items-center rounded-[8px] p-2" style={{ background: '#ECECF0', imageRendering: 'pixelated' }}>
                    <div style={{ transform: 'scale(5)', transformOrigin: 'center', width: s, height: s, margin: s * 2 }}><MenuGlyph size={s} /></div>
                  </div>
                  <span className="font-mono text-[10px] opacity-60">{s}pt @5×</span>
                </div>
              ))}
            </div>
          </div>
        </Panel>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          {dos.map((d) => (
            <div key={d.t} className="overflow-hidden rounded-[18px]" style={{ boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)', background: C.midnight }}>
              <div className="h-[130px]">{d.el}</div>
              <div className="flex items-start gap-2 p-3 font-geist text-[12.5px] leading-snug">
                <span className="mt-0.5 grid size-4 shrink-0 place-items-center rounded-full" style={{ background: d.ok ? C.ice : C.flame, color: C.midnight }}>
                  {d.ok ? <Check size={11} strokeWidth={3.5} /> : <X size={11} strokeWidth={3.5} />}
                </span>
                <span className="text-[#E9EEFF]/85">{d.t}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

/* ───────────── Colour ───────────── */
function lum(hex: string) {
  const v = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
  return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
}
const ratio = (a: string, b: string) => { const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m); return (x + 0.05) / (y + 0.05) }

function ColourSection() {
  const pairs: [string, string, string, string][] = [
    ['Ice', C.ice, 'Midnight', C.midnight], ['Ice', C.ice, 'Ultramarine', C.ultra], ['Ice', C.ice, 'Cobalt', C.cobalt],
    ['Midnight', C.midnight, 'Flame', C.flame], ['Flame', C.flame, 'Midnight', C.midnight], ['Flame', C.flame, 'Cobalt', C.cobalt],
  ]
  return (
    <div className={W}>
      <SectionHead n="02" id="colour" kicker="Palette, roles, tokens" title={<>Four blues. <span style={{ color: C.flame }}>One flame.</span></>}>
        Blue is the field and it is everywhere, as bands. Flame is the hit: the hovered wedge, the main button, a sticker. If two things on screen are flame, one of them is wrong.
      </SectionHead>
      <div className="mt-12 flex h-[520px] overflow-hidden rounded-[24px] max-md:h-auto max-md:flex-col" style={{ boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}>
        {meta.palette.map((p, i) => {
          const dark = p.hex === C.ice || p.hex === C.flame
          return (
            <div key={p.hex} className={cn('relative flex flex-col justify-between p-5 max-md:min-h-[140px]', i === 0 ? 'flex-[1.6]' : i === 2 ? 'flex-[0.8]' : 'flex-1')}
                 style={{ background: p.hex, color: dark ? C.midnight : C.ice, boxShadow: p.hex === C.midnight ? 'inset 0 0 0 1px rgba(233,238,255,.16)' : undefined }}>
              <span className="font-mono text-[10px] font-semibold uppercase tracking-[0.18em] opacity-70">{String(i + 1).padStart(2, '0')}</span>
              <div>
                <div className="font-anton text-[40px] uppercase leading-none">{p.name}</div>
                <div className="mt-2 font-mono text-[12px] font-semibold">{p.hex}</div>
                <div className="mt-1 font-geist text-[13px] opacity-80">{p.role}</div>
              </div>
            </div>
          )
        })}
      </div>
      <div className="mt-3 grid gap-3 lg:grid-cols-[1fr_1.3fr]">
        <Panel className="p-6" style={{ background: C.midnight }} label="Contrast (WCAG 2.x)">
          <div className="mt-8 grid gap-2">
            {pairs.map(([fn, f, bn, b]) => {
              const r = ratio(f, b)
              const pass = r >= 4.5 ? 'AA' : r >= 3 ? 'AA large' : 'Graphic only'
              return (
                <div key={fn + bn} className="flex items-center gap-3 rounded-[12px] p-2 pr-3" style={{ background: 'rgba(233,238,255,.04)' }}>
                  <span className="grid h-10 w-14 place-items-center rounded-[8px] font-anton text-[18px]" style={{ background: b, color: f }}>Aa</span>
                  <span className="font-geist text-[13px] text-[#E9EEFF]/85">{fn} on {bn}</span>
                  <span className="ml-auto font-mono text-[12px] font-semibold tabular-nums">{r.toFixed(1)}:1</span>
                  <span className="w-[100px] whitespace-nowrap rounded-[6px] px-2 py-0.5 text-center font-mono text-[9.5px] font-semibold uppercase"
                        style={r >= 4.5 ? { background: C.ice, color: C.midnight } : r >= 3 ? { background: C.cobalt, color: C.ice } : { background: C.flame, color: C.midnight }}>{pass}</span>
                </div>
              )
            })}
          </div>
          <p className="mt-4 font-geist text-[12.5px] leading-relaxed text-[#E9EEFF]/65">Text on flame is always midnight. Flame on cobalt is for shapes and 48px+ display only. Body copy sits on midnight or ultramarine.</p>
        </Panel>
        <Panel className="overflow-x-auto p-6" style={{ background: C.midnight }} label="Semantic tokens">
          <table className="mt-8 w-full min-w-[520px] border-collapse font-geist text-[13px]">
            <thead><tr className="text-left font-mono text-[10px] uppercase tracking-[0.14em] text-[#E9EEFF]/50"><th className="pb-2 font-medium">Token</th><th className="pb-2 font-medium">Value</th><th className="pb-2 font-medium">Use</th></tr></thead>
            <tbody>
              {tokenTable.map((t) => (
                <tr key={t.token} className="border-t" style={{ borderColor: 'rgba(233,238,255,.08)' }}>
                  <td className="whitespace-nowrap py-2.5 pr-3 font-mono text-[12px]" style={{ color: C.ice }}>{t.token}</td>
                  <td className="py-2.5 pr-3"><span className="flex items-center gap-2 whitespace-nowrap font-mono text-[11.5px]">
                    <span className="size-4 rounded-[4px]" style={{ background: `var(${t.token.startsWith('--co-glow') ? '--co-hit' : t.token})`, boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.25)' }} />{t.value}</span></td>
                  <td className="py-2.5 text-[#E9EEFF]/70">{t.use}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Panel>
      </div>
    </div>
  )
}

/* ───────────── Type ───────────── */
function TypeSection() {
  const scale = [
    { n: 'Display', s: 'Anton 168 / 0.84 / −0.5%', px: 96, f: 'font-anton uppercase', t: 'Drag. Press.' },
    { n: 'H1', s: 'Anton 112 / 0.88', px: 64, f: 'font-anton uppercase', t: 'Take the wheel.' },
    { n: 'H2', s: 'Anton 54 / 1.0', px: 40, f: 'font-anton uppercase', t: 'Three keys, one wheel' },
    { n: 'H3', s: 'Anton 30 / 1.0 / +1%', px: 26, f: 'font-anton uppercase', t: 'Convert · Tools · Actions' },
    { n: 'Body', s: 'Geist 17 / 1.55 / 400', px: 17, f: 'font-geist', t: 'Drag a file in Finder. Press a key. A wheel of everything that file can become opens around your pointer.' },
    { n: 'Label', s: 'JetBrains Mono 11 / +20% / caps', px: 11, f: 'font-mono uppercase tracking-[0.2em]', t: 'Nº 03 · How it works' },
  ]
  return (
    <div className={W}>
      <SectionHead n="03" id="type" kicker="Anton · Geist · JetBrains Mono" title={<>Condensed. <span style={{ color: C.flame }}>Cranked.</span></>}>
        Anton does the shouting, always uppercase, always tight. Geist does the explaining, in sentence case. JetBrains Mono carries the numbers and the race labels.
      </SectionHead>
      <div className="mt-12 grid gap-3 lg:grid-cols-3">
        <Panel className="relative min-h-[380px] p-6 lg:col-span-2" style={{ background: C.cobalt }} label="Anton · display">
          <Bands count={6} />
          <div className="relative mt-10 font-anton uppercase leading-[0.98]" style={{ fontSize: 'clamp(72px, 10vw, 168px)' }}>
            <div>anyfmt <span style={{ color: C.flame }}>43</span></div>
            <div style={outline(C.ice, 2)}>MOV→GIF</div>
          </div>
        </Panel>
        <div className="grid gap-3">
          <Panel className="p-6" style={{ background: C.midnight }} label="Geist · text">
            <div className="mt-8 font-geist text-[44px] font-medium leading-none">Aa Gg 123</div>
            <p className="mt-3 font-geist text-[14px] leading-relaxed text-[#E9EEFF]/75">Quiet, precise, readable at 13px in a menu. Weights 400, 500, 600 only.</p>
          </Panel>
          <Panel className="p-6" style={{ background: C.ultra }} label="JetBrains Mono · specs">
            <div className="mt-8 font-mono text-[34px] font-semibold leading-none">43 ms</div>
            <p className="mt-3 font-mono text-[12px] leading-relaxed text-[#E9EEFF]/80">--to gif --json<br />793 routes · 26 tools</p>
          </Panel>
        </div>
      </div>
      <Panel className="mt-3 p-2 sm:p-4" style={{ background: C.midnight }}>
        {scale.map((s) => (
          <div key={s.n} className="grid items-baseline gap-2 border-b px-3 py-5 last:border-0 md:grid-cols-[150px_1fr]" style={{ borderColor: 'rgba(233,238,255,.08)' }}>
            <div>
              <div className="font-anton text-[16px] uppercase" style={{ color: C.flame }}>{s.n}</div>
              <div className="font-mono text-[10px] text-[#E9EEFF]/55">{s.s}</div>
            </div>
            <div className={cn('min-w-0 truncate leading-[0.95]', s.f)} style={{ fontSize: `min(${s.px}px, ${s.px / 6}vw + 14px)` }}>{s.t}</div>
          </div>
        ))}
      </Panel>
      <div className="mt-3 grid gap-3 md:grid-cols-3">
        {[
          ['Anton is never lowercase.', 'Uppercase, tracking 0 to +4%. Leading 0.84–0.9 on display, so lines lock together like a number board.'],
          ['One size jump, not five.', 'Display then body. Skip the middle sizes on marketing; the contrast is the point.'],
          ['Numbers go mono or Anton.', 'Specs, sizes and timings in JetBrains Mono. Scoreboard numbers in Anton. Never Geist.'],
        ].map(([h, b]) => (
          <Panel key={h} className="p-6" style={{ background: 'rgba(233,238,255,.04)' }}>
            <div className="font-anton text-[24px] uppercase leading-tight">{h}</div>
            <p className="mt-2 font-geist text-[14px] leading-relaxed text-[#E9EEFF]/70">{b}</p>
          </Panel>
        ))}
      </div>
    </div>
  )
}

/* ───────────── Voice ───────────── */
function VoiceSection() {
  const principles = [
    { h: 'Verbs first.', do: 'Drop it on GIF.', dont: 'You can now easily convert your files to GIF format.' },
    { h: 'Short is fast.', do: 'Done. Saved next to the original.', dont: 'Your conversion has completed successfully and the file is ready!' },
    { h: 'Numbers, not adjectives.', do: '43 ms from key to wheel.', dont: 'Blazingly fast, lightning quick conversions.' },
    { h: 'Loud type, calm facts.', do: 'YOUR FILES NEVER LEAVE THE MAC.', dont: 'REVOLUTIONARY PRIVACY-FIRST AI EXPERIENCE!!!' },
    { h: 'Own the miss.', do: "Can't read clip.mov. Nothing was changed.", dont: 'Oops! Something went wrong :(' },
  ]
  const micro = [
    { k: 'Toast · done', v: 'CLIP.GIF. DONE.', s: 'Saved next to the original.' },
    { k: 'Toast · preset', v: 'GIF · 15 FPS SAVED.', s: 'It is on the wheel now.' },
    { k: 'Error · read', v: "CAN'T READ IT.", s: 'clip.mov looks damaged. Nothing was changed.' },
    { k: 'Error · space', v: 'DISK IS FULL.', s: 'Free 2 GB and drop it again.' },
    { k: 'Empty · Float', v: 'SHELF IS EMPTY.', s: 'Hold ⌃ mid-drag and pick Float to park a file here.' },
    { k: 'Empty · presets', v: 'NO PRESETS YET.', s: 'Set the chips once, then Save as preset.' },
    { k: 'Button', v: 'CONVERT · GO PRO · STAY LOCAL', s: 'Verb, two words max.' },
    { k: 'Permission', v: 'LET HALO SEE THE DRAG.', s: "That's all it looks at." },
  ]
  return (
    <div className={W}>
      <SectionHead n="04" id="voice" kicker="How anyfmt talks" title={<>Punchy. <span style={{ color: C.flame }}>Never cringe.</span></>}>
        A race engineer on the radio: short, specific, calm under pressure. Headlines shout in caps; sentences under them speak normally.
      </SectionHead>
      <div className="mt-12 grid gap-3 md:grid-cols-2 lg:grid-cols-5">
        {principles.map((p, i) => (
          <Panel key={p.h} className="flex flex-col p-5" style={{ background: i === 0 ? C.cobalt : C.midnight }}>
            <span className="font-mono text-[10px] font-semibold opacity-60">0{i + 1}</span>
            <div className="mt-3 font-anton text-[30px] uppercase leading-[0.95]">{p.h}</div>
            <div className="mt-auto grid gap-2 pt-6 font-geist text-[13px] leading-snug">
              <div className="rounded-[10px] p-2.5" style={{ background: C.ice, color: C.midnight }}><b className="font-mono text-[9px] uppercase tracking-[0.14em]">Say</b><br />{p.do}</div>
              <div className="rounded-[10px] p-2.5 line-through decoration-[#FF6A2B] decoration-2" style={{ background: 'rgba(233,238,255,.06)', color: 'rgba(233,238,255,.6)' }}><b className="font-mono text-[9px] uppercase tracking-[0.14em] no-underline">Not</b><br />{p.dont}</div>
            </div>
          </Panel>
        ))}
      </div>
      <Panel className="mt-3 p-2" style={{ background: C.midnight }}>
        <div className="grid sm:grid-cols-2 lg:grid-cols-4">
          {micro.map((m) => (
            <div key={m.k} className="m-1 rounded-[14px] p-4" style={{ background: 'rgba(233,238,255,.04)' }}>
              <div className="font-mono text-[10px] uppercase tracking-[0.16em]" style={{ color: C.flame }}>{m.k}</div>
              <div className="mt-2 font-anton text-[20px] uppercase leading-tight">{m.v}</div>
              <div className="mt-1 font-geist text-[13px] text-[#E9EEFF]/70">{m.s}</div>
            </div>
          ))}
        </div>
      </Panel>
    </div>
  )
}

/* ───────────── Motion ───────────── */
function SnapDemo() {
  const reduce = useReducedMotion()
  const [i, setI] = useState(0)
  useEffect(() => { if (isShot || reduce) return; const t = setInterval(() => setI((x) => (x + 1) % 8), 700); return () => clearInterval(t) }, [reduce])
  return <CobaltWheel segments={convertSegs} size={220} hoverIndex={i} interactive={false} hubLabel={<Hub top="SNAP" size={220} />} labelSize={11} />
}
function GlowDemo() {
  return (
    <div className="flex items-center gap-6">
      {[0, 1].map((k) => (
        <motion.div key={k} className="grid h-24 w-20 place-items-center rounded-[14px] font-anton text-[22px]"
          animate={isShot ? undefined : { boxShadow: k ? ['0 0 0px rgba(255,106,43,0)', '0 0 34px rgba(255,106,43,.95)', '0 0 0px rgba(255,106,43,0)'] : undefined }}
          transition={{ duration: 1.6, repeat: Infinity }}
          style={k ? { background: FLAME_GRAD, color: C.midnight, boxShadow: isShot ? '0 0 28px rgba(255,106,43,.9)' : undefined } : { background: 'rgba(31,59,255,.5)', color: C.ice }}>
          {k ? 'GIF' : 'MP4'}
        </motion.div>
      ))}
    </div>
  )
}
function LeanDemo() {
  const reduce = useReducedMotion()
  return (
    <motion.div className="font-anton text-[64px] uppercase leading-none" style={isShot || reduce ? { skewX: -10 } : undefined}
      animate={isShot || reduce ? undefined : { skewX: [0, -14, 0, 8, 0] }} transition={{ duration: 2.4, repeat: Infinity, ease: 'easeInOut' }}>
      Lean<span style={{ color: C.flame }}>.</span>
    </motion.div>
  )
}
function BandsDemo() {
  const reduce = useReducedMotion()
  return (
    <div className="flex h-36 w-full overflow-hidden rounded-[12px]" style={{ boxShadow: `0 0 0 2px ${C.midnight}` }}>
      {[C.cobalt, C.midnight, '#2A46FF', C.cobalt, C.midnight, '#1733F0'].map((c, i) => (
        <motion.div key={i} className="-my-6 flex-1" style={{ background: c }}
          animate={isShot || reduce ? undefined : { y: [0, (i % 2 ? -1 : 1) * 22, 0] }} transition={{ duration: 2.2, repeat: Infinity, ease: 'easeInOut', delay: i * 0.08 }} />
      ))}
    </div>
  )
}

function MotionSection() {
  const demos = [
    { h: 'Snap', s: 'spring 700 / 30', b: 'Wedges jump out, no float. Stiff spring, near-critical damping, settle under 180 ms.', el: <SnapDemo /> },
    { h: 'Glow', s: '0 0 28px Flame 75%', b: 'The hit glows hard, nothing else glows. Glow appears on hover, not on idle.', el: <GlowDemo /> },
    { h: 'Lean', s: 'skew ±14° on scroll velocity', b: 'Big type leans into the scroll and snaps back when you stop. Off when reduced motion is on.', el: <LeanDemo /> },
    { h: 'Bands', s: 'useScroll · 60–160px', b: 'Bands slide against each other at different rates, like a grid at the start line.', el: <BandsDemo /> },
  ]
  const mats = [
    { n: 'Midnight glass', s: 'Midnight 94% · blur 24 · 1px Ice 14% rim', st: { background: 'linear-gradient(180deg, rgba(19,35,143,.78), rgba(5,10,46,.94) 50%)', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.14), inset 0 1px 0 rgba(233,238,255,.22)' } },
    { n: 'Cobalt glass', s: 'Cobalt 55% → Ultramarine 75%', st: { background: 'linear-gradient(180deg, rgba(54,83,255,.62), rgba(11,26,140,.72))', boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.12)' } },
    { n: 'Flame hit', s: '#FF8A4C → #FF6A2B → #E5470C', st: { background: FLAME_GRAD, boxShadow: '0 0 28px rgba(255,106,43,.75)' } },
    { n: 'Sticker', s: 'Solid · 2px Midnight rim · 8px hard drop', st: { background: C.ice, boxShadow: `0 0 0 2px ${C.midnight}, 0 8px 0 ${C.midnight}` } },
  ]
  return (
    <div className={W}>
      <SectionHead n="05" id="motion" kicker="Motion & materials" title={<>Snap, glow, <span style={{ color: C.flame }}>lean.</span></>}>
        Motion is athletic: fast in, hard stop. No floaty fades on the app. On the web, the page reacts to how hard you scroll.
      </SectionHead>
      <div className="mt-12 grid gap-3 md:grid-cols-2 lg:grid-cols-4">
        {demos.map((d) => (
          <Panel key={d.h} className="flex flex-col" style={{ background: C.midnight }}>
            <div className="grid h-[260px] place-items-center overflow-hidden p-4" style={{ background: C.ultra }}>{d.el}</div>
            <div className="p-5">
              <div className="flex items-baseline justify-between gap-2"><span className="font-anton text-[26px] uppercase leading-none">{d.h}</span><span className="font-mono text-[10px] text-[#E9EEFF]/55">{d.s}</span></div>
              <p className="mt-2 font-geist text-[13.5px] leading-relaxed text-[#E9EEFF]/72">{d.b}</p>
            </div>
          </Panel>
        ))}
      </div>
      <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {mats.map((m) => (
          <Panel key={m.n} className="relative p-4" style={{ background: C.cobalt }}>
            <Bands count={4} />
            <div className="relative h-28 rounded-[16px]" style={m.st} />
            <div className="relative mt-3 font-anton text-[18px] uppercase">{m.n}</div>
            <div className="relative font-mono text-[10.5px] text-[#E9EEFF]/80">{m.s}</div>
          </Panel>
        ))}
      </div>
    </div>
  )
}

/* ───────────── Landing preview ───────────── */
function Scaled({ children, w = 1440, h = 900 }: { children: ReactNode; w?: number; h?: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const [s, setS] = useState(0.6)
  useEffect(() => {
    const el = ref.current!
    const ro = new ResizeObserver(() => setS(el.clientWidth / w))
    ro.observe(el); setS(el.clientWidth / w)
    return () => ro.disconnect()
  }, [w])
  return (
    <div ref={ref} className="relative w-full overflow-hidden" style={{ height: h * s }}>
      <div className="absolute left-0 top-0 origin-top-left" style={{ width: w, height: h, transform: `scale(${s})` }}>{children}</div>
    </div>
  )
}

function LandingSection() {
  return (
    <div className={W}>
      <SectionHead n="06" id="landing" kicker="The marketing site" title={<>The page <span style={{ color: C.flame }}>moves.</span></>}>
        Bands slide, the wordmark bleeds off every edge and leans with your scroll, and the hero runs the real wheel. Below it: a playable wheel,
        a scoreboard, a flame privacy band, the CLI.
      </SectionHead>
      <Link to="/d/cobalt/landing" className="group mt-12 block overflow-hidden rounded-[22px]" style={{ boxShadow: `0 0 0 1px rgba(233,238,255,.14), 0 50px 100px -40px ${C.cobalt}` }}>
        <div className="flex h-10 items-center gap-2 px-4" style={{ background: '#0A0F33' }}>
          {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}
          <span className="mx-auto rounded-[7px] px-10 py-1 font-mono text-[11px] text-[#E9EEFF]/60" style={{ background: 'rgba(233,238,255,.06)' }}>halo.app</span>
          <span className="flex items-center gap-1 font-anton text-[13px] uppercase tracking-[0.06em] transition-colors group-hover:text-[#FF6A2B]">Open <ArrowUpRight size={15} /></span>
        </div>
        <div className="pointer-events-none">
          <Scaled><div style={{ ...cssVars, background: C.midnight }}><Nav fixed={false} /><Hero preview /></div></Scaled>
        </div>
      </Link>
      <div className="mt-3 overflow-hidden rounded-[22px]" style={{ boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}><Scoreboard /></div>
      <div className="mt-3 overflow-hidden rounded-[22px]" style={{ boxShadow: 'inset 0 0 0 1px rgba(233,238,255,.1)' }}><Agents /></div>
    </div>
  )
}

/** `?only=onboarding,app` renders a subset (handy for long screenshots). */
const only = typeof location !== 'undefined' ? new URLSearchParams(location.search).get('only')?.split(',') : undefined
const show = (id: string) => !only || only.includes(id)

export function BrandBook() {
  return (
    <div className="min-h-screen overflow-x-clip pb-28 font-geist selection:bg-[#FF6A2B] selection:text-[#050A2E]" style={{ ...cssVars, background: C.midnight, color: C.ice }}>
      <BookNav />
      {show('cover') && <Cover />}
      {show('logo') && <Reveal><LogoSection /></Reveal>}
      {show('colour') && <ColourSection />}
      {show('type') && <TypeSection />}
      {show('voice') && <VoiceSection />}
      {show('motion') && <MotionSection />}
      {show('landing') && <LandingSection />}
      {show('onboarding') && (
        <div className={W}>
          <SectionHead n="07" id="onboarding" kicker="First run · six windows" title={<>Six steps. <span style={{ color: C.flame }}>Green light.</span></>}>
            A racing progress bar in the title bar, the step number huge on a band panel, one flame button per window.
          </SectionHead>
          <div className="mt-12"><Onboarding /></div>
        </div>
      )}
      {show('app') && <AppSurfaces />}
      <div className={cn(W, 'mt-24 flex flex-wrap items-center justify-between gap-6 border-t pt-8')} style={{ borderColor: 'rgba(233,238,255,.1)' }}>
        <Lockup size={28} />
        <span className="font-mono text-[11px] uppercase tracking-[0.18em] text-[#E9EEFF]/55">Cobalt · direction 04 of 05 · end of book</span>
        <Link to="/d/cobalt/landing" className="flex items-center gap-2 rounded-[12px] px-4 py-2.5 font-anton text-[15px] uppercase tracking-[0.06em]" style={{ background: C.flame, color: C.midnight }}>Open the landing <ArrowUpRight size={16} /></Link>
      </div>
    </div>
  )
}
