import { mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

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
): Promise<{ stalled: RalphLoopError[]; blocked: string[] }> => {
  if (!plan.ready) {
    throw new EmanationPlanNotReadyError()
  }
  const repoRoot = resolve(options.repoRoot ?? process.cwd())
  const runCommand = dependencies.runCommand ?? defaultRunCommand
  const git = dependencies.git ?? new GitWorktrees(repoRoot, runCommand)
  let commands: string[] = []
  if (options.testCommand === undefined) {
    const config = JSON.parse(await readFile(join(repoRoot, '.inspire/emanate.json'), 'utf8')) as unknown
    if (config === null || typeof config !== 'object' ||
        !('schema' in config) || config.schema !== 'inspire.emanate-config/1' ||
        !('suite' in config) || !Array.isArray(config.suite) || config.suite.length === 0) {
      throw new Error('.inspire/emanate.json requires a nonempty suite')
    }
    commands = config.suite.map((entry: unknown) => {
      if (entry === null || typeof entry !== 'object' ||
          !('command' in entry) || typeof entry.command !== 'string' || !entry.command.trim()) {
        throw new Error('each suite entry requires a nonempty command')
      }
      return entry.command
    })
  }
  const runTests = async (cwd: string): Promise<CommandResult> => {
    if (options.testCommand !== undefined) return runCommand(options.testCommand, cwd)
    const reports = await mkdtemp(join(tmpdir(), 'inspire-suite-'))
    try {
      let result: CommandResult = { exitCode: 0, stdout: '', stderr: '' }
      for (const [index, command] of commands.entries()) {
        const report = join(reports, `${String(index)}.json`)
        const quotedReport = `'${report.replaceAll("'", "'\\''")}'`
        result = await runCommand(['bash', '-c', command.replaceAll('{report}', quotedReport)], cwd)
        if (result.exitCode !== 0) return result
      }
      return result
    } finally {
      await rm(reports, { recursive: true, force: true })
    }
  }
  const stalled: RalphLoopError[] = []
  const blocked: string[] = []
  const unavailable = new Set<string>()
  const baseBranch = await git.currentBranch()

  const goalUnits = plan.goal === null ? null : new Set(plan.goal.units)
  const waves = plan.waves.slice(0, plan.deliverable_waves)

  for (const wave of waves) {
    const units = goalUnits === null
      ? wave.units
      : wave.units.filter((unit) => goalUnits.has(unit.id))
    for (const unit of units) {
      if (unit.requires.some((dependency) => dependency.ordering &&
          unavailable.has(`${dependency.kind}:${dependency.id}`))) {
        blocked.push(unit.id)
        unavailable.add(`${unit.kind}:${unit.id}`)
        continue
      }
      const worktree = await git.createWorktree(baseBranch, wave.wave, unit)
      const agent = await createOmpAgent(worktree.path)
      let testResult: CommandResult
      try {
        await agent.prompt(buildInitialPrompt(unit))
        testResult = await runTests(worktree.path)
        let tries = 0
        while (testResult.exitCode !== 0 && tries < options.maxTries) {
          tries += 1
          await agent.prompt(buildRetryPrompt(testResult, tries, options.maxTries))
          testResult = await runTests(worktree.path)
        }
      } finally {
        await agent.dispose()
      }
      if (testResult.exitCode !== 0) {
        stalled.push(new RalphLoopError(
          unit.id,
          worktree.branch,
          worktree.path,
          testResult,
        ))
        unavailable.add(`${unit.kind}:${unit.id}`)
        continue
      }
      await git.merge(worktree, unit)
      await git.remove(worktree)
    }
  }
  return { stalled, blocked }
}
