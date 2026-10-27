/**
 * Pricing: four ways in, each card its own object. Self-host is a terminal, Desktop is a licence
 * ticket, Pro is a slab of fluted ember glass, Donate is a tip jar. Then the line between what
 * runs on your Mac (free) and what runs on our servers (paid), a full table, and an API meter.
 */
import NumberFlow from '@number-flow/react'
import { Check, Cloud, Heart, Minus } from '@phosphor-icons/react'
import { AnimatePresence, motion, useInView } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Accordion } from '../components/Accordion'
import { ArrowLink, DownloadButton, RollText, SwapArrow, SmartLink } from '../components/Buttons'
import { Flutes } from '../components/Flutes'
import { Page } from '../components/Page'
import { Container, Eyebrow } from '../components/ui'
import catalog from '../data/catalog.json'
import { FAQ_FREE } from '../data/copy'
import { useHead } from '../lib/head'
import { EASE, prefersReducedMotion, SNAP } from '../lib/hooks'
import { PRICES, SITE } from '../lib/site'

type Billing = 'monthly' | 'yearly'

/* ── small parts ─────────────────────────────────────────────── */

function BillingToggle({ value, onChange }: { value: Billing; onChange: (b: Billing) => void }) {
  return (
    <div role="radiogroup" aria-label="Billing period" className="inline-flex h-12 items-center rounded-full bg-white p-1 ring-1 ring-black/10">
      {(['monthly', 'yearly'] as const).map((b) => (
        <button key={b} type="button" role="radio" aria-checked={value === b} onClick={() => onChange(b)}
          className="relative h-10 rounded-full px-5 text-[15px] font-medium outline-none focus-visible:ring-2 focus-visible:ring-flare">
          {value === b && <motion.span layoutId="bill" className="absolute inset-0 rounded-full bg-ink" transition={{ type: 'spring', stiffness: 500, damping: 38 }} />}
          <span className={`relative flex items-center gap-2 transition-colors duration-300 ${value === b ? 'text-white' : 'text-ink'}`}>
            {b === 'monthly' ? 'Monthly' : 'Yearly'}
            {b === 'yearly' && <span className={`rounded-full px-1.5 py-0.5 text-[11px] font-semibold ${value === b ? 'bg-volt text-ink' : 'bg-sand-2 text-ink'}`}>−25%</span>}
          </span>
        </button>
      ))}
    </div>
  )
}

/** A buy button that's honest about checkout not being open yet. */
function SoonButton({ label, tone = 'dark' }: { label: string; tone?: 'dark' | 'light' | 'volt' }) {
  const [said, setSaid] = useState(false)
  useEffect(() => { if (!said) return; const t = window.setTimeout(() => setSaid(false), 3200); return () => clearTimeout(t) }, [said])
  const skin = tone === 'dark' ? 'bg-ink text-white' : tone === 'light' ? 'bg-white text-ink' : 'bg-volt text-ink'
  const dot = tone === 'dark' ? 'bg-white text-ink' : 'bg-ink text-white'
  return (
    <button type="button" onClick={() => setSaid(true)} aria-live="polite"
      className={`group relative flex h-14 w-full items-center justify-between overflow-hidden rounded-full pl-6 pr-2 text-[16px] font-medium outline-none transition-transform duration-300 active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-2 ${skin}`}>
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

function Feature({ children, tone = 'ink' }: { children: ReactNode; tone?: 'ink' | 'white' }) {
  return (
    <li className="flex gap-3 text-[15.5px] leading-[1.45]">
      <span className={`mt-[3px] flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded-full ${tone === 'ink' ? 'bg-ink text-white' : 'bg-white text-ink'}`}><Check size={11} weight="bold" /></span>
      <span>{children}</span>
    </li>
  )
}

/* ── Self-host: a terminal that types its own install ───────── */

const SH = [
  ['$ ', 'git clone …/aiwithaj/anyfmt'],
  ['$ ', 'make engines build'],
  ['', '✓ anyfmt.app · 63 MB'],
  ['$ ', 'docker compose up -d'],
  ['', '✓ api · worker · db · s3'],
] as const

function Terminal() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.5 })
  const total = SH.reduce((n, [, t]) => n + t.length, 0)
  const [typed, setTyped] = useState(0)
  useEffect(() => {
    if (!seen) return
    if (prefersReducedMotion()) { setTyped(total); return }
    let i = 0
    const id = window.setInterval(() => { i += 2; setTyped(Math.min(i, total)); if (i >= total) clearInterval(id) }, 28)
    return () => clearInterval(id)
  }, [seen, total])
  let left = typed
  return (
    <div ref={ref} className="rounded-[18px] bg-black/60 p-4 font-mono text-[11.5px] leading-[1.75] ring-1 ring-white/10" aria-label="Build from source, then run the server with Docker">
      <div className="mb-2 flex gap-1.5" aria-hidden>{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="h-2.5 w-2.5 rounded-full" style={{ background: c }} />)}</div>
      {SH.map(([p, t], i) => {
        const show = Math.max(0, Math.min(t.length, left)); left -= t.length
        if (show === 0 && i > 0 && typed < total) return null
        const done = t.startsWith('✓')
        return (
          <p key={i} className={`overflow-hidden text-ellipsis whitespace-nowrap ${done ? 'text-volt' : 'text-white/85'}`}>
            <span className="text-flare">{p}</span>{t.slice(0, show)}
            {show < t.length && show > 0 && <span className="animate-blink ml-px inline-block h-[1.1em] w-[0.55em] translate-y-[2px] bg-white/80" />}
          </p>
        )
      })}
      {typed >= total && <p className="text-white/85"><span className="text-flare">$ </span><span className="animate-blink inline-block h-[1.1em] w-[0.55em] translate-y-[2px] bg-white/80" /></p>}
    </div>
  )
}

