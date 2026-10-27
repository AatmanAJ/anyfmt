/**
 * Brand: the press kit and the rules. Name, wordmark, icon, colour, type, the flutes (live, with
 * the angle on a slider), motion, voice, the recording backgrounds and copy-ready descriptions.
 */
import { DownloadSimple } from '@phosphor-icons/react'
import { motion, useInView } from 'motion/react'
import { useRef, useState } from 'react'
import { AppIcon } from '../components/AppIcon'
import { Flutes } from '../components/Flutes'
import { Page } from '../components/Page'
import { Container, CopyButton, Eyebrow, Logo } from '../components/ui'
import catalog from '../data/catalog.json'
import { useHead } from '../lib/head'
import { copyText, EASE, SNAP } from '../lib/hooks'
import { SITE } from '../lib/site'

const SWATCHES: { name: string; hex: string; use: string; ink?: boolean; share: number }[] = [
  { name: 'Paper', hex: '#FFFFFF', use: 'Pages and cards', ink: true, share: 34 },
  { name: 'Fog', hex: '#EFEFEF', use: 'The hero and the glass', ink: true, share: 14 },
  { name: 'Sand', hex: '#F4F2EF', use: 'Alternate sections', ink: true, share: 16 },
  { name: 'Ink', hex: '#0A0A0A', use: 'Type, buttons, dark panels', share: 24 },
  { name: 'Flare', hex: '#FF4A14', use: 'The dot, the hub, one accent', share: 6 },
  { name: 'Ember', hex: '#EE1200', use: 'Deep end of the heat', share: 2 },
  { name: 'Amber', hex: '#FFB23E', use: 'Hot end of the heat', ink: true, share: 2 },
  { name: 'Volt', hex: '#E4FF3A', use: 'Hover floods and "new"', ink: true, share: 2 },
]

function Swatch({ s }: { s: (typeof SWATCHES)[number] }) {
  const [ok, setOk] = useState(false)
  return (
    <button type="button" onClick={async () => { if (await copyText(s.hex)) { setOk(true); window.setTimeout(() => setOk(false), 1400) } }}
      className={`group flex aspect-[4/5] flex-col justify-between rounded-[22px] p-5 text-left outline-none ring-1 transition-transform duration-500 hover:-translate-y-1 focus-visible:ring-2 focus-visible:ring-flare ${s.ink ? 'text-ink ring-black/10' : 'text-white ring-transparent'}`}
      style={{ background: s.hex, transitionTimingFunction: SNAP }} aria-label={`${s.name} ${s.hex}, copy`}>
      <span className="text-[13px] font-medium opacity-70">{s.use}</span>
      <span>
        <span className="block text-[22px] font-semibold tracking-[-0.03em]">{s.name}</span>
        <span className="mt-1 block font-mono text-[13px] opacity-80">{ok ? 'Copied' : s.hex}</span>
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
              className={`h-9 rounded-full px-4 text-[14px] font-medium capitalize ${variant === v ? 'bg-ink text-white' : ''}`}>{v}</button>
          ))}
        </div>
        <p className={`absolute bottom-6 left-6 font-mono text-[13px] ${variant === 'dark' ? 'text-white/70' : 'text-ink/60'}`}>FlutedGlass · angle {angle}° · Swirl · RadialGradient × 2 · ChromaFlow · FilmGrain</p>
      </div>
      <label className="flex flex-wrap items-center gap-5 bg-white px-6 py-5">
        <span className="text-[15px] font-medium">Flute angle</span>
        <input type="range" min={0} max={60} value={angle} onChange={(e) => setAngle(Number(e.target.value))} className="flex-1 accent-[#FF4A14]" aria-valuetext={`${angle} degrees`} />
        <span className="w-24 text-right font-mono text-[14px]">{angle}°{angle === 31 ? ' · ours' : ''}</span>
        <button type="button" onClick={() => setAngle(31)} className="rounded-full bg-sand-2 px-3 py-1.5 text-[13px] font-medium">Reset to 31°</button>
      </label>
    </div>
  )
}

