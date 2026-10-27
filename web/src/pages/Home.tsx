/**
 * Home: the Flare landing. Hero over the diagonal flute shader, a scroll-lit statement, the real
 * gesture to try, the three keys, live numbers from the app's own schema, and the ways in.
 */
import NumberFlow from '@number-flow/react'
import { AnimatePresence, motion, useInView, useReducedMotion, useScroll, useTransform, type MotionValue } from 'motion/react'
import { Fragment, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { ArrowLink, Badge, DownloadButton, GitHubButton } from '../components/Buttons'
import { Flutes } from '../components/Flutes'
import { Page } from '../components/Page'
import { Playground } from '../components/Playground'
import { Command, Eyebrow, Keycap } from '../components/ui'
import catalog from '../data/catalog.json'
import { FAQ_FREE } from '../data/copy'
import { useHead } from '../lib/head'
import { EASE } from '../lib/hooks'
import { SITE } from '../lib/site'

const rise = (i: number) => ({
  initial: { opacity: 0, y: 14, filter: 'blur(6px)' },
  animate: { opacity: 1, y: 0, filter: 'blur(0px)' },
  transition: { duration: 0.9, ease: EASE, delay: 0.25 + i * 0.08 },
})

const ENGINES: [string, string][] = [['ffmpeg', 'Video and audio'], ['ImageIO', 'Photos and images'], ['resvg', 'Vector graphics'], ['PDFKit', 'PDF pages'], ['VideoToolbox', 'Hardware encoding'], ['Vision', 'Backgrounds and QR']]

function Hero() {
  const [tip, setTip] = useState(-1)
  return (
    <section className="relative flex min-h-[100svh] flex-col overflow-hidden bg-fog">
      <Flutes className="pointer-events-none absolute inset-0" />
      <div className="relative z-10 mx-auto flex w-full max-w-[1440px] flex-1 flex-col justify-center px-5 pb-10 pt-36 sm:px-10 lg:px-14">
        <motion.div {...rise(0)}><Badge to="/changelog">Open source, for macOS · {SITE.version}</Badge></motion.div>
        <h1 className="mt-7 max-w-[860px] text-[clamp(44px,6.6vw,104px)] font-semibold leading-[0.97] tracking-[-0.05em] [text-wrap:balance]">
          <motion.span {...rise(1)} className="block">Any file, any format,</motion.span>
          <motion.span {...rise(2)} className="block">one drag away.</motion.span>
        </h1>
        <motion.p {...rise(3)} className="mt-7 max-w-[560px] text-[clamp(17px,1.45vw,21px)] leading-[1.5] text-ink-2 [text-wrap:pretty]">
          Drag a file, tap Shift, and drop it on the format you want. anyfmt converts it right there on your Mac, offline, and leaves the original untouched.
        </motion.p>
        <motion.div {...rise(4)} className="mt-10 flex flex-wrap items-center gap-4">
          <DownloadButton />
          <a href="#try" className="group flex h-14 items-center gap-2 rounded-full px-2 text-base font-medium outline-none focus-visible:ring-2 focus-visible:ring-ink sm:px-4">
            <span className="link-line">Try the gesture here</span>
            <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden className="transition-transform duration-500 group-hover:translate-y-1"><path d="M7 2v10M3 8l4 4 4-4" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </a>
        </motion.div>
      </div>
      <motion.div {...rise(6)} className="relative z-10 mx-auto w-full max-w-[1440px] px-5 pb-10 sm:px-10 lg:px-14">
        <p className="text-[15px] text-mute">Engines inside, nothing to install</p>
        <ul className="mt-5 flex flex-wrap items-center gap-x-10 gap-y-4">
          {ENGINES.map(([e, d], i) => (
            <li key={e} className="relative" onPointerEnter={() => setTip(i)} onPointerLeave={() => setTip(-1)}>
              <span className={`text-[22px] font-semibold tracking-[-0.03em] transition-colors duration-300 ${tip === i ? 'text-ink' : 'text-mute-2'}`}>{e}</span>
              <AnimatePresence>
                {tip === i && (
                  <motion.span initial={{ opacity: 0, y: 6, filter: 'blur(4px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0, y: 4 }} transition={{ duration: 0.3, ease: EASE }}
                    className="absolute bottom-full left-0 mb-2 whitespace-nowrap rounded-full bg-ink px-3 py-1 text-[12px] font-medium text-white">{d}</motion.span>
                )}
              </AnimatePresence>
            </li>
          ))}
        </ul>
      </motion.div>
    </section>
  )
}

const STATEMENT = 'Most converters make you open an app or upload the file first. anyfmt works inside the drag you were already making.'

function W({ children, p, i, n }: { children: string; p: MotionValue<number>; i: number; n: number }) {
  const s = (i / n) * 0.8
  // starts at a readable grey (over 3:1 at this size) and inks in as you scroll
  const color = useTransform(p, [s, s + 0.12], ['#8A857F', '#0A0A0A'])
  return <motion.span style={{ color }}>{children}</motion.span>
}

function Statement() {
  const ref = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 85%', 'end 45%'] })
  const words = STATEMENT.split(' ')
  return (
    <section className="bg-white px-5 pb-24 pt-28 sm:px-10 lg:pb-32 lg:pt-40">
      <Eyebrow className="justify-center">What it does</Eyebrow>
      <div ref={ref} className="mx-auto mt-8 max-w-[1240px]">
        <p className="text-center text-[clamp(36px,5.6vw,88px)] font-semibold leading-[1.02] tracking-[-0.045em] [text-wrap:balance]" aria-label={STATEMENT}>
          {words.map((w, i) => <Fragment key={i}>{reduce ? <span>{w}</span> : <W p={scrollYProgress} i={i} n={words.length}>{w}</W>}{i < words.length - 1 ? ' ' : ''}</Fragment>)}
        </p>
      </div>
    </section>
  )
}

function TrySection() {
  return (
    <section id="try" className="scroll-mt-24 bg-white px-5 pb-24 sm:px-10 lg:px-14 lg:pb-32">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-10 flex flex-wrap items-end justify-between gap-6">
          <h2 className="max-w-[640px] text-[clamp(32px,3.8vw,56px)] font-semibold leading-[1.02] tracking-[-0.04em] [text-wrap:balance]">Go on, try the gesture.</h2>
          <p className="max-w-[420px] text-[17px] leading-[1.5] text-mute">This is the real interaction, minus your files. On a keyboard, focus a file and press Enter, then the arrow keys.</p>
        </div>
        <Playground />
      </div>
    </section>
  )
}

const KEYS = [
  { k: '⇧', name: 'Shift', verb: 'Convert', items: ['GIF', 'MP4', 'PDF', 'JPG', 'MP3', 'WEBP', 'EPUB', 'PNG'], to: '/formats' },
  { k: '⌘', name: 'Command', verb: 'Edit', items: ['Compress', 'Trim', 'Crop', 'Resize', 'Remove background', 'Strip metadata'], to: '/docs/tools' },
  { k: '⌃', name: 'Control', verb: 'Act', items: ['AirDrop', 'Float', 'Copy', 'Move', 'Copy path', 'Terminal'], to: '/docs/actions' },
]

function KeysSection() {
  const [on, setOn] = useState(-1)
  return (
    <section id="keys" className="scroll-mt-24 bg-sand px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto max-w-[1440px]">
        <Eyebrow>Three keys</Eyebrow>
        <h2 className="mt-6 max-w-[900px] text-[clamp(36px,4.6vw,72px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">The key you tap mid‑drag picks the wheel.</h2>
        <div className="mt-16 grid gap-5 md:grid-cols-3">
          {KEYS.map((k, i) => (
            <Link key={k.name} to={k.to} onPointerEnter={() => setOn(i)} onPointerLeave={() => setOn(-1)} onFocus={() => setOn(i)} onBlur={() => setOn(-1)}
              className="group rounded-[28px] bg-white p-8 outline-none focus-visible:ring-2 focus-visible:ring-flare">
              <span className="md:hidden"><Keycap glyph={k.k} name={k.name} pressed={on === i} size="md" /></span>
              <span className="hidden md:block"><Keycap glyph={k.k} name={k.name} pressed={on === i} size="lg" /></span>
              <p className="mt-8 text-[30px] font-semibold tracking-[-0.03em]">{k.verb}</p>
              <ul className="mt-4 flex flex-wrap gap-2">
                {k.items.map((t, j) => (
                  <li key={t} className="rounded-full px-3 py-1.5 text-[14px] font-medium ring-1 ring-black/10 transition-[background-color,color,transform] duration-300"
                    style={{ transitionDelay: on === i ? `${j * 40}ms` : '0ms', background: on === i ? '#0A0A0A' : 'transparent', color: on === i ? '#fff' : '#0A0A0A', transform: on === i ? 'translateY(-2px)' : 'none' }}>{t}</li>
                ))}
              </ul>
            </Link>
          ))}
        </div>
      </div>
    </section>
  )
}

function Numbers() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.4 })
  const c = catalog.counts
  const stats: [number, string, string][] = [
    [c.routes, 'Conversion routes', 'Each one run on a real file and checked before it ships.'],
    [c.tools, 'Editing tools', 'Compress to a target size, trim, crop, redact, merge.'],
    [0, 'Uploads', 'Conversions happen on your Mac, offline.'],
  ]
  return (
    <section id="numbers" ref={ref} className="scroll-mt-24 bg-white px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto grid max-w-[1440px] gap-12 md:grid-cols-3 md:gap-0">
        {stats.map(([n, l, d], i) => (
          <div key={l} className={`md:px-10 ${i > 0 ? 'md:border-l md:border-line' : 'md:pl-0'}`}>
            <p className="text-[clamp(72px,8vw,128px)] font-semibold leading-none tracking-[-0.06em]">
              <NumberFlow value={seen ? n : 0} transformTiming={{ duration: 1400, easing: 'cubic-bezier(0.22,1,0.36,1)' }} spinTiming={{ duration: 1400, easing: 'cubic-bezier(0.22,1,0.36,1)' }} />
            </p>
            <p className="mt-4 text-[20px] font-semibold tracking-[-0.02em]">{l}</p>
            <p className="mt-2 max-w-[320px] text-[16px] leading-[1.5] text-mute">{d}</p>
          </div>
        ))}
      </div>
      <div className="mx-auto mt-14 max-w-[1440px]"><ArrowLink to="/formats" className="text-[17px]">See all {c.routes} routes</ArrowLink></div>
    </section>
  )
}

