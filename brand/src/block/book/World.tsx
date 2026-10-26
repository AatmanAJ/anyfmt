import { ArrowLeft, ArrowRight, Lock, Plus, RotateCw, X } from 'lucide-react'
import { IsoBlock, IsoLeftText, IsoScene, IsoTop } from '../Iso'
import { AppIcon, Mark } from '../Mark'
import { MarkCubes, pt } from './isoBits'
import { C, Caption, FitText, Scaled, Section, Tile } from './ui'

function Monitor() {
  return (
    <div className="relative mx-auto flex w-full max-w-[560px] flex-col items-center">
      <div className="w-full rounded-[14px] bg-[#0E0E10] p-[10px] shadow-[8px_8px_0_#3A0E1E]">
        <div className="grid aspect-[16/9] place-items-center rounded-[6px] bg-[#1C1C21]">
          <div className="flex items-center gap-4"><Mark size={92} /><span className="bk-display text-[56px] font-[650] leading-none text-[#F4F1EC] max-md:text-[34px]">anyfmt</span></div>
        </div>
      </div>
      <div className="h-[56px] w-[64px] bg-[#0E0E10]" />
      <div className="h-[10px] w-[200px] rounded-t-[4px] bg-[#0E0E10]" />
    </div>
  )
}

function Server() {
  return (
    <IsoScene width={620} height={460} unit={62} anchor={[0.52, 0.56]} title="A small server box with an orange cable">
      {(ctx) => {
        const port = pt(ctx, 1.9, 1.2, 0.55)
        const end = [port[0] - 300, port[1] + 160]
        return (
          <>
            <IsoBlock ctx={ctx} x={-1.6} y={-1.6} z={-0.1} w={3.8} d={2.8} h={0.1} material={{ top: '#C9C4BB', left: '#B5B0A6', right: '#A39E95' }} />
            <IsoBlock ctx={ctx} x={-1.4} y={-1.4} z={0} w={3.4} d={2.6} h={1.5} material="cream" />
            <IsoTop ctx={ctx} x={-1.4} y={-1.4} z={1.5} size={1}>
              {Array.from({ length: 12 * 9 }, (_, i) => <circle key={i} cx={20 + (i % 12) * 26} cy={20 + Math.floor(i / 12) * 26} r={6} fill="#CFCAC1" />)}
            </IsoTop>
            {/* label plate on the front face */}
            <IsoBlock ctx={ctx} x={-1.1} y={1.2} z={0.75} w={1.6} d={0.03} h={0.5} material="orange" />
            <IsoLeftText ctx={ctx} x={-1.0} y={1.23} z={0.87} size={20} weight={700} fill={C.ink}>anyfmt</IsoLeftText>
            {[0, 1, 2, 3].map((i) => <IsoBlock key={i} ctx={ctx} x={1.0 + i * 0.22} y={1.2} z={0.3} w={0.12} d={0.03} h={0.12} material={i === 0 ? 'orange' : 'ink'} />)}
            {/* the cable */}
            <path d={`M${port[0]},${port[1]} C${port[0] + 40},${port[1] + 90} ${end[0] + 220},${end[1] - 30} ${end[0]},${end[1]}`} fill="none" stroke={C.orangeLo} strokeWidth={13} strokeLinecap="round" />
            <path d={`M${port[0]},${port[1]} C${port[0] + 40},${port[1] + 90} ${end[0] + 220},${end[1] - 30} ${end[0]},${end[1]}`} fill="none" stroke={C.orange} strokeWidth={9} strokeLinecap="round" />
            <IsoBlock ctx={ctx} x={1.78} y={1.2} z={0.42} w={0.26} d={0.18} h={0.24} material="orange" />
          </>
        )
      }}
    </IsoScene>
  )
}

