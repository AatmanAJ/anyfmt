import type { DirectionMeta, DirectionModule } from './types'
import { meta as signal } from './signal/meta'
import { meta as aura } from './aura/meta'
import { meta as grid } from './grid/meta'
import { meta as cobalt } from './cobalt/meta'
import { meta as prism } from './prism/meta'

export const directions: DirectionMeta[] = [signal, aura, grid, cobalt, prism]

export const loaders: Record<string, () => Promise<{ default: DirectionModule }>> = {
  signal: () => import('./signal'),
  aura: () => import('./aura'),
  grid: () => import('./grid'),
  cobalt: () => import('./cobalt'),
  prism: () => import('./prism'),
}