/* ── Desktop: a licence ticket with a perforated stub ───────── */

function Ticket() {
  return (
    <div className="group/t relative">
      <div className="relative rotate-[-2.5deg] rounded-[16px] bg-[#FBFAF8] p-4 shadow-[0_1px_0_rgba(0,0,0,.05),0_18px_30px_-16px_rgba(0,0,0,.35)] ring-1 ring-black/5 transition-transform duration-700 group-hover:rotate-0 group-hover:-translate-y-1" style={{ transitionTimingFunction: SNAP }}>
        <div className="flex items-start justify-between">
          <div>
            <p className="text-[10px] font-semibold uppercase tracking-[0.16em] text-mute-2">Licence key</p>
            <p className="font-wordmark mt-1 text-[20px] font-bold tracking-[-0.03em]">anyfmt<span className="text-flare">.</span> Desktop</p>
          </div>
          <span className="rounded-full bg-ink px-2 py-0.5 text-[10px] font-semibold text-white">×{PRICES.desktop.macs} Macs</span>
        </div>
        <p className="mt-3 break-all font-mono text-[10.5px] leading-[1.5] text-mute">ANYFMT1-01GQP-8K5F1-R24EK-7JXQ2-M9W4T-…-H58HG-2</p>
        <div className="mt-3 flex items-center justify-between border-t border-dashed border-black/20 pt-2.5 text-[10.5px] text-mute-2">
          <span>Ed25519 signed · verifies offline</span><span>exp: never</span>
        </div>
        <span aria-hidden className="absolute -left-2 top-1/2 h-4 w-4 -translate-y-1/2 rounded-full bg-white" />
        <span aria-hidden className="absolute -right-2 top-1/2 h-4 w-4 -translate-y-1/2 rounded-full bg-white" />
        <span aria-hidden className="pointer-events-none absolute right-5 top-9 rotate-[-14deg] rounded-md border-2 border-flare px-2 py-0.5 text-[12px] font-bold uppercase tracking-[0.1em] text-flare opacity-0 transition-[opacity,transform] duration-500 group-hover:opacity-90 group-hover:scale-110">Paid once</span>
      </div>
    </div>
  )
}

/* ── Pro: fluted ember glass that follows the pointer ───────── */

function ProSlab({ children }: { children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  const move = (e: React.PointerEvent) => {
    if (prefersReducedMotion() || !ref.current) return
    const r = ref.current.getBoundingClientRect()
    ref.current.style.setProperty('--rx', `${((e.clientX - r.left) / r.width) * 100}%`)
    ref.current.style.setProperty('--ry', `${((e.clientY - r.top) / r.height) * 100}%`)
  }
  return (
    <div ref={ref} onPointerMove={move} className="ribs relative flex h-full flex-col overflow-hidden rounded-[30px] p-7 text-white shadow-[0_30px_60px_-30px_rgba(238,18,0,.6)] sm:p-8" style={{ ['--rx' as string]: '80%', ['--ry' as string]: '12%', transition: 'background-position .6s' }}>
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,rgba(10,10,10,0)_40%,rgba(10,10,10,.55))]" />
      <div className="relative flex h-full flex-col">{children}</div>
    </div>
  )
}

