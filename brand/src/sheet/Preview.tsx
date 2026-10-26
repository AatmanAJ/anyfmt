import { AppIcon, Mark, Pixels, Wordmark } from './Mark'
import { SheetWheel } from './SheetWheel'
import './sheet.css'

const W = ['GIF', 'MP4', 'WEBM', 'M4V', 'MP3', 'PNG'].map((l) => ({ id: l, label: l, sub: '4.1 MB' }))

/** Scratch page for checking the foundation pieces. */
export default function Preview() {
  return (
    <div className="sh min-h-screen p-10">
      <div className="flex flex-wrap items-end gap-10">
        <Mark size={128} /><Mark size={48} /><Mark size={16} />
        <AppIcon size={120} /><AppIcon size={120} dark /><AppIcon size={32} />
        <Wordmark size={44} />
      </div>
      <h1 className="sh-display mt-10 max-w-[900px] text-[45px]">Convert any file <span className="sh-hl">in the middle</span> of a drag.</h1>
      <p className="sh-mono mt-4 text-[var(--sh-graphite)]">793 routes · 0 network calls · 43 ms</p>
      <div className="mt-4 flex gap-3"><button className="sh-btn sh-btn-ink">Download for Mac</button><button className="sh-btn sh-btn-ghost">Copy command</button></div>
      <div className="mt-8 flex flex-wrap gap-6">
        <div className="sh-card bg-[var(--sh-mist)] sh-dots"><SheetWheel size={300} active={0} wedges={W} hub={<b>MOV</b>} /></div>
        <div className="sh-card bg-black"><SheetWheel size={300} active={2} tone="dark" wedges={W} hub={<b>MOV</b>} /></div>
        <div className="sh-card bg-[var(--sh-sky)]">
          <Pixels px={10} palette={{ g: '#2FB36B', y: '#FFD23F', o: '#FF4500', k: '#000' }} rows={[
            '..........o.........', '.........ooo........', '....y...ooooo.......', '...yyy.ookoooo...g..',
            '..yyyyyookkkooo.ggg.', '.yyyykyyokkkkoogggg.', 'yyykkkyykkkkkkggkggg', 'ggkkkkkgkkkkkkgkkkgg',
          ]} />
        </div>
      </div>
    </div>
  )
}
