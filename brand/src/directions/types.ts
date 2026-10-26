import type { ComponentType } from 'react'
import type { WheelSkin } from '../shared/Wheel'

/** Static facts about a direction. The hub reads these without loading the direction's code. */
export type DirectionMeta = {
  id: string
  name: string
  /** One line on the idea. */
  tagline: string
  /** Which reference it grew from, in a few words. */
  lineage: string
  /** 4–6 key colours, first is the hero accent. */
  palette: { name: string; hex: string; role: string }[]
  /** Background + text for the hub card. */
  card: { bg: string; fg: string; accent: string }
  fonts: { display: string; text: string; mono?: string }
  /** CSS font-family for the display face (used on the hub card). */
  displayFamily: string
  skin: WheelSkin
}

export type DirectionModule = {
  /** The brand book: identity, landing preview, onboarding, app surfaces. */
  BrandBook: ComponentType
  /** The full-bleed landing page on its own. */
  Landing: ComponentType
}
