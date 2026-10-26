import { ArrowLeft } from 'lucide-react'
import { useEffect, useRef, useState, type ComponentType } from 'react'
import { CHAPTERS, Cover, Icon, jump, Logo } from './book/Identity'
import { ONLY } from './book/kit'
import { Onboarding } from './book/Onboarding'
import { Surfaces } from './book/Surfaces'
import { Colour, Components, Type, Voice } from './book/System'
import { World } from './book/World'
import { Mark, Wordmark } from './Mark'
import './anyfmt.css'
import './book.css'

const PARTS: Record<string, ComponentType> = {
  cover: Cover, logo: Logo, icon: Icon, colour: Colour, type: Type, voice: Voice,
  components: Components, onboarding: Onboarding, surfaces: Surfaces, world: World,
}

function Nav() {
  const [active, setActive] = useState('cover')
  const list = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const els = [...document.querySelectorAll<HTMLElement>('[data-book-section]')]
    const io = new IntersectionObserver((es) => {
      const hit = es.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0]
      if (hit) setActive(hit.target.id)
    }, { rootMargin: '-35% 0px -60% 0px' })
    els.forEach((el) => io.observe(el))
    return () => io.disconnect()
  }, [])
  useEffect(() => {
    const box = list.current, a = box?.querySelector<HTMLElement>(`[data-id="${active}"]`)
    if (box && a) box.scrollTo({ left: a.offsetLeft - box.clientWidth / 2 + a.offsetWidth / 2, behavior: 'smooth' })
  }, [active])
  return (
    <div className="fixed inset-x-0 top-0 z-50 px-3 pt-3 sm:px-5">
      <nav aria-label="Brand book" className="mx-auto flex h-14 max-w-[1240px] items-center gap-2 rounded-[16px] bg-white/80 pl-3 pr-1.5 shadow-[0_0_0_1px_rgba(17,17,17,.08),0_10px_30px_-18px_rgba(17,17,17,.35)] backdrop-blur-xl sm:gap-3 sm:pl-4">
        <a href="#/anyfmt" className="flex shrink-0 items-center gap-2.5 rounded-lg" aria-label="anyfmt home">
          <span className="sm:hidden"><Mark size={24} /></span>
          <span className="max-sm:hidden"><Wordmark size={19} /></span>
          <span className="hidden text-[14px] font-medium text-[#8C8884] xl:inline">Brand book</span>
        </a>
        <span className="h-6 w-px shrink-0 bg-[#E7E5E2]" />
        <div ref={list} className="afb-scroll flex min-w-0 flex-1 items-center gap-0.5 overflow-x-auto [mask-image:linear-gradient(90deg,transparent,#000_12px,#000_calc(100%-16px),transparent)]">
          {CHAPTERS.map((c, i) => {
            const on = active === c.id
            return (
              <a key={c.id} data-id={c.id} href={`#${c.id}`} aria-current={on ? 'true' : undefined}
                onClick={(e) => { e.preventDefault(); jump(c.id) }}
                className={`shrink-0 whitespace-nowrap rounded-[10px] px-2.5 py-1.5 text-[13.5px] font-medium ${on ? 'bg-gradient-to-b from-[#F59248] to-[#E5701E] text-white shadow-[inset_0_1px_0_rgba(255,255,255,.4),0_0_0_1px_#C5521A]' : 'text-[#55524F] hover:bg-black/[.04] hover:text-[#111]'}`}>
                <span className={`af-mono mr-1 text-[10.5px] ${on ? 'text-white/75' : 'text-[#8C8884]'}`}>{String(i + 1).padStart(2, '0')}</span>{c.label}
              </a>
            )
          })}
        </div>
        <a href="#/anyfmt" className="af-btn af-btn-light !h-10 shrink-0 !gap-1.5 !px-3.5 !text-[13.5px] max-md:hidden"><ArrowLeft size={15} />Site</a>
      </nav>
    </div>
  )
}

function Footer() {
  return (
    <footer className="mx-auto max-w-[1240px] px-4 pb-16 pt-6 sm:px-6">
      <div className="flex flex-col justify-between gap-6 border-t border-[#D9D6D2] pt-8 sm:flex-row sm:items-center">
        <div className="flex flex-col gap-2">
          <Wordmark size={20} />
          <p className="text-[13px] text-[#8C8884]">Brand book · Version 1.0 · 26 October 2026. Questions go to the maintainers on GitHub.</p>
        </div>
        <a href="#/anyfmt" className="af-btn af-btn-light self-start sm:self-auto"><ArrowLeft size={16} />Back to anyfmt.app</a>
      </div>
    </footer>
  )
}

export default function BrandBook() {
  useEffect(() => { document.title = 'anyfmt brand book' }, [])
  const ids = CHAPTERS.map((c) => c.id).filter((id) => !ONLY || ONLY.includes(id))
  return (
    <div className="af afb-root min-h-screen overflow-x-clip">
      <Nav />
      <main>
        {!ids.includes('cover') && <div className="h-16" />}
        {ids.map((id) => { const P = PARTS[id]; return <P key={id} /> })}
      </main>
      <Footer />
    </div>
  )
}
