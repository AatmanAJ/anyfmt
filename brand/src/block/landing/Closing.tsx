import { AnimatePresence, motion, useInView, useReducedMotion } from 'motion/react'
import { ArrowUpRight, Check, Download, Plus } from 'lucide-react'
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { isShot, Reveal } from '../../shared/kit'
import { product } from '../../shared/product'
import { IsoBlock, IsoScene } from '../Iso'
import { Wordmark } from '../Mark'
import { DOMAIN, faqs, NAV } from './data'
import { Display, Eyebrow, Jump } from './ui'

/* ───────────────────────── Agents / CLI ───────────────────────── */

const TERM: { t: 'cmd' | 'json' | 'note'; s: string }[] = [
  { t: 'cmd', s: 'anyfmt convert clip.mov --to gif --json' },
  { t: 'json', s: '{"event":"start","input":"clip.mov","to":"gif"}' },
  { t: 'json', s: '{"event":"progress","done":0.25}' },
  { t: 'json', s: '{"event":"progress","done":0.61}' },
  { t: 'json', s: '{"event":"progress","done":1}' },
  { t: 'json', s: '{"event":"done","output":"clip.gif","bytes":4300800}' },
  { t: 'note', s: '# one JSON object per line. pipe it anywhere.' },
]

function Terminal() {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: true, margin: '-80px' })
  const reduce = useReducedMotion()
  const [shown, setShown] = useState(isShot || reduce ? TERM.length : 0)
  useEffect(() => {
    if (!inView || shown >= TERM.length) return
    const t = setTimeout(() => setShown((s) => s + 1), shown === 0 ? 300 : shown === 1 ? 700 : 380)
    return () => clearTimeout(t)
  }, [inView, shown])
  return (
    <div ref={ref} className="w-full overflow-hidden border-t-4 border-[var(--bk-orange)] bg-[var(--bk-ink)] shadow-[10px_10px_0_var(--bk-ink)]">
      <div className="flex items-center gap-2 border-b border-[var(--bk-line)] px-4 py-3">
        {[0, 1, 2].map((i) => <span key={i} className="size-2.5 bg-[var(--bk-ink-3)]" />)}
        <span className="bk-mono ml-3 text-[11px] uppercase tracking-[0.08em] text-[var(--bk-mute)]">zsh · ~/Desktop</span>
        <span className="bk-mono ml-auto bg-[var(--bk-orange)] px-1.5 text-[10.5px] font-bold text-[var(--bk-ink)]">NDJSON</span>
      </div>
      <div className="bkl-dots overflow-x-auto px-4 py-5 sm:px-6">
        <pre className="bk-mono min-h-[236px] text-[12.5px] leading-[1.95] sm:text-[13.5px]">
          {TERM.slice(0, shown).map((l, i) => (
            <div key={i}>
              {l.t === 'cmd' && <><span className="text-[var(--bk-orange)]">$ </span><span className="text-[var(--bk-cream)]">{l.s}</span></>}
              {l.t === 'json' && <span className="text-[var(--bk-lilac)]">{l.s}</span>}
              {l.t === 'note' && <span className="text-[var(--bk-mute)]">{l.s}</span>}
            </div>
          ))}
          {shown < TERM.length && <span className="bkl-caret inline-block h-[15px] w-[8px] translate-y-[3px] bg-[var(--bk-orange)]" />}
          {shown >= TERM.length && <div><span className="text-[var(--bk-orange)]">$ </span><span className="bkl-caret inline-block h-[15px] w-[8px] translate-y-[3px] bg-[var(--bk-orange)]" /></div>}
        </pre>
      </div>
    </div>
  )
}

