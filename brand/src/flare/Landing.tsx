/**
 * Flare: anyfmt in a bright editorial layout. Hero background is the `shaders` stack turned
 * diagonal (FluteShader), in light for the hero and dark for the final call to action.
 */

import '@fontsource-variable/inter-tight'
import '@fontsource-variable/bricolage-grotesque/wdth.css'
import NumberFlow from '@number-flow/react'
import { AnimatePresence, motion, useInView, useReducedMotion, useScroll, useTransform, type MotionValue } from 'motion/react'
import { Fragment, useEffect, useRef, useState, type ReactNode } from 'react'
import { Badge, ButtonStyles, DownloadButton, GitHubButton, NavDownload } from './Buttons'
import { FluteShader } from './FluteShader'
import { Playground } from './Playground'

const EASE = [0.22, 1, 0.36, 1] as const
const go = (id: string) => document.getElementById(id)?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })

const rise = (i: number) => ({
  initial: { opacity: 0, y: 14, filter: 'blur(6px)' },
  animate: { opacity: 1, y: 0, filter: 'blur(0px)' },
  transition: { duration: 0.9, ease: EASE, delay: 0.25 + i * 0.08 },
})

function Logo({ className = '' }: { className?: string }) {
  return (
    <span className={`font-['Bricolage_Grotesque_Variable',sans-serif] text-[32px] font-bold leading-none tracking-[-0.04em] text-[#0A0A0A] [font-variation-settings:'wdth'_75] ${className}`}>
      anyfmt<span className="text-[#FF4A14]">.</span>
    </span>
  )
}

/* ───────────────────────────── Nav ───────────────────────────── */

const LINKS: [string, string][] = [['Try it', 'try'], ['Keys', 'keys'], ['Formats', 'numbers'], ['FAQ', 'faq']]

function Nav() {
  const [open, setOpen] = useState(false)
  return (
    <header className="absolute inset-x-0 top-0 z-30">
      <nav className="mx-auto flex max-w-[1440px] items-center justify-between px-5 pt-6 sm:px-10 lg:px-14 lg:pt-8">
        <div className="flex items-center gap-12">
          <a href="#" onClick={(e) => { e.preventDefault(); window.scrollTo({ top: 0, behavior: 'smooth' }) }} aria-label="anyfmt home"><Logo /></a>
          <ul className="hidden items-center gap-9 md:flex">
            {LINKS.map(([l, id]) => (
              <li key={id}>
                <button type="button" onClick={() => go(id)} className="link-line relative py-1 text-[16px] text-[#0A0A0A] outline-none focus-visible:ring-2 focus-visible:ring-black">{l}</button>
              </li>
            ))}
          </ul>
        </div>
        <div className="flex items-center gap-3">
          <span className="hidden lg:inline-flex"><GitHubButton /></span>
          <span className="hidden sm:inline-flex"><NavDownload onClick={() => go('download')} /></span>
          <button type="button" onClick={() => setOpen(true)} aria-label="Open menu" className="flex h-12 items-center gap-2 rounded-full bg-[#0A0A0A] px-5 text-[15px] font-medium text-white sm:hidden">Menu</button>
        </div>
      </nav>
      <AnimatePresence>
        {open && (
          <motion.div className="fixed inset-0 z-50 sm:hidden" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <button type="button" aria-label="Close menu" onClick={() => setOpen(false)} className="absolute inset-0 bg-black/50" />
            <motion.div initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }} transition={{ duration: 0.5, ease: [0.32, 0.72, 0, 1] }}
              className="absolute inset-x-3 bottom-3 rounded-[28px] bg-white p-6">
              <div className="flex items-center justify-between"><Logo className="text-[28px]" /><button type="button" onClick={() => setOpen(false)} className="rounded-full bg-[#F1EEEA] px-4 py-2 text-[14px] font-medium">Close</button></div>
              <ul className="mt-8 flex flex-col gap-2">
                {LINKS.map(([l, id], i) => (
                  <motion.li key={id} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, ease: EASE, delay: 0.1 + i * 0.05 }}>
                    <button type="button" onClick={() => { setOpen(false); setTimeout(() => go(id), 300) }} className="py-1 text-[32px] font-medium tracking-[-0.03em]">{l}</button>
                  </motion.li>
                ))}
              </ul>
              <div className="mt-8 flex flex-col gap-3"><DownloadButton /><GitHubButton /></div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </header>
  )
}

/* ───────────────────────────── Hero ───────────────────────────── */

