/**
 * Brand: the press kit and the rules. Name, wordmark, icon, colour, type, the flutes (live, with
 * the angle on a slider), motion, voice, the recording backgrounds and copy-ready descriptions.
 */
import { Check, DownloadSimple, X } from '@phosphor-icons/react'
import { motion, useInView } from 'motion/react'
import { useRef, useState } from 'react'
import { AppIcon } from '../components/AppIcon'
import { Flutes } from '../components/Flutes'
import { Page } from '../components/Page'
import { Container, CopyButton, Eyebrow, Logo } from '../components/ui'
import catalog from '../data/catalog.json'
import { useHead } from '../lib/head'
import { copyText, EASE } from '../lib/hooks'
import { SITE } from '../lib/site'

const SWATCHES: { name: string; hex: string; use: string; share: number }[] = [
  { name: 'Paper', hex: '#FFFFFF', use: 'Pages and cards', share: 34 },
  { name: 'Fog', hex: '#EFEFEF', use: 'Heroes, behind the glass', share: 14 },
  { name: 'Sand', hex: '#F4F2EF', use: 'Alternate sections', share: 16 },
  { name: 'Ink', hex: '#0A0A0A', use: 'Type, buttons, dark panels', share: 26 },
  { name: 'Ember', hex: '#FF4A14', use: 'The one accent: the dot, marks, the hot segment', share: 6 },
  { name: 'Volt', hex: '#E4FF3A', use: 'One highlight per screen, at most', share: 2 },
]
const HEAT = ['#EE1200', '#FF4A14', '#FFB23E']

/** A swatch cut like a printer's colour chip: the colour on top, the facts on white underneath. */
function Swatch({ s }: { s: (typeof SWATCHES)[number] }) {
  const [ok, setOk] = useState(false)
  return (
    <button type="button" onClick={async () => { if (await copyText(s.hex)) { setOk(true); window.setTimeout(() => setOk(false), 1400) } }}
      className="group flex flex-col overflow-hidden rounded-[20px] bg-white text-left outline-none ring-1 ring-black/[.08] transition-shadow duration-300 hover:ring-black/25 focus-visible:ring-2 focus-visible:ring-flare"
      aria-label={`${s.name} ${s.hex}, copy`}>
      <span className="block h-[132px] border-b border-black/[.06]" style={{ background: s.hex }} />
      <span className="flex flex-col gap-1 p-4">
        <span className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-0.5">
          <span className="text-[18px] font-semibold tracking-[-0.02em]">{s.name}</span>
          <span className="font-mono text-[13px] text-mute-2">{ok ? 'Copied' : s.hex}</span>
        </span>
        <span className="text-[14px] text-mute">{s.use}</span>
      </span>
    </button>
  )
}

function Proportion() {
  return (
    <div className="flex h-5 overflow-hidden rounded-full ring-1 ring-black/10" aria-label="Rough share of each colour on a page">
      {SWATCHES.map((s) => <span key={s.name} title={`${s.name} · about ${s.share}%`} style={{ width: `${s.share}%`, background: s.hex }} />)}
    </div>
  )
}

/** The heat is a ramp, not three more accents: it only lives inside the glass. */
function Heat() {
  return (
    <div className="flex flex-col overflow-hidden rounded-[20px] bg-white ring-1 ring-black/[.08] sm:col-span-2">
      <span className="block h-[132px] border-b border-black/[.06]" style={{ background: `linear-gradient(90deg, ${HEAT.join(', ')})` }} />
      <span className="flex flex-col gap-1 p-4">
        <span className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-0.5">
          <span className="text-[18px] font-semibold tracking-[-0.02em]">Heat</span>
          <span className="font-mono text-[13px] text-mute-2">{HEAT.join(' → ')}</span>
        </span>
        <span className="text-[14px] text-mute">The glow behind the fluted glass and in the footer wordmark. Never flat fills or text.</span>
      </span>
    </div>
  )
}

