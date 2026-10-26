import { AnimatePresence, motion, useInView, useReducedMotion } from 'motion/react'
import { ArrowUpRight, Check, Copy, FolderInput, Layers, Link2, RotateCcw, Share, SquareTerminal } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { isShot, NumberTicker, Reveal } from '../../shared/kit'
import { SheetWheel, type Wedge } from '../SheetWheel'
import { actionWedges, convertImage, convertVideo, STRIP, toolWedges } from './data'
import { Eyebrow, FileIcon, Scaled, SectionHead, Window, Wrap } from './ui'

/* ───────────────────────── Strip ───────────────────────── */

export function Strip() {
  return (
    <section aria-label="Formats" className="border-b border-black/10 bg-white py-10">
      <Wrap>
        <div className="flex flex-col gap-6 lg:flex-row lg:items-center lg:gap-10">
          <p className="sh-mono shrink-0 text-[12px] text-[var(--sh-graphite)] lg:w-[180px]">Reads and writes<br className="hidden lg:block" /> 793 routes, including</p>
          <ul className="grid flex-1 grid-cols-3 gap-px bg-black/10 p-px sm:grid-cols-6">
            {STRIP.map(([f, kind]) => (
              <li key={f} className="flex h-[76px] flex-col justify-between bg-[var(--sh-slate)] px-3 py-2.5">
                <span className="sh-display text-[22px] leading-none tracking-[-0.03em]">{f}</span>
                <span className="sh-mono text-[10.5px] text-[var(--sh-graphite)]">{kind}</span>
              </li>
            ))}
          </ul>
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────── Features ───────────────────────── */

function MiniWindow({ title, children }: { title: string; children: ReactNode }) {
  return <Window title={title} className="mt-auto w-full" bodyClassName="h-[176px]">{children}</Window>
}

function ConvertMock() {
  return (
    <MiniWindow title="clip.mov">
      <div className="grid h-full place-items-center">
        <SheetWheel size={156} wedges={convertVideo.map((w) => ({ ...w, sub: undefined }))} active={0} hub={<span className="sh-mono text-[9px]">MOV</span>} />
      </div>
    </MiniWindow>
  )
}

function ToolsMock() {
  return (
    <MiniWindow title="Crop · photo.heic">
      <div className="relative h-full overflow-hidden bg-[var(--sh-sky)]">
        <div className="absolute inset-x-0 bottom-0 h-[44%] bg-[var(--sh-px-green)]" />
        <div className="absolute bottom-[44%] left-[18%] h-[30px] w-[30px] rounded-full bg-[var(--sh-px-yellow)]" />
        <div className="absolute inset-0 bg-white/55" style={{ clipPath: 'polygon(0 0,100% 0,100% 100%,0 100%,0 18%,22% 18%,22% 82%,78% 82%,78% 18%,0 18%)' }} />
        <div className="absolute left-[22%] right-[22%] top-[18%] bottom-[18%] border border-black">
          {['-left-[3px] -top-[3px]', '-right-[3px] -top-[3px]', '-left-[3px] -bottom-[3px]', '-right-[3px] -bottom-[3px]'].map((c) => <span key={c} className={`absolute size-[6px] bg-black ${c}`} />)}
          <span className="absolute left-1/3 top-0 bottom-0 border-l border-black/30" /><span className="absolute left-2/3 top-0 bottom-0 border-l border-black/30" />
          <span className="absolute top-1/3 left-0 right-0 border-t border-black/30" /><span className="absolute top-2/3 left-0 right-0 border-t border-black/30" />
        </div>
        <span className="sh-mono absolute bottom-2 left-2 bg-white px-1.5 py-0.5 text-[9.5px]">Saves a new copy</span>
      </div>
    </MiniWindow>
  )
}

function ActionsMock() {
  const rows: [ReactNode, string, string?][] = [
    [<Share size={13} strokeWidth={1.5} />, 'AirDrop'], [<Layers size={13} strokeWidth={1.5} />, 'Float shelf', 'held'],
    [<Copy size={13} strokeWidth={1.5} />, 'Copy'], [<FolderInput size={13} strokeWidth={1.5} />, 'Move to', '~/Projects'],
    [<Link2 size={13} strokeWidth={1.5} />, 'Copy Path'], [<SquareTerminal size={13} strokeWidth={1.5} />, 'Open in Terminal'],
  ]
  return (
    <MiniWindow title="⌃ Actions">
      <ul className="py-1.5">
        {rows.map(([icon, label, note], i) => (
          <li key={label} className={`mx-1.5 flex h-[26px] items-center gap-2 rounded-[3px] px-2 text-[12.5px] ${i === 1 ? 'bg-black text-white' : ''}`}>
            {icon}<span className="flex-1">{label}</span>{note && <span className={`sh-code text-[10.5px] ${i === 1 ? 'text-white/70' : 'text-[var(--sh-graphite)]'}`}>{note}</span>}
          </li>
        ))}
      </ul>
    </MiniWindow>
  )
}

function PresetsMock() {
  const chips = [['GIF', '15 fps'], ['JPG', '80 %'], ['WEBP', 'lossless']]
  return (
    <MiniWindow title="Presets">
      <div className="flex h-full flex-col gap-2 p-3">
        {chips.map(([f, v], i) => (
          <div key={f} className="flex h-[34px] items-center gap-2 rounded-full pl-1 pr-3 text-[13px]" style={{ boxShadow: 'inset 0 0 0 1px #000', background: i === 0 ? '#000' : '#fff', color: i === 0 ? '#fff' : '#000' }}>
            <span className="sh-mono rounded-full px-2 py-[5px] text-[10px]" style={{ background: i === 0 ? '#fff' : '#000', color: i === 0 ? '#000' : '#fff' }}>{f}</span>
            {v}<span className="ml-auto sh-code text-[10.5px] opacity-60">{i === 0 ? 'on the wheel' : ''}</span>
          </div>
        ))}
        <div className="sh-code mt-auto text-[11px] text-[var(--sh-graphite)]">+ New preset from the last drop</div>
      </div>
    </MiniWindow>
  )
}

const FEATURES = [
  { key: '⇧ Shift', title: 'Convert', body: '793 routes across images, video, audio, documents, ebooks and archives. Multi-hop routes picked for quality.', mock: <ConvertMock /> },
  { key: '⌘ Command', title: 'Tools', body: 'Crop, trim, compress to a size, redact, annotate, add a background. Each one saves a new copy.', mock: <ToolsMock /> },
  { key: '⌃ Control', title: 'Actions', body: 'AirDrop, a Float shelf that holds files between drags, Copy Path, Terminal, recent folders.', mock: <ActionsMock /> },
  { key: 'On every wheel', title: 'Presets', body: 'Your GIF at 15 fps, your JPG at 80 %. One chip on the wheel, synced if you want.', mock: <PresetsMock /> },
]

export function Features() {
  return (
    <section id="features" className="scroll-mt-16 py-20 lg:py-24">
      <Wrap>
        <SectionHead eyebrow="Three keys, one gesture"
          title={<>Every file job, <span className="sh-hl">one key</span> away.</>}
          sub="Hold a modifier mid-drag and the wheel changes. Shift for formats, Command for tools, Control for where it goes next." />
        <div className="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {FEATURES.map((f, i) => (
            <Reveal key={f.title} delay={i * 0.06} className="flex">
              <article className="sh-card flex w-full flex-col bg-[var(--sh-lavender)] p-5">
                <Eyebrow className="text-[12px]">{f.key}</Eyebrow>
                <h3 className="sh-display mt-6 text-[24px] leading-[1.3]">{f.title}</h3>
                <p className="mt-2 mb-6 text-[15px] leading-[1.5] text-[var(--sh-graphite)]">{f.body}</p>
                {f.mock}
              </article>
            </Reveal>
          ))}
        </div>
      </Wrap>
    </section>
  )
}

