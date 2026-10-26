import { ArrowRight, Check, Download, Plus } from 'lucide-react'
import { Mark } from '../Mark'
import { Eyebrow, Jump, SectionHead, Wrap } from './ui'

/* ───────────────────────── Pricing ───────────────────────── */

const PLANS = [
  {
    name: 'Local', price: 'Free', period: 'forever', tint: 'var(--sh-lavender)',
    blurb: 'Everything that runs on your Mac. Open source under AGPL-3.0.',
    points: ['All 793 conversions', 'All 26 tools and 6 actions', 'Presets, the Float shelf, the CLI and MCP server', 'No account, no limits, no watermark'],
    cta: <a href="#" onClick={(e) => e.preventDefault()} className="sh-btn sh-btn-ink"><Download size={16} strokeWidth={2} />Download for Mac</a>,
  },
  {
    name: 'Pro', price: '$4', period: '/month', tint: 'var(--sh-cream)',
    blurb: 'Only adds things that need a server. Nothing local moves behind it.',
    points: ['Share links with expiry', 'Cloud conversions for huge files', 'Transcribe, upscale, HQ cut-outs', 'Sync presets across Macs'],
    cta: <a href="#" onClick={(e) => e.preventDefault()} className="sh-btn sh-btn-ghost">Get Pro<ArrowRight size={15} strokeWidth={1.75} /></a>,
  },
]

export function Pricing() {
  return (
    <section id="pricing" className="scroll-mt-16 py-20 lg:py-24">
      <Wrap>
        <SectionHead eyebrow="Pricing" title={<>Free on your Mac. <span className="sh-hl">Forever.</span></>}
          sub="Every local feature is free and open source. Pro is for the few things that need a server." />
        <div className="mx-auto mt-12 grid max-w-[920px] gap-3 md:grid-cols-2">
          {PLANS.map((p) => (
            <article key={p.name} className="sh-card flex flex-col p-6 sm:p-8" style={{ background: p.tint }}>
              <div className="flex items-center justify-between">
                <Eyebrow>{p.name}</Eyebrow>
                {p.name === 'Pro' && <span className="sh-tag sh-mono text-[11px]">Optional</span>}
              </div>
              <div className="mt-6 flex items-baseline gap-2">
                <span className="sh-display-xl text-[72px] leading-[0.9]">{p.price}</span>
                <span className="text-[16px] text-[var(--sh-graphite)]">{p.period}</span>
              </div>
              <p className="mt-4 text-[15.5px] text-[var(--sh-graphite)]">{p.blurb}</p>
              <ul className="mt-6 grid gap-2.5 border-t border-black/15 pt-6 text-[15.5px]">
                {p.points.map((t) => <li key={t} className="flex items-start gap-2.5"><Check size={16} strokeWidth={1.75} className="mt-[3px] shrink-0" />{t}</li>)}
              </ul>
              <div className="mt-8 pt-2">{p.cta}</div>
            </article>
          ))}
        </div>
        <p className="sh-mono mt-6 text-center text-[11.5px] text-[var(--sh-graphite)]">Pro price is a placeholder · Licence keys look like ANYFMT1-…</p>
      </Wrap>
    </section>
  )
}

/* ───────────────────────── FAQ ───────────────────────── */

const FAQ = [
  { q: 'Does anything leave my Mac?', a: 'No. Conversions, tools and actions run locally: 0 network calls unless you ask for a Pro cloud feature. Update checks are opt-in, fetch an appcast once a day and send nothing else.' },
  { q: 'Is it really free?', a: 'Yes. Every local feature is free forever and the app is open source under AGPL-3.0. Pro only adds features that need a server, like share links and cloud conversions for huge files.' },
  { q: 'Will it overwrite my files?', a: 'Never. Every conversion and every tool writes a new file next to the original.' },
  { q: 'What do I need?', a: 'macOS 13 or later on an Apple silicon Mac. anyfmt lives in the menu bar and opens the wheel in about 43 ms from the key press.' },
  { q: 'What permissions does it ask for?', a: 'The wheel needs none. anyfmt reads the mouse button, the modifier keys and the drag pasteboard, the same public state any app can read, and it never sees ordinary keys. Two optional extras ask for Accessibility or Automation, and both are off until you turn them on.' },
  { q: 'Can my agents use it?', a: 'Yes. The anyfmt CLI does everything the wheel does, with --json on every command and NDJSON progress events. anyfmt mcp is an MCP server on stdin and stdout, so Claude and other clients can convert files on your Mac.' },
]

