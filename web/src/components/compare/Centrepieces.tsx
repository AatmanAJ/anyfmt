/**
 * One interactive object per comparison, each built around the single fact that matters most
 * for that pair. Numbers come from the comparison data or from anyfmt's own measurements.
 */
import NumberFlow from '@number-flow/react'
import { Lock } from '@phosphor-icons/react'
import { AnimatePresence, motion, useInView } from 'motion/react'
import { useEffect, useRef, useState } from 'react'
import catalog from '../../data/catalog.json'
import { EASE, SNAP } from '../../lib/hooks'

const Panel = ({ children, dark = false, className = '' }: { children: React.ReactNode; dark?: boolean; className?: string }) => (
  <div className={`relative overflow-hidden rounded-[28px] p-6 sm:p-8 ${dark ? 'bg-night text-white' : 'bg-white ring-1 ring-black/5'} ${className}`}>{children}</div>
)

/* Tangerine: the route tables, one dot per route, side by side. */
export function Routes({ them, theirs }: { them: string; theirs: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.3 })
  const ours = catalog.counts.routes
  const Field = ({ n, label, tone }: { n: number; label: string; tone: string }) => (
    <div>
      <div className="flex items-baseline justify-between"><p className="text-[15px] font-semibold">{label}</p><p className="text-[28px] font-semibold tracking-[-0.04em]"><NumberFlow value={seen ? n : 0} /></p></div>
      <div className="mt-3 grid gap-[2px] [grid-template-columns:repeat(34,minmax(0,1fr))]">
        {Array.from({ length: n }, (_, i) => <span key={i} className="aspect-square rounded-[1.5px]" style={{ background: seen ? tone : 'rgba(0,0,0,.06)', transition: `background .4s ${Math.min(i * 1.4, 1100)}ms` }} />)}
      </div>
    </div>
  )
  return (
    <Panel>
      <div ref={ref} className="grid gap-8">
        <Field n={theirs} label={them} tone="#C9C3BC" />
        <Field n={ours} label="anyfmt" tone="#FF4A14" />
      </div>
      <p className="mt-6 text-[13px] text-mute-2">One square per conversion route. {them}'s figure is its published “conversion options”.</p>
    </Panel>
  )
}

/* convt: a right-click menu walk against one gesture. */
export function Clicks({ them }: { them: string }) {
  const [step, setStep] = useState(0)
  useEffect(() => { const t = window.setInterval(() => setStep((s) => (s + 1) % 5), 1300); return () => clearInterval(t) }, [])
  const theirSteps = ['Right-click the file', `Convert with ${them}`, 'Pick WebP', 'Done']
  return (
    <Panel>
      <div className="grid gap-6 sm:grid-cols-2">
        <div>
          <p className="text-[13px] font-semibold uppercase tracking-[0.12em] text-mute-2">{them}</p>
          <ol className="mt-4 space-y-2">
            {theirSteps.map((s, i) => (
              <li key={s} className={`flex items-center gap-3 rounded-[12px] px-3 py-2.5 text-[14.5px] transition-colors duration-300 ${step === i ? 'bg-ink text-white' : step > i ? 'bg-sand-2 text-mute' : 'bg-sand'}`}>
                <span className="font-mono text-[12px] opacity-60">{i + 1}</span>{s}
              </li>
            ))}
          </ol>
        </div>
        <div>
          <p className="text-[13px] font-semibold uppercase tracking-[0.12em] text-flare">anyfmt</p>
          <div className="mt-4 flex h-[188px] flex-col justify-between rounded-[16px] bg-night p-4 text-white">
            <p className="text-[14.5px]">Already dragging the file?</p>
            <div className="flex items-center gap-3">
              <span className={`inline-flex h-12 min-w-14 items-center justify-center rounded-[12px] bg-white text-[22px] text-ink transition-transform ${step % 2 ? 'translate-y-[3px]' : 'shadow-[0_4px_0_#9a948d]'}`}>⇧</span>
              <span className="text-[14px] text-white/70">tap, then drop on WebP</span>
            </div>
            <p className="text-[13px] text-volt">One motion. No menu.</p>
          </div>
        </div>
      </div>
    </Panel>
  )
}

