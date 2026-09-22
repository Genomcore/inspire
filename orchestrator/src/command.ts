import { CommandError } from './errors'
import type { CommandResult, CommandRunner } from './types'

export const runCommand: CommandRunner = async (command, cwd) => {
  const process = Bun.spawn([...command], {
    cwd,
    stderr: 'pipe',
    stdout: 'pipe',
  })
  const [exitCode, stdout, stderr] = await Promise.all([
    process.exited,
    read(process.stdout),
    read(process.stderr),
  ])
  return { exitCode, stdout, stderr }
}

const read = async (stream: ReadableStream<Uint8Array>): Promise<string> =>
  new Response(stream).text()

export const requireSuccess = async (
  runner: CommandRunner,
  command: readonly string[],
  cwd: string,
): Promise<CommandResult> => {
  const result = await runner(command, cwd)
  if (result.exitCode !== 0) {
    throw new CommandError(command, result)
  }
  return result
}
