import type { DirectionMeta } from '../types'

export const meta: DirectionMeta = {
  id: 'grid',
  name: 'Grid',
  tagline: 'Swiss precision. A tool that tells you exactly what it does.',
  lineage: 'Swiss International style: off-white sheet, black type, one red, giant glyphs, a visible 12-column grid',
  palette: [
    { name: 'Vermilion', hex: '#FF3D2E', role: 'The one colour: the armed wedge' },
    { name: 'Sheet', hex: '#F4F4F1', role: 'Canvas' },
    { name: 'White', hex: '#FFFFFF', role: 'Surfaces' },
    { name: 'Rule', hex: '#D6D6D0', role: 'Grid lines' },
    { name: 'Black', hex: '#0B0B0B', role: 'Type, the wheel disc' },
    { name: 'Ink 2', hex: '#5C5C56', role: 'Captions, indices' },
  ],
  card: { bg: '#F4F4F1', fg: '#0B0B0B', accent: '#FF3D2E' },
  fonts: { display: 'Space Grotesk', text: 'Inter', mono: 'JetBrains Mono' },
  displayFamily: '"Space Grotesk Variable", sans-serif',
  skin: {
    disc: '#0B0B0B',
    segment: '#F4F4F1', segmentHover: '#FF3D2E',
    label: '#0B0B0B', labelHover: '#0B0B0B', labelClassName: 'font-grotesk text-[13px] font-bold uppercase tracking-tight',
    hub: '#0B0B0B', hubText: '#F4F4F1',
    gap: 3, inner: 0.33, outer: 0.95, lift: 0,
  },
}
