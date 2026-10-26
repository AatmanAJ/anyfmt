import { Check, Copy, Lock, TriangleAlert } from 'lucide-react'
import { FileTile, Lbl, Section, Sub } from './ui'

const PRINCIPLES = [
  ['Precise', 'Give the number, the name and the place. “Saved clip.gif to Desktop, 3.8 MB” beats “Done!”.'],
  ['Plain', 'Short words, active verbs, no jargon we wouldn’t say aloud. Say convert, not transcode.'],
  ['Local', 'Remind people their files stay on their Mac, once, where it matters. Never as a slogan.'],
  ['Quiet', 'No exclamation marks, no emoji, no hype. The highlight box does the shouting.'],
]

const PAIRS: [string, string][] = [
  ['Converted to GIF. clip.gif is on your Desktop.', 'Woohoo! Your file is ready!'],
  ['anyfmt couldn’t read this HEIC. It may be damaged; try opening it in Preview.', 'Oops, something went wrong.'],
  ['Runs on your Mac. Nothing is uploaded.', 'Military-grade privacy, powered by AI.'],
  ['Press Shift while you drag to open Convert.', 'Unlock the power of seamless file transformation.'],
  ['Pro adds share links and cloud conversions. Everything else is free.', 'Upgrade now to unlock all features!'],
]

function Toast({ icon, title, body, action }: { icon: React.ReactNode; title: string; body: string; action?: string }) {
  return (
    <div className="flex items-start gap-3 rounded-[8px] bg-white p-3 shb-hair-ink">
      <span className="mt-[1px]">{icon}</span>
      <div className="min-w-0 flex-1"><div className="text-[14px] font-[600]">{title}</div><div className="text-[13px] text-[var(--sh-graphite)]">{body}</div></div>
      {action && <button className="sh-btn sh-btn-ghost !h-[26px] !px-3 !text-[12px]">{action}</button>}
    </div>
  )
}