/* ── Donate: a jar with chips ───────────────────────────────── */

const TIP_LINES: Record<number, string> = { 3: 'A thank-you that pays for a coffee.', 5: 'Keeps the next bug fix fuelled.', 10: 'Pulls the next format a little sooner.', 25: 'Keeps anyfmt independent. Thank you.' }

function DonateCard() {
  const [amt, setAmt] = useState<number>(PRICES.donate[1])
  const [monthly, setMonthly] = useState(false)
  return (
    <div id="donate" className="flex h-full scroll-mt-28 flex-col rounded-[30px] bg-volt p-7 sm:p-8">
      <div className="flex items-center justify-between">
        <p className="text-[15px] font-semibold uppercase tracking-[0.12em]">Donate</p>
        <Heart size={22} weight="fill" className="text-ink" aria-hidden />
      </div>
      <p className="mt-6 flex items-baseline gap-1 text-[56px] font-semibold leading-none tracking-[-0.05em]">
        $<NumberFlow value={amt} />
        <span className="ml-1 text-[16px] font-medium tracking-normal text-ink/60">{monthly ? 'a month' : 'once'}</span>
      </p>
      <p className="mt-3 min-h-[44px] text-[15.5px] leading-[1.45] text-ink/75">
        <AnimatePresence mode="wait" initial={false}>
          <motion.span key={amt} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.25 }} className="block">{TIP_LINES[amt]}</motion.span>
        </AnimatePresence>
      </p>
      <div role="radiogroup" aria-label="Amount" className="mt-5 grid grid-cols-4 gap-2">
        {PRICES.donate.map((d) => (
          <button key={d} type="button" role="radio" aria-checked={amt === d} onClick={() => setAmt(d)}
            className={`h-11 rounded-full text-[15px] font-semibold outline-none ring-1 transition-[background-color,color,transform] duration-300 active:scale-95 focus-visible:ring-2 focus-visible:ring-ink ${amt === d ? 'bg-ink text-white ring-ink' : 'bg-white/60 text-ink ring-black/10 hover:bg-white'}`}>${d}</button>
        ))}
      </div>
      <label className="mt-4 flex cursor-pointer items-center justify-between rounded-full bg-white/50 py-2 pl-4 pr-2 text-[14.5px] font-medium">
        Make it monthly
        <span className={`relative h-7 w-12 rounded-full transition-colors duration-300 ${monthly ? 'bg-ink' : 'bg-black/15'}`}>
          <input type="checkbox" className="peer absolute inset-0 cursor-pointer opacity-0" checked={monthly} onChange={(e) => setMonthly(e.target.checked)} />
          <span className={`absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-[left] duration-300 ${monthly ? 'left-6' : 'left-1'}`} />
        </span>
      </label>
      <ul className="mt-6 flex flex-col gap-3">
        <Feature>Unlocks nothing, changes nothing</Feature>
        <Feature>Goes straight to the person building it</Feature>
      </ul>
      <div className="mt-auto pt-8">
        <SmartLink to={PRICES.donateUrl}
          className="group relative flex h-14 w-full items-center justify-between overflow-hidden rounded-full bg-ink pl-6 pr-2 text-[16px] font-medium text-white outline-none transition-transform duration-300 active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-ink focus-visible:ring-offset-2">
          <span>Give ${amt}{monthly ? ' a month' : ''}</span>
          <span className="relative flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-white text-ink"><SwapArrow /></span>
        </SmartLink>
        <p className="mt-3 text-center text-[12.5px] text-ink/60">Opens Buy Me a Coffee, where you pick the final amount.</p>
      </div>
    </div>
  )
}

/* ── The four cards ─────────────────────────────────────────── */

