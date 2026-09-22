import type { CommandResult } from '../interfaces/command-result'

export class CommandError extends Error {
  constructor(
    readonly command: readonly string[],
    readonly result: CommandResult,
  ) {
    super(`${command.join(' ')} failed with exit code ${String(result.exitCode)}`)
    this.name = 'CommandError'
  }
}
