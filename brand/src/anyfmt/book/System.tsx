import { ArrowRight, Check, Copy, Crop, Download, Eye, Keyboard, Lock, MousePointer2, ShieldCheck, Volume2, WifiOff } from 'lucide-react'
import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { AnyWheel } from '../AnyWheel'
import { Key, Streaks, WHEELS } from '../Landing'
import { AppIcon } from '../Mark'
import { contrast, Fit, grade, InkPanel, Section, Spec, Sub, Verdict } from './kit'

/* ---------- 04 Colour ---------- */

type Swatch = { name: string; hex: string; token: string; role: string; semantic: string }
const CORE: Swatch[] = [
  { name: 'Orange', hex: '#EA7C25', token: '--af-orange', semantic: 'action, light', role: 'Light and action: primary buttons, the hot wedge, stages. Never long text.' },
  { name: 'Ember', hex: '#BB3F14', token: '--af-ember', semantic: 'action-pressed, depth', role: 'Depth under orange: pressed states, extrusion, orange text on paper.' },
  { name: 'Ink', hex: '#111111', token: '--af-ink', semantic: 'text, surface-inverse', role: 'Text, and the dark card for specimens and the menu-bar band.' },
  { name: 'Paper', hex: '#F7F7F7', token: '--af-paper', semantic: 'surface-page', role: 'The page itself. Most of every screen is paper.' },
]
const SUPPORT: Swatch[] = [
  { name: 'Apricot', hex: '#FFA45C', token: '--af-apricot', semantic: 'highlight', role: 'The lit top of a wedge or button.' },
  { name: 'Glow', hex: '#FFD2A8', token: '--af-glow', semantic: 'streak', role: 'Light streaks on the orange stage.' },
  { name: 'White', hex: '#FFFFFF', token: '--af-white', semantic: 'surface-raised', role: 'Cards, wells, keycaps, toasts.' },
  { name: 'Ink 2', hex: '#55524F', token: '--af-ink-2', semantic: 'text-secondary', role: 'Body copy and descriptions.' },
  { name: 'Ink 3', hex: '#8C8884', token: '--af-ink-3', semantic: 'text-tertiary', role: 'Captions, meta, the grey second line.' },
  { name: 'Line', hex: '#E7E5E2', token: '--af-line', semantic: 'border', role: 'The one hairline around a card.' },
  { name: 'Line 2', hex: '#D9D6D2', token: '--af-line-2', semantic: 'border-strong', role: 'Chip and keycap edges, rules.' },
  { name: 'OK', hex: '#1F9D55', token: '--af-ok', semantic: 'status-ok', role: 'Success only: granted, done.' },
]

function Ratio({ hex, on }: { hex: string; on: 'white' | 'ink' }) {
  const bg = on === 'white' ? '#FFFFFF' : '#111111'
  const r = contrast(hex, bg)
  const g = grade(r)
  return (
    <div className="flex items-center gap-2.5 rounded-[10px] px-2.5 py-1.5" style={{ background: bg, boxShadow: on === 'white' ? 'inset 0 0 0 1px #E7E5E2' : 'none' }}>
      <span className="w-6 text-[15px] font-semibold leading-none" style={{ color: hex }}>Aa</span>
      <span className={`text-[12px] ${on === 'white' ? 'text-[#8C8884]' : 'text-white/50'}`}>on {on}</span>
      <span className={`af-mono ml-auto text-[11.5px] ${on === 'white' ? 'text-[#111]' : 'text-white'}`}>{r.toFixed(2)}</span>
      <span className={`w-[62px] whitespace-nowrap rounded-[5px] py-[1px] text-center text-[10px] font-semibold ${g === 'Fail' ? (on === 'white' ? 'bg-[#F3F2F0] text-[#8C8884]' : 'bg-white/10 text-white/50') : g === 'AA Large' ? 'bg-[#FFF3E6] text-[#B4570F]' : 'bg-[#E9F7EF] text-[#1F7A45]'}`}>{g}</span>
    </div>
  )
}

function SwatchCard({ s, big }: { s: Swatch; big?: boolean }) {
  const light = contrast(s.hex, '#111') > contrast(s.hex, '#fff')
  return (
    <div className="af-card flex flex-col overflow-hidden p-2">
      <div className={`relative flex flex-col justify-end rounded-[14px] p-4 ${big ? 'h-[180px]' : 'h-[104px]'}`}
        style={{ background: s.hex, boxShadow: s.hex === '#FFFFFF' || s.hex === '#F7F7F7' ? 'inset 0 0 0 1px #E7E5E2' : 'inset 0 1px 0 rgba(255,255,255,.2)' }}>
        {s.name === 'Orange' && <Streaks className="inset-0 h-full w-full opacity-60" />}
        <span className="af-mono relative text-[12px]" style={{ color: light ? 'rgba(17,17,17,.6)' : 'rgba(255,255,255,.85)' }}>{s.hex}</span>
      </div>
      <div className="flex flex-1 flex-col gap-3 px-2.5 pb-2 pt-3.5">
        <div>
          <div className="flex items-baseline justify-between gap-2"><span className="text-[16px] font-semibold tracking-[-0.02em]">{s.name}</span><Spec>{s.token}</Spec></div>
          <p className="mt-1 text-[13.5px] leading-snug text-[#55524F]">{s.role}</p>
        </div>
        <div className="mt-auto grid gap-1.5"><Ratio hex={s.hex} on="white" /><Ratio hex={s.hex} on="ink" /></div>
      </div>
    </div>
  )
}

