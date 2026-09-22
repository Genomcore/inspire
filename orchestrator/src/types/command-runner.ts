import type { CommandResult } from '@/interfaces/command-result'

export type CommandRunner = (
  command: readonly string[],
  cwd: string,
) => Promise<CommandResult>
