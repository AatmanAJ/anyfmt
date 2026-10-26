import type { DirectionMeta } from '../types'

export const meta: DirectionMeta = {
  id: 'signal',
  name: 'Signal',
  tagline: 'A dark instrument. Every file is a signal, the wheel is the tuner.',
  lineage: 'Dot-matrix LED field, editorial serif on black',
  palette: [
    { name: 'Solar', hex: '#D7FF3A', role: 'The lit wedge. Selection, primary action' },
    { name: 'Void', hex: '#050506', role: 'Canvas' },
    { name: 'Carbon', hex: '#111113', role: 'Surfaces, wedges at rest' },
    { name: 'Graphite', hex: '#2A2A2E', role: 'Hairlines' },
    { name: 'Ash', hex: '#8E8E88', role: 'Labels, secondary text' },
    { name: 'Bone', hex: '#EDEDE6', role: 'Text' },
  ],
  card: { bg: '#050506', fg: '#EDEDE6', accent: '#D7FF3A' },
  fonts: { display: 'Instrument Serif', text: 'Geist', mono: 'JetBrains Mono' },
  displayFamily: '"Instrument Serif", serif',
  skin: {
    disc: 'radial-gradient(circle, #111113 0%, #050506 72%)',
    discStyle: { boxShadow: '0 0 0 1px #2A2A2E, 0 30px 80px -24px rgba(215,255,58,.22)' },
    segment: 'radial-gradient(circle at 50% 50%, #1d1d21 30%, #111113 70%)',
    segmentHover: 'radial-gradient(circle at 50% 50%, #ecff8c 22%, #D7FF3A 55%, #c2ec1c 100%)',
    label: '#8E8E88', labelHover: '#050506',
    labelClassName: 'font-mono text-[11px] font-semibold uppercase tracking-[0.12em]',
    hub: '#050506', hubText: '#EDEDE6', hubStyle: { boxShadow: 'inset 0 0 0 1px #2A2A2E' },
    gap: 4, inner: 0.36, outer: 0.9, lift: 5,
  },
}
