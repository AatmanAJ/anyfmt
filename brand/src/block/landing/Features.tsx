import { Star } from 'lucide-react'
import type { ReactNode } from 'react'
import { NumberTicker, Reveal } from '../../shared/kit'
import { product } from '../../shared/product'
import { IsoBlock, IsoLeftText, IsoScene, IsoTop, type Faces } from '../Iso'
import { actionWedges } from './data'
import { Display, Eyebrow } from './ui'

const F = Object.fromEntries(product.features.map((f) => [f.title, f.body])) as Record<string, string>

function Tile({ n, title, big, body, className, style, children, dot, lift }: {
  n: string; title: string; big: ReactNode; body: string; className?: string; style?: React.CSSProperties; children?: ReactNode; dot?: string; lift?: string
}) {
  return (
    <div className={`bkl-lift relative flex flex-col overflow-hidden p-5 sm:p-7 ${className ?? ''}`} style={{ ...style, ['--lift' as string]: lift ?? 'var(--bk-orange)' }}>
      <div className="flex items-start justify-between gap-4">
        <Eyebrow n={n} dot={dot ?? 'currentColor'}>{title}</Eyebrow>
      </div>
      <div className="relative flex flex-1 items-center justify-center py-6">{children}</div>
      <div>
        <div className="bk-display text-[44px] font-semibold leading-[0.92] tracking-[-0.05em] sm:text-[54px]">{big}</div>
        <p className="mt-3 max-w-[460px] text-[15.5px] leading-[1.5] opacity-80">{body}</p>
      </div>
    </div>
  )
}

/* Convert: a tower of striped slabs, one per family. */
const FAMILIES: [string, Faces, string][] = [
  ['Archives', { top: 'stripe:pink:top', left: '#561629', right: '#3A0E1E' }, '#F4F1EC'],
  ['Ebooks', { top: '#4A4A54', left: '#1C1C21', right: '#0E0E10' }, '#F4F1EC'],
  ['Documents', { top: 'stripe:lilac:top', left: '#B8B3FF', right: '#8E87F2' }, '#0E0E10'],
  ['Audio', { top: 'stripe:pink:top', left: '#FF4FA0', right: '#D62F7E' }, '#0E0E10'],
  ['Video', { top: 'stripe:orange:top', left: '#F4F1EC', right: '#DEDAD3' }, '#0E0E10'],
  ['Images', { top: '#FFFFFF', left: '#0E0E10', right: '#1C1C21' }, '#FF6B1A'],
]
function RouteTower() {
  const jig = [0, 0.18, -0.06, 0.22, 0.04, 0.3]
  return (
    <IsoScene width={440} height={360} unit={44} anchor={[0.5, 0.8]} title="Six format families, stacked">
      {(ctx) => FAMILIES.map(([label, faces, ink], i) => (
        <g key={label}>
          <IsoBlock ctx={ctx} x={-2.6 + jig[i]} y={-1.2 - jig[i] * 0.4} z={i * 0.62} w={4.4} d={2.2} h={0.62} material={faces} />
          <IsoLeftText ctx={ctx} x={-2.35 + jig[i]} y={1.0 - jig[i] * 0.4} z={i * 0.62 + 0.17} size={18} fill={ink}>{label}</IsoLeftText>
        </g>
      ))}
    </IsoScene>
  )
}