/* ───────────────────────── Product rows ───────────────────────── */

function Row({ id, visual, children }: { id?: string; visual: ReactNode; children: ReactNode }) {
  return (
    <div id={id} className="grid scroll-mt-20 items-center gap-10 lg:grid-cols-[55fr_45fr] lg:gap-16">
      <Reveal className="min-w-0">{visual}</Reveal>
      <div className="min-w-0">{children}</div>
    </div>
  )
}

function RowText({ eyebrow, title, children }: { eyebrow: string; title: ReactNode; children: ReactNode }) {
  return (
    <>
      <Eyebrow>{eyebrow}</Eyebrow>
      <h2 className="sh-display mt-5 text-[34px] sm:text-[45px]">{title}</h2>
      <div className="mt-5 text-[17px] text-[var(--sh-graphite)]">{children}</div>
    </>
  )
}

function Ticks({ items }: { items: ReactNode[] }) {
  return (
    <ul className="mt-6 grid gap-2.5 text-[15.5px] text-black">
      {items.map((t, i) => <li key={i} className="flex items-start gap-2.5"><Check size={16} strokeWidth={1.75} className="mt-[3px] shrink-0" />{t}</li>)}
    </ul>
  )
}

/* Code card: types the command, then streams the NDJSON events. */

const CMD = 'anyfmt convert clip.mov --to gif --json'
const EVENTS: [string, string | number][][] = [
  [['event', 'start'], ['jobs', 1]],
  [['event', 'progress'], ['file', '/Users/me/clip.mov'], ['fraction', 0.31]],
  [['event', 'progress'], ['file', '/Users/me/clip.mov'], ['fraction', 0.74]],
  [['event', 'progress'], ['file', '/Users/me/clip.mov'], ['fraction', 1]],
  [['event', 'output'], ['file', '/Users/me/clip.mov'], ['path', '/Users/me/clip.gif']],
  [['event', 'done'], ['succeeded', 1], ['failed', 0], ['skipped', 0], ['exitCode', 0]],
]

