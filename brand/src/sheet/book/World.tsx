import { ArrowRight, Lock, RotateCw, Search, X } from 'lucide-react'
import { Mark, Pixels, Wordmark } from '../Mark'
import { landscape, wheelArt } from './pixel'
import { Lbl, PX, Section, Sub, Win } from './ui'

function Docs() {
  return (
    <Win title="anyfmt.app/docs/cli" className="h-full">
      <div className="grid md:grid-cols-[180px_1fr]">
        <aside className="hidden border-r border-[var(--shb-line)] bg-[var(--sh-slate)] p-4 md:block">
          <Wordmark size={15} />
          <div className="mt-5 grid gap-1 text-[13px]">
            {['Getting started', 'The three wheels', 'Presets', 'CLI', 'MCP server', 'Pro'].map((s, i) => <span key={s} className={`rounded-[3px] px-2 py-1 ${i === 3 ? 'bg-black text-white' : 'text-[var(--sh-graphite)]'}`}>{s}</span>)}
          </div>
        </aside>
        <article className="min-w-0 p-5 md:p-7">
          <span className="sh-mono text-[12px] text-[var(--sh-graphite)]">Docs · Agents</span>
          <h4 className="sh-display mt-2 text-[30px]">Convert from <span className="sh-hl">the command line.</span></h4>
          <p className="mt-3 max-w-[520px] text-[14px] text-[var(--sh-graphite)]">The CLI ships inside the app. It uses the same 793 routes as the wheel and prints JSON when you ask.</p>
          <pre className="sh-code mt-4 overflow-x-auto rounded-[4px] bg-[var(--sh-sky)] p-4 text-[13px] leading-[1.7]">{`$ anyfmt convert IMG_0042.heic --to jpg --opt quality=85
$ anyfmt convert *.png --to webp --dry-run --json`}</pre>
          <div className="mt-4 rounded-[4px] p-3 text-[13px]" style={{ background: 'var(--sh-cream)' }}><b className="font-[600]">Local by default.</b> No command makes a network call unless you pass a Pro flag.</div>
        </article>
      </div>
    </Win>
  )
}

function Readme() {
  return (
    <div className="h-full overflow-hidden rounded-[10px] bg-black text-white shb-hair-d">
      <div className="flex h-[34px] items-center gap-[7px] border-b border-[#2C2C2C] px-3">{[0, 1, 2].map((i) => <span key={i} className="size-[11px] rounded-full bg-[#333]" />)}<span className="sh-code ml-3 text-[12px] text-[#9A9794]">~/src/anyfmt — zsh</span></div>
      <pre className="sh-code overflow-x-auto p-5 text-[12.5px] leading-[1.65]">
        <span className="text-[#9A9794]">$</span> cat README.md{'\n'}
        <Pixels rows={wheelArt(14, 1, 6, 0.27, 'w', 'o')} palette={PX} px={3} style={{ display: 'inline-block', verticalAlign: 'middle' }} /> <b className="text-[15px]">anyfmt</b>{'\n\n'}
        Convert, edit and share any file in the{'\n'}middle of a drag. macOS 13+, Apple silicon.{'\n\n'}
        <span className="text-[#9A9794]">## Install</span>{'\n'}
        brew install --cask anyfmt{'\n\n'}
        <span className="text-[#9A9794]">## Licence</span>{'\n'}
        AGPL-3.0. Every local feature is free.{'\n\n'}
        <span className="text-[#9A9794]">$</span> <span className="sh-caret" style={{ background: '#fff' }} />
      </pre>
    </div>
  )
}

function Social() {
  return (
    <div className="relative aspect-[1200/630] w-full overflow-hidden rounded-[4px] bg-white shb-hair" style={{ containerType: 'inline-size' }}>
      <div className="absolute inset-y-0 left-0 flex w-full flex-col justify-between p-[5%] md:w-[66%]">
        <div className="flex items-center justify-between"><Wordmark size={18} /><span className="shb-lbl text-[10px] text-[var(--sh-graphite)] md:text-[12px]">anyfmt.app</span></div>
        <div className="sh-display-xl" style={{ fontSize: '9.6cqw' }}>Drop on <span className="sh-hl">GIF.</span><br />Done.</div>
        <div className="flex items-center justify-between"><span className="shb-lbl text-[10px] md:text-[12px]">793 routes · 0 network calls</span><span className="shb-lbl text-[10px] text-[var(--sh-graphite)] md:text-[12px]">1200 × 630</span></div>
      </div>
      <div className="sh-dots absolute bottom-0 right-0 top-0 hidden w-[34%] bg-[var(--sh-sky)] md:grid md:place-items-center">
        <Pixels rows={wheelArt(26)} palette={PX} px={6} />
      </div>
    </div>
  )
}