export function Faq() {
  return (
    <section id="faq" className="scroll-mt-16 border-t border-black/10 py-20 lg:py-24">
      <Wrap className="grid gap-10 lg:grid-cols-[1fr_1.6fr] lg:gap-16">
        <div>
          <Eyebrow>FAQ</Eyebrow>
          <h2 className="sh-display mt-5 text-[34px] sm:text-[45px]">Questions, <span className="sh-hl">answered.</span></h2>
          <p className="mt-4 max-w-[340px] text-[17px] text-[var(--sh-graphite)]">The short version: it is local, it is free, and it never touches your originals.</p>
        </div>
        <div className="border-t border-black">
          {FAQ.map((f, i) => (
            <details key={f.q} className="group border-b border-black/15" open={i === 0}>
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 py-5 text-[18px] font-medium [&::-webkit-details-marker]:hidden sm:text-[20px]">
                <span className="sh-display tracking-[-0.015em]">{f.q}</span>
                <Plus size={18} strokeWidth={1.5} className="shrink-0 transition-transform duration-200 group-open:rotate-45" />
              </summary>
              <p className="-mt-1 max-w-[620px] pb-6 text-[16px] text-[var(--sh-graphite)]">{f.a}</p>
            </details>
          ))}
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────── Closing CTA ───────────────────────── */

export function Cta() {
  return (
    <section className="sh-dots relative overflow-hidden border-t border-black/10 bg-[var(--sh-mist)] py-20 lg:py-28">
      <Wrap className="flex flex-col items-center text-center">
        <Mark size={88} />
        <h2 className="sh-display-xl shl-xl mt-10 text-[clamp(54px,10vw,128px)]">
          Drag something.<br /><span className="sh-hl">Press Shift.</span>
        </h2>
        <p className="mt-8 max-w-[560px] text-[18px] text-[var(--sh-graphite)]">Free, local and open source. macOS 13+ on Apple silicon.</p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <a href="#" onClick={(e) => e.preventDefault()} className="sh-btn sh-btn-ink"><Download size={16} strokeWidth={2} />Download for Mac</a>
          <Jump to="#try" className="sh-btn sh-btn-ghost">Try the wheel here</Jump>
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────── Footer ───────────────────────── */

const COLS = [
  { h: 'Product', links: [['How it works', '#demo'], ['Features', '#features'], ['Pricing', '#pricing'], ['FAQ', '#faq']] },
  { h: 'Developers', links: [['CLI and MCP', '#agents'], ['Try the wheel', '#try'], ['Privacy', '#private']] },
  { h: 'Brand', links: [['Brand book', '#/sheet/book'], ['Home', '#top']] },
]

export function Footer() {
  return (
    <footer className="bg-[var(--sh-orange)] text-black">
      <Wrap className="pt-14 pb-8">
        <div className="grid gap-10 md:grid-cols-[1.4fr_repeat(3,1fr)]">
          <div>
            <span className="inline-flex items-center gap-2.5">
              <Mark size={26} accent="#FFFFFF" />
              <span className="sh-display text-[24px] leading-none tracking-[-0.04em]">anyfmt</span>
            </span>
            <p className="mt-4 max-w-[280px] text-[15px]">Convert, edit and share any file in the middle of a drag.</p>
          </div>
          {COLS.map((c) => (
            <div key={c.h}>
              <div className="sh-mono text-[12px]">{c.h}</div>
              <ul className="mt-4 grid gap-2 text-[15px]">
                {c.links.map(([l, href]) => (
                  <li key={l}>{href.startsWith('#/') ? <a href={href} className="sh-link">{l}</a> : <Jump to={href} className="hover:underline hover:underline-offset-[3px]">{l}</Jump>}</li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div aria-hidden className="sh-display-xl mt-14 select-none pb-[0.06em] text-[clamp(96px,27vw,360px)] leading-[0.9]">anyfmt</div>
        <div className="sh-mono mt-8 flex flex-col gap-2 border-t border-black pt-5 text-[11.5px] sm:flex-row sm:justify-between">
          <span>AGPL-3.0 · macOS 13+ · Apple silicon</span>
          <span>anyfmt.app</span>
        </div>
      </Wrap>
    </footer>
  )
}
