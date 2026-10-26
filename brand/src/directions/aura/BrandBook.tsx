import { motion } from 'motion/react'
import { ArrowUpRight, Check, RotateCcw, X } from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { cn } from '../../shared/cn'
import { isShot } from '../../shared/kit'
import { AppBoard, Desktop, ErrorToast, ProgressHUD } from './AppSurfaces'
import { AuraWheel } from './AuraWheel'
import { DoneToast } from './Demo'
import { Agents, Hero, HowItWorks, In, Pricing } from './Landing'
import { OnboardingBoard } from './Onboarding'
import { PALETTE } from './tokens'
import {
  AppIcon, Eyebrow, Fit, Glow, Grain, K, Lockup, Mark, MenuGlyph, Scribble, Sticky, Wordmark, convertSegs,
} from './ui'
import { meta } from './meta'
import './aura.css'

const SECTIONS = [
  { id: 'cover', label: 'Aura' },
  { id: 'logo', label: 'Logo' },
  { id: 'colour', label: 'Colour' },
  { id: 'type', label: 'Type' },
  { id: 'voice', label: 'Voice' },
  { id: 'motion', label: 'Motion' },
  { id: 'landing', label: 'Landing' },
  { id: 'onboarding', label: 'Onboarding' },
  { id: 'app', label: 'App' },
] as const

const part = typeof location !== 'undefined' ? new URLSearchParams(location.search).get('part') : null

function Section({ id, n, title, intro, children, className }: { id: string; n: string; title: ReactNode; intro?: ReactNode; children: ReactNode; className?: string }) {
  if (part && part !== id) return null
  return (
    <section id={`aura-${id}`} className={cn('relative scroll-mt-24 px-5 py-20 md:px-10 md:py-28', className)}>
      <div className="mx-auto max-w-[1240px]">
        <In className="mb-12 grid grid-cols-1 gap-6 border-t border-[#1E1B18]/10 pt-8 md:mb-16 md:grid-cols-[200px_1fr]">
          <div className="aura-serif text-[15px] italic text-[#B04E1B]">{n}</div>
          <div>
            <h2 className="aura-display text-[clamp(44px,6.6vw,92px)] text-[#1E1B18]">{title}</h2>
            {intro && <p className="mt-5 max-w-[40rem] text-[17px] leading-[1.6] text-[#5B524A]">{intro}</p>}
          </div>
        </In>
        {children}
      </div>
    </section>
  )
}

function Tile({ children, className, label, dark, style }: { children: ReactNode; className?: string; label?: ReactNode; dark?: boolean; style?: React.CSSProperties }) {
  return (
    <div className={cn('relative overflow-hidden rounded-[28px]', dark ? 'bg-[#1E1B18] text-[#FBF7F0]' : 'aura-card', className)} style={style}>
      {children}
      {label && <div className={cn('absolute bottom-4 left-5 text-[12px] font-semibold', dark ? 'text-[#FBF7F0]/60' : 'text-[#8A7F74]')}>{label}</div>}
    </div>
  )
}

/* ------------------------------------------------------------------ nav */

function BookNav() {
  const [active, setActive] = useState('cover')
  useEffect(() => {
    if (isShot) return
    const io = new IntersectionObserver((es) => {
      es.forEach((e) => { if (e.isIntersecting) setActive(e.target.id.replace('aura-', '')) })
    }, { rootMargin: '-45% 0px -50% 0px' })
    SECTIONS.forEach((s) => { const el = document.getElementById(`aura-${s.id}`); if (el) io.observe(el) })
    return () => io.disconnect()
  }, [])
  return (
    <div className="sticky top-3 z-50 px-3 md:top-4">
      <nav className="aura-frost no-scrollbar mx-auto flex max-w-max items-center gap-0.5 overflow-x-auto rounded-full p-1.5" aria-label="Brand book sections">
        <span className="shrink-0 px-2.5"><Mark size={22} /></span>
        {SECTIONS.map((s) => (
          <a key={s.id} href={`#aura-${s.id}`}
            onClick={(e) => { e.preventDefault(); document.getElementById(`aura-${s.id}`)?.scrollIntoView({ behavior: 'smooth' }) }}
            className={cn('relative shrink-0 rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors', active === s.id ? 'text-[#1E1B18]' : 'text-[#5B524A] hover:text-[#1E1B18]')}>
            {active === s.id && <motion.span layoutId="aura-nav" className="absolute inset-0 rounded-full bg-white shadow-[0_0_0_.5px_rgba(90,60,30,.2),0_4px_12px_-4px_rgba(150,80,30,.35),0_0_16px_rgba(255,178,122,.45)]" transition={{ type: 'spring', stiffness: 400, damping: 32 }} />}
            <span className="relative">{s.label}</span>
          </a>
        ))}
      </nav>
    </div>
  )
}

/* ------------------------------------------------------------------ 1 cover */