/* Permute: which macOS versions each one runs on. */
export function Timeline({ them, from }: { them: string; from: string }) {
  const VERS = ['13', '14', '15', '26']
  const NAMES = ['Ventura', 'Sonoma', 'Sequoia', 'Tahoe']
  const start = VERS.indexOf(from)
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.5 })
  const Bar = ({ label, s, tone }: { label: string; s: number; tone: string }) => (
    <div className="grid grid-cols-[90px_1fr] items-center gap-4">
      <p className="text-[15px] font-semibold">{label}</p>
      <div className="relative h-10 rounded-full bg-sand">
        <span className="absolute inset-y-1 rounded-full" style={{ left: `calc(${(s / 4) * 100}% + 4px)`, right: 4, background: tone, transformOrigin: 'right', transform: seen ? 'scaleX(1)' : 'scaleX(0)', transition: `transform 1.1s ${SNAP}` }} />
      </div>
    </div>
  )
  return (
    <Panel>
      <div ref={ref} className="space-y-4">
        <div className="grid grid-cols-[90px_1fr] gap-4"><span /><div className="grid grid-cols-4 text-center">{VERS.map((v, i) => <p key={v} className="text-[13px] text-mute-2"><span className="block text-[17px] font-semibold text-ink">{v}</span>{NAMES[i]}</p>)}</div></div>
        <Bar label="anyfmt" s={0} tone="#FF4A14" />
        <Bar label={them} s={start} tone="#0A0A0A" />
      </div>
      <p className="mt-6 text-[13px] text-mute-2">macOS versions each app's current release supports.</p>
    </Panel>
  )
}

/* CloudConvert: the transfer you skip. */
const SIZES = [50, 200, 500, 1000, 2000, 4000]
const SPEEDS = [10, 50, 100, 300]
export function Upload() {
  const [s, setS] = useState(3)
  const [v, setV] = useState(1)
  const mb = SIZES[s], mbps = SPEEDS[v]
  const up = (mb * 8) / mbps, down = up // a converted file can be smaller or larger; assume similar
  const fmt = (x: number) => (x >= 60 ? `${Math.floor(x / 60)} min ${Math.round(x % 60)} s` : `${Math.round(x)} s`)
  const max = (SIZES[SIZES.length - 1] * 8) / SPEEDS[0] * 2
  return (
    <Panel dark>
      <div className="grid gap-5 sm:grid-cols-2">
        <label className="block"><span className="text-[13px] text-white/60">File size</span>
          <div className="mt-2 flex flex-wrap gap-1.5">{SIZES.map((x, i) => <button key={x} type="button" onClick={() => setS(i)} className={`h-9 rounded-full px-3 text-[13.5px] font-medium ${s === i ? 'bg-white text-ink' : 'bg-white/10'}`}>{x >= 1000 ? `${x / 1000} GB` : `${x} MB`}</button>)}</div>
        </label>
        <label className="block"><span className="text-[13px] text-white/60">Your connection</span>
          <div className="mt-2 flex flex-wrap gap-1.5">{SPEEDS.map((x, i) => <button key={x} type="button" onClick={() => setV(i)} className={`h-9 rounded-full px-3 text-[13.5px] font-medium ${v === i ? 'bg-white text-ink' : 'bg-white/10'}`}>{x} Mbps</button>)}</div>
        </label>
      </div>
      <div className="mt-8 space-y-5">
        <div>
          <div className="flex justify-between text-[14px]"><span>Upload, then download</span><span className="font-semibold">{fmt(up + down)}</span></div>
          <div className="mt-2 h-3 overflow-hidden rounded-full bg-white/10"><motion.div className="h-full rounded-full bg-white/70" animate={{ width: `${Math.max(2, (Math.log10(1 + up + down) / Math.log10(1 + max)) * 100)}%` }} transition={{ duration: 0.6, ease: EASE }} /></div>
        </div>
        <div>
          <div className="flex justify-between text-[14px]"><span>anyfmt</span><span className="font-semibold text-volt">0 s</span></div>
          <div className="mt-2 h-3 rounded-full bg-white/10"><div className="h-full w-[6px] rounded-full bg-volt" /></div>
        </div>
      </div>
      <p className="mt-6 text-[12.5px] leading-[1.5] text-white/50">Transfer time only (bar on a log scale), at your full connection speed, assuming the result is about the same size. Conversion time comes on top either way. Above 1 GB the free online tier refuses the file.</p>
    </Panel>
  )
}

