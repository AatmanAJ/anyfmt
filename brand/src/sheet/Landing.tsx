import './sheet.css'
import { Hero, Nav } from './landing/Hero'
import { Features, ProductRows, Stats, Strip } from './landing/Sections'
import { Cta, Faq, Footer, Pricing } from './landing/Closing'

/* anyfmt landing, "Sheet" direction. `?only=hero,features` renders a subset (for tall screenshots). */
const SECTIONS = [
  ['hero', Hero], ['strip', Strip], ['features', Features], ['rows', ProductRows], ['stats', Stats],
  ['pricing', Pricing], ['faq', Faq], ['cta', Cta], ['footer', Footer],
] as const

export default function Landing() {
  const only = new URLSearchParams(location.search).get('only')?.split(',')
  return (
    <div className="sh min-h-screen overflow-x-clip">
      <Nav />
      <main>
        {SECTIONS.filter(([id]) => !only || only.includes(id)).map(([id, C]) => <C key={id} />)}
      </main>
    </div>
  )
}
