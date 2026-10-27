/**
 * Download: the install as a short film. A disk image window where the icon walks itself into
 * Applications and the glyph turns up in the menu bar. Then every way to install, the first
 * minute, what's inside, and the permissions, honestly.
 */
import { Check } from '@phosphor-icons/react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { useEffect, useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { AppIcon, MenuBarGlyph } from '../components/AppIcon'
import { ArrowLink, SwapArrow } from '../components/Buttons'
import { AppleMark } from '../components/Marks'
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
      className="group relative inline-flex h-16 max-w-full items-center overflow-hidden rounded-full bg-ink pl-6 pr-2 text-[16px] font-medium sm:pl-7 sm:text-[17px] text-white outline-none transition-transform duration-300 active:scale-[0.97] focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-2">
      <span aria-hidden className="pointer-events-none absolute inset-0 rounded-full bg-volt transition-[clip-path] duration-500 [clip-path:circle(24px_at_calc(100%-32px)_50%)] group-hover:[clip-path:circle(150%_at_calc(100%-32px)_50%)]" style={{ transitionTimingFunction: SNAP }} />
      <span className="relative flex items-center gap-3 pr-5 transition-colors duration-500 group-hover:text-ink">
        <AppleMark size={20} className="-mt-0.5" />
        <span className="relative grid overflow-hidden">
          <AnimatePresence mode="popLayout" initial={false}>
            <motion.span key={String(said)} initial={{ y: 26, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -26, opacity: 0 }} transition={{ duration: 0.45, ease: EASE }} className="whitespace-nowrap">
              {said ? 'The first build lands soon' : <>Download <span className="hidden min-[360px]:inline">anyfmt </span>{SITE.version}</>}
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
  const loop = { duration: 5.6, repeat: Infinity, repeatDelay: 0.6, ease: [0.45, 0, 0.2, 1] as const }
  // one timeline: pick up (0.12), carry (0.12 to 0.5), drop on Applications (0.5 to 0.58), glyph shows in the menu bar (0.66)
  return (
    <figure className="relative mx-auto w-full max-w-[640px]">
      <div className="relative overflow-hidden rounded-[22px] shadow-[0_40px_80px_-30px_rgba(0,0,0,.55)] ring-1 ring-black/15">
        <div className="flutes-static-dark absolute inset-0" />
        {/* menu bar */}
        <div className="relative flex h-8 items-center justify-between bg-black/35 px-4 text-[12.5px] font-medium text-white backdrop-blur-md">
          <span className="flex items-center gap-4"><AppleMark size={13} className="-mt-0.5" /><b className="font-semibold">Finder</b><span className="hidden sm:inline">File</span><span className="hidden sm:inline">Edit</span><span className="hidden sm:inline">View</span></span>
          <span className="flex items-center gap-3.5">
            <motion.span className="flex h-6 w-7 items-center justify-center rounded-[5px]"
              animate={reduce ? { opacity: 1 } : { opacity: [0, 0, 1, 1, 1], backgroundColor: ['rgba(255,255,255,0)', 'rgba(255,255,255,0)', 'rgba(255,255,255,.22)', 'rgba(255,255,255,0)', 'rgba(255,255,255,0)'] }}
              transition={reduce ? undefined : { ...loop, times: [0, 0.62, 0.68, 0.8, 1] }}>
              <MenuBarGlyph size={15} />
            </motion.span>
            <span className="tabular-nums">Tue 27 Oct 09:41</span>
          </span>
        </div>
        {/* the disk image window */}
        <div className="relative px-5 pb-8 pt-6 sm:px-10 sm:pb-12 sm:pt-10">
          <div className="overflow-hidden rounded-[12px] bg-[#F6F5F3] shadow-[0_24px_48px_-20px_rgba(0,0,0,.6)] ring-1 ring-black/20">
            <div className="relative flex h-9 items-center justify-center border-b border-black/[.08] bg-[#ECEBE8]">
              <span className="absolute left-3.5 flex gap-2">{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="h-3 w-3 rounded-full" style={{ background: c }} />)}</span>
              <span className="text-[13px] font-semibold text-ink/80">anyfmt {SITE.version}</span>
            </div>
            <div className="relative h-[220px] sm:h-[260px]">
              <div className="absolute left-[27%] top-[46%] flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-2">
                <AppIcon size={92} uid="dmg" />
                <span className="text-[13px] font-medium text-ink">anyfmt</span>
              </div>
              <svg viewBox="0 0 120 40" className="absolute left-1/2 top-[38%] w-[18%] max-w-[110px] -translate-x-1/2 -translate-y-1/2 text-ink/30" aria-hidden><path d="M4 26c30-22 70-22 100-4" fill="none" stroke="currentColor" strokeWidth="2.5" strokeDasharray="5 7" strokeLinecap="round" /><path d="M98 13l8 10-12 3" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
              <div className="absolute left-[73%] top-[46%] flex -translate-x-1/2 -translate-y-1/2 flex-col items-center gap-2">
                <motion.div animate={reduce ? undefined : { scale: [1, 1, 1, 1.1, 1, 1] }} transition={reduce ? undefined : { ...loop, times: [0, 0.44, 0.5, 0.55, 0.62, 1] }}><Folder /></motion.div>
                <span className="text-[13px] font-medium text-ink">Applications</span>
              </div>
              {/* the dragged copy and the pointer; the original stays put, like Finder */}
              {!reduce && (
                <motion.div aria-hidden className="pointer-events-none absolute top-[46%] z-10"
                  initial={{ left: '27%', opacity: 0 }}
                  animate={{ left: ['27%', '27%', '50%', '73%', '73%'], y: [0, -6, -40, -4, -4], opacity: [0, 0.75, 0.75, 0.75, 0], scale: [1, 1, 1, 0.9, 0.6] }}
                  transition={{ ...loop, times: [0, 0.12, 0.32, 0.5, 0.58] }}>
                  <div className="relative -translate-x-1/2 -translate-y-[62%]">
                    <AppIcon size={92} uid="dmg-ghost" />
                    <svg width="18" height="22" viewBox="0 0 18 22" className="absolute -bottom-1 left-[58%] drop-shadow-[0_1px_1px_rgba(0,0,0,.4)]"><path d="M2 1.5v16.2l4.1-3.9 2.7 6.3 2.6-1.1-2.7-6.2h5.8z" fill="#0A0A0A" stroke="#fff" strokeWidth="1.4" strokeLinejoin="round" /></svg>
                  </div>
                </motion.div>
              )}
            </div>
          </div>
        </div>
      </div>
      <figcaption className="mt-4 text-center text-[14px] text-mute-2">Drag the icon onto Applications. The glyph turns up in your menu bar.</figcaption>
    </figure>
  )
}