function Tokens() {
  const extra: [string, string, string][] = [
    ['.af-stage', '3 layers', 'Orange panels: heroes, bands, Pro'],
    ['.af-btn-primary', 'orange, lit', 'The one main action per view'],
    ['.af-btn-light / -ghost / -dark', 'white, glass, ink', 'Secondary actions on paper, orange and ink'],
    ['.af-card', 'white + hairline', 'Raised content'],
    ['.af-well', 'inset paper', 'Content inside a card'],
    ['.af-chip / .af-chip-on', 'pill, 30 px', 'Options and filters'],
    ['.af-key', '64 px keycap', 'Shift, Command, Control'],
    ['.af-pill-status', '22 px tag', 'Pro, Beta, New'],
  ]
  return (
    <div className="af-card overflow-hidden">
      <div className="hidden grid-cols-[1.2fr_.8fr_1fr_1.6fr] gap-4 border-b border-[#E7E5E2] px-5 py-3 text-[12px] font-semibold text-[#8C8884] md:grid">
        <span>Token</span><span>Value</span><span>Semantic role</span><span>Use</span>
      </div>
      {[...CORE, ...SUPPORT].map((s) => (
        <div key={s.token} className="grid grid-cols-[1fr_auto] items-center gap-x-4 gap-y-1 border-b border-[#E7E5E2] px-5 py-3 md:grid-cols-[1.2fr_.8fr_1fr_1.6fr]">
          <span className="af-mono flex items-center gap-2.5 text-[13px]"><span className="size-4 shrink-0 rounded-[5px]" style={{ background: s.hex, boxShadow: 'inset 0 0 0 1px rgba(17,17,17,.12)' }} />{s.token}</span>
          <span className="af-mono text-[13px] text-[#55524F]">{s.hex}</span>
          <span className="af-mono text-[12.5px] text-[#B4570F] max-md:col-span-2">{s.semantic}</span>
          <span className="text-[13.5px] text-[#55524F] max-md:col-span-2">{s.role.split(':')[0].split('.')[0]}</span>
        </div>
      ))}
      <div className="bg-[#FAFAF9] px-5 py-2.5 text-[12px] font-semibold text-[#8C8884]">Component classes</div>
      {extra.map(([t, v, u]) => (
        <div key={t} className="grid grid-cols-[1fr_auto] items-center gap-x-4 gap-y-1 border-t border-[#E7E5E2] px-5 py-3 md:grid-cols-[1.2fr_.8fr_1fr_1.6fr]">
          <span className="af-mono text-[13px]">{t}</span>
          <span className="af-mono text-[13px] text-[#55524F]">{v}</span>
          <span className="hidden md:block" />
          <span className="text-[13.5px] text-[#55524F] max-md:col-span-2">{u}</span>
        </div>
      ))}
    </div>
  )
}

function Code({ children }: { children: string }) {
  return (
    <pre className="af-mono overflow-x-auto rounded-[14px] bg-[#111] p-4 text-[12px] leading-[1.75] text-white/80 shadow-[0_0_0_1px_#000]">
      {children.split('\n').map((l, i) => {
        const m = l.match(/^(\s*)([\w-]+)(:)(.*)$/)
        return <div key={i}>{m ? <>{m[1]}<span className="text-[#F59248]">{m[2]}</span>{m[3]}<span className="text-white">{m[4]}</span></> : l}</div>
      })}
    </pre>
  )
}

function Layer({ c, label, v }: { c: string; label: string; v: string }) {
  return (
    <li className="flex items-center gap-3">
      <span className="size-7 shrink-0 rounded-full" style={{ background: c, boxShadow: 'inset 0 0 0 1px rgba(17,17,17,.1)' }} />
      <div className="min-w-0"><div className="text-[14px] font-semibold">{label}</div><div className="af-mono truncate text-[11.5px] text-[#8C8884]">{v}</div></div>
    </li>
  )
}

function Gradients() {
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <div className="af-card flex flex-col gap-6 p-6 sm:p-8">
        <div className="af-stage relative h-[200px] overflow-hidden rounded-[16px]">
          <Streaks className="inset-0 h-full w-full" />
          <span className="absolute bottom-4 left-4 rounded-full bg-white/15 px-3 py-1 text-[12px] font-medium ring-1 ring-white/35 backdrop-blur">.af-stage</span>
        </div>
        <div>
          <h4 className="text-[20px] font-semibold tracking-[-0.03em]">The stage</h4>
          <p className="mt-1 text-[14.5px] leading-relaxed text-[#55524F]">Three layers, bottom up, then light streaks blended with screen. The light always enters top left.</p>
        </div>
        <ol className="grid gap-3">
          <Layer c="linear-gradient(160deg,#F08A35,#EA7C25 40%,#D9601D)" label="1 · Base" v="linear 160° F08A35 → EA7C25 → D9601D" />
          <Layer c="radial-gradient(circle at 30% 20%,#FF9A4A,#EA7C25)" label="2 · Light, top left" v="radial 120×90% at 20% 0, FF9A4A" />
          <Layer c="radial-gradient(circle at 70% 80%,#C9461A,#EA7C25)" label="3 · Shade, bottom right" v="radial 90×80% at 100% 100%, C9461A" />
          <Layer c="linear-gradient(90deg,#EA7C25,#FFD2A8,#EA7C25)" label="4 · Streaks" v="FFD2A8 + white, blur, screen" />
        </ol>
        <Code>{`background:
  radial-gradient(120% 90% at 20% 0%, #FF9A4A 0%, transparent 55%),
  radial-gradient(90% 80% at 100% 100%, #C9461A 0%, transparent 60%),
  linear-gradient(160deg, #F08A35 0%, #EA7C25 40%, #D9601D 100%);`}</Code>
      </div>
      <div className="af-card flex flex-col gap-6 p-6 sm:p-8">
        <div className="af-well grid h-[200px] place-items-center">
          <span className="af-btn af-btn-primary !h-14 !rounded-[16px] !px-8 !text-[18px]"><Download size={20} />Download for Mac</span>
        </div>
        <div>
          <h4 className="text-[20px] font-semibold tracking-[-0.03em]">The lit button</h4>
          <p className="mt-1 text-[14.5px] leading-relaxed text-[#55524F]">Lit from the top, pressed into the page. A highlight line on top, a darker lip below, an ember edge and a warm shadow.</p>
        </div>
        <ol className="grid gap-3">
          <Layer c="linear-gradient(180deg,#F59248,#E5701E)" label="1 · Face" v="linear 180° F59248 → E5701E" />
          <Layer c="linear-gradient(180deg,#fff,#F59248 40%)" label="2 · Top light" v="inset 0 1px 0 white 45%" />
          <Layer c="#C5521A" label="3 · Edge" v="0 0 0 1px C5521A, lip 8C2805 25%" />
          <Layer c="radial-gradient(circle,#E58A5C,#F7F7F7)" label="4 · Glow" v="0 6px 16px -4px BB3F14 55%" />
        </ol>
        <Code>{`background: linear-gradient(180deg, #F59248 0%, #E5701E 100%);
box-shadow:
  inset 0 1px 0 rgba(255,255,255,.45),
  inset 0 -2px 0 rgba(140,40,5,.25),
  0 0 0 1px #C5521A,
  0 6px 16px -4px rgba(187,63,20,.55);`}</Code>
      </div>
    </div>
  )
}