/* Tools: a photo slab with a crop frame on top. */
function CropSlab() {
  return (
    <IsoScene width={380} height={270} unit={54} anchor={[0.5, 0.6]} title="A photo being cropped">
      {(ctx) => (<>
        <IsoBlock ctx={ctx} x={-1.9} y={-1.5} z={0} w={3.8} d={3} h={0.35} material="ink" />
        <IsoTop ctx={ctx} x={-1.9} y={-1.5} z={0.35} size={1}>
          {/* the picture: flat colour blocks */}
          <rect x="0" y="0" width="380" height="300" fill="#FF6B1A" />
          <rect x="0" y="170" width="380" height="130" fill="#561629" />
          <rect x="210" y="40" width="90" height="90" fill="#F4F1EC" />
          <rect x="40" y="120" width="140" height="80" fill="#FF4FA0" />
          {/* outside the crop: dimmed */}
          <path d="M0 0H380V300H0Z M60 50V250H320V50Z" fill="#0E0E10" fillOpacity=".62" fillRule="evenodd" />
          <rect x="60" y="50" width="260" height="200" fill="none" stroke="#F4F1EC" strokeWidth="5" />
          {[[60, 50], [320, 50], [60, 250], [320, 250]].map(([x, y], i) => (
            <rect key={i} x={x - 13} y={y - 13} width="26" height="26" fill="#B8B3FF" stroke="#0E0E10" strokeWidth="4" />
          ))}
        </IsoTop>
      </>)}
    </IsoScene>
  )
}

function ActionsList() {
  return (
    <div className="w-full max-w-[300px] border-2 border-[var(--bk-ink-3)] bg-[var(--bk-ink)] p-1.5 shadow-[6px_6px_0_var(--bk-wine-2)]">
      {actionWedges.map((a, i) => {
        const on = i === 1
        return (
          <div key={a.id} className="flex h-10 items-center gap-3 px-3 text-[15px] font-medium"
            style={{ background: on ? 'var(--bk-orange)' : 'transparent', color: on ? 'var(--bk-ink)' : 'var(--bk-cream)' }}>
            <span style={{ opacity: on ? 1 : 0.6 }}>{a.icon}</span>{a.label}
            <span className="bk-mono ml-auto text-[10.5px] opacity-60">⌃{i + 1}</span>
          </div>
        )
      })}
    </div>
  )
}

const PRESETS = [
  { f: 'GIF', s: '15 fps', size: '4.1 MB', bg: 'var(--bk-orange)', rot: -4 },
  { f: 'JPG', s: '80 %', size: '1.2 MB', bg: 'var(--bk-lilac)', rot: 3 },
  { f: 'MP4', s: '720p', size: '1.8 MB', bg: 'var(--bk-pink)', rot: -2 },
]
function PresetChips() {
  return (
    <div className="flex flex-col items-center gap-3">
      {PRESETS.map((p, i) => (
        <div key={p.f} className="flex h-14 items-center gap-3 border-2 border-[var(--bk-ink)] pl-2 pr-4 text-[var(--bk-ink)] shadow-[5px_5px_0_var(--bk-ink)]"
          style={{ background: p.bg, transform: `rotate(${p.rot}deg) translateX(${(i - 1) * 18}px)` }}>
          <span className="grid size-9 place-items-center bg-[var(--bk-ink)] text-[var(--bk-cream)]"><Star size={15} fill="currentColor" /></span>
          <span className="bk-display text-[24px] font-bold tracking-[-0.03em]">{p.f}</span>
          <span className="text-[15px] font-medium opacity-75">{p.s}</span>
          <span className="bk-mono ml-2 bg-[var(--bk-ink)]/12 px-1.5 py-0.5 text-[11px] font-semibold">{p.size}</span>
        </div>
      ))}
    </div>
  )
}

