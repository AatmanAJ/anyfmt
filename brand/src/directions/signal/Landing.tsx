import { AnimatePresence, motion, useScroll, useTransform } from 'motion/react'
import { CodeXml, Minus, Plus } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { isShot, Marquee, NumberTicker, Reveal, SpotlightCard } from '../../shared/kit'
import { product } from '../../shared/product'
import { cn } from '../../shared/cn'
import { LedField } from './LedField'
import { Led, Lockup } from './Mark'
import { KeyCap, SignalDemo, SignalFile } from './SignalDemo'
import { FileHub, SignalWheel } from './SignalWheel'
import { C, convertSegs, cssVars, wheels } from './tokens'
import { Button, Label, Scale, SectionHead, SignalRoot, Terminal } from './ui'

export function useWide(min = 1024) {
  const q = `(min-width: ${min}px)`
  const [wide, setWide] = useState(() => typeof window !== 'undefined' && window.matchMedia(q).matches)
  useEffect(() => {
    const m = window.matchMedia(q)
    const on = () => setWide(m.matches)
    m.addEventListener('change', on)
    return () => m.removeEventListener('change', on)
  }, [q])
  return wide
}

const wrap = 'mx-auto w-full max-w-[1280px] px-4 sm:px-6 md:px-10'

/* ───────────────────────────── Nav ───────────────────────────── */

