import { resolve } from 'node:path'

import { createOmpAgent } from '@/agents/create-omp-agent'
import { runCommand as defaultRunCommand } from '@/commands/run-command'
import { EmanationPlanNotReadyError } from '@/errors/emanation-plan-not-ready-error'
import { RalphLoopError } from '@/errors/ralph-loop-error'
import { GitWorktrees } from '@/git/git-worktrees'
import type { CommandResult } from '@/interfaces/command-result'
import type { EmanationPlan } from '@/interfaces/emanation-plan'
import type { RalphLoopDependencies } from '@/interfaces/ralph-loop-dependencies'
import type { RalphLoopOptions } from '@/interfaces/ralph-loop-options'
import { buildInitialPrompt } from '@/prompts/build-initial-prompt'
import { buildRetryPrompt } from '@/prompts/build-retry-prompt'

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
  const testCommand = options.testCommand
  const baseBranch = await git.currentBranch()

  const goalUnits = plan.goal === null ? null : new Set(plan.goal.units)
  const waves = plan.waves.slice(0, plan.deliverable_waves)

  for (const wave of waves) {
    const units = goalUnits === null
      ? wave.units
      : wave.units.filter((unit) => goalUnits.has(unit.id))
    for (const unit of units) {
      const worktree = await git.createWorktree(baseBranch, wave.wave, unit)
      const agent = await createOmpAgent(worktree.path)
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
      await options.verifyUnit(worktree, unit)
      await git.merge(worktree, unit)
      await git.remove(worktree)
    }
  }
}