function JsonLine({ pairs }: { pairs: [string, string | number][] }) {
  return (
    <div className="break-all sm:whitespace-nowrap sm:break-normal">
      {'{'}
      {pairs.map(([k, v], i) => (
        <span key={k}>
          <span className="text-black/55">"{k}"</span>:{typeof v === 'string' ? <span>"{v}"</span> : <span className="font-semibold">{v}</span>}{i < pairs.length - 1 ? ',' : ''}
        </span>
      ))}
      {'}'}
    </div>
  )
}

function CodeCard() {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: true, margin: '-80px' })
  const reduce = useReducedMotion()
  const done = isShot || !!reduce
  const [typed, setTyped] = useState(done ? CMD.length : 0)
  const [lines, setLines] = useState(done ? EVENTS.length : 0)
  const [run, setRun] = useState(0)

  useEffect(() => {
    if (done || !inView) return
    let i = 0, j = 0
    const timers: ReturnType<typeof setTimeout>[] = []
    setTyped(0); setLines(0)
    const type = () => {
      i++; setTyped(i)
      if (i < CMD.length) timers.push(setTimeout(type, 38 + Math.random() * 40))
      else timers.push(setTimeout(stream, 420))
    }
    const stream = () => {
      j++; setLines(j)
      if (j < EVENTS.length) timers.push(setTimeout(stream, j === 1 ? 260 : 340))
    }
    timers.push(setTimeout(type, 500))
    return () => timers.forEach(clearTimeout)
  }, [inView, done, run])

  const finished = typed === CMD.length && lines === EVENTS.length
  return (
    <div ref={ref} className="sh-card bg-[var(--sh-sky)] p-0">
      <div className="flex items-center justify-between border-b border-black/15 px-5 py-3">
        <span className="sh-mono text-[11.5px]">Terminal · zsh</span>
        <button onClick={() => setRun((r) => r + 1)} disabled={done || !finished} className="sh-mono flex items-center gap-1.5 text-[11.5px] disabled:opacity-0" aria-label="Replay">
          <RotateCcw size={12} strokeWidth={1.75} />Replay
        </button>
      </div>
      <div className="sh-code overflow-x-auto px-5 py-5 text-[12px] leading-[1.9] xl:text-[12.5px]">
        <div className="break-all sm:whitespace-nowrap sm:break-normal">
          <span className="text-black/45">~ $ </span>{CMD.slice(0, typed)}
          {lines === 0 && <span className="sh-caret ml-px" />}
        </div>
        <div className="min-h-[154px]">
          {EVENTS.slice(0, lines).map((p, i) => (
            <motion.div key={`${run}-${i}`} initial={done ? false : { opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.2 }}>
              <JsonLine pairs={p} />
            </motion.div>
          ))}
          {finished && <div><span className="text-black/45">~ $ </span><span className="sh-caret" /></div>}
        </div>
      </div>
    </div>
  )
}

