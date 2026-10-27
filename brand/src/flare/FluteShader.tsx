/**
 * The page's shader, built on the `shaders` package (shaders.com, MIT): Swirl, ChromaFlow,
 * FlutedGlass and FilmGrain, with the flutes cut diagonally so a warm colour mass anchored in one
 * corner streaks away across the canvas.
 *
 * Always: the orange breathes. On hover: a hot spot of light rides the pointer and ChromaFlow
 * paints liquid by direction; the flutes drag both into diagonal streaks and the glass sharpens
 * its aberration. `light` multiplies colour into white, `dark` screens it onto black.
 * WebGPU only; elsewhere a static CSS gradient stands in.
 */

import { useEffect, useRef, useState } from 'react'
import { ChromaFlow, FilmGrain, FlutedGlass, RadialGradient, Shader, Swirl } from 'shaders/react'

type Corner = 'tr' | 'bl'

export interface FluteShaderProps {
  className?: string
  variant?: 'light' | 'dark'
  corner?: Corner
  /** Flute direction in degrees; 0 is vertical. */
  angle?: number
}

const at = (corner: Corner, x: number, y: number) => (corner === 'tr' ? { x, y } : { x: 1 - x, y: 1 - y })

function Fallback({ variant, corner }: { variant: 'light' | 'dark'; corner: Corner }) {
  const pos = corner === 'tr' ? '88% 8%' : '12% 92%'
  const base = variant === 'light' ? '#EFEFEF' : '#0A0A0A'
  return (
    <div aria-hidden className="absolute inset-0" style={{
      background: `repeating-linear-gradient(121deg, transparent 0 34px, rgba(255,255,255,${variant === 'light' ? 0.32 : 0.08}) 36px, transparent 44px),
        radial-gradient(ellipse 70% 80% at ${pos}, #ff2e00 0%, #ff5f03 22%, rgba(255,140,60,.55) 45%, transparent 70%), ${base}`,
    }} />
  )
}

export function FluteShader({ className = '', variant = 'light', corner = 'tr', angle = 31 }: FluteShaderProps) {
  const [unavailable, setUnavailable] = useState(false)
  const [f, setF] = useState({ t: 0, h: 0, x: 0.7, y: 0.3, portrait: false })
  const target = useRef(0)
  const host = useRef<HTMLDivElement>(null)
  const ptr = useRef({ x: 0.7, y: 0.3 })

  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    let raf = 0, last = 0, h = 0, x = 0.7, y = 0.3, inView = true
    const start = performance.now()
    const onMove = (e: PointerEvent) => {
      const r = host.current?.getBoundingClientRect()
      if (!r || !r.width) return
      const nx = (e.clientX - r.left) / r.width, ny = (e.clientY - r.top) / r.height
      ptr.current = { x: nx, y: ny }
      // hover is derived from position, so it works with content stacked over the canvas
      target.current = e.pointerType === 'mouse' && nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 ? 1 : 0
    }
    const onOut = (e: PointerEvent) => { if (!e.relatedTarget) target.current = 0 }
    const tick = (now: number) => {
      raf = requestAnimationFrame(tick)
      if (!inView || now - last < 33) return             // ~30 updates a second is plenty for a breath
      last = now
      h += (target.current - h) * 0.08
      x += (ptr.current.x - x) * 0.14; y += (ptr.current.y - y) * 0.14
      const r = host.current?.getBoundingClientRect()
      setF({ t: reduce ? 1.2 : (now - start) / 1000, h, x, y, portrait: !!r && r.width / Math.max(1, r.height) < 0.85 })
    }
    const io = new IntersectionObserver(([e]) => { inView = e.isIntersecting })
    if (host.current) io.observe(host.current)
    window.addEventListener('pointermove', onMove, { passive: true })
    document.addEventListener('pointerout', onOut)
    raf = requestAnimationFrame(tick)
    return () => { cancelAnimationFrame(raf); io.disconnect(); window.removeEventListener('pointermove', onMove); document.removeEventListener('pointerout', onOut) }
  }, [])

  if (unavailable) return <div className={className}><Fallback variant={variant} corner={corner} /></div>

  const { t, h, x, y, portrait } = f
  const breath = 0.5 + 0.5 * Math.sin(t * 1.25)           // ~5 s
  const breath2 = 0.5 + 0.5 * Math.sin(t * 0.9 + 2.1)
  const light = variant === 'light'
  const blend = light ? 'multiply' : 'screen'
  const edge = light ? '#ffffff' : '#000000'
  // the mass sits in the corner and reaches toward the middle; on portrait screens it stays tighter
  const main = portrait ? { c: at(corner, 0.98, 0.0), r: 0.26 + breath * 0.07, a: 1.0 } : { c: at(corner, 0.92, 0.08), r: 0.7 + breath * 0.14, a: 1.45 }
  const side = portrait ? { c: at(corner, 0.35, 0.02), r: 0.14 } : { c: at(corner, 0.62, 0.05), r: 0.3 }

  return (
    <div ref={host} className={className}>
      <Shader disableTelemetry onUnavailable={() => setUnavailable(true)} style={{ width: '100%', height: '100%' }}>
        <Swirl colorA={light ? '#ffffff' : '#0a0a0a'} colorB={light ? '#f0f0f0' : '#141414'} detail={1.7} />
        {/* always on: the orange breathes */}
        <RadialGradient blendMode={blend} center={main.c} radius={main.r + h * 0.05} aspect={main.a} opacity={0.86 + breath * 0.14}
          stops={[{ color: '#ee1200', position: 0 }, { color: '#ff2600', position: 0.28 }, { color: '#ff5a0a', position: 0.5 }, { color: light ? '#ffae7a' : '#5a1a06', position: 0.74 }, { color: edge, position: 1 }]} />
        <RadialGradient blendMode={blend} center={side.c} radius={side.r + breath2 * 0.1} aspect={1.6} opacity={0.45 + breath2 * 0.35}
          stops={[{ color: '#ff6a10', position: 0 }, { color: light ? '#ffb070' : '#4a1806', position: 0.5 }, { color: edge, position: 1 }]} />
        {/* on hover: a hot spot rides the pointer */}
        <RadialGradient blendMode={blend} center={{ x, y }} opacity={h} radius={0.15 + h * 0.06} aspect={1.8}
          stops={[{ color: '#e8160c', position: 0 }, { color: '#ff4a0a', position: 0.25 }, { color: light ? '#ffc27a' : '#3a1206', position: 0.6 }, { color: edge, position: 1 }]} />
        {/* and paints liquid by direction, in a warm spectrum */}
        <ChromaFlow blendMode={blend} baseColor={edge} upColor="#ff2a0e" downColor="#ff5f03" leftColor="#ff8a1f" rightColor="#ffb23e"
          momentum={13} radius={3.5} intensity={1.1} opacity={0.3 + h * 0.7} />
        <FlutedGlass shape="rounded" angle={angle} frequency={9} softness={1} speed={0.15}
          refraction={4 + h * 2} aberration={0.61 + h * 0.7} highlight={0.12 + h * 0.08} highlightSoftness={0} lightAngle={-90} />
        <FilmGrain strength={0.05} />
      </Shader>
    </div>
  )
}
