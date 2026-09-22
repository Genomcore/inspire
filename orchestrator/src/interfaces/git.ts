import type { Unit } from './unit'
import type { Worktree } from './worktree'

export interface Git {
  currentBranch: () => Promise<string>
  createWorktree: (
    baseBranch: string,
    waveId: number,
    unit: Unit,
  ) => Promise<Worktree>
  merge: (worktree: Worktree, unit: Unit) => Promise<void>
  remove: (worktree: Worktree) => Promise<void>
}