function Plans({ billing }: { billing: Billing }) {
  const pro = billing === 'monthly' ? PRICES.pro.monthly : PRICES.pro.yearlyPerMonth
  return (
    <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
      {/* Self-host */}
      <div className="flex flex-col rounded-[30px] bg-night p-7 text-white sm:p-8">
        <p className="text-[15px] font-semibold uppercase tracking-[0.12em] text-white/60">Self-host</p>
        <p className="mt-6 text-[56px] font-semibold leading-none tracking-[-0.05em]">$0</p>
        <p className="mt-3 text-[15.5px] leading-[1.45] text-white/70">Build the app from source and run your own server. Every feature, on your hardware.</p>
        <div className="mt-6"><Terminal /></div>
        <ul className="mt-6 flex flex-col gap-3">
          <Feature tone="white">All {catalog.counts.routes} routes, {catalog.counts.tools} tools, CLI and MCP</Feature>
          <Feature tone="white">Your server for links, sync and inbox</Feature>
          <Feature tone="white">AGPL-3.0, commercial use included</Feature>
        </ul>
        <div className="mt-auto pt-8">
          <SmartLink to="/docs/self-host" className="group flex h-14 w-full items-center justify-between rounded-full bg-white pl-6 pr-2 text-[16px] font-medium text-ink outline-none transition-transform duration-300 active:scale-[0.98] focus-visible:ring-2 focus-visible:ring-flare">
            <RollText>Read the self-host guide</RollText>
            <span className="relative flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-ink text-white"><SwapArrow /></span>
          </SmartLink>
        </div>
      </div>

      {/* Desktop */}
      <div className="flex flex-col rounded-[30px] bg-white p-7 ring-1 ring-black/10 sm:p-8">
        <p className="text-[15px] font-semibold uppercase tracking-[0.12em] text-mute-2">Desktop</p>
        <p className="mt-6 flex items-baseline gap-2 text-[56px] font-semibold leading-none tracking-[-0.05em]">${PRICES.desktop.once}<span className="text-[16px] font-medium tracking-normal text-mute-2">once</span></p>
        <p className="mt-3 text-[15.5px] leading-[1.45] text-mute">The signed app, ready to drag into Applications. Pay once, keep every update.</p>
        <div className="mt-7 px-1"><Ticket /></div>
        <ul className="mt-7 flex flex-col gap-3">
          <Feature>Signed and notarized by Apple</Feature>
          <Feature>Every future update, automatically</Feature>
          <Feature>Up to {PRICES.desktop.macs} Macs, email support</Feature>
        </ul>
        <div className="mt-auto pt-8"><SoonButton label="Get Desktop" /></div>
      </div>

      {/* Pro */}
      <ProSlab>
        <div className="flex items-center justify-between">
          <p className="text-[15px] font-semibold uppercase tracking-[0.12em]">Pro</p>
          <span className="rounded-full bg-white px-2.5 py-1 text-[12px] font-semibold text-ink">Most useful</span>
        </div>
        <p className="mt-6 flex items-baseline gap-2 text-[56px] font-semibold leading-none tracking-[-0.05em]">
          $<NumberFlow value={pro} /><span className="text-[16px] font-medium tracking-normal text-white/80">/ month</span>
        </p>
        <p className="mt-3 min-h-[44px] text-[15.5px] leading-[1.45] text-white/85">
          {billing === 'yearly' ? `$${pro * 12} billed yearly. ` : ''}Desktop, plus the things that need our servers.
        </p>
        <ul className="mt-6 flex flex-col gap-3">
          <Feature tone="white">Everything in Desktop</Feature>
          <Feature tone="white">Share links with expiry, password and a download cap</Feature>
          <Feature tone="white">Heavy video in the cloud when your Mac is busy</Feature>
          <Feature tone="white">Presets and wheel order synced across Macs</Feature>
          <Feature tone="white">Send from your phone, land in a folder on your Mac</Feature>
          <Feature tone="white">Transcribe to SRT, upscale, HQ cutouts</Feature>
        </ul>
        <div className="mt-auto pt-8"><SoonButton label="Start Pro" tone="light" /></div>
      </ProSlab>

      <DonateCard />
    </div>
  )
}

/* ── The line: your Mac | our servers ───────────────────────── */

const LOCAL = ['Every conversion', 'Every tool', 'AirDrop, Float, Copy, Move', 'Batch and presets', 'Command line and MCP', 'Commercial use']
const CLOUD = ['Share links', 'Cloud conversions', 'Sync across Macs', 'Inbox from your phone', 'Transcription', 'Upscaling and HQ cutouts']

