import type { Severity } from '../types/severity'

export interface Finding {
  code: string
  severity: Severity
  unit: string | null
  target: string | null
  owner: string | null
  message: string
  remedy: string
  derive_class: string | null
}