/* Clop: the free tier's per-session limit, felt. */
export function Session({ them }: { them: string }) {
  const [n, setN] = useState(0)
  return (
    <Panel>
      <div className="grid gap-4 sm:grid-cols-2">
        {[{ name: `${them} free`, cap: 5 }, { name: 'anyfmt', cap: Infinity }].map((lane) => {
          const used = Math.min(n, lane.cap)
          const locked = n >= lane.cap
          return (
            <div key={lane.name} className={`rounded-[18px] p-4 ${lane.cap === Infinity ? 'bg-night text-white' : 'bg-sand'}`}>
              <div className="flex items-center justify-between"><p className="text-[14px] font-semibold">{lane.name}</p><p className="font-mono text-[13px]">{used}{lane.cap === Infinity ? '' : ` / ${lane.cap}`}</p></div>
              <div className="mt-4 grid grid-cols-8 gap-1.5">
                {Array.from({ length: 16 }, (_, i) => (
                  <span key={i} className={`aspect-square rounded-[4px] transition-colors duration-300 ${i < Math.min(used, 16) ? (lane.cap === Infinity ? 'bg-volt' : 'bg-flare') : lane.cap === Infinity ? 'bg-white/10' : i >= lane.cap ? 'bg-black/[0.04]' : 'bg-white'}`} />
                ))}
              </div>
              <AnimatePresence>{locked && <motion.p initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} className="mt-3 flex items-center gap-1.5 text-[13px] font-medium"><Lock size={13} weight="bold" />Limit reached for this session</motion.p>}</AnimatePresence>
            </div>
          )
        })}
      </div>
      <div className="mt-6 flex items-center gap-3">
        <button type="button" onClick={() => setN((x) => x + 1)} className="h-11 rounded-full bg-ink px-5 text-[15px] font-medium text-white transition-transform active:scale-95">Convert a file</button>
        <button type="button" onClick={() => setN(0)} className="h-11 rounded-full px-4 text-[14px] text-mute">Reset</button>
      </div>
      <p className="mt-4 text-[12.5px] text-mute-2">{them}'s free version limits drop zones, conversions, folder watching and its CLI to 5 per session each.</p>
    </Panel>
  )
}