function MiniTerminal() {
  return (
    <div className="bk-mono w-full max-w-[340px] overflow-hidden border-2 border-[var(--bk-wine-2)] bg-[var(--bk-ink)] text-[12px] leading-[1.75] shadow-[6px_6px_0_var(--bk-pink)]">
      <div className="flex items-center gap-1.5 border-b border-[var(--bk-ink-3)] px-3 py-2">
        {[0, 1, 2].map((i) => <span key={i} className="size-2 bg-[var(--bk-ink-3)]" />)}
        <span className="ml-2 text-[10.5px] uppercase tracking-[0.06em] text-[var(--bk-mute)]">agent</span>
      </div>
      <div className="px-3 py-2.5">
        <div><span className="text-[var(--bk-orange)]">$</span> <span className="text-[var(--bk-cream)]">anyfmt convert a.heic --to jpg</span></div>
        <div className="text-[var(--bk-lilac)]">{'{"event":"progress","done":0.5}'}</div>
        <div className="text-[var(--bk-lilac)]">{'{"event":"done","output":"a.jpg"}'}</div>
        <div className="mt-1 flex items-center gap-2"><span className="bg-[var(--bk-pink)] px-1.5 text-[10.5px] font-bold text-[var(--bk-ink)]">MCP</span><span className="text-[var(--bk-mute)]">server ready</span></div>
      </div>
    </div>
  )
}

function SealedMac() {
  const files: [number, number, string][] = [[-0.9, -0.7, 'orange'], [0.15, -0.8, 'lilac'], [-0.7, 0.3, 'pink'], [0.3, 0.25, 'cream']]
  return (
    <IsoScene width={420} height={300} unit={52} anchor={[0.5, 0.62]} title="Your files stay on your Mac">
      {(ctx) => (<>
        <IsoBlock ctx={ctx} x={-2.2} y={-2.2} z={-0.4} w={4.4} d={4.4} h={0.4} material="stripePink" />
        <IsoBlock ctx={ctx} x={-1.7} y={-1.7} z={0} w={3.4} d={3.4} h={0.8} material="inkLight" />
        <IsoLeftText ctx={ctx} x={-1.45} y={1.7} z={0.26} size={19} fill="#F4F1EC">your Mac</IsoLeftText>
        {files.map(([x, y, mat], i) => <IsoBlock key={i} ctx={ctx} x={x} y={y} z={0.8} w={0.75} d={0.75} h={0.75 + (i % 2) * 0.35} material={mat as 'orange'} />)}
      </>)}
    </IsoScene>
  )
}

