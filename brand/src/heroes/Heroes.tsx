import { useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { AuroraHero } from '../components/ui/aurora-hero'
import CinematicOrbitHero from '../components/ui/cinematic-orbit-hero'
import GlassHeadlineHero from '../components/ui/glass-headline-hero'
import ShutterText from '../components/ui/hero-shutter-text'
import ScrollMorphHero from '../components/ui/scroll-morph-hero'
import { FORMATS, FormatCard } from './FormatCard'
import { COPY, Ctas, Glyph, HEROES, Nav, Switcher } from './Shell'

/* 1 ─ Glass: "Any format." in refractive glass over a molten field. */
function GlassHero() {
  return (
    <>
      <Nav tone="dark" />
      <GlassHeadlineHero
        eyebrow={COPY.eyebrow}
        title="Any format."
        description={COPY.body}
        colors={['#0B0A10', '#FF5A1F', '#FF8FB8', '#3D5CFF', '#FFE3B8']}
        primaryAction={{ label: 'Download for Mac', href: '#' }}
        secondaryAction={{ label: 'See how it works', href: '#' }}
        titleStyle={{ fontFamily: "'Geist Variable', sans-serif", letterSpacing: '-0.06em' }}
      >
        <div className="flex items-center gap-3 text-[13px] text-white/60">
          <span className="rounded-md bg-white/10 px-2 py-1 font-mono ring-1 ring-white/15">drag</span>
          <span className="text-white/30">→</span>
          <span className="rounded-md bg-white/10 px-2 py-1 font-mono ring-1 ring-white/15">⇧</span>
          <span className="text-white/30">→</span>
          <span className="rounded-md bg-white/10 px-2 py-1 font-mono ring-1 ring-white/15">drop</span>
        </div>
      </GlassHeadlineHero>
    </>
  )
}

/* 2 ─ Morph: scattered files gather into the wheel, then fan into an arc you can shuffle. */
function MorphHero() {
  const kinds: Record<string, string> = { GIF: 'Animation', PNG: 'Image', MP4: 'Video', PDF: 'Document', MP3: 'Audio', HEIC: 'Photo', WEBM: 'Video', DOCX: 'Document', JPG: 'Photo', WAV: 'Audio', MOV: 'Video', EPUB: 'Ebook', WEBP: 'Image', FLAC: 'Audio', MKV: 'Video', MD: 'Text', AVIF: 'Image', M4A: 'Audio', ZIP: 'Archive', TIFF: 'Image' }
  return (
    <div className="h-[100svh]">
      <Nav tone="light" />
      <ScrollMorphHero
        background="radial-gradient(70% 60% at 50% 45%, #FFFFFF 0%, #F3F1EC 70%)"
        cards={FORMATS.map((f, i) => ({
          key: f,
          front: <FormatCard fmt={f} seed={i} />,
          back: <div className="text-center"><div className="text-[13px] font-semibold text-white">{f}</div><div className="mt-0.5 font-mono text-[8px] uppercase text-[#FF7A45]">{kinds[f]}</div></div>,
        }))}
        introTitle={<h1 className="text-[clamp(28px,4vw,52px)] font-medium leading-[1.05] tracking-[-0.04em] text-[#111]">Every file wants to be<br />something else.</h1>}
        introHint="SCROLL"
        arcTitle={<h2 className="flex items-center gap-3 text-[clamp(44px,6vw,88px)] font-semibold leading-none tracking-[-0.06em] text-[#111]"><Glyph size={56} />anyfmt</h2>}
        arcBody={<p className="mt-5 max-w-[520px] text-[clamp(15px,1.2vw,17px)] leading-relaxed text-black/60">{COPY.body}</p>}
        arcActions={<Ctas tone="light" />}
      />
    </div>
  )
}

/* 3 ─ Aurora: iridescent silk drifting to a horizon; serif, calm, expensive. */
function AuroraHeroPage() {
  return (
    <>
      <Nav tone="dark" />
      <AuroraHero
        eyebrow="anyfmt · for macOS"
        headline={<>Any file.<br /><em className="text-[#F2C38B]">Any format.</em></>}
        description={COPY.body}
        colors={['#FF5A1F', '#E8C27A', '#2B9FA8']}
        background="#07070A"
        foreground="#F1ECE4"
        accent="#E8C27A"
        displayFont="'Instrument Serif', Georgia, serif"
        meta={['793 conversion routes', '0 network calls', '43 ms to the wheel']}
        action={<Ctas tone="dark" />}
        topInset
      />
    </>
  )
}

/* 4 ─ Shutter: the format itself is the headline, slicing from one to the next. */
const SHUTTER_WORDS = ['GIF', 'PDF', 'MP4', 'HEIC', 'WEBP', 'MP3', 'PNG', 'ZIP']
function ShutterHero() {
  const [fmt, setFmt] = useState(SHUTTER_WORDS[0])
  const onWord = useCallback((w: string) => setFmt(w), [])
  return (
    <section className="relative flex h-[100svh] flex-col items-center justify-center overflow-hidden bg-[#F4F3EF] text-[#111]">
      <Nav tone="light" />
      <div aria-hidden className="pointer-events-none absolute inset-0 opacity-[0.07]"
        style={{ backgroundImage: 'linear-gradient(to right,#111 1px,transparent 1px),linear-gradient(to bottom,#111 1px,transparent 1px)', backgroundSize: 'clamp(24px,5vw,64px) clamp(24px,5vw,64px)' }} />
      <div aria-hidden className="absolute left-6 top-24 h-12 w-12 border-l border-t border-black/20" />
      <div aria-hidden className="absolute bottom-24 right-6 h-12 w-12 border-b border-r border-black/20" />
      <div className="relative z-10 flex flex-col items-center px-4 text-center">
        <p className="mb-2 font-mono text-[12px] uppercase tracking-[0.3em] text-black/50">{COPY.eyebrow}</p>
        <p className="text-[clamp(20px,2.4vw,32px)] font-medium tracking-[-0.03em]">Drop it as</p>
        <ShutterText words={SHUTTER_WORDS} size="min(24vw, 30vh)" color="#111" sliceA="#FF4D00" sliceB="#8A8A8A" onWord={onWord} className="focus-visible:ring-[#FF4D00]" />
        <div className="mt-3 flex items-center gap-2 font-mono text-[13px] text-black/55">
          <span className="rounded-md bg-white px-2 py-1 ring-1 ring-black/10">clip.mov</span>
          <span>→</span>
          <span className="rounded-md bg-[#111] px-2 py-1 text-white">clip.{fmt.toLowerCase()}</span>
        </div>
        <p className="mt-7 max-w-[520px] text-[16px] leading-relaxed text-black/60">{COPY.body}</p>
        <div className="mt-8"><Ctas tone="light" /></div>
      </div>
    </section>
  )
}

/* 5 ─ Orbit: scroll fans a stack of files into an orbit around the promise. */
function OrbitHero() {
  const eight = ['GIF', 'MP4', 'PNG', 'PDF', 'MP3', 'HEIC', 'WEBP', 'DOCX']
  return (
    <>
      <Nav tone="dark" />
      <CinematicOrbitHero
        background="radial-gradient(80% 60% at 50% 40%, #16141C 0%, #08080B 70%)"
        foreground="#F2F1F6"
        glow="rgba(255,90,31,.28)"
        cards={eight.map((f, i) => <FormatCard key={f} fmt={f} seed={i} />)}
        title={<h1 className="text-[clamp(40px,6vw,96px)] font-semibold leading-[0.95] tracking-[-0.055em]">One gesture.<br /><span className="text-white/45">Every format.</span></h1>}
        body={<p className="mt-5 max-w-[48ch] text-[clamp(14px,1.15vw,17px)] leading-relaxed text-white/60">{COPY.body}</p>}
        actions={<Ctas tone="dark" />}
        intro={<span className="font-mono text-[11px] uppercase tracking-[0.3em] text-white/50">Scroll</span>}
      />
      <div className="h-[30vh] bg-[#08080B]" />
    </>
  )
}

const PAGES = [GlassHero, MorphHero, AuroraHeroPage, ShutterHero, OrbitHero]

export function HeroPage() {
  const { n = '1' } = useParams()
  const i = Math.min(5, Math.max(1, parseInt(n, 10) || 1))
  const Page = PAGES[i - 1]
  useEffect(() => { document.title = `anyfmt · ${HEROES[i - 1].name}`; window.scrollTo(0, 0) }, [i])
  return (
    <div className="min-h-screen font-['Geist_Variable',sans-serif]">
      <Page key={i} />
      <Switcher current={i} />
    </div>
  )
}

export function HeroIndex() {
  useEffect(() => { document.title = 'anyfmt · five heroes' }, [])
  const tiles = [
    { bg: 'radial-gradient(60% 60% at 30% 30%, #FF5A1F, transparent 60%), radial-gradient(50% 50% at 75% 40%, #3D5CFF, transparent 60%), #0B0A10', fg: '#fff', blurb: 'The headline is thick refractive glass. A molten colour field flows behind it and bends through the letters; the light follows your pointer.' },
    { bg: 'linear-gradient(160deg, #FFFFFF, #ECE9E2)', fg: '#111', blurb: 'Twenty file cards scatter, line up and close into a ring: the wheel. Scroll and the ring fans into an arc you can shuffle through.' },
    { bg: 'linear-gradient(180deg, #07070A 40%, #3a1a10 75%, #0e3a3d)', fg: '#F1ECE4', blurb: 'A sheet of iridescent silk drifts toward the horizon in real 3D. Serif headline, calm, expensive. The quietest of the five.' },
    { bg: '#F4F3EF', fg: '#111', blurb: 'The format is the headline. A giant word slices from GIF to PDF to MP4, and the file chip under it renames to match.' },
    { bg: 'radial-gradient(70% 60% at 50% 40%, #2a1a14, #08080B 70%)', fg: '#F2F1F6', blurb: 'Scroll fans a stack of eight format cards into a 3D orbit around the promise, with depth and pointer parallax.' },
  ]
  return (
    <div className="min-h-screen bg-[#0B0B0D] px-5 pb-24 pt-16 font-['Geist_Variable',sans-serif] text-white sm:px-10">
      <div className="mx-auto max-w-[1200px]">
        <div className="flex items-center gap-2 text-[15px] font-semibold"><Glyph />anyfmt</div>
        <h1 className="mt-10 text-[clamp(40px,6vw,84px)] font-semibold leading-[0.95] tracking-[-0.05em]">Five heroes.<br /><span className="text-white/40">Pick one.</span></h1>
        <p className="mt-5 max-w-[560px] text-[16px] leading-relaxed text-white/55">Each starts from a component on 21st.dev, rebuilt around anyfmt: our copy, our formats, our colours. Open one, play with it, use the switcher at the bottom to compare.</p>
        <div className="mt-12 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {HEROES.map((h, i) => (
            <Link key={h.n} to={`/heroes/${h.n}`} className="group overflow-hidden rounded-[20px] ring-1 ring-white/10 transition-transform duration-300 hover:-translate-y-1">
              <div className="relative flex aspect-[16/10] items-end p-5" style={{ background: tiles[i].bg, color: tiles[i].fg }}>
                <span className="font-mono text-[12px] opacity-60">{String(h.n).padStart(2, '0')}</span>
                <span className="ml-3 text-[34px] font-semibold leading-none tracking-[-0.05em]">{h.name}</span>
              </div>
              <div className="bg-[#141417] p-5">
                <p className="text-[14px] leading-relaxed text-white/65">{tiles[i].blurb}</p>
                <p className="mt-3 font-mono text-[11px] text-white/35">From “{h.from}” by {h.by} on 21st.dev</p>
              </div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  )
}