/* ── ways in ───────────────────────────────────────────────── */

function Way({ title, tag, children, action }: { title: string; tag?: string; children: ReactNode; action: ReactNode }) {
  return (
    <li className="grid gap-x-8 gap-y-3 py-7 lg:grid-cols-[minmax(0,3fr)_minmax(0,4fr)_minmax(0,5fr)] lg:items-center">
      <h3 className="flex items-center gap-3 text-[22px] font-semibold tracking-[-0.025em]">{title}{tag && <span className="rounded-full bg-sand-2 px-2.5 py-0.5 text-[13px] font-semibold tracking-normal ring-1 ring-black/[.06]">{tag}</span>}</h3>
      <p className="max-w-[440px] text-[15.5px] leading-[1.55] text-mute">{children}</p>
      <div className="min-w-0">{action}</div>
    </li>
  )
}

/* ── the first minute ──────────────────────────────────────── */

function FirstMinute() {
  const steps: { n: string; title: string; text: string; art: ReactNode }[] = [
    { n: '01', title: 'Open it once', text: 'From Applications. There is no window and no Dock icon: anyfmt lives in the menu bar.', art: <div className="flex h-full items-center justify-center"><AppIcon size={96} uid="s1" /></div> },
    { n: '02', title: 'Drag any file, tap Shift', text: 'Mid-drag, tap ⇧ Shift. The wheel opens around your pointer with every format that file can become.', art: <div className="flex h-full items-center justify-center gap-4"><span className="flex h-[78px] w-[62px] items-end rounded-[10px] bg-white p-1.5 shadow-[0_10px_20px_-10px_rgba(0,0,0,.3)] ring-1 ring-black/5"><span className="rounded-[4px] bg-[#FF8A2A] px-1 text-[12px] font-bold uppercase text-ink">heic</span></span><Keycap glyph="⇧" name="Shift" pressed /></div> },
    { n: '03', title: 'Drop on a format', text: 'A new copy appears beside the original, in milliseconds for most photos. The original is never touched.', art: <div className="flex h-full items-center justify-center gap-3 font-mono text-[13px]"><span className="rounded-lg bg-white px-2.5 py-1.5 ring-1 ring-black/10">IMG_0042.heic</span><span className="text-flare">→</span><span className="rounded-lg bg-ink px-2.5 py-1.5 text-white">IMG_0042.jpg</span></div> },
  ]
  return (
    <div className="grid overflow-hidden rounded-[28px] bg-sand lg:grid-cols-3">
      {steps.map((s, i) => (
        <motion.div key={s.n} initial={{ opacity: 0, y: 18 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, amount: 0.4 }} transition={{ duration: 0.7, ease: EASE, delay: i * 0.08 }}
          className={`flex flex-col ${i > 0 ? 'border-t border-line lg:border-l lg:border-t-0' : ''}`}>
          <div className="h-[180px]">{s.art}</div>
          <div className="px-7 pb-8">
            <h3 className="text-[22px] font-semibold tracking-[-0.03em]">{s.title}</h3>
            <p className="mt-2 max-w-[400px] text-[15.5px] leading-[1.55] text-mute">{s.text}</p>
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
      <section id="top" className="relative overflow-hidden bg-fog pb-20 pt-36 lg:pb-28 lg:pt-44">
        <div className="flutes-static pointer-events-none absolute inset-0 opacity-60" />
        <Container className="relative grid items-center gap-16 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
          <div>
            <Eyebrow>Download</Eyebrow>
            <h1 className="mt-6 text-[clamp(48px,6.6vw,104px)] font-semibold leading-[0.94] tracking-[-0.055em]">Get anyfmt.</h1>
            <p className="mt-6 max-w-[480px] text-[19px] leading-[1.5] text-ink-2">One disk image, one drag into Applications. Every engine is inside, so there is nothing else to install.</p>
            <div className="mt-10"><ReleaseButton /></div>
            <dl className="mt-10 grid max-w-[520px] grid-cols-2 gap-x-8 gap-y-4 text-[15px] sm:grid-cols-4">
              {[['Version', SITE.version], ['Download', SITE.dmgSize], ['Chip', 'Apple silicon'], ['macOS', '13 or later']].map(([k, v]) => (
                <div key={k}><dt className="text-[13px] text-mute">{k}</dt><dd className="mt-0.5 font-semibold">{v}</dd></div>
              ))}
            </dl>
            {!SITE.released && <p className="mt-8 flex max-w-[480px] items-baseline gap-2.5 text-[15px] leading-[1.5] text-mute"><span className="h-2 w-2 shrink-0 translate-y-[-1px] rounded-full bg-flare" /><span>The first public build is on its way. <Link to="/changelog" className="font-medium text-ink underline decoration-flare/60 decoration-[1.5px] underline-offset-[3px] outline-none hover:decoration-flare focus-visible:ring-2 focus-visible:ring-flare">Follow the changelog</Link></span></p>}
          </div>
          <DiskImage />
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Ways in</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Four ways to install it.</h2>
          <ul className="mt-12 divide-y divide-line border-y border-line">
            <Way title="Disk image" tag="Easiest" action={<p className="text-[15.5px] text-mute">{SITE.released ? <ArrowLink to="#top" className="text-[16px]">Download the {SITE.dmgSize} .dmg</ArrowLink> : `The ${SITE.dmgSize} .dmg arrives with the first release.`}</p>}>Signed and notarized by Apple. Open it and drag anyfmt into Applications.</Way>
            <Way title="Homebrew" action={<Command cmd={SITE.brew.cask} tone="light" />}>The app, plus the <code className="font-mono text-[14px]">anyfmt</code> command linked onto your PATH.</Way>
            <Way title="Command line only" action={<Command cmd={SITE.brew.cli} tone="light" />}>Just the CLI, its framework and the engines. No app and no menu bar.</Way>
            <Way title="Build from source" action={<ArrowLink to="/open-source" className="text-[16px]">Clone and build</ArrowLink>}>AGPL-3.0 and free. You need Xcode 16 and Rust, and <code className="font-mono text-[14px]">make</code> does the rest.</Way>
          </ul>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>After installing</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Your first minute with it.</h2>
          <div className="mt-14"><FirstMinute /></div>
          <p className="mt-8 text-[16px] text-mute">Not a dragger? Select files in Finder and use <strong className="text-ink">Services › Open in anyfmt Wheel</strong>, or press <strong className="text-ink">⌃⌥Space</strong> for a ring you can drop onto. <ArrowLink to="/docs/keyboard">All the ways in</ArrowLink></p>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div className="lg:sticky lg:top-28 lg:self-start">
            <Eyebrow>Permissions, honestly</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em] [text-wrap:balance]">The wheel needs none.</h2>
            <p className="mt-6 max-w-[400px] text-[16.5px] leading-[1.55] text-mute">Two extras ask for more, and both stay off until you switch them on.</p>
          </div>
          <ul className="divide-y divide-line rounded-[28px] bg-white px-6 ring-1 ring-black/[.07] sm:px-8">
            {PERMS.map(([what, perm, why]) => (
              <li key={what} className="grid gap-2 py-6 sm:grid-cols-[1fr_auto] sm:gap-6">
                <div>
                  <p className="text-[17px] font-semibold tracking-[-0.01em]">{what}</p>
                  <p className="mt-1.5 text-[15px] leading-[1.55] text-mute">{why}</p>
                </div>
                <p className={`h-fit w-fit rounded-full px-3 py-1 text-[13px] font-semibold ${perm === 'None' ? 'bg-ink text-white' : 'bg-sand-2'}`}>{perm === 'None' ? <span className="flex items-center gap-1.5"><Check size={13} weight="bold" />None</span> : perm}</p>
              </li>
            ))}
          </ul>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div className="lg:sticky lg:top-28 lg:self-start">
            <Eyebrow>What's inside</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em] [text-wrap:balance]">{SITE.appSize} installed, everything included.</h2>
            <p className="mt-6 max-w-[400px] text-[16.5px] leading-[1.55] text-mute">Built from pinned, checksummed sources. Every licence ships in the app with a written source offer. {catalog.counts.routes} routes need nothing from Homebrew.</p>
          </div>
          {/* a table from sm up; on a phone each engine is a two-line row */}
          <div className="overflow-hidden rounded-[28px] ring-1 ring-line">
            <table className="hidden w-full text-left text-[15px] sm:table">
              <thead className="bg-sand text-[13px] text-mute-2"><tr><th className="px-6 py-3 font-medium">Engine</th><th className="px-6 py-3 font-medium">Version</th><th className="px-6 py-3 font-medium">Licence</th><th className="px-6 py-3 font-medium">For</th></tr></thead>
              <tbody>
                {BUNDLED.map((e) => (
                  <tr key={e.name} className="border-t border-line"><td className="px-6 py-3 font-semibold">{e.name}</td><td className="px-6 py-3 font-mono text-[13.5px]">{e.version}</td><td className="px-6 py-3 text-mute">{e.licence}</td><td className="px-6 py-3 text-mute">{e.does}</td></tr>
                ))}
              </tbody>
            </table>
            <ul className="divide-y divide-line sm:hidden">
              {BUNDLED.map((e) => (
                <li key={e.name} className="px-5 py-3.5">
                  <p className="flex items-baseline justify-between gap-3"><span className="text-[15.5px] font-semibold">{e.name}</span><span className="font-mono text-[13px] text-mute-2">{e.version}</span></p>
                  <p className="mt-0.5 text-[14px] text-mute">{e.does} · {e.licence}</p>
                </li>
              ))}
            </ul>
          </div>
        </Container>
      </section>
    </Page>
  )
}
