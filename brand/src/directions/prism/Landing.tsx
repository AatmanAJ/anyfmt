import { AnimatePresence, motion, useInView, useScroll, useTransform } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import {
  ArrowRight, ArrowUpRight, Bot, Check, Cpu, Download, Layers, Lock, Plus, ShieldCheck, Sparkles, Zap,
} from 'lucide-react'
import { cn } from '../../shared/cn'
import { Marquee, SpotlightCard, isShot } from '../../shared/kit'
import { product } from '../../shared/product'
import { FloatShelf, Toast } from './AppSurfaces'
import { GlassKey, PrismDemo } from './Demo'
import { Lockup, PrismMark } from './Logo'
import { Hub, PrismWheel, SEG, type PSeg } from './PrismWheel'
import { Eyebrow, FormatRing, IRIS, Mesh, P, Pill, PrismStyle, Rise, Scaled, Ticker, glass } from './theme'

const W = 'mx-auto w-full max-w-[1200px] px-5 md:px-8'

/* ---------------- nav ---------------- */
function Nav() {
  return (
    <div className="fixed inset-x-0 top-3 z-50 px-3 md:top-4">
      <nav className="mx-auto flex h-14 max-w-[1080px] items-center justify-between rounded-full pl-4 pr-2" style={glass.light} aria-label="Main">
        <a href="#top" className="p-focus rounded-full"><Lockup size={22} /></a>
        <div className="hidden items-center gap-1 text-[13.5px] text-[#5E5677] md:flex">
          {[['How it works', '#how'], ['Features', '#features'], ['Agents', '#agents'], ['Pricing', '#pricing'], ['FAQ', '#faq']].map(([l, h]) => (
            <a key={h} href={h} className="p-focus rounded-full px-3 py-1.5 transition-colors hover:bg-white/70 hover:text-[#1C1530]">{l}</a>
          ))}
        </div>
        <div className="flex items-center gap-1">
          <Pill variant="ghost" size="sm" className="hidden sm:inline-flex" href="#agents">Source</Pill>
          <Pill size="sm" href="#pricing"><Download size={14} /> Download</Pill>
        </div>
      </nav>
    </div>
  )
}

/* ---------------- hero ---------------- */
function OrbitChip({ children, className, delay = 0 }: { children: ReactNode; className?: string; delay?: number }) {
  return (
    <motion.div className={cn('absolute z-20 hidden items-center gap-2 whitespace-nowrap rounded-full px-3.5 py-2 text-[12.5px] font-medium text-[#1C1530] md:flex', className)}
      style={glass.light}
      initial={isShot ? false : { opacity: 0, scale: 0.8, filter: 'blur(6px)' }} animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }}
      transition={{ delay: 0.6 + delay, type: 'spring', stiffness: 200, damping: 20 }}>
      <span className="p-float inline-flex items-center gap-2" style={{ animationDelay: `${delay * 2}s` }}>{children}</span>
    </motion.div>
  )
}

