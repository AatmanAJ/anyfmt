/**
 * The centrepiece of each conversion guide, chosen by the guide's `visual`. Each shows what
 * actually changes between the two formats. No invented numbers: sizes appear only where they
 * are plain arithmetic (bitrate × time) or measured in docs/PERF.md.
 */
import NumberFlow from '@number-flow/react'
import { motion, useInView } from 'motion/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import catalog from '../../data/catalog.json'
import options from '../../data/options.json'
import type { Guide } from '../../data/guide-types'
import { EASE, SNAP } from '../../lib/hooks'
import { AppIcon } from '../AppIcon'
import { FormatChip } from '../ui'

const F = Object.fromEntries(catalog.formats.map((f) => [f.id, f])) as Record<string, (typeof catalog.formats)[number]>
const label = (id: string) => F[id]?.label ?? id.toUpperCase()
const kindOf = (id: string) => F[id]?.kind ?? 'document'

const Stage = ({ children, dark = false }: { children: ReactNode; dark?: boolean }) => (
  <div className={`relative overflow-hidden rounded-[28px] p-6 sm:p-8 ${dark ? 'bg-night text-white' : 'bg-white ring-1 ring-black/5'}`}>{children}</div>
)

function useLoop(n: number, ms = 1800) {
  const [i, setI] = useState(0)
  useEffect(() => { const t = window.setInterval(() => setI((x) => (x + 1) % n), ms); return () => clearInterval(t) }, [n, ms])
  return i
}

function Arrow() {
  return <svg width="44" height="16" viewBox="0 0 44 16" aria-hidden className="shrink-0 text-flare"><path d="M1 8h40M34 2l7 6-7 6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
}

/* photo: the same picture, re-wrapped */
function Photo({ g }: { g: Guide }) {
  const to = g.to, from = g.from[0]
  const alpha = ['png', 'webp', 'avif', 'tiff', 'heic'].includes(to)
  const flip = useLoop(2, 2200)
  return (
    <Stage>
      <div className="flex items-center justify-between gap-4">
        {[from, to].map((f, i) => (
          <div key={f} className="flex flex-1 flex-col items-center gap-3">
            <motion.div animate={{ scale: flip === i ? 1.03 : 0.97, opacity: flip === i ? 1 : 0.75 }} transition={{ duration: 0.8, ease: EASE }}
              className="relative aspect-[4/5] w-full max-w-[200px] overflow-hidden rounded-[16px] shadow-[0_20px_40px_-20px_rgba(0,0,0,.45)]"
              style={i === 1 && alpha ? { backgroundImage: 'conic-gradient(#eee 25%,#fff 0 50%,#eee 0 75%,#fff 0)', backgroundSize: '16px 16px' } : undefined}>
              <img src="/brand/wallpapers/anyfmt-molten-preview.jpg" alt="" className={`absolute inset-0 h-full w-full object-cover ${i === 1 && alpha ? '[mask-image:radial-gradient(70%_80%_at_50%_45%,#000_60%,transparent_62%)]' : ''}`} />
              <span className="absolute bottom-2.5 left-2.5"><FormatChip label={label(f)} kind={kindOf(f)} /></span>
            </motion.div>
            <p className="font-mono text-[12.5px] text-mute-2">photo.{f === 'jpg' ? 'jpg' : F[f]?.extensions[0]}</p>
          </div>
        ))}
      </div>
      <div className="mt-6 flex items-center justify-center gap-3 text-[13.5px] text-mute">
        <span>Same pixels</span><Arrow /><span>{alpha ? 'transparency can stay' : 'transparency becomes a solid colour'}</span>
      </div>
    </Stage>
  )
}