export function Agents() {
  return (
    <section id="agents" className="mx-auto max-w-[1440px] scroll-mt-20 px-2 pt-2">
      <div className="grid gap-2 lg:grid-cols-12">
        <div className="flex flex-col gap-8 bg-[var(--bk-ink-2)] px-5 py-10 sm:px-10 sm:py-12 lg:col-span-5">
          <div>
            <Eyebrow n="04" className="mb-6 text-[var(--bk-cream)]">For agents</Eyebrow>
            <Display a="Your agents" b="drop files too." bColor="var(--bk-lilac)" className="text-[clamp(46px,5.4vw,84px)] tracking-[-0.06em]" />
            <p className="mt-5 max-w-[440px] text-[17px] leading-[1.5] text-[var(--bk-cream)]/70">{product.features[4].body}</p>
          </div>
          {/* MCP chat */}
          <div className="mt-auto grid gap-2.5">
            <div className="bk-mono flex items-center gap-2 text-[11px] uppercase tracking-[0.08em] text-[var(--bk-mute)]">
              <span className="bg-[var(--bk-pink)] px-1.5 font-bold text-[var(--bk-ink)]">MCP</span>anyfmt server, on this Mac
            </div>
            <div className="ml-auto max-w-[86%] bg-[var(--bk-lilac)] px-4 py-3 text-[15.5px] font-medium text-[var(--bk-ink)]">Make clip.mov a GIF for the README.</div>
            <div className="flex h-9 w-fit items-center gap-2 rounded-full bg-[var(--bk-cream)] pl-3 pr-4 text-[14px] font-semibold text-[var(--bk-ink)]">
              <span className="flex gap-[3px]">{[0, 1, 2].map((i) => <span key={i} className="size-[5px] rounded-full bg-[var(--bk-orange)]" style={{ opacity: 0.4 + i * 0.3 }} />)}</span>
              Thinking…
            </div>
            <div className="max-w-[86%] border-l-4 border-[var(--bk-orange)] bg-[var(--bk-ink)] px-4 py-3 text-[15.5px] text-[var(--bk-cream)]">
              Done. <span className="bk-mono text-[13.5px] text-[var(--bk-orange)]">clip.gif</span> is next to the original. Nothing left your Mac.
            </div>
          </div>
        </div>
        <div className="bk-stripe-orange relative flex min-h-[560px] flex-col justify-center gap-6 overflow-hidden px-4 py-10 sm:px-10 lg:col-span-7">
          <Reveal className="relative z-10"><Terminal /></Reveal>
          <div className="relative z-10 flex flex-wrap items-end justify-between gap-4">
            <div className="flex flex-wrap gap-2">
              {['--json', 'NDJSON progress', 'MCP server', 'runs locally'].map((t) => (
                <span key={t} className="bk-tag bg-[var(--bk-ink)] text-[var(--bk-cream)]">{t}</span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────── Pricing ───────────────────────── */

export function Pricing() {
  const [local, pro] = product.pricing
  return (
    <section id="pricing" className="mx-auto max-w-[1440px] scroll-mt-20 px-2 pt-2">
      <div className="bg-[var(--bk-cream)] px-5 py-10 text-[var(--bk-ink)] sm:px-10 sm:py-14 lg:flex lg:items-end lg:justify-between lg:gap-10">
        <div>
          <Eyebrow n="05" className="mb-6 text-[var(--bk-ink)]">Pricing</Eyebrow>
          <Display a="Local is free." b="Forever." className="text-[clamp(52px,8.4vw,128px)] tracking-[-0.06em]" />
        </div>
        <p className="mt-6 max-w-[380px] text-[18px] leading-[1.45] text-[var(--bk-ink)]/75 lg:mt-0">{product.licence} Pro only adds the things that need a server.</p>
      </div>
      <div className="mt-2 grid gap-2 lg:grid-cols-2">
        {[local, pro].map((p, i) => {
          const isPro = i === 1
          return (
            <div key={p.name} className="relative flex flex-col overflow-hidden p-5 sm:p-10"
              style={{ background: isPro ? 'var(--bk-orange)' : 'var(--bk-ink-2)', color: isPro ? 'var(--bk-ink)' : 'var(--bk-cream)' }}>
              <div className="flex items-center justify-between">
                <span className="bk-display text-[30px] font-semibold tracking-[-0.03em]">{p.name}</span>
                <span className="bk-tag" style={{ background: isPro ? 'var(--bk-ink)' : 'var(--bk-lilac)', color: isPro ? 'var(--bk-cream)' : 'var(--bk-ink)' }}>{isPro ? 'Optional' : 'Everything local'}</span>
              </div>
              <div className="mt-8 flex items-baseline gap-3">
                <span className="bk-display font-semibold leading-[0.8] tracking-[-0.075em]" style={{ fontSize: 'clamp(110px, 12vw, 190px)', color: isPro ? 'var(--bk-ink)' : 'var(--bk-lilac)' }}>{p.price}</span>
                <span className="bk-mono text-[15px] font-medium opacity-70">{p.period}</span>
              </div>
              <ul className="mt-10 grid gap-3 sm:grid-cols-2">
                {p.points.map((pt) => (
                  <li key={pt} className="flex items-start gap-3 text-[16.5px] font-medium leading-snug">
                    <span className="mt-0.5 grid size-5 shrink-0 place-items-center" style={{ background: isPro ? 'var(--bk-ink)' : 'var(--bk-orange)', color: isPro ? 'var(--bk-orange)' : 'var(--bk-ink)' }}><Check size={13} strokeWidth={3.2} /></span>
                    {pt}
                  </li>
                ))}
              </ul>
              <div className="mt-10 flex flex-wrap items-center gap-4 pt-2">
                {isPro
                  ? <a href="#" onClick={(e) => e.preventDefault()} className="bk-btn bk-btn-ink h-[54px] px-6 text-[17px]">Get Pro<ArrowUpRight size={18} /></a>
                  : <a href="#" onClick={(e) => e.preventDefault()} className="bk-btn bk-btn-orange h-[54px] px-6 text-[17px]"><Download size={18} strokeWidth={2.4} />Download free</a>}
                <span className="bk-mono text-[12px] opacity-60">{isPro ? 'cancel any time' : 'no account needed'}</span>
              </div>
            </div>
          )
        })}
      </div>
    </section>
  )
}

/* ───────────────────────── FAQ ───────────────────────── */

export function Faq() {
  const [open, setOpen] = useState<number | null>(0)
  return (
    <section id="faq" className="mx-auto max-w-[1440px] scroll-mt-20 px-2 pt-2">
      <div className="grid gap-2 lg:grid-cols-12">
        <div className="relative flex min-h-[320px] flex-col justify-between overflow-hidden bg-[var(--bk-lilac)] p-5 text-[var(--bk-ink)] sm:p-10 lg:col-span-5">
          <div>
            <Eyebrow n="06" className="mb-6 text-[var(--bk-ink)]" dot="var(--bk-ink)">FAQ</Eyebrow>
            <Display a="Asked," b="answered." bColor="var(--bk-wine-2)" className="text-[clamp(52px,6.6vw,104px)] tracking-[-0.06em]" />
          </div>
          <div className="pointer-events-none mt-6 w-[300px] self-end"><Steps /></div>
        </div>
        <div className="bg-[var(--bk-ink-2)] px-5 py-4 sm:px-10 sm:py-6 lg:col-span-7">
          {faqs.map((f, i) => {
            const on = open === i
            return (
              <div key={f.q} className="border-b border-[var(--bk-line)] last:border-0">
                <button onClick={() => setOpen(on ? null : i)} aria-expanded={on}
                  className="group flex w-full items-center justify-between gap-5 py-5 text-left">
                  <span className="bk-display text-[21px] font-semibold leading-tight tracking-[-0.025em] sm:text-[25px]" style={{ color: on ? 'var(--bk-cream)' : 'rgba(244,241,236,.82)' }}>{f.q}</span>
                  <span className="grid size-9 shrink-0 place-items-center transition-[background,box-shadow] duration-200"
                    style={{ background: on ? 'var(--bk-orange)' : 'var(--bk-ink-3)', color: on ? 'var(--bk-ink)' : 'var(--bk-cream)', boxShadow: on ? '3px 3px 0 var(--bk-wine-2)' : 'none' }}>
                    <Plus size={18} strokeWidth={2.6} className="transition-transform duration-200" style={{ transform: on ? 'rotate(45deg)' : 'none' }} />
                  </span>
                </button>
                <AnimatePresence initial={false}>
                  {on && (
                    <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.25, ease: [0.2, 0.8, 0.2, 1] }} className="overflow-hidden">
                      <p className="max-w-[620px] pb-6 pr-12 text-[16.5px] leading-[1.6] text-[var(--bk-cream)]/70">{f.a}</p>
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

function Steps() {
  return (
    <IsoScene width={300} height={200} unit={36} anchor={[0.55, 0.78]}>
      {(ctx) => (<>
        {[0, 1, 2, 3].map((i) => (
          <IsoBlock key={i} ctx={ctx} x={-2 + i * 0.9} y={-1} z={0} w={0.9} d={2.2} h={0.55 * (4 - i)} material={i === 0 ? 'orange' : i % 2 ? 'ink' : 'cream'} />
        ))}
      </>)}
    </IsoScene>
  )
}

/* ───────────────────────── Final CTA + footer ───────────────────────── */

/** One line of display type sized to exactly fill its container's width. */
function FitWord({ children, className }: { children: string; className?: string }) {
  const box = useRef<HTMLDivElement>(null), probe = useRef<HTMLSpanElement>(null)
  const [size, setSize] = useState(200)
  useLayoutEffect(() => {
    const fit = () => {
      if (!box.current || !probe.current) return
      const natural = probe.current.getBoundingClientRect().width // at 100px
      if (natural) setSize((box.current.clientWidth / natural) * 100)
    }
    fit()
    document.fonts?.ready.then(fit)
    const ro = new ResizeObserver(fit)
    if (box.current) ro.observe(box.current)
    return () => ro.disconnect()
  }, [])
  return (
    <div ref={box} className={`relative w-full ${className ?? ''}`}>
      <span ref={probe} aria-hidden className="bk-display invisible absolute left-0 top-0 whitespace-nowrap font-semibold tracking-[-0.025em]" style={{ fontSize: 100 }}>{children}</span>
      <span className="bk-display block whitespace-nowrap font-semibold leading-[0.98] tracking-[-0.025em]" style={{ fontSize: size }}>{children}</span>
    </div>
  )
}

export function FinalCta() {
  return (
    <section aria-label="Download" className="mt-2 overflow-hidden bg-[var(--bk-orange)] text-[var(--bk-ink)]">
      <div className="mx-auto flex max-w-[1440px] flex-col gap-8 px-5 pt-12 sm:px-10 sm:pt-16 lg:flex-row lg:items-end lg:justify-between">
        <div className="flex items-end gap-6">
          <span className="hidden w-[150px] shrink-0 sm:block"><MarkFill /></span>
          <div>
            <Eyebrow className="mb-5 text-[var(--bk-ink)]" dot="var(--bk-ink)">Ready when you drag</Eyebrow>
            <p className="bk-display max-w-[700px] text-[clamp(34px,4vw,58px)] font-semibold leading-[0.98] tracking-[-0.045em]">
              Stop opening apps to change a file. <span className="text-[var(--bk-wine-2)]">Hold a key instead.</span>
            </p>
          </div>
        </div>
        <div className="flex flex-col items-start gap-3 lg:items-end">
          <a href="#" onClick={(e) => e.preventDefault()} className="bk-btn bk-btn-ink h-[60px] px-7 text-[18px]"><Download size={19} strokeWidth={2.4} />Download for Mac</a>
          <span className="bk-mono text-[12px] font-medium uppercase tracking-[0.06em] opacity-70">{product.platform} · free · open source</span>
        </div>
      </div>
      <div className="mx-auto mt-10 max-w-[1440px] overflow-hidden px-3 sm:px-8" aria-label="anyfmt">
        <FitWord className="mb-[-1.2%]">anyfmt</FitWord>
      </div>
    </section>
  )
}

/** The mark redrawn at poster size: ink cubes, the lit one in cream. Same geometry as Mark. */
const CELLS: [number, number, number][] = []
for (let z = 0; z < 2; z++) for (let x = 0; x < 2; x++) for (let y = 0; y < 2; y++) CELLS.push([x, y, z])
CELLS.sort((a, b) => a[0] + a[1] + a[2] - (b[0] + b[1] + b[2]) || a[2] - b[2])
function MarkFill() {
  const g = 0.08, s = 1 - g, lift = 0.9
  return (
    <IsoScene width={250} height={280} anchor={[0.5, 0.62]} unit={55} title="anyfmt mark">
      {(ctx) => (
        <g transform="translate(0 -15)">
          {CELLS.map(([x, y, z]) => {
            const hot = x === 1 && y === 1 && z === 1
            return <IsoBlock key={`${x}${y}${z}`} ctx={ctx} x={x - 1 + g / 2 + (hot ? lift * 0.42 : 0)} y={y - 1 + g / 2 + (hot ? lift * 0.42 : 0)} z={z + (hot ? lift * 0.62 : 0)} w={s} d={s} h={s} material={hot ? 'cream' : 'ink'} />
          })}
        </g>
      )}
    </IsoScene>
  )
}

export function Footer() {
  const cols = [
    { h: 'Product', links: NAV.slice(0, 5).map((l) => ({ label: l.label, to: l.href })) },
    { h: 'Developers', links: [{ label: 'CLI', to: '#agents' }, { label: 'MCP server', to: '#agents' }, { label: 'Source (AGPL-3.0)', href: '#' }] },
    { h: 'Brand', links: [{ label: 'Brand book', href: '#/block/book' }] },
  ] as { h: string; links: { label: string; to?: string; href?: string }[] }[]
  return (
    <footer className="bg-[var(--bk-ink)] text-[var(--bk-cream)]">
      <div className="mx-auto grid max-w-[1440px] gap-10 px-5 py-14 sm:px-10 lg:grid-cols-12">
        <div className="lg:col-span-5">
          <Wordmark size={30} />
          <p className="mt-5 max-w-[360px] text-[15.5px] leading-[1.55] text-[var(--bk-cream)]/60">{product.oneLiner}</p>
        </div>
        <div className="grid grid-cols-2 gap-8 sm:grid-cols-3 lg:col-span-7">
          {cols.map((c) => (
            <div key={c.h}>
              <div className="bk-mono mb-4 text-[11px] uppercase tracking-[0.08em] text-[var(--bk-mute)]">{c.h}</div>
              <ul className="grid gap-2.5">
                {c.links.map((l) => (
                  <li key={l.label}>
                    {l.to
                      ? <Jump to={l.to} className="text-[15px] text-[var(--bk-cream)]/80 hover:text-[var(--bk-orange)]">{l.label}</Jump>
                      : <a href={l.href} className={`text-[15px] hover:text-[var(--bk-orange)] ${l.label === 'Brand book' ? 'inline-flex items-center gap-1 font-semibold text-[var(--bk-cream)]' : 'text-[var(--bk-cream)]/80'}`}>{l.label}{l.label === 'Brand book' && <ArrowUpRight size={15} />}</a>}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
      <div className="border-t border-[var(--bk-line)]">
        <div className="bk-mono mx-auto flex max-w-[1440px] flex-wrap items-center justify-between gap-3 px-5 py-5 text-[11.5px] uppercase tracking-[0.06em] text-[var(--bk-mute)] sm:px-10">
          <span>{DOMAIN}</span>
          <span>Open source · AGPL-3.0 · {product.platform}</span>
        </div>
      </div>
    </footer>
  )
}
