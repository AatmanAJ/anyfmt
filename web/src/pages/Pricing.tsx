/**
 * Pricing. Three plans built the same way, Desktop marked as the one most people want with crop
 * marks (the Crop tool's own corners). Donating sits under them, apart from the plans. Then a
 * switch that takes "your Mac" offline to show what keeps working, the full table, the API
 * calculator and the questions.
 */
import NumberFlow from '@number-flow/react'
import { Check, Cloud, Minus, WifiHigh, WifiSlash } from '@phosphor-icons/react'
import { AnimatePresence, motion } from 'motion/react'
import { useEffect, useState, type ReactNode } from 'react'
import { Accordion } from '../components/Accordion'
import { ArrowLink, RollText, SmartLink, SwapArrow } from '../components/Buttons'
import { Page } from '../components/Page'
import { Container, Eyebrow } from '../components/ui'
import catalog from '../data/catalog.json'
import { FAQ_FREE } from '../data/copy'
import { useHead } from '../lib/head'
import { EASE, SNAP } from '../lib/hooks'
import { PRICES, SITE } from '../lib/site'

type Billing = 'monthly' | 'yearly'

/* ── small parts ─────────────────────────────────────────────── */

function BillingToggle({ value, onChange }: { value: Billing; onChange: (b: Billing) => void }) {
  return (
    <div role="radiogroup" aria-label="Billing period" className="inline-grid h-10 grid-cols-2 rounded-full bg-sand-2 p-1">
      {(['monthly', 'yearly'] as const).map((b) => (
        <button key={b} type="button" role="radio" aria-checked={value === b} onClick={() => onChange(b)}
          className="relative h-8 rounded-full px-4 text-[14px] font-medium outline-none focus-visible:ring-2 focus-visible:ring-flare">
          {value === b && <motion.span layoutId="bill" className="absolute inset-0 rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,.08)]" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
          <span className="relative">{b === 'monthly' ? 'Monthly' : <span className="whitespace-nowrap">Yearly −25%</span>}</span>
        </button>
      ))}
    </div>
  )
}

/** A buy button that's honest about checkout not being open yet. */
function SoonButton({ label, tone = 'dark' }: { label: string; tone?: 'dark' | 'light' }) {
  const [said, setSaid] = useState(false)
  useEffect(() => { if (!said) return; const t = window.setTimeout(() => setSaid(false), 3200); return () => clearTimeout(t) }, [said])
  const skin = tone === 'dark' ? 'bg-ink text-white focus-visible:ring-offset-white' : 'bg-white text-ink focus-visible:ring-offset-ink'
  const dot = tone === 'dark' ? 'bg-white text-ink' : 'bg-ink text-white'
  return (
    <button type="button" onClick={() => setSaid(true)} aria-live="polite"
      className={`group relative flex h-13 w-full items-center justify-between overflow-hidden rounded-full pl-5 pr-1.5 text-[15.5px] font-medium outline-none transition-transform duration-300 active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-2 ${skin}`}>
      <span className="relative grid overflow-hidden">
        <AnimatePresence mode="popLayout" initial={false}>
          <motion.span key={String(said)} initial={{ y: 22, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -22, opacity: 0 }} transition={{ duration: 0.4, ease: EASE }} className="whitespace-nowrap text-left">
            {said ? 'Checkout opens with the first release' : <RollText>{label}</RollText>}
          </motion.span>
        </AnimatePresence>
      </span>
      <span className={`relative flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full ${dot}`}><SwapArrow /></span>
    </button>
  )
}

function LinkButton({ to, label, tone = 'dark' }: { to: string; label: string; tone?: 'dark' | 'light' }) {
  const skin = tone === 'dark' ? 'bg-ink text-white' : 'bg-white text-ink ring-1 ring-black/10'
  const dot = tone === 'dark' ? 'bg-white text-ink' : 'bg-ink text-white'
  return (
    <SmartLink to={to} className={`group flex h-13 w-full items-center justify-between rounded-full pl-5 pr-1.5 text-[15.5px] font-medium outline-none transition-transform duration-300 active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-2 ${skin}`}>
      <RollText>{label}</RollText>
      <span className={`relative flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-full ${dot}`}><SwapArrow /></span>
    </SmartLink>
  )
}

function Feature({ children, tone = 'ink' }: { children: ReactNode; tone?: 'ink' | 'white' }) {
  return (
    <li className="flex gap-3 text-[15.5px] leading-[1.45]">
      <Check size={16} weight="bold" aria-hidden className={`mt-[3px] shrink-0 ${tone === 'ink' ? 'text-ink' : 'text-white/70'}`} />
      <span className="[text-wrap:pretty]">{children}</span>
    </li>
  )
}

/* ── the three plans ─────────────────────────────────────────── */

function Plan({ name, line, price, unit, note, cta, children, aside, dark = false, className = '' }:
  { name: string; line: string; price: number; unit: string; note: ReactNode; cta: ReactNode; children: ReactNode; aside?: ReactNode; dark?: boolean; className?: string }) {
  return (
    <article className={`relative flex flex-col rounded-[28px] p-7 sm:p-8 ${dark ? 'bg-ink text-white' : 'bg-white ring-1 ring-black/[.07]'} ${className}`}>
      <div className="flex min-h-10 flex-wrap items-center justify-between gap-3">
        <h3 className="text-[22px] font-semibold tracking-[-0.025em]">{name}</h3>
        {aside}
      </div>
      <p className={`mt-1.5 min-h-[44px] text-[15px] leading-[1.45] ${dark ? 'text-white/70' : 'text-mute'}`}>{line}</p>
      <p className="mt-6 flex items-baseline gap-2">
        <span className="text-[64px] font-semibold leading-none tracking-[-0.055em] tabular-nums [--number-flow-mask-height:0.08em]"><NumberFlow value={price} format={{ style: 'currency', currency: 'USD', maximumFractionDigits: 0 }} /></span>
        <span className={`pb-0.5 text-[16px] font-medium ${dark ? 'text-white/70' : 'text-mute-2'}`}>{unit}</span>
      </p>
      <p className={`mt-2 min-h-[42px] text-[14px] leading-[1.5] ${dark ? 'text-white/70' : 'text-mute-2'}`}>{note}</p>
      <div className="mt-6">{cta}</div>
      <div className={`my-7 h-px ${dark ? 'bg-white/12' : 'bg-line'}`} />
      <ul className="flex flex-col gap-3.5">{children}</ul>
    </article>
  )
}

function Plans() {
  const [billing, setBilling] = useState<Billing>('yearly')
  const pro = billing === 'monthly' ? PRICES.pro.monthly : PRICES.pro.yearlyPerMonth
  return (
    <div className="grid gap-5 lg:gap-6">
      {/* Desktop is what the headline sells, so it gets the full width */}
      <article className="grid gap-8 rounded-[28px] bg-ink p-7 text-white sm:p-10 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:gap-14">
        <div className="flex flex-col">
          <h3 className="text-[22px] font-semibold tracking-[-0.025em]">Desktop</h3>
          <p className="mt-1.5 text-[15px] leading-[1.45] text-white/70">The signed app. Drag it into Applications and you're done.</p>
          <p className="mt-6 flex items-baseline gap-2">
            <span className="text-[64px] font-semibold leading-none tracking-[-0.055em] tabular-nums [--number-flow-mask-height:0.08em]"><NumberFlow value={PRICES.desktop.once} format={{ style: 'currency', currency: 'USD', maximumFractionDigits: 0 }} /></span>
            <span className="text-[16px] font-medium text-white/70">once</span>
          </p>
          <p className="mt-2 text-[14px] leading-[1.5] text-white/70">One payment and every future update, on up to {PRICES.desktop.macs} Macs.</p>
          <div className="mt-8 max-w-[420px] lg:mt-auto lg:pt-8"><SoonButton label="Buy Desktop" tone="light" /></div>
        </div>
        <ul className="grid content-start gap-x-8 gap-y-4 border-t border-white/12 pt-8 sm:grid-cols-2 lg:border-l lg:border-t-0 lg:pl-14 lg:pt-1">
          <Feature tone="white">Every conversion, tool and action, all offline</Feature>
          <Feature tone="white">Signed and notarized by Apple</Feature>
          <Feature tone="white">Updates install themselves</Feature>
          <Feature tone="white">The command line and MCP server, linked for you</Feature>
          <Feature tone="white">Email support from the person who wrote it</Feature>
          <Feature tone="white">14 days to change your mind, full refund</Feature>
        </ul>
      </article>

      <div className="grid gap-5 lg:grid-cols-2 lg:gap-6">
        <Plan name="Build it yourself" line="The whole app from source, for people happy to run a build." price={0} unit="free forever"
          note="AGPL-3.0, commercial use included."
          cta={<LinkButton to="/docs/self-host" label="Read the build guide" tone="light" />}>
          <Feature>All {catalog.counts.routes} routes and {catalog.counts.tools} tools</Feature>
          <Feature>Command line and MCP server</Feature>
          <Feature>Share links and sync on your own server</Feature>
          <Feature>Updates when you pull and rebuild</Feature>
        </Plan>

        <Plan name="Pro" line="Desktop, plus the features that run on our servers." price={pro} unit="a month"
          aside={<BillingToggle value={billing} onChange={setBilling} />}
          note={billing === 'yearly' ? `$${pro * 12} billed once a year. Cancel any time.` : 'Billed monthly. Cancel any time.'}
          cta={<SoonButton label="Start Pro" />}>
          <Feature>Everything in Desktop</Feature>
          <Feature>Share links with expiry, a password and a download cap</Feature>
          <Feature>Heavy video converted in the cloud while your Mac stays free</Feature>
          <Feature>Synced presets, a phone-to-Mac inbox, transcription and upscaling</Feature>
        </Plan>
      </div>
    </div>
  )
}

/* ── donate: apart from the plans ────────────────────────────── */

function Donate() {
  const [amt, setAmt] = useState<number>(PRICES.donate[1])
  return (
    <div id="donate" className="mt-6 grid scroll-mt-28 items-center gap-6 rounded-[28px] bg-white p-7 ring-1 ring-black/[.07] sm:p-8 lg:grid-cols-[minmax(0,1fr)_auto] lg:gap-10">
      <div>
        <h3 className="text-[22px] font-semibold tracking-[-0.025em]">Or just chip in</h3>
        <p className="mt-1.5 max-w-[560px] text-[15px] leading-[1.5] text-mute">A donation doesn't buy any features. It pays for the hours that go into anyfmt, and it goes straight to the person building it.</p>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <div role="radiogroup" aria-label="Amount" className="flex gap-1.5">
          {PRICES.donate.map((d) => (
            <button key={d} type="button" role="radio" aria-checked={amt === d} onClick={() => setAmt(d)}
              className={`h-12 min-w-[56px] rounded-full px-4 text-[15px] font-semibold tabular-nums outline-none transition-[background-color,color] duration-200 focus-visible:ring-2 focus-visible:ring-flare ${amt === d ? 'bg-ink text-white' : 'bg-sand-2 text-ink hover:bg-sand'}`}>${d}</button>
          ))}
        </div>
        <SmartLink to={PRICES.donateUrl}
          className="group flex h-12 items-center gap-3 rounded-full bg-ink pl-5 pr-1.5 text-[15.5px] font-medium text-white outline-none transition-transform duration-300 active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-2">
          <span className="whitespace-nowrap">Give ${amt}</span>
          <span className="relative flex h-9 w-9 items-center justify-center overflow-hidden rounded-full bg-white text-ink"><SwapArrow /></span>
        </SmartLink>
      </div>
    </div>
  )
}

/* ── offline: what keeps working without the internet ───────── */

const LOCAL = ['Every conversion, all ' + catalog.counts.routes, 'Every tool, all ' + catalog.counts.tools, 'AirDrop, Float, Copy and Move', 'Batches and presets', 'Command line and MCP server', 'Your licence check']
const CLOUD = ['Share links', 'Cloud conversions', 'Sync across Macs', 'Inbox from your phone', 'Transcription', 'Upscaling and HQ cutouts']

function WifiSwitch({ on, onChange }: { on: boolean; onChange: (v: boolean) => void }) {
  return (
    <button type="button" role="switch" aria-checked={on} onClick={() => onChange(!on)}
      className="group flex h-11 items-center gap-3 rounded-full bg-white py-1.5 pl-4 pr-1.5 text-[15px] font-medium outline-none ring-1 ring-black/10 focus-visible:ring-2 focus-visible:ring-flare">
      {on ? <WifiHigh size={18} weight="bold" aria-hidden /> : <WifiSlash size={18} weight="bold" aria-hidden />}
      Wi-Fi
      <span className={`relative h-8 w-[52px] rounded-full transition-colors duration-300 ${on ? 'bg-[#34C759]' : 'bg-black/15'}`}>
        <span className="absolute top-1 h-6 w-6 rounded-full bg-white shadow-[0_1px_3px_rgba(0,0,0,.25)] transition-[left] duration-300" style={{ left: on ? 24 : 4, transitionTimingFunction: SNAP }} />
      </span>
    </button>
  )
}

function Offline() {
  const [online, setOnline] = useState(true)
  return (
    <section className="bg-white py-24 lg:py-32">
      <Container>
        <div className="grid items-end gap-8 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
          <div>
            <Eyebrow>What stays free</Eyebrow>
            <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Nothing that runs on your Mac is behind a paywall.</h2>
          </div>
          <p className="max-w-[460px] text-[17px] leading-[1.55] text-mute lg:pb-2">Pro only covers features that need our servers, because those cost money to run. Switch off the Wi-Fi to see the difference.</p>
        </div>

        <div className="mt-14 overflow-hidden rounded-[28px] bg-sand">
          <div className="flex flex-wrap items-center justify-between gap-4 border-b border-line px-6 py-4 sm:px-8">
            <p className="text-[15px] font-medium" aria-live="polite">
              {online ? 'Online. Everything is available.' : `Offline. All ${LOCAL.length} Mac features still work.`}
            </p>
            <WifiSwitch on={online} onChange={setOnline} />
          </div>
          <div className="grid md:grid-cols-2">
            <div className="p-6 sm:p-8">
              <p className="text-[15px] font-semibold">On your Mac <span className="font-normal text-mute-2">· every plan, including the free build</span></p>
              <ul className="mt-5 divide-y divide-line border-y border-line">
                {LOCAL.map((t) => (
                  <li key={t} className="flex items-center justify-between gap-4 py-3.5 text-[16px]">
                    <span>{t}</span>
                    <span className="flex items-center gap-1.5 text-[13px] font-medium text-ink"><Check size={14} weight="bold" aria-hidden />Works</span>
                  </li>
                ))}
              </ul>
            </div>
            <div className={`border-t border-line p-6 transition-colors duration-500 sm:p-8 md:border-l md:border-t-0 ${online ? '' : 'bg-sand-2'}`}>
              <p className="flex items-center gap-2 text-[15px] font-semibold"><Cloud size={16} weight="fill" className="text-flare" aria-hidden />On our servers <span className="font-normal text-mute-2">· Pro</span></p>
              <ul className="mt-5 divide-y divide-line border-y border-line">
                {CLOUD.map((t, i) => (
                  <li key={t} className="flex items-center justify-between gap-4 py-3.5 text-[16px]">
                    <span className={`transition-opacity duration-500 ${online ? '' : 'opacity-40'}`} style={{ transitionDelay: `${i * 40}ms` }}>{t}</span>
                    <AnimatePresence mode="wait" initial={false}>
                      <motion.span key={String(online)} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.25, delay: i * 0.04 }}
                        className={`text-[13px] font-medium ${online ? 'text-ink' : 'text-mute-2'}`}>{online ? 'Available' : 'Waiting for Wi-Fi'}</motion.span>
                    </AnimatePresence>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
        <p className="mt-6 max-w-[680px] text-[15px] leading-[1.55] text-mute-2">In the app, anything that would leave your Mac carries a small cloud glyph, and the first upload always names the server it's going to. A licence key never limits anything local.</p>
      </Container>
    </section>
  )
}

/* ── full table ─────────────────────────────────────────────── */

type Cell = boolean | string
const ROWS: { group: string; rows: [string, Cell, Cell, Cell][] }[] = [
  { group: 'On your Mac', rows: [
    [`${catalog.counts.routes} conversion routes`, true, true, true],
    [`${catalog.counts.tools} editing tools`, true, true, true],
    ['Actions and the Float shelf', true, true, true],
    ['Command line and MCP server', true, true, true],
    ['Commercial use', true, true, true],
  ] },
  { group: 'The app', rows: [
    ['How you get it', 'Build from source', 'Signed download', 'Signed download'],
    ['Updates', 'Pull and rebuild', 'Automatic', 'Automatic'],
    ['Macs', 'Unlimited', `Up to ${PRICES.desktop.macs}`, `Up to ${PRICES.desktop.macs}`],
    ['Email support', false, true, 'Priority'],
  ] },
  { group: 'On our servers', rows: [
    ['Share links', 'Your server', false, true],
    ['Cloud conversions', 'Your server', false, true],
    ['Sync across Macs', 'Your server', false, true],
    ['Inbox from phone or browser', 'Your server', false, true],
    ['Transcribe, upscale, HQ cutouts', 'Your GPU', false, true],
  ] },
]
const PLANS: [string, string][] = [['Build it yourself', '$0'], ['Desktop', `$${PRICES.desktop.once} once`], ['Pro', `from $${PRICES.pro.yearlyPerMonth} a month`]]

function CellView({ v }: { v: Cell }) {
  if (v === true) return <><Check size={18} weight="bold" aria-hidden /><span className="sr-only">Included</span></>
  if (v === false) return <><Minus size={16} weight="bold" className="text-mute-3" aria-hidden /><span className="sr-only">Not included</span></>
  return <span className="text-[15px]">{v}</span>
}

function Table() {
  const [col, setCol] = useState(1)
  return (
    <section className="bg-sand py-24 lg:py-32">
      <Container>
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <Eyebrow>Side by side</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Every plan, line by line.</h2>
          </div>
          {/* on phones, one plan at a time */}
          <div role="tablist" aria-label="Plan" className="inline-flex rounded-full bg-white p-1 ring-1 ring-black/10 md:hidden">
            {PLANS.map(([p], i) => (
              <button key={p} type="button" role="tab" aria-selected={col === i} onClick={() => setCol(i)} className={`h-9 rounded-full px-3.5 text-[14px] font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-flare ${col === i ? 'bg-ink text-white' : ''}`}>
                {i === 0 ? 'Free' : p}
              </button>
            ))}
          </div>
        </div>
        <div className="mt-12 overflow-hidden rounded-[28px] bg-white">
          <table className="w-full border-collapse text-left md:table-fixed">
                        <thead>
              <tr className="border-b border-line">
                <th scope="col" className="w-[58%] p-5 align-bottom text-[14px] font-medium text-mute-2 sm:px-7 sm:py-6 md:w-[34%]"><span className="sr-only">Feature</span></th>
                {PLANS.map(([p, price], i) => (
                  <th key={p} scope="col" className={`p-5 align-bottom sm:px-7 sm:py-6 ${i !== col ? 'hidden md:table-cell' : ''}`}>
                    <span className="block text-[17px] font-semibold tracking-[-0.02em]">{p}</span>
                    <span className="mt-0.5 block text-[14px] font-normal text-mute-2">{price}</span>
                  </th>
                ))}
              </tr>
            </thead>
            {ROWS.map((g) => (
              <tbody key={g.group}>
                <tr><th colSpan={4} scope="colgroup" className="px-5 pb-3 pt-9 text-[14px] font-semibold sm:px-7"><span className="flex items-center gap-2.5"><span className="h-2 w-2 bg-ink" />{g.group}</span></th></tr>
                {g.rows.map(([label, ...cells]) => (
                  <tr key={label} className="border-t border-line">
                    <th scope="row" className="px-5 py-4 text-[15.5px] font-normal text-mute sm:px-7">{label}</th>
                    {cells.map((c, i) => <td key={i} className={`px-5 py-4 sm:px-7 ${i !== col ? 'hidden md:table-cell' : ''}`}><CellView v={c} /></td>)}
                  </tr>
                ))}
              </tbody>
            ))}
          </table>
        </div>
      </Container>
    </section>
  )
}

/* ── API calculator ─────────────────────────────────────────── */

const STEPS = [0, 100, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000]
const MIN_STEPS = [0, 10, 30, 60, 120, 300, 600, 1200, 3000, 6000]

function Slider({ label, steps, value, onChange, unit }: { label: string; steps: number[]; value: number; onChange: (i: number) => void; unit: string }) {
  const pct = (value / (steps.length - 1)) * 100
  return (
    <label className="block">
      <span className="flex items-baseline justify-between gap-4">
        <span className="text-[15px] font-medium text-white/70">{label}</span>
        <span className="text-[22px] font-semibold tabular-nums tracking-[-0.02em] text-white"><NumberFlow value={steps[value]} /> <span className="text-[14px] font-medium text-white/60">{unit}</span></span>
      </span>
      <span className="relative mt-4 block h-10">
        <input type="range" min={0} max={steps.length - 1} step={1} value={value} onChange={(e) => onChange(Number(e.target.value))}
          className="peer absolute inset-0 z-10 h-full w-full cursor-pointer opacity-0" aria-valuetext={`${steps[value]} ${unit}`} />
        <span className="pointer-events-none absolute inset-x-0 top-1/2 h-1.5 -translate-y-1/2 rounded-full bg-white/12" />
        <span className="pointer-events-none absolute left-0 top-1/2 h-1.5 -translate-y-1/2 rounded-full bg-flare" style={{ width: `${pct}%` }} />
        <span className="pointer-events-none absolute top-1/2 h-6 w-6 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white shadow-[0_2px_8px_rgba(0,0,0,.4)] peer-focus-visible:ring-4 peer-focus-visible:ring-flare/50" style={{ left: `${pct}%` }} />
      </span>
    </label>
  )
}

function ApiMeter() {
  const [c, setC] = useState(4)
  const [m, setM] = useState(3)
  const conv = STEPS[c] * PRICES.api.perConversion
  const mins = MIN_STEPS[m] * PRICES.api.perMediaMinute
  const total = Math.round((conv + mins) * 100) / 100
  const cents = (n: number) => `${Math.round(n * 100)}¢`
  return (
    <section className="bg-white">
      <div className="mx-auto max-w-[1440px] px-5 sm:px-10 lg:px-14">
      <div className="rounded-[28px] bg-night text-white">
        <div className="mx-auto grid max-w-[1440px] gap-12 px-6 py-16 sm:px-12 lg:grid-cols-[1fr_1.1fr] lg:py-24">
          <div>
            <Eyebrow tone="white">HTTP API</Eyebrow>
            <h2 className="mt-6 max-w-[560px] text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em] [text-wrap:balance]">The API is {cents(PRICES.api.perConversion)} a conversion, with no plan to buy.</h2>
            <p className="mt-6 max-w-[460px] text-[17px] leading-[1.55] text-white/70">
              The same routes and options as the app, over HTTP. Audio and video cost {cents(PRICES.api.perMediaMinute)} a minute. A conversion that fails costs nothing.
            </p>
            <p className="mt-6 inline-flex items-center gap-2 rounded-full bg-white/10 px-3.5 py-2 text-[14px] text-white/80"><span className="h-1.5 w-1.5 shrink-0 rounded-full bg-volt" />In preview: the contract and SDK are ready, the hosted API isn't live yet.</p>
            <div className="mt-8"><ArrowLink to="/docs/api" className="text-white">Read the API docs</ArrowLink></div>
          </div>
          <div className="rounded-[24px] bg-white/[0.06] p-6 ring-1 ring-white/10 sm:p-8">
            <div className="space-y-8">
              <Slider label="Conversions a month" steps={STEPS} value={c} onChange={setC} unit="files" />
              <Slider label="Audio and video a month" steps={MIN_STEPS} value={m} onChange={setM} unit="minutes" />
            </div>
            <div className="mt-10 flex flex-wrap items-end justify-between gap-4 border-t border-white/10 pt-6">
              <div className="text-[14px] leading-[1.7] tabular-nums text-white/65">
                <p>{STEPS[c].toLocaleString('en-US')} × {cents(PRICES.api.perConversion)} = ${conv.toFixed(2)}</p>
                <p>{MIN_STEPS[m].toLocaleString('en-US')} min × {cents(PRICES.api.perMediaMinute)} = ${mins.toFixed(2)}</p>
              </div>
              <p className="text-right">
                <span className="block text-[14px] text-white/65">You'd pay, a month</span>
                <span className="text-[clamp(40px,5vw,64px)] font-semibold leading-none tracking-[-0.05em]">$<NumberFlow value={total} format={{ minimumFractionDigits: 2, maximumFractionDigits: 2 }} /></span>
              </p>
            </div>
          </div>
        </div>
      </div>
      </div>
    </section>
  )
}

/* ── FAQ ────────────────────────────────────────────────────── */

const FAQ: [string, string][] = [
  FAQ_FREE,
  ['Why pay for something open source?', `You don't have to. The Desktop licence pays for what building it yourself skips: a build signed and notarized by Apple, updates that arrive on their own, and someone answering your email. It also funds the work.`],
  ['Can I use anyfmt at work?', 'Yes, on every plan. Commercial use is included. The AGPL only asks something of you if you distribute a modified anyfmt or run a modified server for other people: then you share your changes.'],
  ['What happens if I stop paying for Pro?', 'Everything on your Mac keeps working exactly as before. Share links you made expire on their normal schedule, and sync stops. You keep your Desktop licence.'],
  ['Do you offer refunds?', 'Yes. If anyfmt isn\'t for you, email us within 14 days of buying and we\'ll refund you in full.'],
  ['Do you have team plans?', `Pro covers one person. For seats, shared links and a custom domain for a team, email ${SITE.email.sales}.`],
]

export default function Pricing() {
  useHead({
    title: 'Pricing',
    description: `anyfmt is $${PRICES.desktop.once} once for the signed Mac app. The source is free to build, Pro adds cloud features from $${PRICES.pro.yearlyPerMonth} a month, and you can donate any amount.`,
    path: '/pricing',
    jsonLd: [
      {
        '@context': 'https://schema.org', '@type': 'Product', name: 'anyfmt', description: SITE.description, brand: { '@type': 'Brand', name: 'anyfmt' },
        offers: [
          { '@type': 'Offer', name: 'Build it yourself', price: '0', priceCurrency: 'USD' },
          { '@type': 'Offer', name: 'Desktop licence', price: String(PRICES.desktop.once), priceCurrency: 'USD' },
          { '@type': 'Offer', name: 'Pro (monthly)', price: String(PRICES.pro.monthly), priceCurrency: 'USD' },
        ],
      },
      { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: FAQ.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
    ],
  })
  return (
    <Page>
      <section className="overflow-x-clip bg-sand pb-20 pt-36 lg:pb-28 lg:pt-44">
        <Container>
          <Eyebrow>Pricing</Eyebrow>
          <h1 className="mt-6 text-[clamp(48px,7vw,112px)] font-semibold leading-[0.95] tracking-[-0.055em]">anyfmt is ${PRICES.desktop.once}, once.</h1>
          <p className="mt-6 max-w-[620px] text-[clamp(17px,1.4vw,20px)] leading-[1.5] text-mute">That's the signed app with every future update, on up to {PRICES.desktop.macs} Macs. The source code is free to build yourself, and Pro adds the features that run on our servers.</p>
          <div className="mt-16"><Plans /></div>
          <Donate />
          <p className="mt-6 text-[14px] text-mute-2">Checkout opens with the first public release; the buttons will say so until then. Prices in US dollars, tax may apply.</p>
        </Container>
      </section>
      <Offline />
      <Table />
      <ApiMeter />
      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div className="lg:sticky lg:top-28 lg:self-start">
            <Eyebrow>Questions</Eyebrow>
            <h2 className="mt-6 text-[clamp(36px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Paying for anyfmt, and what happens if you stop.</h2>
          </div>
          <Accordion items={FAQ} />
        </Container>
      </section>
    </Page>
  )
}
