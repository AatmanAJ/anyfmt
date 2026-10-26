import { Pixels } from '../Mark'
import { landscape } from './pixel'
import { PX } from './ui'

const SCENE = landscape(120, 60)
const SCENE_SM = landscape(64, 44, { cursor: false, files: false })

const CONTENTS = [
  ['01', 'Logo', 'The pixel wheel, the highlight name'],
  ['02', 'App icon', '1024 to 16, menu bar, Dock'],
  ['03', 'Colour', 'Monochrome first, one signal'],
  ['04', 'Type', 'Host Grotesk, Inter, Geist Mono'],
  ['05', 'Surfaces', 'Tint and hairline, never shadow'],
  ['06', 'Imagery', 'Pixels, halftone, the caret'],
  ['07', 'Voice', 'Precise, plain, local'],
  ['08', 'Components', 'Pills, cards, the wheel'],
  ['09', 'Onboarding', 'Seven windows, one minute'],
  ['10', 'App surfaces', 'Light and dark'],
  ['11', 'In the world', 'Docs, slides, print'],
]

export function Cover() {
  return (
    <section id="cover" data-sec="cover" className="scroll-mt-[64px] pt-6 md:pt-8">
      {/* Masthead */}
      <div className="flex items-center justify-between border-b border-black pb-2">
        <span className="shb-lbl">Vol. 01 · No. 1</span>
        <span className="shb-lbl hidden md:inline">The anyfmt brand book</span>
        <span className="shb-lbl">October 2026</span>
      </div>
      <div className="flex items-center justify-between border-b border-[var(--shb-line)] py-2">
        <span className="shb-lbl text-[var(--sh-graphite)]">Sheet edition</span>
        <span className="shb-lbl text-[var(--sh-graphite)]">anyfmt.app</span>
      </div>

      <h1 className="sh-display-xl mt-10 text-[72px] !leading-[0.98] md:mt-14 md:text-[150px] lg:text-[190px]">
        Any file,<br />any <span className="sh-hl">format.</span>
      </h1>

      <div className="mt-10 grid gap-6 md:mt-14 md:grid-cols-12 md:gap-8">
        <p className="text-[20px] leading-[1.4] md:col-span-6 md:text-[24px] md:leading-[1.3]">
          How anyfmt looks, sounds and behaves: a black-and-white broadsheet with a data terminal’s precision, and one orange box that says <i>here</i>.
        </p>
        <div className="md:col-span-5 md:col-start-8">
          <div className="shb-lbl grid grid-cols-2 gap-y-2 border-t border-black pt-3">
            <span className="text-[var(--sh-graphite)]">Product</span><span>anyfmt for macOS</span>
            <span className="text-[var(--sh-graphite)]">Platform</span><span>macOS 13+ · Apple silicon</span>
            <span className="text-[var(--sh-graphite)]">Licence</span><span>Open source · AGPL-3.0</span>
            <span className="text-[var(--sh-graphite)]">Edition</span><span>Sheet, v1.0</span>
          </div>
        </div>
      </div>

      {/* The piece: the wheel rising over a field of files. */}
      <figure className="mt-12 md:mt-16">
        <div className="sh-dots relative overflow-hidden rounded-[4px] bg-[var(--sh-sky)]">
          <Pixels rows={SCENE} palette={PX} px={10} className="hidden w-full md:block" style={{ width: '100%' }} />
          <Pixels rows={SCENE_SM} palette={PX} px={6} className="block w-full md:hidden" style={{ width: '100%' }} />
        </div>
        <figcaption className="mt-3 flex justify-between gap-4">
          <span className="shb-lbl text-[var(--sh-graphite)]">Fig. 1 · Sunrise over the Downloads folder · 120 × 60 px</span>
          <span className="shb-lbl hidden text-[var(--sh-graphite)] md:inline">Pixel palette, §06</span>
        </figcaption>
      </figure>

      {/* Contents, set like a magazine index. */}
      <div className="mt-16">
        <div className="flex items-baseline justify-between border-t border-black pt-3">
          <span className="shb-lbl">In this issue</span><span className="shb-lbl text-[var(--sh-graphite)]">11 sections</span>
        </div>
        <ol className="mt-2 grid md:grid-cols-3 md:gap-x-8">
          {CONTENTS.map(([n, t, d]) => (
            <li key={n} className="flex items-baseline gap-4 border-b border-[var(--shb-line)] py-3">
              <span className="shb-num text-[13px] text-[var(--sh-graphite)]">{n}</span>
              <span className="sh-display text-[20px]">{t}</span>
              <span className="ml-auto text-right text-[13px] text-[var(--sh-graphite)]">{d}</span>
            </li>
          ))}
        </ol>
      </div>
    </section>
  )
}
