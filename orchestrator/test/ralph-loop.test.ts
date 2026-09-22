import { describe, expect, test } from 'bun:test'

import { RalphLoopError } from '@/errors/ralph-loop-error'
import type { Agent } from '@/interfaces/agent'
import type { CommandResult } from '@/interfaces/command-result'
import type { EmanationPlan } from '@/interfaces/emanation-plan'
import type { Git } from '@/interfaces/git'
import type { Unit } from '@/interfaces/unit'
import type { Wave } from '@/interfaces/wave'
import type { Worktree } from '@/interfaces/worktree'
import { buildInitialPrompt } from '@/prompts/build-initial-prompt'
import { runRalphLoop } from '@/ralph-loop/run-ralph-loop'
import type { AgentFactory } from '@/types/agent-factory'
import type { CommandRunner } from '@/types/command-runner'

describe('runRalphLoop', () => {
  test('processes waves and units in order and promotes green worktrees', async () => {
    const trace: string[] = []
    const git = new FakeGit(trace)
    const createAgent = createAgentFactory(trace)
    const runCommand = createCommandRunner(trace, [green(), green(), green()])
    const input = plan([
      wave(1, [unit('entity', 'auth.account'), unit('action', 'auth.account.create')]),
      wave(2, [unit('screen', 'accounts.detail')]),
    ])

    await runRalphLoop(input, { maxTries: 2 }, {
      createAgent,
      git,
      runCommand,
    })

    expect(trace).toEqual([
      'base',
      'create:1:auth.account',
      'agent:create:worktree-1-auth.account',
      'prompt:auth.account:initial',
      'test:worktree-1-auth.account',
      'dispose:auth.account',
      'merge:branch-1-auth.account:auth.account',
      'remove:branch-1-auth.account',
      'create:1:auth.account.create',
      'agent:create:worktree-1-auth.account.create',
      'prompt:auth.account.create:initial',
      'test:worktree-1-auth.account.create',
      'dispose:auth.account.create',
      'merge:branch-1-auth.account.create:auth.account.create',
      'remove:branch-1-auth.account.create',
      'create:2:accounts.detail',
      'agent:create:worktree-2-accounts.detail',
      'prompt:accounts.detail:initial',
      'test:worktree-2-accounts.detail',
      'dispose:accounts.detail',
      'merge:branch-2-accounts.detail:accounts.detail',
      'remove:branch-2-accounts.detail',
    ])
  })

  test('sends each test failure back to the same agent session', async () => {
    const trace: string[] = []
    const git = new FakeGit(trace)
    const createAgent = createAgentFactory(trace)
    const runCommand = createCommandRunner(trace, [red('first'), red('second'), green()])

    await runRalphLoop(plan([wave(1, [unit('component', 'button')])]), {
      maxTries: 2,
    }, { createAgent, git, runCommand })

    expect(trace).toEqual([
      'base',
      'create:1:button',
      'agent:create:worktree-1-button',
      'prompt:button:initial',
      'test:worktree-1-button',
      'prompt:button:first',
      'test:worktree-1-button',
      'prompt:button:second',
      'test:worktree-1-button',
      'dispose:button',
      'merge:branch-1-button:button',
      'remove:branch-1-button',
    ])
  })

  test('keeps a red worktree after exhausting the retry budget', async () => {
    const trace: string[] = []
    const git = new FakeGit(trace)
    const createAgent = createAgentFactory(trace)
    const runCommand = createCommandRunner(trace, [red('first'), red('last')])

    const execution = runRalphLoop(plan([
      wave(1, []),
      wave(2, []),
      wave(3, [unit('pattern', 'dashboard')]),
    ]), {
      maxTries: 1,
    }, { createAgent, git, runCommand })

    expect(execution).rejects.toEqual(new RalphLoopError(
      'dashboard',
      'branch-3-dashboard',
      'worktree-3-dashboard',
      red('last'),
    ))
    await execution.catch(() => undefined)
    expect(trace).toEqual([
      'base',
      'create:3:dashboard',
      'agent:create:worktree-3-dashboard',
      'prompt:dashboard:initial',
      'test:worktree-3-dashboard',
      'prompt:dashboard:first',
      'test:worktree-3-dashboard',
      'dispose:dashboard',
    ])
  })

  test('builds a prompt with the unit contract and commit cadence', () => {
    const prompt = buildInitialPrompt(unit('action', 'auth.account.create'))

    expect(prompt).toContain('spec/sdd/auth/account/auth.account.create.md')
    expect(prompt).toContain('Red:')
    expect(prompt).toContain('Green:')
    expect(prompt).toContain('Blue:')
    expect(prompt).toContain('Commit the completed cycle')
    expect(prompt).toContain('Do not modify inspire_kb')
    expect(prompt).toContain('Do not add comments')
  })

  test('does not start work from a plan that is not ready', async () => {
    const trace: string[] = []
    const input = plan([wave(1, [unit('entity', 'auth.account')])])
    input.ready = false

    const execution = runRalphLoop(input, { maxTries: 1 }, {
      git: new FakeGit(trace),
    })

    expect(execution).rejects.toThrow('emanation plan is not ready')
    await execution.catch(() => undefined)
    expect(trace).toEqual([])
  })
})