export function Agents() {
  return (
    <Row id="agents" visual={<CodeCard />}>
      <RowText eyebrow="For agents" title={<>Agents can <span className="sh-hl whitespace-nowrap">drive it.</span></>}>
        <p>Everything on the wheel is also a command. <code className="sh-code text-[15px] text-black">--json</code> on every command, NDJSON progress on stdout, and an MCP server, so Claude can convert your files on your Mac.</p>
      </RowText>
      <div className="sh-code mt-6 flex items-center justify-between gap-3 overflow-x-auto rounded-[4px] bg-[var(--sh-slate)] px-4 py-3 text-[13px]" style={{ boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.1)' }}>
        <span className="whitespace-nowrap"><span className="text-black/45">$ </span>claude mcp add anyfmt -- anyfmt mcp</span>
        <span className="sh-mono shrink-0 text-[10.5px] text-[var(--sh-graphite)]">MCP</span>
      </div>
      <Ticks items={['Same engines and routes as the app', 'Stable exit codes and error codes', 'Cancel with ^C; temp files go, nothing is placed']} />
      <a href="#faq" className="sh-link mt-7 inline-flex items-center gap-1 text-[15.5px]">How agents use it<ArrowUpRight size={15} strokeWidth={1.75} /></a>
    </Row>
  )
}

/* Playground: real modifier keys switch the wheel; picks go to a log. */

const FILES = [
  { name: 'clip.mov', base: 'clip', ext: 'MOV' },
  { name: 'photo.heic', base: 'photo', ext: 'HEIC' },
] as const

const MODES = [
  { key: '⇧', name: 'Shift', code: 'Shift', wheel: 'Convert' },
  { key: '⌘', name: 'Command', code: 'Meta', wheel: 'Tools' },
  { key: '⌃', name: 'Control', code: 'Control', wheel: 'Actions' },
]

type Line = { id: number; key: string; text: string; out: string }

function result(mode: number, file: (typeof FILES)[number], w: Wedge): Omit<Line, 'id'> {
  const k = MODES[mode].key
  if (mode === 0) return { key: k, text: `${file.name} → ${w.label}`, out: `${file.base}.${w.label.toLowerCase()}` }
  if (mode === 1) return { key: k, text: `${w.label} ${file.name}`, out: 'new copy, original untouched' }
  const out: Record<string, string> = {
    AirDrop: 'AirDrop sheet opened', Float: 'held on the Float shelf', Copy: 'copied to the clipboard',
    Move: 'moved to a recent folder', 'Copy Path': `~/Desktop/${file.name}`, Terminal: 'Terminal opened in ~/Desktop',
  }
  return { key: k, text: `${w.label} ${file.name}`, out: out[w.label] }
}

const SEED: Line[] = isShot ? [
  { id: -3, key: '⇧', text: 'clip.mov → GIF', out: 'clip.gif' },
  { id: -2, key: '⌘', text: 'Trim clip.mov', out: 'new copy, original untouched' },
  { id: -1, key: '⌃', text: 'AirDrop clip.mov', out: 'AirDrop sheet opened' },
] : []

function Playground() {
  const [mode, setMode] = useState(0)
  const [held, setHeld] = useState<number | null>(null)
  const [file, setFile] = useState(0)
  const [log, setLog] = useState<Line[]>(SEED)
  const n = useRef(0)

  useEffect(() => {
    const idx = (e: KeyboardEvent) => MODES.findIndex((m) => m.code === e.key)
    const down = (e: KeyboardEvent) => { const i = idx(e); if (i < 0 || e.repeat) return; setHeld(i); setMode(i) }
    const up = (e: KeyboardEvent) => { if (idx(e) >= 0) setHeld(null) }
    const clear = () => setHeld(null)
    window.addEventListener('keydown', down); window.addEventListener('keyup', up); window.addEventListener('blur', clear)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up); window.removeEventListener('blur', clear) }
  }, [])

  const f = FILES[file], m = MODES[mode]
  const wedges = mode === 0 ? (file === 0 ? convertVideo : convertImage) : mode === 1 ? toolWedges : actionWedges
  const pick = (w: Wedge) => setLog((l) => [...l, { id: n.current++, ...result(mode, f, w) }].slice(-5))

  const visual = (
    <div className="sh-card sh-dots relative overflow-hidden bg-[var(--sh-mist)] p-0">
      <div className="flex items-center justify-between px-5 pt-4">
        <Eyebrow className="text-[12px]">{m.key} {m.name} · {m.wheel}</Eyebrow>
        <span className="sh-mono text-[12px] text-black/60">{f.name}</span>
      </div>
      <div className="mx-auto w-full max-w-[440px] px-6 pb-8 pt-5">
        <Scaled width={440} height={440}>
          <SheetWheel key={`${mode}-${file}`} size={440} wedges={wedges} onPick={pick} active={isShot ? 0 : undefined}
            hub={<span className="flex flex-col items-center leading-none"><span className="sh-display text-[34px]">{m.key}</span><span className="sh-mono mt-1.5 text-[11px]">{f.ext}</span></span>} />
        </Scaled>
      </div>
    </div>
  )

  return (
    <Row id="try" visual={visual}>
      <RowText eyebrow="Try it here" title={<>Go on, <span className="sh-hl whitespace-nowrap">hold Shift.</span></>}>
        <p>Press <b className="font-medium text-black">Shift</b>, <b className="font-medium text-black">Command</b> or <b className="font-medium text-black">Control</b> on your keyboard and the wheel switches. Aim at a wedge and click to drop. On a phone, tap the keys.</p>
      </RowText>

      <div className="mt-7 flex flex-wrap items-end gap-6">
        <div>
          <div className="sh-mono mb-2 text-[11px] text-[var(--sh-graphite)]">Holding</div>
          <div className="flex gap-2">
            {MODES.map((x, i) => {
              const on = mode === i, down = held === i
              return (
                <button key={x.code} onClick={() => setMode(i)} aria-pressed={on} aria-label={`${x.name}: ${x.wheel}`}
                  className="flex h-[58px] w-[86px] flex-col items-start justify-between rounded-[4px] px-2.5 py-2 text-left transition-[background,color,transform] duration-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-black"
                  style={{ background: on ? '#000' : '#fff', color: on ? '#fff' : '#000', boxShadow: 'inset 0 0 0 1px #000', transform: down ? 'translateY(2px)' : 'none' }}>
                  <span className="text-[18px] leading-none">{x.key}</span>
                  <span className="sh-mono text-[9.5px]">{x.wheel}</span>
                </button>
              )
            })}
          </div>
        </div>
        <div>
          <div className="sh-mono mb-2 text-[11px] text-[var(--sh-graphite)]">Dragging</div>
          <div className="flex gap-2">
            {FILES.map((x, i) => (
              <button key={x.name} onClick={() => setFile(i)} aria-pressed={file === i}
                className="sh-code flex h-[34px] items-center rounded-full px-3.5 text-[13px] transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-black"
                style={{ background: file === i ? '#000' : '#fff', color: file === i ? '#fff' : '#000', boxShadow: 'inset 0 0 0 1px #000' }}>
                {x.name}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="sh-card mt-6 bg-[var(--sh-cream)] p-4" style={{ boxShadow: 'inset 0 0 0 1px rgba(0,0,0,.1)' }} aria-live="polite">
        <div className="sh-mono mb-2 flex items-center justify-between text-[11px] text-[var(--sh-graphite)]">
          <span>Drop log</span>
          {log.length > 0 && <button onClick={() => setLog([])} className="flex items-center gap-1 hover:text-black"><RotateCcw size={11} />Clear</button>}
        </div>
        <div className="sh-code min-h-[120px] text-[13px] leading-[1.85]">
          {log.length === 0 && <div className="text-[var(--sh-graphite)]">Nothing dropped yet. Aim at a wedge and click. <span className="sh-caret" /></div>}
          <AnimatePresence initial={false}>
            {log.map((l) => (
              <motion.div key={l.id} initial={{ opacity: 0, x: -6 }} animate={{ opacity: 1, x: 0 }} className="flex min-w-0 gap-2.5">
                <span className="w-3 shrink-0">{l.key}</span>
                <span className="shrink-0">{l.text}</span>
                <span className="truncate text-[var(--sh-graphite)]">· {l.out}</span>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      </div>
    </Row>
  )
}

/* Private: a log of local jobs and a zero. */

function PrivateCard() {
  const jobs = [['clip.mov', 'GIF'], ['photo.heic', 'JPG'], ['notes.pdf', 'Redact'], ['voice.wav', 'MP3']]
  return (
    <div className="sh-card sh-dots bg-[var(--sh-mist)] p-5 sm:p-8">
      <Window title="anyfmt · this Mac" bodyClassName="p-0">
        <ul className="divide-y divide-black/10">
          {jobs.map(([f, to]) => (
            <li key={f} className="flex items-center gap-3 px-4 py-2.5 text-[14px]">
              <FileIcon ext={f.split('.')[1].toUpperCase()} size={20} />
              <span className="sh-code min-w-0 flex-1 truncate">{f} <span className="text-black/40">→</span> {to}</span>
              <span className="sh-mono hidden text-[10.5px] text-[var(--sh-graphite)] sm:inline">on device</span>
            </li>
          ))}
        </ul>
        <div className="flex items-end justify-between gap-4 border-t border-black px-4 py-4">
          <div>
            <div className="sh-mono text-[11px]">Network calls</div>
            <div className="sh-mono mt-1 text-[10.5px] text-[var(--sh-graphite)]">Unless you turn on Pro cloud</div>
          </div>
          <div className="sh-display-xl text-[84px] leading-[0.8]">0</div>
        </div>
      </Window>
    </div>
  )
}

function Private() {
  return (
    <Row id="private" visual={<PrivateCard />}>
      <RowText eyebrow="Privacy" title={<>Private <span className="sh-hl whitespace-nowrap">by default.</span></>}>
        <p>Every conversion and every tool runs on your Mac. Nothing is uploaded, nothing is counted. Update checks are opt-in and send nothing else.</p>
      </RowText>
      <Ticks items={['No account, no sign-in', 'No upload, no telemetry', 'Never overwrites: every result is a new file', 'Pro cloud features are opt-in']} />
    </Row>
  )
}

export function ProductRows() {
  return (
    <section className="border-t border-black/10 py-20 lg:py-24">
      <Wrap className="grid gap-24 lg:gap-32">
        <Agents />
        <Playground />
        <Private />
      </Wrap>
    </section>
  )
}

/* ───────────────────────── Stats ───────────────────────── */

const STATS = [
  { v: '793', l: 'Routes', note: 'every one tested' },
  { v: '26', l: 'Tools', note: 'crop, trim, compress, redact' },
  { v: '0', l: 'Network calls', note: 'unless you ask' },
  { v: '43', l: 'ms', note: 'key press to wheel' },
]

export function Stats() {
  return (
    <section aria-label="Numbers" className="border-y border-black bg-white">
      <Wrap className="px-0 sm:px-0">
        <div className="grid grid-cols-2 lg:grid-cols-4">
          {STATS.map((s, i) => (
            <div key={s.l} className={`px-4 py-8 sm:px-6 sm:py-10 ${i % 2 ? 'border-l' : ''} ${i >= 2 ? 'border-t lg:border-t-0' : ''} ${i === 2 ? 'lg:border-l' : ''} border-black/10`}>
              <div className="sh-display-xl text-[64px] sm:text-[88px]"><NumberTicker value={s.v} /></div>
              <p className="mt-4"><span className="sh-mono text-[12.5px]">{s.l}</span><span className="mt-1 block text-[14px] text-[var(--sh-graphite)]">{s.note}</span></p>
            </div>
          ))}
        </div>
      </Wrap>
    </section>
  )
}
