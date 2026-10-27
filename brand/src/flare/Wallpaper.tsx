/**
 * Recording backgrounds (Screen Studio, Cap) in the Flare look: the same `shaders` stack as the
 * hero, with time frozen so a render is repeatable. The recording covers the middle, so every
 * variant puts its heat on the diagonal corners and lets the 31° flutes carry it along the edges.
 *
 * Render one at #/wallpaper/<id>; the viewport sets the output size.
 */

import { useEffect, useState, type ReactNode } from 'react'
import { useParams } from 'react-router-dom'
import { FilmGrain, FlutedGlass, Glow, LightLeak, LinearGradient, RadialGradient, Shader, Swirl } from 'shaders/react'

const flutes = (o: { aberration?: number; refraction?: number; highlight?: number; highlightColor?: string } = {}) => (
  <FlutedGlass shape="rounded" angle={31} frequency={12} softness={1} speed={0} refraction={o.refraction ?? 4}
    aberration={o.aberration ?? 0.7} highlight={o.highlight ?? 0.14} highlightSoftness={0} highlightColor={o.highlightColor ?? '#ffffff'} lightAngle={-90} />
)

const WALLS: Record<string, { bg: string; layers: ReactNode }> = {
  // full bleed: white-hot masses in two corners, a near-black crimson valley under the recording
  ember: {
    bg: '#6a0500',
    layers: (
      <>
        <LinearGradient start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} stops={[
          { color: '#ff4a00', position: 0 }, { color: '#e01800', position: 0.22 }, { color: '#7a0600', position: 0.4 },
          { color: '#1c0200', position: 0.54 }, { color: '#6a0500', position: 0.7 }, { color: '#d81400', position: 0.86 }, { color: '#ff3000', position: 1 }]} />
        <Swirl blendMode="multiply" colorA="#ffffff" colorB="#ffe2d4" detail={1.7} speed={0} />
        <RadialGradient blendMode="screen" center={{ x: 0.98, y: -0.02 }} radius={0.56} aspect={1.45} stops={[
          { color: '#fff4e0', position: 0 }, { color: '#ffc46a', position: 0.1 }, { color: '#ff7a1f', position: 0.28 },
          { color: '#ff2a00', position: 0.5 }, { color: '#000000', position: 1 }]} />
        <RadialGradient blendMode="screen" center={{ x: 0.02, y: 1.02 }} radius={0.44} aspect={1.45} stops={[
          { color: '#ffb070', position: 0 }, { color: '#ff5a0a', position: 0.2 }, { color: '#e01000', position: 0.45 },
          { color: '#000000', position: 1 }]} />
        <LightLeak position={{ x: 0.99, y: 0.02 }} spread={0.7} intensity={0.25} streaks={0.75} colorFringe="#ff2a0e" flicker={0} speed={0} seed={3} />
        {flutes({ aberration: 0.9, highlight: 0.18, highlightColor: '#ffd9b0' })}
        <Glow intensity={0.6} threshold={0.7} size={48} />
        <FilmGrain strength={0.06} animated={false} />
      </>
    ),
  },
  // ember poured through rippled glass
  molten: {
    bg: '#6a0500',
    layers: (
      <>
        <LinearGradient start={{ x: 1, y: 0 }} end={{ x: 0, y: 1 }} stops={[
          { color: '#ff4a00', position: 0 }, { color: '#e01800', position: 0.22 }, { color: '#7a0600', position: 0.4 },
          { color: '#1c0200', position: 0.54 }, { color: '#6a0500', position: 0.7 }, { color: '#d81400', position: 0.86 }, { color: '#ff3000', position: 1 }]} />
        <Swirl blendMode="multiply" colorA="#ffffff" colorB="#ffe2d4" detail={1.7} speed={0} />
        <RadialGradient blendMode="screen" center={{ x: 0.98, y: -0.02 }} radius={0.56} aspect={1.45} stops={[
          { color: '#fff4e0', position: 0 }, { color: '#ffc46a', position: 0.1 }, { color: '#ff7a1f', position: 0.28 },
          { color: '#ff2a00', position: 0.5 }, { color: '#000000', position: 1 }]} />
        <RadialGradient blendMode="screen" center={{ x: 0.02, y: 1.02 }} radius={0.44} aspect={1.45} stops={[
          { color: '#ffb070', position: 0 }, { color: '#ff5a0a', position: 0.2 }, { color: '#e01000', position: 0.45 },
          { color: '#000000', position: 1 }]} />
        <FlutedGlass shape="waves" angle={31} frequency={12} softness={1} speed={0} waveAmplitude={0.1} waveFrequency={1.3}
          refraction={4} aberration={0.9} highlight={0.18} highlightSoftness={0} highlightColor="#ffd9b0" lightAngle={-90} />
        <Glow intensity={0.6} threshold={0.7} size={48} />
        <FilmGrain strength={0.06} animated={false} />
      </>
    ),
  },
  // light from behind the recording: a white-hot core the screen covers, streaked out across the margin
  eclipse: {
    bg: '#0A0A0A',
    layers: (
      <>
        <Swirl colorA="#0a0a0a" colorB="#161616" detail={1.7} speed={0} />
        <RadialGradient blendMode="screen" center={{ x: 0.5, y: 0.5 }} radius={1.0} aspect={1.6} stops={[
          { color: '#fff1d6', position: 0 }, { color: '#ffb23e', position: 0.3 }, { color: '#ff5a0a', position: 0.46 },
          { color: '#ee1200', position: 0.6 }, { color: '#3a0800', position: 0.8 }, { color: '#000000', position: 1 }]} />
        {flutes({ aberration: 0.8 })}
        <Glow intensity={0.5} threshold={0.7} size={40} />
        <FilmGrain strength={0.05} animated={false} />
      </>
    ),
  },
  // black, orange burning in from the bottom left with an answer in the top right
  night: {
    bg: '#0A0A0A',
    layers: (
      <>
        <Swirl colorA="#0a0a0a" colorB="#161616" detail={1.7} speed={0} />
        <RadialGradient blendMode="screen" center={{ x: 0.06, y: 0.96 }} radius={0.7} aspect={1.45} stops={[
          { color: '#ee1200', position: 0 }, { color: '#ff2600', position: 0.26 }, { color: '#ff5a0a', position: 0.48 },
          { color: '#5a1a06', position: 0.74 }, { color: '#000000', position: 1 }]} />
        <RadialGradient blendMode="screen" center={{ x: 0.97, y: 0.02 }} radius={0.44} aspect={1.6} stops={[
          { color: '#ff4a14', position: 0 }, { color: '#ff7a1f', position: 0.2 }, { color: '#4a1806', position: 0.6 }, { color: '#000000', position: 1 }]} />
        {flutes()}
        <FilmGrain strength={0.05} animated={false} />
      </>
    ),
  },
  // the hero itself: light paper, orange multiplied in from the top right, a softer echo bottom left
  paper: {
    bg: '#EFEFEF',
    layers: (
      <>
        <Swirl colorA="#ffffff" colorB="#f0f0f0" detail={1.7} speed={0} />
        <RadialGradient blendMode="multiply" center={{ x: 0.94, y: 0.06 }} radius={0.74} aspect={1.45} stops={[
          { color: '#ee1200', position: 0 }, { color: '#ff2600', position: 0.28 }, { color: '#ff5a0a', position: 0.5 },
          { color: '#ffae7a', position: 0.74 }, { color: '#ffffff', position: 1 }]} />
        <RadialGradient blendMode="multiply" center={{ x: 0.04, y: 0.98 }} radius={0.42} aspect={1.6} stops={[
          { color: '#ff4a14', position: 0 }, { color: '#ff8a3a', position: 0.3 }, { color: '#ffd2b0', position: 0.65 }, { color: '#ffffff', position: 1 }]} />
        {flutes({ aberration: 0.61, highlight: 0.12 })}
        <FilmGrain strength={0.05} animated={false} />
      </>
    ),
  },
}

export default function Wallpaper() {
  const { id = 'ember' } = useParams()
  const wall = WALLS[id] ?? WALLS.ember
  const [ready, setReady] = useState(false)
  useEffect(() => {
    document.title = `anyfmt wallpaper: ${id}`
  }, [id])
  return (
    <div className="fixed inset-0 overflow-hidden" style={{ background: wall.bg }} data-ready={ready ? '1' : undefined}>
      <Shader key={id} disableTelemetry onReady={() => setReady(true)} style={{ width: '100%', height: '100%' }}>
        {wall.layers}
      </Shader>
    </div>
  )
}
