import { useEffect, useState, type ComponentType } from 'react'
import './block.css'
import './book/book.css'
import { Mark } from './Mark'
import { isShot } from '../shared/kit'
import { Cover } from './book/Cover'
import { Logo } from './book/Logo'
import { IconSection } from './book/Icon'
import { Colour } from './book/Colour'
import { Type } from './book/Type'
import { IsoSystem } from './book/IsoSystem'
import { Voice } from './book/Voice'
import { Components } from './book/Components'
import { Onboarding } from './book/Onboarding'
import { Surfaces } from './book/Surfaces'
import { World } from './book/World'

const SECTIONS: { id: string; label: string; C: ComponentType }[] = [
  { id: 'cover', label: 'Cover', C: Cover },
  { id: 'logo', label: 'Logo', C: Logo },
  { id: 'icon', label: 'App icon', C: IconSection },
  { id: 'colour', label: 'Colour', C: Colour },
  { id: 'type', label: 'Type', C: Type },
  { id: 'iso', label: 'Isometric', C: IsoSystem },
  { id: 'voice', label: 'Voice', C: Voice },
  { id: 'components', label: 'Components', C: Components },
  { id: 'onboarding', label: 'Onboarding', C: Onboarding },
  { id: 'surfaces', label: 'App surfaces', C: Surfaces },
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
    }, { rootMargin: '-35% 0px -60% 0px' })
    els.forEach((e) => io.observe(e))
    return () => io.disconnect()
  }, [])
  return active
}

function go(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
}

export default function BrandBook() {
  const active = useActive()
  const list = only ? SECTIONS.filter((s) => only.includes(s.id)) : SECTIONS
  return (
    <div className="bk bkb min-h-screen">
      {/* Mobile: a sticky strip of chunky chips. */}
      <nav aria-label="Sections" className="sticky top-0 z-40 border-b border-[#2A2A30] bg-[#0E0E10] md:hidden">
        <div className="flex items-center gap-2 overflow-x-auto px-4 py-2.5 [scrollbar-width:none]">
          <span className="shrink-0 pr-1"><Mark size={22} /></span>
          {SECTIONS.map((s, i) => (
            <button key={s.id} onClick={() => go(s.id)}
              className="bk-mono shrink-0 rounded-[4px] px-2.5 py-1.5 text-[11px] uppercase tracking-[.06em]"
              style={{ background: active === s.id ? '#FF6B1A' : '#1C1C21', color: active === s.id ? '#0E0E10' : '#F4F1EC' }}>
              {String(i + 1).padStart(2, '0')} {s.label}
            </button>
          ))}
        </div>
      </nav>

      <div className="mx-auto flex max-w-[1520px]">
        {/* Desktop: a sticky sidebar, like the case-study page it's modelled on. */}
        <aside className="sticky top-0 hidden h-screen w-[232px] shrink-0 flex-col border-r border-[#2A2A30] px-5 py-6 md:flex">
          <a href="#/block" className="flex items-center gap-2.5">
            <Mark size={30} />
            <span className="bk-display text-[22px] font-[640] leading-none">anyfmt</span>
          </a>
          <div className="mt-6">
            <div className="bk-display text-[19px] font-[600] leading-[1.05]">Brand book</div>
            <div className="bk-mono mt-1 text-[11px] uppercase tracking-[.08em] text-[#8A8790]">Block edition · v1.0</div>
          </div>
          <ul className="mt-8 flex flex-col gap-1">
            {SECTIONS.map((s, i) => {
              const on = active === s.id
              return (
                <li key={s.id}>
                  <button onClick={() => go(s.id)} aria-current={on ? 'true' : undefined}
                    className="bkb-nav group flex w-full items-center gap-3 rounded-[4px] px-2.5 py-[7px] text-left text-[14px] font-[550]"
                    style={{ background: on ? '#FF6B1A' : undefined, color: on ? '#0E0E10' : undefined, boxShadow: on ? '3px 3px 0 #561629' : undefined }}>
                    <span className="bk-mono w-5 text-[11px] opacity-60">{String(i + 1).padStart(2, '0')}</span>{s.label}
                  </button>
                </li>
              )
            })}
          </ul>
          <div className="bk-mono mt-auto text-[11px] leading-[1.6] text-[#8A8790]">
            anyfmt.app<br />Open source · AGPL-3.0<br />macOS 13+ · Apple silicon
          </div>
        </aside>

        <main className="min-w-0 flex-1 px-4 pb-32 pt-4 md:px-8 md:pt-8">
          {list.map(({ id, C }) => <C key={id} />)}
          <footer className="mt-32 flex flex-col items-start justify-between gap-6 border-t border-[#2A2A30] pt-8 md:flex-row md:items-end">
            <div className="bk-display text-[40px] font-[640] leading-[.9] md:text-[64px]">Drag. Press.<br /><span className="text-[#FF6B1A]">Drop.</span></div>
            <div className="bk-mono text-[12px] leading-[1.7] text-[#8A8790]">anyfmt brand book · Block edition<br />Everything on this page is drawn in CSS and SVG.</div>
          </footer>
        </main>
      </div>
    </div>
  )
}