function ReportCover() {
  return (
    <div className="mx-auto aspect-[3/4] w-full max-w-[400px] overflow-hidden rounded-[3px] bg-[#F4F1EC] text-[#0E0E10] shadow-[10px_10px_0_#0E0E10]">
      <div className="flex h-full flex-col">
        <div className="flex items-start justify-between p-5">
          <div><span className="mb-3 block h-1.5 w-10 bg-[#FF6B1A]" /><div className="bk-display text-[34px] font-[660] leading-[.9]">Field<br />Report</div></div>
          <div className="bk-mono text-right text-[10px] uppercase leading-[1.5]">anyfmt<br />2026</div>
        </div>
        <div className="relative mt-auto">
          <IsoScene width={400} height={330} unit={34} anchor={[0.5, 0.55]}>
            {(ctx) => (<>
              {[0, 1, 2, 3].map((i) => (
                <IsoBlock key={i} ctx={ctx} x={-2.2} y={-3 + i * 1.5} z={0} w={3} d={1.3} h={1 + (3 - i) * 0.9} material={(['stripeLilac', 'stripePink', 'stripeOrange', 'stripePink'] as const)[i]} />
              ))}
              <IsoBlock ctx={ctx} x={-1.05} y={-2.65} z={1 + 2.7} w={0.7} d={0.7} h={0.7} material="orange" />
            </>)}
          </IsoScene>
        </div>
        <div className="bk-mono flex justify-between border-t border-[#0E0E10]/15 px-5 py-3 text-[10px] uppercase"><span>How files move on a Mac</span><span>01</span></div>
      </div>
    </div>
  )
}

function StatTile() {
  return (
    <div className="mx-auto flex aspect-[4/5] w-full max-w-[360px] flex-col overflow-hidden rounded-[10px] bg-[#0E0E10] text-[#F4F1EC] ring-1 ring-[#2C2C33]">
      <div className="flex items-center gap-2 px-4 pt-4"><Mark size={20} /><span className="text-[13px] font-[650]">anyfmt</span><span className="bk-mono ml-auto text-[10px] text-[#8A8790]">@anyfmt</span></div>
      <div className="bk-display px-4 pt-5 text-[76px] font-[680] leading-[.82]">793<br /><span className="text-[#FF6B1A]">routes.</span></div>
      <div className="relative mt-auto h-[38%]">
        <div className="absolute inset-0 bkb-dots-orange [mask-image:linear-gradient(to_top,#000_30%,transparent)]" />
      </div>
      <div className="flex items-center justify-between bg-[#F4F1EC] px-4 py-3 text-[#0E0E10]">
        <span className="text-[13px] font-[650] leading-[1.2]">Every one tested.<br /><span className="font-[500] opacity-70">All of them local and free.</span></span>
        <span className="bk-display text-[30px] font-[700]">Aa</span>
      </div>
    </div>
  )
}

function Page404() {
  return (
    <div className="w-full overflow-hidden rounded-[10px] bg-[#0E0E10] p-[8px] shadow-[8px_8px_0_#561629]">
      <div className="relative overflow-hidden rounded-[5px] bg-[#F4F1EC] text-[#0E0E10]">
        <div className="flex items-center justify-between border-b border-[#0E0E10]/10 px-4 py-2.5">
          <span className="flex items-center gap-2"><Mark size={18} variant="flat" /><b className="bk-display text-[15px]">anyfmt</b></span>
          <span className="bk-btn bk-btn-ink !h-[26px] !px-2.5 !text-[11px] !shadow-[2px_2px_0_#FF6B1A]">Download</span>
        </div>
        <div className="relative px-6 pb-6 pt-6">
          <p className="relative z-10 text-center text-[14px] font-[600]">That page didn't convert.</p>
          <div className="relative z-10"><FitText className="bk-display text-center font-[650] leading-[.85]"><span className="block">404</span></FitText></div>
          <div className="pointer-events-none absolute right-[8%] top-[18%] w-[30%]">
            <IsoScene width={200} height={220} unit={36} anchor={[0.5, 0.75]}>
              {(ctx) => (<>{[0, 1, 2].map((i) => <IsoBlock key={i} ctx={ctx} x={-1.2 + i * 0.8} y={-0.6} z={0} w={0.8} d={1.2} h={1 + i} material={i === 2 ? 'stripePink' : 'lilac'} />)}</>)}
            </IsoScene>
          </div>
          <div className="relative z-10 mt-2 flex justify-center"><span className="bk-btn bk-btn-orange !h-[34px] !text-[13px]">Back to the home page</span></div>
        </div>
      </div>
    </div>
  )
}

