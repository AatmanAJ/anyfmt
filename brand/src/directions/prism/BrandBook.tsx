import { useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ArrowUpRight, Check, RotateCcw, X } from 'lucide-react'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { FloatShelf, MenuBarMenu, OptionsPanel, ProgressHUD, Toast } from './AppSurfaces'
import { LandingParts } from './Landing'
import { AppIcon, Lockup, MenuGlyph, PrismMark, Wordmark } from './Logo'
import { Onboarding } from './Onboarding'
import { Hub, PrismWheel, SEG } from './PrismWheel'
import { Eyebrow, HaloRing, IRIS, Mesh, P, Pill, PrismStyle, Rise, Scaled, Wallpaper, glass } from './theme'
import { meta } from './meta'

const W = 'mx-auto w-full max-w-[1200px] px-5 md:px-8'

const NAV = [
  ['cover', 'Prism'], ['logo', 'Logo'], ['colour', 'Colour'], ['type', 'Type'], ['voice', 'Voice'], ['motion', 'Motion'],
  ['landing', 'Landing'], ['onboarding', 'Onboarding'], ['app', 'App'],
] as const

function BookNav() {
  return (
    <div className="sticky top-3 z-50 px-3">
      <nav className="mx-auto flex max-w-max items-center gap-0.5 overflow-x-auto rounded-full p-1 no-scrollbar" style={glass.light} aria-label="Brand book sections">
        <a href="#cover" className="p-focus mr-1 shrink-0 rounded-full py-1 pl-2 pr-1"><PrismMark size={24} /></a>
        {NAV.slice(1).map(([id, l]) => (
          <a key={id} href={`#${id}`} className="p-focus shrink-0 rounded-full px-3 py-1.5 text-[13px] font-medium text-[#5E5677] transition-colors hover:bg-white hover:text-[#1C1530]">{l}</a>
        ))}
      </nav>
    </div>
  )
}

function Chapter({ id, n, title, intro, children, className }: { id: string; n: string; title: ReactNode; intro?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <section id={id} className={cn('relative scroll-mt-20 py-20 md:py-28', className)}>
      <div className={W}>
        <Rise className="mb-12 grid gap-6 md:mb-16 md:grid-cols-[1fr_1fr] md:items-end">
          <div>
            <div className="font-mono text-[12px] text-[#8E87A6]">{n}</div>
            <h2 className="p-display mb-0 mt-3 text-[48px] font-semibold leading-[.95] md:text-[76px]">{title}</h2>
          </div>
          {intro && <p className="m-0 max-w-[460px] text-[16.5px] leading-[1.6] text-[#5E5677] md:justify-self-end">{intro}</p>}
        </Rise>
        {children}
      </div>
    </section>
  )
}

function Card({ children, className, label, dark, style }: { children: ReactNode; className?: string; label?: ReactNode; dark?: boolean; style?: React.CSSProperties }) {
  return (
    <div className={cn('relative overflow-hidden rounded-[28px]', dark ? 'text-white' : 'text-[#1C1530]', className)} style={{ ...(dark ? { background: P.night } : glass.light), ...style }}>
      {children}
      {label && <div className={cn('absolute bottom-4 left-5 text-[12px] font-medium', dark ? 'text-white/55' : 'text-[#8E87A6]')}>{label}</div>}
    </div>
  )
}