function RatioRule() {
  const parts = [
    { name: 'Paper', pct: 56, c: '#F7F7F7', fg: '#111', note: 'The page. Space is what makes it calm.' },
    { name: 'White', pct: 26, c: '#FFFFFF', fg: '#111', note: 'Cards, wells and toasts sit on paper.' },
    { name: 'Ink', pct: 12, c: '#111111', fg: '#fff', note: 'Text, plus one dark band per page at most.' },
    { name: 'Orange', pct: 6, c: '#EA7C25', fg: '#fff', note: 'Light and action: the stage, the main button, the hot wedge.' },
  ]
  return (
    <div className="af-card flex flex-col gap-6 p-6 sm:p-8">
      <div className="flex h-[88px] overflow-hidden rounded-[14px] shadow-[0_0_0_1px_#E7E5E2]">
        {parts.map((p) => (
          <div key={p.name} className="flex flex-col justify-end px-2 pb-2.5 sm:px-3" style={{ width: `${p.pct}%`, background: p.name === 'Orange' ? 'linear-gradient(160deg,#F08A35,#EA7C25 40%,#D9601D)' : p.c, color: p.fg, borderRight: p.name === 'Paper' ? '1px solid #E7E5E2' : undefined }}>
            <span className={`af-mono text-[11px] opacity-70 ${p.pct < 10 ? 'max-sm:hidden' : ''}`}>{p.pct}%</span>
          </div>
        ))}
      </div>
      <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {parts.map((p) => (
          <div key={p.name}>
            <div className="flex items-center gap-2"><span className="size-3 rounded-full" style={{ background: p.c, boxShadow: 'inset 0 0 0 1px rgba(17,17,17,.15)' }} /><span className="text-[15px] font-semibold">{p.name}</span><Spec>~{p.pct}%</Spec></div>
            <p className="mt-1 text-[14px] leading-snug text-[#55524F]">{p.note}</p>
          </div>
        ))}
      </div>
    </div>
  )
}

export function Colour() {
  return (
    <Section id="colour" n="04" eyebrow="Colour" title={<>Orange is the light.<br /><span className="text-[#8C8884]">Paper does the work.</span></>}
      intro="A warm, small palette. Orange is reserved for light and action, so it always means something. Contrast is computed against white and ink; orange text is for large type only.">
      <Sub title="Core" aside={<Spec>WCAG 2.1 contrast · AA 4.5 · AA Large 3.0</Spec>}>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{CORE.map((s) => <SwatchCard key={s.hex} s={s} big />)}</div>
      </Sub>
      <Sub title="Support">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">{SUPPORT.map((s) => <SwatchCard key={s.hex} s={s} />)}</div>
      </Sub>
      <Sub title="Semantic tokens" note={<>Every surface reads these variables from <span className="af-mono text-[13px]">anyfmt.css</span>. Use the token, never the hex.</>}>
        <Tokens />
      </Sub>
      <Sub title="Gradient recipes">
        <Gradients />
      </Sub>
      <Sub title="The ratio rule" note="Roughly how much of a typical screen each colour covers.">
        <RatioRule />
      </Sub>
    </Section>
  )
}

/* ---------- 05 Type ---------- */

const WEIGHTS = [['Light', 300], ['Regular', 400], ['Medium', 500], ['Semibold', 600], ['Bold', 700]] as const