function Phone() {
  const tiles = ['#5B8DEF', '#3FBF6A', '#F6C443', '#F2545B', '#8E8E96', '#1E1E22', '#B8B3FF', '#FFFDF4', '#5B8DEF', '#F2545B', '#3FBF6A', '#8E8E96', '#F6C443', '#1E1E22', '#B8B3FF']
  return (
    <div className="mx-auto w-[230px] rounded-[38px] bg-[#0E0E10] p-[9px] shadow-[8px_8px_0_#561629]">
      <div className="relative overflow-hidden rounded-[30px] bg-[#3A0E1E] px-4 pb-6 pt-10">
        <div className="absolute left-1/2 top-2.5 h-[20px] w-[70px] -translate-x-1/2 rounded-full bg-[#0E0E10]" />
        <div className="absolute inset-0 bk-stripe-pink opacity-25" />
        <div className="relative grid grid-cols-4 gap-x-3 gap-y-4">
          {tiles.slice(0, 9).map((c, i) => <div key={i} className="flex flex-col items-center gap-1"><div className="size-[38px] rounded-[10px]" style={{ background: c }} /><span className="h-[4px] w-[26px] rounded-full bg-white/30" /></div>)}
          <div className="flex flex-col items-center gap-1"><AppIcon size={38} /><span className="text-[8.5px] font-[600] text-white">anyfmt</span></div>
          {tiles.slice(9, 14).map((c, i) => <div key={i} className="flex flex-col items-center gap-1"><div className="size-[38px] rounded-[10px]" style={{ background: c }} /><span className="h-[4px] w-[26px] rounded-full bg-white/30" /></div>)}
        </div>
        <div className="relative mt-8 flex justify-around rounded-[20px] bg-white/20 p-2.5">
          {['#3FBF6A', '#5B8DEF', '#F2545B'].map((c) => <div key={c} className="size-[38px] rounded-[10px]" style={{ background: c }} />)}
          <AppIcon size={38} />
        </div>
      </div>
    </div>
  )
}

function Conference() {
  return (
    <div className="relative overflow-hidden rounded-[6px] bg-[#0E0E10]" style={{ width: 1000, height: 520 }}>
      <div className="absolute inset-0 bkb-dots opacity-40" />
      <div className="absolute left-1/2 top-[40px] h-[300px] w-[560px] -translate-x-1/2 overflow-hidden bg-[#FF6B1A]">
        <div className="flex h-full flex-col justify-between p-6 text-[#0E0E10]">
          <div className="bk-mono flex justify-between text-[11px] uppercase"><span>anyfmt</span><span>Keynote · 01</span></div>
          <div className="bk-display text-[64px] font-[680] leading-[.86]">Drag. Press.<br /><span className="text-[#F4F1EC]">Drop.</span></div>
        </div>
        <div className="absolute right-2 top-8 w-[150px]">
          <IsoScene width={220} height={200} unit={42} anchor={[0.5, 0.62]}>{(ctx) => <MarkCubes ctx={ctx} x={-1} y={-1} z={0} rest="ink" hot="cream" lift={0.9} />}</IsoScene>
        </div>
      </div>
      {/* side screens */}
      <div className="absolute left-[40px] top-[90px] h-[160px] w-[140px] bg-[#B8B3FF] p-3"><div className="bk-display text-[30px] font-[680] leading-[.9] text-[#0E0E10]">0<br /><span className="text-[14px] font-[600]">network calls</span></div></div>
      <div className="absolute right-[40px] top-[90px] h-[160px] w-[140px] bk-stripe-pink" />
      {/* stage */}
      <div className="absolute bottom-[150px] left-[180px] right-[180px] h-[14px] bg-[#2C2C33]" />
      <div className="absolute bottom-[164px] left-[470px] h-[46px] w-[30px] rounded-t-[14px] bg-[#1C1C21]" />
      <div className="absolute bottom-[200px] left-[476px] size-[18px] rounded-full bg-[#2C2C33]" />
      {/* audience */}
      <div className="absolute inset-x-0 bottom-0 h-[150px]">
        {[0, 1, 2].map((row) => (
          <div key={row} className="absolute inset-x-0 flex justify-center gap-[14px]" style={{ bottom: row * 46 - 20 + (row === 0 ? 0 : 0), opacity: 1 - row * 0.12, transform: `translateX(${row % 2 ? 22 : 0}px)` }}>
            {Array.from({ length: 22 - row * 2 }, (_, i) => (
              <div key={i} className="flex flex-col items-center">
                <span className="size-[26px] rounded-full" style={{ background: row === 0 ? '#2C2C33' : '#1C1C21' }} />
                <span className="-mt-[2px] h-[40px] w-[52px] rounded-t-[22px]" style={{ background: row === 0 ? '#2C2C33' : '#1C1C21' }} />
              </div>
            )).reverse()}
          </div>
        )).reverse()}
      </div>
    </div>
  )
}

