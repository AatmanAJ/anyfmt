import { AlertTriangle, Check, Copy, Layers, Lock, Sparkles } from 'lucide-react'
import type { ReactNode } from 'react'
import { C, Caption, Section, Sub, Tile, Verdict } from './ui'

const PRINCIPLES = [
  { w: 'plain', c: C.lilac, body: 'Say what happened in words a tired person understands. File extensions are the only jargon we use.' },
  { w: 'quick', c: C.orange, body: 'Short sentences, verbs first. The wheel opens in 43 ms; the copy shouldn\'t take longer to read than that.' },
  { w: 'local', c: C.pink, body: 'Talk the way the app works: on your Mac, with your files. Privacy is a fact we state, not a promise we sell.' },
]

const PAIRS = [
  ['Converted to GIF. Saved next to the original.', 'Success! Your file has been successfully processed!'],
  ['Can\'t open clip.mov. It looks damaged. Try exporting it again.', 'Error 0x80041: An unexpected error has occurred.'],
  ['Runs on your Mac. Nothing is uploaded.', 'Bank-grade privacy powered by cutting-edge technology.'],
  ['Press ⇧ while you drag.', 'Leverage our intuitive radial interface to unlock seamless workflows.'],
]

function Card({ children, kind, title, icon }: { children: ReactNode; kind: string; title?: string; icon?: ReactNode }) {
  return (
    <div className="rounded-[8px] bg-[#1C1C21] p-4 ring-1 ring-inset ring-[#2C2C33]">
      <div className="bk-mono mb-3 flex items-center gap-2 text-[10.5px] uppercase tracking-[.08em] text-[#8A8790]">{icon}{kind}</div>
      {title && <div className="mb-1 text-[15px] font-[620] leading-[1.3]">{title}</div>}
      <div className="text-[14px] leading-[1.45] text-[#F4F1EC]/75">{children}</div>
    </div>
  )
}

function Toast({ children, tone = 'ok' }: { children: ReactNode; tone?: 'ok' | 'err' }) {
  return (
    <div className="flex items-center gap-3 rounded-full bg-[#0E0E10] py-2 pl-2 pr-4 ring-1 ring-inset ring-[#2C2C33]">
      <span className="grid size-6 shrink-0 place-items-center rounded-full" style={{ background: tone === 'ok' ? C.orange : C.pink, color: C.ink }}>
        {tone === 'ok' ? <Check size={14} strokeWidth={3} /> : <AlertTriangle size={13} strokeWidth={2.6} />}
      </span>
      <span className="text-[14px] font-[540]">{children}</span>
    </div>
  )
}

