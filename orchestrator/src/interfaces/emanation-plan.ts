import type { Finding } from './finding'
import type { Goal } from './goal'
import type { Preflight } from './preflight'
import type { Reemanate } from './reemanate'
import type { Wave } from './wave'
import type { WireConventions } from './wire-conventions'

export interface EmanationPlan {
  schema: 'inspire.emanation-plan/2'
  scope: string[]
  ready: boolean
  floor: number
  ceiling: number | null
  deliverable_waves: number
  realized: string[]
  realized_all: boolean
  reemanate: Reemanate | null
  goal: Goal | null
  preflight: Preflight
  wire_conventions: WireConventions
  waves: Wave[]
  findings: Finding[]
}