export function Features() {
  return (
    <section id="features" className="mx-auto max-w-[1440px] scroll-mt-20 px-2 pt-2">
      <div className="bg-[var(--bk-ink)] px-3 py-10 sm:px-8 sm:py-14">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <Eyebrow n="03" className="mb-6 text-[var(--bk-cream)]">What is inside</Eyebrow>
            <Display a="Six blocks." b="One wheel." bColor="var(--bk-lilac)" className="text-[clamp(52px,8.4vw,128px)] tracking-[-0.06em]" />
          </div>
          <p className="max-w-[380px] text-[17px] leading-[1.5] text-[var(--bk-cream)]/70">{product.oneLiner} Every result is a new file. The original is never touched.</p>
        </div>
      </div>
      <Reveal className="grid gap-2 lg:grid-cols-12">
        <Tile n="01" title="Convert" big={<>793 routes<span className="text-[var(--bk-wine-2)]">.</span></>} body={F.Convert}
          className="min-h-[600px] lg:col-span-7" style={{ background: 'var(--bk-orange)', color: 'var(--bk-ink)' }} lift="var(--bk-wine)">
          <div className="w-full max-w-[460px]"><RouteTower /></div>
        </Tile>
        <Tile n="02" title="Tools" big={<>26 tools<span className="text-[var(--bk-lilac-lo)]">.</span></>} body={F.Tools}
          className="min-h-[600px] lg:col-span-5" style={{ background: 'var(--bk-lilac)', color: 'var(--bk-ink)' }} lift="var(--bk-ink)">
          <div className="flex w-full flex-col items-center gap-2">
            <div className="w-full max-w-[380px]"><CropSlab /></div>
            <div className="flex flex-wrap justify-center gap-1.5">
              {product.tools.map((t) => <span key={t} className="bk-tag" style={{ background: t === 'Crop' ? 'var(--bk-ink)' : 'rgba(14,14,16,.1)', color: t === 'Crop' ? 'var(--bk-lilac)' : 'var(--bk-ink)' }}>{t}</span>)}
            </div>
          </div>
        </Tile>
        <Tile n="03" title="Actions" big="Six exits." body={F.Actions} dot="var(--bk-orange)"
          className="min-h-[560px] lg:col-span-4" style={{ background: 'var(--bk-ink-2)', color: 'var(--bk-cream)' }}>
          <ActionsList />
        </Tile>
        <Tile n="04" title="Presets" big="Yours, saved." body={F.Presets} dot="var(--bk-orange)"
          className="min-h-[560px] lg:col-span-4" style={{ background: 'var(--bk-cream)', color: 'var(--bk-ink)' }} lift="var(--bk-ink)">
          <PresetChips />
        </Tile>
        <Tile n="05" title="Agents" big="CLI + MCP." body={F.Agents} dot="var(--bk-pink)"
          className="min-h-[560px] lg:col-span-4" style={{ background: 'var(--bk-wine)', color: 'var(--bk-cream)' }} lift="var(--bk-pink)">
          <MiniTerminal />
        </Tile>
        <div className="bkl-lift relative grid overflow-hidden bg-[var(--bk-ink-2)] p-5 text-[var(--bk-cream)] sm:p-7 lg:col-span-12 lg:grid-cols-12 lg:items-center" style={{ ['--lift' as string]: 'var(--bk-pink)' }}>
          <div className="lg:col-span-4">
            <Eyebrow n="06" dot="var(--bk-pink)">Private</Eyebrow>
            <div className="bk-display mt-4 font-semibold leading-[0.78] tracking-[-0.08em] text-[var(--bk-pink)]" style={{ fontSize: 'clamp(160px, 20vw, 300px)' }}>0</div>
          </div>
          <div className="lg:col-span-4">
            <div className="bk-display text-[44px] font-semibold leading-[0.92] tracking-[-0.05em] sm:text-[60px]">network calls.</div>
            <p className="mt-4 max-w-[420px] text-[16px] leading-[1.5] opacity-80">{F.Private}</p>
          </div>
          <div className="mx-auto w-full max-w-[420px] lg:col-span-4"><SealedMac /></div>
        </div>
      </Reveal>
    </section>
  )
}

/* ───────────────────────── Big numbers ───────────────────────── */

const BANDS = [
  { bg: 'var(--bk-orange)', fg: 'var(--bk-ink)', accent: 'var(--bk-ink)' },
  { bg: 'var(--bk-ink-2)', fg: 'var(--bk-cream)', accent: 'var(--bk-lilac)' },
  { bg: 'var(--bk-lilac)', fg: 'var(--bk-ink)', accent: 'var(--bk-ink)' },
  { bg: 'var(--bk-wine)', fg: 'var(--bk-cream)', accent: 'var(--bk-pink)' },
]

export function Numbers() {
  return (
    <section aria-label="In numbers" className="mx-auto max-w-[1440px] px-2 pt-2">
      <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
        {product.stats.map((s, i) => {
          const b = BANDS[i]
          const [num, unit] = s.value.split(' ')
          return (
            <div key={s.label} className="flex min-h-[330px] flex-col justify-between p-5 sm:p-7" style={{ background: b.bg, color: b.fg }}>
              <span className="bk-mono text-[11.5px] font-medium uppercase tracking-[0.08em] opacity-70">0{i + 1}</span>
              <div>
                <div className="bk-display flex items-baseline font-semibold leading-[0.8] tracking-[-0.075em]" style={{ color: b.accent }}>
                  <NumberTicker value={num} className="text-[clamp(120px,11vw,176px)]" />
                  {unit && <span className="ml-2 text-[clamp(40px,3.6vw,56px)] tracking-[-0.04em]">{unit}</span>}
                </div>
                <p className="mt-4 max-w-[240px] text-[16px] font-medium leading-snug">{s.label}</p>
              </div>
            </div>
          )
        })}
      </div>
    </section>
  )
}