function Hero() {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start start', 'end start'] })
  const tilt = useTransform(scrollYProgress, [0, 0.5], [14, 0])
  const scale = useTransform(scrollYProgress, [0, 0.5], [0.94, 1])
  const glow = useTransform(scrollYProgress, [0, 0.6], [0.6, 1])
  const inView = useInView(ref)
  return (
    <section ref={ref} id="top" className="relative overflow-hidden pb-20 pt-32 md:pb-28 md:pt-40">
      <Mesh />
      <div aria-hidden className="absolute inset-x-0 bottom-0 h-40 bg-gradient-to-b from-transparent to-[#F6F4FB]" />
      <div className={cn(W, 'relative text-center')}>
        <Rise><Eyebrow>Open source · {product.platform}</Eyebrow></Rise>
        <h1 className="p-display mx-auto mb-0 mt-6 max-w-[920px] text-[52px] font-semibold leading-[0.95] sm:text-[76px] md:text-[104px]">
          <Rise delay={0.05}>Files that change</Rise>
          <Rise delay={0.12}><span className="p-iris-text-anim pr-[0.04em]">mid‑air.</span></Rise>
        </h1>
        <Rise delay={0.2}>
          <p className="mx-auto mb-0 mt-6 max-w-[540px] text-[17px] leading-[1.55] text-[#5E5677] md:text-[19px]">
            {product.how}
          </p>
        </Rise>
        <Rise delay={0.28} className="mt-8 flex flex-wrap items-center justify-center gap-3">
          <Pill size="lg" href="#pricing"><Download size={16} /> Download for Mac</Pill>
          <Pill size="lg" variant="glass" href="#play">Play with the wheel <ArrowRight size={16} /></Pill>
        </Rise>
        <Rise delay={0.34}><p className="mb-0 mt-4 text-[12.5px] text-[#8E87A6]">Free forever · no account · nothing uploaded</p></Rise>
      </div>

      {/* Stage */}
      <div className={cn(W, 'relative mt-14 md:mt-20')} style={{ perspective: 1400 }}>
        <motion.div className="relative mx-auto max-w-[1040px] overflow-hidden rounded-[32px] md:rounded-[44px]"
          style={{ rotateX: isShot ? 0 : tilt, scale: isShot ? 1 : scale, transformOrigin: '50% 0%', ...glass.light }}>
          <motion.div className="absolute inset-0" style={{ opacity: isShot ? 1 : glow }}>
            <div className="absolute inset-0" style={{ background: `radial-gradient(70% 90% at 20% 0%, rgba(255,107,139,.32), transparent 60%), radial-gradient(60% 80% at 100% 30%, rgba(94,231,223,.35), transparent 60%), radial-gradient(80% 80% at 50% 110%, rgba(185,167,255,.6), transparent 60%)` }} />
          </motion.div>
          <div className="p-grain absolute inset-0 opacity-[.15] mix-blend-overlay" />
          {/* faux desktop: menu bar */}
          <div className="relative flex h-8 items-center justify-between border-b border-white/50 bg-white/35 px-4 text-[11.5px] font-medium text-[#1C1530]/75">
            <span className="flex items-center gap-4"><span className="font-semibold text-[#1C1530]">Finder</span><span className="hidden sm:inline">File</span><span className="hidden sm:inline">Edit</span><span className="hidden sm:inline">View</span></span>
            <span className="flex items-center gap-3"><PrismMark size={15} /><span className="tabular-nums">Mon 9:41</span></span>
          </div>
          <div className="relative grid h-[460px] place-items-center sm:h-[540px] md:h-[600px]">
            <FormatRing size={560} thickness={1} className="left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 opacity-60" speed="p-spin-slow" />
            <FormatRing size={720} thickness={1} bloom={false} className="left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 opacity-30" speed="p-spin-rev" />
            <div className="w-full max-w-[400px]"><Scaled w={400} h={400}><PrismDemo size={360} paused={!inView && !isShot} /></Scaled></div>
            <OrbitChip className="left-[7%] top-[16%]"><span className="font-mono text-[11px] text-[#8E87A6]">⇧</span> Convert · 793 routes</OrbitChip>
            <OrbitChip className="right-[6%] top-[22%]" delay={0.15}><Zap size={13} className="text-[#FF6B8B]" /> 43 ms to wheel</OrbitChip>
            <OrbitChip className="bottom-[18%] left-[9%]" delay={0.3}><ShieldCheck size={13} className="text-[#2FBF9B]" /> Stays on your Mac</OrbitChip>
            <OrbitChip className="bottom-[14%] right-[8%]" delay={0.45}><span className="size-2 rounded-full" style={{ background: IRIS }} /> GIF · 15 fps · 4.1 MB</OrbitChip>
          </div>
        </motion.div>
      </div>
    </section>
  )
}

/* ---------------- marquee ---------------- */
function Formats() {
  const all = [...product.conversions]
  const chip = (t: string) => (
    <span key={t} className="inline-flex shrink-0 items-center gap-2 rounded-full px-4 py-2 text-[14px] font-medium text-[#3A3152]" style={glass.thin}>
      {t.split(/ ([→←]) /).map((p, i) => i === 1 ? <span key={i} className="p-iris-text font-semibold">{p}</span> : <span key={i}>{p}</span>)}
    </span>
  )
  return (
    <section className="relative py-10" aria-label="Formats">
      <p className="mb-6 text-center text-[13px] text-[#8E87A6]">793 conversion routes. Here are a few favourites.</p>
      <Marquee className="gap-3 py-1" duration={50}>{all.map(chip)}</Marquee>
      <Marquee className="mt-3 gap-3 py-1" duration={60} reverse>{[...all].reverse().map(chip)}</Marquee>
    </section>
  )
}

