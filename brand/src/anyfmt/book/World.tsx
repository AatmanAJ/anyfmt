import {
  Bookmark, CalendarDays, ChartNoAxesColumn, ChevronLeft, ChevronRight, Download, Globe, Heart, Lock, MessageCircle, Plus, Repeat2, RotateCw, Share, X,
} from 'lucide-react'
import type { ReactNode } from 'react'
import { product } from '../../shared/product'
import { AnyWheel } from '../AnyWheel'
import { brand, convertWedges } from '../copy'
import { FileTile } from '../Demo'
import { Streaks } from '../Landing'
import { AppIcon, GlassTile, Mark, Wordmark } from '../Mark'
import { StackedLockup } from './Identity'
import { Fit, Section, Sub } from './kit'

function Tile({ label, children, tone = 'paper', className }: { label: string; children: ReactNode; tone?: 'paper' | 'ink'; className?: string }) {
  return (
    <figure className={`flex min-w-0 flex-col gap-3 ${className ?? ''}`}>
      <div className={`flex flex-1 items-center justify-center overflow-hidden rounded-[24px] p-4 sm:p-8 ${tone === 'ink' ? 'bg-[#111]' : 'af-well'}`}>{children}</div>
      <figcaption className="px-1 text-[14px] font-semibold">{label}</figcaption>
    </figure>
  )
}

/* lanyard badge */
function Badge() {
  return (
    <div className="relative h-[600px] w-[320px]">
      {/* strap */}
      <div className="absolute left-1/2 top-0 h-[120px] w-[40px] -translate-x-1/2 overflow-hidden"
        style={{ background: 'linear-gradient(90deg,#C95A1C,#EA7C25 30%,#F59248 50%,#EA7C25 70%,#C95A1C)', boxShadow: 'inset 0 0 0 1px rgba(120,35,0,.25)' }}>
        <div className="flex flex-col items-center gap-3 pt-2 text-[10px] font-semibold tracking-[-0.02em] text-white/85" style={{ writingMode: 'vertical-rl' }}>
          <span>anyfmt</span><span>anyfmt</span><span>anyfmt</span>
        </div>
      </div>
      {/* clip */}
      <div className="absolute left-1/2 top-[112px] h-[30px] w-[54px] -translate-x-1/2 rounded-[8px]" style={{ background: 'linear-gradient(180deg,#E9E9E9,#A9A9A9 60%,#D4D4D4)', boxShadow: '0 2px 4px rgba(0,0,0,.25), inset 0 1px 0 #fff' }} />
      <div className="absolute left-1/2 top-[136px] h-[22px] w-[16px] -translate-x-1/2 rounded-b-[6px]" style={{ background: 'linear-gradient(90deg,#9A9A9A,#E5E5E5,#9A9A9A)' }} />
      {/* card */}
      <div className="absolute inset-x-[10px] top-[150px] h-[440px] overflow-hidden rounded-[22px] bg-white"
        style={{ boxShadow: '0 0 0 1px rgba(17,17,17,.08), 0 30px 50px -24px rgba(90,30,0,.55), 0 8px 16px -8px rgba(17,17,17,.2)', transform: 'rotate(-2deg)' }}>
        <div className="mx-auto mt-3 h-[8px] w-[56px] rounded-full bg-[#F3F2F0] shadow-[inset_0_1px_2px_rgba(17,17,17,.25)]" />
        <div className="af-stage relative mx-3 mt-3 grid h-[180px] place-items-center overflow-hidden rounded-[16px]">
          <Streaks className="inset-0 h-full w-full" />
          <GlassTile size={118} />
        </div>
        <div className="px-6 pt-6">
          <div className="text-[12px] font-medium text-[#8C8884]">Contributor</div>
          <div className="mt-1 text-[30px] font-semibold leading-none tracking-[-0.045em]">Rowan Ito</div>
          <div className="mt-1.5 text-[14px] text-[#55524F]">Core maintainer · Wheel</div>
        </div>
        <div className="absolute inset-x-6 bottom-5 flex items-center justify-between border-t border-[#E7E5E2] pt-4">
          <Wordmark size={16} />
          <span className="af-mono text-[10.5px] text-[#8C8884]">AGPL-3.0</span>
        </div>
      </div>
    </div>
  )
}

