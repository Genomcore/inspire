import { resolve } from 'node:path'

import { runCommand as defaultRunCommand } from './command'
import { GitWorktrees } from './git'
import { createOmpAgent } from './omp'
import type {
  CommandResult,
  RalphLoopDependencies,
  RalphLoopOptions,
  Unit,
  Wave,
} from './types'

export class RalphLoopError extends Error {
  constructor(
    readonly unitName: string,
    readonly branch: string,
    readonly worktree: string,
    readonly testResult: CommandResult,
  ) {
    super(`${unitName} remained red in ${worktree}`)
    this.name = 'RalphLoopError'
  }
}

export const runRalphLoop = async (
  waves: Wave[],
  options: RalphLoopOptions,
  dependencies: RalphLoopDependencies = {},
): Promise<void> => {
  const repoRoot = resolve(options.repoRoot ?? process.cwd())
  const runCommand = dependencies.runCommand ?? defaultRunCommand
  const git = dependencies.git ?? new GitWorktrees(repoRoot, runCommand)
  const createAgent = dependencies.createAgent ?? createOmpAgent
  const testCommand = options.testCommand ?? ['bun', 'test']
  const baseBranch = await git.currentBranch()

  for (const wave of waves) {
    for (const unit of wave.units) {
      const worktree = await git.createWorktree(baseBranch, wave.wave_id, unit)
      const agent = await createAgent(worktree.path)
      let testResult: CommandResult
      try {
        await agent.prompt(buildInitialPrompt(unit))
        testResult = await runCommand(testCommand, worktree.path)
        let tries = 0
        while (testResult.exitCode !== 0 && tries < options.maxTries) {
          tries += 1
          await agent.prompt(buildRetryPrompt(testResult, tries, options.maxTries))
          testResult = await runCommand(testCommand, worktree.path)
        }
      } finally {
        await agent.dispose()
      }
      if (testResult.exitCode !== 0) {
        throw new RalphLoopError(
          unit.name,
          worktree.branch,
          worktree.path,
          testResult,
        )
      }
      await git.merge(worktree, unit)
      await git.remove(worktree)
    }
  }
}

export const buildInitialPrompt = (unit: Unit): string => `
Implement the ${unit.type} "${unit.name}" specified at inspire_kb/${unit.path}.

Work only inside this worktree.
Use strict test-driven development.
Repeat this cycle until the unit is complete:
1. Red: write or adjust a test and confirm that it fails for the expected reason.
2. Green: implement only the minimum code required to pass.
3. Blue: refactor for clarity while keeping the suite green.
4. Commit the completed cycle.

Never skip the red execution.
Never weaken or delete a test to obtain green.
Keep the code minimal and readable.
Do not add comments.
Do not add speculative abstractions or unnecessary validation.
Do not modify inspire_kb.
`.trim()

const buildRetryPrompt = (
  result: CommandResult,
  tryNumber: number,
  maxTries: number,
): string => `
The test suite is still red after attempt ${String(tryNumber)} of ${String(maxTries)}.
Continue the Red, Green, Blue, commit cycle and fix the failure.

stdout:
${result.stdout}

stderr:
${result.stderr}
`.trim()