export function Voice() {
  return (
    <Section id="voice" n={7} label="Voice" title={<>Say what happened, <span className="sh-hl">then stop.</span></>}
      lede="anyfmt talks like a good reference page: exact, short and calm. It names files, formats and places, and when something breaks it says what and how to fix it.">
      <Sub n="7.1" title="Principles">
        <div className="grid gap-px overflow-hidden rounded-[4px] bg-[var(--shb-line)] md:grid-cols-4">
          {PRINCIPLES.map(([t, d], i) => (
            <div key={t} className="bg-white p-6">
              <span className="shb-num text-[12px] text-[var(--sh-graphite)]">0{i + 1}</span>
              <div className="sh-display mt-6 text-[34px]">{t}</div>
              <p className="mt-3 text-[15px] text-[var(--sh-graphite)]">{d}</p>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="7.2" title="Say this, not that">
        <div className="overflow-hidden rounded-[4px] shb-hair">
          <div className="grid grid-cols-2 border-b border-black bg-[var(--sh-slate)]"><span className="shb-lbl px-4 py-3">Say</span><span className="shb-lbl border-l border-[var(--shb-line)] px-4 py-3 text-[var(--sh-graphite)]">Not</span></div>
          {PAIRS.map(([a, b]) => (
            <div key={a} className="grid grid-cols-2 border-b border-[var(--shb-line)] last:border-0">
              <div className="flex gap-2 px-4 py-4 text-[15px]"><Check size={16} className="mt-[3px] flex-none" />{a}</div>
              <div className="border-l border-[var(--shb-line)] px-4 py-4 text-[15px] text-[var(--sh-graphite)] line-through decoration-[#686562]/50">{b}</div>
            </div>
          ))}
        </div>
      </Sub>

      <Sub n="7.3" title="Microcopy" note="Real strings from the app’s surfaces. Errors always carry a cause and a next step.">
        <div className="grid gap-4 md:grid-cols-2">
          <div className="rounded-[4px] bg-[var(--sh-lavender)] p-5">
            <Lbl className="!text-black">Toasts</Lbl>
            <div className="mt-4 grid gap-3">
              <Toast icon={<FileTile ext="GIF" size={22} />} title="Converted to GIF" body="clip.gif · 3.8 MB · saved next to clip.mov" action="Show" />
              <Toast icon={<FileTile ext="JPG" size={22} />} title="12 photos converted" body="Saved to ~/Pictures/trip as JPG, 80%" action="Show" />
              <Toast icon={<Check size={18} />} title="Path copied" body="/Users/sam/Desktop/clip.gif" />
            </div>
          </div>
          <div className="rounded-[4px] bg-[var(--sh-lavender)] p-5">
            <Lbl className="!text-black">Errors: what, why, what next</Lbl>
            <div className="mt-4 grid gap-3">
              <Toast icon={<TriangleAlert size={18} />} title="Couldn’t convert report.pages" body="Pages files need Pages installed to export. Install it from the App Store, or export to PDF from Pages first." action="Copy details" />
              <Toast icon={<TriangleAlert size={18} />} title="Not enough space on Macintosh HD" body="The MP4 needs about 2.1 GB and 1.4 GB is free. Empty the Bin or pick another folder." action="Choose…" />
              <Toast icon={<TriangleAlert size={18} />} title="Can’t write to this folder" body="anyfmt doesn’t have access to ~/Documents. Allow it in System Settings → Privacy → Files and Folders." action="Open" />
            </div>
          </div>
          <div className="rounded-[4px] bg-[var(--sh-slate)] p-5">
            <Lbl className="!text-black">Empty states</Lbl>
            <div className="mt-4 grid gap-3">
              <div className="rounded-[8px] bg-white p-5 text-center shb-hair">
                <div className="sh-display text-[20px]">The shelf is empty</div>
                <p className="mx-auto mt-1 max-w-[300px] text-[13px] text-[var(--sh-graphite)]">Drag a file, press Control and drop it on Float. It waits here until you drag it somewhere else.</p>
              </div>
              <div className="rounded-[8px] bg-white p-5 text-center shb-hair">
                <div className="sh-display text-[20px]">No presets yet</div>
                <p className="mx-auto mt-1 max-w-[300px] text-[13px] text-[var(--sh-graphite)]">Convert once with the options you like, then choose Save as preset. It shows up as a chip on the wheel.</p>
              </div>
              <div className="rounded-[8px] bg-white p-5 text-center shb-hair">
                <div className="sh-display text-[20px]">Nothing converted yet</div>
                <p className="mx-auto mt-1 max-w-[300px] text-[13px] text-[var(--sh-graphite)]">Your last ten conversions will be listed here, with the folder each one went to.</p>
              </div>
            </div>
          </div>
          <div className="grid gap-4">
            <div className="rounded-[4px] bg-[var(--sh-slate)] p-5">
              <Lbl className="!text-black">Permission ask</Lbl>
              <div className="mt-4 rounded-[8px] bg-white p-4 shb-hair">
                <div className="flex items-center gap-2 text-[15px] font-[600]"><Lock size={15} />Open the wheel with Return in Finder?</div>
                <p className="mt-1 text-[13px] text-[var(--sh-graphite)]">Optional. macOS calls this Accessibility and Input Monitoring. anyfmt watches only for Return on a selected Finder file and never reads what you type. Dragging works without it.</p>
                <div className="mt-3 flex gap-2"><button className="sh-btn sh-btn-ink !h-8 !px-4 !text-[14px]">Open System Settings</button><button className="sh-btn sh-btn-ghost !h-8 !px-4 !text-[14px]">Not now</button></div>
              </div>
            </div>
            <div className="rounded-[4px] p-5" style={{ background: 'var(--sh-cream)' }}>
              <Lbl className="!text-black">The Pro explainer</Lbl>
              <p className="sh-display mt-3 text-[22px]">Everything on your Mac is free. Pro pays for the servers.</p>
              <p className="mt-2 text-[14px] text-[var(--sh-graphite)]">$4 a month adds share links that expire, cloud conversions for files too big for your Mac, transcription and upscaling, and presets synced across Macs. Cancel any time; nothing local changes.</p>
              <div className="mt-3 flex items-center gap-2 text-[13px]"><Copy size={13} /><span className="sh-code">ANYFMT1-…</span><span className="text-[var(--sh-graphite)]">keys work offline</span></div>
            </div>
          </div>
        </div>
      </Sub>
    </Section>
  )
}