/* vector: edges at any zoom */
function Vector() {
  const [z, setZ] = useState(4)
  const px = Math.max(1, Math.round(z))
  return (
    <Stage>
      <div className="grid grid-cols-2 gap-4">
        {['SVG', 'PNG'].map((k, i) => (
          <div key={k} className="overflow-hidden rounded-[16px] bg-sand">
            <svg viewBox="0 0 100 100" className="aspect-square w-full" style={i === 1 ? { imageRendering: 'pixelated' } : undefined} aria-hidden>
              <defs><pattern id={`px-${px}`} width={px} height={px} patternUnits="userSpaceOnUse"><rect width={px} height={px} fill="none" stroke="rgba(0,0,0,.08)" strokeWidth="0.2" /></pattern></defs>
              <g transform={`translate(50 50) scale(${z}) translate(-50 -50)`}>
                {i === 0 ? <circle cx="50" cy="50" r="18" fill="#FF4A14" /> : Array.from({ length: 40 }, (_, y) => Array.from({ length: 40 }, (_, x) => { const cx = 30 + x + 0.5, cy = 30 + y + 0.5; return Math.hypot(cx - 50, cy - 50) < 18 ? <rect key={`${x}-${y}`} x={30 + x} y={30 + y} width="1.02" height="1.02" fill="#FF4A14" /> : null }))}
              </g>
              {i === 1 && z > 3 && <rect width="100" height="100" fill={`url(#px-${px})`} />}
            </svg>
            <p className="px-4 py-3 text-[13px] font-medium">{k}{i === 1 ? ' at 1× size' : ', drawn from maths'}</p>
          </div>
        ))}
      </div>
      <label className="mt-5 flex items-center gap-4 text-[14px]"><span className="font-medium">Zoom</span><input type="range" min={1} max={8} step={0.1} value={z} onChange={(e) => setZ(Number(e.target.value))} className="flex-1 accent-[#FF4A14]" /><span className="w-10 font-mono text-[13px]">{z.toFixed(1)}×</span></label>
      <p className="mt-3 text-[12.5px] text-mute-2">Render big enough the first time: set the size on the way out, not after.</p>
    </Stage>
  )
}

/* icon: one artwork, every size */
function Icon({ g }: { g: Guide }) {
  const icns = g.to === 'icns'
  const sizes = icns ? [16, 32, 64, 128, 256, 512] : [16, 24, 32, 48, 64, 128, 256]
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.5 })
  return (
    <Stage>
      <div ref={ref} className="flex min-h-[220px] flex-wrap items-end justify-center gap-4">
        {sizes.map((s, i) => (
          <motion.div key={s} initial={{ opacity: 0, y: 12 }} animate={seen ? { opacity: 1, y: 0 } : {}} transition={{ duration: 0.5, ease: EASE, delay: i * 0.07 }} className="flex flex-col items-center gap-2">
            <AppIcon size={Math.min(s, 96)} uid={`g${s}`} />
            <span className="font-mono text-[11px] text-mute-2">{s}{s > 96 ? '*' : ''}</span>
          </motion.div>
        ))}
      </div>
      <p className="mt-5 text-center text-[13px] text-mute">One {label(g.from[0])} in, {icns ? 'a .icns with every size macOS asks for' : 'a .ico with the sizes Windows uses'}. {icns ? 'Retina (@2x) variants are included.' : ''}</p>
      {sizes.some((s) => s > 96) && <p className="mt-1 text-center text-[11.5px] text-mute-3">* drawn smaller here</p>}
    </Stage>
  )
}

