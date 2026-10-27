/**
 * Hero background built on the `shaders` package (shaders.com, MIT): the Swirl, ChromaFlow,
 * FlutedGlass and FilmGrain stack, turned horizontal. An orange glow breathes underneath at all
 * times; hovering hands over to ChromaFlow, so the pointer paints liquid colour that the
 * horizontal flutes smear into bands, while the glass sharpens its aberration. WebGPU only, so
 * browsers without it get the WebGL Streaks shader instead.
 */

import { useEffect, useRef, useState } from 'react'
import { ChromaFlow, FilmGrain, FlutedGlass, RadialGradient, Shader, Swirl } from 'shaders/react'
import { Streaks } from './Streaks'

/** `hover` means the pointer is over the hero. It is derived from pointer position, so it also
 *  works when the canvas sits under content that takes the pointer. */

const breath0 = (t: number) => 0.5 + 0.5 * Math.sin(t * 1.25)

export function HeroShader({ className = '' }: { className?: string }) {
  const [unavailable, setUnavailable] = useState(false)
  const [f, setF] = useState({ t: 0, h: 0, x: 0.7, y: 0.4, portrait: false })
  const target = useRef(0)
  const host = useRef<HTMLDivElement>(null)
  const ptr = useRef({ x: 0.7, y: 0.4 })

  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    let raf = 0, last = 0, h = 0, x = 0.7, y = 0.4
    const start = performance.now()
    const onMove = (e: PointerEvent) => {
      const r = host.current?.getBoundingClientRect()
      if (!r || !r.width) return
      const nx = (e.clientX - r.left) / r.width, ny = (e.clientY - r.top) / r.height
      ptr.current = { x: nx, y: ny }
      target.current = e.pointerType === 'mouse' && nx >= 0 && nx <= 1 && ny >= 0 && ny <= 1 ? 1 : 0
    }
    const onOut = (e: PointerEvent) => { if (!e.relatedTarget) target.current = 0 }
    const tick = (now: number) => {
      raf = requestAnimationFrame(tick)
      if (now - last < 33) return                        // ~30 updates a second is plenty for a breath
      last = now
      h += (target.current - h) * 0.08
      x += (ptr.current.x - x) * 0.14; y += (ptr.current.y - y) * 0.14
      const r = host.current?.getBoundingClientRect()
      setF({ t: reduce ? 1.2 : (now - start) / 1000, h, x, y, portrait: !!r && r.width / Math.max(1, r.height) < 0.85 })
    }
    window.addEventListener('pointermove', onMove, { passive: true })
    document.addEventListener('pointerout', onOut)
    raf = requestAnimationFrame(tick)
    return () => { cancelAnimationFrame(raf); window.removeEventListener('pointermove', onMove); document.removeEventListener('pointerout', onOut) }
  }, [])

  if (unavailable) return <div className={className}><Streaks /></div>

  const { t, h, x, y, portrait } = f
  // on a tall, narrow canvas the glow tucks into the top corner so the copy below stays light
  const main = portrait ? { c: { x: 0.92, y: 0.12 }, r: 0.32 + breath0(t) * 0.1, a: 1.1 } : { c: { x: 0.8, y: 0.42 }, r: 0.55 + breath0(t) * 0.2, a: 1.7 }
  const side = portrait ? { c: { x: 0.15, y: 0.02 }, r: 0.14 } : { c: { x: 0.6, y: 0.74 }, r: 0.28 }
  const breath = 0.5 + 0.5 * Math.sin(t * 1.25)          // ~5s cycle
  const breath2 = 0.5 + 0.5 * Math.sin(t * 0.9 + 2.1)

  return (
    <div ref={host} className={className}>
    <Shader disableTelemetry onUnavailable={() => setUnavailable(true)} style={{ width: '100%', height: '100%' }}>
      <Swirl colorA="#ffffff" colorB="#f0f0f0" detail={1.7} />
      {/* always on: the orange breathes */}
      <RadialGradient blendMode="multiply" center={main.c}
        stops={[{ color: '#ff2e00', position: 0 }, { color: '#ff5f03', position: 0.28 }, { color: '#ff9a4a', position: 0.55 }, { color: '#ffffff', position: 1 }]}
        radius={main.r + h * 0.06} aspect={main.a} opacity={0.88 + breath * 0.12} />
      <RadialGradient blendMode="multiply" center={side.c}
        stops={[{ color: '#ff6a10', position: 0 }, { color: '#ffb070', position: 0.5 }, { color: '#ffffff', position: 1 }]}
        radius={side.r + breath2 * 0.1} aspect={1.5} opacity={0.5 + breath2 * 0.35} />
      {/* on hover: a hot spot of light rides the pointer and the flutes smear it into a band */}
      <RadialGradient blendMode="multiply" center={{ x, y }} opacity={h}
        stops={[{ color: '#e8160c', position: 0 }, { color: '#ff4a0a', position: 0.25 }, { color: '#ffc27a', position: 0.6 }, { color: '#ffffff', position: 1 }]}
        radius={0.16 + h * 0.06} aspect={2.4} />
      {/* and the pointer paints liquid, by direction, in a warm spectrum */}
      <ChromaFlow blendMode="multiply" baseColor="#ffffff" upColor="#ff2a0e" downColor="#ff5f03" leftColor="#ff8a1f" rightColor="#ffb23e"
        momentum={13} radius={3.5} intensity={1.1} opacity={0.35 + h * 0.65} />
      <FlutedGlass shape="rounded" angle={90} frequency={8} softness={1} speed={0.15}
        refraction={4 + h * 2} aberration={0.61 + h * 0.8} highlight={0.12 + h * 0.1} highlightSoftness={0} lightAngle={-90} />
      <FilmGrain strength={0.05} />
    </Shader>
    </div>
  )
}
