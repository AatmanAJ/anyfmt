/**
 * Download: the install as a short film. A disk image window where the icon walks itself into
 * Applications and the glyph turns up in the menu bar. Then every way to install, the first
 * minute, what's inside, and the permissions, honestly.
 */
import { AppleLogo, Check, Package, Terminal as TerminalIcon, Wrench } from '@phosphor-icons/react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { AppIcon } from '../components/AppIcon'
import { ArrowLink, SwapArrow } from '../components/Buttons'
import { Page } from '../components/Page'
import { Command, Container, Eyebrow, Keycap } from '../components/ui'
import catalog from '../data/catalog.json'
import { BUNDLED } from '../data/engines'
import { useHead } from '../lib/head'
import { EASE, SNAP } from '../lib/hooks'
import { SITE } from '../lib/site'

/* ── the release button ────────────────────────────────────── */

function ReleaseButton() {
  const [said, setSaid] = useState(false)
  useEffect(() => { if (!said) return; const t = window.setTimeout(() => setSaid(false), 3600); return () => clearTimeout(t) }, [said])
  return (
    <button type="button" onClick={() => setSaid(true)} aria-live="polite"
      className="group relative inline-flex h-16 items-center overflow-hidden rounded-full bg-ink pl-7 pr-2 text-[17px] font-medium text-white outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-2">
      <span aria-hidden className="pointer-events-none absolute inset-0 rounded-full bg-volt transition-[clip-path] duration-500 [clip-path:circle(24px_at_calc(100%-32px)_50%)] group-hover:[clip-path:circle(150%_at_calc(100%-32px)_50%)]" style={{ transitionTimingFunction: SNAP }} />
      <span className="relative flex items-center gap-3 pr-5 transition-colors duration-500 group-hover:text-ink">
        <AppleLogo size={20} weight="fill" aria-hidden />
        <span className="relative grid overflow-hidden">
          <AnimatePresence mode="popLayout" initial={false}>
            <motion.span key={String(said)} initial={{ y: 26, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -26, opacity: 0 }} transition={{ duration: 0.45, ease: EASE }} className="whitespace-nowrap">
              {said ? 'The first build lands soon' : `Download anyfmt ${SITE.version}`}
            </motion.span>
          </AnimatePresence>
        </span>
      </span>
      <span className="relative flex h-12 w-12 items-center justify-center rounded-full text-ink"><span className="relative flex h-5 w-5 items-center justify-center overflow-hidden"><SwapArrow size={16} dir="s" /></span></span>
    </button>
  )
}

/* ── the disk image film ───────────────────────────────────── */

function Folder() {
  return (
    <svg viewBox="0 0 120 96" width="112" aria-hidden>
      <path d="M8 18c0-5 4-9 9-9h28l9 9h49c5 0 9 4 9 9v52c0 5-4 9-9 9H17c-5 0-9-4-9-9z" fill="#5BA3F5" />
      <path d="M8 30c0-5 4-9 9-9h86c5 0 9 4 9 9v49c0 5-4 9-9 9H17c-5 0-9-4-9-9z" fill="#7DB8FA" />
      <path d="M60 40l14 8v16l-14 8-14-8V48z" fill="none" stroke="#3E83D6" strokeWidth="3" strokeLinejoin="round" />
      <path d="M46 48l14 8 14-8M60 56v16" fill="none" stroke="#3E83D6" strokeWidth="3" strokeLinejoin="round" />
    </svg>
  )
}

