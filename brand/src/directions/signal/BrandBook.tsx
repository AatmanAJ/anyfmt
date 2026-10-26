import { ArrowUpRight, Check, X } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { isShot } from '../../shared/kit'
import { product } from '../../shared/product'
import { cn } from '../../shared/cn'
import { Agents, HowItWorks, Pricing } from './Landing'
import { LedField } from './LedField'
import { AppIcon, Led, Lockup, Mark, MenuGlyph, Wordmark } from './Mark'
import { Onboarding } from './Onboarding'
import { DoneToast, KeyCap, SignalDemo } from './SignalDemo'
import { SignalWheel } from './SignalWheel'
import { Desktop, ErrorToast, FloatShelf, MenuBarMenu, OptionsPanel, ProgressHUD, WheelTrio } from './Surfaces'
import { C, contrast, convertSegs, cssVars, TOKENS, vibrancy } from './tokens'
import { Label, Scale, SignalRoot } from './ui'
import { meta } from './meta'

const SECTIONS = [
  ['cover', 'Cover'], ['logo', 'Logo'], ['colour', 'Colour'], ['type', 'Type'], ['voice', 'Voice'],
  ['motion', 'Motion'], ['landing', 'Landing'], ['onboarding', 'Onboarding'], ['app', 'App surfaces'],
] as const

const only = typeof location !== 'undefined' ? new URLSearchParams(location.search).get('only') : null

/* ───────────────────────────── Frame ───────────────────────────── */

function Sec({ id, n, title, intro, children }: { id: string; n: number; title: ReactNode; intro?: ReactNode; children: ReactNode }) {
  if (only && only !== id) return null
  return (
    <section id={id} className="scroll-mt-20 py-20 md:py-28" style={{ borderTop: `1px solid ${C.graphite}` }}>
      <div className="flex items-center gap-3">
        <Label style={{ color: C.solar }}>CH {String(n).padStart(2, '0')}</Label>
        <span className="h-px flex-1" style={{ background: C.graphite }} />
      </div>
      <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_1fr] lg:items-end">
        <h2 className="font-serif text-[52px] leading-[0.9] tracking-[-0.03em] md:text-[84px]">{title}</h2>
        {intro && <p className="max-w-[52ch] text-[15.5px] leading-[1.65] lg:justify-self-end" style={{ color: C.ash }}>{intro}</p>}
      </div>
      <div className="mt-14">{children}</div>
    </section>
  )
}

function Tile({ children, className, label, note, style }: { children: ReactNode; className?: string; label?: string; note?: ReactNode; style?: React.CSSProperties }) {
  return (
    <div className={cn('relative flex flex-col overflow-hidden rounded-[18px]', className)} style={{ background: C.carbon, boxShadow: `inset 0 0 0 1px ${C.graphite}`, ...style }}>
      {(label || note) && (
        <div className="relative z-10 flex items-center justify-between gap-3 px-5 pt-4">
          {label && <Label>{label}</Label>}
          {note && <Label dim className="hidden text-right sm:block">{note}</Label>}
        </div>
      )}
      <div className="relative flex flex-1 items-center justify-center p-6">{children}</div>
    </div>
  )
}