/* social profile */
function Profile() {
  return (
    <div className="w-[520px] overflow-hidden rounded-[20px] bg-white" style={{ boxShadow: '0 0 0 1px #E7E5E2, 0 20px 40px -20px rgba(17,17,17,.25)' }}>
      <div className="af-stage relative h-[170px] overflow-hidden">
        <Streaks className="inset-0 h-full w-full" />
        <div aria-hidden className="absolute -bottom-[0.2em] right-4 text-[150px] font-semibold leading-none tracking-[-0.07em] text-white/[.16]">anyfmt</div>
      </div>
      <div className="relative px-5 pb-5">
        <div className="-mt-[52px] flex items-end justify-between">
          <div className="rounded-[26px] bg-white p-1.5"><AppIcon size={100} /></div>
          <span className="af-btn af-btn-dark !h-9 !rounded-full !px-5 !text-[14px]">Follow</span>
        </div>
        <div className="mt-3 text-[22px] font-semibold leading-tight tracking-[-0.03em]">anyfmt</div>
        <div className="text-[14px] text-[#8C8884]">@anyfmt</div>
        <p className="mt-3 text-[15px] leading-snug">{product.oneLiner} Free and open source, and every local feature stays on your Mac.</p>
        <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-[13.5px] text-[#8C8884]">
          <span className="flex items-center gap-1.5"><Globe size={14} /><span className="text-[#BB3F14]">{brand.domain}</span></span>
          <span>{product.platform}</span>
          <span className="flex items-center gap-1.5"><CalendarDays size={14} />Joined October 2026</span>
        </div>
      </div>
    </div>
  )
}

/* X post */
function Post() {
  return (
    <div className="w-[520px] rounded-[20px] bg-white p-5" style={{ boxShadow: '0 0 0 1px #E7E5E2, 0 20px 40px -20px rgba(17,17,17,.25)' }}>
      <div className="flex items-start gap-3">
        <AppIcon size={46} />
        <div className="min-w-0 flex-1">
          <div className="flex items-baseline gap-1.5 text-[15px]"><span className="font-semibold">anyfmt</span><span className="text-[#8C8884]">@anyfmt · Oct 26</span></div>
          <p className="mt-1 whitespace-pre-line text-[15.5px] leading-snug">{'Drag a file. Press Shift. Drop it on GIF.\n\n793 conversion routes, all running on your Mac. Free and open source. anyfmt.app'}</p>
        </div>
      </div>
      <div className="af-stage relative mt-4 h-[270px] overflow-hidden rounded-[16px] ring-1 ring-black/5">
        <Streaks className="inset-0 h-full w-full" />
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
          <AnyWheel wedges={convertWedges} size={230} tone="stage" active={0} hub={<span className="text-[11px] font-semibold text-[#111]">MOV</span>} />
        </div>
        <div className="absolute left-[57%] top-[5%] -rotate-6 scale-[.8]"><FileTile small /></div>
      </div>
      <div className="mt-4 flex items-center justify-between px-1 text-[#8C8884]">
        {[MessageCircle, Repeat2, Heart, ChartNoAxesColumn].map((I, i) => <I key={i} size={17} />)}
        <span className="flex gap-4"><Bookmark size={17} /><Share size={17} /></span>
      </div>
    </div>
  )
}

/* conference stage */
function Stage() {
  return (
    <div className="relative h-[620px] w-[1200px] overflow-hidden rounded-[18px]" style={{ background: 'radial-gradient(70% 60% at 50% 30%, #2A1A10 0%, #0B0807 70%)' }}>
      {/* beams */}
      {[180, 1020].map((x, i) => (
        <div key={x} className="absolute top-[-40px] h-[700px] w-[260px] opacity-30 blur-[18px]"
          style={{ left: x - 130, background: 'linear-gradient(180deg, rgba(255,200,150,.7), transparent 80%)', clipPath: 'polygon(45% 0, 55% 0, 100% 100%, 0 100%)', transform: `rotate(${i ? 14 : -14}deg)` }} />
      ))}
      {/* screen */}
      <div className="absolute left-1/2 top-[36px] h-[404px] w-[718px] -translate-x-1/2 rounded-[6px] p-[6px]" style={{ background: '#050505', boxShadow: '0 0 120px 10px rgba(234,124,37,.35), 0 0 0 1px #222' }}>
        <div className="af-stage relative h-full w-full overflow-hidden rounded-[3px]">
          <Streaks className="inset-0 h-full w-full" />
          <div className="relative flex h-full items-center gap-6 px-12">
            <div className="flex-1">
              <Wordmark size={22} tone="white" />
              <div className="mt-6 text-[54px] font-semibold leading-[0.95] tracking-[-0.055em] text-white">Any file.<br />Any format.<br /><span className="text-white/70">Mid‑drag.</span></div>
              <div className="mt-6 text-[15px] text-white/80">Free and open source · {brand.domain}</div>
            </div>
            <AnyWheel wedges={convertWedges} size={250} tone="stage" active={0} hub={<span className="text-[12px] font-semibold text-[#111]">MOV</span>} />
          </div>
        </div>
      </div>
      {/* floor + lectern */}
      <div className="absolute bottom-[40px] left-1/2 h-[120px] w-[1100px] -translate-x-1/2 rounded-[50%]" style={{ background: 'radial-gradient(50% 50% at 50% 40%, rgba(234,124,37,.22), rgba(20,12,8,.9) 70%)' }} />
      <div className="absolute bottom-[58px] left-[800px] h-[100px] w-[86px]" style={{ background: 'linear-gradient(180deg,#1E1E1E,#0E0E0E)', clipPath: 'polygon(6% 0, 94% 0, 100% 100%, 0 100%)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,.1)' }}>
        <div className="mt-6 grid place-items-center"><Mark size={30} variant="flat" /></div>
      </div>
      {/* audience */}
      <div className="absolute inset-x-0 bottom-0 h-[150px]">
        {Array.from({ length: 15 }, (_, i) => {
          const x = i * 84 - 20 + (i % 2) * 18, y = (i % 3) * 12
          return (
            <div key={i} className="absolute" style={{ left: x, bottom: -30 + y }}>
              <div className="mx-auto size-[46px] rounded-full" style={{ background: '#040404', boxShadow: 'inset 0 6px 8px -4px rgba(234,124,37,.35)' }} />
              <div className="-mt-2 h-[70px] w-[110px] rounded-t-[50px]" style={{ background: '#040404', boxShadow: 'inset 0 8px 10px -6px rgba(234,124,37,.25)' }} />
            </div>
          )
        })}
      </div>
    </div>
  )
}

/* browser tab */
function Browser() {
  return (
    <div className="w-[760px] overflow-hidden rounded-[14px] bg-[#EDECEA]" style={{ boxShadow: '0 0 0 1px rgba(17,17,17,.12), 0 30px 60px -28px rgba(17,17,17,.45)' }}>
      <div className="flex h-[42px] items-end gap-1 px-3">
        <div className="mb-[14px] mr-3"><span className="flex gap-2">{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-3 rounded-full" style={{ background: c }} />)}</span></div>
        <div className="flex h-[34px] w-[250px] items-center gap-2 rounded-t-[10px] bg-white px-3 text-[12.5px] font-medium shadow-[0_-1px_0_rgba(17,17,17,.06)]">
          <Mark size={14} /><span className="truncate">anyfmt · Any file. Any format.</span><X size={13} className="ml-auto text-[#8C8884]" />
        </div>
        <div className="flex h-[34px] w-[150px] items-center gap-2 px-3 text-[12.5px] text-[#8C8884]"><Globe size={13} /><span className="truncate">Docs</span></div>
        <Plus size={15} className="mb-[10px] ml-1 text-[#8C8884]" />
      </div>
      <div className="flex h-[44px] items-center gap-3 border-b border-[#E7E5E2] bg-white px-3 text-[#55524F]">
        <ChevronLeft size={17} /><ChevronRight size={17} className="opacity-40" /><RotateCw size={14} />
        <div className="flex h-[30px] flex-1 items-center gap-2 rounded-[8px] bg-[#F3F2F0] px-3 text-[13px]">
          <Lock size={12} className="text-[#8C8884]" /><span className="text-[#111]">{brand.domain}</span>
        </div>
      </div>
      <div className="bg-[#F7F7F7] p-2">
        <div className="af-stage relative h-[330px] overflow-hidden rounded-[16px]">
          <Streaks className="inset-0 h-full w-full" />
          <div className="relative mx-3 mt-3 flex h-10 items-center justify-between rounded-[11px] bg-white/75 px-3 backdrop-blur">
            <Wordmark size={15} />
            <div className="flex gap-4 text-[11.5px] font-medium text-[#55524F]"><span>How it works</span><span>Features</span><span>Pricing</span></div>
            <span className="af-btn af-btn-primary !h-7 !gap-1.5 !rounded-[8px] !px-2.5 !text-[11.5px]"><Download size={12} />Download</span>
          </div>
          <div className="relative mt-9 text-center">
            <div className="text-[46px] font-semibold leading-[0.95] tracking-[-0.055em]">Any file. Any format.<br /><span className="text-white/75">Mid‑drag.</span></div>
            <div className="mt-6 flex justify-center gap-2">
              <span className="af-btn af-btn-light !h-9 !gap-1.5 !px-4 !text-[13px]"><Download size={14} />Download for Mac</span>
              <span className="af-btn af-btn-ghost !h-9 !px-4 !text-[13px]">See how it works</span>
            </div>
          </div>
          <div className="absolute inset-x-[14%] -bottom-6 h-[60px] rounded-t-[12px] bg-white/30 ring-1 ring-white/50" />
        </div>
      </div>
    </div>
  )
}

/* store card */
function Store() {
  const shots = [
    <div key="a" className="af-stage relative grid h-full place-items-center overflow-hidden"><Streaks className="inset-0 h-full w-full" /><GlassTile size={66} /></div>,
    <div key="b" className="grid h-full place-items-center bg-[#F7F7F7] p-2"><div className="flex w-full items-center gap-1.5 rounded-[8px] bg-white p-1.5 shadow-[0_0_0_1px_#E7E5E2]"><AppIcon size={18} /><div className="text-[7.5px] leading-tight"><div className="font-semibold">clip.gif is ready</div><div className="text-[#8C8884]">4.1 MB</div></div></div></div>,
    <div key="c" className="grid h-full place-items-center bg-[#111]"><StackedLockup size={14} tone="white" /></div>,
  ]
  return (
    <div className="w-[480px] rounded-[22px] bg-white p-5" style={{ boxShadow: '0 0 0 1px #E7E5E2, 0 20px 40px -20px rgba(17,17,17,.25)' }}>
      <div className="flex gap-4">
        <AppIcon size={104} />
        <div className="flex min-w-0 flex-1 flex-col">
          <div className="text-[22px] font-semibold leading-tight tracking-[-0.03em]">anyfmt</div>
          <div className="text-[14px] text-[#55524F]">Convert any file mid-drag</div>
          <div className="mt-auto flex items-center gap-3">
            <span className="af-btn af-btn-primary !h-8 !rounded-full !px-5 !text-[13px]">Get</span>
            <span className="text-[12px] text-[#8C8884]">Free · open source</span>
          </div>
        </div>
      </div>
      <div className="mt-5 grid grid-cols-4 divide-x divide-[#E7E5E2] border-y border-[#E7E5E2] py-3 text-center">
        {[['Price', 'Free'], ['Category', 'Utilities'], ['Requires', 'macOS 13'], ['Chip', 'Apple silicon']].map(([k, v]) => (
          <div key={k} className="px-1"><div className="text-[10.5px] font-medium text-[#8C8884]">{k}</div><div className="mt-0.5 truncate text-[13px] font-semibold">{v}</div></div>
        ))}
      </div>
      <div className="mt-4 grid grid-cols-3 gap-2">
        {shots.map((s, i) => <div key={i} className="h-[96px] overflow-hidden rounded-[10px] ring-1 ring-black/5">{s}</div>)}
      </div>
    </div>
  )
}

export function World() {
  return (
    <Section id="world" n="10" eyebrow="Brand in the world" title={<>The same light,<br /><span className="text-[#8C8884]">everywhere it lands.</span></>}
      intro="Mockups of the brand applied, built from the same parts as the product: the stage, the glass tile, the app icon and the wheel.">
      <Sub title="On stage" note="A keynote slide: one orange stage, the headline in two tones, the wheel doing the talking.">
        <Tile label="Conference stage screen" tone="ink"><Fit w={1200} h={620}><Stage /></Fit></Tile>
      </Sub>
      <Sub title="In people’s hands and feeds">
        <div className="flex flex-col gap-6">
          <div className="grid gap-6 lg:grid-cols-[1fr_1.45fr]">
            <Tile label="Lanyard badge"><Fit w={320} h={600}><Badge /></Fit></Tile>
            <Tile label="Post"><Fit w={520} h={520}><Post /></Fit></Tile>
          </div>
          <div className="grid gap-6 lg:grid-cols-[1.1fr_1fr]">
            <Tile label="Social profile"><Fit w={520} h={418}><Profile /></Fit></Tile>
            <Tile label="Store product card"><Fit w={480} h={330}><Store /></Fit></Tile>
          </div>
        </div>
      </Sub>
      <Sub title="On screens" note="The tab, the address bar and the first screen of anyfmt.app.">
        <Tile label="Browser tab at anyfmt.app"><Fit w={760} h={430}><Browser /></Fit></Tile>
      </Sub>
    </Section>
  )
}
