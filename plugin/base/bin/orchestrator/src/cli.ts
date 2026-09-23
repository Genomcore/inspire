import { mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { isAbsolute, join, relative, resolve } from 'node:path'
import { parseArgs } from 'node:util'

import { requireSuccess, runCommand } from '@/commands/run-command'
import { runRalphLoop } from '@/ralph-loop/run-ralph-loop'
import type { EmanationPlan } from '@/interfaces/emanation-plan'
import type { Unit } from '@/interfaces/unit'
import type { Worktree } from '@/interfaces/worktree'

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    'test-command': { type: 'string' },
    'results-file': { type: 'string' },
    'tests-root': { type: 'string', multiple: true },
  },
})
const testCommand = JSON.parse(values['test-command'] ?? 'null') as unknown
const resultsFile = values['results-file']
const testsRoots = values['tests-root'] ?? []
if (!Array.isArray(testCommand) || testCommand.length === 0 ||
    !testCommand.every((arg) => typeof arg === 'string') ||
    !resultsFile || testsRoots.length === 0) {
  throw new Error('run requires --test-command JSON array, --results-file and --tests-root')
}
if (!resultsFile.startsWith('.claude/worktrees/') || resultsFile.split('/').includes('..')) {
  throw new Error('--results-file must be under .claude/worktrees/')
}

const input = JSON.parse(await Bun.stdin.text()) as unknown
if (input === null || typeof input !== 'object' ||
    !('schema' in input) || input.schema !== 'inspire.emanation-plan/2' ||
    !('ready' in input) || input.ready !== true ||
    !('waves' in input) || !Array.isArray(input.waves)) {
  throw new Error('Ralph loop requires a ready emanation plan')
}

const verifyUnit = async (worktree: Worktree, unit: Unit): Promise<void> => {
  const manifest = resolve(worktree.path, resultsFile)
  const rel = relative(worktree.path, manifest)
  if (rel.startsWith('..') || isAbsolute(rel) || !rel.startsWith('.claude/worktrees/')) {
    throw new Error('--results-file must be under .claude/worktrees/ in the unit worktree')
  }
  const scratch = await mkdtemp(join(tmpdir(), 'inspire-gate-'))
  try {
    const derive = await requireSuccess(runCommand, [
      join(worktree.path, '.inspire/bin/emanate-derive.sh'), unit.kind, '--file', unit.path,
    ], worktree.path)
    const contract = join(scratch, 'contract.json')
    await writeFile(contract, derive.stdout)
    await requireSuccess(runCommand, [
      join(worktree.path, '.inspire/bin/emanate-gate.sh'),
      '--contract', contract, '--results', manifest,
      ...testsRoots.flatMap((root) => ['--tests-root', root]),
    ], worktree.path)
  } finally {
    await rm(scratch, { recursive: true, force: true })
    await rm(manifest, { force: true })
  }
}

const repoRoot = process.cwd()
const status = await requireSuccess(runCommand, ['git', 'status', '--porcelain'], repoRoot)
if (status.stdout.trim()) throw new Error('run requires a clean launch worktree')
const goal = (input as EmanationPlan).goal?.selector ?? 'scope'
const branch = `emanate/${goal.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${crypto.randomUUID().slice(0, 8)}`
const goalWorktree = join(repoRoot, '.claude', 'worktrees', branch.replace('/', '-'))
await mkdir(join(repoRoot, '.claude', 'worktrees'), { recursive: true })
await requireSuccess(runCommand, ['git', 'worktree', 'add', '-b', branch, goalWorktree], repoRoot)
await runRalphLoop(input as EmanationPlan, {
  maxTries: 2, repoRoot: goalWorktree, testCommand, verifyUnit,
})
console.log(`emanation branch: ${branch}`)
