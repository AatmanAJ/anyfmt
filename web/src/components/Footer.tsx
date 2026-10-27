/**
 * Footer: five columns, then the wordmark set edge to edge in fluted glass. The ember light inside
 * the letters follows the pointer.
 */
import { useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import { WORDMARK, WORDMARK_VIEWBOX } from '../data/wordmark'
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

const { x: VX, y: VY, w: VW, h: VH } = WORDMARK_VIEWBOX

/**
 * The real outlines (so the y keeps its descender and the letters keep their spacing), filled
 * with ember heat behind glass flutes. The hot spot eases toward the pointer every frame; with
 * no pointer it rests over the "fmt".
 */
function Wordmark() {
  const ref = useRef<SVGSVGElement>(null)
  const grad = useRef<SVGRadialGradientElement>(null)
  const goal = useRef({ x: VX + VW * 0.72, y: VY + VH * 0.3 })

  useEffect(() => {
    const svg = ref.current, g = grad.current
    if (!svg || !g || prefersReducedMotion()) return
    const now = { ...goal.current }
    let raf = 0, visible = false
    const tick = () => {
      now.x += (goal.current.x - now.x) * 0.08
      now.y += (goal.current.y - now.y) * 0.08
      g.setAttribute('cx', now.x.toFixed(1)); g.setAttribute('cy', now.y.toFixed(1))
      g.setAttribute('fx', now.x.toFixed(1)); g.setAttribute('fy', now.y.toFixed(1))
      raf = visible ? requestAnimationFrame(tick) : 0
    }
    const io = new IntersectionObserver(([e]) => {
      visible = e.isIntersecting
      if (visible && !raf) raf = requestAnimationFrame(tick)
    })
    io.observe(svg)
    return () => { io.disconnect(); cancelAnimationFrame(raf) }
  }, [])

  const move = (e: React.PointerEvent) => {
    if (e.pointerType !== 'mouse' || !ref.current) return
    const r = ref.current.getBoundingClientRect()
    goal.current = { x: VX + ((e.clientX - r.left) / r.width) * VW, y: VY + ((e.clientY - r.top) / r.height) * VH }
  }
  const leave = () => { goal.current = { x: VX + VW * 0.72, y: VY + VH * 0.3 } }

  return (
    <svg ref={ref} onPointerMove={move} onPointerLeave={leave} viewBox={`${VX} ${VY} ${VW} ${VH}`} className="block h-auto w-full select-none" role="img" aria-label="anyfmt">
      <defs>
        {/* user-space units, so the light keeps its round shape and never runs out at an edge */}
        <radialGradient ref={grad} id="wm-heat" gradientUnits="userSpaceOnUse" cx={VX + VW * 0.72} cy={VY + VH * 0.3} fx={VX + VW * 0.72} fy={VY + VH * 0.3} r={VW * 0.7}>
          <stop offset="0" stopColor="#FFF1D6" /><stop offset="0.12" stopColor="#FFB23E" /><stop offset="0.32" stopColor="#FF5A0A" />
          <stop offset="0.62" stopColor="#EE1200" /><stop offset="1" stopColor="#A31000" />
        </radialGradient>
        {/* one flute: a soft highlight rolling into a soft shadow, like a ridge of reeded glass */}
        <linearGradient id="wm-flute" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#fff" stopOpacity="0" />
          <stop offset="0.28" stopColor="#fff" stopOpacity="0.26" />
          <stop offset="0.5" stopColor="#fff" stopOpacity="0.04" />
          <stop offset="0.82" stopColor="#000" stopOpacity="0.12" />
          <stop offset="1" stopColor="#000" stopOpacity="0" />
        </linearGradient>
        <pattern id="wm-ribs" width="56" height="56" patternUnits="userSpaceOnUse" patternTransform="rotate(31)">
          <rect width="56" height="56" fill="url(#wm-flute)" />
        </pattern>
        <clipPath id="wm-type">
          {WORDMARK.map((g) => <path key={g.x} d={g.d} transform={`translate(${g.x} 0) scale(1 -1)`} />)}
        </clipPath>
      </defs>
      <g clipPath="url(#wm-type)">
        <rect x={VX} y={VY} width={VW} height={VH} fill="url(#wm-heat)" />
        <rect x={VX} y={VY} width={VW} height={VH} fill="url(#wm-ribs)" />
      </g>
    </svg>
  )
}

export function Footer() {
  return (
    <footer className="bg-white px-5 pb-[max(20px,env(safe-area-inset-bottom))] pt-10 sm:px-10 lg:px-14">
      <div className="mx-auto max-w-[1440px]">
        <div className="grid gap-x-8 gap-y-12 border-t border-line pt-14 sm:grid-cols-2 md:grid-cols-3 xl:grid-cols-[minmax(0,1.6fr)_repeat(5,minmax(0,1fr))]">
          <div className="sm:col-span-2 md:col-span-3 xl:col-span-1">
            <p className="max-w-[360px] text-[22px] font-semibold leading-[1.15] tracking-[-0.03em] [text-wrap:balance]">Any file, any format, one drag away.</p>
            <p className="mt-3 max-w-[340px] text-[15px] leading-[1.55] text-mute">Open source, for macOS. Conversions run on your Mac and never leave it.</p>
            <div className="mt-7 flex flex-wrap gap-3"><PillLink to="/download">Download</PillLink></div>
          </div>
          {COLS.map((c) => (
            <nav key={c.title} aria-label={c.title}>
              <p className="flex items-center gap-2.5 text-[14px] text-mute-2"><span className="h-2 w-2 bg-ink" />{c.title}</p>
              <ul className="mt-5 flex flex-col gap-3 text-[15.5px]">
                {c.links.map(([l, to]) => <li key={to}><Link to={to} className="link-line whitespace-nowrap outline-none focus-visible:ring-2 focus-visible:ring-flare">{l}</Link></li>)}
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
              <span className="link-line whitespace-nowrap">Back to top</span>
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
