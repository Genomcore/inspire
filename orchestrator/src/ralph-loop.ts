import { resolve } from 'node:path'

import { runCommand as defaultRunCommand } from './command'
import { EmanationPlanNotReadyError, RalphLoopError } from './errors'
import { GitWorktrees } from './git'
import { createOmpAgent } from './omp'
import { buildInitialPrompt, buildRetryPrompt } from './prompts'
import type {
  CommandResult,
  EmanationPlan,
  RalphLoopDependencies,
  RalphLoopOptions,
} from './types'

export const runRalphLoop = async (
  plan: EmanationPlan,
  options: RalphLoopOptions,
  dependencies: RalphLoopDependencies = {},
): Promise<void> => {
  if (!plan.ready) {
    throw new EmanationPlanNotReadyError()
  }
  const repoRoot = resolve(options.repoRoot ?? process.cwd())
  const runCommand = dependencies.runCommand ?? defaultRunCommand
  const git = dependencies.git ?? new GitWorktrees(repoRoot, runCommand)
  const createAgent = dependencies.createAgent ?? createOmpAgent
  const testCommand = options.testCommand ?? ['bun', 'test']
  const baseBranch = await git.currentBranch()

  const goalUnits = plan.goal === null ? null : new Set(plan.goal.units)
  const waves = plan.waves.slice(0, plan.deliverable_waves)

  for (const wave of waves) {
    const units = goalUnits === null
      ? wave.units
      : wave.units.filter((unit) => goalUnits.has(unit.id))
    for (const unit of units) {
      const worktree = await git.createWorktree(baseBranch, wave.wave, unit)
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
          unit.id,
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
