// Aura design tokens. Hex values mirror the CSS variables on `.aura-root` (aura.css).
export const C = {
  paper: '#FBF7F0',
  linen: '#F1EADF',
  sand: '#E7DCCB',
  ink: '#1E1B18',
  ink2: '#5B524A',
  ink3: '#8A7F74',
  apricot: '#FFB27A',
  ember: '#B04E1B',
  peri: '#9DB4FF',
  dusk: '#4E63C9',
  butter: '#FFE8A3',
  white: '#FFFFFF',
} as const

/** The palette shown in the book, with roles and contrast notes (WCAG 2.x, against Paper unless stated). */
export const PALETTE = [
  { name: 'Apricot', hex: C.apricot, token: '--aura-glow-warm', role: 'Warm light. Glow, hovered wedge, highlights.', note: 'Never text. Light only.' },
  { name: 'Periwinkle', hex: C.peri, token: '--aura-glow-cool', role: 'Cool light. The far side of the halo, focus.', note: 'Never text. Light only.' },
  { name: 'Paper', hex: C.paper, token: '--aura-canvas', role: 'Canvas. Every page starts here.', note: 'Ink on Paper 16.1:1' },
  { name: 'Linen', hex: C.linen, token: '--aura-surface-2', role: 'Quiet surfaces, wells, code.', note: 'Ink on Linen 14.4:1' },
  { name: 'Ink', hex: C.ink, token: '--aura-text', role: 'Text, primary buttons.', note: 'AAA everywhere' },
  { name: 'Ink 2', hex: C.ink2, token: '--aura-text-2', role: 'Body copy, secondary text.', note: '7.3:1 AAA' },
  { name: 'Ember', hex: C.ember, token: '--aura-accent-text', role: 'Apricot, made readable. Links, labels.', note: '5.0:1 AA' },
  { name: 'Dusk', hex: C.dusk, token: '--aura-focus', role: 'Periwinkle, made readable. Focus rings.', note: '4.9:1 AA' },
  { name: 'Butter', hex: C.butter, token: '--aura-note', role: 'Sticky notes and hand-written asides.', note: 'Ink on Butter 14.8:1' },
] as const

export const GLOW = {
  warm: 'radial-gradient(closest-side, rgba(255,178,122,.95), rgba(255,178,122,.35) 55%, rgba(255,178,122,0))',
  cool: 'radial-gradient(closest-side, rgba(157,180,255,.9), rgba(157,180,255,.3) 55%, rgba(157,180,255,0))',
  butter: 'radial-gradient(closest-side, rgba(255,232,163,.95), rgba(255,232,163,0))',
}

export const EASE = [0.22, 1, 0.36, 1] as const
export const SPRING = { type: 'spring', stiffness: 260, damping: 26 } as const