function Browser() {
  return (
    <div className="overflow-hidden rounded-[10px] bg-[#1C1C21] ring-1 ring-[#2C2C33]" style={{ width: 1000, height: 560 }}>
      <div className="flex h-[42px] items-end gap-1 px-3 pt-2">
        <div className="mb-2.5 mr-3 flex gap-[7px]">{['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <span key={c} className="size-[11px] rounded-full" style={{ background: c }} />)}</div>
        <div className="flex h-[34px] w-[240px] items-center gap-2 rounded-t-[8px] bg-[#2C2C33] px-3 text-[12.5px] font-[560] text-[#F4F1EC]">
          <span className="grid size-[16px] place-items-center rounded-[4px] bg-[#FF6B1A] text-[#0E0E10]"><svg width="11" height="11" viewBox="0 0 18 18" fill="currentColor"><rect x="1" y="10.5" width="6.5" height="6.5" rx="1" /><rect x="9" y="10.5" width="6.5" height="6.5" rx="1" /><rect x="1" y="2.5" width="6.5" height="6.5" rx="1" /><rect x="10.5" y="1" width="6.5" height="6.5" rx="1" /></svg></span>
          <span className="truncate">anyfmt · any file, any format</span><X size={12} className="ml-auto opacity-60" />
        </div>
        <div className="flex h-[34px] w-[200px] items-center gap-2 px-3 text-[12.5px] text-[#8A8790]"><span className="size-[14px] rounded-[3px] bg-[#3A3A42]" /><span className="truncate">New Tab</span></div>
        <Plus size={14} className="mb-2.5 text-[#8A8790]" />
      </div>
      <div className="flex h-[44px] items-center gap-3 bg-[#2C2C33] px-3 text-[#8A8790]">
        <ArrowLeft size={15} /><ArrowRight size={15} /><RotateCw size={14} />
        <div className="flex h-[30px] flex-1 items-center gap-2 rounded-[6px] bg-[#0E0E10] px-3 text-[13px]"><Lock size={12} /><span className="text-[#F4F1EC]">anyfmt.app</span></div>
      </div>
      <div className="relative h-[474px] overflow-hidden bg-[#FF6B1A] text-[#0E0E10]">
        <div className="flex items-center justify-between px-8 py-5">
          <span className="flex items-center gap-2"><Mark size={26} variant="icon" /><b className="bk-display text-[20px]">anyfmt</b></span>
          <span className="flex items-center gap-6 text-[14px] font-[560]"><span>Features</span><span>Pricing</span><span>Docs</span><span className="bk-btn bk-btn-ink !h-[36px] !px-4 !text-[14px]">Download</span></span>
        </div>
        <div className="px-8 pt-6">
          <div className="bk-display max-w-[12ch] text-[60px] font-[660] leading-[.9]">Any file. Any format. <span className="text-[#F4F1EC]">Mid‑drag.</span></div>
        </div>
        <div className="absolute -bottom-6 right-6 w-[420px]">
          <IsoScene width={420} height={360} unit={60} anchor={[0.5, 0.6]}>
            {(ctx) => (<>
              <IsoBlock ctx={ctx} x={-2.2} y={-2.2} z={-1.1} w={4.4} d={4.4} h={0.5} material="stripePink" />
              <IsoBlock ctx={ctx} x={-1.6} y={-1.6} z={-0.6} w={3.2} d={3.2} h={0.5} material="ink" />
              <MarkCubes ctx={ctx} x={-1} y={-1} z={-0.1} rest="lilac" hot="cream" lift={0.9} />
            </>)}
          </IsoScene>
        </div>
      </div>
    </div>
  )
}

export function World() {
  return (
    <Section id="world" num="11" title="In the" accent=" world." intro="How the system holds up away from the app: on a desk, on hardware, on paper, on a feed and on a stage. All mockups are drawn in CSS and SVG.">
      <div className="grid gap-2 md:grid-cols-12">
        <Tile bg={C.orange} fg={C.ink} label="Desk" className="relative flex min-h-[420px] flex-col justify-end overflow-hidden md:col-span-12 md:min-h-[560px]">
          <div className="relative z-10 px-6 pt-14"><Monitor /></div>
          <div className="relative h-[60px] bg-[#0E0E10]">
            <div className="absolute -top-[22px] left-[12%] h-[22px] w-[34%] max-w-[300px] rounded-t-[6px] bg-[#2C2C33]" />
            <div className="absolute -top-[30px] right-[14%] h-[30px] w-[26px] rounded-t-[4px] bg-[#B8B3FF]" />
            <div className="absolute -top-[12px] right-[24%] h-[12px] w-[60px] rounded-t-[10px] bg-[#1C1C21]" />
          </div>
        </Tile>
        <Tile bg="#E4E0D8" fg={C.ink} label="Hardware" className="grid min-h-[400px] place-items-center px-2 pt-10 md:col-span-7">
          <div className="w-full max-w-[620px]"><Server /></div>
        </Tile>
        <Tile bg={C.wine} label="Report cover" fg={C.cream} className="grid min-h-[400px] place-items-center px-6 pb-10 pt-14 md:col-span-5">
          <ReportCover />
        </Tile>
        <Tile bg={C.lilac} fg={C.ink} label="Social" className="grid place-items-center px-6 pb-10 pt-14 md:col-span-4">
          <StatTile />
        </Tile>
        <Tile bg={C.orange} fg={C.ink} label="404" className="grid place-items-center px-5 pb-10 pt-14 md:col-span-5">
          <Page404 />
        </Tile>
        <Tile bg={C.ink2} label="Phone tile" fg={C.cream} className="grid place-items-center px-5 pb-10 pt-14 md:col-span-3">
          <Phone />
        </Tile>
        <Tile bg={C.ink} label="Conference" fg={C.cream} className="px-3 pb-4 pt-12 ring-1 ring-inset ring-[#2A2A30] md:col-span-12 md:px-6">
          <Scaled w={1000} h={520}><Conference /></Scaled>
        </Tile>
        <Tile bg={C.cream} label="anyfmt.app" fg={C.ink} className="px-3 pb-4 pt-12 md:col-span-12 md:px-6">
          <Scaled w={1000} h={560}><Browser /></Scaled>
        </Tile>
      </div>
      <Caption label="Same blocks, everywhere">
        The orange block, the lifted cube, the stripes and the giant type carry across every surface. If a placement can only fit one
        thing, it's the mark on orange.
      </Caption>
    </Section>
  )
}
