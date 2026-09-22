import type { CommandResult } from '../interfaces/command-result'

export class RalphLoopError extends Error {
  constructor(
    readonly unitId: string,
    readonly branch: string,
    readonly worktree: string,
    readonly testResult: CommandResult,
  ) {
    super(`${unitId} remained red in ${worktree}`)
    this.name = 'RalphLoopError'
  }
}
