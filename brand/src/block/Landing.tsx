import './block.css'
import './landing/landing.css'
import { Hero, Nav } from './landing/Hero'
import { FormatsMarquee, ThreeKeys } from './landing/Keys'
import { Playground } from './landing/Playground'
import { Features, Numbers } from './landing/Features'
import { Agents, Faq, FinalCta, Footer, Pricing } from './landing/Closing'

/* anyfmt landing, "Block" direction. `?only=hero,keys` renders a subset (for tall screenshots). */
const SECTIONS = [
  ['hero', Hero], ['marquee', FormatsMarquee], ['keys', ThreeKeys], ['play', Playground], ['features', Features],
  ['numbers', Numbers], ['agents', Agents], ['pricing', Pricing], ['faq', Faq], ['cta', FinalCta], ['footer', Footer],
] as const

export default function Landing() {
  const only = new URLSearchParams(location.search).get('only')?.split(',')
  return (
    <div className="bk min-h-screen overflow-x-clip">
      <Nav />
      <main>
        {SECTIONS.filter(([id]) => !only || only.includes(id)).map(([id, C]) => <C key={id} />)}
      </main>
    </div>
  )
}