/* container: same streams, new box */
function Container({ g }: { g: Guide }) {
  const from = g.from[0], to = g.slug === 'trim-video' ? from : g.to
  const step = useLoop(3, 1500)
  const Box = ({ ext, on }: { ext: string; on: boolean }) => (
    <div className={`relative flex h-[170px] flex-1 flex-col justify-between rounded-[18px] p-3 transition-colors duration-500 ${on ? 'bg-white/10' : 'bg-white/[0.04]'}`}>
      <span className="w-fit rounded-md bg-flare px-1.5 py-0.5 text-[11px] font-bold uppercase">{ext}</span>
      <span className="text-[12px] text-white/50">.{ext} container</span>
    </div>
  )
  return (
    <Stage dark>
      <div className="relative flex items-stretch gap-4">
        <Box ext={label(from)} on={step === 0} />
        <Box ext={label(to)} on={step === 2} />
        <motion.div className="pointer-events-none absolute top-[54px] flex w-[calc(50%-24px)] flex-col gap-1.5 px-3"
          animate={{ left: step === 0 ? '0%' : step === 1 ? '25%' : 'calc(50% + 8px)' }} transition={{ duration: 0.9, ease: [0.65, 0, 0.35, 1] }}>
          <span className="rounded-[8px] bg-volt px-2 py-1.5 font-mono text-[11.5px] font-semibold text-ink">video · H.264</span>
          <span className="rounded-[8px] bg-amber px-2 py-1.5 font-mono text-[11.5px] font-semibold text-ink">audio · AAC</span>
        </motion.div>
      </div>
      <p className="mt-6 text-[13.5px] text-white/70">{g.slug === 'trim-video' ? 'A lossless trim cuts at keyframes and copies the streams; a frame-exact trim re-encodes only what it has to.' : 'When the video inside is already H.264 or HEVC, it is copied into the new container, not re-encoded. Same quality, a fraction of the time.'}</p>
    </Stage>
  )
}

/* gif: frames into a loop */
function Gif() {
  const fr = useLoop(8, 140)
  return (
    <Stage dark>
      <div className="flex gap-1.5 overflow-hidden">
        {Array.from({ length: 8 }, (_, i) => (
          <div key={i} className={`relative aspect-[4/3] flex-1 overflow-hidden rounded-[6px] transition-opacity ${i === fr ? 'opacity-100 ring-2 ring-volt' : 'opacity-45'}`}>
            <img src="/brand/wallpapers/anyfmt-ember-preview.jpg" alt="" className="absolute inset-0 h-full w-full object-cover" style={{ objectPosition: `${i * 12}% 50%` }} />
          </div>
        ))}
      </div>
      <div className="mt-5 grid grid-cols-[1fr_auto] items-center gap-5">
        <div className="relative aspect-[4/3] overflow-hidden rounded-[14px]">
          <img src="/brand/wallpapers/anyfmt-ember-preview.jpg" alt="" className="absolute inset-0 h-full w-full object-cover [image-rendering:pixelated]" style={{ objectPosition: `${fr * 12}% 50%`, filter: 'contrast(1.1) saturate(1.2)' }} />
          <span className="absolute bottom-2 left-2 rounded-md bg-ink/80 px-1.5 py-0.5 text-[11px] font-bold">GIF · loops</span>
        </div>
        <ul className="space-y-1.5 text-[12.5px]">
          {['Frame rate', 'Width', 'Colours', 'Dither', 'Loop'].map((o) => <li key={o} className="rounded-full bg-white/10 px-3 py-1">{o}</li>)}
        </ul>
      </div>
      <p className="mt-5 text-[13px] text-white/60">GIF holds 256 colours per frame. Fewer frames and a narrower width are what make it small.</p>
    </Stage>
  )
}