export function Voice() {
  return (
    <Section id="voice" num="07" title="Voice" accent="." intro="We sound like a good tool: short, specific, and on your side. We say what happened, then what to do about it.">
      <Tile bg={C.ink2} className="px-5 py-14 md:px-16 md:py-24">
        <p className="bk-display mx-auto max-w-[18ch] text-center text-[38px] font-[600] leading-[1.02] md:text-[76px]">
          The anyfmt tone of voice is based on the following principles:{' '}
          <span style={{ color: C.lilac }}>plain</span>, <span style={{ color: C.orange }}>quick</span>, <span style={{ color: C.pink }}>local</span>.
        </p>
        <div className="mx-auto mt-14 grid max-w-[1000px] gap-8 md:mt-20 md:grid-cols-3">
          {PRINCIPLES.map((p) => (
            <div key={p.w} className="flex gap-3">
              <span className="mt-1 size-3 shrink-0" style={{ background: p.c }} />
              <p className="text-[14px] leading-[1.55] text-[#F4F1EC]/75"><b className="font-[650] text-[#F4F1EC]">{p.w[0].toUpperCase() + p.w.slice(1)}.</b> {p.body}</p>
            </div>
          ))}
        </div>
      </Tile>
      <Caption label="Plain, quick, local">
        Three words to check every line against. If a sentence isn't plain, cut the jargon. If it isn't quick, cut it in half. If it
        makes a privacy claim, make sure it's a fact about where the file goes.
      </Caption>

      <Sub n="7.1">Do and don't</Sub>
      <div className="grid gap-2 md:grid-cols-2">
        {PAIRS.map(([d, n]) => (
          <div key={d} className="grid grid-cols-2 gap-2">
            <Tile bg={C.lilac} fg={C.ink} className="flex min-h-[170px] flex-col justify-between gap-4 p-4"><Verdict ok /><p className="text-[17px] font-[560] leading-[1.3]">{d}</p></Tile>
            <Tile bg={C.ink2} className="flex min-h-[170px] flex-col justify-between gap-4 p-4"><Verdict ok={false} /><p className="text-[17px] leading-[1.3] text-[#F4F1EC]/60">{n}</p></Tile>
          </div>
        ))}
      </div>
      <Caption label="Specific beats cheerful">
        Name the file, name the format, name the folder. No exclamation marks, no emoji, no "oops". If something worked, say where it is.
      </Caption>

      <Sub n="7.2">Microcopy</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.orange} fg={C.ink} className="flex flex-col gap-2 p-5 md:col-span-5">
          <span className="bk-mono mb-2 text-[11px] uppercase tracking-[.08em] opacity-70">Toasts</span>
          <div className="flex flex-col items-start gap-2 text-[#F4F1EC]">
            <Toast>Converted. clip.gif · 4.1 MB</Toast>
            <Toast>Copied the path.</Toast>
            <Toast>Sent with AirDrop.</Toast>
            <Toast>Saved 12 JPGs to Desktop.</Toast>
            <Toast tone="err">Couldn't trim clip.mov. Details →</Toast>
          </div>
        </Tile>
        <Tile bg={C.ink} className="grid gap-2 p-2 ring-1 ring-inset ring-[#2A2A30] md:col-span-7 md:grid-cols-2">
          <Card kind="Error · what + fix" icon={<AlertTriangle size={12} />} title="Couldn't convert IMG_2041.heic.">
            It's still downloading from iCloud. Wait for it to finish, then drop it again.
          </Card>
          <Card kind="Error · what + fix" icon={<AlertTriangle size={12} />} title="No room for clip.mp4.">
            Your disk is full. Free up 1.2 GB, or pick another folder in Settings → General.
          </Card>
          <Card kind="Error · what + fix" icon={<AlertTriangle size={12} />} title="Can't save to Downloads.">
            macOS is blocking it. Open System Settings → Privacy → Files and Folders and turn on anyfmt.
          </Card>
          <Card kind="Error · what + fix" icon={<AlertTriangle size={12} />} title="No route from .pages to .mp3.">
            Those don't convert into each other. Try PDF or DOCX instead.
          </Card>
        </Tile>
        <Tile bg={C.ink2} className="flex flex-col gap-2 p-2 md:col-span-4">
          <Card kind="Empty state" icon={<Layers size={12} />} title="Nothing on the shelf.">
            Drag a file here, or press ⌃ while dragging and drop on Float. It'll wait here until you need it.
          </Card>
          <Card kind="Empty state" icon={<Layers size={12} />} title="No presets yet.">
            Right-click any wedge and choose Save as preset. It'll show up as a chip on the wheel.
          </Card>
        </Tile>
        <Tile bg={C.lilac} fg={C.ink} className="flex flex-col gap-3 p-5 md:col-span-4">
          <span className="bk-mono flex items-center gap-2 text-[11px] uppercase tracking-[.08em] opacity-70"><Lock size={12} />Permission asks</span>
          {[
            ['Notifications', 'So we can tell you when a long conversion finishes. Optional.'],
            ['Full Disk Access', 'So we can save into protected folders like Mail Downloads. Optional.'],
            ['Automation · Finder', 'So "Reveal" can select the new file for you. Optional.'],
          ].map(([t, b]) => (
            <div key={t} className="rounded-[6px] bg-[#F4F1EC] p-3"><div className="text-[14px] font-[650]">{t}</div><div className="text-[13.5px] leading-[1.4] opacity-80">{b}</div></div>
          ))}
        </Tile>
        <Tile bg={C.wine} className="flex flex-col justify-between gap-4 p-5 md:col-span-4">
          <span className="bk-mono flex items-center gap-2 text-[11px] uppercase tracking-[.08em] text-[#FF4FA0]"><Sparkles size={12} />Pro explainer</span>
          <p className="bk-display text-[28px] font-[640] leading-[1]">Everything local is free. <span className="text-[#FF4FA0]">Pro is for the server stuff.</span></p>
          <p className="text-[14px] leading-[1.5] text-[#F4F1EC]/75">$4 a month adds share links with expiry, cloud conversions for huge files, transcribe, upscale and HQ cut-outs, and preset sync across Macs. The 793 routes and 26 tools stay free and on your Mac.</p>
          <div className="flex items-center gap-2 text-[13px] text-[#F4F1EC]/60"><Copy size={13} />Key format: <span className="bk-mono">ANYFMT1-…</span></div>
        </Tile>
      </div>
      <Caption label="Errors have two halves">
        Every error says what went wrong, in one sentence, and how to fix it, in one more. Permission asks give one reason and say whether
        it's optional. The Pro explainer leads with what's free.
      </Caption>
    </Section>
  )
}