const ENGINES: [string, string][] = [['ffmpeg', 'Video and audio'], ['pandoc', 'Documents and ebooks'], ['ImageIO', 'Photos and images'], ['AVFoundation', 'Apple media'], ['VideoToolbox', 'Hardware encoding'], ['Vision', 'Backgrounds and QR']]

function Hero() {
  const [tip, setTip] = useState(-1)
  return (
    <section className="relative flex min-h-[100svh] flex-col overflow-hidden bg-[#EFEFEF]">
      <FluteShader className="pointer-events-none absolute inset-0" />
      <Nav />
      <div className="relative z-10 mx-auto flex w-full max-w-[1440px] flex-1 flex-col justify-center px-5 pb-10 pt-36 sm:px-10 lg:px-14">
        <motion.div {...rise(0)}><Badge onClick={() => go('try')}>Free and open source, for macOS</Badge></motion.div>
        <h1 className="mt-7 max-w-[860px] text-[clamp(44px,6.6vw,104px)] font-semibold leading-[0.97] tracking-[-0.05em] text-[#0A0A0A] [text-wrap:balance]">
          <motion.span {...rise(1)} className="block">Any file, any format,</motion.span>
          <motion.span {...rise(2)} className="block">one drag away.</motion.span>
        </h1>
        <motion.p {...rise(3)} className="mt-7 max-w-[560px] text-[clamp(17px,1.45vw,21px)] leading-[1.5] text-[#1A1A1A] [text-wrap:pretty]">
          Drag a file, tap Shift, and drop it on the format you want. anyfmt converts it right there on your Mac, offline, and leaves the original untouched.
        </motion.p>
        <motion.div {...rise(4)} className="mt-10 flex flex-wrap items-center gap-4">
          <DownloadButton />
          <button type="button" onClick={() => go('try')} className="group flex h-14 items-center gap-2 rounded-full px-4 text-base font-medium text-[#0A0A0A] outline-none focus-visible:ring-2 focus-visible:ring-black">
            <span className="link-line relative">Try the gesture here</span>
            <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden className="transition-transform duration-500 group-hover:translate-y-1"><path d="M7 2v10M3 8l4 4 4-4" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </button>
        </motion.div>
      </div>
      <motion.div {...rise(6)} className="relative z-10 mx-auto w-full max-w-[1440px] px-5 pb-10 sm:px-10 lg:px-14">
        <p className="text-[15px] text-[#3A3A3A]">Engines inside, nothing to install</p>
        <ul className="mt-5 flex flex-wrap items-center gap-x-10 gap-y-4">
          {ENGINES.map(([e, d], i) => (
            <li key={e} className="relative" onPointerEnter={() => setTip(i)} onPointerLeave={() => setTip(-1)}>
              <span className={`text-[22px] font-semibold tracking-[-0.03em] transition-colors duration-300 ${tip === i ? 'text-[#0A0A0A]' : 'text-[#0A0A0A]/45'}`}>{e}</span>
              <AnimatePresence>
                {tip === i && (
                  <motion.span initial={{ opacity: 0, y: 6, filter: 'blur(4px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} exit={{ opacity: 0, y: 4 }} transition={{ duration: 0.3, ease: EASE }}
                    className="absolute bottom-full left-0 mb-2 whitespace-nowrap rounded-full bg-[#0A0A0A] px-3 py-1 text-[12px] font-medium text-white">{d}</motion.span>
                )}
              </AnimatePresence>
            </li>
          ))}
        </ul>
      </motion.div>
    </section>
  )
}

/* ───────────────────────────── Statement ───────────────────────────── */

const STATEMENT = 'Other converters want your file before they help. anyfmt meets it where it already is.'

function W({ children, p, i, n }: { children: string; p: MotionValue<number>; i: number; n: number }) {
  const s = (i / n) * 0.8
  const color = useTransform(p, [s, s + 0.12], ['#CFCBC6', '#0A0A0A'])
  return <motion.span style={{ color }}>{children}</motion.span>
}

function Statement() {
  const ref = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start 85%', 'end 45%'] })
  const words = STATEMENT.split(' ')
  return (
    <section className="bg-white px-5 pb-24 pt-28 sm:px-10 lg:pb-32 lg:pt-40">
      <p className="flex items-center justify-center gap-3 text-[18px] text-[#0A0A0A]"><span className="h-2.5 w-2.5 bg-[#0A0A0A]" />What it does</p>
      <div ref={ref} className="mx-auto mt-8 max-w-[1240px]">
        <p className="text-center text-[clamp(36px,5.6vw,88px)] font-semibold leading-[1.02] tracking-[-0.045em] [text-wrap:balance]" aria-label={STATEMENT}>
          {words.map((w, i) => <Fragment key={i}>{reduce ? <span>{w}</span> : <W p={scrollYProgress} i={i} n={words.length}>{w}</W>}{i < words.length - 1 ? ' ' : ''}</Fragment>)}
        </p>
      </div>
    </section>
  )
}

/* ───────────────────────────── Try it ───────────────────────────── */

function TrySection() {
  return (
    <section id="try" className="scroll-mt-6 bg-white px-5 pb-24 sm:px-10 lg:px-14 lg:pb-32">
      <div className="mx-auto max-w-[1440px]">
        <div className="mb-10 flex flex-wrap items-end justify-between gap-6">
          <h2 className="max-w-[640px] text-[clamp(32px,3.8vw,56px)] font-semibold leading-[1.02] tracking-[-0.04em]">Go on, try the gesture.</h2>
          <p className="max-w-[420px] text-[17px] leading-[1.5] text-[#3A3A3A]">This is the real interaction, minus your files. On a keyboard, focus a file and press Enter, then the arrow keys.</p>
        </div>
        <Playground />
      </div>
    </section>
  )
}

/* ───────────────────────────── Keys ───────────────────────────── */

const KEYS = [
  { k: '⇧', name: 'Shift', verb: 'Convert', items: ['GIF', 'MP4', 'PDF', 'JPG', 'MP3', 'WEBP', 'EPUB', 'PNG'] },
  { k: '⌘', name: 'Command', verb: 'Edit', items: ['Compress', 'Trim', 'Crop', 'Resize', 'Remove background', 'Strip metadata'] },
  { k: '⌃', name: 'Control', verb: 'Act', items: ['AirDrop', 'Float', 'Copy', 'Move', 'Copy path', 'Terminal'] },
]

function KeysSection() {
  const [on, setOn] = useState(-1)
  return (
    <section id="keys" className="scroll-mt-6 bg-[#F4F2EF] px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto max-w-[1440px]">
        <p className="flex items-center gap-3 text-[18px]"><span className="h-2.5 w-2.5 bg-[#0A0A0A]" />Three keys</p>
        <h2 className="mt-6 max-w-[900px] text-[clamp(36px,4.6vw,72px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">One drag. Three keys. Every file you own.</h2>
        <div className="mt-16 grid gap-5 md:grid-cols-3">
          {KEYS.map((k, i) => (
            <div key={k.name} onPointerEnter={() => setOn(i)} onPointerLeave={() => setOn(-1)} className="group rounded-[28px] bg-white p-8">
              <div className={`flex h-[140px] w-[200px] flex-col justify-between rounded-[22px] bg-[#FBFAF8] p-5 ring-1 ring-black/5 transition-[transform,box-shadow] duration-200 ${on === i ? 'translate-y-[5px] shadow-[0_1px_0_#D9D4CE,0_2px_6px_rgba(0,0,0,.06)]' : 'shadow-[0_6px_0_#D9D4CE,0_16px_30px_-12px_rgba(0,0,0,.18)]'}`}>
                <span className="text-[40px] leading-none">{k.k}</span>
                <span className="text-[15px] font-medium text-[#3A3A3A]">{k.name}</span>
              </div>
              <p className="mt-8 text-[30px] font-semibold tracking-[-0.03em]">{k.verb}</p>
              <ul className="mt-4 flex flex-wrap gap-2">
                {k.items.map((t, j) => (
                  <li key={t} className="rounded-full px-3 py-1.5 text-[14px] font-medium ring-1 ring-black/10 transition-[background-color,color,transform] duration-300"
                    style={{ transitionDelay: on === i ? `${j * 40}ms` : '0ms', background: on === i ? '#0A0A0A' : 'transparent', color: on === i ? '#fff' : '#0A0A0A', transform: on === i ? 'translateY(-2px)' : 'none' }}>{t}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ───────────────────────────── Numbers ───────────────────────────── */

function Numbers() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.4 })
  const stats: [number, string, string][] = [[793, 'Conversion routes', 'Each run on a real file and checked before it ships.'], [26, 'Editing tools', 'Compress to a target size, trim, crop, redact, merge.'], [0, 'Uploads', 'Everything happens on your Mac, offline.']]
  return (
    <section id="numbers" ref={ref} className="scroll-mt-6 bg-white px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto grid max-w-[1440px] gap-12 md:grid-cols-3 md:gap-0">
        {stats.map(([n, l, d], i) => (
          <div key={l} className={`md:px-10 ${i > 0 ? 'md:border-l md:border-black/10' : 'md:pl-0'}`}>
            <p className="text-[clamp(72px,8vw,128px)] font-semibold leading-none tracking-[-0.06em]">
              <NumberFlow value={seen ? n : 0} transformTiming={{ duration: 1400, easing: 'cubic-bezier(0.22,1,0.36,1)' }} spinTiming={{ duration: 1400, easing: 'cubic-bezier(0.22,1,0.36,1)' }} />
            </p>
            <p className="mt-4 text-[20px] font-semibold tracking-[-0.02em]">{l}</p>
            <p className="mt-2 max-w-[320px] text-[16px] leading-[1.5] text-[#3A3A3A]">{d}</p>
          </div>
        ))}
      </div>
    </section>
  )
}

/* ───────────────────────────── FAQ ───────────────────────────── */

const FAQ: [string, string][] = [
  ['Is it really free?', 'Yes. Every conversion, tool and action that runs on your Mac is free, commercial use included.'],
  ['Does it upload my files?', 'No. Work happens on your Mac, offline. Share links are the only thing that leaves, and only when you make one.'],
  ['Will it overwrite my original?', 'Never. Every conversion and edit writes a new copy beside the file you started with.'],
  ['What do I need?', 'A Mac with Apple silicon on macOS 13 Ventura or later. The engines ship inside the app.'],
  ['Can I script it?', 'Yes. The anyfmt command in Terminal runs the same routes the wheel does.'],
]

function Faq() {
  const [open, setOpen] = useState(0)
  return (
    <section id="faq" className="scroll-mt-6 bg-[#F4F2EF] px-5 py-24 sm:px-10 lg:px-14 lg:py-32">
      <div className="mx-auto grid max-w-[1440px] gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
        <div>
          <p className="flex items-center gap-3 text-[18px]"><span className="h-2.5 w-2.5 bg-[#0A0A0A]" />Questions</p>
          <h2 className="mt-6 text-[clamp(36px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Short answers.</h2>
        </div>
        <ul className="divide-y divide-black/10 border-y border-black/10">
          {FAQ.map(([q, a], i) => (
            <li key={q}>
              <button type="button" aria-expanded={open === i} onClick={() => setOpen(open === i ? -1 : i)} className="group flex w-full items-center justify-between gap-6 py-6 text-left text-[clamp(19px,1.6vw,24px)] font-medium tracking-[-0.02em] outline-none focus-visible:ring-2 focus-visible:ring-black">
                {q}
                <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full transition-[background-color,transform] duration-500 ${open === i ? 'rotate-45 bg-[#FF4A14] text-white' : 'bg-white text-black group-hover:bg-[#E4FF3A]'}`}>
                  <svg width="14" height="14" viewBox="0 0 14 14" aria-hidden><path d="M7 1.5v11M1.5 7h11" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" /></svg>
                </span>
              </button>
              <AnimatePresence initial={false}>
                {open === i && (
                  <motion.p initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.45, ease: EASE }}
                    className="max-w-[620px] overflow-hidden text-[17px] leading-[1.55] text-[#3A3A3A]"><span className="block pb-6">{a}</span></motion.p>
                )}
              </AnimatePresence>
            </li>
          ))}
        </ul>
      </div>
    </section>
  )
}

/* ───────────────────────────── Final CTA ───────────────────────────── */

function FinalCta() {
  return (
    <section id="download" className="bg-white p-3 sm:p-5">
      <div className="relative overflow-hidden rounded-[32px] bg-[#0A0A0A]">
        <FluteShader variant="dark" corner="bl" className="pointer-events-none absolute inset-0" />
        <div className="relative mx-auto flex min-h-[640px] max-w-[1440px] flex-col items-end justify-center px-6 py-24 text-right sm:px-14">
          <h2 className="max-w-[820px] text-[clamp(44px,6vw,96px)] font-semibold leading-[0.97] tracking-[-0.05em] text-white [text-wrap:balance]">Your next drag already knows the way.</h2>
          <p className="mt-6 max-w-[460px] text-[18px] leading-[1.5] text-white/70">Free, no account, open source. Install it once and every file you touch learns a new trick.</p>
          <div className="mt-10 flex flex-wrap justify-end gap-3"><GitHubButton /><DownloadButton tone="light" /></div>
        </div>
      </div>
    </section>
  )
}

function FooterCol({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div>
      <p className="flex items-center gap-2.5 text-[14px] text-[#6A6A6A]"><span className="h-2 w-2 bg-[#0A0A0A]" />{title}</p>
      <ul className="mt-5 flex flex-col gap-3 text-[16px]">{children}</ul>
    </div>
  )
}

function Footer() {
  return (
    <footer className="bg-white px-5 pb-8 pt-20 sm:px-10 lg:px-14">
      <div className="mx-auto max-w-[1440px]">
        <div className="grid gap-12 border-t border-black/10 pt-12 sm:grid-cols-2 lg:grid-cols-[minmax(0,1.5fr)_repeat(3,minmax(0,1fr))]">
          <div>
            <Logo />
            <p className="mt-5 max-w-[340px] text-[16px] leading-[1.5] text-[#3A3A3A]">Any file, any format, one drag away. Free and open source, for macOS.</p>
            <div className="mt-7"><NavDownload onClick={() => go('download')} /></div>
          </div>
          <FooterCol title="On this page">
            {LINKS.map(([l, id]) => <li key={id}><button type="button" onClick={() => go(id)} className="link-line relative">{l}</button></li>)}
          </FooterCol>
          <FooterCol title="Project">
            <li><button type="button" onClick={() => go('download')} className="link-line relative">Download</button></li>
            <li className="flex items-center gap-2 text-[#0A0A0A]/45">Source on GitHub<span className="rounded-full bg-[#E4FF3A] px-2 py-0.5 text-[11px] font-semibold text-[#0A0A0A]">Soon</span></li>
            <li><a href="https://www.gnu.org/licenses/agpl-3.0.html" target="_blank" rel="noreferrer" className="link-line relative">Licence: AGPL 3.0</a></li>
          </FooterCol>
          <FooterCol title="Requirements">
            <li className="text-[#3A3A3A]">Mac with Apple silicon</li>
            <li className="text-[#3A3A3A]">macOS 13 Ventura or later</li>
            <li className="text-[#3A3A3A]">No account, no uploads</li>
          </FooterCol>
        </div>
        <div className="mt-16 flex flex-wrap items-center justify-between gap-4 border-t border-black/10 pt-6 text-[14px] text-[#6A6A6A]">
          <span>© 2026 anyfmt</span>
          <button type="button" onClick={() => window.scrollTo({ top: 0, behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })}
            className="group flex items-center gap-2 text-[#0A0A0A] outline-none focus-visible:ring-2 focus-visible:ring-black">
            <span className="link-line relative">Back to top</span>
            <span className="relative flex h-8 w-8 items-center justify-center overflow-hidden rounded-full bg-[#F1EEEA] transition-colors duration-300 group-hover:bg-[#0A0A0A] group-hover:text-white">
              {[0, 1].map((k) => (
                <svg key={k} width="12" height="12" viewBox="0 0 12 12" aria-hidden className={`absolute transition-transform duration-500 ${k === 0 ? 'group-hover:-translate-y-6' : 'translate-y-6 group-hover:translate-y-0'}`} style={{ transitionTimingFunction: 'cubic-bezier(0.785,0.135,0.15,0.86)' }}>
                  <path d="M6 10.5v-9M2 5.5l4-4 4 4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              ))}
            </span>
          </button>
        </div>
      </div>
    </footer>
  )
}

export default function FlareLanding() {
  useEffect(() => { document.title = 'anyfmt: any file, any format, one drag away' }, [])
  return (
    <div className="min-h-screen bg-white font-['Inter_Tight_Variable',ui-sans-serif,system-ui,sans-serif] text-[#0A0A0A] antialiased">
      <ButtonStyles />
      <style>{`
        .link-line::after { content:""; position:absolute; left:0; right:0; bottom:-2px; height:1.5px; background:currentColor; transform:scaleX(0); transform-origin:right; transition:transform .5s cubic-bezier(.785,.135,.15,.86); }
        .link-line:hover::after, button:focus-visible .link-line::after, .group:hover .link-line::after { transform:scaleX(1); transform-origin:left; }
      `}</style>
      <Hero />
      <main>
        <Statement />
        <TrySection />
        <KeysSection />
        <Numbers />
        <Faq />
        <FinalCta />
      </main>
      <Footer />
    </div>
  )
}