function Nav() {
  const [solid, setSolid] = useState(false)
  useEffect(() => {
    const on = () => setSolid(window.scrollY > 24)
    on(); window.addEventListener('scroll', on, { passive: true })
    return () => window.removeEventListener('scroll', on)
  }, [])
  const links = [['How', '#how'], ['Features', '#features'], ['Agents', '#agents'], ['Pricing', '#pricing'], ['FAQ', '#faq']]
  return (
    <header className="fixed inset-x-0 top-0 z-50 transition-[background,box-shadow] duration-300"
      style={solid ? { background: 'rgba(5,5,6,.72)', backdropFilter: 'blur(18px) saturate(140%)', WebkitBackdropFilter: 'blur(18px) saturate(140%)', boxShadow: `0 1px 0 ${C.graphite}` } : undefined}>
      <div className={cn(wrap, 'flex h-16 items-center justify-between')}>
        <a href="#top" aria-label="anyfmt home"><Lockup size={24} /></a>
        <nav className="hidden items-center gap-8 md:flex" aria-label="Sections">
          {links.map(([l, h]) => (
            <a key={l} href={h} className="font-mono text-[11px] uppercase tracking-[0.18em] transition-colors hover:text-[#EDEDE6]" style={{ color: C.ash }}>{l}</a>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          <a href="#" aria-label="Source on GitHub" className="hidden size-10 place-items-center rounded-full transition-colors hover:bg-white/5 sm:grid" style={{ boxShadow: `inset 0 0 0 1px ${C.graphite}` }}><CodeXml size={16} /></a>
          <Button className="h-10 pl-4 pr-3 text-[11px]">Download</Button>
        </div>
      </div>
    </header>
  )
}

/* ───────────────────────────── Hero ───────────────────────────── */

function Hero() {
  const wide = useWide()
  const size = wide ? 360 : 272
  const anchor = useRef<HTMLDivElement>(null)
  const lit = useRef<number | null>(null)
  const [aim, setAim] = useState<number | null>(isShot ? 0 : null)
  const hero = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: hero, offset: ['start start', 'end start'] })
  const y = useTransform(scrollYProgress, [0, 1], [0, 140])
  const fade = useTransform(scrollYProgress, [0, 0.9], [1, 0.25])

  return (
    <section ref={hero} id="top" className="relative overflow-hidden pt-16">
      <motion.div className="absolute inset-0" style={{ opacity: fade }}>
        <LedField pitch={wide ? 11 : 9} dot={wide ? 1.45 : 1.2} base={0.075}
          ring={{ anchor, outer: wide ? 1.5 : 1.42, inner: wide ? 1.08 : 1.07, wedges: convertSegs.length, gap: wide ? 20 : 14 }}
          litRef={lit} shotLit={0}
          className="[mask-image:linear-gradient(180deg,#000_70%,transparent)]" />
      </motion.div>
      <div className={cn(wrap, 'relative grid min-h-[min(calc(100svh-140px),780px)] items-center gap-6 pb-10 pt-10 lg:min-h-[740px] lg:grid-cols-[1.1fr_1fr] lg:gap-0 lg:pb-24')}>
        <motion.div style={{ y: isShot ? 0 : y }} className="relative z-10 order-2 lg:order-1">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
            <span className="flex items-center gap-2"><Led size={6} blink /><Label style={{ color: C.bone }}>Live</Label></span>
            <Label>{product.platform}</Label>
            <Label dim>AGPL-3.0</Label>
          </div>
          <h1 className="mt-7 font-serif text-[64px] leading-[0.86] tracking-[-0.035em] sm:text-[96px] lg:text-[124px] xl:text-[136px]">
            Tune any file <span className="italic" style={{ color: C.solar }}>mid&#8209;drag.</span>
          </h1>
          <p className="mt-7 max-w-[44ch] text-[16px] leading-[1.6] md:text-[18px]" style={{ color: C.ash }}>
            {product.how}
          </p>
          <div className="mt-9 flex flex-wrap items-center gap-3">
            <Button>Download for Mac</Button>
            <Button variant="ghost" icon={false}>Read the source</Button>
          </div>
        </motion.div>
        <div className="relative order-1 flex items-center justify-center py-14 lg:order-2 lg:py-0">
          <div ref={anchor} style={{ width: size, height: size }} className="relative">
            <SignalDemo segments={convertSegs} target={0} sweep={[2, 1, 0]} size={size}
              onAim={(v) => { lit.current = v; setAim(v) }} />
          </div>
        </div>
      </div>
      {/* Readout strip */}
      <div className="relative z-10" style={{ borderTop: `1px solid ${C.graphite}`, background: 'rgba(5,5,6,.6)', backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)' }}>
        <div className={cn(wrap, 'grid grid-cols-2 md:grid-cols-4')}>
          {[
            ['Input', 'clip.mov · 48 MB'],
            ['Key', '⇧ Shift · Convert'],
            ['Tuned', aim != null ? `CH ${String(aim + 1).padStart(2, '0')} · ${convertSegs[aim].label}${convertSegs[aim].sub ? ' · ' + convertSegs[aim].sub : ''}` : 'Scanning…'],
            ['Latency', '43 ms key → wheel'],
          ].map(([k, v], i) => (
            <div key={k} className={cn('flex flex-col gap-2 py-4', i % 2 === 1 && 'pl-4 md:pl-6', i >= 2 && 'max-md:border-t', i > 0 && 'md:border-l md:pl-6')} style={{ borderColor: C.graphite }}>
              <Label dim>{k}</Label>
              <span className="truncate font-mono text-[12px] tracking-[0.04em]" style={{ color: k === 'Tuned' && aim != null ? C.solar : C.bone }}>{v}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── Marquee ───────────────────────────── */

function Formats() {
  const all = [...product.conversions]
  const fmts = [...new Set([...product.formatsVideo, ...product.formatsImage])]
  return (
    <section className="py-14" aria-label="Formats" style={{ borderBottom: `1px solid ${C.graphite}` }}>
      <Marquee duration={50} className="gap-10">
        {all.map((c) => (
          <span key={c} className="flex shrink-0 items-center gap-10 font-mono text-[13px] uppercase tracking-[0.14em]" style={{ color: C.bone }}>
            {c}<span className="size-1.5 rounded-full" style={{ background: C.graphite2 }} />
          </span>
        ))}
      </Marquee>
      <Marquee duration={36} reverse className="mt-6 gap-4">
        {fmts.map((f, i) => (
          <span key={f} className="shrink-0 rounded-full px-4 py-2 font-mono text-[12px] tracking-[0.14em]"
            style={i % 5 === 0 ? { background: C.solar, color: C.void } : { color: C.ash, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>{f}</span>
        ))}
      </Marquee>
    </section>
  )
}

/* ───────────────────────────── How it works ───────────────────────────── */

export function HowItWorks({ compact }: { compact?: boolean }) {
  const [k, setK] = useState(0)
  const [hot, setHot] = useState<number | null>(null)
  const wide = useWide(768)
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === 'Shift') setK(0)
      else if (e.key === 'Meta') setK(1)
      else if (e.key === 'Control') setK(2)
    }
    window.addEventListener('keydown', down)
    return () => window.removeEventListener('keydown', down)
  }, [])
  const w = wheels[k]
  const size = wide ? 420 : 320
  const hub = [<FileHub key="a" stem="clip" ext="MOV" meta="48 MB" size={size} />, <FileHub key="b" stem="photo" ext="HEIC" size={size} />, <FileHub key="c" stem="deck" ext="PDF" size={size} />][k]
  return (
    <section id="how" className={cn(!compact && 'py-24 md:py-36')}>
      <div className={cn(!compact && wrap)}>
        <SectionHead ch="02" kicker="How it works" title={<>Three keys.<br /><i>Three wheels.</i></>}
          lede="You are already dragging. Hold a modifier and the wheel opens round your pointer. Drop on a wedge. That is the whole interface." />
        <div className="mt-14 grid items-center gap-12 lg:grid-cols-[1fr_auto] lg:gap-20">
          <div className="flex flex-col gap-3">
            {wheels.map((x, i) => (
              <button key={x.wheel} type="button" onClick={() => setK(i)}
                className="group flex items-center gap-5 rounded-[16px] p-3 pr-5 text-left outline-none transition-colors focus-visible:ring-2 focus-visible:ring-[#D7FF3A]"
                style={{ background: k === i ? C.carbon : 'transparent', boxShadow: k === i ? `inset 0 0 0 1px ${C.graphite}` : 'none' }}>
                <KeyCap symbol={x.key} label={x.name} size="md" pressed={k === i} active={k === i} />
                <div className="min-w-0 flex-1">
                  <div className="flex items-baseline gap-3">
                    <span className="font-serif text-[32px] leading-none md:text-[38px]" style={{ color: k === i ? C.bone : C.ash }}>{x.wheel}</span>
                    <Label dim>{x.segs.length} wedges</Label>
                  </div>
                  <p className="mt-1.5 text-[14px] leading-snug" style={{ color: C.ash }}>{x.blurb}</p>
                </div>
              </button>
            ))}
            <p className="mt-3 pl-3 font-mono text-[10.5px] uppercase tracking-[0.16em]" style={{ color: C.ash2 }}>
              Try it: press <span style={{ color: C.bone }}>⇧</span> <span style={{ color: C.bone }}>⌘</span> or <span style={{ color: C.bone }}>⌃</span> on your keyboard
            </p>
          </div>
          <div className="relative mx-auto mb-10 grid place-items-center" style={{ width: size, height: size }}>
            <div className="pointer-events-none absolute -inset-16 rounded-full opacity-60" style={{ background: 'radial-gradient(circle, rgba(215,255,58,.10), transparent 62%)' }} />
            <AnimatePresence mode="wait">
              <SignalWheel key={w.wheel} segments={w.segs} size={size} hub={hub} onHover={setHot} restIndex={isShot ? 0 : null} />
            </AnimatePresence>
            <div className="absolute -bottom-10 left-1/2 -translate-x-1/2 whitespace-nowrap font-mono text-[11px] uppercase tracking-[0.16em]" style={{ color: hot != null ? C.solar : C.ash2 }}>
              {hot != null ? `▸ ${w.segs[hot].label}` : 'Aim at a wedge'}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── Features ───────────────────────────── */

function Card({ ch, title, body, children, className }: { ch: string; title: string; body: string; children?: ReactNode; className?: string }) {
  return (
    <SpotlightCard color="rgba(215,255,58,.07)" className={cn('flex flex-col rounded-[20px] p-6 md:p-7', className)} style={{ background: C.carbon, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
      <div className="flex items-center justify-between"><Label style={{ color: C.solar }}>{ch}</Label><Led size={5} on={false} className="transition-colors group-hover:!bg-[#D7FF3A]" /></div>
      <div className="relative flex min-h-[150px] flex-1 items-center">{children}</div>
      <h3 className="mt-6 font-serif text-[34px] leading-none tracking-[-0.02em]">{title}</h3>
      <p className="mt-2.5 max-w-[46ch] text-[14.5px] leading-[1.55]" style={{ color: C.ash }}>{body}</p>
    </SpotlightCard>
  )
}

function Features() {
  const f = product.features
  return (
    <section id="features" className="py-24 md:py-36" style={{ borderTop: `1px solid ${C.graphite}` }}>
      <div className={wrap}>
        <SectionHead ch="03" kicker="Features" title={<>Six things,<br /><i>done properly.</i></>} />
        <div className="mt-14 grid gap-3 md:grid-cols-6">
          <Card ch="01" title={f[0].title} body={f[0].body} className="md:col-span-4">
            <div className="relative h-[230px] w-full overflow-hidden">
              <LedField pitch={8} dot={1.3} base={0.05} glow={90} glyph={{ text: '793', family: '"Instrument Serif"', height: 1.12, x: 0.0, y: 0.56, align: 'left', level: 0.95, thicken: 0.7 }} />
              <div className="absolute right-0 top-0 flex flex-col items-end gap-1.5"><Label dim>Routes</Label><Label style={{ color: C.solar }}>All tested</Label></div>
            </div>
          </Card>
          <Card ch="02" title={f[1].title} body={f[1].body} className="md:col-span-2">
            <div className="flex flex-wrap gap-1.5">
              {product.tools.map((t, i) => (
                <span key={t} className="rounded-full px-3 py-1.5 font-mono text-[11px] uppercase tracking-[0.1em]"
                  style={i === 2 ? { background: C.solar, color: C.void } : { color: C.bone, boxShadow: `inset 0 0 0 1px ${C.graphite2}` }}>{t}</span>
              ))}
            </div>
          </Card>
          <Card ch="03" title={f[2].title} body={f[2].body} className="md:col-span-2">
            <div className="mt-4 flex w-full flex-col">
              {product.actions.map((a, i) => (
                <div key={a} className="flex items-center justify-between py-[7px]" style={{ borderBottom: i < 5 ? `1px solid ${C.graphite}` : 'none' }}>
                  <span className="font-mono text-[11.5px] uppercase tracking-[0.12em]" style={{ color: i === 1 ? C.bone : C.ash }}>{a}</span>
                  <Led size={5} on={i === 1} />
                </div>
              ))}
            </div>
          </Card>
          <Card ch="04" title={f[3].title} body={f[3].body} className="md:col-span-2">
            <div className="flex w-full flex-col gap-2">
              {[['GIF', '15 fps · 720 px', true], ['JPG', '80 % · strip GPS', false], ['MP4', 'H.264 · ≤ 25 MB', false]].map(([e, d, on]) => (
                <div key={e as string} className="flex items-center gap-3 rounded-[12px] px-3 py-2.5" style={{ background: on ? 'rgba(215,255,58,.08)' : C.carbon2, boxShadow: `inset 0 0 0 1px ${on ? 'rgba(215,255,58,.4)' : C.graphite}` }}>
                  <span className="rounded-[4px] px-1.5 py-[3px] font-mono text-[9px] font-bold leading-none tracking-[0.12em]" style={{ background: on ? C.solar : C.graphite2, color: on ? C.void : C.bone }}>{e as string}</span>
                  <span className="font-mono text-[11.5px]" style={{ color: on ? C.bone : C.ash }}>{d as string}</span>
                </div>
              ))}
            </div>
          </Card>
          <Card ch="05" title={f[4].title} body={f[4].body} className="md:col-span-2">
            <div className="w-full rounded-[12px] p-3.5 font-mono text-[11px] leading-[1.8]" style={{ background: C.void, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
              <div><span style={{ color: C.solar }}>❯</span> anyfmt convert clip.mov --to gif --json</div>
              <div style={{ color: C.ash }}>{'{"event":"progress","pct":0.42}'}</div>
              <div style={{ color: C.ash }}>{'{"event":"done","out":"clip.gif"}'}</div>
            </div>
          </Card>
          <Card ch="06" title={f[5].title} body={f[5].body} className="md:col-span-6">
            <div className="relative h-[120px] w-full overflow-hidden rounded-[12px]" style={{ background: C.void, boxShadow: `inset 0 0 0 1px ${C.graphite}` }}>
              <LedField pitch={8} dot={1.1} base={0.06} glow={80} wave={{ y: 0.5, amp: 0.004, cycles: 3 }} />
              <div className="absolute left-4 top-3"><Label>Network · outbound</Label></div>
              <div className="absolute right-4 top-3 font-mono text-[12px]" style={{ color: C.solar }}>0 B/s</div>
            </div>
          </Card>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── Stats ───────────────────────────── */

function Stats() {
  return (
    <section className="py-20 md:py-28" style={{ borderTop: `1px solid ${C.graphite}` }}>
      <div className={wrap}>
        <Scale ticks={64} />
        <div className="grid grid-cols-2 lg:grid-cols-4">
          {product.stats.map((s, i) => (
            <div key={s.label} className={cn('flex flex-col gap-4 py-10 pr-4', i > 0 && 'lg:border-l lg:pl-8', i % 2 === 1 && 'border-l pl-4 lg:pl-8')}
              style={{ borderColor: C.graphite }}>
              <div className="flex items-center gap-2"><Led size={5} on={i === 2} /><Label dim>CH {String(i + 1).padStart(2, '0')}</Label></div>
              <span className="font-serif text-[64px] leading-[0.85] tracking-[-0.03em] sm:text-[88px] lg:text-[112px]" style={{ color: i === 2 ? C.solar : C.bone }}>
                {isShot ? s.value : <NumberTicker value={s.value} />}
              </span>
              <span className="max-w-[22ch] text-[14px] leading-snug" style={{ color: C.ash }}>{s.label}</span>
            </div>
          ))}
        </div>
        <Scale ticks={64} className="rotate-180" />
      </div>
    </section>
  )
}

/* ───────────────────────────── Privacy ───────────────────────────── */

function Privacy() {
  return (
    <section className="relative overflow-hidden py-24 md:py-36" style={{ borderTop: `1px solid ${C.graphite}` }}>
      <div className={cn(wrap, 'grid items-center gap-10 lg:grid-cols-2')}>
        <div className="relative h-[340px] w-full md:h-[520px]">
          <LedField pitch={10} dot={1.6} base={0.05} glow={140} glyph={{ text: '0', family: '"Instrument Serif"', height: 1.25, y: 0.55, color: 'solar', level: 1 }} />
          <div className="absolute left-0 top-0"><Label>Network calls · default</Label></div>
        </div>
        <div>
          <SectionHead ch="04" kicker="Local" title={<>Your files <i>stay home.</i></>}
            lede="Everything runs on your Mac. anyfmt makes zero network calls unless you ask for a Pro cloud feature, per file, every time." />
          <div className="mt-10 grid grid-cols-2 gap-px overflow-hidden rounded-[16px]" style={{ background: C.graphite, boxShadow: `0 0 0 1px ${C.graphite}` }}>
            {[['Account', 'Not needed'], ['Upload', 'Never'], ['Telemetry', 'None'], ['Cloud', 'Opt-in, Pro']].map(([k, v]) => (
              <div key={k} className="flex flex-col gap-2 p-5" style={{ background: C.void }}>
                <Label dim>{k}</Label>
                <span className="font-serif text-[28px] leading-none">{v}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── Agents ───────────────────────────── */

export function Agents({ compact }: { compact?: boolean }) {
  return (
    <section id="agents" className={cn(!compact && 'py-24 md:py-36')} style={compact ? undefined : { borderTop: `1px solid ${C.graphite}` }}>
      <div className={cn(!compact && wrap, 'grid items-center gap-12 lg:grid-cols-[1fr_1.15fr]')}>
        <div>
          <SectionHead ch="05" kicker="Agents · CLI · MCP" title={<>A real CLI. <i>For you and your agents.</i></>}
            lede="Every wheel action is a command. JSON out, NDJSON progress, exit codes that mean something. The MCP server lets Claude convert your files, on your Mac." />
          <div className="mt-8 flex flex-wrap gap-2">
            {['--json', '--ndjson', 'MCP', 'exit 0'].map((t) => (
              <span key={t} className="rounded-full px-3 py-1.5 font-mono text-[11px] tracking-[0.08em]" style={{ color: C.bone, boxShadow: `inset 0 0 0 1px ${C.graphite2}` }}>{t}</span>
            ))}
          </div>
        </div>
        <Terminal lines={[
          '# convert, stream progress, get a path back',
          '$ anyfmt convert clip.mov --to gif --json',
          '{"event":"start","route":"mov→gif","fps":15}',
          '{"event":"progress","pct":0.42}',
          '{"event":"progress","pct":1}',
          '{"event":"done","out":"~/Desktop/clip.gif","ms":1840}',
          '',
          '# local. 0 network calls.',
        ]} />
      </div>
    </section>
  )
}

/* ───────────────────────────── Pricing ───────────────────────────── */

export function Pricing({ compact }: { compact?: boolean }) {
  const [local, pro] = product.pricing
  return (
    <section id="pricing" className={cn(!compact && 'py-24 md:py-36')} style={compact ? undefined : { borderTop: `1px solid ${C.graphite}` }}>
      <div className={cn(!compact && wrap)}>
        <SectionHead ch="06" kicker="Pricing" title={<>Free where it runs. <i>Paid where it doesn’t.</i></>} />
        <div className="mt-14 grid gap-3 md:grid-cols-2">
          {[local, pro].map((p, i) => (
            <div key={p.name} className="relative flex flex-col overflow-hidden rounded-[24px] p-7 md:p-9"
              style={{ background: i === 0 ? C.carbon : C.void, boxShadow: `inset 0 0 0 1px ${i === 0 ? 'rgba(215,255,58,.45)' : C.graphite}` }}>
              {i === 0 && <div className="pointer-events-none absolute -right-20 -top-20 size-64 rounded-full" style={{ background: 'radial-gradient(circle, rgba(215,255,58,.16), transparent 65%)' }} />}
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2"><Led size={6} on={i === 0} /><Label style={{ color: C.bone }}>{p.name}</Label></span>
                <Label dim>{i === 0 ? 'Open source' : 'Optional'}</Label>
              </div>
              <div className="mt-10 flex items-baseline gap-2">
                <span className="font-serif text-[88px] leading-[0.8] tracking-[-0.03em]">{p.price}</span>
                <span className="font-mono text-[12px] uppercase tracking-[0.14em]" style={{ color: C.ash }}>{p.period}</span>
              </div>
              <ul className="mt-9 flex flex-col">
                {p.points.map((pt) => (
                  <li key={pt} className="flex items-center gap-3 py-3 text-[15px]" style={{ borderTop: `1px solid ${C.graphite}` }}>
                    <span className="size-1.5 rounded-full" style={{ background: i === 0 ? C.solar : C.ash }} />{pt}
                  </li>
                ))}
              </ul>
              <div className="mt-8">{i === 0 ? <Button>Download</Button> : <Button variant="ghost">Get Pro</Button>}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── FAQ ───────────────────────────── */

const FAQ = [
  ['Is anyfmt really free?', 'Yes. Every local feature is free, forever, and the code is open source under AGPL-3.0. Pro adds cloud extras for $4 a month. You never need it.'],
  ['Does anything leave my Mac?', 'No. Conversions, tools and actions run on your Mac. No account, no upload, no telemetry. Pro cloud features are opt-in.'],
  ['What do I need?', 'macOS 13 or later on Apple silicon. anyfmt lives in the menu bar and asks for Accessibility so it can see the drag.'],
  ['How many formats?', '793 conversion routes across images, video, audio, documents, ebooks and archives. Every route is tested. Multi-hop routes are picked for quality.'],
  ['Can my agent use it?', 'Yes. The halo CLI prints JSON and streams NDJSON progress, and the MCP server lets Claude convert files locally.'],
  ['Why a key, not a right-click?', 'Because you are already dragging. A key puts the wheel round your pointer in 43 ms, and the drop is the click.'],
]

function Faq() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="py-24 md:py-36" style={{ borderTop: `1px solid ${C.graphite}` }}>
      <div className={cn(wrap, 'grid gap-12 lg:grid-cols-[1fr_1.5fr]')}>
        <SectionHead ch="07" kicker="FAQ" title={<>Short <i>answers.</i></>} />
        <div className="flex flex-col" style={{ borderBottom: `1px solid ${C.graphite}` }}>
          {FAQ.map(([q, a], i) => {
            const on = open === i
            return (
              <div key={q} style={{ borderTop: `1px solid ${C.graphite}` }}>
                <button type="button" aria-expanded={on} onClick={() => setOpen(on ? null : i)}
                  className="flex w-full items-center gap-5 py-6 text-left outline-none focus-visible:ring-2 focus-visible:ring-[#D7FF3A]">
                  <Label style={{ color: on ? C.solar : C.ash2 }}>{String(i + 1).padStart(2, '0')}</Label>
                  <span className="flex-1 font-serif text-[26px] leading-tight md:text-[32px]">{q}</span>
                  <span className="grid size-8 shrink-0 place-items-center rounded-full transition-colors" style={on ? { background: C.solar, color: C.void } : { boxShadow: `inset 0 0 0 1px ${C.graphite2}` }}>
                    {on ? <Minus size={14} /> : <Plus size={14} />}
                  </span>
                </button>
                <AnimatePresence initial={false}>
                  {on && (
                    <motion.div initial={isShot ? false : { height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }}
                      transition={{ type: 'spring', stiffness: 300, damping: 34 }} className="overflow-hidden">
                      <p className="max-w-[58ch] pb-7 pl-[52px] text-[15.5px] leading-[1.65]" style={{ color: C.ash }}>{a}</p>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── Final CTA + footer ───────────────────────────── */

function FinalCta() {
  return (
    <section className="relative overflow-hidden" style={{ borderTop: `1px solid ${C.graphite}` }}>
      <div className="absolute inset-0">
        <LedField pitch={10} dot={1.4} base={0.07} glow={160} wave={{ y: 0.9, amp: 0.035, cycles: 2.2 }} className="[mask-image:radial-gradient(ellipse_at_center,#000_40%,transparent_80%)]" />
      </div>
      <div className={cn(wrap, 'relative flex flex-col items-center py-32 text-center md:py-44')}>
        <Reveal><SignalFile size={56} name="" lit /></Reveal>
        <h2 className="mt-10 font-serif text-[60px] leading-[0.88] tracking-[-0.035em] sm:text-[96px] md:text-[132px]">
          Drop it <i style={{ color: C.solar }}>on the wheel.</i>
        </h2>
        <p className="mt-6 max-w-[40ch] text-[16px] leading-relaxed" style={{ color: C.ash }}>{product.oneLiner}</p>
        <div className="mt-10 flex flex-wrap justify-center gap-3">
          <Button>Download for Mac</Button>
          <Button variant="ghost" icon={false}>{product.platform}</Button>
        </div>
      </div>
    </section>
  )
}

function Footer() {
  const cols: [string, string[]][] = [
    ['Product', ['Download', 'Pricing', 'Changelog', 'Roadmap']],
    ['Build', ['CLI', 'MCP server', 'Source', 'Licence']],
    ['anyfmt', ['Privacy', 'Press kit', 'Contact']],
  ]
  return (
    <footer className="pb-28 pt-16" style={{ borderTop: `1px solid ${C.graphite}` }}>
      <div className={cn(wrap, 'grid grid-cols-3 gap-x-6 gap-y-12 md:grid-cols-[1.4fr_repeat(3,1fr)]')}>
        <div className="col-span-3 flex flex-col gap-5 md:col-span-1">
          <Lockup size={28} />
          <p className="max-w-[30ch] text-[14px] leading-relaxed" style={{ color: C.ash }}>{product.licence}</p>
        </div>
        {cols.map(([h, ls]) => (
          <div key={h} className="flex flex-col gap-3">
            <Label dim>{h}</Label>
            {ls.map((l) => <a key={l} href="#" className="text-[14px] transition-colors hover:text-[#D7FF3A]" style={{ color: C.bone }}>{l}</a>)}
          </div>
        ))}
      </div>
      <div className={cn(wrap, 'mt-16 flex flex-wrap items-center justify-between gap-4')}>
        <Label dim>© 2026 anyfmt · AGPL-3.0</Label>
        <span className="flex items-center gap-2"><Led size={5} /><Label dim>{product.platform}</Label></span>
      </div>
    </footer>
  )
}

export function Landing() {
  return (
    <SignalRoot vars={cssVars}>
      <Nav />
      <main>
        <Hero />
        <Formats />
        <HowItWorks />
        <Features />
        <Stats />
        <Privacy />
        <Agents />
        <Pricing />
        <Faq />
        <FinalCta />
      </main>
      <Footer />
    </SignalRoot>
  )
}