function Specimen() {
  return (
    <InkPanel>
      <div aria-hidden className="pointer-events-none absolute -right-32 -top-32 size-[520px] rounded-full opacity-50 blur-[70px]" style={{ background: 'radial-gradient(circle, #EA7C25 0%, transparent 60%)' }} />
      <div className="relative grid gap-10 p-6 sm:p-10 lg:grid-cols-[1fr_1.2fr]">
        <div className="flex flex-col justify-between gap-8">
          <div>
            <div className="text-[13px] font-medium text-white/55">Primary typeface</div>
            <div className="mt-2 text-[44px] font-semibold leading-none tracking-[-0.045em] sm:text-[56px]">Inter Tight</div>
            <p className="mt-4 max-w-[420px] text-[15px] leading-relaxed text-white/65">Inter, cut tighter. Neutral and very legible at 13 px, dense and confident at 104 px. One family for everything people read.</p>
          </div>
          <div className="text-[150px] font-semibold leading-[0.8] tracking-[-0.06em] sm:text-[210px]">A<span className="text-[#EA7C25]">a</span></div>
        </div>
        <div className="flex flex-col">
          {WEIGHTS.map(([n, w]) => (
            <div key={n} className="flex items-baseline justify-between gap-4 border-b border-white/10 py-3.5 first:pt-0">
              <span className="truncate text-[30px] leading-none tracking-[-0.04em] sm:text-[38px]" style={{ fontWeight: w }}>Drop it. It’s done.</span>
              <span className="shrink-0 text-right"><span className="block text-[13px] text-white/80">{n}</span><Spec tone="white">{w}</Spec></span>
            </div>
          ))}
          <p className="mt-6 break-words text-[20px] leading-[1.45] tracking-[-0.01em] text-white/60">ABCDEFGHIJKLMNOPQRSTUVWXYZ<br />abcdefghijklmnopqrstuvwxyz<br />0123456789 → · % & ( ) ? !</p>
          <div className="mt-6 rounded-[14px] bg-white/[.06] p-4 ring-1 ring-white/10">
            <div className="flex items-baseline justify-between"><span className="text-[13px] font-medium text-white/55">Data typeface</span><Spec tone="white">JetBrains Mono</Spec></div>
            <div className="af-mono mt-2 text-[15px] text-white">clip.gif · 4.1 MB · 15 fps · 480 × 270</div>
            <div className="af-mono mt-1 text-[13px] text-white/50">~/Desktop/clip.mov → clip.gif</div>
          </div>
        </div>
      </div>
    </InkPanel>
  )
}

function Scale() {
  const rows: { name: string; spec: string; use: string; size: string; style: CSSProperties; text: string; mono?: boolean }[] = [
    { name: 'Display XL', spec: '104 / 0.95 · −0.055em · 600', use: 'Hero, desktop', size: 'min(104px, 19vw)', style: { lineHeight: 0.95, letterSpacing: '-0.055em', fontWeight: 600 }, text: 'Mid‑drag.' },
    { name: 'Display L', spec: '84 / 0.95 · −0.055em · 600', use: 'Hero, tablet', size: 'min(84px, 17vw)', style: { lineHeight: 0.95, letterSpacing: '-0.055em', fontWeight: 600 }, text: 'Any format.' },
    { name: 'Display M', spec: '56 / 1.02 · −0.045em · 600', use: 'Section titles', size: 'min(56px, 11vw)', style: { lineHeight: 1.02, letterSpacing: '-0.045em', fontWeight: 600 }, text: 'Free where it runs.' },
    { name: 'Heading', spec: '28 / 1.1 · −0.04em · 600', use: 'Card titles', size: '28px', style: { lineHeight: 1.1, letterSpacing: '-0.04em', fontWeight: 600 }, text: 'Convert' },
    { name: 'Heading S', spec: '24 / 1.15 · −0.035em · 600', use: 'Feature titles', size: '24px', style: { lineHeight: 1.15, letterSpacing: '-0.035em', fontWeight: 600 }, text: 'Presets' },
    { name: 'Body L', spec: '17 / 1.6 · 0 · 400', use: 'Intros, hero copy', size: '17px', style: { lineHeight: 1.6 }, text: 'Drag a file, press Shift, and drop it on the format you want.' },
    { name: 'Body', spec: '15 / 1.4 · 0 · 400', use: 'Card copy, settings', size: '15px', style: { lineHeight: 1.4 }, text: 'Every result is saved as a new file next to the original.' },
    { name: 'Caption', spec: '13 / 1.4 · 0 · 500', use: 'Meta, labels, notes', size: '13px', style: { lineHeight: 1.4, fontWeight: 500, color: '#8C8884' }, text: 'macOS 13+ · Apple silicon · No account' },
    { name: 'Data', spec: 'JetBrains Mono 13 / 1.9', use: 'Sizes, paths, CLI', size: '13px', style: { lineHeight: 1.9 }, text: 'anyfmt convert clip.mov --to gif --json', mono: true },
  ]
  return (
    <div className="af-card overflow-hidden">
      {rows.map((r) => (
        <div key={r.name} className="grid gap-3 border-b border-[#E7E5E2] px-5 py-6 last:border-0 sm:px-8 md:grid-cols-[220px_1fr] md:items-center">
          <div>
            <div className="text-[14px] font-semibold">{r.name}</div>
            <Spec className="block">{r.spec}</Spec>
            <span className="text-[12.5px] text-[#8C8884]">{r.use}</span>
          </div>
          <div className={`min-w-0 text-balance ${r.mono ? 'af-mono' : ''}`} style={{ fontSize: r.size, ...r.style }}>{r.text}</div>
        </div>
      ))}
    </div>
  )
}