/* audio: waveform and the size a bitrate gives you */
type Opt = { id: string; kind: string; label: string; choices?: { id: string; label: string }[]; default?: unknown }
function Audio({ g }: { g: Guide }) {
  const opts = ((options as Record<string, { options: Opt[] }>)[g.to]?.options ?? []).find((o) => o.id === 'bitrate')
  const choices = opts?.choices ?? [{ id: '128', label: '128 kbps' }, { id: '192', label: '192 kbps' }, { id: '256', label: '256 kbps' }, { id: '320', label: '320 kbps' }]
  const [b, setB] = useState(String(opts?.default ?? choices[Math.min(2, choices.length - 1)].id))
  const kbps = Number(b) || 192
  const mbPerMin = (kbps * 60) / 8 / 1000
  const bars = Array.from({ length: 64 }, (_, i) => 0.25 + 0.75 * Math.abs(Math.sin(i * 0.42) * Math.cos(i * 0.13 + 1)))
  return (
    <Stage>
      <div className="flex h-[120px] items-center gap-[3px]">
        {bars.map((h, i) => <span key={i} className="flex-1 rounded-full bg-ink" style={{ height: `${h * 100}%`, opacity: 0.35 + (i % 9) / 14 }} />)}
      </div>
      <div className="mt-6 flex flex-wrap gap-1.5" role="radiogroup" aria-label="Bitrate">
        {choices.filter((c) => /^\d+$/.test(c.id)).map((c) => (
          <button key={c.id} type="button" role="radio" aria-checked={b === c.id} onClick={() => setB(c.id)} className={`h-9 rounded-full px-3.5 text-[13.5px] font-medium ring-1 ${b === c.id ? 'bg-ink text-white ring-ink' : 'ring-black/10'}`}>{c.label}</button>
        ))}
      </div>
      <p className="mt-5 flex items-baseline gap-2 text-[15px]"><span className="text-[34px] font-semibold tracking-[-0.04em]"><NumberFlow value={Math.round(mbPerMin * 100) / 100} format={{ maximumFractionDigits: 2 }} /> MB</span><span className="text-mute">per minute of {label(g.to)} at {kbps} kbps</span></p>
      <p className="mt-1 text-[12.5px] text-mute-2">Bitrate × time ÷ 8. The source's size doesn't change it.</p>
    </Stage>
  )
}

/* document: a page re-typeset */
function Document({ g }: { g: Guide }) {
  const Page = ({ tone, chip, k }: { tone: string; chip: string; k: string }) => (
    <div className={`relative aspect-[3/4] flex-1 rounded-[12px] p-4 shadow-[0_18px_36px_-18px_rgba(0,0,0,.35)] ${tone}`}>
      <span className="block h-2.5 w-2/3 rounded bg-ink/80" />
      <span className="mt-3 block h-1.5 w-full rounded bg-ink/15" /><span className="mt-1.5 block h-1.5 w-11/12 rounded bg-ink/15" /><span className="mt-1.5 block h-1.5 w-4/5 rounded bg-ink/15" />
      <span className="mt-4 block h-2 w-1/2 rounded bg-ink/60" />
      <span className="mt-2.5 block h-1.5 w-full rounded bg-ink/15" /><span className="mt-1.5 block h-1.5 w-10/12 rounded bg-ink/15" />
      <span className="absolute bottom-3 left-3"><FormatChip label={chip} kind={k} size="sm" /></span>
    </div>
  )
  return (
    <Stage>
      <div className="flex items-center gap-4">
        <Page tone="bg-[#FBFAF8]" chip={label(g.from[0])} k={kindOf(g.from[0])} />
        <Arrow />
        <Page tone="bg-white ring-1 ring-black/5" chip={label(g.to)} k={kindOf(g.to)} />
      </div>
      <p className="mt-6 text-[13.5px] text-mute">Headings, lists, tables and images carry over. {g.to === 'pdf' ? 'The text is typeset again for the page, so it stays sharp and selectable.' : ''}</p>
    </Stage>
  )
}

