import type { CommandResult } from './types'

export class CommandError extends Error {
  constructor(
    readonly command: readonly string[],
    readonly result: CommandResult,
  ) {
    super(`${command.join(' ')} failed with exit code ${String(result.exitCode)}`)
    this.name = 'CommandError'
  }
}

export class EmanationPlanNotReadyError extends Error {
  constructor() {
    super('emanation plan is not ready')
    this.name = 'EmanationPlanNotReadyError'
  }
}

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
