import { IsoBlock, IsoScene } from '../Iso'
import { C, Caption, FitText, Section, Sub, Tile, Verdict } from './ui'

const SCALE = [
  { name: 'Display XXL', spec: '160 / 0.86 / −5%', size: 'text-[64px] md:text-[160px]', w: 680, sample: 'Drop.' },
  { name: 'Display XL', spec: '104 / 0.88 / −4.5%', size: 'text-[52px] md:text-[104px]', w: 640, sample: 'Any file.' },
  { name: 'H1', spec: '64 / 0.95 / −4%', size: 'text-[40px] md:text-[64px]', w: 640, sample: 'Press a key.' },
  { name: 'H2', spec: '40 / 1.0 / −3%', size: 'text-[30px] md:text-[40px]', w: 620, sample: 'A wheel opens around your pointer.' },
  { name: 'H3', spec: '28 / 1.1 / −2%', size: 'text-[24px] md:text-[28px]', w: 600, sample: 'Drop it on the format you want.' },
]

export function Type() {
  return (
    <Section id="type" num="05" title="Type" accent="." intro="Funnel Display, huge and tight, for anything you'd shout. Funnel Sans for reading. JetBrains Mono for small labels that explain.">
      <Sub n="5.1">Funnel Display</Sub>
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.orange} fg={C.ink} label="Funnel Display · 680" className="flex min-h-[340px] flex-col justify-end px-4 pb-2 pt-16 md:col-span-7 md:min-h-[460px]">
          <FitText className="bk-display font-[680] leading-[.8]"><span className="block pb-[.08em]">Drop.</span></FitText>
        </Tile>
        <Tile bg={C.cream} fg={C.ink} label="Error page" className="relative flex min-h-[340px] flex-col justify-end overflow-hidden px-4 pb-4 pt-16 md:col-span-5 md:min-h-[460px]">
          <div className="pointer-events-none absolute right-[-30px] top-[40px] w-[260px] opacity-100 md:w-[300px]">
            <IsoScene width={300} height={300} unit={44} anchor={[0.5, 0.7]}>
              {(ctx) => (<>
                <IsoBlock ctx={ctx} x={-1.5} y={-1.5} z={0} w={3} d={3} h={0.5} material="stripePink" />
                <IsoBlock ctx={ctx} x={-1} y={-1} z={0.5} w={2} d={2} h={0.5} material="lilac" />
                <IsoBlock ctx={ctx} x={-0.5} y={-0.5} z={1} w={1} d={1} h={0.5} material="orange" />
              </>)}
            </IsoScene>
          </div>
          <FitText className="bk-display relative font-[640] leading-[.8]"><span className="block pb-[.06em]">404</span></FitText>
          <p className="relative mt-3 text-[15px] font-[560]">That page didn't convert. <span className="text-[#D9500A]">Try the home page.</span></p>
        </Tile>
        <Tile bg={C.ink2} label="Character set" fg={C.cream} className="p-5 pt-14 md:col-span-12 md:p-8 md:pt-14">
          <div className="bk-display break-words text-[34px] font-[600] leading-[1.08] md:text-[56px]">
            Aa Bb Cc Dd Ee Ff Gg Hh Ii Jj Kk Ll Mm Nn Oo Pp Qq Rr Ss Tt Uu Vv Ww Xx Yy Zz
            <span className="text-[#FF6B1A]"> 0123456789</span> <span className="text-[#B8B3FF]">→ ← ↗ ⇧ ⌘ ⌃ & % . , : ;</span>
          </div>
          <div className="mt-6 flex flex-wrap gap-x-8 gap-y-2">
            {[300, 400, 500, 600, 700, 800].map((w) => (
              <span key={w} className="bk-display text-[24px] leading-none" style={{ fontWeight: w }}>anyfmt <span className="bk-mono text-[11px] font-normal text-[#8A8790]">{w}</span></span>
            ))}
          </div>
        </Tile>
      </div>
      <Caption label="Shout in Funnel Display">
        Display sizes are set solid (line height below 0.9) with tight tracking, so a word becomes a block. Words go full-width when they
        can. The "404", the name on a cover, a single verb: one giant moment per spread.
      </Caption>

      <Sub n="5.2">Scale</Sub>
      <Tile bg={C.ink} className="ring-1 ring-inset ring-[#2A2A30]">
        {SCALE.map((s) => (
          <div key={s.name} className="grid items-baseline gap-2 border-b border-[#2A2A30] px-5 py-5 last:border-b-0 md:grid-cols-[200px_1fr] md:px-8">
            <div className="bk-mono text-[11px] uppercase leading-[1.6] tracking-[.06em] text-[#8A8790]">{s.name}<br /><span className="text-[#F4F1EC]/60">{s.spec}</span></div>
            <div className={`bk-display ${s.size} overflow-hidden pb-[.12em] pt-[.04em] leading-[1] md:whitespace-nowrap`} style={{ fontWeight: s.w }}>{s.sample}</div>
          </div>
        ))}
        <div className="grid items-baseline gap-2 border-t border-[#2A2A30] px-5 py-5 md:grid-cols-[200px_1fr] md:px-8">
          <div className="bk-mono text-[11px] uppercase leading-[1.6] tracking-[.06em] text-[#8A8790]">Body L · Body<br /><span className="text-[#F4F1EC]/60">Funnel Sans 20 & 16 / 1.5</span></div>
          <div><p className="text-[20px] leading-[1.5]">Everything runs on your Mac. No account, no upload.</p><p className="mt-1 text-[16px] leading-[1.5] text-[#F4F1EC]/75">793 conversion routes, every one tested. Multi-hop routes are picked for quality.</p></div>
        </div>
        <div className="grid items-baseline gap-2 border-t border-[#2A2A30] px-5 py-5 md:grid-cols-[200px_1fr] md:px-8">
          <div className="bk-mono text-[11px] uppercase leading-[1.6] tracking-[.06em] text-[#8A8790]">Label<br /><span className="text-[#F4F1EC]/60">JetBrains Mono 12 / caps +6%</span></div>
          <div className="bk-mono text-[12px] uppercase tracking-[.06em] text-[#FF6B1A]">MOV → GIF · 15 fps · 4.1 MB</div>
        </div>
      </Tile>

      <div className="mt-2 grid gap-2 md:grid-cols-2">
        <Tile bg={C.cream} fg={C.ink} label="Funnel Sans · text" className="p-6 pt-14 md:p-8 md:pt-14">
          <p className="text-[22px] font-[500] leading-[1.35]">Drag a file in Finder. Press a key. A wheel of everything that file can become opens around your pointer. Drop.</p>
          <p className="mt-4 text-[15px] leading-[1.6] opacity-75">Funnel Sans shares Funnel Display's skeleton with opener spacing and lower contrast. Use it for paragraphs, UI and anything longer than a line. Regular 400 for reading, 560 for UI labels, italic for asides only.</p>
        </Tile>
        <Tile bg={C.ink2} label="JetBrains Mono · labels" fg={C.cream} className="flex flex-col justify-between gap-6 p-6 pt-14 md:p-8 md:pt-14">
          <div className="flex flex-wrap gap-2">
            {['HEIC → JPG', 'MOV → GIF', '⇧ CONVERT', '⌘ TOOLS', '⌃ ACTIONS', 'FIG. 1', '43 MS', 'ANYFMT1-…'].map((t, i) => (
              <span key={t} className="bk-tag" style={{ background: [C.orange, C.lilac, C.ink3, C.pink][i % 4], color: i % 4 === 2 ? C.cream : C.ink }}>{t}</span>
            ))}
          </div>
          <pre className="bk-mono overflow-x-auto rounded-[4px] bg-[#0E0E10] p-4 text-[12.5px] leading-[1.7] text-[#F4F1EC]/85">{`$ anyfmt convert clip.mov --to gif --fps 15
`}<span className="text-[#FF6B1A]">✓</span>{` clip.gif  4.1 MB  saved next to the original`}</pre>
          <p className="text-[14px] leading-[1.5] text-[#F4F1EC]/65">Mono is for labels, file names, routes, keys and code. Always small, often uppercase. It is the voice of the engineer annotating the drawing.</p>
        </Tile>
      </div>
      <Caption label="Three families, three jobs">
        Display shouts, Sans explains, Mono annotates. Don't swap their jobs: no mono headlines, no display paragraphs.
      </Caption>

      <Sub n="5.3">Two-tone headlines</Sub>
      <div className="grid gap-2 md:grid-cols-3">
        <Tile bg={C.cream} fg={C.ink} className="flex min-h-[260px] flex-col justify-between p-6">
          <Verdict ok />
          <p className="bk-display text-[44px] font-[650] leading-[.92]">Drag it. Press it. <span className="text-[#FF6B1A]">Drop it.</span></p>
          <span className="bk-mono text-[11px] uppercase opacity-60">Ink + orange · on cream</span>
        </Tile>
        <Tile bg={C.ink} className="flex min-h-[260px] flex-col justify-between p-6 ring-1 ring-inset ring-[#2A2A30]">
          <Verdict ok />
          <p className="bk-display text-[44px] font-[650] leading-[.92]">Every format. <span className="text-[#B8B3FF]">None of the uploading.</span></p>
          <span className="bk-mono text-[11px] uppercase text-[#8A8790]">Cream + lilac · on ink</span>
        </Tile>
        <Tile bg={C.ink2} className="flex min-h-[260px] flex-col justify-between p-6">
          <Verdict ok={false} />
          <p className="bk-display text-[44px] font-[650] leading-[.92]"><span className="text-[#FF4FA0]">Conv</span>ert <span className="text-[#B8B3FF]">any</span> <span className="text-[#FF6B1A]">file</span></p>
          <span className="bk-mono text-[11px] uppercase text-[#8A8790]">Three tones, split words</span>
        </Tile>
      </div>
      <Caption label="Two tones, one turn">
        A headline gets two colours at most. The second colour starts where the sentence turns: the payoff, the verb, the promise. Never
        split a word, never colour more than half the line.
      </Caption>
    </Section>
  )
}