function Slide() {
  return (
    <div className="relative aspect-[16/9] w-full overflow-hidden rounded-[4px] bg-black text-white" style={{ containerType: 'inline-size' }}>
      <div className="absolute inset-0 flex flex-col p-[5%]">
        <div className="flex justify-between"><span className="shb-lbl text-[9px] text-[#9A9794] md:text-[11px]">Local-first tools · Talk 04</span><span className="shb-lbl text-[9px] text-[#9A9794] md:text-[11px]">12 / 30</span></div>
        <div className="mt-auto grid grid-cols-[1fr_auto] items-end gap-6">
          <div>
            <div className="sh-display leading-[1.05]" style={{ fontSize: '6.2cqw' }}>The key you press <span className="sh-hl whitespace-nowrap text-black">picks the wheel.</span></div>
            <div className="mt-[3%] flex gap-[4%]">
              {[['⇧', 'Convert'], ['⌘', 'Tools'], ['⌃', 'Actions']].map(([k, w]) => <span key={w} className="shb-lbl text-[9px] md:text-[12px]">{k} {w}</span>)}
            </div>
          </div>
          <Mark size={64} ink="#fff" className="hidden md:block" />
        </div>
      </div>
    </div>
  )
}

function BrowserTab() {
  return (
    <div className="overflow-hidden rounded-[10px] bg-white shb-hair">
      <div className="flex items-end gap-1 bg-[var(--sh-slate)] px-3 pt-2">
        <span className="flex gap-[7px] pb-3 pr-3">{[0, 1, 2].map((i) => <span key={i} className="size-[11px] rounded-full bg-[#DCE1E8]" />)}</span>
        <div className="flex h-[34px] min-w-0 max-w-[240px] flex-1 items-center gap-2 rounded-t-[8px] bg-white px-3 text-[12px] shb-hair" style={{ boxShadow: 'inset 1px 1px 0 #D3D9E2, inset -1px 0 0 #D3D9E2' }}>
          <Mark size={16} /><span className="truncate">anyfmt: convert any file mid-drag</span><X size={12} className="ml-auto flex-none text-[var(--sh-graphite)]" />
        </div>
        <div className="hidden h-[30px] w-[160px] items-center gap-2 px-3 text-[12px] text-[var(--sh-graphite)] sm:flex"><span className="size-4 rounded-[3px] bg-[var(--sh-mist)]" />Docs</div>
      </div>
      <div className="flex items-center gap-3 border-b border-[var(--shb-line)] px-3 py-2">
        <RotateCw size={14} className="text-[var(--sh-graphite)]" />
        <div className="flex h-7 flex-1 items-center gap-2 rounded-[999px] bg-[var(--sh-slate)] px-3 text-[13px]"><Lock size={12} className="text-[var(--sh-graphite)]" /><span>anyfmt.app</span></div>
        <Search size={14} className="text-[var(--sh-graphite)]" />
      </div>
      <div className="p-5">
        <div className="flex items-center justify-between"><Wordmark size={16} /><span className="sh-btn sh-btn-ink !h-7 !px-3 !text-[12px]">Download</span></div>
        <div className="sh-display mt-6 text-[30px] leading-[1.05]">Any file, <span className="sh-hl">any format.</span></div>
        <div className="sh-dots mt-4 overflow-hidden rounded-[4px] bg-[var(--sh-sky)]"><Pixels rows={landscape(80, 28, { cursor: false, files: false })} palette={PX} px={5} style={{ width: '100%' }} /></div>
      </div>
    </div>
  )
}