/* ---------------- how it works ---------------- */
function SectionHead({ eyebrow, title, body, dark, center = true }: { eyebrow: string; title: ReactNode; body?: ReactNode; dark?: boolean; center?: boolean }) {
  return (
    <Rise className={cn('max-w-[720px]', center && 'mx-auto text-center')}>
      <Eyebrow dark={dark}>{eyebrow}</Eyebrow>
      <h2 className={cn('p-display mb-0 mt-5 text-[40px] font-semibold leading-[1] md:text-[60px]', dark ? 'text-white' : 'text-[#1C1530]')}>{title}</h2>
      {body && <p className={cn('mx-auto mb-0 mt-5 max-w-[560px] text-[17px] leading-[1.55]', dark ? 'text-white/65' : 'text-[#5E5677]')}>{body}</p>}
    </Rise>
  )
}

const WHEELS: PSeg[][] = [SEG.convert, SEG.tools, SEG.actions]

function How() {
  return (
    <section id="how" className="relative scroll-mt-24 py-24 md:py-32">
      <div className={W}>
        <SectionHead eyebrow="How it works" title={<>One drag. Three keys.<br /><span className="text-[#8E87A6]">Every file’s next step.</span></>} />
        <div className="mt-14 grid gap-5 md:grid-cols-3">
          {product.keys.map((k, i) => (
            <Rise key={k.key} delay={i * 0.08}>
              <SpotlightCard className="rounded-[32px] p-6 pb-8" color="rgba(185,167,255,.35)" style={glass.light}>
                <div className="flex items-center justify-between">
                  <GlassKey k={k.key} label={k.name.toLowerCase()} />
                  <span className="font-mono text-[11px] text-[#8E87A6]">0{i + 1}</span>
                </div>
                <div className="relative mt-6 grid place-items-center py-2">
                  <PrismWheel segments={WHEELS[i]} size={230} hoverIndex={[0, 6, 1][i]} interactive={false} rim={false}
                              hubLabel={<Hub size={['18 MB', '2.4 MB', '1 file'][i]} small />} />
                </div>
                <h3 className="p-display mb-0 mt-6 text-[28px] font-semibold">{k.wheel}</h3>
                <p className="mb-0 mt-1.5 text-[15px] leading-[1.5] text-[#5E5677]">{k.blurb}</p>
              </SpotlightCard>
            </Rise>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ---------------- playground ---------------- */
function Playground() {
  const [mode, setMode] = useState(0)
  const [picked, setPicked] = useState<{ label: string; n: number } | null>(null)
  const keys = product.keys
  useEffect(() => {
    const on = (e: KeyboardEvent) => {
      if (e.key === 'Shift') setMode(0)
      else if (e.key === 'Meta') setMode(1)
      else if (e.key === 'Control') setMode(2)
    }
    window.addEventListener('keydown', on)
    return () => window.removeEventListener('keydown', on)
  }, [])
  useEffect(() => { if (!picked) return; const t = setTimeout(() => setPicked(null), 2600); return () => clearTimeout(t) }, [picked])
  const verb = (l: string) => mode === 0 ? [`clip.${l.toLowerCase()} is ready`, 'Saved next to clip.mov'] : mode === 1 ? [`${l} opened`, 'Your original stays untouched'] : [`${l}: done`, 'clip.mov is where you want it']
  return (
    <section id="play" className="relative scroll-mt-24 pb-24 md:pb-32">
      <div className={W}>
        <div className="relative overflow-hidden rounded-[36px] md:rounded-[48px]" style={glass.light}>
          <Mesh intensity={0.8} />
          <div className="relative grid grid-cols-[minmax(0,1fr)] items-center gap-10 p-6 sm:p-10 md:grid-cols-[minmax(0,1fr)_auto] md:p-14">
            <div>
              <Eyebrow>Playground</Eyebrow>
              <h2 className="p-display mb-0 mt-5 text-[38px] font-semibold leading-[1] md:text-[52px]">Go on, give it a spin.</h2>
              <p className="mb-0 mt-4 max-w-[420px] text-[16px] leading-[1.55] text-[#5E5677]">
                Hover a wedge and click. Or press <b className="font-semibold text-[#1C1530]">⇧</b>, <b className="font-semibold text-[#1C1530]">⌘</b> or <b className="font-semibold text-[#1C1530]">⌃</b> on your keyboard to swap wheels, just like in the app.
              </p>
              <div className="mt-7 inline-flex rounded-full p-1" style={glass.thin} role="tablist">
                {keys.map((k, i) => (
                  <button key={k.key} role="tab" aria-selected={mode === i} onClick={() => setMode(i)}
                    className={cn('p-focus relative whitespace-nowrap rounded-full px-3.5 py-2 text-[13.5px] font-medium transition-[background,color] duration-300 sm:px-4', mode === i ? 'text-white' : 'text-[#5E5677] hover:text-[#1C1530]')}
                    style={mode === i ? { background: P.plum, boxShadow: '0 6px 16px -6px rgba(107,78,255,.6)' } : undefined}>
                    <span className="relative">{k.key} {k.wheel}</span>
                  </button>
                ))}
              </div>
              <div className="mt-6 h-[68px]">
                <AnimatePresence mode="wait">
                  {picked && (
                    <motion.div key={picked.n} initial={{ opacity: 0, y: 10, filter: 'blur(6px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0, y: -8 }}>
                      <Toast title={verb(picked.label)[0]} body={verb(picked.label)[1]} action="Show" />
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </div>
            <div className="mx-auto w-full max-w-[380px] md:w-[380px]">
              <Scaled w={380} h={380}>
                <PrismWheel key={mode} segments={WHEELS[mode]} size={380}
                  hubLabel={<Hub size={['18.4 MB', '18.4 MB', '1 file'][mode]} name="clip.mov" />}
                  onPick={(s) => setPicked({ label: s.label, n: Date.now() })} />
              </Scaled>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ---------------- bento ---------------- */
function Tile({ children, className, title, body, icon }: { children?: ReactNode; className?: string; title: string; body: string; icon: ReactNode }) {
  return (
    <Rise className={className}>
      <SpotlightCard className="flex h-full flex-col rounded-[30px] p-6" color="rgba(255,107,139,.18)" style={glass.light}>
        <div className="relative h-[190px] shrink-0">{children}</div>
        <div className="mt-5 flex items-center gap-2 text-[#1C1530]">
          <span className="grid size-7 place-items-center rounded-full bg-white shadow-[0_2px_8px_-2px_rgba(44,30,90,.3)]">{icon}</span>
          <h3 className="p-display m-0 text-[22px] font-semibold">{title}</h3>
        </div>
        <p className="mb-0 mt-2 text-[14.5px] leading-[1.5] text-[#5E5677]">{body}</p>
      </SpotlightCard>
    </Rise>
  )
}

function Bento() {
  const f = product.features
  return (
    <section id="features" className="relative scroll-mt-24 py-24 md:py-32">
      <div className={W}>
        <SectionHead eyebrow="Features" title={<>Small app.<br />Surprisingly deep.</>} body="Six things anyfmt does, each one a drag away." />
        <div className="mt-14 grid gap-4 md:grid-cols-6">
          <Tile className="md:col-span-4" title={f[0].title} body={f[0].body} icon={<Layers size={14} />}>
            <div className="relative flex h-full flex-col justify-center gap-3 overflow-hidden">
              <div className="p-display text-[88px] font-semibold leading-[.8] md:text-[120px]"><span className="p-iris-text"><Ticker value="793" /></span></div>
              <div className="flex flex-wrap gap-1.5">
                {product.conversions.slice(0, 9).map((c) => <span key={c} className="rounded-full bg-white/70 px-2.5 py-1 font-mono text-[11px] text-[#3A3152] shadow-[inset_0_0_0_1px_rgba(255,255,255,.9)]">{c}</span>)}
              </div>
            </div>
          </Tile>
          <Tile className="md:col-span-2" title={f[1].title} body={f[1].body} icon={<Sparkles size={14} />}>
            <div className="grid h-full place-items-center"><PrismWheel segments={SEG.tools} size={190} hoverIndex={0} interactive={false} rim={false} hubLabel={<Hub size="26" small />} /></div>
          </Tile>
          <Tile className="md:col-span-2" title={f[2].title} body={f[2].body} icon={<ArrowUpRight size={14} />}>
            <div className="relative h-full"><div className="absolute left-1/2 top-0 origin-top -translate-x-1/2 scale-[.56]"><FloatShelf /></div></div>
          </Tile>
          <Tile className="md:col-span-2" title={f[3].title} body={f[3].body} icon={<Check size={14} />}>
            <div className="flex h-full flex-col justify-center gap-2">
              {[['GIF · 15 fps', '4.1 MB', true], ['JPG · 80 %', '0.9 MB', false], ['MP4 · 720p', '6.0 MB', false]].map(([l, s, on]) => (
                <div key={l as string} className={cn('flex items-center justify-between rounded-full px-4 py-2.5 text-[13.5px] font-medium', on ? 'text-[#1C1530]' : 'text-[#3A3152]')}
                     style={on ? { background: `linear-gradient(120deg, ${P.coral}, ${P.lilac} 60%, #8FD1F4)`, boxShadow: '0 10px 24px -10px rgba(255,107,139,.6)' } : glass.thin}>
                  <span>{l}</span><span className="font-mono text-[11.5px] opacity-75">{s}</span>
                </div>
              ))}
            </div>
          </Tile>
          <Tile className="md:col-span-2" title={f[4].title} body={f[4].body} icon={<Bot size={14} />}>
            <div className="flex h-full items-center">
              <pre className="m-0 w-full overflow-hidden rounded-[18px] p-4 font-mono text-[11.5px] leading-[1.7] text-white/85" style={{ background: P.plum, boxShadow: 'inset 0 1px 0 rgba(255,255,255,.12)' }}>
                <span className="text-[#5EE7DF]">$</span> anyfmt convert clip.mov \{'\n'}  --to gif --json{'\n'}<span className="text-white/45">{'{"event":"done", …}'}</span>
              </pre>
            </div>
          </Tile>
          <Rise className="md:col-span-6">
            <SpotlightCard className="grid overflow-hidden rounded-[30px] md:grid-cols-[1.1fr_1fr]" color="rgba(94,231,223,.2)" style={glass.light}>
              <div className="relative grid h-[260px] place-items-center overflow-hidden md:h-[300px]">
                <Mesh intensity={0.6} />
                <FormatRing size={230} thickness={1.5} className="left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" />
                <FormatRing size={330} thickness={1} bloom={false} className="left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 opacity-40" speed="p-spin-rev" />
                <div className="relative text-center">
                  <div className="p-display text-[96px] font-semibold leading-none">0</div>
                  <div className="mt-1 text-[13px] text-[#5E5677]">network calls unless you ask</div>
                </div>
              </div>
              <div className="flex flex-col justify-center p-6 md:p-10">
                <div className="flex items-center gap-2">
                  <span className="grid size-7 place-items-center rounded-full bg-white shadow-[0_2px_8px_-2px_rgba(44,30,90,.3)]"><Lock size={14} /></span>
                  <h3 className="p-display m-0 text-[22px] font-semibold">{f[5].title}</h3>
                </div>
                <p className="mb-0 mt-2 max-w-[420px] text-[14.5px] leading-[1.5] text-[#5E5677]">{f[5].body}</p>
                <div className="mt-5 flex flex-wrap gap-2">
                  {['No account', 'No upload', 'No telemetry'].map((t) => (
                    <span key={t} className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-[12.5px] font-medium text-[#3A3152]" style={glass.thin}><Check size={12} strokeWidth={3} className="text-[#2FBF9B]" />{t}</span>
                  ))}
                </div>
              </div>
            </SpotlightCard>
          </Rise>
        </div>
      </div>
    </section>
  )
}

/* ---------------- stats ---------------- */
function Stats() {
  return (
    <section className="relative py-10">
      <div className={cn(W, 'grid grid-cols-2 gap-4 md:grid-cols-4')}>
        {product.stats.map((s, i) => (
          <Rise key={s.label} delay={i * 0.06}>
            <div className="rounded-[28px] p-6" style={glass.light}>
              <div className="p-display whitespace-nowrap text-[40px] font-semibold leading-none sm:text-[48px] md:text-[64px]"><Ticker value={s.value} /></div>
              <div className="mt-3 text-[14px] leading-[1.4] text-[#5E5677]">{s.label}</div>
            </div>
          </Rise>
        ))}
      </div>
    </section>
  )
}

/* ---------------- night: privacy + agents ---------------- */
function Night() {
  const lines: [string, string][] = [
    ['p', 'anyfmt convert clip.mov --to gif --json'],
    ['o', '{"event":"start","input":"clip.mov","route":["mov","gif"]}'],
    ['o', '{"event":"progress","pct":0.42}'],
    ['o', '{"event":"progress","pct":0.91}'],
    ['d', '{"event":"done","output":"clip.gif","bytes":4301817}'],
  ]
  return (
    <section className="relative px-3 py-6 md:px-5">
      <div className="relative overflow-hidden rounded-[40px] md:rounded-[56px]" style={{ background: P.night }}>
        <Mesh dark intensity={0.9} />
        <div className="p-grain absolute inset-0 opacity-20 mix-blend-overlay" />
        {/* privacy */}
        <div className={cn(W, 'relative py-24 md:py-32')}>
          <div className="grid grid-cols-[minmax(0,1fr)] items-center gap-14 md:grid-cols-2">
            <div>
              <SectionHead dark center={false} eyebrow="Private by default" title={<>Nothing leaves<br />your Mac.</>}
                body="Everything runs on your Mac. No account, no upload, no telemetry. Pro cloud is opt-in, and anyfmt asks before a single byte leaves." />
              <ul className="mb-0 mt-8 grid list-none gap-3 p-0 text-[15px] text-white/80 sm:grid-cols-2">
                {['No account to make', 'No upload, ever', 'No telemetry', 'AGPL source you can read'].map((t) => (
                  <li key={t} className="flex items-center gap-2.5"><span className="grid size-5 place-items-center rounded-full" style={{ background: IRIS }}><Check size={11} strokeWidth={3} className="text-[#1C1530]" /></span>{t}</li>
                ))}
              </ul>
            </div>
            <div className="relative mx-auto grid size-[300px] place-items-center sm:size-[400px]">
              <FormatRing size="100%" thickness={1.5} />
              <FormatRing size="72%" thickness={1} bloom={false} className="opacity-50" speed="p-spin-rev" />
              <div className="relative grid size-[150px] place-items-center rounded-full" style={glass.dark}>
                <ShieldCheck size={46} strokeWidth={1.4} className="text-white" />
              </div>
              <div className="absolute left-0 top-[18%] rounded-full px-3 py-1.5 text-[12px] text-white/85 sm:-left-6" style={glass.dark}>beach.heic → JPG · local</div>
              <div className="absolute bottom-[14%] right-0 rounded-full px-3 py-1.5 text-[12px] text-white/85 sm:-right-4" style={glass.dark}>0 bytes sent</div>
            </div>
          </div>
        </div>
        {/* agents */}
        <div id="agents" className={cn(W, 'relative scroll-mt-24 pb-24 md:pb-32')}>
          <div className="grid grid-cols-[minmax(0,1fr)] items-center gap-12 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]">
            <Rise className="order-2 md:order-1">
              <div className="overflow-hidden rounded-[24px]" style={glass.dark}>
                <div className="flex items-center gap-2 border-b border-white/10 px-4 py-3">
                  {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}
                  <span className="ml-3 font-mono text-[11.5px] text-white/45">~/Desktop — zsh</span>
                </div>
                <pre className="m-0 overflow-x-auto p-5 font-mono text-[12px] leading-[1.9] text-white/80 md:text-[13px]">
                  {lines.map(([t, l], i) => (
                    <div key={i} className="whitespace-pre">
                      {t === 'p' ? <><span className="text-[#5EE7DF]">❯ </span><span className="text-white">{l}</span></> : <span className={t === 'd' ? 'text-[#FFB3C4]' : 'text-white/50'}>{l}</span>}
                    </div>
                  ))}
                  <div className="mt-2"><span className="text-[#5EE7DF]">❯ </span><span className="inline-block h-[1.1em] w-[.55em] translate-y-[2px] bg-white/70" /></div>
                </pre>
              </div>
            </Rise>
            <div className="order-1 md:order-2">
              <SectionHead dark center={false} eyebrow="For agents" title={<>Your agent<br />can drag too.</>}
                body="A real CLI with JSON and NDJSON progress, plus an MCP server. Claude can convert your files, locally." />
              <div className="mt-7 flex flex-wrap gap-2">
                {['anyfmt convert', 'anyfmt tools', '--json', '--ndjson', 'MCP server'].map((t) => (
                  <span key={t} className="rounded-full px-3 py-1.5 font-mono text-[12px] text-white/80" style={glass.dark}>{t}</span>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ---------------- pricing ---------------- */
function Pricing() {
  return (
    <section id="pricing" className="relative scroll-mt-24 py-24 md:py-32">
      <div className={W}>
        <SectionHead eyebrow="Pricing" title={<>Free where it counts.</>} body={product.licence} />
        <div className="mx-auto mt-14 grid max-w-[880px] gap-5 md:grid-cols-2">
          {product.pricing.map((p, i) => {
            const pro = i === 1
            return (
              <Rise key={p.name} delay={i * 0.08}>
                <div className="relative h-full overflow-hidden rounded-[34px] p-7 md:p-8" style={pro ? { ...glass.light, background: 'linear-gradient(160deg, rgba(255,227,234,.9), rgba(237,230,255,.85) 50%, rgba(221,248,246,.9))' } : glass.light}>
                  {pro && <div className="absolute -right-24 -top-24"><FormatRing size={260} thickness={1.5} className="relative" /></div>}
                  <div className="relative flex items-center justify-between">
                    <h3 className="m-0 text-[17px] font-semibold">{p.name}</h3>
                    {pro ? <span className="rounded-full bg-white px-2.5 py-1 text-[11px] font-semibold text-[#6B4EFF] shadow-sm">Optional</span>
                         : <span className="rounded-full bg-[#1C1530] px-2.5 py-1 text-[11px] font-semibold text-white">Most people</span>}
                  </div>
                  <div className="relative mt-5 flex items-baseline gap-1.5">
                    <span className="p-display text-[64px] font-semibold leading-none">{p.price}</span>
                    <span className="text-[15px] text-[#5E5677]">{p.period}</span>
                  </div>
                  <ul className="relative mb-0 mt-6 list-none space-y-3 p-0 text-[15px]">
                    {p.points.map((t) => <li key={t} className="flex items-center gap-2.5"><Check size={16} strokeWidth={2.6} className={pro ? 'text-[#6B4EFF]' : 'text-[#2FBF9B]'} />{t}</li>)}
                  </ul>
                  <div className="relative mt-8">
                    {pro ? <Pill variant="white" className="w-full">Try Pro</Pill> : <Pill className="w-full"><Download size={15} /> Download anyfmt</Pill>}
                  </div>
                </div>
              </Rise>
            )
          })}
        </div>
      </div>
    </section>
  )
}

/* ---------------- FAQ ---------------- */
const FAQ: [string, string][] = [
  ['Is anyfmt really free?', 'Yes. Every local feature, all 793 conversions, all 26 tools and 6 actions, the CLI and the MCP server. It’s open source under AGPL-3.0. Pro only adds cloud extras.'],
  ['Does anything get uploaded?', 'No. anyfmt makes 0 network calls unless you ask. Pro cloud conversions are opt-in, and anyfmt tells you before a file leaves your Mac.'],
  ['Which Macs does it run on?', 'macOS 13 or later, on Apple silicon.'],
  ['Why does it ask for Accessibility?', 'So it can notice a modifier key while you’re mid-drag. It listens for ⇧ ⌘ ⌃ during a drag, nothing else.'],
  ['Can my AI agent use it?', 'Yes. There’s a real CLI with JSON and NDJSON progress, plus an MCP server, so Claude can convert your files locally.'],
  ['What happens to my original file?', 'It stays exactly where it was. Every conversion and tool saves a new copy next to it.'],
]
function Faq() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="relative scroll-mt-24 pb-24 md:pb-32">
      <div className={cn(W, 'grid gap-10 md:grid-cols-[1fr_1.4fr]')}>
        <SectionHead center={false} eyebrow="FAQ" title={<>Good<br />questions.</>} body="Something else on your mind? The source is open, and so are the issues." />
        <div className="space-y-2.5">
          {FAQ.map(([q, a], i) => {
            const on = open === i
            return (
              <div key={q} className="overflow-hidden rounded-[22px]" style={on ? glass.light : glass.thin}>
                <button className="p-focus flex w-full items-center justify-between gap-4 px-5 py-4 text-left text-[16px] font-medium tracking-[-0.01em]" aria-expanded={on} onClick={() => setOpen(on ? null : i)}>
                  {q}
                  <motion.span initial={false} animate={{ rotate: on ? 45 : 0 }} className="grid size-7 shrink-0 place-items-center rounded-full" style={{ background: on ? P.plum : 'rgba(255,255,255,.8)', color: on ? '#fff' : P.plum }}>
                    <Plus size={14} strokeWidth={2.4} />
                  </motion.span>
                </button>
                <AnimatePresence initial={false}>
                  {on && (
                    <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}>
                      <p className="m-0 px-5 pb-5 text-[15px] leading-[1.6] text-[#5E5677]">{a}</p>
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

/* ---------------- final CTA + footer ---------------- */
function FinalCta() {
  return (
    <section className="relative px-3 md:px-5">
      <div className="relative overflow-hidden rounded-[40px] py-24 text-center md:rounded-[56px] md:py-36" style={{ background: '#F1ECFB' }}>
        <Mesh intensity={1.4} />
        <FormatRing size={620} thickness={1.5} className="left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" />
        <FormatRing size={860} thickness={1} bloom={false} className="left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 opacity-40" speed="p-spin-rev" />
        <div className="relative px-5">
          <PrismMark size={84} className="mx-auto" />
          <h2 className="p-display mx-auto mb-0 mt-8 max-w-[760px] text-[48px] font-semibold leading-[.95] md:text-[88px]">Go on.<br />Drag something.</h2>
          <p className="mx-auto mb-0 mt-5 max-w-[440px] text-[17px] text-[#3A3152]">{product.oneLiner}</p>
          <div className="mt-8 flex flex-wrap justify-center gap-3">
            <Pill size="lg"><Download size={16} /> Download for Mac</Pill>
            <Pill size="lg" variant="white" href="#agents"><Cpu size={16} /> Read the source</Pill>
          </div>
          <p className="mb-0 mt-4 text-[12.5px] text-[#5E5677]">{product.platform}</p>
        </div>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className={cn(W, 'pb-28 pt-16')}>
      <div className="flex flex-col justify-between gap-10 md:flex-row">
        <div className="max-w-[320px]">
          <Lockup size={24} />
          <p className="mb-0 mt-4 text-[14px] leading-[1.55] text-[#5E5677]">{product.oneLiner}</p>
        </div>
        <div className="grid grid-cols-2 gap-10 text-[14px] sm:grid-cols-3">
          {[['Product', ['How it works', 'Features', 'Pricing', 'Changelog']], ['Developers', ['CLI', 'MCP server', 'Source code', 'Issues']], ['About', ['Privacy', 'Licence', 'Press kit']]].map(([h, ls]) => (
            <div key={h as string}>
              <div className="mb-3 text-[12px] font-medium text-[#8E87A6]">{h}</div>
              <ul className="m-0 list-none space-y-2 p-0">{(ls as string[]).map((l) => <li key={l}><a href="#top" className="p-focus rounded text-[#3A3152] hover:text-[#1C1530]">{l}</a></li>)}</ul>
            </div>
          ))}
        </div>
      </div>
      <div className="mt-14 flex flex-col justify-between gap-2 border-t border-[#1C1530]/10 pt-6 text-[12.5px] text-[#8E87A6] sm:flex-row">
        <span>Open source · AGPL-3.0 · Made for the Mac</span>
        <span>No cookies were harmed in the making of this page.</span>
      </div>
    </footer>
  )
}

export function Landing() {
  return (
    <div className="prism min-h-screen overflow-x-clip" style={{ background: P.pearl }}>
      <PrismStyle />
      <Nav />
      <Hero />
      <Formats />
      <How />
      <Playground />
      <Bento />
      <Stats />
      <Night />
      <Pricing />
      <Faq />
      <FinalCta />
      <Footer />
    </div>
  )
}

/** Sections reused inline in the brand book. */
export const LandingParts = { Hero, How, Bento, Pricing, Playground }