function Cover() {
  if (part && part !== 'cover') return null
  return (
    <section id="aura-cover" className="relative overflow-hidden px-5 pb-24 pt-16 md:px-10 md:pb-32 md:pt-24">
      <Glow className="right-[-15%] top-[-5%] h-[900px] w-[900px]" intensity={1} />
      <div className="relative mx-auto max-w-[1240px]">
        <div className="flex flex-wrap items-center justify-between gap-4 text-[13px] text-[#5B524A]">
          <Lockup size={26} />
          <span>Brand direction 02 of 05 · {meta.lineage}</span>
        </div>
        <div className="mt-20 grid grid-cols-1 items-end gap-10 lg:mt-28 lg:grid-cols-[1.25fr_1fr]">
          <div>
            <Eyebrow>Direction</Eyebrow>
            <h1 className="aura-display mt-6 text-[clamp(120px,22vw,320px)] leading-[.82] text-[#1E1B18]" style={{ letterSpacing: '-0.055em' }}>
              Au<em>ra</em>
            </h1>
            <p className="aura-serif mt-8 max-w-[22ch] text-[clamp(26px,3vw,40px)] leading-[1.12] text-[#1E1B18]" style={{ fontWeight: 360 }}>
              Warm paper, soft light. The <em className="aura-em">calm, human</em> take on a power tool.
            </p>
            <p className="mt-6 max-w-[36rem] text-[17px] leading-[1.6] text-[#5B524A]">
              Halo does a lot of heavy lifting: 793 routes, 26 tools, a CLI. Aura’s job is to make all of that feel like a sunny desk.
              Light pools where your attention is. Surfaces are paper and frosted glass. The voice talks to you like a friend who happens to know codecs.
            </p>
          </div>
          <div className="relative grid place-items-center">
            <Fit width={420} height={420} className="max-w-[420px]">
              <div className="grid h-full place-items-center">
                <AuraWheel segments={convertSegs} size={380} hoverIndex={0} interactive={false}
                  hubLabel={<span className="aura-serif text-[14px] italic text-[#5B524A]">Convert</span>}
                  hubSub={<span className="mt-0.5 text-[11px] font-semibold">clip.mov</span>} />
              </div>
            </Fit>
            <Sticky className="absolute -bottom-4 left-0 md:left-[-20px]" rotate={-5}>The halo of light follows your aim.</Sticky>
          </div>
        </div>
        <div className="mt-20 grid grid-cols-1 gap-px overflow-hidden rounded-[24px] bg-[#1E1B18]/10 sm:grid-cols-2 lg:grid-cols-4">
          {[
            ['Feels like', 'A sunlit desk. Paper, glass, warm light.'],
            ['Display', 'Fraunces, soft and a little wonky'],
            ['Text', 'Inter, plain and friendly'],
            ['Signature', 'An apricot to periwinkle glow that breathes'],
          ].map(([a, b]) => (
            <div key={a} className="bg-[#FBF7F0] p-6">
              <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">{a}</div>
              <div className="aura-serif mt-2 text-[20px] leading-[1.2] text-[#1E1B18]">{b}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ------------------------------------------------------------------ 2 logo */

function LogoSection() {
  return (
    <Section id="logo" n="01 — Logo" title={<>A ring of light, with <em>room</em> for your file.</>}
      intro="The mark is a halo with an opening at half past one. The dot in the gap is the file you’re dragging, the moment before it lands. Read it as a sunrise, a wheel, or a gesture; all three are right.">
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[1.3fr_1fr]">
        <Tile className="grid min-h-[480px] place-items-center bg-[#FBF7F0]" label="Primary mark · glow">
          <Glow className="inset-[12%]" intensity={0.65} />
          <div className="relative">
            <Mark size={260} />
            {/* construction */}
            <svg className="pointer-events-none absolute inset-0" width="260" height="260" viewBox="0 0 64 64" aria-hidden>
              <circle cx="32" cy="32" r="25" fill="none" stroke="#4E63C9" strokeWidth=".15" strokeDasharray=".8 .8" />
              <circle cx="32" cy="32" r="29.25" fill="none" stroke="#4E63C9" strokeWidth=".1" strokeDasharray=".6 .8" opacity=".6" />
              <line x1="32" y1="32" x2="49.68" y2="14.32" stroke="#4E63C9" strokeWidth=".15" />
              <line x1="32" y1="32" x2="32" y2="2" stroke="#4E63C9" strokeWidth=".1" strokeDasharray=".6 .6" opacity=".6" />
              <circle cx="32" cy="32" r=".7" fill="#4E63C9" />
            </svg>
            <span className="absolute -right-24 top-6 hidden font-mono sm:block text-[11px] text-[#4E63C9]">45° · the file</span>
            <span className="absolute -left-28 bottom-10 hidden font-mono sm:block text-[11px] text-[#4E63C9]">stroke = r / 3</span>
          </div>
        </Tile>
        <div className="grid gap-5">
          <Tile className="grid min-h-[230px] place-items-center" label="Wordmark · Fraunces 520, SOFT 100, WONK on">
            <Wordmark style={{ fontSize: 132, lineHeight: 1, color: '#1E1B18' }} />
          </Tile>
          <Tile className="grid min-h-[230px] place-items-center gap-6 py-10" label="Lockups">
            <Lockup size={52} />
            <div className="flex flex-col items-center gap-1"><Mark size={56} /><Wordmark style={{ fontSize: 40, lineHeight: 1, color: '#1E1B18' }} /></div>
          </Tile>
        </div>
      </div>

      <div className="mt-5 grid grid-cols-1 gap-5 md:grid-cols-2 lg:grid-cols-4">
        <Tile className="grid min-h-[260px] place-items-center" label="Clear space = one dot (x)">
          <div className="relative p-[22px]" style={{ outline: '1px dashed rgba(78,99,201,.6)' }}>
            <div className="absolute inset-[22px] outline outline-1 outline-[#4E63C9]/30" />
            <Lockup size={44} />
            <span className="absolute left-1 top-1 font-mono text-[10px] text-[#4E63C9]">x</span>
            <span className="absolute bottom-1 right-1 font-mono text-[10px] text-[#4E63C9]">x</span>
          </div>
        </Tile>
        <Tile className="grid min-h-[260px] place-items-center" label="Minimum sizes">
          <div className="flex items-end gap-8">
            {[16, 24, 32].map((s) => <div key={s} className="flex flex-col items-center gap-2"><Mark size={s} /><span className="font-mono text-[10px] text-[#8A7F74]">{s}px</span></div>)}
            <div className="flex flex-col items-center gap-2"><Lockup size={18} /><span className="font-mono text-[10px] text-[#8A7F74]">lockup 72px</span></div>
          </div>
        </Tile>
        <Tile dark className="grid min-h-[260px] place-items-center" label="On ink">
          <div className="absolute inset-[20%] rounded-full bg-[#FFB27A]/25 blur-3xl" />
          <div className="relative"><Lockup size={44} tone="paper" /></div>
        </Tile>
        <Tile className="grid min-h-[260px] place-items-center" style={{ background: 'linear-gradient(140deg,#FFC79C,#FFB27A 45%,#9DB4FF)' }} label={<span className="text-[#1E1B18]/60">On the glow</span>}>
          <Lockup size={44} tone="ink" />
        </Tile>
      </div>

      {/* App icon + menu bar */}
      <div className="mt-5 grid grid-cols-1 gap-5 lg:grid-cols-[1.4fr_1fr]">
        <Tile className="relative min-h-[420px] p-8" label="App icon · 1024 master, continuous-corner squircle">
          <Glow className="left-[5%] top-[5%] h-[90%] w-[60%]" intensity={0.5} />
          <div className="relative flex h-full flex-wrap items-center justify-center gap-8 pb-8">
            <AppIcon size={240} />
            <div className="flex flex-col items-center gap-6">
              <div className="flex items-end gap-5">
                <AppIcon size={128} /><AppIcon size={64} /><AppIcon size={32} /><AppIcon size={16} />
              </div>
              <div className="flex items-center gap-5 rounded-[22px] bg-[#1E1B18] px-6 py-4">
                <AppIcon size={96} variant="night" />
                <span className="max-w-[10rem] text-[12.5px] leading-[1.45] text-[#FBF7F0]/70">Night variant for dark Docks and press shots.</span>
              </div>
            </div>
          </div>
        </Tile>
        <Tile className="flex min-h-[420px] flex-col justify-center gap-6 p-8" label="Menu-bar glyph · template image, 16 / 18 pt">
          {[{ bg: 'rgba(255,251,245,.9)', fg: '#1E1B18', hi: 'rgba(30,27,24,.12)' }, { bg: '#2A2622', fg: '#FBF7F0', hi: 'rgba(255,255,255,.18)' }].map((b, i) => (
            <div key={i} className="flex h-[30px] items-center justify-end gap-4 rounded-[10px] px-4 text-[13px]" style={{ background: b.bg, color: b.fg, boxShadow: '0 0 0 .5px rgba(90,60,30,.15)' }}>
              <span className="opacity-60">Wi-Fi</span>
              <span className="grid h-[22px] w-[30px] place-items-center rounded-[6px]" style={{ background: b.hi }}><MenuGlyph size={16} /></span>
              <span className="tabular-nums">9:41</span>
            </div>
          ))}
          <div className="flex items-end justify-center gap-10 pt-4">
            {[16, 18, 36, 72].map((s) => <div key={s} className="flex flex-col items-center gap-2 text-[#1E1B18]"><MenuGlyph size={s} /><span className="font-mono text-[10px] text-[#8A7F74]">{s}</span></div>)}
          </div>
        </Tile>
      </div>

      {/* do / don't */}
      <div className="mt-5 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <DoDont ok label="Let it glow on paper.">
          <div className="relative grid place-items-center"><div className="absolute size-24 rounded-full bg-[#FFB27A]/40 blur-2xl" /><Mark size={80} /></div>
        </DoDont>
        <DoDont label="Don’t close the gap. The file needs its spot.">
          <svg width="80" height="80" viewBox="0 0 64 64"><circle cx="32" cy="32" r="25" fill="none" stroke="#FFB27A" strokeWidth="8.5" /></svg>
        </DoDont>
        <DoDont label="Don’t stretch or skew it.">
          <div style={{ transform: 'scaleX(1.6)' }}><Mark size={70} /></div>
        </DoDont>
        <DoDont label="Don’t recolour it to a rainbow or neon.">
          <svg width="80" height="80" viewBox="0 0 64 64"><defs><linearGradient id="bad" x1="0" x2="1"><stop offset="0" stopColor="#00F" /><stop offset=".5" stopColor="#0F0" /><stop offset="1" stopColor="#F0F" /></linearGradient></defs>
            <path d="M37.2 7.55 A25 25 0 1 0 56.45 26.8" fill="none" stroke="url(#bad)" strokeWidth="8.5" strokeLinecap="round" /><circle cx="49.68" cy="14.32" r="5.6" fill="#F0F" /></svg>
        </DoDont>
      </div>
    </Section>
  )
}

function DoDont({ ok, label, children }: { ok?: boolean; label: string; children: ReactNode }) {
  return (
    <div className="aura-card overflow-hidden">
      <div className="grid h-[180px] place-items-center bg-[#FBF7F0]">{children}</div>
      <div className="flex items-start gap-2.5 p-4 text-[14px] leading-[1.4] text-[#1E1B18]">
        <span className={cn('mt-0.5 grid size-5 shrink-0 place-items-center rounded-full', ok ? 'bg-[#DDF0DF] text-[#2F7A3E]' : 'bg-[#FBE0D8] text-[#A4361A]')}>
          {ok ? <Check size={12} strokeWidth={3} /> : <X size={12} strokeWidth={3} />}
        </span>{label}
      </div>
    </div>
  )
}

/* ------------------------------------------------------------------ 3 colour */

const TOKENS = [
  ['--aura-canvas', '#FBF7F0', 'Page and window backgrounds'],
  ['--aura-surface', '#FFFFFF', 'Cards, the wheel hub'],
  ['--aura-surface-2', '#F1EADF', 'Wells, code, quiet chips'],
  ['--aura-frost', 'rgba(255,253,250,.82) + blur 28', 'Wheel disc, HUD, menus, shelf'],
  ['--aura-text', '#1E1B18', 'Headlines, primary buttons'],
  ['--aura-text-2', '#5B524A', 'Body and secondary text'],
  ['--aura-text-3', '#8A7F74', 'Labels ≥ 12px semibold, meta'],
  ['--aura-accent-text', '#B04E1B', 'Links, eyebrow labels'],
  ['--aura-glow-warm', '#FFB27A', 'Hovered wedge, selected chip'],
  ['--aura-glow-cool', '#9DB4FF', 'Far side of the halo, progress start'],
  ['--aura-focus', '#4E63C9', 'Keyboard focus ring, 2px'],
  ['--aura-note', '#FFE8A3', 'Sticky-note asides'],
] as const

function ColourSection() {
  return (
    <Section id="colour" n="02 — Colour" title={<>Mostly paper. A little <em>light</em>.</>}
      intro="Aura is 90% Paper, Linen and Ink. Apricot and Periwinkle are never paint, only light: glows, the hovered wedge, the selected chip. When a warm or cool colour has to carry text, use its readable sibling, Ember or Dusk.">
      <div className="relative mb-5 overflow-hidden rounded-[32px] p-8 md:p-12" style={{ background: '#FBF7F0', boxShadow: '0 0 0 1px rgba(30,27,24,.06) inset' }}>
        <Glow className="left-[10%] top-[-40%] h-[180%] w-[80%]" intensity={1} />
        <div className="relative flex min-h-[200px] flex-col justify-between gap-8 md:flex-row md:items-end">
          <div>
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#5B524A]">The glow</div>
            <div className="aura-display mt-3 text-[clamp(40px,5vw,64px)]">Apricot <em>to</em> Periwinkle</div>
          </div>
          <code className="max-w-[420px] rounded-[16px] bg-white/70 p-4 font-mono text-[11.5px] leading-[1.6] text-[#1E1B18] backdrop-blur">
            radial(#FFB27A 0 → 45%, fade 75%) + radial(#9DB4FF, offset 30% 25%) + radial(#FFE2AA), blur 30px, breathe 7s
          </code>
        </div>
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {PALETTE.map((p) => {
          const glow = p.name === 'Apricot' || p.name === 'Periwinkle'
          const dark = p.name === 'Ink'
          return (
            <div key={p.name} className="aura-card overflow-hidden">
              <div className="relative h-[150px]" style={{ background: glow ? `radial-gradient(circle at 50% 120%, ${p.hex}, ${p.hex}80 45%, #FBF7F0 85%)` : p.hex, boxShadow: p.name === 'Paper' ? '0 -1px 0 rgba(30,27,24,.06) inset' : undefined }}>
                <span className={cn('absolute left-5 top-5 font-mono text-[12px]', dark || ['Ember', 'Dusk', 'Ink 2'].includes(p.name) ? 'text-white/85' : 'text-[#1E1B18]/70')}>{p.hex}</span>
                {!glow && <span className="aura-display absolute bottom-3 right-5 text-[44px]" style={{ color: dark ? '#FBF7F0' : p.name === 'Ember' || p.name === 'Dusk' || p.name === 'Ink 2' ? '#FFFFFF' : '#1E1B18' }}>Aa</span>}
              </div>
              <div className="p-5">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="aura-serif text-[22px] text-[#1E1B18]">{p.name}</span>
                  <span className="font-mono text-[11px] text-[#8A7F74]">{p.token}</span>
                </div>
                <p className="mt-1.5 text-[14px] leading-[1.5] text-[#5B524A]">{p.role}</p>
                <p className="mt-3 inline-block rounded-full bg-[#F1EADF] px-2.5 py-1 text-[11.5px] font-semibold text-[#1E1B18]">{p.note}</p>
              </div>
            </div>
          )
        })}
      </div>

      <div className="aura-card mt-5 overflow-hidden">
        <div className="border-b border-[#1E1B18]/[.07] px-6 py-4 text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">Semantic tokens</div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[620px] text-left text-[14px]">
            <thead><tr className="text-[12px] text-[#8A7F74]"><th className="px-6 py-3 font-semibold">Token</th><th className="px-6 py-3 font-semibold">Value</th><th className="px-6 py-3 font-semibold">Use</th></tr></thead>
            <tbody>
              {TOKENS.map(([t, v, u]) => (
                <tr key={t} className="border-t border-[#1E1B18]/[.06]">
                  <td className="px-6 py-3 font-mono text-[12.5px] text-[#1E1B18]">{t}</td>
                  <td className="px-6 py-3"><span className="flex items-center gap-2.5 font-mono text-[12.5px] text-[#5B524A]">
                    <span className="size-4 shrink-0 rounded-full shadow-[0_0_0_1px_rgba(30,27,24,.12)]" style={{ background: v.startsWith('#') ? v : 'linear-gradient(180deg,#FFFDFA,#F6EEE3)' }} />{v}</span></td>
                  <td className="px-6 py-3 text-[#5B524A]">{u}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </Section>
  )
}

/* ------------------------------------------------------------------ 4 type */

function TypeSection() {
  const [soft, setSoft] = useState(100)
  const [wonk, setWonk] = useState(1)
  const [opsz, setOpsz] = useState(144)
  const [wght, setWght] = useState(380)
  const scale = [
    { n: 'Display', s: 'Fraunces 380 · 148/0.95 · −3.5%', el: <span className="aura-display text-[clamp(56px,8vw,112px)]">Hello, <em>file</em>.</span> },
    { n: 'H1', s: 'Fraunces 380 · 84/0.95', el: <span className="aura-display text-[clamp(40px,5vw,72px)]">Three keys, three wheels</span> },
    { n: 'H3', s: 'Fraunces opsz 36 · 30/1', el: <span className="aura-serif text-[30px] leading-none" style={{ fontWeight: 430 }}>Convert, quietly</span> },
    { n: 'Body', s: 'Inter 400 · 17/1.6', el: <span className="text-[17px] leading-[1.6] text-[#5B524A]">Drag a file in Finder. Press a key. A wheel of everything that file can become opens around your pointer.</span> },
    { n: 'UI', s: 'Inter 500–600 · 13/1.3', el: <span className="text-[13px] font-semibold">clip.gif is ready · 2.4 MB</span> },
    { n: 'Label', s: 'Inter 600 · 12 caps · +14%', el: <span className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">Frame rate</span> },
    { n: 'Hand', s: 'Fraunces italic opsz 9 · WONK', el: <span className="aura-hand text-[22px] text-[#B04E1B]">psst, try <K>⌃</K> for AirDrop</span> },
    { n: 'Mono', s: 'JetBrains Mono · 13/1.8', el: <span className="font-mono text-[13px]">halo convert clip.mov --to gif --json</span> },
  ]
  return (
    <Section id="type" n="03 — Type" title={<>A serif that <em>smiles</em>.</>}
      intro="Fraunces carries the warmth: high optical size, SOFT all the way up, and WONK switched on for italics only, so the leaning letters land on the words that matter. Inter does the work everywhere else, in the app especially.">
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-[1.4fr_1fr]">
        <Tile className="relative min-h-[460px] p-8 md:p-10">
          <Glow className="right-[-10%] top-[-10%] h-[80%] w-[60%]" intensity={0.5} />
          <div className="relative">
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">Fraunces · live axes</div>
            <div className="mb-10 mt-4 text-[clamp(110px,16vw,220px)] leading-[.9] text-[#1E1B18]"
                 style={{ fontFamily: "'Aura Fraunces', serif", fontWeight: wght, fontVariationSettings: `"opsz" ${opsz}, "SOFT" ${soft}, "WONK" ${wonk}`, letterSpacing: '-0.04em' }}>
              Aa<span style={{ fontStyle: 'italic' }}>gy</span>
            </div>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <Slider label="SOFT" v={soft} min={0} max={100} on={setSoft} />
              <Slider label="opsz" v={opsz} min={9} max={144} on={setOpsz} />
              <Slider label="wght" v={wght} min={200} max={800} on={setWght} />
              <label className="flex items-center justify-between gap-3 rounded-[14px] bg-[#F1EADF] px-4 py-3 text-[13px] font-semibold">
                <span className="font-mono">WONK</span>
                <button type="button" onClick={() => setWonk(wonk ? 0 : 1)} aria-pressed={!!wonk}
                  className={cn('relative h-[22px] w-[38px] rounded-full transition-colors', wonk ? 'bg-[#FFA868]' : 'bg-[#D8CCBB]')}>
                  <span className={cn('absolute top-[2px] size-[18px] rounded-full bg-white shadow transition-all', wonk ? 'left-[18px]' : 'left-[2px]')} />
                </button>
              </label>
            </div>
          </div>
        </Tile>
        <Tile className="flex min-h-[460px] flex-col justify-between p-8 md:p-10">
          <div>
            <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">Inter · text and UI</div>
            <div className="mt-4 text-[96px] font-medium leading-none tracking-[-0.04em] text-[#1E1B18]">Aa</div>
            <p className="mt-6 text-[15px] leading-[1.6] text-[#5B524A]">ABCDEFGHIJKLMNOPQRSTUVWXYZ<br />abcdefghijklmnopqrstuvwxyz<br />0123456789 → ⇧ ⌘ ⌃ ↵ · 43 ms</p>
          </div>
          <div className="space-y-2.5 border-t border-[#1E1B18]/[.07] pt-5 text-[14px] leading-[1.5] text-[#1E1B18]">
            <p><b className="font-semibold">Pair:</b> serif for feelings, sans for facts. Never Fraunces below 20px except the hand style.</p>
            <p><b className="font-semibold">Italic:</b> one emphasised idea per headline, in WONK italic. Not two.</p>
            <p><b className="font-semibold">In the app:</b> Inter only, plus Fraunces italic for the wheel’s hub name.</p>
          </div>
        </Tile>
      </div>
      <div className="aura-card mt-5 divide-y divide-[#1E1B18]/[.07]">
        {scale.map((r) => (
          <div key={r.n} className="grid grid-cols-1 items-center gap-2 px-6 py-5 md:grid-cols-[120px_240px_1fr] md:px-8">
            <span className="text-[13px] font-semibold text-[#1E1B18]">{r.n}</span>
            <span className="font-mono text-[11.5px] text-[#8A7F74]">{r.s}</span>
            <span className="min-w-0 text-[#1E1B18]">{r.el}</span>
          </div>
        ))}
      </div>
    </Section>
  )
}

function Slider({ label, v, min, max, on }: { label: string; v: number; min: number; max: number; on: (n: number) => void }) {
  return (
    <label className="flex items-center gap-3 rounded-[14px] bg-[#F1EADF] px-4 py-3 text-[13px] font-semibold">
      <span className="w-12 font-mono">{label}</span>
      <input type="range" min={min} max={max} value={v} onChange={(e) => on(+e.target.value)} className="h-1 flex-1 accent-[#FF9858]" aria-label={label} />
      <span className="w-9 text-right font-mono text-[12px] tabular-nums text-[#5B524A]">{v}</span>
    </label>
  )
}

/* ------------------------------------------------------------------ 5 voice */

const VOICE = [
  { t: 'Talk to one person.', b: 'Second person, present tense. You drag, you drop. Halo is “it”, and “we” only when we, the people who make it, owe you something.', do: 'Drop it on GIF and you’re done.', dont: 'Users can initiate a conversion workflow.' },
  { t: 'Plain beats clever.', b: 'Say the format, the size, the place. Wit is a garnish, at most once per screen.', do: 'clip.gif is ready. 2.4 MB, next to the original.', dont: 'Boom! Your media has been transformed ✨' },
  { t: 'Reassure before you ask.', b: 'Tell people why, then what. Especially for permissions and money.', do: 'Accessibility lets Halo notice ⇧ while you drag. Nothing leaves your Mac.', dont: 'Halo requires Accessibility access to function.' },
  { t: 'Own the mistake, offer the fix.', b: 'Errors say what happened, that nothing broke, and what to do next. No codes in the headline.', do: 'clip.mov moved before we finished. Drop it again and we’ll pick up.', dont: 'Error -43: source unavailable.' },
  { t: 'Quietly confident.', b: 'Real numbers, no superlatives. Let 43 ms do the bragging.', do: 'Key press to wheel in 43 ms.', dont: 'The fastest, most powerful converter ever made.' },
]

function VoiceSection() {
  return (
    <Section id="voice" n="04 — Voice" title={<>Warm, plain, a <em>little</em> witty.</>}
      intro="Aura sounds like the friend who helps you move house and also knows which van to rent. Calm about the hard parts, honest about the limits, never in a hurry.">
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {VOICE.map((v, i) => (
          <In key={v.t} delay={i * 0.04} className={cn(i === 0 && 'lg:col-span-2')}>
            <div className={cn('aura-card grid h-full gap-6 p-7 md:p-8', i === 0 && 'md:grid-cols-[1fr_1.2fr]')}>
              <div>
                <span className="aura-serif text-[14px] italic text-[#B04E1B]">0{i + 1}</span>
                <h3 className="aura-serif mt-2 text-[30px] leading-[1.05] text-[#1E1B18]" style={{ fontWeight: 420 }}>{v.t}</h3>
                <p className="mt-3 text-[15px] leading-[1.55] text-[#5B524A]">{v.b}</p>
              </div>
              <div className="grid content-start gap-2.5">
                <div className="flex items-start gap-3 rounded-[16px] bg-[#EEF6EE] px-4 py-3 text-[14.5px] text-[#1E1B18]"><Check size={16} className="mt-0.5 shrink-0 text-[#2F7A3E]" strokeWidth={2.6} />{v.do}</div>
                <div className="flex items-start gap-3 rounded-[16px] bg-[#FBEDE8] px-4 py-3 text-[14.5px] text-[#5B524A] line-through decoration-[#A4361A]/40"><X size={16} className="mt-0.5 shrink-0 text-[#A4361A]" strokeWidth={2.6} />{v.dont}</div>
              </div>
            </div>
          </In>
        ))}
      </div>

      <div className="mt-5 grid grid-cols-1 gap-5 lg:grid-cols-3">
        <Desktop className="p-6 lg:col-span-2">
          <div className="mb-4 text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">Microcopy, in the app</div>
          <Fit width={520} height={240} max={1.2} className="my-auto">
            <div className="flex h-full flex-col items-start justify-center gap-4">
              <DoneToast name="IMG_2041.jpg" meta="from HEIC · 1.8 MB · next to the original" />
              <ErrorToast />
              <ProgressHUD value={0.4} />
            </div>
          </Fit>
        </Desktop>
        <div className="aura-card p-7">
          <div className="text-[12px] font-semibold uppercase tracking-[0.14em] text-[#8A7F74]">Empty states</div>
          <div className="mt-5 space-y-5">
            {[
              ['Float shelf, empty', 'Nothing floating yet. Drag a file here and it’ll wait for you.'],
              ['History, empty', 'Your conversions will show up here. So far, so tidy.'],
              ['No routes for a file', 'We don’t know how to turn a .sketch into anything yet. Want to tell us what you’d like?'],
              ['Pro, signed out', 'Everything local works without an account. Pro is here if you need it.'],
            ].map(([h, b]) => (
              <div key={h}>
                <div className="text-[12.5px] font-semibold text-[#1E1B18]">{h}</div>
                <p className="aura-serif mt-1 text-[18px] leading-[1.3] text-[#1E1B18]">“{b}”</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Section>
  )
}

/* ------------------------------------------------------------------ 6 motion */

function MotionSection() {
  const [open, setOpen] = useState(true)
  const [k, setK] = useState(0)
  const [hover, setHover] = useState<number | null>(isShot ? 0 : null)
  useEffect(() => {
    if (isShot) return
    const id = setInterval(() => setHover((h) => (h == null ? 0 : (h + 1) % 8)), 900)
    return () => clearInterval(id)
  }, [])
  const principles = [
    ['Light, not paint', 'Colour arrives as glow. It gathers under the thing you’re aiming at, and fades when you leave.'],
    ['Springs that settle', 'Stiffness 260–520, damping 24–32. Things arrive quickly and settle softly. No bounce-backs.'],
    ['Breathing, not blinking', 'Ambient glow drifts on 7–17 s loops. Slow enough to feel alive, never enough to notice.'],
    ['Warm glass', 'Frost is blur 28 + saturate 1.6 over a warm tint, with a 1px white top edge. Never grey.'],
    ['A hand was here', 'Underlines draw in once. Sticky notes sit slightly crooked. One per view.'],
  ]
  return (
    <Section id="motion" n="05 — Motion & materials" title={<>Things <em>glow</em>, then settle.</>}
      intro="Every motion in Aura is light moving or paper landing. Respect reduced motion: glows hold still, springs become fades.">
      <div className="grid grid-cols-1 gap-4 md:grid-cols-5">
        {principles.map(([t, b], i) => (
          <div key={t} className="aura-card p-6">
            <span className="aura-serif text-[13px] italic text-[#B04E1B]">0{i + 1}</span>
            <div className="aura-serif mt-2 text-[22px] leading-[1.1] text-[#1E1B18]" style={{ fontWeight: 430 }}>{t}</div>
            <p className="mt-2 text-[13.5px] leading-[1.5] text-[#5B524A]">{b}</p>
          </div>
        ))}
      </div>
      <div className="mt-5 grid grid-cols-1 gap-5 lg:grid-cols-3">
        <Tile className="relative h-[380px]" label="Breathing glow · 7 s">
          <Glow className="inset-[12%]" intensity={1} />
          <div className="absolute inset-0 grid place-items-center"><Mark size={70} /></div>
        </Tile>
        <Tile className="relative h-[380px] bg-[#FBF7F0]" label="Bloom · spring 340 / 26">
          <div className="absolute inset-0 grid place-items-center">
            <AuraWheel segments={convertSegs} size={240} open={open} hoverIndex={hover} interactive={false} labelSize={10.5} />
          </div>
          <button type="button" onClick={() => setOpen(!open)} className="aura-btn aura-btn-soft absolute right-4 top-4 px-3 py-1.5 text-[12px]"><RotateCcw size={12} /> {open ? 'Close' : 'Open'}</button>
        </Tile>
        <Tile className="relative h-[380px] overflow-hidden" label="Warm glass over light">
          <div className="aura-drift-a absolute left-[10%] top-[15%] size-[200px] rounded-full bg-[#FFB27A] blur-2xl" />
          <div className="aura-drift-b absolute bottom-[10%] right-[5%] size-[180px] rounded-full bg-[#9DB4FF] blur-2xl" />
          <div className="absolute inset-0 grid place-items-center">
            <div className="aura-frost grid h-[170px] w-[250px] place-items-center rounded-[28px]">
              <div className="text-center"><div className="aura-serif text-[22px] text-[#1E1B18]">Frost</div><div className="mt-1 font-mono text-[11px] text-[#5B524A]">blur 28 · sat 1.6 · 82% paper</div></div>
            </div>
          </div>
        </Tile>
        <Tile className="relative h-[300px] lg:col-span-2" label="Hand-drawn underline · draws once, 1.4 s">
          <div className="absolute inset-0 grid place-items-center px-6">
            <button type="button" onClick={() => setK(k + 1)} className="aura-display relative text-[clamp(48px,6vw,88px)] text-[#1E1B18]" aria-label="Redraw underline">
              Done, <em>gently</em>.
              <Scribble key={k} className="absolute -bottom-2 right-0 h-[16px] w-[58%]" width={300} />
            </button>
          </div>
          <span className="absolute right-5 top-4 text-[12px] text-[#8A7F74]">click to redraw</span>
        </Tile>
        <Tile className="relative h-[300px]" label="Paper grain · 22% multiply">
          <div className="absolute inset-0 grid grid-cols-2">
            <div className="relative bg-[#FBF7F0]"><Grain className="!opacity-70" /><span className="absolute left-5 top-5 text-[12px] font-semibold text-[#5B524A]">with</span></div>
            <div className="relative bg-[#FBF7F0]"><span className="absolute left-5 top-5 text-[12px] font-semibold text-[#5B524A]">without</span></div>
          </div>
        </Tile>
      </div>
    </Section>
  )
}

/* ------------------------------------------------------------------ 7 landing */

function LandingSection() {
  return (
    <Section id="landing" n="06 — Landing" title={<>The page is a <em>sunny</em> desk.</>}
      intro="Paper all the way down, product UI floating on pools of light, and one sticky note per screen saying the thing a friend would point out.">
      <Link to="/d/aura/landing" className="group block">
        <div className="aura-card overflow-hidden p-2 transition-transform duration-500 group-hover:-translate-y-1">
          <div className="flex items-center gap-2 rounded-t-[22px] bg-[#F1EADF] px-4 py-3">
            {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-2.5 rounded-full" style={{ background: c }} />)}
            <span className="mx-auto rounded-full bg-white/80 px-6 py-1 font-mono text-[11.5px] text-[#5B524A]">halo.app</span>
            <span className="flex items-center gap-1 text-[12.5px] font-semibold text-[#1E1B18]">Open landing <ArrowUpRight size={14} className="transition group-hover:-translate-y-0.5 group-hover:translate-x-0.5" /></span>
          </div>
          <div className="relative overflow-hidden rounded-b-[22px] bg-[#FBF7F0]" style={{ maxHeight: 980 }}>
            <Fit width={1440} height={1500}><div className="aura-root pointer-events-none"><Hero /></div></Fit>
            <div className="absolute inset-x-0 bottom-0 h-32 bg-gradient-to-t from-[#FBF7F0] to-transparent" />
          </div>
        </div>
      </Link>
      <div className="mt-10 overflow-hidden rounded-[36px] bg-[#FBF7F0] shadow-[0_0_0_1px_rgba(30,27,24,.06)_inset]">
        <HowItWorks />
      </div>
      <div className="mt-5 grid gap-5">
        <div className="overflow-hidden rounded-[36px] bg-[#FBF7F0] shadow-[0_0_0_1px_rgba(30,27,24,.06)_inset] [&_section]:py-16"><Agents /></div>
        <div className="overflow-hidden rounded-[36px] bg-[#FBF7F0] shadow-[0_0_0_1px_rgba(30,27,24,.06)_inset] [&_section]:py-16"><Pricing /></div>
      </div>
    </Section>
  )
}

/* ------------------------------------------------------------------ page */

export default function BrandBook() {
  return (
    <div className="aura-root relative min-h-screen pb-24">
      <Grain className="fixed z-[1]" />
      {!part && <BookNav />}
      <div className="relative z-[2]">
        <Cover />
        <LogoSection />
        <ColourSection />
        <TypeSection />
        <VoiceSection />
        <MotionSection />
        <LandingSection />
        <Section id="onboarding" n="07 — Onboarding" title={<>Six pills to <em>hello</em>.</>}
          intro="Setup windows are stadiums floating on light. A round porthole on the left shows the one thing each step is about; the right side says it in a sentence and offers one clear button.">
          <OnboardingBoard />
        </Section>
        <Section id="app" n="08 — App surfaces" title={<>The app, in <em>warm</em> glass.</>}
          intro="This is where Aura matters most. Light vibrancy, a frosted warm-white wheel with an apricot wedge that glows when you aim, and a halo breathing round the disc. Hover the wheels; they work.">
          <AppBoard />
        </Section>
        <footer className="px-5 pb-10 pt-6 text-center text-[13px] text-[#8A7F74]">
          <Lockup size={20} className="mx-auto" /> <p className="mt-3">Aura · a Halo brand direction · {meta.tagline}</p>
        </footer>
      </div>
    </div>
  )
}
