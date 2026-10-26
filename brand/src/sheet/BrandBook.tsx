import { useEffect, useRef, useState, type ComponentType } from 'react'
import './sheet.css'
import './book/book.css'
import { Wordmark } from './Mark'
import { isShot } from '../shared/kit'
import { Cover } from './book/Cover'
import { Logo } from './book/Logo'
import { IconSection } from './book/Icon'
import { Colour } from './book/Colour'
import { Type } from './book/Type'
import { Elevation } from './book/Elevation'
import { Imagery } from './book/Imagery'
import { Voice } from './book/Voice'
import { Components } from './book/Components'
import { Onboarding } from './book/Onboarding'
import { AppSurfaces } from './book/AppSurfaces'
import { World } from './book/World'

export const SECTIONS: { id: string; label: string; C: ComponentType }[] = [
  { id: 'cover', label: 'Cover', C: Cover },
  { id: 'logo', label: 'Logo', C: Logo },
  { id: 'icon', label: 'App icon', C: IconSection },
  { id: 'colour', label: 'Colour', C: Colour },
  { id: 'type', label: 'Type', C: Type },
  { id: 'surfaces', label: 'Surfaces', C: Elevation },
  { id: 'imagery', label: 'Imagery', C: Imagery },
  { id: 'voice', label: 'Voice', C: Voice },
  { id: 'components', label: 'Components', C: Components },
  { id: 'onboarding', label: 'Onboarding', C: Onboarding },
  { id: 'app', label: 'App surfaces', C: AppSurfaces },
  { id: 'world', label: 'In the world', C: World },
]

const only = typeof location !== 'undefined' ? new URLSearchParams(location.search).get('only')?.split(',') : undefined

function useActive() {
  const [active, setActive] = useState('cover')
  useEffect(() => {
    if (isShot) return
    const els = [...document.querySelectorAll<HTMLElement>('[data-sec]')]
    const io = new IntersectionObserver((entries) => {
      const vis = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)
      if (vis[0]) setActive((vis[0].target as HTMLElement).dataset.sec!)
    }, { rootMargin: '-30% 0px -65% 0px' })
    els.forEach((e) => io.observe(e))
    return () => io.disconnect()
  }, [])
  return active
}

function go(e: React.MouseEvent, id: string) {
  e.preventDefault()
  document.getElementById(id)?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
}

export default function BrandBook() {
  const active = useActive()
  const list = only ? SECTIONS.filter((s) => only.includes(s.id)) : SECTIONS
  const bar = useRef<HTMLDivElement>(null)
  // Keep the current label in view in the scrolling nav strip.
  useEffect(() => {
    const el = bar.current?.querySelector<HTMLElement>(`[data-nav="${active}"]`)
    const box = bar.current
    if (el && box) box.scrollTo({ left: el.offsetLeft - box.clientWidth / 2 + el.clientWidth / 2, behavior: 'smooth' })
  }, [active])

  useEffect(() => { document.title = 'anyfmt brand book · Sheet' }, [])

  return (
    <div className="sh shb min-h-screen overflow-x-clip">
      <header className="sticky top-0 z-40 border-b border-black bg-white/95 backdrop-blur-[6px]">
        <div className="mx-auto flex h-[52px] max-w-[1200px] items-center gap-6 px-4 md:px-6">
          <a href="#/sheet" className="flex-none" aria-label="anyfmt home"><Wordmark size={19} /></a>
          <span className="hidden h-5 w-px bg-[var(--shb-line)] md:block" />
          <nav aria-label="Sections" className="shb-nav min-w-0 flex-1">
            <div ref={bar} className="shb-scroll flex items-center gap-5 overflow-x-auto py-[15px]">
              {SECTIONS.map((s, i) => (
                <a key={s.id} data-nav={s.id} href={`#${s.id}`} onClick={(e) => go(e, s.id)} aria-current={active === s.id ? 'true' : undefined} className="shb-lbl py-1">
                  <span className="opacity-60">{String(i).padStart(2, '0')}</span> {s.label}
                </a>
              ))}
            </div>
          </nav>
        </div>
      </header>

      <main className="mx-auto max-w-[1200px] px-4 pb-0 md:px-6">
        {list.map(({ id, C }) => <C key={id} />)}
      </main>

      <footer className="mt-28 bg-[var(--sh-orange)]">
        <div className="mx-auto max-w-[1200px] px-4 pb-10 pt-16 md:px-6">
          <div className="sh-display-xl text-[64px] md:text-[150px]">Drag. Press. Drop.</div>
          <div className="mt-10 flex flex-col justify-between gap-4 border-t border-black pt-4 md:flex-row">
            <span className="shb-lbl">anyfmt brand book · Sheet edition · Vol. 01</span>
            <span className="shb-lbl">anyfmt.app · Open source, AGPL-3.0 · Drawn in CSS and SVG</span>
          </div>
        </div>
      </footer>
    </div>
  )
}
