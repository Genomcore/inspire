import type { UnitKind } from '../types/unit-kind'

export interface Requirement {
  kind: UnitKind
  id: string
  ordering: boolean
}