function SideNav() {
  const [act, setAct] = useState('cover')
  useEffect(() => {
    const io = new IntersectionObserver((es) => es.forEach((e) => e.isIntersecting && setAct(e.target.id)), { rootMargin: '-40% 0px -55% 0px' })
    SECTIONS.forEach(([id]) => { const el = document.getElementById(id); if (el) io.observe(el) })
    return () => io.disconnect()
  }, [])
  return (
    <>
      <aside className="sticky top-0 hidden h-screen w-[220px] shrink-0 flex-col justify-between py-8 pl-8 lg:flex">
        <div>
          <Lockup size={26} />
          <div className="mt-2"><Label dim>Brand book · Signal</Label></div>
          <nav className="mt-12 flex flex-col gap-0.5" aria-label="Brand book sections">
            {SECTIONS.map(([id, l], i) => (
              <a key={id} href={`#${id}`} onClick={(e) => { e.preventDefault(); document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' }) }}
                className="group flex items-center gap-3 rounded-[8px] py-1.5 pr-3 transition-colors">
                <span className="w-6 font-mono text-[10px] tracking-[0.1em]" style={{ color: act === id ? C.solar : C.ash2 }}>{String(i).padStart(2, '0')}</span>
                <span className="text-[13.5px] transition-colors group-hover:text-[#EDEDE6]" style={{ color: act === id ? C.bone : C.ash }}>{l}</span>
                {act === id && <Led size={4} className="ml-auto" />}
              </a>
            ))}
          </nav>
        </div>
        <Link to="/d/signal/landing" className="flex items-center gap-2 font-mono text-[10.5px] uppercase tracking-[0.16em] transition-colors hover:text-[#D7FF3A]" style={{ color: C.ash }}>
          Open landing <ArrowUpRight size={13} />
        </Link>
      </aside>
      <nav className="no-scrollbar sticky top-0 z-40 flex gap-1 overflow-x-auto px-4 py-3 lg:hidden" aria-label="Brand book sections"
        style={{ background: 'rgba(5,5,6,.82)', backdropFilter: 'blur(14px)', WebkitBackdropFilter: 'blur(14px)', borderBottom: `1px solid ${C.graphite}` }}>
        {SECTIONS.map(([id, l]) => (
          <a key={id} href={`#${id}`} onClick={(e) => { e.preventDefault(); document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' }) }}
            className="shrink-0 rounded-full px-3 py-1.5 font-mono text-[10.5px] uppercase tracking-[0.14em]"
            style={act === id ? { background: C.solar, color: C.void } : { color: C.ash }}>{l}</a>
        ))}
      </nav>
    </>
  )
}

/* ───────────────────────────── 00 Cover ───────────────────────────── */

function Cover() {
  if (only && only !== 'cover') return null
  const readouts: [string, string][] = [['Routes', '793'], ['Latency', '43 ms'], ['Network', '0'], ['Licence', 'AGPL-3.0']]
  return (
    <section id="cover" className="relative pb-14 pt-10 lg:pt-16">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <span className="flex items-center gap-2"><Led size={6} blink /><Label style={{ color: C.bone }}>anyfmt · Brand direction</Label></span>
        <Label dim>Ref. dot-matrix LED · editorial serif</Label>
      </div>
      <div className="relative mt-8 h-[220px] overflow-hidden rounded-[24px] sm:h-[340px] md:h-[460px]" style={{ background: '#030304', boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
        <LedField pitch={9} dot={1.5} base={0.07} glow={150} glyph={{ text: 'Signal', family: '"Instrument Serif"', style: 'italic', height: 0.78, y: 0.5, level: 0.95 }} />
        <div className="pointer-events-none absolute inset-x-5 top-4 flex justify-between"><Label dim>CH 00</Label><Label dim>{meta.palette[0].hex}</Label></div>
      </div>
      <div className="mt-10 grid gap-10 lg:grid-cols-[1.3fr_1fr]">
        <p className="font-serif text-[34px] leading-[1.05] tracking-[-0.02em] md:text-[48px]">
          A dark instrument. Every file is a signal, <i style={{ color: C.solar }}>the wheel is the tuner.</i>
        </p>
        <div className="grid grid-cols-2 gap-px self-end overflow-hidden rounded-[14px]" style={{ background: C.graphite, boxShadow: `0 0 0 1px ${C.graphite}` }}>
          {readouts.map(([k, v]) => (
            <div key={k} className="flex flex-col gap-2 p-4" style={{ background: C.void }}>
              <Label dim>{k}</Label>
              <span className="font-mono text-[20px] tracking-[-0.01em]" style={{ color: k === 'Network' ? C.solar : C.bone }}>{v}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── 01 Logo ───────────────────────────── */

function Construction() {
  const n = 24
  return (
    <svg viewBox="0 0 100 100" className="w-full max-w-[300px]" aria-label="Mark construction">
      <circle cx="50" cy="50" r="40" fill="none" stroke={C.graphite2} strokeWidth="0.3" strokeDasharray="1 1" />
      <circle cx="50" cy="50" r="46" fill="none" stroke={C.graphite} strokeWidth="0.25" />
      {Array.from({ length: n }, (_, i) => {
        const a = (i / n) * Math.PI * 2
        return <line key={i} x1={50 + 30 * Math.sin(a)} y1={50 - 30 * Math.cos(a)} x2={50 + 46 * Math.sin(a)} y2={50 - 46 * Math.cos(a)} stroke={C.graphite} strokeWidth="0.25" />
      })}
      <path d={`M50 50 L${50 + 46 * Math.sin((1.5 / n) * Math.PI * 2)} ${50 - 46 * Math.cos((1.5 / n) * Math.PI * 2)} A46 46 0 0 1 ${50 + 46 * Math.sin((4.5 / n) * Math.PI * 2)} ${50 - 46 * Math.cos((4.5 / n) * Math.PI * 2)} Z`} fill="rgba(215,255,58,.06)" stroke="rgba(215,255,58,.4)" strokeWidth="0.3" />
      <g transform="translate(0 0)"><Mark size={100} glow={false} /></g>
      <line x1="50" y1="50" x2="50" y2="12" stroke={C.ash2} strokeWidth="0.3" />
      <text x="51.5" y="31" fontSize="3" fill={C.ash} fontFamily="JetBrains Mono Variable">r 40</text>
      <text x="74" y="9" fontSize="3" fill={C.solar} fontFamily="JetBrains Mono Variable">45° · 3 LEDs</text>
    </svg>
  )
}

function LogoSection() {
  return (
    <Sec id="logo" n={1} title={<>The <i>mark.</i></>}
      intro="Twenty-four LEDs on a ring. Three are lit, at one o’clock: the wedge you aimed at. It is a wheel, a halo and a level meter at once, and it survives at 16 px.">
      <div className="grid gap-3 lg:grid-cols-[1.4fr_1fr]">
        <Tile label="Primary lockup" note="Mark + Instrument Serif" className="min-h-[360px]" style={{ background: 'radial-gradient(70% 80% at 50% 40%, #121214, #050506)' }}>
          <div className="scale-[0.7] sm:scale-100"><Lockup size={96} /></div>
        </Tile>
        <Tile label="Construction" note="24 × 15°">
          <Construction />
        </Tile>
      </div>
      <div className="mt-3 grid gap-3 md:grid-cols-3">
        <Tile label="Stacked" className="min-h-[240px]">
          <div className="flex flex-col items-center gap-3"><Mark size={72} /><Wordmark size={44} /></div>
        </Tile>
        <Tile label="Mark" className="min-h-[240px]"><Mark size={110} /></Tile>
        <Tile label="Silkscreen" note="Mono lockup, for hardware moments" className="min-h-[240px]">
          <div className="flex items-center gap-3"><Mark size={34} /><span className="font-mono text-[18px] font-medium uppercase tracking-[0.32em]">anyfmt</span></div>
        </Tile>
      </div>
      {/* Backgrounds */}
      <div className="mt-3 grid gap-3 md:grid-cols-3">
        <Tile label="On void" className="min-h-[200px]"><Lockup size={44} /></Tile>
        <Tile label="On bone" note="Lit LEDs go solid ink" className="min-h-[200px]" style={{ background: C.bone }}>
          <Lockup size={44} ink={C.void} lit={C.void} glow={false} />
        </Tile>
        <Tile label="On solar" note="Ink only" className="min-h-[200px]" style={{ background: C.solar }}>
          <div className="[&_span]:!text-[#050506]"><Lockup size={44} ink={C.void} lit={C.void} glow={false} /></div>
        </Tile>
      </div>
      {/* Clear space + min size */}
      <div className="mt-3 grid gap-3 md:grid-cols-2">
        <Tile label="Clear space" note="x = mark height ÷ 2" className="min-h-[260px]">
          <div className="relative p-[28px]" style={{ outline: `1px dashed ${C.graphite2}` }}>
            <div className="pointer-events-none absolute inset-[28px]" style={{ outline: `1px solid rgba(215,255,58,.35)` }} />
            <Lockup size={56} />
            {['left-0 top-1/2 -translate-y-1/2 w-[28px] h-px', 'right-0 top-1/2 -translate-y-1/2 w-[28px] h-px', 'top-0 left-1/2 -translate-x-1/2 h-[28px] w-px', 'bottom-0 left-1/2 -translate-x-1/2 h-[28px] w-px'].map((c) => (
              <span key={c} className={cn('absolute', c)} style={{ background: C.solar }} />
            ))}
            <span className="absolute -top-5 left-1/2 -translate-x-1/2 font-mono text-[10px]" style={{ color: C.solar }}>x</span>
          </div>
        </Tile>
        <Tile label="Minimum size" note="Mark 16 px · lockup 72 px wide" className="min-h-[260px]">
          <div className="flex items-end gap-7">
            {[16, 24, 32, 48].map((s) => (
              <div key={s} className="flex flex-col items-center gap-3"><Mark size={s} glow={s >= 24} /><Label dim>{s}</Label></div>
            ))}
            <div className="flex flex-col items-center gap-3"><Lockup size={18} glow={false} /><Label dim>72 w</Label></div>
          </div>
        </Tile>
      </div>
      {/* App icon + menu bar */}
      <div className="mt-3 grid gap-3 lg:grid-cols-[1.4fr_1fr]">
        <Tile label="App icon" note="1024 grid · 824 body · superellipse n=5" className="min-h-[380px]" style={{ background: 'radial-gradient(70% 70% at 50% 40%, #1a1a1d, #0a0a0b)' }}>
          <div className="flex flex-wrap items-end justify-center gap-6">
            <AppIcon size={232} />
            <div className="flex items-end gap-4">
              <div className="flex flex-col items-center gap-2"><AppIcon size={96} /><Label dim>128</Label></div>
              <div className="flex flex-col items-center gap-2"><AppIcon size={48} /><Label dim>64</Label></div>
              <div className="flex flex-col items-center gap-2"><AppIcon size={24} /><Label dim>32</Label></div>
            </div>
          </div>
        </Tile>
        <Tile label="Menu-bar glyph" note="Template · alpha only" className="min-h-[380px]">
          <div className="flex w-full flex-col gap-5">
            {[['Dark', 'rgba(30,30,33,.95)', C.bone], ['Light', 'rgba(236,236,236,.95)', '#000']].map(([k, bg, fg]) => (
              <div key={k}>
                <div className="flex h-[26px] items-center justify-end gap-4 rounded-[7px] px-3 text-[12px]" style={{ background: bg, color: fg }}>
                  <span className="grid h-[22px] w-[30px] place-items-center rounded-[5px]" style={{ background: k === 'Dark' ? 'rgba(255,255,255,.18)' : 'rgba(0,0,0,.1)' }}><MenuGlyph size={16} color={fg} /></span>
                  <MenuGlyph size={18} color={fg} />
                  <span className="font-medium">9:41</span>
                </div>
                <div className="mt-1.5 flex justify-end gap-5 pr-12"><Label dim>16 px</Label><Label dim>18 px</Label></div>
              </div>
            ))}
            <div className="flex items-center gap-5">
              <div className="relative grid size-[128px] place-items-center rounded-[10px]" style={{ background: C.void, backgroundImage: `linear-gradient(${C.graphite} 1px, transparent 1px), linear-gradient(90deg, ${C.graphite} 1px, transparent 1px)`, backgroundSize: '8px 8px' }}>
                <MenuGlyph size={128} color={C.bone} />
              </div>
              <p className="text-[13px] leading-relaxed" style={{ color: C.ash }}>12 dots, r 1.05. The two lit dots grow to r 1.55 at full alpha. Unlit dots sit at 50 % alpha so macOS tints them correctly.</p>
            </div>
          </div>
        </Tile>
      </div>
      {/* Do / don't */}
      <div className="mt-3 grid grid-cols-2 gap-3 md:grid-cols-4">
        {[
          { ok: true, t: 'Light one wedge, at one o’clock.', v: <Mark size={88} /> },
          { ok: false, t: 'Don’t light more than three LEDs.', v: <Mark size={88} count={9} /> },
          { ok: false, t: 'Don’t recolour the lit wedge.', v: <Mark size={88} lit="#5B8CFF" /> },
          { ok: false, t: 'Don’t join the dots into a stroke.', v: <svg width="88" height="88" viewBox="0 0 100 100"><circle cx="50" cy="50" r="38" fill="none" stroke={C.bone} strokeOpacity=".35" strokeWidth="7" /><path d="M64.5 14.9 A38 38 0 0 1 82.9 31" fill="none" stroke={C.solar} strokeWidth="8" strokeLinecap="round" /></svg> },
        ].map((d, i) => (
          <div key={i} className="flex flex-col overflow-hidden rounded-[18px]" style={{ background: C.carbon, boxShadow: `inset 0 0 0 1px ${d.ok ? 'rgba(215,255,58,.35)' : C.graphite}` }}>
            <div className="grid h-[150px] place-items-center">{d.v}</div>
            <div className="flex items-start gap-2 px-4 pb-4 text-[13px] leading-snug" style={{ color: d.ok ? C.bone : C.ash }}>
              <span className="mt-0.5 grid size-4 shrink-0 place-items-center rounded-full" style={{ background: d.ok ? C.solar : C.clip, color: C.void }}>{d.ok ? <Check size={10} strokeWidth={3} /> : <X size={10} strokeWidth={3} />}</span>
              {d.t}
            </div>
          </div>
        ))}
      </div>
    </Sec>
  )
}

/* ───────────────────────────── 02 Colour ───────────────────────────── */

function ColourSection() {
  const sw = [
    { n: 'Solar', h: C.solar, r: 'The lit wedge, selection, the one primary action per screen.', ink: C.void },
    { n: 'Void', h: C.void, r: 'Canvas. Pages, windows, the space between.', ink: C.bone },
    { n: 'Carbon', h: C.carbon, r: 'Matte surfaces. Wedges at rest, cards.', ink: C.bone },
    { n: 'Graphite', h: C.graphite, r: 'Hairlines. 1 px, never thicker.', ink: C.bone },
    { n: 'Ash', h: C.ash, r: 'Labels and secondary text.', ink: C.void },
    { n: 'Bone', h: C.bone, r: 'Text. Warm, never pure white.', ink: C.void },
    { n: 'Clip', h: C.clip, r: 'Errors only, like a clipping LED.', ink: C.void },
  ]
  const share = [['Void', 64, C.void], ['Carbon', 18, C.carbon], ['Graphite', 6, C.graphite], ['Ash', 5, C.ash], ['Bone', 6, C.bone], ['Solar', 1, C.solar]] as const
  return (
    <Sec id="colour" n={2} title={<>Black, bone,<br /><i>one light.</i></>}
      intro="Signal is a dark room with a single LED in it. Solar lime appears where the user is aiming and nowhere else. If two things on a screen are lime, one of them is wrong.">
      <div className="grid gap-3 md:grid-cols-[1.5fr_1fr_1fr]">
        {sw.slice(0, 3).map((s, i) => (
          <div key={s.n} className={cn('flex flex-col justify-between rounded-[18px] p-5', i === 0 ? 'min-h-[320px]' : 'min-h-[220px] md:min-h-[320px]')} style={{ background: s.h, color: s.ink, boxShadow: `inset 0 0 0 1px ${C.graphite}`, ...(i === 0 ? { boxShadow: '0 0 60px -10px rgba(215,255,58,.4)' } : {}) }}>
            <div className="flex justify-between font-mono text-[11px] uppercase tracking-[0.14em]"><span>{s.n}</span><span>{s.h}</span></div>
            <div>
              <p className="max-w-[30ch] text-[13.5px] leading-snug opacity-80">{s.r}</p>
              <div className="mt-3 font-mono text-[11px] opacity-70">{s.n === 'Solar' ? `on void ${contrast(s.h, C.void).toFixed(1)}:1` : `bone on ${s.n.toLowerCase()} ${contrast(C.bone, s.h).toFixed(1)}:1`}</div>
            </div>
          </div>
        ))}
      </div>
      <div className="mt-3 grid grid-cols-2 gap-3 md:grid-cols-4">
        {sw.slice(3).map((s) => (
          <div key={s.n} className="flex min-h-[170px] flex-col justify-between rounded-[18px] p-4" style={{ background: s.h, color: s.ink, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
            <div className="flex justify-between font-mono text-[10.5px] uppercase tracking-[0.14em]"><span>{s.n}</span><span>{s.h}</span></div>
            <div>
              <p className="text-[12.5px] leading-snug opacity-80">{s.r}</p>
              <div className="mt-2 font-mono text-[10.5px] opacity-70">{s.n === 'Graphite' ? `bone on graphite ${contrast(C.bone, s.h).toFixed(1)}:1` : `on void ${contrast(s.h, C.void).toFixed(1)}:1`}</div>
            </div>
          </div>
        ))}
      </div>
      <div className="mt-10">
        <div className="flex items-center justify-between"><Label>Share of a typical screen</Label><Label dim>Solar ≤ 2 %</Label></div>
        <div className="mt-3 flex h-12 overflow-hidden rounded-[10px]" style={{ boxShadow: `0 0 0 1px ${C.graphite}` }}>
          {share.map(([n, p, c]) => <div key={n} style={{ width: `${p}%`, background: c, minWidth: 6 }} title={n} />)}
        </div>
        <div className="mt-2 flex flex-wrap gap-x-5 gap-y-1">{share.map(([n, p]) => <Label key={n} dim>{n} {p}%</Label>)}</div>
      </div>
      <div className="mt-12 overflow-hidden rounded-[18px]" style={{ boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
        <div className="grid grid-cols-[1.2fr_0.8fr] gap-4 px-5 py-3 md:grid-cols-[1fr_0.6fr_1.4fr]" style={{ background: C.carbon, borderBottom: `1px solid ${C.graphite}` }}>
          <Label>Token</Label><Label>Value</Label><Label className="hidden md:block">Use</Label>
        </div>
        {TOKENS.map((t, i) => (
          <div key={t.name} className="grid grid-cols-[1.2fr_0.8fr] items-center gap-4 px-5 py-3 md:grid-cols-[1fr_0.6fr_1.4fr]" style={{ borderTop: i ? `1px solid ${C.graphite}` : 'none' }}>
            <code className="font-mono text-[12.5px]" style={{ color: t.name === '--sg-live' ? C.solar : C.bone }}>{t.name}</code>
            <span className="flex items-center gap-2 font-mono text-[12px]" style={{ color: C.ash }}><span className="size-3.5 rounded-[4px]" style={{ background: t.value, boxShadow: `inset 0 0 0 1px ${C.graphite2}` }} />{t.value}</span>
            <span className="col-span-2 text-[13px] md:col-span-1" style={{ color: C.ash }}>{t.use}</span>
          </div>
        ))}
      </div>
    </Sec>
  )
}

/* ───────────────────────────── 03 Type ───────────────────────────── */

function TypeSection() {
  const scale = [
    ['Display', 'font-serif', 'text-[56px] md:text-[96px] leading-[0.88] tracking-[-0.035em]', 'Instrument Serif 136/96 · −3.5 %', 'Tune any file'],
    ['Headline', 'font-serif', 'text-[40px] md:text-[56px] leading-[0.95] tracking-[-0.025em]', 'Instrument Serif 56 · −2.5 %', 'Three keys. Three wheels.'],
    ['Title', 'font-serif', 'text-[30px] leading-none tracking-[-0.02em]', 'Instrument Serif 30 · −2 %', 'Ready. 793 routes armed.'],
    ['Body', 'font-geist', 'text-[17px] leading-[1.6]', 'Geist 17/27 · 0', 'Everything runs on your Mac. No account, no upload, no telemetry.'],
    ['UI', 'font-geist', 'text-[13px] leading-[1.4] font-medium', 'Geist 13 · medium', 'clip.mov → GIF · Encoding'],
    ['Label', 'font-mono', 'text-[10.5px] uppercase tracking-[0.18em]', 'JetBrains Mono 10.5 · +18 % · caps', 'CH 01 · Convert · 15 fps'],
  ] as const
  return (
    <Sec id="type" n={3} title={<>Serif for meaning, <i>mono for measure.</i></>}
      intro="Instrument Serif says the big thing, in italics when it is the turn of phrase. Geist runs the interface. JetBrains Mono is the silkscreen: units, channels, keys, numbers.">
      <div className="grid gap-3 lg:grid-cols-3">
        <Tile label="Display" note="Instrument Serif" className="min-h-[300px]">
          <div className="text-center font-serif leading-[0.8] tracking-[-0.04em]"><span className="text-[160px]">Aa</span><span className="text-[160px] italic" style={{ color: C.solar }}>g</span></div>
        </Tile>
        <Tile label="Text" note="Geist" className="min-h-[300px]">
          <div className="text-center font-geist text-[120px] font-medium leading-none tracking-[-0.04em]">Aa</div>
        </Tile>
        <Tile label="Silkscreen" note="JetBrains Mono" className="min-h-[300px]">
          <div className="flex flex-col items-center gap-3">
            <div className="font-mono text-[96px] leading-none tracking-[-0.04em]">0<span style={{ color: C.solar }}>1</span></div>
            <Label>⇧ ⌘ ⌃ · 43 ms · 15 fps</Label>
          </div>
        </Tile>
      </div>
      <div className="mt-10 flex flex-col">
        {scale.map(([n, f, cls, spec, sample]) => (
          <div key={n} className="grid items-baseline gap-2 py-6 md:grid-cols-[180px_1fr]" style={{ borderTop: `1px solid ${C.graphite}` }}>
            <div className="flex flex-col gap-1.5"><Label style={{ color: C.bone }}>{n}</Label><span className="font-mono text-[11px] leading-snug" style={{ color: C.ash2 }}>{spec}</span></div>
            <div className={cn(f, cls, 'min-w-0 break-words')}>{n === 'Display' ? <>{sample} <i style={{ color: C.solar }}>mid-drag.</i></> : n === 'Headline' ? <>Three keys. <i>Three wheels.</i></> : sample}</div>
          </div>
        ))}
      </div>
      <div className="mt-8 grid gap-3 md:grid-cols-3">
        {[
          ['Italic is the hinge', 'One italic phrase per headline, at the turn. Never a whole sentence. Never two.'],
          ['Numbers go mono', 'Any value with a unit is mono and tabular: 43 ms, 15 fps, 4.1 MB. Stats on the page may go serif at display size.'],
          ['No bold serif', 'Instrument Serif has one weight. Emphasis comes from size and italic, not weight.'],
        ].map(([h, b]) => (
          <div key={h} className="rounded-[16px] p-5" style={{ background: C.carbon, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
            <div className="font-serif text-[24px] leading-tight">{h}</div>
            <p className="mt-2 text-[13.5px] leading-relaxed" style={{ color: C.ash }}>{b}</p>
          </div>
        ))}
      </div>
    </Sec>
  )
}

/* ───────────────────────────── 04 Voice ───────────────────────────── */

function VoiceSection() {
  const rules = [
    ['Numbers first.', 'Lead with the measurement. It is more convincing than an adjective.', '793 routes. Every one tested.', 'Supports tons of formats!'],
    ['Say the verb.', 'Name what happened, in the past tense, then stop.', 'Converted. clip.gif · 4.1 MB', 'Your conversion was completed successfully!'],
    ['Measure, don’t promise.', 'Claims we can time, we time. Claims we can’t, we drop.', 'Key to wheel in 43 ms.', 'Blazing-fast, lightning-quick performance.'],
    ['Quiet until it matters.', 'No celebration for routine work. Save words for errors.', 'Done.', 'Woohoo!! Another file transformed!!'],
    ['One line, with the fix.', 'What broke, why, and the next move. No apology theatre.', 'Locked by Preview. Close it, then retry.', 'Oops! Something went wrong. Please try again later.'],
  ]
  const micro: [string, ReactNode][] = [
    ['Done toast', <DoneToast key="d" name="clip.gif" detail="4.1 MB · 1.8 s" />],
    ['Error toast', <ErrorToast key="e" />],
    ['Empty Float', <div key="f" className="flex items-center gap-3 rounded-[14px] px-4 py-3 text-[13px]" style={{ ...vibrancy, color: C.bone }}><Led size={5} on={false} /><span>Float is empty.</span><span style={{ color: C.ash }}>Drop a file here to hold it.</span></div>],
    ['No route', <div key="n" className="flex items-center gap-3 rounded-[14px] px-4 py-3 text-[13px]" style={{ ...vibrancy, color: C.bone }}><Led size={5} color={C.ash} /><span>No route from .xyz yet.</span><span style={{ color: C.ash }}>Tools and Actions still work.</span></div>],
  ]
  return (
    <Sec id="voice" n={4} title={<>Precise. Terse. <i>Measured.</i></>}
      intro="anyfmt talks like a good instrument reads: a value, a unit, a state. Short sentences. No exclamation marks. Numbers do the persuading.">
      <div className="flex flex-col">
        {rules.map(([h, b, d, n], i) => (
          <div key={h} className="grid gap-5 py-7 lg:grid-cols-[0.9fr_1fr_1fr]" style={{ borderTop: `1px solid ${C.graphite}` }}>
            <div>
              <div className="flex items-center gap-3"><Label style={{ color: C.solar }}>{String(i + 1).padStart(2, '0')}</Label><span className="font-serif text-[30px] leading-none">{h}</span></div>
              <p className="mt-2 max-w-[40ch] text-[13.5px] leading-relaxed" style={{ color: C.ash }}>{b}</p>
            </div>
            <div className="flex items-start gap-3 self-start rounded-[14px] p-4" style={{ background: 'rgba(215,255,58,.05)', boxShadow: 'inset 0 0 0 1px rgba(215,255,58,.25)' }}>
              <span className="mt-0.5 grid size-4 shrink-0 place-items-center rounded-full" style={{ background: C.solar, color: C.void }}><Check size={10} strokeWidth={3} /></span>
              <span className="text-[15px]">{d}</span>
            </div>
            <div className="flex items-start gap-3 self-start rounded-[14px] p-4" style={{ background: C.carbon, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
              <span className="mt-0.5 grid size-4 shrink-0 place-items-center rounded-full" style={{ background: C.clip, color: C.void }}><X size={10} strokeWidth={3} /></span>
              <span className="text-[15px] line-through decoration-[#FF5B3A]/60" style={{ color: C.ash }}>{n}</span>
            </div>
          </div>
        ))}
      </div>
      <Desktop className="mt-10 p-6 md:p-10">
        <Label>Microcopy in place</Label>
        <div className="mt-6 grid gap-6 md:grid-cols-2">
          {micro.map(([k, v]) => (
            <div key={k} className="flex min-w-0 flex-col gap-3">
              <Label dim>{k}</Label>
              <div className="no-scrollbar overflow-x-auto pb-1">{v}</div>
            </div>
          ))}
        </div>
      </Desktop>
    </Sec>
  )
}

/* ───────────────────────────── 05 Motion ───────────────────────────── */

function MotionSection() {
  return (
    <Sec id="motion" n={5} title={<>Lit, <i>not animated.</i></>}
      intro="Things in Signal switch on, like LEDs: a fast attack, a slow phosphor decay. The wheel springs; nothing floats, bounces or drifts for its own sake. Move your pointer over the panels.">
      <div className="grid gap-3 lg:grid-cols-3">
        <Tile label="Phosphor" note="45 % on · 7 % off" className="h-[360px] !p-0">
          <div className="absolute inset-0"><LedFieldScan /></div>
        </Tile>
        <Tile label="Spring" note="Stiffness 420 · damping 28" className="h-[360px]">
          <SignalWheel segments={convertSegs.slice(0, 6)} size={240} restIndex={isShot ? 1 : null} hub={<span className="font-serif text-[22px] italic">aim</span>} />
        </Tile>
        <Tile label="Ripple" note="Click to ping" className="h-[360px] !p-0">
          <div className="absolute inset-0"><LedField pitch={10} dot={1.5} base={0.12} glow={110} ping={2600} /></div>
        </Tile>
      </div>
      <div className="mt-3 grid gap-3 md:grid-cols-3">
        <Tile label="Carbon" note="Matte · wedges, cards" className="h-[220px]">
          <div className="size-[120px] rounded-[22px]" style={{ background: `radial-gradient(circle at 50% 30%, #232327, ${C.carbon} 70%)`, boxShadow: `inset 0 0 0 1px ${C.graphite}, inset 0 1px 0 rgba(255,255,255,.06), 0 20px 40px -10px #000` }} />
        </Tile>
        <Tile label="Vibrancy" note="Blur 28 · saturate 160 %" className="h-[220px] !p-0">
          <div className="absolute inset-0" style={{ backgroundImage: `radial-gradient(circle at 30% 40%, rgba(215,255,58,.5), transparent 30%), radial-gradient(circle, rgba(237,237,230,.18) 1px, transparent 1.6px)`, backgroundSize: '100% 100%, 10px 10px' }} />
          <div className="relative grid h-full place-items-center"><div className="size-[120px] rounded-[22px]" style={vibrancy} /></div>
        </Tile>
        <Tile label="LED" note="Solar + 1.6× glow" className="h-[220px]">
          <div className="grid grid-cols-6 gap-3">
            {Array.from({ length: 18 }, (_, i) => <Led key={i} size={10} on={i === 7 || i === 8 || i === 9} />)}
          </div>
        </Tile>
      </div>
      <div className="mt-10 overflow-hidden rounded-[18px]" style={{ boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
        {[
          ['wheel.open', 'spring 420 / 28', 'Bloom from 60 %, −10°. Wedges stagger 14 ms.'],
          ['wedge.aim', 'spring 560 / 32', 'Lift outward size ÷ 64. LED ring follows in 120 ms.'],
          ['led.on / led.off', '45 % / 7 % per frame', 'Fast attack, slow decay. Reads as hardware.'],
          ['toast.in', 'spring 320 / 26', 'Rise 14 px. Hold 2.3 s. No exit flourish.'],
          ['reduced motion', '0 ms', 'Springs become cuts. LED fields freeze on their lit frame.'],
        ].map(([k, v, d], i) => (
          <div key={k} className="grid gap-2 px-5 py-4 md:grid-cols-[0.8fr_0.8fr_1.6fr]" style={{ borderTop: i ? `1px solid ${C.graphite}` : 'none', background: i % 2 ? 'transparent' : 'rgba(255,255,255,.012)' }}>
            <code className="font-mono text-[12.5px]">{k}</code>
            <span className="font-mono text-[12px]" style={{ color: C.solar }}>{v}</span>
            <span className="text-[13px]" style={{ color: C.ash }}>{d}</span>
          </div>
        ))}
      </div>
    </Sec>
  )
}

function LedFieldScan() {
  const anchor = useRef<HTMLDivElement>(null)
  return (
    <div className="relative h-full w-full">
      <div ref={anchor} className="absolute left-1/2 top-[54%] size-[150px] -translate-x-1/2 -translate-y-1/2" />
      <LedField pitch={9} dot={1.4} base={0.05} glow={70} ring={{ anchor, outer: 1.3, inner: 0.62, wedges: 8, gap: 14 }} scanMs={420} shotLit={2} />
    </div>
  )
}

/* ───────────────────────────── 06 Landing ───────────────────────────── */

function LandingSection() {
  const anchor = useRef<HTMLDivElement>(null)
  const lit = useRef<number | null>(null)
  return (
    <Sec id="landing" n={6} title={<>The page is <i>the instrument.</i></>}
      intro="The landing opens on a live LED field: the wheel’s wedges echo as an LED ring that follows the demo’s aim. Below: the interactive key-to-wheel section, the CLI and pricing, shown inline.">
      <Link to="/d/signal/landing" className="group block overflow-hidden rounded-[22px] transition-transform duration-500 hover:-translate-y-1" style={{ boxShadow: `inset 0 0 0 1px ${C.graphite}, 0 40px 100px -40px rgba(215,255,58,.25)` }}>
        <div className="flex items-center gap-2 px-4 py-3" style={{ background: C.carbon, borderBottom: `1px solid ${C.graphite}` }}>
          {[0, 1, 2].map((i) => <span key={i} className="size-[10px] rounded-full" style={{ background: C.graphite2 }} />)}
          <span className="mx-auto rounded-full px-4 py-1 font-mono text-[11px]" style={{ background: C.void, color: C.ash }}>halo.app</span>
          <ArrowUpRight size={15} className="transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" style={{ color: C.solar }} />
        </div>
        <div className="relative grid min-h-[460px] items-center gap-6 overflow-hidden p-6 md:grid-cols-[1.2fr_1fr] md:p-12" style={{ background: C.void }}>
          <div className="absolute inset-0"><LedField pitch={9} dot={1.25} base={0.07} glow={100} ring={{ anchor, outer: 1.48, inner: 1.07, wedges: 8, gap: 14 }} litRef={lit} shotLit={0} /></div>
          <div className="relative z-10">
            <div className="flex items-center gap-2"><Led size={5} blink /><Label style={{ color: C.bone }}>Live</Label></div>
            <div className="mt-5 font-serif text-[48px] leading-[0.86] tracking-[-0.035em] md:text-[72px]">Tune any file <i style={{ color: C.solar }}>mid&#8209;drag.</i></div>
            <div className="mt-6 inline-flex items-center gap-2 rounded-full px-4 py-2.5 font-mono text-[11px] font-semibold uppercase tracking-[0.14em]" style={{ background: C.solar, color: C.void }}>Open the landing <ArrowUpRight size={13} /></div>
          </div>
          <div className="relative flex justify-center py-10">
            <div ref={anchor} className="relative size-[260px]">
              <SignalDemo segments={convertSegs} target={0} sweep={[3, 1, 0]} size={260} onAim={(v) => { lit.current = v }} />
            </div>
          </div>
        </div>
      </Link>
      <div className="mt-16 rounded-[22px] p-6 md:p-12" style={{ background: '#08080A', boxShadow: `inset 0 0 0 1px ${C.graphite}` }}><HowItWorks compact /></div>
      <div className="mt-3 rounded-[22px] p-6 md:p-12" style={{ background: '#08080A', boxShadow: `inset 0 0 0 1px ${C.graphite}` }}><Agents compact /></div>
      <div className="mt-3 rounded-[22px] p-6 md:p-12" style={{ background: '#08080A', boxShadow: `inset 0 0 0 1px ${C.graphite}` }}><Pricing compact /></div>
    </Sec>
  )
}

/* ───────────────────────────── 08 App ───────────────────────────── */

function AppSection() {
  return (
    <Sec id="app" n={8} title={<>The app, <i>wearing Signal.</i></>}
      intro="Dark vibrancy everywhere, carbon wedges, solar for the thing under your pointer. Everything here is at real size and live: hover the wheels, pick chips, watch the HUD.">
      <Desktop className="px-4 py-10 md:p-12">
        <div className="mb-10 flex items-center justify-between"><Label>Wheels · 290 pt</Label><Label dim>Hover to aim</Label></div>
        <WheelTrio size={290} />
      </Desktop>
      <div className="mt-3 grid gap-3 lg:grid-cols-[1fr_1fr]">
        <Desktop className="flex min-h-[520px] flex-col p-5 md:p-8">
          <div className="flex items-center justify-between"><Label>Options · ⌥ on a wedge</Label><Label dim>Size per chip</Label></div>
          <div className="mt-8 flex flex-1 items-center justify-center"><OptionsPanel /></div>
        </Desktop>
        <Desktop className="flex min-h-[520px] flex-col p-5 md:p-8">
          <div className="flex items-center justify-between"><Label>Menu bar</Label><Label dim>Solar selection</Label></div>
          <div className="mt-8 flex flex-1 justify-center"><MenuBarMenu /></div>
        </Desktop>
      </div>
      <div className="mt-3 grid gap-3 lg:grid-cols-[1.1fr_1fr]">
        <Desktop className="flex min-h-[300px] flex-col p-5 md:p-8">
          <div className="flex items-center justify-between"><Label>Progress HUD</Label><Label dim>24-LED ring</Label></div>
          <div className="mt-8 flex flex-1 flex-col items-center justify-center gap-4">
            <ProgressHUD />
            <ProgressHUD fixed={0.25} className="opacity-70" />
          </div>
        </Desktop>
        <Desktop className="flex min-h-[300px] flex-col p-5 md:p-8">
          <div className="flex items-center justify-between"><Label>Float shelf</Label><Label dim>Holds files between drags</Label></div>
          <div className="mt-8 flex flex-1 items-center justify-center"><FloatShelf /></div>
        </Desktop>
      </div>
      <Desktop className="mt-3 p-5 md:p-8">
        <div className="flex items-center justify-between"><Label>Toasts</Label><Label dim>Done · error</Label></div>
        <div className="no-scrollbar mt-8 flex flex-col items-start gap-4 overflow-x-auto pb-1 md:items-center">
          <DoneToast name="clip.gif" detail="4.1 MB · 1.8 s" />
          <ErrorToast />
        </div>
      </Desktop>
      <div className="mt-10 grid gap-3 md:grid-cols-3">
        {wheelsKeys.map(([k, n, w]) => (
          <div key={k} className="flex items-center gap-4 rounded-[16px] p-4" style={{ background: C.carbon, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
            <KeyCap symbol={k} label={n} size="sm" />
            <div><div className="font-serif text-[24px] leading-none">{w}</div><Label dim className="mt-1.5 block">{n} while dragging</Label></div>
          </div>
        ))}
      </div>
    </Sec>
  )
}
const wheelsKeys = product.keys.map((k) => [k.key, k.name, k.wheel] as const)

/* ───────────────────────────── Book ───────────────────────────── */

export function BrandBook() {
  return (
    <SignalRoot vars={cssVars}>
      <div className="flex flex-col lg:flex-row">
        <SideNav />
        <main className="min-w-0 flex-1 px-4 pb-28 sm:px-6 lg:border-l lg:pl-10 lg:pr-12" style={{ borderColor: C.graphite }}>
          <div className="mx-auto max-w-[1180px]">
            <Cover />
            <LogoSection />
            <ColourSection />
            <TypeSection />
            <VoiceSection />
            <MotionSection />
            <LandingSection />
            <Sec id="onboarding" n={7} title={<>Six windows, <i>one minute.</i></>}
              intro="Onboarding uses the same vibrancy as the app, with a dot meter for progress. Each window asks for one thing. Tap the Accessibility row to grant it.">
              <Onboarding />
            </Sec>
            <AppSection />
            <Scale ticks={96} className="mt-6" />
            <div className="mt-6 flex flex-wrap items-center justify-between gap-4">
              <Lockup size={22} />
              <Label dim>Signal · anyfmt brand direction</Label>
            </div>
          </div>
        </main>
      </div>
    </SignalRoot>
  )
}
