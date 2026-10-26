import type { DirectionMeta } from '../types'

export const meta: DirectionMeta = {
  id: 'cobalt',
  name: 'Cobalt',
  tagline: 'Loud, fast, kinetic. Conversion as a sport: drag, hit the key, take the wedge.',
  lineage: 'Full-bleed cobalt bands, a giant bleeding condensed wordmark',
  palette: [
    { name: 'Cobalt', hex: '#1F3BFF', role: 'The field' },
    { name: 'Ultramarine', hex: '#0B1A8C', role: 'Deep band' },
    { name: 'Flame', hex: '#FF6A2B', role: 'The hit. One per view' },
    { name: 'Ice', hex: '#E9EEFF', role: 'Ink on blue' },
    { name: 'Midnight', hex: '#050A2E', role: 'Surfaces, the app' },
  ],
  card: { bg: '#1F3BFF', fg: '#E9EEFF', accent: '#FF6A2B' },
  fonts: { display: 'Anton', text: 'Geist', mono: 'JetBrains Mono' },
  displayFamily: '"Anton", sans-serif',
  skin: {
    disc: 'radial-gradient(circle at 50% 50%, #0B1A8C 0%, #050A2E 72%)',
    discStyle: { boxShadow: '0 0 0 1px rgba(233,238,255,.14), 0 30px 80px -20px rgba(2,5,22,.9), inset 0 1px 0 rgba(233,238,255,.18)' },
    segment: 'linear-gradient(180deg, rgba(31,59,255,.55), rgba(11,26,140,.75))',
    segmentHover: 'linear-gradient(160deg, #FF8A4C 0%, #FF6A2B 45%, #E5470C 100%)',
    label: '#E9EEFF', labelHover: '#050A2E', labelClassName: 'font-anton text-[15px] uppercase tracking-[0.04em]',
    hub: '#050A2E', hubText: '#E9EEFF', hubStyle: { boxShadow: 'inset 0 0 0 1.5px rgba(233,238,255,.22)' },
    gap: 4, inner: 0.34, outer: 0.95, lift: 12, hoverRing: '#E9EEFF',
  },
}