/* pdf: pages to images, to an editable document, or merged */
function Pdf({ g }: { g: Guide }) {
  const toImages = ['jpg', 'png', 'webp', 'heic', 'tiff'].includes(g.to)
  const merge = g.slug === 'merge-pdf'
  const step = useLoop(2, 2000)
  return (
    <Stage>
      {toImages ? (
        <div className="flex h-[220px] items-center justify-center">
          {[0, 1, 2, 3].map((i) => (
            <motion.div key={i} animate={{ x: step ? (i - 1.5) * 92 : (i - 1.5) * 6, rotate: step ? 0 : (i - 1.5) * 3 }} transition={{ duration: 0.9, ease: EASE }}
              className="absolute flex aspect-[3/4] w-[84px] flex-col justify-between rounded-[8px] bg-white p-2 shadow-[0_12px_24px_-12px_rgba(0,0,0,.4)] ring-1 ring-black/5">
              <span className="space-y-1">{[80, 95, 70].map((w, j) => <span key={j} className="block h-1 rounded bg-ink/20" style={{ width: `${w}%` }} />)}</span>
              <span className="w-fit rounded-[4px] bg-[#FF8A2A] px-1 text-[8.5px] font-bold uppercase text-white">{step ? `p${i + 1}.${g.to}` : 'pdf'}</span>
            </motion.div>
          ))}
        </div>
      ) : merge ? (
        <div className="flex h-[220px] items-center justify-center gap-3">
          {['A', 'B', 'C'].map((p, i) => (
            <motion.div key={p} animate={{ x: step ? (1 - i) * 74 : 0, opacity: 1 }} transition={{ duration: 0.8, ease: EASE }} className="flex aspect-[3/4] w-[90px] items-center justify-center rounded-[8px] bg-white text-[28px] font-semibold ring-1 ring-black/10">{p}</motion.div>
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4">
          <div className="rounded-[12px] bg-[#FBFAF8] p-4 ring-1 ring-black/5"><p className="text-[11px] font-semibold uppercase text-mute-2">PDF · fixed layout</p>
            <div className="mt-3 space-y-1.5">{[90, 70, 85].map((w, i) => <span key={i} className="block h-1.5 rounded bg-ink/20" style={{ width: `${w}%` }} />)}</div>
            <div className="mt-3 grid grid-cols-3 gap-px rounded bg-ink/15 p-px">{Array.from({ length: 9 }, (_, i) => <span key={i} className="h-4 bg-white" />)}</div>
          </div>
          <div className="rounded-[12px] bg-white p-4 ring-1 ring-black/10"><p className="text-[11px] font-semibold uppercase text-flare">{label(g.to)} · editable</p>
            <p className="mt-3 text-[12px] leading-[1.5]">Quarterly results<span className={`ml-px inline-block h-3 w-px bg-ink align-middle ${step ? 'opacity-100' : 'opacity-0'}`} /></p>
            <table className="mt-3 w-full border-collapse text-[10px]"><tbody>{[['Q1', '12'], ['Q2', '18'], ['Q3', '21']].map(([a, b]) => <tr key={a}><td className="border border-ink/20 px-1">{a}</td><td className="border border-ink/20 px-1">{b}</td></tr>)}</tbody></table>
          </div>
        </div>
      )}
      <p className="mt-5 text-[13.5px] text-mute">{toImages ? 'Every page becomes its own image, placed together in a folder.' : merge ? 'Pages stay vector, and each file keeps its bookmarks.' : 'Text is rebuilt into paragraphs, and tables are detected and rebuilt as real tables.'}</p>
    </Stage>
  )
}

/* sheet: cells to delimited text */
function Sheet({ g }: { g: Guide }) {
  const rows = [['Item', 'Qty', 'Price'], ['Paper', '4', '3.50'], ['Ink', '2', '12.00']]
  const sep = g.to === 'tsv' ? '\t' : ','
  return (
    <Stage>
      <div className="grid gap-4 sm:grid-cols-2">
        <table className="w-full border-collapse overflow-hidden rounded-[10px] text-[13px] ring-1 ring-black/10"><tbody>
          {rows.map((r, i) => <tr key={i}>{r.map((c, j) => <td key={j} className={`border border-black/10 px-2 py-1.5 ${i === 0 ? 'bg-sand font-semibold' : ''}`}>{c}</td>)}</tr>)}
        </tbody></table>
        <pre className="rounded-[10px] bg-night p-3 font-mono text-[12.5px] leading-[1.7] text-white/85">{rows.map((r) => r.join(sep === '\t' ? '  →  ' : sep)).join('\n')}</pre>
      </div>
      <p className="mt-5 text-[13.5px] text-mute">Values come across, formulas as their last saved results, and formatting stays behind. The first sheet by default, or every sheet as its own {label(g.to)}.</p>
    </Stage>
  )
}

/* subtitle: the cue format, character by character */
function Subtitle() {
  return (
    <Stage dark>
      <div className="grid gap-4 sm:grid-cols-2">
        <pre className="rounded-[12px] bg-white/[0.06] p-4 font-mono text-[12.5px] leading-[1.7] text-white/85">{'1\n00:00:01'}<span className="rounded bg-flare px-0.5 text-white">,</span>{'200 --> 00:00:03'}<span className="rounded bg-flare px-0.5 text-white">,</span>{'400\nHello there.'}</pre>
        <pre className="rounded-[12px] bg-white/[0.06] p-4 font-mono text-[12.5px] leading-[1.7] text-white/85"><span className="text-volt">WEBVTT</span>{'\n\n00:00:01'}<span className="rounded bg-volt px-0.5 text-ink">.</span>{'200 --> 00:00:03'}<span className="rounded bg-volt px-0.5 text-ink">.</span>{'400\nHello there.'}</pre>
      </div>
      <p className="mt-5 text-[13.5px] text-white/65">Same cues, timed to the millisecond. The header and the decimal mark change; styling carries across where both formats have it.</p>
    </Stage>
  )
}

/* archive: the listing moves across */
function Archive({ g }: { g: Guide }) {
  const files = ['photos/', 'photos/IMG_0042.heic', 'notes.md', 'budget.xlsx']
  const step = useLoop(2, 2000)
  return (
    <Stage>
      <div className="grid grid-cols-2 gap-4">
        {[g.from[0], g.to].map((ext, i) => (
          <div key={ext} className={`rounded-[14px] p-4 transition-colors duration-500 ${(step === 1) === (i === 1) ? 'bg-sand' : 'bg-sand/50'}`}>
            <FormatChip label={label(ext)} kind="archive" />
            <ul className="mt-3 space-y-1 font-mono text-[12px]">{files.map((f, j) => <motion.li key={f} animate={{ opacity: i === 0 || step === 1 ? 1 : 0.15 }} transition={{ delay: j * 0.08 }}>{f}</motion.li>)}</ul>
          </div>
        ))}
      </div>
      <p className="mt-5 text-[13.5px] text-mute">Unpacked and packed again, folders and all. Encrypted archives are refused with a clear message rather than guessed at.</p>
    </Stage>
  )
}

/* squeeze: compress towards a target */
function Squeeze({ g }: { g: Guide }) {
  const pdf = g.to === 'pdf.compress'
  const [target, setTarget] = useState(40)
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.5 })
  if (pdf) {
    return (
      <Stage>
        <div ref={ref} className="space-y-5">
          {[['Before', 4.1, 'MB'], ['After', 0.315, 'MB']].map(([l, v], i) => (
            <div key={String(l)}>
              <div className="flex justify-between text-[14.5px]"><span>{l}</span><span className="font-mono font-semibold">{i ? '315 KB' : '4.1 MB'}</span></div>
              <div className="mt-2 h-4 overflow-hidden rounded-full bg-sand"><div className={`h-full rounded-full ${i ? 'bg-flare' : 'bg-ink'}`} style={{ width: seen ? `${(Number(v) / 4.1) * 100}%` : '0%', transition: `width 1.2s ${SNAP}` }} /></div>
            </div>
          ))}
        </div>
        <p className="mt-6 text-[13.5px] text-mute">The test PDF from anyfmt's own suite. Text stays vector; only images are recompressed.</p>
      </Stage>
    )
  }
  return (
    <Stage>
      <div className="flex items-end gap-4">
        <div className="flex-1"><p className="text-[13px] text-mute-2">Original</p><div className="mt-2 h-28 rounded-[12px] bg-ink" /></div>
        <div className="flex-1"><p className="text-[13px] text-mute-2">Your target</p><div className="mt-2 flex h-28 items-end"><motion.div className="w-full rounded-[12px] bg-flare" animate={{ height: `${target}%` }} transition={{ duration: 0.5, ease: EASE }} /></div></div>
      </div>
      <label className="mt-6 flex items-center gap-4 text-[14px]"><span className="font-medium">Target</span><input type="range" min={10} max={90} value={target} onChange={(e) => setTarget(Number(e.target.value))} className="flex-1 accent-[#FF4A14]" /><span className="w-12 font-mono text-[13px]">{target} %</span></label>
      <p className="mt-4 text-[13px] text-mute">Pick a quality, a percentage or an exact size. anyfmt aims at it and never hands back a bigger file than you started with.</p>
    </Stage>
  )
}

/* cutout: the background lifts away */
function Cutout() {
  const on = useLoop(2, 2000)
  return (
    <Stage>
      <div className="relative mx-auto aspect-[4/3] max-w-[420px] overflow-hidden rounded-[16px]" style={{ backgroundImage: 'conic-gradient(#e8e4df 25%,#fff 0 50%,#e8e4df 0 75%,#fff 0)', backgroundSize: '18px 18px' }}>
        <motion.img src="/brand/wallpapers/anyfmt-night-preview.jpg" alt="" className="absolute inset-0 h-full w-full object-cover" animate={{ opacity: on ? 0 : 1 }} transition={{ duration: 0.9, ease: EASE }} />
        <svg viewBox="0 0 400 300" className="absolute inset-0 h-full w-full" aria-hidden>
          <ellipse cx="200" cy="300" rx="110" ry="80" fill="#FF4A14" /><circle cx="200" cy="150" r="58" fill="#FFB23E" />
        </svg>
      </div>
      <p className="mt-5 text-center text-[13.5px] text-mute">The subject stays; the background becomes transparent PNG. Any subject on macOS 14 and later, people on macOS 13.</p>
    </Stage>
  )
}

/* scrub: metadata rows struck out */
function Scrub() {
  const rows = [['Camera', 'iPhone 16 Pro'], ['Location', '54.597, -5.930'], ['Taken', '18 Oct 2026, 11:32'], ['Software', 'iOS 26.1'], ['Lens', '24 mm f/1.78']]
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.6 })
  return (
    <Stage>
      <div ref={ref} className="divide-y divide-line overflow-hidden rounded-[14px] ring-1 ring-line">
        {rows.map(([k, v], i) => (
          <div key={k} className="relative grid grid-cols-[110px_1fr] px-4 py-2.5 text-[14px]">
            <span className="text-mute-2">{k}</span><span className="font-mono text-[13px]">{v}</span>
            <span className="absolute left-3 right-3 top-1/2 h-[2px] origin-left bg-flare" style={{ transform: seen ? 'scaleX(1)' : 'scaleX(0)', transition: `transform .6s ${SNAP} ${300 + i * 140}ms` }} />
          </div>
        ))}
      </div>
      <p className="mt-5 text-[13.5px] text-mute">Example values. Everything above goes; the picture, sound or pages stay.</p>
    </Stage>
  )
}

export function GuideVisual({ g }: { g: Guide }) {
  switch (g.visual) {
    case 'photo': return <Photo g={g} />
    case 'vector': return <Vector />
    case 'icon': return <Icon g={g} />
    case 'container': return <Container g={g} />
    case 'gif': return <Gif />
    case 'audio': return <Audio g={g} />
    case 'document': return <Document g={g} />
    case 'pdf': return <Pdf g={g} />
    case 'sheet': return <Sheet g={g} />
    case 'subtitle': return <Subtitle />
    case 'archive': return <Archive g={g} />
    case 'squeeze': return <Squeeze g={g} />
    case 'cutout': return <Cutout />
    case 'scrub': return <Scrub />
  }
}

export const formatLabel = label
export const formatKind = kindOf