function DiskImage() {
  const reduce = useReducedMotion()
  const loop = { duration: 5.2, repeat: Infinity, repeatDelay: 0.8, ease: [0.45, 0, 0.2, 1] as const }
  return (
    <div className="relative mx-auto w-full max-w-[640px]">
      {/* menu bar */}
      <div className="mb-4 flex h-9 items-center justify-end gap-4 rounded-[12px] bg-white/70 px-4 text-[12px] font-medium text-ink ring-1 ring-black/5">
        <span className="text-mute-2">Tue 27 Oct  09:41</span>
        <motion.span className="flex items-center gap-1.5 rounded-[6px] px-1.5 py-0.5"
          animate={reduce ? { opacity: 1 } : { opacity: [0, 0, 1, 1, 0], backgroundColor: ['rgba(0,0,0,0)', 'rgba(0,0,0,0)', 'rgba(10,10,10,.08)', 'rgba(0,0,0,0)', 'rgba(0,0,0,0)'] }}
          transition={reduce ? undefined : { ...loop, times: [0, 0.62, 0.7, 0.92, 1] }}>
          <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden><circle cx="8" cy="8" r="6.2" fill="none" stroke="#0A0A0A" strokeWidth="1.6" /><path d="M8 1.8 9.9 7.4H6.1Z" fill="#FF4A14" /><circle cx="8" cy="8" r="1.7" fill="#0A0A0A" /></svg>
          anyfmt
        </motion.span>
        <span className="h-3 w-5 rounded-[3px] ring-1 ring-ink/60" />
      </div>
      {/* window */}
      <div className="overflow-hidden rounded-[16px] bg-[#1A1A1A] shadow-[0_40px_80px_-30px_rgba(0,0,0,.55)] ring-1 ring-black/20">
        <div className="relative flex h-10 items-center justify-center bg-[#2A2A2A]">
          <span className="absolute left-4 flex gap-2">{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="h-3 w-3 rounded-full" style={{ background: c }} />)}</span>
          <span className="text-[13px] font-medium text-white/70">anyfmt {SITE.version}</span>
        </div>
        <div className="flutes-static-dark relative h-[300px] sm:h-[340px]">
          <svg viewBox="0 0 120 40" className="absolute left-1/2 top-[44%] w-[20%] max-w-[120px] -translate-x-1/2 -translate-y-1/2 text-white/40" aria-hidden><path d="M4 26c30-22 70-22 100-4" fill="none" stroke="currentColor" strokeWidth="2.5" strokeDasharray="5 7" strokeLinecap="round" /><path d="M98 13l8 10-12 3" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
          <div className="absolute left-[74%] top-1/2 flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-2">
            <motion.div animate={reduce ? undefined : { scale: [1, 1, 1, 1.12, 1, 1] }} transition={reduce ? undefined : { ...loop, times: [0, 0.4, 0.56, 0.62, 0.7, 1] }}><Folder /></motion.div>
            <span className="text-[13px] font-medium text-white">Applications</span>
          </div>
          <span className="absolute left-[26%] top-[calc(50%+68px)] -translate-x-1/2 text-[13px] font-medium text-white">anyfmt</span>
          <motion.div className="absolute top-1/2 z-10"
            initial={{ left: '26%' }}
            animate={reduce ? { left: '26%' } : { left: ['26%', '26%', '50%', '74%', '74%', '26%'], y: [0, -10, -50, -6, 0, 0], scale: [1, 1.06, 1.04, 0.45, 0.45, 1], opacity: [1, 1, 1, 0, 0, 1] }}
            transition={reduce ? undefined : { ...loop, times: [0, 0.12, 0.38, 0.58, 0.95, 1] }}>
            <div className="-translate-x-1/2 -translate-y-[58%]"><AppIcon size={112} uid="dmg" /></div>
          </motion.div>
        </div>
      </div>
      <p className="mt-4 text-center text-[13px] text-mute-2">Drag the icon onto Applications. The glyph appears in your menu bar.</p>
    </div>
  )
}

/* ── ways in ───────────────────────────────────────────────── */

function Way({ icon, title, tag, children, cmd, foot }: { icon: ReactNode; title: string; tag?: string; children: ReactNode; cmd?: string; foot?: ReactNode }) {
  return (
    <div className="flex flex-col rounded-[26px] bg-white p-7 ring-1 ring-black/5">
      <div className="flex items-center justify-between">
        <span className="flex h-12 w-12 items-center justify-center rounded-[14px] bg-sand text-ink">{icon}</span>
        {tag && <span className="rounded-full bg-volt px-2.5 py-1 text-[12px] font-semibold">{tag}</span>}
      </div>
      <h3 className="mt-6 text-[22px] font-semibold tracking-[-0.03em]">{title}</h3>
      <p className="mt-2 text-[15.5px] leading-[1.55] text-mute">{children}</p>
      <div className="mt-auto pt-6">{cmd && <Command cmd={cmd} />}{foot}</div>
    </div>
  )
}

/* ── the first minute ──────────────────────────────────────── */