class FakeGit implements Git {
  constructor(private readonly trace: string[]) {}

  currentBranch(): Promise<string> {
    this.trace.push('base')
    return Promise.resolve('ralph-loop-omp')
  }

  createWorktree(
    _baseBranch: string,
    waveId: number,
    target: Unit,
  ): Promise<Worktree> {
    this.trace.push(`create:${String(waveId)}:${target.id}`)
    return Promise.resolve({
      branch: `branch-${String(waveId)}-${target.id}`,
      path: `worktree-${String(waveId)}-${target.id}`,
    })
  }

  merge(worktree: Worktree, target: Unit): Promise<void> {
    this.trace.push(`merge:${worktree.branch}:${target.id}`)
    return Promise.resolve()
  }

  remove(worktree: Worktree): Promise<void> {
    this.trace.push(`remove:${worktree.branch}`)
    return Promise.resolve()
  }
}

const createAgentFactory = (trace: string[]): AgentFactory => (cwd) => {
  const name = cwd.split('-').slice(2).join('-')
  trace.push(`agent:create:${cwd}`)
  const agent: Agent = {
    prompt: (prompt) => {
      const failure = ['first', 'second'].find((value) => prompt.includes(value))
      trace.push(`prompt:${name}:${failure ?? 'initial'}`)
      return Promise.resolve()
    },
    dispose: () => {
      trace.push(`dispose:${name}`)
    },
  }
  return Promise.resolve(agent)
}

const createCommandRunner = (
  trace: string[],
  results: CommandResult[],
): CommandRunner => (_command, cwd) => {
  trace.push(`test:${cwd}`)
  const result = results.shift()
  if (result === undefined) {
    return Promise.reject(new Error('missing command result'))
  }
  return Promise.resolve(result)
}

const wave = (waveId: number, units: Unit[]): Wave => ({
  wave: waveId,
  units,
})

const plan = (waves: Wave[]): EmanationPlan => ({
  schema: 'inspire.emanation-plan/2',
  scope: ['spec/kb', 'spec/sdd'],
  ready: true,
  floor: waves.length,
  ceiling: null,
  deliverable_waves: waves.length,
  realized: [],
  realized_all: false,
  reemanate: null,
  goal: null,
  preflight: {
    components: [],
    probe_profiles: [],
    worktree_recipe: [],
  },
  wire_conventions: {
    ids: [],
    decisions: [],
  },
  waves,
  findings: [],
})

const unit = (kind: Unit['kind'], id: string): Unit => ({
  kind,
  id,
  path: kind === 'action'
    ? 'spec/sdd/auth/account/auth.account.create.md'
    : `spec/${id}.md`,
  module: kind === 'component' || kind === 'pattern' ? null : 'auth',
  surface: null,
  population: kind === 'entity' ? 'internal' : null,
  profiles: ['typescript'],
  requires: [],
  claims: 1,
})

const green = (): CommandResult => ({
  exitCode: 0,
  stderr: '',
  stdout: 'pass',
})

const red = (message: string): CommandResult => ({
  exitCode: 1,
  stderr: message,
  stdout: '',
})
