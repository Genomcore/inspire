import type { Finding } from '@/interfaces/finding'
import type { Goal } from '@/interfaces/goal'
import type { Preflight } from '@/interfaces/preflight'
import type { Reemanate } from '@/interfaces/reemanate'
import type { Wave } from '@/interfaces/wave'
import type { WireConventions } from '@/interfaces/wire-conventions'

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
