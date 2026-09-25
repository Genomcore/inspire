import type { Requirement } from '@/interfaces/requirement'
import type { Population } from '@/types/population'
import type { UnitKind } from '@/types/unit-kind'

export interface Unit {
  kind: UnitKind
  id: string
  path: string
  module: string | null
  surface: string | null
  population: Population | null
  profiles: string[]
  requires: Requirement[]
  claims: number
}
