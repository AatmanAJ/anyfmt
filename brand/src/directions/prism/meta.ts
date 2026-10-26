import type { DirectionMeta } from '../types'

export const meta: DirectionMeta = {
  id: 'prism',
  name: 'Prism',
  tagline: 'Pearl glass that catches light. Native, soft, a little magic.',
  lineage: 'Lavender glass SaaS meets the frosted macOS wheel',
  palette: [
    { name: 'Coral', hex: '#FF6B8B', role: 'Warm refraction' },
    { name: 'Lilac', hex: '#B9A7FF', role: 'Mid refraction, glow' },
    { name: 'Aqua', hex: '#5EE7DF', role: 'Cool refraction' },
    { name: 'Pearl', hex: '#F6F4FB', role: 'Canvas' },
    { name: 'Plum', hex: '#1C1530', role: 'Ink' },
    { name: 'Iris', hex: '#6B4EFF', role: 'Links, focus' },
  ],
  card: { bg: '#F6F4FB', fg: '#1C1530', accent: '#FF6B8B' },
  fonts: { display: 'Inter Display', text: 'Inter', mono: 'JetBrains Mono' },
  displayFamily: '"Inter Variable", sans-serif',
  skin: {
    disc: 'radial-gradient(circle at 30% 15%, rgba(255,255,255,.85), rgba(240,235,252,.55) 55%, rgba(225,216,248,.5))',
    discStyle: { backdropFilter: 'blur(26px) saturate(190%)', boxShadow: 'inset 0 1.5px 0 #fff, inset 0 0 0 1px rgba(255,255,255,.7), 0 40px 80px -30px rgba(44,30,90,.5)' },
    segment: 'linear-gradient(180deg, rgba(255,255,255,.86), rgba(255,255,255,.55))',
    segmentHover: 'conic-gradient(from 200deg, #FF6B8B, #B9A7FF 40%, #5EE7DF 75%, #FF6B8B)',
    label: '#3A3152', labelHover: '#1C1530', labelClassName: 'font-sans text-[13px] font-semibold uppercase',
    hub: 'radial-gradient(circle at 35% 25%, #fff, rgba(255,255,255,.72))', hubText: '#1C1530',
    hubStyle: { boxShadow: 'inset 0 1px 0 #fff, 0 6px 18px -8px rgba(44,30,90,.35)' },
    gap: 6, inner: 0.37, lift: 6,
  },
}
