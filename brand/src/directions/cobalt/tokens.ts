// Cobalt tokens. Five colours, no tints you have to guess.
export const C = {
  cobalt: '#1F3BFF',
  ultra: '#0B1A8C',
  midnight: '#050A2E',
  flame: '#FF6A2B',
  ice: '#E9EEFF',
  // Supporting values (derived, never new hues).
  deep: '#020516',
  steel: '#8E9CFF',
  flameHot: '#FF8A4C',
  flameDeep: '#E5470C',
} as const

export const FLAME_GRAD = `linear-gradient(160deg, ${C.flameHot} 0%, ${C.flame} 45%, ${C.flameDeep} 100%)`

/** CSS variables for the semantic token table (also applied on the page roots). */
export const cssVars = {
  '--co-field': C.cobalt,
  '--co-band': C.ultra,
  '--co-surface': C.midnight,
  '--co-hit': C.flame,
  '--co-ink': C.ice,
  '--co-ink-muted': 'rgba(233,238,255,.68)',
  '--co-line': 'rgba(233,238,255,.14)',
  '--co-glass': 'rgba(11,26,140,.42)',
  '--co-glow': '0 0 28px rgba(255,106,43,.75)',
} as Record<string, string>

export const tokenTable: { token: string; value: string; use: string }[] = [
  { token: '--co-field', value: C.cobalt, use: 'Hero bands, primary field, focus rings' },
  { token: '--co-band', value: C.ultra, use: 'Alternate bands, wedges at rest, cards on blue' },
  { token: '--co-surface', value: C.midnight, use: 'App windows, HUD, wheel disc, terminal' },
  { token: '--co-hit', value: C.flame, use: 'The hovered wedge, primary CTA, stickers. One per view.' },
  { token: '--co-ink', value: C.ice, use: 'All text on blue and midnight' },
  { token: '--co-ink-muted', value: 'Ice 68%', use: 'Secondary text on midnight only (not on cobalt)' },
  { token: '--co-line', value: 'Ice 14%', use: 'Hairlines, window borders, ticks' },
  { token: '--co-glass', value: 'Ultramarine 42%', use: 'Glass fills over bands (with 24px blur)' },
  { token: '--co-glow', value: '0 0 28px Flame 75%', use: 'Hard glow on the hit wedge and HUD needle' },
]