function TheLine() {
  const [hot, setHot] = useState<number | null>(null)
  return (
    <section className="bg-white py-24 lg:py-32">
      <Container>
        <Eyebrow>The line we don't cross</Eyebrow>
        <h2 className="mt-6 max-w-[920px] text-[clamp(34px,4.4vw,68px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">If it runs on your Mac, it's yours. If it runs on ours, it costs us.</h2>
        <div className="mt-16 grid items-stretch gap-6 lg:grid-cols-[1fr_auto_1fr]">
          <div className="rounded-[28px] bg-sand p-8">
            <p className="text-[14px] font-semibold uppercase tracking-[0.14em] text-mute-2">Your Mac · never paywalled</p>
            <ul className="mt-6 grid gap-2 sm:grid-cols-2">
              {LOCAL.map((t) => <li key={t} className="flex items-center gap-3 rounded-2xl bg-white px-4 py-3 text-[16px] font-medium"><Check size={16} weight="bold" className="text-ink" />{t}</li>)}
            </ul>
          </div>
          <div className="relative hidden w-24 lg:block" aria-hidden>
            <div className="absolute inset-y-4 left-1/2 w-px -translate-x-1/2 bg-[repeating-linear-gradient(to_bottom,#0A0A0A_0_6px,transparent_6px_12px)]" />
            <motion.div className="absolute left-1/2 top-1/2 flex h-14 w-11 -translate-x-1/2 -translate-y-1/2 items-end justify-center rounded-[8px] bg-white pb-1.5 shadow-[0_10px_24px_-10px_rgba(0,0,0,.35)] ring-1 ring-black/10"
              animate={{ x: hot === null ? '-50%' : '120%', rotate: hot === null ? 0 : 8 }} transition={{ type: 'spring', stiffness: 260, damping: 22 }}>
              <span className="rounded-[4px] bg-flare px-1 text-[8px] font-bold uppercase text-white">mov</span>
            </motion.div>
          </div>
          <div className="rounded-[28px] bg-night p-8 text-white">
            <p className="flex items-center gap-2 text-[14px] font-semibold uppercase tracking-[0.14em] text-white/55"><Cloud size={16} weight="fill" /> Our servers · Pro</p>
            <ul className="mt-6 grid gap-2 sm:grid-cols-2">
              {CLOUD.map((t, i) => (
                <li key={t} onPointerEnter={() => setHot(i)} onPointerLeave={() => setHot(null)}
                  className="flex items-center gap-3 rounded-2xl bg-white/[0.07] px-4 py-3 text-[16px] font-medium transition-colors duration-300 hover:bg-white/[0.14]">
                  <Cloud size={16} weight="fill" className="text-flare" />{t}
                </li>
              ))}
            </ul>
          </div>
        </div>
        <p className="mt-8 max-w-[640px] text-[16px] leading-[1.55] text-mute">In the app, anything that would leave your Mac carries a small cloud glyph, and the first upload always tells you which server it's going to. A licence key never unlocks or limits anything local.</p>
      </Container>
    </section>
  )
}

/* ── Full table ─────────────────────────────────────────────── */

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
    ['Automatic updates', 'Pull and rebuild', true, true],
    ['Macs', 'Unlimited', `Up to ${PRICES.desktop.macs}`, `Up to ${PRICES.desktop.macs}`],
    ['Email support', false, true, 'Priority'],
  ] },
  { group: 'Server features', rows: [
    ['Share links', 'Your server', false, true],
    ['Cloud conversions', 'Your server', false, true],
    ['Sync across Macs', 'Your server', false, true],
    ['Inbox from phone or browser', 'Your server', false, true],
    ['Transcribe, upscale, HQ cutouts', 'Your GPU', false, true],
  ] },
]
const PLANS = ['Self-host', 'Desktop', 'Pro'] as const

function CellView({ v }: { v: Cell }) {
  if (v === true) return <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-ink text-white"><Check size={12} weight="bold" /><span className="sr-only">Included</span></span>
  if (v === false) return <span className="inline-flex h-6 w-6 items-center justify-center text-mute-3"><Minus size={14} weight="bold" /><span className="sr-only">Not included</span></span>
  return <span className="text-[14.5px] font-medium">{v}</span>
}