function Broadsheet() {
  return (
    <div className="mx-auto w-full max-w-[560px] bg-white p-6 shb-hair md:aspect-[210/297] md:p-9">
      <div className="flex h-full flex-col">
        <div className="flex justify-between border-b border-black pb-1.5"><span className="shb-lbl text-[9px]">Fact sheet · Oct 2026</span><span className="shb-lbl text-[9px]">anyfmt.app</span></div>
        <div className="sh-display-xl mt-4 text-[30px] md:text-[44px]">anyfmt, on <span className="sh-hl whitespace-nowrap">one page.</span></div>
        <p className="mt-3 text-[12px] leading-[1.45]">A free, open-source macOS menu-bar app. Drag a file, press a key, and a wheel of everything it can become opens around the pointer. Drop on one.</p>
        <div className="mt-4 grid grid-cols-4 border-y border-black">
          {[['793', 'routes'], ['26', 'tools'], ['0', 'net calls'], ['43 ms', 'to wheel']].map(([v, l], i) => (
            <div key={l} className={`py-2 ${i ? 'border-l border-[var(--shb-line)] pl-2' : ''}`}><div className="sh-display text-[clamp(16px,3.2vw,24px)] leading-none">{v}</div><div className="shb-lbl mt-1 text-[8px] text-[var(--sh-graphite)]">{l}</div></div>
          ))}
        </div>
        <div className="mt-4 grid grid-cols-2 gap-4 text-[10.5px] leading-[1.5]">
          <div>
            <div className="shb-lbl text-[9px]">How it works</div>
            <p className="mt-1">Shift opens Convert. Command opens Tools: crop, trim, compress, redact. Control opens Actions: AirDrop, Float, Copy, Move, Copy Path, Terminal.</p>
            <div className="shb-lbl mt-3 text-[9px]">Private</div>
            <p className="mt-1">Runs on your Mac. No account, no upload, no telemetry.</p>
          </div>
          <div>
            <div className="shb-lbl text-[9px]">Pricing</div>
            <p className="mt-1"><b>Local · free forever.</b> All conversions, tools, actions, the CLI and MCP server.</p>
            <p className="mt-1"><b>Pro · $4/month.</b> Share links, cloud conversions, transcription, upscaling, synced presets.</p>
          </div>
        </div>
        <div className="mt-4 border-t border-black pt-2">
          <div className="shb-lbl text-[9px]">Popular routes</div>
          <div className="sh-code mt-1 grid grid-cols-4 gap-x-2 text-[9.5px] leading-[1.6]">
            {['HEIC → JPG', 'MOV → GIF', 'PDF → PNG', 'WAV → MP3', 'PNG → WEBP', 'MP4 → WEBM', 'DOCX → PDF', 'SVG → PNG'].map((r) => <span key={r}>{r}</span>)}
          </div>
        </div>
        <div className="sh-dots mt-4 flex h-[110px] min-h-0 items-end overflow-hidden rounded-[2px] bg-[var(--sh-sky)] md:h-auto md:flex-1">
          <Pixels rows={landscape(96, 36, { cursor: false, files: true })} palette={PX} px={5} style={{ width: '100%', display: 'block' }} />
        </div>
        <div className="-mx-6 -mb-6 mt-4 flex items-center justify-between bg-[var(--sh-orange)] px-6 py-2 md:-mx-9 md:-mb-9 md:px-9"><span className="shb-lbl text-[9px]">Drag. Press. Drop.</span><span className="shb-lbl text-[9px]">brew install --cask anyfmt</span></div>
      </div>
    </div>
  )
}

export function World() {
  return (
    <Section id="world" n={11} label="In the world" title={<>Off the screen, <span className="sh-hl">same paper.</span></>}
      lede="Docs, a README, a social card, a slide, a browser tab and a printed sheet. Each is mostly white and black, has one highlight, and carries pixels only where there’s room.">
      <Sub n="11.1" title="Docs and README">
        <div className="grid gap-4 md:grid-cols-12">
          <div className="md:col-span-7"><Docs /></div>
          <div className="md:col-span-5"><Readme /></div>
        </div>
      </Sub>
      <Sub n="11.2" title="Social card and slide" note="One giant phrase, one highlight. The card is 1200 × 630; the slide is 16:9 on black.">
        <div className="grid gap-4 md:grid-cols-2">
          <figure><Social /><figcaption className="mt-3"><Lbl>Social card · Open Graph</Lbl></figcaption></figure>
          <figure><Slide /><figcaption className="mt-3"><Lbl>Conference slide · dark</Lbl></figcaption></figure>
        </div>
      </Sub>
      <Sub n="11.3" title="Browser tab and broadsheet" note="The favicon is the 16 px mark. Printed, the fact sheet ends in the orange band like every page does.">
        <div className="grid items-start gap-4 md:grid-cols-12">
          <figure className="md:col-span-6"><BrowserTab /><figcaption className="mt-3"><Lbl>anyfmt.app in a browser tab</Lbl></figcaption></figure>
          <figure className="md:col-span-6">
            <div className="sh-dots rounded-[4px] bg-[var(--sh-lavender)] p-4 md:p-8"><Broadsheet /></div>
            <figcaption className="mt-3 flex items-center gap-2"><Lbl>One-page broadsheet · A4</Lbl><ArrowRight size={12} className="text-[var(--sh-graphite)]" /><Lbl>prints in black plus one orange</Lbl></figcaption>
          </figure>
        </div>
      </Sub>
    </Section>
  )
}