/* The ways in: three doors to the rest of the site, each with its own little machine. */
function Doors() {
  return (
    <section className="bg-sand px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto max-w-[1440px]">
        <Eyebrow>Beyond the wheel</Eyebrow>
        <h2 className="mt-6 max-w-[880px] text-[clamp(36px,4.6vw,72px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">The same routes, from Terminal and from your agent.</h2>
        <div className="mt-14 grid gap-5 lg:grid-cols-[1.25fr_1fr]">
          <div className="group relative flex min-h-[420px] flex-col justify-between overflow-hidden rounded-[28px] bg-night p-8 text-white sm:p-10">
            <div className="flutes-static-dark pointer-events-none absolute inset-0 opacity-70 transition-opacity duration-700 group-hover:opacity-100" />
            <div className="relative">
              <p className="text-[14px] font-semibold text-white/70">For agents</p>
              <p className="mt-4 max-w-[520px] text-[clamp(28px,3vw,44px)] font-semibold leading-[1.02] tracking-[-0.04em]">Your agent converts files too. On your Mac, through MCP.</p>
            </div>
            <div className="relative mt-10 space-y-3">
              <Command cmd="claude mcp add anyfmt -- anyfmt mcp" />
              <p className="font-mono text-[12.5px] leading-relaxed text-white/55">→ convert · estimate · formats · options · presets · run_tool · targets</p>
              <ArrowLink to="/docs/mcp" className="pt-3 text-white">Set it up</ArrowLink>
            </div>
          </div>
          <div className="grid gap-5">
            <Link to="/docs/cli" className="group flex flex-col justify-between rounded-[28px] bg-white p-8 outline-none focus-visible:ring-2 focus-visible:ring-flare">
              <p className="text-[14px] font-semibold text-mute-2">Command line</p>
              <div className="mt-6 overflow-x-auto whitespace-nowrap rounded-2xl bg-sand p-4 font-mono text-[12.5px] leading-[1.7] text-ink no-scrollbar">
                <p><span className="text-flare">$</span> anyfmt convert IMG_0042.heic --to jpg</p>
                <p className="text-mute-2">{'{"event":"progress","fraction":0.62}'}</p>
                <p className="text-mute-2">{'{"event":"output","path":"IMG_0042.jpg"}'}</p>
              </div>
              <p className="mt-6 text-[22px] font-semibold tracking-[-0.03em]">Every command takes --json and exits with a documented code.</p>
            </Link>
            <Link to="/compare" className="group flex flex-col justify-between rounded-[28px] bg-white p-8 outline-none focus-visible:ring-2 focus-visible:ring-flare">
              <p className="text-[14px] font-semibold text-mute-2">Choosing a converter?</p>
              <p className="mt-6 text-[22px] font-semibold leading-[1.15] tracking-[-0.03em]">Honest side-by-sides with Tangerine, convt, Permute and the web upload sites.</p>
              <span className="mt-6 inline-flex items-center gap-2 font-medium"><span className="link-line">Compare</span><span aria-hidden>→</span></span>
            </Link>
          </div>
        </div>
      </div>
    </section>
  )
}