function Curve({ name, css, points }: { name: string; css: string; points: [number, number, number, number] }) {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { amount: 0.6 })
  const [x1, y1, x2, y2] = points
  return (
    <div ref={ref} className="rounded-[22px] bg-white p-6 ring-1 ring-black/5">
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
          <motion.div initial={{ opacity: 0, y: 20, filter: 'blur(8px)' }} animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }} transition={{ duration: 1, ease: EASE }}>
            <Logo className="mt-10 block !text-[clamp(96px,19vw,300px)] !leading-[0.8]" />
          </motion.div>
          <div className="mt-12 flex flex-wrap items-end justify-between gap-8">
            <p className="max-w-[520px] text-[19px] leading-[1.5] text-ink-2">Everything you need to write about anyfmt or show it: the rules, the files, and copy you can paste.</p>
            <div className="flex flex-wrap gap-2">
              {[['Wordmark', '/brand/anyfmt-wordmark.svg'], ['White wordmark', '/brand/anyfmt-wordmark-white.svg'], ['Icon', '/brand/anyfmt-icon.svg']].map(([l, h]) => (
                <a key={h} href={h} download className="inline-flex h-11 items-center gap-2 rounded-full bg-white px-4 text-[14.5px] font-medium ring-1 ring-black/10 transition-colors hover:bg-volt"><DownloadSimple size={16} weight="bold" />{l}</a>
              ))}
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container className="grid gap-12 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div>
            <Eyebrow>The name</Eyebrow>
            <h2 className="mt-6 text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">anyfmt. Lowercase, one word.</h2>
            <p className="mt-6 max-w-[440px] text-[17px] leading-[1.55] text-mute">Say it “any format”. In a sentence it stays lowercase, even at the start of one. The full stop is part of the wordmark, not the name: write “anyfmt” in text.</p>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="rounded-[22px] bg-sand p-6"><p className="text-[13px] font-semibold uppercase tracking-[0.12em] text-[#3F6212]">Write</p><p className="mt-3 text-[28px] font-semibold tracking-[-0.03em]">anyfmt</p><p className="mt-2 text-[14.5px] text-mute">“anyfmt converts it on your Mac.”</p></div>
            <div className="rounded-[22px] bg-sand p-6"><p className="text-[13px] font-semibold uppercase tracking-[0.12em] text-flare">Not</p><p className="mt-3 flex flex-wrap gap-x-4 text-[24px] font-semibold tracking-[-0.03em] text-mute-3 line-through decoration-flare decoration-2">AnyFmt <span>ANYFMT</span> <span>any fmt</span> <span>Anyfmt</span></p></div>
          </div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Wordmark and icon</Eyebrow>
          <h2 className="mt-6 max-w-[820px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">One mark: the name, then its first letter.</h2>
          <div className="mt-14 grid gap-4 lg:grid-cols-3">
            <div className="flex aspect-[4/3] items-center justify-center rounded-[26px] bg-white"><Logo className="!text-[clamp(56px,6vw,88px)]" /></div>
            <div className="flex aspect-[4/3] items-center justify-center rounded-[26px] bg-night"><Logo tone="white" className="!text-[clamp(56px,6vw,88px)]" /></div>
            <div className="ribs flex aspect-[4/3] items-center justify-center rounded-[26px]"><span className="font-wordmark text-[clamp(56px,6vw,88px)] font-bold leading-none tracking-[-0.04em] text-white">anyfmt<span className="text-ink">.</span></span></div>
          </div>
          <div className="mt-4 grid gap-4 lg:grid-cols-[1.2fr_1fr]">
            <div className="relative flex min-h-[340px] items-center justify-center rounded-[26px] bg-white p-10">
              <div className="relative">
                <Logo className="!text-[clamp(64px,8vw,120px)]" />
                <span className="pointer-events-none absolute -inset-[0.4em] rounded-[8px] border-2 border-dashed border-flare/50" />
                <span className="absolute -right-[0.42em] -top-[0.42em] rounded-full bg-flare px-2 py-0.5 text-[11px] font-semibold text-white">clear space = 2 dots</span>
              </div>
            </div>
            <div className="flex flex-col justify-between gap-8 rounded-[26px] bg-white p-8">
              <div className="flex flex-wrap items-end gap-4">
                {[160, 96, 64, 32, 16].map((s) => <AppIcon key={s} size={s} uid={`b${s}`} />)}
                <AppIcon size={96} uid="bp" tone="paper" />
              </div>
              <p className="text-[15.5px] leading-[1.55] text-mute">The icon is the wordmark cut to its first letter and its full stop: a white “a” and the ember dot on ink. The paper version is for light documents only. Don't recolour the dot, stretch the letter, or put the icon on a busy photo.</p>
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Colour</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Mostly paper and ink. Heat where it matters.</h2>
          <div className="mt-10 max-w-[720px]"><Proportion /><p className="mt-3 text-[14px] text-mute-2">Roughly how much of a page each colour covers. Click a swatch to copy its hex.</p></div>
          <div className="mt-10 grid grid-cols-2 gap-3 md:grid-cols-4">{SWATCHES.map((s) => <Swatch key={s.name} s={s} />)}</div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Type</Eyebrow>
          <div className="mt-10 grid gap-4 lg:grid-cols-3">
            <div className="rounded-[26px] bg-white p-8 lg:col-span-2">
              <p className="text-[clamp(64px,9vw,140px)] font-semibold leading-[0.9] tracking-[-0.055em]">Aa</p>
              <p className="mt-6 text-[26px] font-semibold tracking-[-0.03em]">Inter Tight</p>
              <p className="mt-2 max-w-[520px] text-[15.5px] leading-[1.55] text-mute">Everything you read. Headlines set semibold with tight tracking (−0.045em to −0.055em), text at 17px with loose leading.</p>
            </div>
            <div className="flex flex-col gap-4">
              <div className="flex-1 rounded-[26px] bg-white p-8"><p className="font-wordmark text-[64px] font-bold leading-none tracking-[-0.04em]">Aa</p><p className="mt-4 text-[19px] font-semibold">Bricolage Grotesque, condensed</p><p className="mt-1 text-[14.5px] text-mute">The wordmark and version numbers only.</p></div>
              <div className="flex-1 rounded-[26px] bg-night p-8 text-white"><p className="font-mono text-[44px] leading-none">{'{ }'}</p><p className="mt-4 text-[19px] font-semibold">JetBrains Mono</p><p className="mt-1 text-[14.5px] text-white/60">Commands, code and file names.</p></div>
            </div>
          </div>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>The flutes</Eyebrow>
          <div className="mt-6 grid items-end gap-6 lg:grid-cols-[1.2fr_1fr]">
            <h2 className="text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Fluted glass, cut at 31°, over a breathing ember.</h2>
            <p className="max-w-[460px] text-[16.5px] leading-[1.55] text-mute">Built with the shaders library on WebGPU. The heat sits in a corner and the ribs carry it across the page. Try another angle; there's a reason we stopped at 31.</p>
          </div>
          <div className="mt-12"><FluteLab /></div>
        </Container>
      </section>

      <section className="bg-sand py-24 lg:py-32">
        <Container>
          <Eyebrow>Motion</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Two curves do almost everything.</h2>
          <div className="mt-12 grid gap-4 md:grid-cols-2 lg:max-w-[880px]">
            <Curve name="Arrive" css="cubic-bezier(0.22, 1, 0.36, 1)" points={[0.22, 1, 0.36, 1]} />
            <Curve name="Snap" css="cubic-bezier(0.785, 0.135, 0.15, 0.86)" points={[0.785, 0.135, 0.15, 0.86]} />
          </div>
          <p className="mt-6 max-w-[620px] text-[15.5px] leading-[1.55] text-mute">Arrive is for things entering: text, cards, the wheel opening. Snap is for things changing state: underlines, arrows, fills. With Reduce Motion on, everything crossfades instead.</p>
        </Container>
      </section>

      <section className="bg-white py-24 lg:py-32">
        <Container>
          <Eyebrow>Voice</Eyebrow>
          <h2 className="mt-6 max-w-[860px] text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">Talk like the app works: quickly, then get out of the way.</h2>
          <ul className="mt-12 divide-y divide-line border-y border-line">
            {VOICE.map(([rule, yes, no]) => (
              <li key={rule} className="grid gap-4 py-6 md:grid-cols-[1fr_1.2fr_1.2fr] md:items-baseline md:gap-8">
                <p className="text-[19px] font-semibold tracking-[-0.02em]">{rule}</p>
                <p className="flex gap-3 text-[16px]"><span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-[#65A30D]" />{yes}</p>
                <p className="flex gap-3 text-[16px] text-mute-3 line-through decoration-flare/70"><span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-flare" />{no}</p>
              </li>
            ))}
          </ul>
        </Container>
      </section>

      <section className="bg-night py-24 text-white lg:py-32">
        <Container>
          <Eyebrow tone="white">Recording backgrounds</Eyebrow>
          <div className="mt-6 grid items-end gap-6 lg:grid-cols-[1.2fr_1fr]">
            <h2 className="text-[clamp(34px,4.2vw,64px)] font-semibold leading-[1.0] tracking-[-0.045em]">For Screen Studio, Cap and every demo you record.</h2>
            <p className="max-w-[440px] text-[16.5px] leading-[1.55] text-white/65">Rendered from the same shader as this site at 3840 × 2400, a Mac's own 16:10. The heat sits in the corners, so it frames a recording instead of fighting it.</p>
          </div>
          <ul className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
            {WALLS.map((w) => (
              <li key={w}>
                <a href={`/brand/wallpapers/anyfmt-${w}-3840x2400.jpg`} download className="group block outline-none">
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
            <h2 className="mt-6 text-[clamp(32px,3.6vw,54px)] font-semibold leading-[1.02] tracking-[-0.04em]">Paste these.</h2>
            <p className="mt-6 text-[16px] text-mute">Questions, interviews and review builds: <span className="font-medium text-ink">{SITE.email.press}</span></p>
            <CopyButton text={SITE.email.press} label="Copy address" className="mt-4" />
          </div>
          <div className="space-y-4">
            {[['One line', SHORT], ['One paragraph', LONG]].map(([k, v]) => (
              <div key={k} className="rounded-[22px] bg-sand p-6">
                <div className="flex items-center justify-between gap-3"><p className="text-[13px] font-semibold uppercase tracking-[0.12em] text-mute-2">{k}</p><CopyButton text={v} /></div>
                <p className="mt-3 text-[16.5px] leading-[1.6]">{v}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>
    </Page>
  )
}