function FluteLab() {
  const [angle, setAngle] = useState(31)
  const [variant, setVariant] = useState<'light' | 'dark'>('light')
  return (
    <div className="overflow-hidden rounded-[28px] ring-1 ring-black/5">
      <div className="relative h-[420px] bg-fog">
        <Flutes variant={variant} corner={variant === 'light' ? 'tr' : 'bl'} angle={angle} className="absolute inset-0" />
        <div className="absolute left-6 top-6 flex gap-1.5 rounded-full bg-white p-1 ring-1 ring-black/10">
          {(['light', 'dark'] as const).map((v) => (
            <button key={v} type="button" onClick={() => setVariant(v)} aria-pressed={variant === v}
              className={`h-9 rounded-full px-4 text-[14px] font-medium capitalize outline-none focus-visible:ring-2 focus-visible:ring-flare ${variant === v ? 'bg-ink text-white' : ''}`}>{v}</button>
          ))}
        </div>
      </div>
      <label className="flex flex-wrap items-center gap-5 bg-white px-6 py-5">
        <span className="text-[15px] font-medium">Flute angle</span>
        <input type="range" min={0} max={60} value={angle} onChange={(e) => setAngle(Number(e.target.value))} className="min-w-[160px] flex-1 accent-[#FF4A14] outline-none focus-visible:ring-2 focus-visible:ring-flare" aria-valuetext={`${angle} degrees`} />
        <span className="w-24 text-right font-mono text-[14px]">{angle}°{angle === 31 ? ' · ours' : ''}</span>
        <button type="button" onClick={() => setAngle(31)} className="rounded-full bg-sand-2 px-3.5 py-2 text-[14px] font-medium outline-none hover:bg-sand focus-visible:ring-2 focus-visible:ring-flare">Reset to 31°</button>
      </label>
    </div>
  )
}

function Curve({ name, css, points }: { name: string; css: string; points: [number, number, number, number] }) {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { amount: 0.6 })
  const [x1, y1, x2, y2] = points
  return (
    <div ref={ref} className="rounded-[28px] bg-white p-6 ring-1 ring-black/[.07]">
      <svg viewBox="-0.05 -0.1 1.1 1.2" className="h-[140px] w-full" aria-hidden>
        <path d="M0 1 L1 1 M0 1 L0 0" stroke="#E8E4DF" strokeWidth="0.008" fill="none" />
        <path d={`M0 1 C${x1} ${1 - y1} ${x2} ${1 - y2} 1 0`} stroke="#0A0A0A" strokeWidth="0.025" fill="none" />
        <circle cx={x1} cy={1 - y1} r="0.025" fill="#FF4A14" /><circle cx={x2} cy={1 - y2} r="0.025" fill="#FF4A14" />
      </svg>
      <div className="relative mt-4 h-8 rounded-full bg-sand">
        <span className="absolute top-1 h-6 w-6 rounded-full bg-flare transition-[left] duration-[1200ms]" style={{ left: seen ? 'calc(100% - 28px)' : '4px', transitionTimingFunction: css }} />
      </div>
      <p className="mt-4 text-[17px] font-semibold">{name}</p>
      <p className="mt-1 font-mono text-[12.5px] text-mute-2">{css}</p>
    </div>
  )
}

const VOICE: [string, string, string][] = [
  ['Say what it does', 'Drag a file, tap Shift, drop it on JPG.', 'Seamlessly transform your media workflow.'],
  ['Numbers over adjectives', '793 routes, each run on a real file.', 'Supports tons of formats!'],
  ['Honest about limits', "PDF to PowerPoint gives picture slides, not editable text.", 'Converts anything to anything.'],
  ['Short sentences, plain words', 'It never overwrites. Results are new files.', 'Leveraging non-destructive output paradigms.'],
]

const WALLS = ['molten', 'ember', 'eclipse', 'night', 'paper']

const SHORT = `anyfmt is an open-source Mac app that converts files where they are: drag a file, tap Shift, and drop it on the format you want.`
const LONG = `anyfmt is an open-source (AGPL-3.0) menu bar app for macOS that converts files without opening anything. Start dragging any file in Finder and tap Shift: a wheel of every format that file can become opens around the pointer, and dropping on one writes a converted copy beside the original. Tap Command instead for ${catalog.counts.tools} tools such as compress-to-size, trim and remove background, or Control for actions such as AirDrop and Copy Path. It ships with ${catalog.counts.routes} tested conversion routes across images, video, audio, PDF, documents, spreadsheets, ebooks, subtitles and archives, all running on the Mac with nothing uploaded, plus a command-line tool and an MCP server for AI agents.`

