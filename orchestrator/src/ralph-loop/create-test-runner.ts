import { mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import type { CommandResult } from '@/interfaces/command-result'
import type { CommandRunner } from '@/types/command-runner'

export const createTestRunner = async (
  repoRoot: string,
  testCommand: readonly string[] | undefined,
  runCommand: CommandRunner,
): Promise<(cwd: string) => Promise<CommandResult>> => {
  let commands: string[] = []
  if (testCommand === undefined) {
    const config = JSON.parse(await readFile(join(repoRoot, '.inspire/emanate.json'), 'utf8')) as unknown
    if (config === null || typeof config !== 'object' ||
        !('schema' in config) || config.schema !== 'inspire.emanate-config/1' ||
        !('suite' in config) || !Array.isArray(config.suite) || config.suite.length === 0) {
      throw new Error('.inspire/emanate.json requires a nonempty suite')
    }
    commands = config.suite.map((entry: unknown) => {
      if (entry === null || typeof entry !== 'object' ||
          !('command' in entry) || typeof entry.command !== 'string' || !entry.command.trim() ||
          !entry.command.includes('{report}') || !('format' in entry) || entry.format !== 'jest') {
        throw new Error('each suite entry requires format jest and a command containing {report}')
      }
      return entry.command
    })
  }
  return async (cwd: string): Promise<CommandResult> => {
    if (testCommand !== undefined) return runCommand(testCommand, cwd)
    const reports = await mkdtemp(join(tmpdir(), 'inspire-suite-'))
    try {
      let result: CommandResult = { exitCode: 0, stdout: '', stderr: '' }
      let passed = 0
      for (const [index, command] of commands.entries()) {
        const report = join(reports, `${String(index)}.json`)
        const quotedReport = `'${report.replaceAll("'", "'\\''")}'`
        result = await runCommand(['bash', '-c', command.replaceAll('{report}', quotedReport)], cwd)
        if (result.exitCode !== 0) return result
        try {
          const summary = JSON.parse(await readFile(report, 'utf8')) as unknown
          if (summary === null || typeof summary !== 'object' ||
              !('numPassedTests' in summary) || typeof summary.numPassedTests !== 'number' ||
              !Number.isSafeInteger(summary.numPassedTests) || summary.numPassedTests < 0 ||
              !('numFailedTests' in summary) || summary.numFailedTests !== 0 ||
              !('success' in summary) || summary.success !== true) {
            throw new Error('missing or unsuccessful Jest test counts')
          }
          passed += summary.numPassedTests
        } catch (error) {
          return { ...result, exitCode: 1, stderr: `${result.stderr}\nCannot verify Jest report ${report}: ${String(error)}` }
        }
      }
      if (passed === 0) return { ...result, exitCode: 1, stderr: `${result.stderr}\nSuite executed zero passing tests; empty or skipped-only suites cannot complete a unit.` }
      return result
    } finally {
      await rm(reports, { recursive: true, force: true })
    }
  }
}
