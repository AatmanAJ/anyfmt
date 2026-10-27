/**
 * Footer: five columns, then the wordmark set edge to edge in fluted glass. The ember light inside
 * the letters follows the pointer.
 */
import { useRef } from 'react'
import { Link } from 'react-router-dom'
import { prefersReducedMotion, SNAP } from '../lib/hooks'
import { SITE } from '../lib/site'
import { PillLink } from './Buttons'

const COLS: { title: string; links: [string, string][] }[] = [
  { title: 'Product', links: [['Download', '/download'], ['Formats', '/formats'], ['Pricing', '/pricing'], ['Changelog', '/changelog'], ['Donate', '/pricing#donate']] },
  { title: 'Developers', links: [['Docs', '/docs'], ['Command line', '/docs/cli'], ['MCP for agents', '/docs/mcp'], ['HTTP API', '/docs/api'], ['Self-host', '/docs/self-host'], ['Open source', '/open-source']] },
  { title: 'Compare', links: [['vs Tangerine', '/compare/tangerine'], ['vs convt', '/compare/convt'], ['vs Permute', '/compare/permute'], ['vs CloudConvert', '/compare/cloudconvert'], ['All comparisons', '/compare']] },
  { title: 'Convert', links: [['HEIC to JPG', '/convert/heic-to-jpg'], ['MOV to MP4', '/convert/mov-to-mp4'], ['Video to GIF', '/convert/video-to-gif'], ['PDF to Word', '/convert/pdf-to-word'], ['All guides', '/convert']] },
  { title: 'Company', links: [['Privacy', '/privacy'], ['Terms', '/terms'], ['Contact', '/contact'], ['Brand', '/brand']] },
]

function Wordmark() {
  const ref = useRef<SVGSVGElement>(null)
  const grad = useRef<SVGRadialGradientElement>(null)
  const move = (e: React.PointerEvent) => {
    if (prefersReducedMotion() || !ref.current || !grad.current) return
    const r = ref.current.getBoundingClientRect()
    grad.current.setAttribute('cx', String((e.clientX - r.left) / r.width))
    grad.current.setAttribute('cy', String((e.clientY - r.top) / r.height))
  }
  return (
    <svg ref={ref} onPointerMove={move} viewBox="0 0 1000 236" className="block w-full select-none" role="img" aria-label="anyfmt">
      <defs>
        <radialGradient ref={grad} id="wm-heat" cx="0.78" cy="0.2" r="0.75" fx="0.78" fy="0.2" gradientTransform="scale(1 1.6)" style={{ transition: `all .8s ${SNAP}` }}>
          <stop offset="0" stopColor="#FFF1D6" /><stop offset="0.12" stopColor="#FFB23E" /><stop offset="0.3" stopColor="#FF5A0A" />
          <stop offset="0.52" stopColor="#EE1200" /><stop offset="0.8" stopColor="#5A0A00" /><stop offset="1" stopColor="#1C0200" />
        </radialGradient>
        <pattern id="wm-ribs" width="22" height="22" patternUnits="userSpaceOnUse" patternTransform="rotate(31)">
          <rect width="22" height="22" fill="transparent" />
          <rect x="0" width="4" height="22" fill="rgba(255,255,255,.42)" />
          <rect x="4" width="3" height="22" fill="rgba(255,255,255,.12)" />
          <rect x="17" width="5" height="22" fill="rgba(0,0,0,.14)" />
        </pattern>
        <mask id="wm-type">
          <text x="0" y="206" textLength="1000" lengthAdjust="spacingAndGlyphs" fill="#fff"
            style={{ fontFamily: 'Bricolage Grotesque Variable, Inter Tight Variable, sans-serif', fontWeight: 700, fontSize: 268, letterSpacing: '-0.04em', fontVariationSettings: '"wdth" 75' }}>anyfmt.</text>
        </mask>
      </defs>
      <g mask="url(#wm-type)">
        <rect width="1000" height="236" fill="url(#wm-heat)" />
        <rect width="1000" height="236" fill="url(#wm-ribs)" />
      </g>
    </svg>
  )
}

export function Footer() {
  return (
    <footer className="bg-white px-5 pb-[max(20px,env(safe-area-inset-bottom))] pt-20 sm:px-10 lg:px-14">
      <div className="mx-auto max-w-[1440px]">
        <div className="grid gap-x-8 gap-y-12 border-t border-line pt-14 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-[minmax(0,1.6fr)_repeat(5,minmax(0,1fr))]">
          <div className="sm:col-span-2 md:col-span-3 xl:col-span-1">
            <p className="max-w-[360px] text-[22px] font-semibold leading-[1.15] tracking-[-0.03em]">Any file, any format, one drag away.</p>
            <p className="mt-3 max-w-[340px] text-[15px] leading-[1.55] text-mute">Open source, for macOS. Conversions run on your Mac and never leave it.</p>
            <div className="mt-7 flex flex-wrap gap-3"><PillLink to="/download">Download</PillLink></div>
          </div>
          {COLS.map((c) => (
            <nav key={c.title} aria-label={c.title}>
              <p className="flex items-center gap-2.5 text-[14px] text-mute-2"><span className="h-2 w-2 bg-ink" />{c.title}</p>
              <ul className="mt-5 flex flex-col gap-3 text-[15.5px]">
                {c.links.map(([l, to]) => <li key={to}><Link to={to} className="link-line outline-none focus-visible:ring-2 focus-visible:ring-flare">{l}</Link></li>)}
              </ul>
            </nav>
          ))}
        </div>

        <div className="mt-20"><Wordmark /></div>

        <div className="mt-6 flex flex-wrap items-center justify-between gap-x-6 gap-y-4 border-t border-line pt-6 text-[14px] text-mute-2">
          <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
            <span>© 2026 anyfmt</span>
            <a href="https://www.gnu.org/licenses/agpl-3.0.html" target="_blank" rel="noreferrer" className="link-line">AGPL-3.0</a>
            <a href="/changelog.xml" className="link-line">RSS</a>
            <a href="/llms.txt" className="link-line">llms.txt</a>
          </div>
          <div className="flex items-center gap-5">
            <span className="flex items-center gap-2"><span className="relative flex h-2 w-2"><span className="absolute inset-0 animate-ping rounded-full bg-[#22C55E] opacity-60" /><span className="relative h-2 w-2 rounded-full bg-[#22C55E]" /></span>Every conversion runs offline</span>
            <button type="button" onClick={() => window.scrollTo({ top: 0, behavior: prefersReducedMotion() ? 'auto' : 'smooth' })}
              className="group flex items-center gap-2 text-ink outline-none focus-visible:ring-2 focus-visible:ring-flare">
              <span className="link-line">Back to top</span>
              <span className="relative flex h-8 w-8 items-center justify-center overflow-hidden rounded-full bg-sand-2 transition-colors duration-300 group-hover:bg-ink group-hover:text-white">
                {[0, 1].map((k) => (
                  <svg key={k} width="12" height="12" viewBox="0 0 12 12" aria-hidden className={`absolute transition-transform duration-500 ${k === 0 ? 'group-hover:-translate-y-6' : 'translate-y-6 group-hover:translate-y-0'}`} style={{ transitionTimingFunction: SNAP }}>
                    <path d="M6 10.5v-9M2 5.5l4-4 4 4" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                ))}
              </span>
            </button>
          </div>
        </div>
        <p className="sr-only">{SITE.description}</p>
      </div>
    </footer>
  )
}