function FirstMinute() {
  const steps: { n: string; title: string; text: string; art: ReactNode }[] = [
    { n: '01', title: 'Open it once', text: 'From Applications. There is no window and no Dock icon: anyfmt lives in the menu bar.', art: <div className="flex h-full items-center justify-center"><AppIcon size={96} uid="s1" /></div> },
    { n: '02', title: 'Drag any file, tap Shift', text: 'Mid-drag, tap ⇧ Shift. The wheel opens around your pointer with every format that file can become.', art: <div className="flex h-full items-center justify-center gap-4"><span className="flex h-[78px] w-[62px] items-end rounded-[10px] bg-white p-1.5 shadow-[0_10px_20px_-10px_rgba(0,0,0,.3)] ring-1 ring-black/5"><span className="rounded-[4px] bg-[#FF8A2A] px-1 text-[10px] font-bold uppercase text-white">heic</span></span><Keycap glyph="⇧" name="Shift" pressed /></div> },
    { n: '03', title: 'Drop on a format', text: 'A new copy appears beside the original, in milliseconds for most photos. The original is never touched.', art: <div className="flex h-full items-center justify-center gap-3 font-mono text-[13px]"><span className="rounded-lg bg-white px-2.5 py-1.5 ring-1 ring-black/10">IMG_0042.heic</span><span className="text-flare">→</span><span className="rounded-lg bg-ink px-2.5 py-1.5 text-white">IMG_0042.jpg</span></div> },
  ]
  return (
    <div className="grid gap-5 lg:grid-cols-3">
      {steps.map((s, i) => (
        <motion.div key={s.n} initial={{ opacity: 0, y: 18 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.4 }} transition={{ duration: 0.7, ease: EASE, delay: i * 0.08 }}
          className="overflow-hidden rounded-[26px] bg-sand">
          <div className="h-[180px] border-b border-black/5">{s.art}</div>
          <div className="p-7">
            <p className="font-mono text-[13px] text-flare">{s.n}</p>
            <h3 className="mt-2 text-[22px] font-semibold tracking-[-0.03em]">{s.title}</h3>
            <p className="mt-2 text-[15.5px] leading-[1.55] text-mute">{s.text}</p>
          </div>
        </motion.div>
      ))}
    </div>
  )
}

/* ── permissions ───────────────────────────────────────────── */

const PERMS: [string, string, string][] = [
  ['The wheel, every conversion and tool', 'None', 'anyfmt reads the mouse button, the modifier keys and the drag pasteboard: public state any app can read. It never sees ordinary keys.'],
  ['Return on a Finder selection opens the wheel', 'Accessibility, Automation › Finder', 'Optional, off until you turn it on. To catch Return before Finder starts renaming, and to ask Finder what is selected.'],
  ['Export to Pages, open Keynote or Numbers files', 'Automation › Pages, Keynote, Numbers', 'Optional. anyfmt asks your own iWork apps to do the conversion.'],
  ['Update checks', 'None (network)', 'Opt-in. Once a day anyfmt fetches the release feed and sends nothing else.'],
]

