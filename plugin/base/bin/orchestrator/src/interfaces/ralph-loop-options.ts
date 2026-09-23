import type { Unit } from '@/interfaces/unit'
import type { Worktree } from '@/interfaces/worktree'

export interface RalphLoopOptions {
  maxTries: number
  repoRoot?: string
  testCommand: readonly string[]
  verifyUnit: (worktree: Worktree, unit: Unit) => Promise<void>
}
