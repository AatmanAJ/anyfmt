import { AppIcon, Mark, Wordmark } from './Mark'
import { IsoBlock, IsoKeycap, IsoScene } from './Iso'
import { BlockWheel } from './BlockWheel'
import './block.css'

/** Scratch page for checking the foundation pieces. */
export default function Preview() {
  return (
    <div className="bk min-h-screen p-10">
      <div className="flex flex-wrap items-end gap-10">
        <Mark size={160} />
        <Mark size={64} />
        <Mark size={24} />
        <span className="text-[#FF6B1A]"><Mark size={64} variant="mono" /></span>
        <div className="rounded-xl bg-[#F4F1EC] p-4"><Mark size={64} variant="reverse" /></div>
        <AppIcon size={128} />
        <AppIcon size={32} />
        <Wordmark size={40} />
      </div>
      <div className="mt-8 flex gap-8">
        <BlockWheel size={300} active={0} wedges={['GIF','MP4','WEBM','M4V','MP3','PNG'].map((l) => ({ id: l, label: l, sub: '4.1 MB' }))} hub={<b>MOV</b>} />
        <div className="bg-[#F4F1EC] p-4"><BlockWheel size={300} active={2} tone="light" hot="lilac" wedges={['GIF','MP4','WEBM','M4V','MP3','PNG'].map((l) => ({ id: l, label: l }))} hub={<b>MOV</b>} /></div>
      </div>
      <div className="mt-10 grid grid-cols-2 gap-6">
        <div className="bg-[#3A0E1E]">
          <IsoScene width={520} height={340} unit={46}>
            {(ctx) => (<>
              <IsoBlock ctx={ctx} x={-2} y={-1} z={0} w={3} d={3} h={0.6} material="stripePink" />
              <IsoBlock ctx={ctx} x={-1.5} y={-0.5} z={0.6} w={2} d={2} h={0.6} material="lilac" />
              <IsoBlock ctx={ctx} x={-1} y={0} z={1.2} w={1} d={1} h={0.6} material="orange" />
            </>)}
          </IsoScene>
        </div>
        <div className="bg-[#FF6B1A]">
          <IsoScene width={520} height={340} unit={70}>
            {(ctx) => (<>
              <IsoKeycap ctx={ctx} x={-1.6} y={0} legend="⇧" sub="shift" />
              <IsoKeycap ctx={ctx} x={-0.5} y={0} legend="⌘" sub="cmd" pressed material="lilac" />
              <IsoKeycap ctx={ctx} x={0.6} y={0} legend="⌃" sub="ctrl" material="stripeLilac" />
            </>)}
          </IsoScene>
        </div>
      </div>
    </div>
  )
}