export default function Download() {
  useHead({
    title: 'Download anyfmt for Mac',
    description: `Download anyfmt ${SITE.version} for macOS: a ${SITE.dmgSize} disk image for Apple silicon Macs on macOS 13 or later. Or install with Homebrew, or build it from source.`,
    path: '/download',
    jsonLd: {
      '@context': 'https://schema.org', '@type': 'SoftwareApplication', name: 'anyfmt', operatingSystem: 'macOS 13+', applicationCategory: 'UtilitiesApplication',
      softwareVersion: SITE.version, fileSize: SITE.dmgSize, processorRequirements: 'Apple silicon (arm64)', downloadUrl: `${SITE.url}/download`,
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    },
  })
  return (
    <Page>
      <section className="relative overflow-hidden bg-fog pb-20 pt-36 lg:pb-28 lg:pt-44">
        <div className="flutes-static pointer-events-none absolute inset-0 opacity-60" />
        <Container className="relative grid items-center gap-16 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
          <div>
            <Eyebrow>Download</Eyebrow>
            <h1 className="mt-6 text-[clamp(48px,6.6vw,104px)] font-semibold leading-[0.94] tracking-[-0.055em]">Get anyfmt.</h1>
            <p className="mt-6 max-w-[480px] text-[19px] leading-[1.5] text-ink-2">One disk image, one drag into Applications. Every engine is inside, so there is nothing else to install.</p>
            <div className="mt-10"><ReleaseButton /></div>
            <dl className="mt-10 grid max-w-[520px] grid-cols-2 gap-x-8 gap-y-4 text-[15px] sm:grid-cols-4">
              {[['Version', SITE.version], ['Size', SITE.dmgSize], ['Chip', 'Apple silicon'], ['macOS', '13 or later']].map(([k, v]) => (
                <div key={k}><dt className="text-[13px] text-mute">{k}</dt><dd className="mt-0.5 font-semibold">{v}</dd></div>
              ))}
            </dl>
            {!SITE.released && <p className="mt-8 inline-flex items-center gap-2 rounded-full bg-white/80 px-3.5 py-1.5 text-[13.5px] font-medium ring-1 ring-black/5"><span className="h-1.5 w-1.5 rounded-full bg-flare" />The first public build is on its way. <Link to="/changelog" className="underline decoration-flare/60 underline-offset-2">Follow the changelog</Link></p>}
          </div>
          <DiskImage />
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Ways in</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">However you like to install things.</h2>
          <div className="mt-14 grid gap-5 md:grid-cols-2 xl:grid-cols-4">
            <Way icon={<AppleLogo size={22} weight="fill" />} title="Disk image" tag="Easiest">Signed and notarized by Apple. Open it, drag anyfmt into Applications, done.</Way>
            <Way icon={<Package size={22} weight="fill" />} title="Homebrew" cmd={SITE.brew.cask}>The app, plus the anyfmt command linked onto your PATH.</Way>
            <Way icon={<TerminalIcon size={22} weight="fill" />} title="Command line only" cmd={SITE.brew.cli}>Just the CLI, its framework and the engines. No app, no menu bar.</Way>
            <Way icon={<Wrench size={22} weight="fill" />} title="Build from source" foot={<ArrowLink to="/open-source">Clone and build</ArrowLink>}>AGPL-3.0, free forever. You need Xcode 16 and Rust; make does the rest.</Way>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>The first minute</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Three steps, then it's muscle memory.</h2>
          <div className="mt-14"><FirstMinute /></div>
          <p className="mt-8 text-[16px] text-mute">Not a dragger? Select files in Finder and use <strong className="text-ink">Services › Open in anyfmt Wheel</strong>, or press <strong className="text-ink">⌃⌥Space</strong> for a ring you can drop onto. <ArrowLink to="/docs/keyboard">All the ways in</ArrowLink></p>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div>
            <Eyebrow>Permissions, honestly</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">The wheel needs none.</h2>
            <p className="mt-6 max-w-[400px] text-[16.5px] leading-[1.55] text-mute">Two extras ask for more, and both stay off until you switch them on.</p>
          </div>
          <ul className="divide-y divide-line rounded-[26px] bg-white px-6 ring-1 ring-black/5 sm:px-8">
            {PERMS.map(([what, perm, why]) => (
              <li key={what} className="grid gap-2 py-6 sm:grid-cols-[1fr_auto] sm:gap-6">
                <div>
                  <p className="text-[17px] font-semibold tracking-[-0.01em]">{what}</p>
                  <p className="mt-1.5 text-[15px] leading-[1.55] text-mute">{why}</p>
                </div>
                <p className={`h-fit w-fit rounded-full px-3 py-1 text-[13px] font-semibold ${perm === 'None' ? 'bg-volt' : 'bg-sand-2'}`}>{perm === 'None' ? <span className="flex items-center gap-1.5"><Check size={13} weight="bold" />None</span> : perm}</p>
              </li>
            ))}
          </ul>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div>
            <Eyebrow>What's inside</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">{SITE.appSize}, everything included.</h2>
            <p className="mt-6 max-w-[400px] text-[16.5px] leading-[1.55] text-mute">Built from pinned, checksummed sources. Every licence ships in the app with a written source offer. {catalog.counts.routes} routes need nothing from Homebrew.</p>
          </div>
          <div className="overflow-x-auto rounded-[26px] ring-1 ring-line">
            <table className="w-full min-w-[520px] text-left text-[15px]">
              <thead className="bg-sand text-[13px] text-mute-2"><tr><th className="px-6 py-3 font-medium">Engine</th><th className="px-6 py-3 font-medium">Version</th><th className="px-6 py-3 font-medium">Licence</th><th className="px-6 py-3 font-medium">For</th></tr></thead>
              <tbody>
                {BUNDLED.map((e) => (
                  <tr key={e.name} className="border-t border-line"><td className="px-6 py-3 font-semibold">{e.name}</td><td className="px-6 py-3 font-mono text-[13.5px]">{e.version}</td><td className="px-6 py-3 text-mute">{e.licence}</td><td className="px-6 py-3 text-mute">{e.does}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        </Container>
      </section>
    </Page>
  )
}