const FAQ: [string, string][] = [
  FAQ_FREE,
  ['Does it upload my files?', 'No. Conversions happen on your Mac, offline. anyfmt has no account and no server, so your files never leave it.'],
  ['Will it overwrite my original?', 'Never. Every conversion and edit writes a new copy beside the file you started with.'],
  ['What do I need?', `A Mac with ${SITE.requires}. The engines ship inside the app, so there's nothing else to install.`],
  ['Can I script it?', 'Yes. The anyfmt command in Terminal runs the same routes the wheel does, with --json output and an MCP server for agents.'],
]

function Faq() {
  const [open, setOpen] = useState(0)
  return (
    <section id="faq" className="scroll-mt-24 bg-white px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto grid max-w-[1440px] gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
        <div>
          <Eyebrow>Questions</Eyebrow>
          <h2 className="mt-6 text-[clamp(36px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Before you download.</h2>
        </div>
        <ul className="divide-y divide-line border-y border-line">
          {FAQ.map(([q, a], i) => (
            <li key={q}>
              <button type="button" aria-expanded={open === i} onClick={() => setOpen(open === i ? -1 : i)} className="group flex w-full items-center justify-between gap-6 py-6 text-left text-[clamp(19px,1.6vw,24px)] font-medium tracking-[-0.02em] outline-none focus-visible:ring-2 focus-visible:ring-ink">
                {q}
                <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full transition-[background-color,transform] duration-500 ${open === i ? 'rotate-45 bg-flare text-white' : 'bg-sand-2 text-ink group-hover:bg-volt'}`}>
                  <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden><path d="M7 1.5v11M1.5 7h11" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>
                </span>
              </button>
              <AnimatePresence initial={false}>
                {open === i && (
                  <motion.p initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.45, ease: EASE }}
                    className="max-w-[620px] overflow-hidden text-[17px] leading-[1.55] text-mute"><span className="block pb-6">{a}</span></motion.p>
                )}
              </AnimatePresence>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

function FinalCta() {
  return (
    <section id="download" className="bg-white">
      <div className="mx-auto max-w-[1440px] px-5 sm:px-10 lg:px-14">
      <div className="relative overflow-hidden rounded-[28px] bg-night">
        <Flutes variant="dark" corner="bl" className="pointer-events-none absolute inset-0" />
        <div className="relative mx-auto flex min-h-[640px] max-w-[1440px] flex-col items-end justify-center px-6 py-24 text-right sm:px-14">
          <h2 className="max-w-[820px] text-[clamp(44px,6vw,96px)] font-semibold leading-[0.97] tracking-[-0.05em] text-white [text-wrap:balance]">Try it on the next file you drag.</h2>
          <p className="mt-6 max-w-[460px] text-[18px] leading-[1.5] text-white/70">No account, no uploads, nothing to set up. It lives in your menu bar until you need it.</p>
          <div className="mt-10 flex flex-wrap justify-end gap-3"><GitHubButton tone="dark" /><DownloadButton tone="light" /></div>
        </div>
      </div>
      </div>
    </section>
  )
}

export default function Home() {
  useHead({
    title: 'anyfmt: any file, any format, one drag away',
    description: SITE.description,
    path: '/',
    jsonLd: [
      {
        '@context': 'https://schema.org', '@type': 'SoftwareApplication', name: 'anyfmt', applicationCategory: 'UtilitiesApplication', operatingSystem: 'macOS 13 or later (Apple silicon)',
        description: SITE.description, url: SITE.url, softwareVersion: SITE.version, license: 'https://www.gnu.org/licenses/agpl-3.0.html',
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD', description: 'Open source; build from source for free' },
        featureList: [`${catalog.counts.routes} conversion routes`, `${catalog.counts.tools} editing tools`, 'Works offline', 'Command line tool and MCP server'],
      },
      { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: FAQ.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
    ],
  })
  return (
    <Page>
      <Hero />
      <Statement />
      <TrySection />
      <KeysSection />
      <Numbers />
      <Doors />
      <Faq />
      <FinalCta />
    </Page>
  )
}