function Table() {
  const [col, setCol] = useState(2)
  return (
    <section className="bg-sand py-24 lg:py-32">
      <Container>
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <Eyebrow>Side by side</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Everything, in one table.</h2>
          </div>
          {/* on phones, one plan at a time */}
          <div role="tablist" aria-label="Plan" className="inline-flex rounded-full bg-white p-1 ring-1 ring-black/10 md:hidden">
            {PLANS.map((p, i) => (
              <button key={p} type="button" role="tab" aria-selected={col === i} onClick={() => setCol(i)} className="relative h-9 rounded-full px-4 text-[14px] font-medium">
                {col === i && <motion.span layoutId="tcol" className="absolute inset-0 rounded-full bg-ink" />}
                <span className={`relative ${col === i ? 'text-white' : ''}`}>{p}</span>
              </button>
            ))}
          </div>
        </div>
        <div className="mt-12 overflow-hidden rounded-[28px] bg-white">
          <table className="w-full border-collapse text-left">
            <thead className="bg-white">
              <tr className="border-b border-line">
                <th scope="col" className="p-5 text-[14px] font-medium text-mute-2 sm:p-6">Feature</th>
                {PLANS.map((p, i) => (
                  <th key={p} scope="col" className={`p-5 text-[17px] font-semibold tracking-[-0.02em] sm:p-6 ${i !== col ? 'hidden md:table-cell' : ''} ${i === 2 ? 'text-flare' : ''}`}>{p}</th>
                ))}
              </tr>
            </thead>
            {ROWS.map((g) => (
              <tbody key={g.group}>
                <tr><th colSpan={4} scope="colgroup" className="bg-sand-2/60 px-5 py-3 text-[12.5px] font-semibold uppercase tracking-[0.14em] text-mute-2 sm:px-6">{g.group}</th></tr>
                {g.rows.map(([label, ...cells]) => (
                  <tr key={label} className="border-b border-line last:border-0">
                    <th scope="row" className="p-5 text-[15.5px] font-medium sm:px-6 sm:py-4">{label}</th>
                    {cells.map((c, i) => <td key={i} className={`p-5 sm:px-6 sm:py-4 ${i !== col ? 'hidden md:table-cell' : ''}`}><CellView v={c} /></td>)}
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

/* ── API meter ──────────────────────────────────────────────── */

const STEPS = [0, 100, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000]
const MIN_STEPS = [0, 10, 30, 60, 120, 300, 600, 1200, 3000, 6000]

function Slider({ label, steps, value, onChange, unit }: { label: string; steps: number[]; value: number; onChange: (i: number) => void; unit: string }) {
  const pct = (value / (steps.length - 1)) * 100
  return (
    <label className="block">
      <span className="flex items-baseline justify-between gap-4">
        <span className="text-[15px] font-medium text-white/70">{label}</span>
        <span className="text-[22px] font-semibold tracking-[-0.02em] text-white"><NumberFlow value={steps[value]} /> <span className="text-[14px] font-medium text-white/55">{unit}</span></span>
      </span>
      <span className="relative mt-4 block h-10">
        <span className="absolute inset-x-0 top-1/2 h-2 -translate-y-1/2 rounded-full bg-white/10" />
        <span className="absolute left-0 top-1/2 h-2 -translate-y-1/2 rounded-full bg-[linear-gradient(90deg,#EE1200,#FF4A14,#FFB23E)]" style={{ width: `${pct}%` }} />
        <span className="pointer-events-none absolute top-1/2 h-7 w-7 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white shadow-[0_4px_14px_rgba(0,0,0,.4)]" style={{ left: `${pct}%` }} />
        <input type="range" min={0} max={steps.length - 1} step={1} value={value} onChange={(e) => onChange(Number(e.target.value))}
          className="absolute inset-0 h-full w-full cursor-pointer opacity-0" aria-valuetext={`${steps[value]} ${unit}`} />
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
  return (
    <section className="bg-white p-3 sm:p-5">
      <div className="relative overflow-hidden rounded-[32px] bg-night text-white">
        <Flutes variant="dark" corner="bl" className="pointer-events-none absolute inset-0 opacity-60" />
        <div className="relative grid gap-12 px-6 py-16 sm:px-12 lg:grid-cols-[1fr_1.1fr] lg:py-24">
          <div>
            <Eyebrow tone="white">HTTP API</Eyebrow>
            <h2 className="mt-6 max-w-[520px] text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Pay per conversion. No plan needed.</h2>
            <p className="mt-6 max-w-[460px] text-[17px] leading-[1.55] text-white/70">
              The same routes and options as the app, over HTTP. {Math.round(PRICES.api.perConversion * 100)}¢ a conversion, {Math.round(PRICES.api.perMediaMinute * 100)}¢ a minute of audio or video. Failed conversions are free.
            </p>
            <p className="mt-6 inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1.5 text-[13px] font-medium text-white/80"><span className="h-1.5 w-1.5 rounded-full bg-volt" />Preview: the contract and SDK are ready, the hosted API isn't live yet</p>
            <div className="mt-8"><ArrowLink to="/docs/api" className="text-white">Read the API docs</ArrowLink></div>
          </div>
          <div className="rounded-[24px] bg-white/[0.06] p-6 ring-1 ring-white/10 sm:p-8">
            <div className="space-y-8">
              <Slider label="Conversions a month" steps={STEPS} value={c} onChange={setC} unit="files" />
              <Slider label="Audio and video" steps={MIN_STEPS} value={m} onChange={setM} unit="minutes" />
            </div>
            <div className="mt-10 flex items-end justify-between gap-4 border-t border-white/10 pt-6">
              <div className="text-[14px] leading-[1.7] text-white/60">
                <p>{STEPS[c].toLocaleString('en-US')} × {Math.round(PRICES.api.perConversion * 100)}¢ = ${conv.toFixed(2)}</p>
                <p>{MIN_STEPS[m].toLocaleString('en-US')} min × {Math.round(PRICES.api.perMediaMinute * 100)}¢ = ${mins.toFixed(2)}</p>
              </div>
              <p className="text-right">
                <span className="block text-[13px] font-medium uppercase tracking-[0.12em] text-white/50">a month</span>
                <span className="text-[clamp(40px,5vw,64px)] font-semibold leading-none tracking-[-0.05em]">$<NumberFlow value={total} format={{ minimumFractionDigits: 2, maximumFractionDigits: 2 }} /></span>
              </p>
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
  const [billing, setBilling] = useState<Billing>('yearly')
  useHead({
    title: 'Pricing',
    description: `anyfmt is open source. Self-host for free, buy the signed Desktop app for $${PRICES.desktop.once} once, add Pro for $${PRICES.pro.yearlyPerMonth}/month for cloud features, or donate any amount.`,
    path: '/pricing',
    jsonLd: [
      {
        '@context': 'https://schema.org', '@type': 'Product', name: 'anyfmt', description: SITE.description, brand: { '@type': 'Brand', name: 'anyfmt' },
        offers: [
          { '@type': 'Offer', name: 'Self-host', price: '0', priceCurrency: 'USD' },
          { '@type': 'Offer', name: 'Desktop licence', price: String(PRICES.desktop.once), priceCurrency: 'USD' },
          { '@type': 'Offer', name: 'Pro (monthly)', price: String(PRICES.pro.monthly), priceCurrency: 'USD' },
        ],
      },
      { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: FAQ.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
    ],
  })
  return (
    <Page>
      <section className="bg-sand pb-20 pt-36 lg:pb-28 lg:pt-44">
        <Container>
          <div className="grid items-end gap-10 lg:grid-cols-[1.4fr_1fr]">
            <div>
              <Eyebrow>Pricing</Eyebrow>
              <h1 className="mt-6 text-[clamp(44px,6.4vw,100px)] font-semibold leading-[0.95] tracking-[-0.055em] [text-wrap:balance]">Pay for convenience. Never for your own files.</h1>
            </div>
            <div className="lg:pb-3">
              <p className="max-w-[440px] text-[18px] leading-[1.55] text-mute">Every conversion that runs on your Mac is open source and free to build. Money buys you a signed app, our servers, or a thank-you.</p>
              <div className="mt-8"><BillingToggle value={billing} onChange={setBilling} /></div>
            </div>
          </div>
          <div className="mt-16"><Plans billing={billing} /></div>
          <p className="mt-8 text-[14px] text-mute-2">Prices in US dollars. Taxes may apply at checkout. Checkout opens with the first public release.</p>
        </Container>
      </section>
      <TheLine />
      <Table />
      <ApiMeter />
      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>Questions</Eyebrow>
            <h2 className="mt-6 text-[clamp(36px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Money, plainly.</h2>
            <div className="mt-10"><DownloadButton /></div>
          </div>
          <Accordion items={FAQ} />
        </Container>
      </section>
    </Page>
  )
}