function TypeRules() {
  const pairs: { title: string; ok: ReactNode; bad: ReactNode; okNote: string; badNote: string }[] = [
    {
      title: 'Tracking', okNote: 'Track display sizes in, about −0.05em.', badNote: 'Space headlines out.',
      ok: <span className="text-[40px] font-semibold leading-none tracking-[-0.05em]">Drop it.</span>,
      bad: <span className="text-[40px] font-semibold leading-none tracking-[0.12em]">Drop it.</span>,
    },
    {
      title: 'Case', okNote: 'Sentence case, always. The name is always lowercase.', badNote: 'Set headlines in capitals or title case.',
      ok: <span className="text-[26px] font-semibold leading-tight tracking-[-0.04em]">Any file. Any format.</span>,
      bad: <span className="text-[24px] font-semibold uppercase leading-tight tracking-[0.02em]">Any File. Any Format.</span>,
    },
    {
      title: 'Emphasis', okNote: 'Two tones: ink, then a grey second line.', badNote: 'Mix colours, italics and weights in one line.',
      ok: <span className="text-[26px] font-semibold leading-[1.05] tracking-[-0.045em]">Three keys.<br /><span className="text-[#8C8884]">Everything a file can become.</span></span>,
      bad: <span className="text-[26px] leading-[1.05] tracking-[-0.02em]"><b className="text-[#EA7C25]">Three</b> <i>keys</i>. <span className="font-light text-[#2F6BE0]">Everything</span> <b>a file</b> can become.</span>,
    },
    {
      title: 'Orange text', okNote: 'Use orange for a big number or a short label.', badNote: 'Set paragraphs in orange. It fails contrast.',
      ok: <span className="flex items-baseline gap-2"><span className="text-[48px] font-semibold leading-none tracking-[-0.05em] text-[#EA7C25]">793</span><span className="text-[13px] text-[#8C8884]">routes, all tested</span></span>,
      bad: <span className="text-[14px] leading-snug text-[#EA7C25]">Every conversion, tool and action runs on your Mac and is free forever. Pro only adds things that need a server.</span>,
    },
  ]
  return (
    <div className="grid gap-4 md:grid-cols-2">
      {pairs.map((p) => (
        <div key={p.title} className="af-card flex flex-col p-2">
          <div className="px-3 pb-2 pt-2.5 text-[13px] font-semibold text-[#8C8884]">{p.title}</div>
          <div className="grid gap-2 sm:grid-cols-2">
            {[true, false].map((ok) => (
              <div key={String(ok)} className="flex flex-col gap-4 rounded-[14px] p-4" style={{ background: ok ? '#FAFAF9' : '#FFF8F5', boxShadow: `inset 0 0 0 1px ${ok ? '#E7E5E2' : '#F7D9CC'}` }}>
                <div className="flex min-h-[96px] items-center overflow-hidden">{ok ? p.ok : p.bad}</div>
                <Verdict ok={ok}>{ok ? p.okNote : p.badNote}</Verdict>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

export function Type() {
  return (
    <Section id="type" n="05" eyebrow="Type" title={<>Tight, plain,<br /><span className="text-[#8C8884]">easy to scan.</span></>}
      intro="Inter Tight for everything people read, JetBrains Mono for everything a machine produces: sizes, paths, frame rates and commands.">
      <Sub title="Specimen"><Specimen /></Sub>
      <Sub title="The scale" note="The sizes the landing page and the app use. Display sizes shrink to fit on phones.">
        <Scale />
      </Sub>
      <Sub title="Do and don’t"><TypeRules /></Sub>
    </Section>
  )
}

/* ---------- 06 Voice ---------- */

function Toast({ icon, title, body, actions }: { icon?: ReactNode; title: string; body: ReactNode; actions?: ReactNode; tone?: 'ok' | 'err' }) {
  return (
    <div className="flex w-full items-start gap-3 rounded-[16px] bg-white p-3 pr-4 shadow-[0_0_0_1px_rgba(17,17,17,.07),0_14px_30px_-16px_rgba(90,30,0,.4)]">
      {icon ?? <AppIcon size={34} />}
      <div className="min-w-0 flex-1 text-[13px] leading-snug">
        <div className="font-semibold text-[#111]">{title}</div>
        <div className="text-[#55524F]">{body}</div>
        {actions && <div className="mt-2.5 flex flex-wrap gap-2">{actions}</div>}
      </div>
    </div>
  )
}

const MiniBtn = ({ children, primary }: { children: ReactNode; primary?: boolean }) => (
  <span className={`af-btn ${primary ? 'af-btn-primary' : 'af-btn-light'} !h-7 !gap-1.5 !rounded-[8px] !px-2.5 !text-[12px]`}>{children}</span>
)

const ErrIcon = () => <span className="grid size-[34px] shrink-0 place-items-center rounded-[10px] bg-[#FDECE6] text-[14px] font-bold text-[#BB3F14] ring-1 ring-[#F7D9CC]">!</span>

function Principles() {
  const items = [
    { n: 'Plain', b: 'Say what happened in the words on screen: file names, formats, sizes. No metaphors.', ex: 'clip.gif is ready' },
    { n: 'Confident', b: 'No hedging, no “just”, no apologising for doing the job. If it worked, say so once.', ex: 'Saved next to clip.mov' },
    { n: 'Local-first', b: 'Lead with what stays on the Mac. Never imply an account, a sync or an upload.', ex: 'Converted on this Mac. Nothing was uploaded.' },
    { n: 'No hype', b: 'No exclamation marks, no “magic”, no “supercharge”. Numbers we can prove, or none.', ex: '793 routes, every one tested' },
  ]
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {items.map((it, i) => (
        <div key={it.n} className="af-card flex flex-col gap-5 p-6">
          <span className="af-mono text-[12px] text-[#EA7C25]">0{i + 1}</span>
          <div>
            <h4 className="text-[24px] font-semibold tracking-[-0.035em]">{it.n}</h4>
            <p className="mt-1.5 text-[14.5px] leading-relaxed text-[#55524F]">{it.b}</p>
          </div>
          <div className="af-well mt-auto px-3.5 py-3 text-[14px] font-medium">“{it.ex}”</div>
        </div>
      ))}
    </div>
  )
}

function CopyPairs() {
  const rows: [string, string, string][] = [
    ['A conversion finishes', 'clip.gif is ready. 4.1 MB, saved next to clip.mov.', 'Woohoo! Your awesome GIF has been magically created!'],
    ['Mentioning Pro', 'Pro adds share links and cloud conversions. Everything local stays free.', 'Unlock the full power of anyfmt. Upgrade to Pro today!'],
    ['Something fails', 'Couldn’t read clip.mkv. It may still be downloading. Try again when it’s done.', 'Oops! Something went wrong. Please try again later.'],
    ['Asking for access', 'Lets anyfmt ask Finder which files are selected. Nothing else is read.', 'anyfmt needs full access to your Mac to work properly.'],
    ['Nothing to show', 'Nothing on the shelf. Drop files here to hold them between drags.', 'Your shelf is looking a little lonely right now…'],
  ]
  return (
    <div className="af-card overflow-hidden">
      <div className="hidden grid-cols-[200px_1fr_1fr] gap-6 border-b border-[#E7E5E2] px-6 py-3 text-[12px] font-semibold text-[#8C8884] md:grid">
        <span>Moment</span><span>Say</span><span>Not</span>
      </div>
      {rows.map(([m, ok, bad]) => (
        <div key={m} className="grid gap-3 border-b border-[#E7E5E2] px-5 py-5 last:border-0 sm:px-6 md:grid-cols-[200px_1fr_1fr] md:gap-6">
          <div className="text-[14px] font-semibold">{m}</div>
          <Verdict ok>{ok}</Verdict>
          <Verdict ok={false}><span className="line-through decoration-[#BB3F14]/40">{bad}</span></Verdict>
        </div>
      ))}
    </div>
  )
}

function Group({ title, rule, children }: { title: string; rule: string; children: ReactNode }) {
  return (
    <div className="af-card flex flex-col p-2">
      <div className="px-3.5 pb-3 pt-3">
        <div className="text-[16px] font-semibold tracking-[-0.02em]">{title}</div>
        <div className="text-[13px] text-[#8C8884]">{rule}</div>
      </div>
      <div className="af-well flex flex-1 flex-col gap-2.5 p-3">{children}</div>
    </div>
  )
}

function Microcopy() {
  const perms: [ReactNode, string, string][] = [
    [<Eye size={16} />, 'Accessibility', 'Lets anyfmt catch Return in Finder before Finder starts renaming the file.'],
    [<Keyboard size={16} />, 'Input Monitoring', 'Lets anyfmt notice the Return key while Finder is in front. Every other key is passed through untouched.'],
    [<MousePointer2 size={16} />, 'Automation for Finder', 'Lets anyfmt ask Finder which files are selected. Nothing else is read.'],
  ]
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <div className="flex flex-col gap-4">
        <Group title="Toasts" rule="Result first, then size and place.">
          <Toast title="clip.gif is ready" body="4.1 MB · saved next to clip.mov" actions={<><MiniBtn>Show in Finder</MiniBtn><MiniBtn>Copy</MiniBtn></>} />
          <Toast title="12 photos converted to JPG" body="Saved next to the originals" />
          <Toast title="Path copied" body={<span className="af-mono text-[12px]">~/Desktop/clip.gif</span>} />
        </Group>
        <Group title="Empty states" rule="Say what goes here and how it gets there.">
          <div className="flex flex-col items-center gap-1 rounded-[12px] border border-dashed border-[#D9D6D2] bg-white/60 px-4 py-5 text-center">
            <div className="text-[14px] font-semibold">Nothing on the shelf</div>
            <div className="text-[13px] text-[#55524F]">Drop files here to hold them between drags.</div>
          </div>
          <div className="flex flex-col items-center gap-1 rounded-[12px] border border-dashed border-[#D9D6D2] bg-white/60 px-4 py-5 text-center">
            <div className="text-[14px] font-semibold">No conversions yet</div>
            <div className="text-[13px] text-[#55524F]">Drag any file and press Shift.</div>
          </div>
        </Group>
      </div>
      <div className="flex flex-col gap-4">
        <Group title="Errors" rule="What went wrong, then how to fix it.">
          <Toast tone="err" icon={<ErrIcon />} title="Couldn’t convert clip.mkv" body="It uses a video codec anyfmt can’t read yet. Try MP4 instead, or copy the details into a bug report."
            actions={<><MiniBtn>Copy details</MiniBtn><MiniBtn>Dismiss</MiniBtn></>} />
          <Toast tone="err" icon={<ErrIcon />} title="Not enough space for clip.gif" body="It needs about 420 MB. Free some space on Macintosh HD, then drop it again." />
          <Toast tone="err" icon={<ErrIcon />} title="Can’t save next to report.pdf" body="That folder is read-only. Results go to Downloads instead. Change it in Settings › General." />
        </Group>
        <Group title="Pro explainer" rule="Calm, once, never in the way.">
          <div className="rounded-[12px] bg-white p-4 shadow-[0_0_0_1px_#E7E5E2]">
            <div className="flex items-center gap-2"><span className="af-pill-status">Pro</span><span className="text-[14px] font-semibold">If you want it</span></div>
            <p className="mt-2 text-[13px] leading-relaxed text-[#55524F]">Pro adds the few things that need a server: share links, cloud conversions for huge files, transcription and preset sync. Everything on this Mac stays free. $4 a month.</p>
            <div className="mt-3 flex gap-2"><MiniBtn>Learn about Pro</MiniBtn><MiniBtn>Not now</MiniBtn></div>
          </div>
        </Group>
      </div>
      <div className="lg:col-span-2">
        <Group title="Permission asks" rule="One sentence each: what it lets anyfmt do, and what it never touches. Only asked for the optional Finder Return shortcut.">
          <div className="grid gap-2.5 md:grid-cols-3">
            {perms.map(([i, n, r]) => (
              <div key={n} className="flex gap-3 rounded-[12px] bg-white p-3.5 shadow-[0_0_0_1px_#E7E5E2]">
                <span className="grid size-8 shrink-0 place-items-center rounded-[9px] bg-[#FFF3E6] text-[#B4570F]">{i}</span>
                <div className="text-[13px] leading-snug"><div className="font-semibold">{n}</div><div className="text-[#55524F]">{r}</div></div>
              </div>
            ))}
          </div>
        </Group>
      </div>
    </div>
  )
}

export function Voice() {
  return (
    <Section id="voice" n="06" eyebrow="Voice" title={<>Say what happened.<br /><span className="text-[#8C8884]">Then get out of the way.</span></>}
      intro="anyfmt talks like a good tool: short, specific and calm. It names the file, the format and the size, and it never celebrates itself.">
      <Sub title="Four principles"><Principles /></Sub>
      <Sub title="Say this, not that"><CopyPairs /></Sub>
      <Sub title="Microcopy" note="The real strings, in the places they appear."><Microcopy /></Sub>
    </Section>
  )
}

/* ---------- 07 Components ---------- */

function Buttons() {
  const variants = [
    { cls: 'af-btn-primary', name: 'Primary', note: 'One per view', icon: <Download size={16} />, label: 'Download', bg: '' },
    { cls: 'af-btn-light', name: 'Light', note: 'Secondary on paper or orange', icon: <ArrowRight size={16} />, label: 'See how', bg: '' },
    { cls: 'af-btn-ghost', name: 'Ghost', note: 'Secondary on orange only', icon: <ShieldCheck size={16} />, label: 'Read the source', bg: 'stage' },
    { cls: 'af-btn-dark', name: 'Dark', note: 'On orange or for Pro', icon: <Lock size={16} />, label: 'Activate', bg: '' },
  ]
  const states = [['Rest', ''], ['Hover', 'afb-hover'], ['Pressed', 'afb-press']]
  return (
    <div className="af-card overflow-hidden">
      <div className="hidden grid-cols-[180px_repeat(3,1fr)] border-b border-[#E7E5E2] px-6 py-3 text-[12px] font-semibold text-[#8C8884] md:grid">
        <span>Variant</span>{states.map(([s]) => <span key={s}>{s}</span>)}
      </div>
      {variants.map((v) => (
        <div key={v.cls} className="grid items-center gap-4 border-b border-[#E7E5E2] px-5 py-5 last:border-0 sm:px-6 md:grid-cols-[180px_1fr]">
          <div><div className="text-[15px] font-semibold">{v.name}</div><div className="text-[12.5px] text-[#8C8884]">{v.note}</div></div>
          <div className={`grid grid-cols-1 gap-3 rounded-[14px] p-3 min-[440px]:grid-cols-3 ${v.bg === 'stage' ? 'af-stage relative overflow-hidden' : 'af-well'}`}>
            {states.map(([s, c]) => (
              <div key={s} className="relative flex flex-col items-start gap-1.5">
                <span className={`af-btn ${v.cls} ${c} !h-10 !px-4 !text-[14px]`}>{v.icon}{v.label}</span>
                <span className={`af-mono text-[10.5px] md:hidden ${v.bg === 'stage' ? 'text-white/70' : 'text-[#8C8884]'}`}>{s}</span>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

export const FPS = [{ f: 10, s: '2.8 MB' }, { f: 15, s: '4.1 MB' }, { f: 24, s: '6.3 MB' }, { f: 30, s: '7.9 MB' }]
export const WIDTHS = [{ w: 320, s: '≈ 1.9 MB' }, { w: 480, s: '≈ 4.1 MB' }, { w: 640, s: '≈ 7.2 MB' }, { w: 800, s: '≈ 11 MB' }]

export function SizeChip({ on, top, sub, onClick, dark }: { on?: boolean; top: string; sub: string; onClick?: () => void; dark?: boolean }) {
  return (
    <button type="button" onClick={onClick} aria-pressed={on}
      className={`af-chip !h-auto flex-col !items-start !gap-0 !rounded-[10px] !px-3 !py-1.5 ${on ? 'af-chip-on' : ''}`}
      style={dark && !on ? { background: 'linear-gradient(180deg,#2C2C2C,#242424)', color: '#fff', boxShadow: 'inset 0 1px 0 rgba(255,255,255,.08), 0 0 0 1px #3A3A3A' } : undefined}>
      <span className="text-[14px] font-semibold">{top}</span>
      <span className={`af-mono text-[10px] ${on ? 'text-white/85' : dark ? 'text-white/50' : 'text-[#8C8884]'}`}>{sub}</span>
    </button>
  )
}

function Chips() {
  const [fps, setFps] = useState(15)
  const [w, setW] = useState(480)
  return (
    <div className="af-card flex flex-col gap-6 p-6">
      <div>
        <div className="mb-3 text-[13px] font-semibold text-[#8C8884]">Chips</div>
        <div className="flex flex-wrap gap-2">
          <span className="af-chip">MP4</span><span className="af-chip af-chip-on">GIF</span><span className="af-chip">WEBM</span>
          <span className="af-chip"><Crop size={13} />1080 × 1080</span><span className="af-chip"><Volume2 size={13} />Keep audio</span>
        </div>
      </div>
      <div>
        <div className="mb-3 flex items-center justify-between text-[13px]"><span className="font-semibold text-[#8C8884]">Frame rate, with size</span><Spec>tap one</Spec></div>
        <div className="flex flex-wrap gap-2">{FPS.map((x) => <SizeChip key={x.f} on={fps === x.f} top={`${x.f} fps`} sub={x.s} onClick={() => setFps(x.f)} />)}</div>
      </div>
      <div>
        <div className="mb-3 text-[13px] font-semibold text-[#8C8884]">Width, with estimate</div>
        <div className="flex flex-wrap gap-2">{WIDTHS.map((x) => <SizeChip key={x.w} on={w === x.w} top={`${x.w} px`} sub={x.s} onClick={() => setW(x.w)} />)}</div>
      </div>
    </div>
  )
}

function Keys() {
  const [held, setHeld] = useState<string | null>(null)
  useEffect(() => {
    const d = (e: KeyboardEvent) => setHeld(e.key)
    const u = () => setHeld(null)
    window.addEventListener('keydown', d); window.addEventListener('keyup', u)
    return () => { window.removeEventListener('keydown', d); window.removeEventListener('keyup', u) }
  }, [])
  const keys: [string, string, string][] = [['⇧', 'shift', 'Shift'], ['⌘', 'command', 'Meta'], ['⌃', 'control', 'Control'], ['⌥', 'option', 'Alt']]
  return (
    <div className="af-card flex flex-col gap-5 p-6">
      <div className="flex items-center justify-between text-[13px]"><span className="font-semibold text-[#8C8884]">Keycaps</span><Spec>try your keyboard</Spec></div>
      <div className="flex flex-wrap gap-3">
        {keys.map(([k, l, code], i) => <Key key={k} k={k} label={l} on={held === code || (held === null && i === 0)} />)}
      </div>
      <p className="text-[13.5px] leading-snug text-[#55524F]">Rest: 3 px lip. Pressed: down 2 px, orange edge and symbol. Option locks a wedge mid-drag.</p>
      <div className="h-px bg-[#E7E5E2]" />
      <div className="flex items-center justify-between text-[13px]"><span className="font-semibold text-[#8C8884]">Status pills</span></div>
      <div className="flex flex-wrap items-center gap-2">
        <span className="af-pill-status">Pro</span>
        <span className="af-pill-status">Beta</span>
        <span className="af-pill-status !bg-[#E9F7EF] !text-[#1F7A45] !shadow-[inset_0_0_0_1px_#BFE6CF]"><Check size={11} strokeWidth={3} />Granted</span>
        <span className="af-pill-status !bg-[#F3F2F0] !text-[#55524F] !shadow-[inset_0_0_0_1px_#E7E5E2]"><WifiOff size={11} />Local</span>
      </div>
    </div>
  )
}

function CardsWells() {
  return (
    <div className="af-card flex flex-col gap-5 p-6">
      <div className="text-[13px] font-semibold text-[#8C8884]">Card and well</div>
      <div className="af-card p-2">
        <div className="flex items-center justify-between px-3 pb-3 pt-2"><span className="text-[16px] font-semibold tracking-[-0.02em]">GIF · frame rate</span><span className="af-mono text-[12px] text-[#8C8884]">clip.mov</span></div>
        <div className="af-well flex items-center gap-3 p-3">
          <span className="h-12 w-16 shrink-0 rounded-[8px]" style={{ background: 'linear-gradient(160deg,#FFC08A,#EA7C25 55%,#8E2E0B)' }} />
          <div className="text-[13px] leading-snug"><div className="font-semibold">clip.gif</div><div className="af-mono text-[11px] text-[#8C8884]">15 fps · 480 px · 4.1 MB</div></div>
          <Copy size={15} className="ml-auto text-[#8C8884]" />
        </div>
      </div>
      <ul className="flex flex-col gap-2 text-[13.5px] leading-snug text-[#55524F]">
        <li><b className="font-semibold text-[#111]">Card:</b> white, 20 px radius, one hairline and a long, low shadow.</li>
        <li><b className="font-semibold text-[#111]">Well:</b> pressed into the card, 14 px radius. Content lives in wells.</li>
        <li>Nest card → well once. Never a card inside a well.</li>
      </ul>
    </div>
  )
}

function Wheels() {
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      {WHEELS.map((x, i) => (
        <div key={x.wheel} className="af-card flex flex-col p-2">
          <div className="flex items-center justify-between px-3 pb-3 pt-2">
            <div><div className="text-[16px] font-semibold tracking-[-0.02em]">{x.wheel}</div><div className="text-[12.5px] text-[#8C8884]">Hold {x.name}</div></div>
            <span className="af-key !h-11 !w-11 !rounded-[10px] !p-0 !items-center !justify-center !text-[17px]">{x.key}</span>
          </div>
          <div className="af-well px-2 py-5">
            <Fit w={380} h={380}>
              <AnyWheel wedges={x.wedges} size={380} active={i === 0 ? 0 : i === 1 ? 1 : 1} hub={<span className="text-[13px] font-semibold">{x.hub}</span>} />
            </Fit>
          </div>
          <div className="px-3 pb-2 pt-3 text-[13px] text-[#55524F]">{x.blurb}</div>
        </div>
      ))}
    </div>
  )
}

export function Components() {
  return (
    <Section id="components" n="07" eyebrow="Components" title={<>Soft white parts,<br /><span className="text-[#8C8884]">lit from the top.</span></>}
      intro="Every control is a physical object: lit from above, with a highlight on its top edge and a shadow tinted by the orange light. Hover lifts a little, pressing pushes it into the page.">
      <Sub title="Buttons" note="Four variants, three states. Pressed moves down 1 px and loses its lift."><Buttons /></Sub>
      <Sub title="Chips, keycaps, pills, cards">
        <div className="grid gap-4 lg:grid-cols-3"><Chips /><Keys /><CardsWells /></div>
      </Sub>
      <Sub title="The wheel" note="All three sets at real size, 380 px. Shift converts, Command opens tools, Control runs actions.">
        <Wheels />
      </Sub>
    </Section>
  )
}