/* HandBrake: rewrap vs re-encode, measured on anyfmt. */
export function Passthrough() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.5 })
  const rows: [string, number, string][] = [['Rewrap, no re-encode', 0.23, '111.9 MB · bit-exact'], ['Re-encode, VideoToolbox', 3.39, '45.4 MB · SSIM 0.995'], ['Re-encode, libx264 CRF 23', 4.91, '44.3 MB · SSIM 0.995']]
  return (
    <Panel>
      <div ref={ref} className="space-y-5">
        {rows.map(([l, s, note], i) => (
          <div key={l}>
            <div className="flex items-baseline justify-between gap-3 text-[14.5px]"><span className={i === 0 ? 'font-semibold' : ''}>{l}</span><span className="font-mono text-[14px] font-semibold">{s.toFixed(2)} s</span></div>
            <div className="mt-2 h-3 overflow-hidden rounded-full bg-sand"><div className={`h-full rounded-full ${i === 0 ? 'bg-flare' : 'bg-ink/80'}`} style={{ width: seen ? `${Math.max(2, (s / 4.91) * 100)}%` : '0%', transition: `width 1.2s ${SNAP} ${i * 120}ms` }} /></div>
            <p className="mt-1 text-[12.5px] text-mute-2">{note}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 text-[12.5px] text-mute-2">One-minute 1080p30 H.264 MOV to MP4, all three run by anyfmt on an M5 Max (docs/PERF.md). HandBrake wasn't timed; its docs say it always re-encodes.</p>
    </Panel>
  )
}

/* FFmpeg: the command you'd type, typed out. */
const CMD = 'ffmpeg -i clip.mov -vf "fps=10,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" -loop 0 clip.gif'
export function Terminal() {
  const ref = useRef<HTMLDivElement>(null)
  const seen = useInView(ref, { once: true, amount: 0.5 })
  const [n, setN] = useState(0)
  useEffect(() => { if (!seen) return; const id = window.setInterval(() => setN((x) => { if (x >= CMD.length) { clearInterval(id); return x } return x + 2 }), 24); return () => clearInterval(id) }, [seen])
  return (
    <div ref={ref} className="grid gap-4">
      <Panel dark>
        <p className="text-[13px] text-white/50">One way to make a good GIF by hand</p>
        <p className="mt-3 break-all font-mono text-[13px] leading-[1.7] text-white/90"><span className="text-flare">$ </span>{CMD.slice(0, n)}<span className="animate-blink inline-block h-[1.1em] w-[0.55em] translate-y-[3px] bg-white/80" /></p>
        <p className="mt-4 font-mono text-[12px] text-white/40">{CMD.length} characters</p>
      </Panel>
      <Panel>
        <p className="text-[13px] text-mute-2">With anyfmt</p>
        <p className="mt-3 flex flex-wrap items-center gap-2 text-[17px] font-medium">Drag clip.mov <span className="text-flare">→</span> tap <kbd className="rounded-md bg-sand-2 px-2 py-0.5 font-sans text-[15px] font-semibold shadow-[0_2px_0_#D9D4CE]">⇧</kbd> <span className="text-flare">→</span> drop on <span className="rounded-md bg-flare px-2 py-0.5 text-[13px] font-bold uppercase text-white">GIF</span></p>
        <p className="mt-3 text-[13px] text-mute-2">Same engine. Presets like “Small · 10 fps · 480 w” pick the flags.</p>
      </Panel>
    </div>
  )
}

/* macOS: Finder's Convert Image sheet next to the wheel. */
export function Menu() {
  const targets = catalog.formats.find((f) => f.id === 'heic')!.targets.filter((t) => t.wheel).map((t) => catalog.formats.find((f) => f.id === t.to)!.label)
  const [fmt, setFmt] = useState('JPEG')
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <Panel>
        <p className="text-[13px] text-mute-2">Finder › Quick Actions › Convert Image</p>
        <div className="mt-4 rounded-[14px] bg-[#ECEBE9] p-4 text-[13px] shadow-[inset_0_0_0_1px_rgba(0,0,0,.06)]">
          <p className="font-semibold">Convert Image</p>
          <div className="mt-3 flex items-center justify-between"><span>Format:</span>
            <span className="flex overflow-hidden rounded-md ring-1 ring-black/15">{['JPEG', 'PNG', 'HEIF'].map((f) => <button key={f} type="button" onClick={() => setFmt(f)} className={`px-2.5 py-1 ${fmt === f ? 'bg-[#2F7BF5] text-white' : 'bg-white'}`}>{f}</button>)}</span>
          </div>
          <div className="mt-2 flex items-center justify-between"><span>Image Size:</span><span className="rounded-md bg-white px-2 py-0.5 ring-1 ring-black/15">Actual Size</span></div>
          <label className="mt-2 flex items-center gap-2"><input type="checkbox" defaultChecked readOnly className="accent-[#2F7BF5]" />Preserve Metadata</label>
        </div>
        <p className="mt-4 text-[13px] text-mute-2">3 formats out</p>
      </Panel>
      <Panel dark>
        <p className="text-[13px] text-white/50">anyfmt, same HEIC photo</p>
        <ul className="mt-4 flex flex-wrap gap-1.5">
          {targets.map((t, i) => <motion.li key={t} initial={{ opacity: 0, scale: 0.8 }} whileInView={{ opacity: 1, scale: 1 }} viewport={{ once: true }} transition={{ delay: i * 0.05 }} className="rounded-[8px] bg-white/10 px-2.5 py-1.5 text-[13px] font-semibold">{t}</motion.li>)}
        </ul>
        <p className="mt-4 text-[13px] text-white/50">{targets.length} on the wheel, more opt-in</p>
      </Panel>
    </div>
  )
}
