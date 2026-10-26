import type { CSSProperties } from 'react'

/** What a file of each kind looks like as a card: one motif per kind, the format set large. */
type Kind = 'image' | 'video' | 'audio' | 'doc' | 'archive'

const KIND: Record<string, Kind> = {
  JPG: 'image', PNG: 'image', HEIC: 'image', WEBP: 'image', AVIF: 'image', TIFF: 'image', SVG: 'image',
  MP4: 'video', MOV: 'video', WEBM: 'video', MKV: 'video', GIF: 'video', M4V: 'video',
  MP3: 'audio', WAV: 'audio', FLAC: 'audio', M4A: 'audio',
  PDF: 'doc', DOCX: 'doc', MD: 'doc', EPUB: 'doc', TXT: 'doc',
  ZIP: 'archive',
}

const SKIN: Record<Kind, { bg: string; ink: string }> = {
  image: { bg: 'radial-gradient(120% 90% at 20% 15%, #FFD29A 0%, #FF7A45 38%, #B8326A 70%, #2A1238 100%)', ink: '#fff' },
  video: { bg: 'linear-gradient(160deg, #1B1C24 0%, #0B0C10 100%)', ink: '#fff' },
  audio: { bg: 'linear-gradient(160deg, #3B5BFF 0%, #2236B8 55%, #121A5C 100%)', ink: '#fff' },
  doc: { bg: 'linear-gradient(180deg, #FBFAF7 0%, #EEEBE4 100%)', ink: '#151514' },
  archive: { bg: 'linear-gradient(160deg, #D9F25A 0%, #9CC52A 100%)', ink: '#151514' },
}

function Motif({ kind, seed }: { kind: Kind; seed: number }) {
  if (kind === 'image')
    return (
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="absolute inset-0 h-full w-full" aria-hidden>
        <circle cx={68 - (seed % 3) * 8} cy="30" r="13" fill="#FFF3D6" opacity=".9" />
        <path d={`M0 78 L${28 + (seed % 4) * 4} 52 L50 70 L72 46 L100 74 L100 100 L0 100 Z`} fill="#000" opacity=".28" />
        <path d="M0 88 L35 66 L60 84 L100 62 L100 100 L0 100 Z" fill="#000" opacity=".35" />
      </svg>
    )
  if (kind === 'video')
    return (
      <div className="absolute inset-0" aria-hidden>
        {[0, 1].map((row) => (
          <div key={row} className="absolute inset-x-0 flex justify-between px-[6%]" style={{ top: row ? 'auto' : '5%', bottom: row ? '5%' : 'auto' }}>
            {Array.from({ length: 6 }).map((_, i) => <span key={i} className="h-[6px] w-[9%] rounded-[1.5px] bg-white/25" />)}
          </div>
        ))}
        <div className="absolute inset-x-[8%] top-[17%] bottom-[30%] overflow-hidden rounded-[4px]"
             style={{ background: `linear-gradient(${120 + seed * 23}deg, #FF7A45, #6B4EFF 60%, #20D4C4)` }}>
          <svg viewBox="0 0 24 24" className="absolute left-1/2 top-1/2 h-[34%] w-[34%] -translate-x-1/2 -translate-y-1/2" aria-hidden><path d="M8 5v14l11-7z" fill="#fff" /></svg>
        </div>
      </div>
    )
  if (kind === 'audio')
    return (
      <div className="absolute inset-x-[10%] top-[18%] bottom-[34%] flex items-center gap-[3%]" aria-hidden>
        {Array.from({ length: 16 }).map((_, i) => {
          const h = 22 + Math.abs(Math.sin((i + seed) * 1.7) * 70) + (i % 3) * 4
          return <span key={i} className="flex-1 rounded-full bg-white/85" style={{ height: `${Math.min(100, h)}%` }} />
        })}
      </div>
    )
  if (kind === 'doc')
    return (
      <div className="absolute inset-x-[12%] top-[14%] flex flex-col gap-[7px]" aria-hidden>
        <span className="h-[7px] w-[60%] rounded-full bg-[#151514]/80" />
        {Array.from({ length: 6 }).map((_, i) => <span key={i} className="h-[4px] rounded-full bg-[#151514]/15" style={{ width: `${92 - ((i + seed) % 4) * 14}%` }} />)}
      </div>
    )
  return (
    <div className="absolute left-1/2 top-[10%] bottom-[34%] flex w-[16%] -translate-x-1/2 flex-col" aria-hidden>
      {Array.from({ length: 9 }).map((_, i) => <span key={i} className="h-[11%] bg-[#151514]/70" style={{ marginLeft: i % 2 ? '45%' : 0, width: '55%' }} />)}
    </div>
  )
}

export function FormatCard({ fmt, seed = 0, className, style, label = true }: { fmt: string; seed?: number; className?: string; style?: CSSProperties; label?: boolean }) {
  const kind = KIND[fmt] ?? 'doc'
  const skin = SKIN[kind]
  return (
    <div className={`relative h-full w-full overflow-hidden rounded-[inherit] ${className ?? ''}`} style={{ background: skin.bg, color: skin.ink, containerType: 'inline-size', ...style }}>
      <Motif kind={kind} seed={seed} />
      {label && (
        <div className="absolute inset-x-[9%] bottom-[7%] flex items-end justify-between">
          <span className="font-semibold leading-none tracking-[-0.04em]" style={{ fontSize: 'clamp(10px, 24cqw, 64px)' }}>{fmt}</span>
          <span className="font-mono text-[clamp(6px,8cqw,12px)] uppercase opacity-60">{kind}</span>
        </div>
      )}
    </div>
  )
}

export const FORMATS = ['GIF', 'PNG', 'MP4', 'PDF', 'MP3', 'HEIC', 'WEBM', 'DOCX', 'JPG', 'WAV', 'MOV', 'EPUB', 'WEBP', 'FLAC', 'MKV', 'MD', 'AVIF', 'M4A', 'ZIP', 'TIFF']