/* ---------------- 1 cover ---------------- */
function Cover() {
  return (
    <section id="cover" className="relative -mt-[60px] flex min-h-[min(100svh,980px)] items-center overflow-hidden pb-20 pt-28">
      <Mesh intensity={1.15} />
      <div className="p-grain absolute inset-0 opacity-[.14] mix-blend-overlay" />
      <div aria-hidden className="absolute inset-x-0 bottom-0 h-48 bg-gradient-to-b from-transparent to-[#F6F4FB]" />
      <div className={cn(W, 'relative grid items-center gap-10 lg:grid-cols-[1.15fr_1fr]')}>
        <div>
          <Rise><Eyebrow>Halo brand · Direction 05</Eyebrow></Rise>
          <Rise delay={0.06}><h1 className="p-display mb-0 mt-6 text-[96px] font-semibold leading-[.85] sm:text-[150px] lg:text-[190px]"><span className="p-iris-text-anim">Prism</span></h1></Rise>
          <Rise delay={0.12}><p className="mb-0 mt-6 max-w-[520px] text-[21px] leading-[1.4] tracking-[-0.015em] text-[#3A3152] md:text-[24px]">{meta.tagline}</p></Rise>
          <Rise delay={0.18}>
            <p className="mb-0 mt-4 max-w-[500px] text-[15px] leading-[1.6] text-[#5E5677]">
              Halo should feel like it shipped with macOS: frosted pearl glass, soft plum shadows, and light that splits into coral, lilac and aqua the moment something happens. Calm at rest, a little magic in motion.
            </p>
          </Rise>
          <Rise delay={0.24} className="mt-8 flex flex-wrap gap-3">
            <Pill href="#app">See the app</Pill>
            <Link to="/d/prism/landing" className="p-focus inline-flex h-10 items-center gap-1.5 rounded-full px-5 text-[14px] font-medium text-[#1C1530]" style={glass.thin}>Open the landing <ArrowUpRight size={15} /></Link>
          </Rise>
        </div>
        <div className="relative mx-auto grid size-[340px] place-items-center sm:size-[460px]">
          <HaloRing size="100%" thickness={1.5} />
          <HaloRing size="78%" thickness={1} bloom={false} className="opacity-50" speed="p-spin-rev" />
          <PrismWheel segments={SEG.convert} size={300} hoverIndex={0} interactive={false} rim={false} className="scale-[.8] sm:scale-100"
                      hubLabel={<PrismMark size={58} />} />
          {[['Pearl', P.pearl, 'left-0 top-[12%]'], ['Coral', P.coral, 'right-0 top-[6%]'], ['Aqua', P.aqua, 'right-[-2%] bottom-[16%]'], ['Lilac', P.lilac, 'left-[2%] bottom-[8%]']].map(([n, c, pos]) => (
            <span key={n} className={cn('absolute flex items-center gap-2 rounded-full px-3 py-1.5 text-[12px] font-medium', pos)} style={glass.light}>
              <span className="size-3 rounded-full shadow-[inset_0_0_0_1px_rgba(28,21,48,.1)]" style={{ background: c }} />{n}
            </span>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ---------------- 2 logo ---------------- */
function Construction() {
  return (
    <svg viewBox="0 0 200 200" className="h-full w-full" aria-label="Logo construction">
      <g stroke="#6B4EFF" strokeWidth=".4" fill="none" opacity=".55">
        <circle cx="100" cy="100" r="83" strokeDasharray="2 2" />
        <circle cx="100" cy="100" r="49" strokeDasharray="2 2" />
        <circle cx="100" cy="100" r="66" />
        <line x1="0" y1="100" x2="200" y2="100" /><line x1="100" y1="0" x2="100" y2="200" />
        <line x1="100" y1="100" x2="38" y2="62" strokeDasharray="1 2" />
      </g>
      <g transform="scale(2)"><PrismMark size={100} /></g>
      <g fontFamily="JetBrains Mono Variable, monospace" fontSize="5" fill="#5E5677">
        <text x="152" y="96">r 66</text><text x="152" y="34">outer 83</text><text x="112" y="58">inner 49</text><text x="16" y="56">glint 10:00</text>
      </g>
    </svg>
  )
}

function LogoChapter() {
  const bgs: [string, React.CSSProperties, boolean][] = [
    ['On Pearl', { background: P.pearl }, false],
    ['On Plum night', { background: P.night }, true],
    ['On iris', { background: `linear-gradient(120deg, #FFC2CF, #DCD3FF 50%, #BDF4EF)` }, false],
  ]
  return (
    <Chapter id="logo" n="02 — Logo" title={<>A halo that<br />catches light.</>}
      intro="The mark is a glass ring: the wheel at rest, the halo around your pointer. One specular glint at ten o’clock does the work of a whole illustration.">
      <div className="grid gap-4 lg:grid-cols-[1.3fr_1fr]">
        <Card className="grid min-h-[420px] place-items-center p-10" label="Primary mark">
          <Mesh intensity={0.5} />
          <div className="relative grid place-items-center">
            <HaloRing size={300} thickness={1} bloom={false} className="opacity-40" />
            <PrismMark size={220} />
          </div>
        </Card>
        <Card className="aspect-square p-6 lg:aspect-auto" label="Construction · 200 unit grid">
          <div className="mx-auto max-w-[360px]"><Construction /></div>
        </Card>
      </div>

      {/* lockups on backgrounds */}
      <div className="mt-4 grid gap-4 md:grid-cols-3">
        {bgs.map(([l, st, dark]) => (
          <Card key={l} className="grid h-[220px] place-items-center" style={st} label={l} dark={dark}>
            <Lockup size={40} dark={dark} />
          </Card>
        ))}
      </div>

      <div className="mt-4 grid gap-4 md:grid-cols-[1fr_1fr_1fr]">
        <Card className="h-[240px] p-6" label="Stacked lockup">
          <div className="grid h-full place-items-center pb-6"><div className="flex flex-col items-center gap-3"><PrismMark size={72} /><Wordmark size={36} /></div></div>
        </Card>
        <Card className="h-[240px] p-6" label="Clear space = ring width (x) on every side">
          <div className="grid h-full place-items-center pb-6">
            <div className="relative p-[22px]" style={{ outline: '1px dashed rgba(107,78,255,.5)', background: 'repeating-linear-gradient(45deg, rgba(185,167,255,.14) 0 4px, transparent 4px 8px)' }}>
              <div className="bg-white/80 p-1"><Lockup size={30} /></div>
              <span className="absolute left-1 top-1 font-mono text-[9px] text-[#6B4EFF]">x</span>
            </div>
          </div>
        </Card>
        <Card className="h-[240px] p-6" label="Minimum sizes">
          <div className="flex h-full items-center justify-center gap-8 pb-6">
            {[[16, 'mark 16 px'], [24, '24 px']].map(([s, l]) => (
              <div key={l} className="flex flex-col items-center gap-2"><PrismMark size={s as number} /><span className="font-mono text-[10px] text-[#8E87A6]">{l}</span></div>
            ))}
            <div className="flex flex-col items-center gap-2"><Lockup size={14} /><span className="font-mono text-[10px] text-[#8E87A6]">lockup 64 px</span></div>
          </div>
        </Card>
      </div>

      {/* app icon + menu bar */}
      <div className="mt-4 grid gap-4 lg:grid-cols-[1.4fr_1fr]">
        <Card className="p-6 pb-14" label="App icon · 1024 grid, Big Sur squircle">
          <Mesh intensity={0.4} />
          <div className="relative flex flex-wrap items-end justify-center gap-6 py-4">
            <AppIcon size={220} />
            <AppIcon size={220} dark />
            <div className="flex items-end gap-3">
              <AppIcon size={64} /><AppIcon size={40} /><AppIcon size={24} />
            </div>
          </div>
        </Card>
        <Card className="p-6 pb-14" label="Menu-bar glyph · template image, 16 and 18 pt">
          <div className="space-y-3">
            {[false, true].map((dk) => (
              <div key={String(dk)} className={cn('flex h-[26px] items-center justify-end gap-4 rounded-[8px] px-3 text-[12px] font-medium', dk ? 'bg-[#1d1828] text-white/90' : 'bg-white/70 text-[#1C1530]')}>
                <span className="opacity-60">Wi‑Fi</span><MenuGlyph size={16} /><span className="grid h-[22px] w-[30px] place-items-center rounded-[6px]" style={{ background: dk ? 'rgba(255,255,255,.2)' : 'rgba(28,21,48,.1)' }}><MenuGlyph size={16} /></span><span className="tabular-nums">9:41</span>
              </div>
            ))}
            <div className="flex items-center justify-center gap-6 pt-3">
              {[16, 18].map((s) => (
                <div key={s} className="flex flex-col items-center gap-2">
                  <div className="relative grid place-items-center rounded-[10px] bg-white" style={{ width: s * 5 + 8, height: s * 5 + 8, backgroundImage: 'linear-gradient(rgba(28,21,48,.07) 1px, transparent 1px), linear-gradient(90deg, rgba(28,21,48,.07) 1px, transparent 1px)', backgroundSize: '5px 5px' }}>
                    <MenuGlyph size={s * 5} className="text-[#1C1530]" />
                  </div>
                  <span className="font-mono text-[10px] text-[#8E87A6]">{s} pt @ 5×</span>
                </div>
              ))}
            </div>
          </div>
        </Card>
      </div>

      {/* do / don't */}
      <div className="mt-4 grid grid-cols-2 gap-4 md:grid-cols-4">
        {[
          ['Do', 'Let it sit on Pearl or glass', <PrismMark size={64} />, true],
          ['Don’t', 'Flatten it to one colour', <svg width="64" height="64" viewBox="0 0 100 100"><circle cx="50" cy="50" r="33" fill="none" stroke={P.coral} strokeWidth="17" /></svg>, false],
          ['Don’t', 'Stretch or squash it', <div style={{ transform: 'scaleX(1.5)' }}><PrismMark size={56} /></div>, false],
          ['Don’t', 'Put it on loud colour', <div className="grid size-20 place-items-center rounded-2xl" style={{ background: '#FF7A00' }}><PrismMark size={52} /></div>, false],
        ].map(([h, t, el, ok], i) => (
          <Card key={i} className="h-[220px] p-5">
            <div className="flex items-center gap-1.5 text-[12.5px] font-semibold">
              <span className="grid size-5 place-items-center rounded-full text-white" style={{ background: ok ? P.success : P.danger }}>{ok ? <Check size={11} strokeWidth={3} /> : <X size={11} strokeWidth={3} />}</span>{h as string}
            </div>
            <div className="grid h-[120px] place-items-center">{el as ReactNode}</div>
            <div className="text-[12.5px] text-[#5E5677]">{t as string}</div>
          </Card>
        ))}
      </div>
    </Chapter>
  )
}

/* ---------------- 3 colour ---------------- */
function lum(hex: string) {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4))
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}
function contrast(a: string, b: string) { const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m); return (x + 0.05) / (y + 0.05) }

function ColourChapter() {
  const sw: [string, string, string, string][] = [
    ['Pearl', P.pearl, 'Canvas. Every light surface starts here.', P.plum],
    ['Plum', P.plum, 'Ink. Headlines, body, the primary button.', P.pearl],
    ['Coral', P.coral, 'Warm refraction. Hovered wedges, starts.', P.plum],
    ['Lilac', P.lilac, 'Mid refraction. Glows, selection, focus halo.', P.plum],
    ['Aqua', P.aqua, 'Cool refraction. Success, the end of a gradient.', P.plum],
    ['Iris', P.iris, 'Links and focus rings, where text needs a hue.', '#FFFFFF'],
  ]
  const tokens: [string, string, string, string][] = [
    ['--p-canvas', P.pearl, P.night, 'Page and window background'],
    ['--p-ink', P.plum, '#FFFFFF', 'Primary text, primary button'],
    ['--p-ink-2', P.plum60, 'rgba(255,255,255,.65)', 'Body copy, secondary text'],
    ['--p-ink-3', P.plum40, 'rgba(255,255,255,.45)', 'Captions, shortcuts (large or non-essential only)'],
    ['--p-glass', 'rgba(255,255,255,.62)', 'rgba(36,28,60,.68)', 'Panels, wheel wedges, HUD'],
    ['--p-glass-edge', 'rgba(255,255,255,.95)', 'rgba(255,255,255,.16)', '1 px inner highlight on all glass'],
    ['--p-shadow', 'rgba(44,30,90,.32)', 'rgba(0,0,0,.7)', 'Soft plum drop shadow'],
    ['--p-iris', 'Coral → Lilac → Aqua', 'same', 'Hover, progress, selection'],
    ['--p-focus', P.iris, P.lilac, 'Focus ring, links'],
    ['--p-success', P.success, P.aqua, 'Done toasts'],
    ['--p-danger', P.danger, '#FF8FA3', 'Error toasts'],
  ]
  const isHex = (v: string) => v.startsWith('#')
  return (
    <Chapter id="colour" n="03 — Colour" title={<>Pearl, plum,<br />and refractions.</>}
      intro="Two neutrals carry the interface. The three refractions only ever appear together, as light: in gradients, glows and the hovered wedge. Never as flat fills for text.">
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
        {sw.map(([n, hex, role, fg], i) => (
          <Rise key={n} delay={i * 0.04}>
            <div className="relative h-[220px] overflow-hidden rounded-[26px] p-5 md:h-[260px]" style={{ background: hex, color: fg, boxShadow: hex === P.pearl ? 'inset 0 0 0 1px rgba(28,21,48,.08)' : '0 20px 40px -24px rgba(44,30,90,.5)' }}>
              <div className="flex items-baseline justify-between"><span className="text-[19px] font-semibold tracking-[-0.02em]">{n}</span><span className="font-mono text-[12px] opacity-80">{hex}</span></div>
              <p className="m-0 mt-2 max-w-[240px] text-[13px] leading-[1.45] opacity-80">{role}</p>
              <div className="absolute bottom-5 left-5 right-5 flex items-center justify-between font-mono text-[11px]">
                <span className="opacity-80">vs Plum {contrast(hex, P.plum).toFixed(1)}:1</span>
                <span className="opacity-80">vs Pearl {contrast(hex, P.pearl).toFixed(1)}:1</span>
              </div>
            </div>
          </Rise>
        ))}
      </div>
      <div className="mt-3 overflow-hidden rounded-[26px] p-6 text-[#1C1530] md:p-8" style={{ background: IRIS }}>
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div><div className="text-[19px] font-semibold tracking-[-0.02em]">The Iris</div><p className="m-0 mt-1 max-w-[460px] text-[13.5px] opacity-80">115° linear for surfaces, conic around rings. It turns, slowly, on anything that is alive.</p></div>
          <span className="font-mono text-[12px] opacity-80">#FF6B8B → #B9A7FF → #5EE7DF</span>
        </div>
      </div>

      <div className="mt-6 grid gap-3 md:grid-cols-3">
        {[
          ['Plum on Pearl', `${contrast(P.plum, P.pearl).toFixed(1)}:1`, 'Headlines and body. AAA.'],
          ['Plum 60 on Pearl', `${contrast(P.plum60, P.pearl).toFixed(1)}:1`, 'Secondary body copy. AA at any size.'],
          ['Plum on Coral', `${contrast(P.plum, P.coral).toFixed(1)}:1`, 'Text on a refraction always stays Plum, including the label on the hovered wedge.'],
        ].map(([a, b, c]) => (
          <div key={a} className="rounded-[22px] p-5" style={glass.thin}>
            <div className="flex items-baseline justify-between"><span className="text-[14px] font-semibold">{a}</span><span className="font-mono text-[13px] text-[#6B4EFF]">{b}</span></div>
            <p className="m-0 mt-2 text-[13px] leading-[1.5] text-[#5E5677]">{c}</p>
          </div>
        ))}
      </div>

      <div className="mt-6 overflow-x-auto rounded-[26px]" style={glass.light}>
        <table className="w-full min-w-[640px] border-collapse text-left text-[13px]">
          <thead><tr className="text-[11.5px] font-medium uppercase tracking-[.08em] text-[#8E87A6]">
            <th className="px-5 py-4 font-medium">Token</th><th className="px-5 py-4 font-medium">Pearl (light)</th><th className="px-5 py-4 font-medium">Plum night (dark)</th><th className="px-5 py-4 font-medium">Use</th>
          </tr></thead>
          <tbody>
            {tokens.map(([t, l, d, u]) => (
              <tr key={t} className="border-t border-[#1C1530]/[.06]">
                <td className="px-5 py-3 font-mono text-[12.5px] text-[#6B4EFF]">{t}</td>
                {[l, d].map((v, i) => (
                  <td key={i} className="px-5 py-3"><span className="inline-flex items-center gap-2 font-mono text-[12px]">
                    <span className="size-4 rounded-[5px] shadow-[inset_0_0_0_1px_rgba(28,21,48,.12)]" style={{ background: v.includes('→') || v === 'same' ? IRIS : i === 1 && !isHex(v) ? `linear-gradient(${v}, ${v}), ${P.night}` : v }} />{v}</span></td>
                ))}
                <td className="px-5 py-3 text-[#5E5677]">{u}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Chapter>
  )
}

/* ---------------- 4 type ---------------- */
function TypeChapter() {
  const scale: [string, string, string, string][] = [
    ['Display', '104 / 0.95', '−4.5%', 'Mid‑air.'],
    ['Title 1', '60 / 1.0', '−4.5%', 'One drag. Three keys.'],
    ['Title 2', '40 / 1.05', '−4%', 'Nothing leaves your Mac.'],
    ['Title 3', '28 / 1.1', '−3%', 'Convert'],
    ['Body', '17 / 1.55', '−0.5%', 'Drag a file in Finder. Press a key. Drop.'],
    ['UI', '13.5 / 1.3', '−1.5%', 'Making clip.gif · 62% · 3 s left'],
    ['Label', '11 / caps', '+8%', 'FRAME RATE'],
    ['Mono', '12 / 1.7', '0', 'halo convert clip.mov --to gif'],
  ]
  return (
    <Chapter id="type" n="04 — Type" title={<>Inter, cut<br />for display.</>}
      intro="One family, two optical sizes. Inter Display (opsz 32) runs big and tight for headlines; Inter Text keeps the UI as legible as the system font. JetBrains Mono for anything a terminal would print.">
      <div className="grid gap-4 lg:grid-cols-[1fr_1.1fr]">
        <Card className="relative min-h-[420px] p-8">
          <Mesh intensity={0.5} />
          <div className="relative">
            <div className="p-display text-[200px] font-semibold leading-[.8] md:text-[260px]"><span className="p-iris-text">Aa</span></div>
            <div className="mt-6 grid grid-cols-2 gap-4 text-[13px] text-[#5E5677]">
              <div><div className="text-[15px] font-semibold text-[#1C1530]">Inter Display</div>Semibold 600 · opsz 32 · −4.5% tracking</div>
              <div><div className="text-[15px] font-semibold text-[#1C1530]">Inter Text</div>Regular 400 / Medium 500 · −0.5%</div>
            </div>
            <div className="mt-5 break-all font-mono text-[12px] leading-[1.7] text-[#8E87A6]">ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 ⇧⌘⌃ → · %</div>
          </div>
        </Card>
        <Card className="p-2">
          {scale.map(([n, s, t, ex]) => (
            <div key={n} className="grid grid-cols-[88px_1fr] items-baseline gap-3 border-b border-[#1C1530]/[.06] px-4 py-3 last:border-0 md:grid-cols-[100px_110px_1fr]">
              <span className="text-[12.5px] font-semibold">{n}</span>
              <span className="hidden font-mono text-[11px] text-[#8E87A6] md:block">{s} · {t}</span>
              <span className={cn('min-w-0 truncate',
                n === 'Display' && 'p-display text-[38px] font-semibold leading-none', n === 'Title 1' && 'p-display text-[30px] font-semibold leading-none',
                n === 'Title 2' && 'p-display text-[24px] font-semibold', n === 'Title 3' && 'p-display text-[20px] font-semibold',
                n === 'Body' && 'text-[16px] text-[#5E5677]', n === 'UI' && 'text-[13.5px] font-medium', n === 'Label' && 'text-[11px] font-medium uppercase tracking-[.08em] text-[#5E5677]',
                n === 'Mono' && 'font-mono text-[12px]')}>{ex}</span>
            </div>
          ))}
        </Card>
      </div>
      <div className="mt-4 grid gap-3 md:grid-cols-3">
        {[
          ['Tight at the top', 'Display sizes track in hard, −4% to −4.5%. Below 20 px, let Inter breathe at −0.5% or less.'],
          ['Sentence case, always', 'Headlines read like something a friend would say. Caps only for tiny labels in the app.'],
          ['One accent per line', 'A single word may carry the Iris gradient. Never a whole paragraph, never body copy.'],
        ].map(([h, b]) => (
          <div key={h} className="rounded-[22px] p-5" style={glass.thin}>
            <div className="text-[15px] font-semibold">{h}</div>
            <p className="m-0 mt-1.5 text-[13.5px] leading-[1.55] text-[#5E5677]">{b}</p>
          </div>
        ))}
      </div>
    </Chapter>
  )
}

/* ---------------- 5 voice ---------------- */
function VoiceChapter() {
  const rules: [string, string, string, string][] = [
    ['Light, not cute', 'Warm and quick. A smile, never a wink.', 'clip.gif is ready. 4.1 MB, right next to the original.', 'Woohoo!!! Your GIF is SO ready!!!'],
    ['Say what happened', 'Name the file, the format and the size.', 'Compressed Invoice 214.pdf to 1.2 MB.', 'Operation completed successfully.'],
    ['Blame the situation, not the person', 'Errors explain and offer the next move.', 'That file is locked by another app. Close it and drop again.', 'You dropped an invalid file.'],
    ['Short enough to read mid-drag', 'Toasts are one line, then one detail.', 'On your Float shelf.', 'Your file has now been added to the Float shelf, where…'],
    ['Honest about the cloud', 'Local is the default. Say so when it isn’t.', 'This one’s 4 GB. Send it to Pro cloud? It’s deleted after.', 'Optimising your experience…'],
  ]
  return (
    <Chapter id="voice" n="05 — Voice" title={<>Friendly,<br />light, clear.</>}
      intro="Halo talks like a helpful friend looking over your shoulder: brief, specific, a little delighted when things work, and calm when they don’t.">
      <div className="space-y-3">
        {rules.map(([h, s, d, dn], i) => (
          <Rise key={h} delay={i * 0.03}>
            <div className="grid gap-4 rounded-[24px] p-5 md:grid-cols-[1fr_1.2fr_1.2fr] md:p-6" style={glass.light}>
              <div><div className="font-mono text-[11px] text-[#8E87A6]">0{i + 1}</div><div className="mt-1 text-[18px] font-semibold tracking-[-0.02em]">{h}</div><div className="mt-1 text-[13.5px] text-[#5E5677]">{s}</div></div>
              <div className="rounded-[16px] bg-white/70 p-4 text-[14px]"><div className="mb-1.5 flex items-center gap-1.5 text-[11.5px] font-semibold text-[#2FBF9B]"><Check size={12} strokeWidth={3} /> Say</div>{d}</div>
              <div className="rounded-[16px] bg-[#1C1530]/[.04] p-4 text-[14px] text-[#5E5677]"><div className="mb-1.5 flex items-center gap-1.5 text-[11.5px] font-semibold text-[#E5486A]"><X size={12} strokeWidth={3} /> Not</div><span className="line-through decoration-[#E5486A]/40">{dn}</span></div>
            </div>
          </Rise>
        ))}
      </div>
      <Wallpaper className="mt-6 rounded-[30px] p-6 md:p-10">
        <div className="mb-6 text-[12px] font-medium text-[#3A3152]">Microcopy in the wild</div>
        <div className="grid grid-cols-[minmax(0,1fr)] items-start gap-5 md:grid-cols-2 lg:grid-cols-3">
          <Toast />
          <Toast kind="error" />
          <Toast title="Saved as a preset" body="GIF · 15 fps now lives on your wheel" action="Undo" />
          <Toast kind="error" title="No route to .key yet" body="Try PDF, then convert from there." action="Use PDF" />
          <Toast title="Copied the path" body="~/Desktop/clip.gif" action="Open" />
          <div className="rounded-[22px] p-5 text-center" style={glass.light}>
            <div className="mx-auto grid size-12 place-items-center rounded-full border border-dashed border-[#B9A7FF]"><MenuGlyph size={18} className="text-[#6B4EFF]" /></div>
            <div className="mt-3 text-[14px] font-semibold">Your shelf is empty</div>
            <p className="m-0 mt-1 text-[12.5px] text-[#5E5677]">Hold ⌃ mid-drag and drop on Float. Files wait here for you.</p>
          </div>
        </div>
      </Wallpaper>
    </Chapter>
  )
}

/* ---------------- 6 motion & materials ---------------- */
function MotionChapter() {
  const [k, setK] = useState(0)
  const [hover, setHover] = useState<number | null>(0)
  return (
    <Chapter id="motion" n="06 — Motion & materials" title={<>Glass, light,<br />and springs.</>}
      intro="Materials are borrowed from macOS and pushed one step: heavier blur, a brighter edge, and a refraction that only shows up when you touch something.">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <Card className="h-[340px]" label={<>Bloom · spring 420 / 30, blur 10 → 0</>}>
          <div className="grid h-full place-items-center pb-8">
            <PrismWheel key={k} segments={SEG.actions} size={210} hoverIndex={1} interactive={false} rim={false} hubLabel={<Hub size="1 file" small />} />
          </div>
          <button onClick={() => setK(k + 1)} className="p-focus absolute right-4 top-4 inline-flex items-center gap-1.5 rounded-full bg-white px-3 py-1.5 text-[12px] font-medium shadow-sm"><RotateCcw size={12} /> Replay</button>
        </Card>
        <Card className="h-[340px]" label="Frosted glass · blur 28, saturate 180%, 1 px edge">
          <Mesh intensity={1.6} />
          <div className="relative grid h-full place-items-center pb-8">
            <div className="p-shimmer grid h-[150px] w-[220px] place-items-center rounded-[28px]" style={glass.light}>
              <span className="text-[13px] font-medium text-[#3A3152]">Pearl glass</span>
            </div>
          </div>
        </Card>
        <Card className="h-[340px]" label="Iridescence · conic, one turn per 40 s" dark>
          <Mesh dark intensity={0.6} />
          <div className="relative grid h-full place-items-center pb-8">
            <HaloRing size={190} thickness={3} speed="p-spin" />
            <HaloRing size={130} thickness={1.5} bloom={false} speed="p-spin-rev" />
            <span className="absolute text-[13px] font-medium text-white/80">Halo ring</span>
          </div>
        </Card>
        <Card className="h-[340px]" label="Lift · hovered wedge rises 2% and glows (try it)">
          <div className="grid h-full place-items-center pb-8">
            <PrismWheel segments={SEG.convert} size={230} rim={false} hoverIndex={hover} onHover={() => {}} interactive={false} hubLabel={<Hub size="18 MB" small />} />
            <div className="absolute inset-x-0 top-4 flex justify-center gap-1">
              {SEG.convert.map((s, i) => <button key={s.id} onPointerEnter={() => setHover(i)} onClick={() => setHover(i)} className={cn('p-focus rounded-full px-2 py-1 font-mono text-[10px]', hover === i ? 'bg-[#1C1530] text-white' : 'bg-white/70 text-[#5E5677]')}>{s.label}</button>)}
            </div>
          </div>
        </Card>
        <Card className="h-[340px]" label="Caustic · soft drifting light pools behind glass">
          <div className="absolute inset-0 overflow-hidden"><Mesh intensity={2} /></div>
          <div className="relative grid h-full place-items-center pb-8">
            <ProgressHUD className="scale-[.85]" />
          </div>
        </Card>
        <Card className="h-[340px] p-6" label="Principles">
          <ul className="m-0 list-none space-y-3.5 p-0 text-[14px]">
            {[
              ['Springs, not easings', 'Everything that moves has mass. 420 / 30 for the wheel, 300 / 26 for toasts.'],
              ['Blur in, blur out', 'Elements arrive from 8–10 px of blur, like focusing a lens.'],
              ['Light means life', 'Only active things refract. Idle surfaces stay pearl.'],
              ['Calm by default', 'Reduced motion stops rotation and drifting. Nothing essential is lost.'],
            ].map(([h, b]) => <li key={h}><div className="font-semibold">{h}</div><div className="text-[13px] leading-[1.5] text-[#5E5677]">{b}</div></li>)}
          </ul>
        </Card>
      </div>
    </Chapter>
  )
}

/* ---------------- 7 landing ---------------- */
function LandingChapter() {
  return (
    <Chapter id="landing" n="07 — Landing" title={<>The page,<br />in one breath.</>}
      intro="Pearl, then night, then pearl again. The hero is a live desktop where the wheel blooms by itself; further down, the visitor gets a wheel of their own to spin.">
      <Link to="/d/prism/landing" className="p-focus group block overflow-hidden rounded-[30px]" style={glass.light}>
        <div className="flex items-center gap-2 border-b border-white/70 bg-white/50 px-4 py-2.5">
          {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-2.5 rounded-full" style={{ background: c }} />)}
          <span className="mx-auto rounded-full bg-white/80 px-4 py-1 font-mono text-[11px] text-[#5E5677]">halo.app</span>
          <span className="inline-flex items-center gap-1 text-[12px] font-medium text-[#6B4EFF]">Open full page <ArrowUpRight size={13} className="transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" /></span>
        </div>
        <div className="pointer-events-none relative max-h-[880px] overflow-hidden">
          <Scaled w={1280} h={1560}>
            <div className="prism" style={{ background: P.pearl, width: 1280 }}><LandingParts.Hero /></div>
          </Scaled>
          <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-b from-transparent to-[#F6F4FB]" />
        </div>
      </Link>
      <div className="-mx-5 mt-10 md:-mx-8">
        <LandingParts.Playground />
        <LandingParts.Pricing />
      </div>
    </Chapter>
  )
}

/* ---------------- 8 onboarding ---------------- */
function OnboardingChapter() {
  return (
    <Chapter id="onboarding" n="08 — Onboarding" title={<>Six stadiums<br />to magic.</>}
      intro="Setup windows are stadiums, the wheel’s shape stretched into a window. One idea per screen, a real practice drag, and Pro offered once, honestly.">
      <Wallpaper className="rounded-[36px] p-5 sm:p-8 md:p-12">
        <Onboarding />
      </Wallpaper>
    </Chapter>
  )
}

/* ---------------- 9 app ---------------- */
function SurfaceBoard({ dark }: { dark?: boolean }) {
  const cap = dark ? 'text-white/60' : 'text-[#3A3152]'
  const L = ({ children }: { children: ReactNode }) => <div className={cn('mt-4 text-center text-[12px] font-medium', cap)}>{children}</div>
  return (
    <Wallpaper dark={dark} className="rounded-[36px] px-4 py-10 sm:p-10 md:p-14">
      <div className="mb-10 flex flex-wrap items-center justify-between gap-3">
        <div className={cn('text-[20px] font-semibold tracking-[-0.02em]', dark ? 'text-white' : 'text-[#1C1530]')}>{dark ? 'Plum night' : 'Pearl'}</div>
        <span className={cn('rounded-full px-3 py-1 font-mono text-[11px]', dark ? 'text-white/70' : 'text-[#3A3152]')} style={dark ? glass.dark : glass.thin}>{dark ? 'macOS dark appearance' : 'macOS light appearance'}</span>
      </div>
      {/* wheels at real size */}
      <div className="grid grid-cols-[minmax(0,1fr)] justify-items-center gap-x-8 gap-y-12 lg:grid-cols-3">
        {([['⇧ Convert · clip.mov', SEG.convert, 0, '18.4 MB'], ['⌘ Tools · Invoice 214.pdf', SEG.tools, 6, '2.4 MB'], ['⌃ Actions · beach.heic', SEG.actions, 1, '1 file']] as const).map(([l, segs, h, sz]) => (
          <div key={l} className="flex w-full flex-col items-center">
            <div className="w-full max-w-[340px]"><Scaled w={340} h={340}><PrismWheel segments={segs} size={340} tone={dark ? 'dark' : 'light'} hoverIndex={isShot ? h : undefined} hubLabel={<Hub size={sz} name={l.split('· ')[1]} />} /></Scaled></div>
            <L>{l}</L>
          </div>
        ))}
      </div>
      <div className="mt-16 grid grid-cols-[minmax(0,1fr)] items-start justify-items-center gap-12 lg:grid-cols-3">
        <div className="flex w-full max-w-[340px] flex-col items-center"><OptionsPanel dark={dark} /><L>Options · ⌥ while hovering GIF</L></div>
        <div className="flex w-full max-w-[360px] flex-col items-center gap-4">
          <ProgressHUD dark={dark} />
          <ProgressHUD dark={dark} value={0.18} live={false} />
          <L>Progress HUD · top centre of the screen</L>
          <div className="mt-4 flex w-full flex-col items-center gap-3">
            <Toast dark={dark} />
            <Toast dark={dark} kind="error" />
            <L>Done and error toasts</L>
          </div>
        </div>
        <div className="flex w-full flex-col items-center"><MenuBarMenu dark={dark} /><L>Menu-bar menu</L></div>
      </div>
      <div className="mt-16 flex flex-wrap items-start justify-center gap-10">
        <div className="flex flex-col items-center"><FloatShelf dark={dark} /><L>Float shelf · holding 4 files</L></div>
        <div className="flex flex-col items-center"><FloatShelf dark={dark} empty /><L>Float shelf · empty</L></div>
      </div>
    </Wallpaper>
  )
}

function AppChapter() {
  return (
    <Chapter id="app" n="09 — App surfaces" title={<>Native,<br />with a glint.</>}
      intro="Every surface is real-size and built the way the app draws it: one pearl glass material, rounded wedges, and the Iris reserved for whatever is under your pointer. Hover the wheels.">
      <div className="space-y-6">
        <SurfaceBoard />
        <SurfaceBoard dark />
      </div>
    </Chapter>
  )
}

export function BrandBook() {
  return (
    <div className="prism min-h-screen overflow-x-clip" style={{ background: P.pearl }}>
      <PrismStyle />
      <BookNav />
      <Cover />
      <LogoChapter />
      <ColourChapter />
      <TypeChapter />
      <VoiceChapter />
      <MotionChapter />
      <LandingChapter />
      <OnboardingChapter />
      <AppChapter />
      <footer className={cn(W, 'flex flex-col items-center gap-3 pb-28 pt-10 text-center')}>
        <Lockup size={26} />
        <span className="text-[12.5px] text-[#8E87A6]">Prism · a brand direction for Halo · open source, AGPL-3.0</span>
      </footer>
    </div>
  )
}
