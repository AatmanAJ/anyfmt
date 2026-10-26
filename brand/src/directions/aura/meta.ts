import type { DirectionMeta } from '../types'

export const meta: DirectionMeta = {
  id: 'aura',
  name: 'Aura',
  tagline: 'Warm paper, soft light. The calm, human take on a power tool.',
  lineage: 'Cream paper, a soft friendly serif, an apricot-to-periwinkle glow',
  palette: [
    { name: 'Apricot', hex: '#FFB27A', role: 'Warm light: glow, hovered wedge' },
    { name: 'Periwinkle', hex: '#9DB4FF', role: 'Cool light: far side of the halo' },
    { name: 'Paper', hex: '#FBF7F0', role: 'Canvas' },
    { name: 'Linen', hex: '#F1EADF', role: 'Quiet surfaces' },
    { name: 'Ink', hex: '#1E1B18', role: 'Text, primary buttons' },
    { name: 'Ember', hex: '#B04E1B', role: 'Apricot, readable: links, labels' },
  ],
  card: { bg: '#FBF7F0', fg: '#1E1B18', accent: '#FFB27A' },
  fonts: { display: 'Fraunces (opsz, SOFT, WONK)', text: 'Inter', mono: 'JetBrains Mono' },
  displayFamily: '"Fraunces Variable", serif',
  skin: {
    disc: 'radial-gradient(circle at 35% 25%, rgba(255,255,255,.95), rgba(255,250,243,.78) 55%, rgba(250,240,228,.7))',
    discStyle: { boxShadow: '0 0 0 .5px rgba(90,60,30,.16), 0 30px 70px -24px rgba(150,80,30,.38), 0 0 90px 10px rgba(255,178,122,.35)' },
    segment: 'linear-gradient(180deg, rgba(255,255,255,.8), rgba(255,248,240,.55))',
    segmentHover: 'radial-gradient(circle at 50% 50%, #FFF3E8 30%, #FFC9A0 70%, #FFA868 97%)',
    segmentStyle: { backdropFilter: 'blur(12px)' },
    label: '#5B524A', labelHover: '#1E1B18', labelClassName: 'font-sans text-[13px] font-medium',
    hub: 'radial-gradient(circle at 40% 30%, #fff, #FBF5EC)', hubText: '#1E1B18',
    hubStyle: { boxShadow: '0 0 0 .5px rgba(90,60,30,.18), 0 8px 22px -8px rgba(150,80,30,.35)' },
    gap: 6, inner: 0.37, outer: 0.95, lift: 8,
  },
}