export default function Brand() {
  useHead({ title: 'Brand and press kit', description: 'The anyfmt name, wordmark, icon, colours, type, motion and voice, with downloadable logos, recording backgrounds and press copy.', path: '/brand' })
  return (
    <Page>
      <section className="relative overflow-hidden bg-fog pb-16 pt-36 lg:pt-44">
        <Flutes className="pointer-events-none absolute inset-0" />
        <Container className="relative">
          <Eyebrow>Brand</Eyebrow>
          <motion.h1 initial={{ opacity: 0, y: 20, filter: 'blur(8px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} transition={{ duration: 1, ease: EASE }} aria-label="anyfmt brand and press kit">
            <Logo className="mt-10 block !text-[clamp(64px,19vw,300px)] !leading-[0.8]" />
          </motion.h1>
          <div className="mt-12 flex flex-wrap items-end justify-between gap-8">
            <p className="max-w-[520px] text-[19px] leading-[1.5] text-ink-2">Everything you need to write about anyfmt or show it: the rules, the files, and copy you can paste.</p>
            <div className="flex flex-wrap gap-2">
              {[['Wordmark', '/brand/anyfmt-wordmark.svg'], ['White', '/brand/anyfmt-wordmark-white.svg'], ['Icon', '/brand/anyfmt-icon.svg']].map(([l, h]) => (
                <a key={h} href={h} download className="inline-flex h-11 items-center gap-2 rounded-full bg-white px-4 text-[14.5px] font-medium outline-none ring-1 ring-black/10 transition-colors hover:bg-volt focus-visible:ring-2 focus-visible:ring-flare"><DownloadSimple size={16} weight="bold" />{l}</a>
              ))}
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>The name</Eyebrow>
            <h2 className="mt-6 text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">anyfmt. Lowercase, one word.</h2>
            <p className="mt-6 max-w-[440px] text-[17px] leading-[1.55] text-mute">Say it “any format”. In a sentence it stays lowercase, even at the start of one. The full stop is part of the wordmark, not the name: write “anyfmt” in text.</p>
          </div>
          <div className="grid content-start gap-3 sm:grid-cols-2 lg:pt-16">
            <div className="rounded-[28px] bg-sand p-6 sm:p-7"><p className="flex items-center gap-2 text-[14px] font-semibold"><Check size={15} weight="bold" aria-hidden />Write</p><p className="mt-4 text-[32px] font-semibold leading-none tracking-[-0.035em]">anyfmt</p><p className="mt-3 text-[15px] text-mute">“anyfmt converts it on your Mac.”</p></div>
            <div className="rounded-[28px] bg-sand p-6 sm:p-7"><p className="flex items-center gap-2 text-[14px] font-semibold"><X size={15} weight="bold" aria-hidden />Not</p><p className="mt-4 flex flex-wrap gap-x-4 gap-y-1 text-[24px] font-semibold leading-tight tracking-[-0.03em] text-mute-2 line-through decoration-flare decoration-2"><span>AnyFmt</span><span>ANYFMT</span><span>any fmt</span><span>Anyfmt</span></p></div>
          </div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Wordmark and icon</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">The icon is the wordmark's first letter.</h2>
          <div className="mt-14 grid gap-4 lg:grid-cols-3">
            <div className="flex aspect-[16/9] items-center justify-center rounded-[28px] bg-white lg:aspect-[4/3]"><Logo className="!text-[clamp(56px,6vw,88px)]" /></div>
            <div className="flex aspect-[16/9] items-center justify-center rounded-[28px] bg-night lg:aspect-[4/3]"><Logo tone="white" className="!text-[clamp(56px,6vw,88px)]" /></div>
            <div className="flutes-static-dark flex aspect-[16/9] items-center justify-center rounded-[28px] lg:aspect-[4/3]"><Logo tone="white" className="!text-[clamp(56px,6vw,88px)]" /></div>
          </div>
          <div className="mt-4 grid gap-4 lg:grid-cols-[1.2fr_1fr]">
            <div className="relative flex min-h-[340px] flex-col items-center justify-center gap-10 rounded-[28px] bg-white p-10">
              <div className="relative">
                <Logo className="!text-[clamp(56px,7vw,112px)]" />
                <span className="pointer-events-none absolute -inset-[0.4em] rounded-[8px] border-2 border-dashed border-flare/60" />
              </div>
              <p className="text-[14px] text-mute-2">Clear space: the width of two dots on every side.</p>
            </div>
            <div className="flex flex-col justify-between gap-8 rounded-[28px] bg-white p-8">
              <ul className="flex flex-wrap items-end gap-x-6 gap-y-5">
                {[128, 64, 32, 16].map((s) => <li key={s} className="flex flex-col items-center gap-2"><AppIcon size={s} uid={`b${s}`} /><span className="text-[13px] tabular-nums text-mute-2">{s} px</span></li>)}
                <li className="flex flex-col items-center gap-2"><AppIcon size={64} uid="bp" tone="paper" /><span className="text-[13px] text-mute-2">Paper</span></li>
              </ul>
              <p className="text-[15.5px] leading-[1.55] text-mute">The icon is the wordmark cut to its first letter and its full stop: a white “a” and the ember dot on ink. The paper version is for light documents only. Don't recolour the dot, stretch the letter, or put the icon on a busy photo.</p>
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Colour</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Paper and ink, with one ember accent.</h2>
          <div className="mt-10 max-w-[720px]"><Proportion /><p className="mt-3 text-[14px] text-mute-2">Roughly how much of a page each colour covers. Click a swatch to copy its hex.</p></div>
          <div className="mt-10 grid grid-cols-2 gap-4 md:grid-cols-4">{SWATCHES.map((s) => <Swatch key={s.name} s={s} />)}<Heat /></div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Type</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,60px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Inter Tight for reading, Bricolage for the name.</h2>
          <div className="mt-12 grid gap-4 lg:grid-cols-3">
            <div className="rounded-[28px] bg-white p-8 lg:col-span-2">
              <p className="text-[clamp(64px,9vw,140px)] font-semibold leading-[0.9] tracking-[-0.055em]">Aa</p>
              <p className="mt-6 text-[26px] font-semibold tracking-[-0.03em]">Inter Tight</p>
              <p className="mt-2 max-w-[520px] text-[15.5px] leading-[1.55] text-mute">Everything you read. Headlines set semibold with tight tracking (−0.045em to −0.055em), text at 17px with loose leading.</p>
              <p className="mt-8 border-t border-line pt-6 text-[clamp(26px,3vw,40px)] font-semibold leading-[1.1] tracking-[-0.045em] [text-wrap:balance]">Drag a file, tap Shift, drop it on JPG.</p>
              <p className="mt-3 max-w-[560px] text-[17px] leading-[1.55] text-mute">The copy lands beside the original, which is never touched. 793 routes, each run on a real file before it ships.</p>
            </div>
            <div className="flex flex-col gap-4">
              <div className="flex-1 rounded-[28px] bg-white p-8"><p className="font-wordmark text-[64px] font-bold leading-none tracking-[-0.04em]">Aa</p><p className="mt-4 text-[19px] font-semibold">Bricolage Grotesque, condensed</p><p className="mt-1 text-[14.5px] text-mute">The wordmark and version numbers only.</p></div>
              <div className="flex-1 rounded-[28px] bg-night p-8 text-white"><p className="font-mono text-[44px] leading-none">{'{ }'}</p><p className="mt-4 text-[19px] font-semibold">JetBrains Mono</p><p className="mt-1 text-[14.5px] text-white/60">Commands, code and file names.</p></div>
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>The flutes</Eyebrow>
          <div className="mt-6 grid items-end gap-6 lg:grid-cols-[1.2fr_1fr]">
            <h2 className="text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Fluted glass, cut at 31°, over a breathing ember.</h2>
            <p className="max-w-[460px] text-[16.5px] leading-[1.55] text-mute">Built with the shaders library on WebGPU. The heat sits in a corner and the ribs carry it across the page. Try another angle; there's a reason we stopped at 31.</p>
          </div>
          <div className="mt-12"><FluteLab /></div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Motion</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Two curves do almost everything.</h2>
          <div className="mt-12 grid gap-4 md:grid-cols-2">
            <Curve name="Arrive" css="cubic-bezier(0.22, 1, 0.36, 1)" points={[0.22, 1, 0.36, 1]} />
            <Curve name="Snap" css="cubic-bezier(0.785, 0.135, 0.15, 0.86)" points={[0.785, 0.135, 0.15, 0.86]} />
          </div>
          <p className="mt-6 max-w-[620px] text-[15.5px] leading-[1.55] text-mute">Arrive is for things entering: text, cards, the wheel opening. Snap is for things changing state: underlines, arrows, fills. With Reduce Motion on, everything crossfades instead.</p>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Voice</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">Say what it does, with numbers, in plain words.</h2>
          <ul className="mt-12 divide-y divide-line border-y border-line">
            {VOICE.map(([rule, yes, no]) => (
              <li key={rule} className="grid gap-4 py-6 md:grid-cols-[1fr_1.2fr_1.2fr] md:items-baseline md:gap-8">
                <p className="text-[19px] font-semibold tracking-[-0.02em]">{rule}</p>
                <p className="flex gap-3 text-[16px]"><Check size={15} weight="bold" aria-hidden className="mt-1 shrink-0" />{yes}</p>
                <p className="flex gap-3 text-[16px] text-mute-2 line-through decoration-flare/70"><X size={15} weight="bold" aria-hidden className="mt-1 shrink-0 text-flare" />{no}</p>
              </li>
            ))}
          </ul>
        </Container>
      </section>

      <section className="bg-night py-24 text-white lg:py-32">
        <Container>
          <Eyebrow tone="white">Recording backgrounds</Eyebrow>
          <div className="mt-6 grid items-end gap-6 lg:grid-cols-[1.2fr_1fr]">
            <h2 className="text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em] [text-wrap:balance]">For Screen Studio, Cap and every demo you record.</h2>
            <p className="max-w-[440px] text-[16.5px] leading-[1.55] text-white/65">Rendered from the same shader as this site at 3840 × 2400, a Mac's own 16:10. The heat sits in the corners, so it frames a recording instead of fighting it.</p>
          </div>
          <ul className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            {WALLS.map((w) => (
              <li key={w}>
                <a href={`/brand/wallpapers/anyfmt-${w}-3840x2400.jpg`} download className="group block rounded-[16px] outline-none focus-visible:ring-2 focus-visible:ring-flare focus-visible:ring-offset-4 focus-visible:ring-offset-night">
                  <span className="block overflow-hidden rounded-[16px] ring-1 ring-white/10">
                    <img src={`/brand/wallpapers/anyfmt-${w}-preview.jpg`} alt={`The ${w} background`} loading="lazy" width={800} height={500} className="aspect-[16/10] w-full object-cover transition-transform duration-700 group-hover:scale-[1.04]" />
                  </span>
                  <span className="mt-3 flex items-center justify-between text-[15px] font-medium capitalize">{w}<DownloadSimple size={16} className="text-white/60 transition-colors group-hover:text-volt" /></span>
                </a>
              </li>
            ))}
          </ul>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,4fr)_minmax(0,8fr)]">
          <div>
            <Eyebrow>For press</Eyebrow>
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em] [text-wrap:balance]">Copy you can paste.</h2>
            <p className="mt-6 text-[16px] text-mute">Questions, interviews and review builds: <span className="font-medium text-ink">{SITE.email.press}</span></p>
            <CopyButton text={SITE.email.press} label="Copy address" className="mt-4" />
          </div>
          <div className="space-y-4">
            {[['One line', SHORT], ['One paragraph', LONG]].map(([k, v]) => (
              <div key={k} className="rounded-[28px] bg-sand p-6 sm:p-7">
                <div className="flex items-center justify-between gap-3"><p className="text-[14px] font-semibold">{k}</p><CopyButton text={v} /></div>
                <p className="mt-3 max-w-[680px] text-[16.5px] leading-[1.6]">{v}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>
    </Page>
  )
}
