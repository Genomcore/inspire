import { describe, expect, test } from 'bun:test'

import {
  RalphLoopError,
  buildInitialPrompt,
  runRalphLoop,
} from '../src/ralph-loop'
import type {
  Agent,
  AgentFactory,
  CommandResult,
  CommandRunner,
  Git,
  Unit,
  Wave,
  Worktree,
} from '../src/types'

describe('runRalphLoop', () => {
  test('processes waves and units in order and promotes green worktrees', async () => {
    const trace: string[] = []
    const git = new FakeGit(trace)
    const createAgent = createAgentFactory(trace)
    const runCommand = createCommandRunner(trace, [green(), green(), green()])
    const waves = [
      wave(1, [unit('entity', 'Account'), unit('action', 'Create account')]),
      wave(2, [unit('screen', 'Account detail')]),
    ]

    await runRalphLoop(waves, { maxTries: 2 }, {
      createAgent,
      git,
      runCommand,
    })

    expect(trace).toEqual([
      'base',
      'create:1:Account',
      'agent:create:worktree-1-Account',
      'prompt:Account:initial',
      'test:worktree-1-Account',
      'dispose:Account',
      'merge:branch-1-Account:Account',
      'remove:branch-1-Account',
      'create:1:Create account',
      'agent:create:worktree-1-Create account',
      'prompt:Create account:initial',
      'test:worktree-1-Create account',
      'dispose:Create account',
      'merge:branch-1-Create account:Create account',
      'remove:branch-1-Create account',
      'create:2:Account detail',
      'agent:create:worktree-2-Account detail',
      'prompt:Account detail:initial',
      'test:worktree-2-Account detail',
      'dispose:Account detail',
      'merge:branch-2-Account detail:Account detail',
      'remove:branch-2-Account detail',
    ])
  })

  test('sends each test failure back to the same agent session', async () => {
    const trace: string[] = []
    const git = new FakeGit(trace)
    const createAgent = createAgentFactory(trace)
    const runCommand = createCommandRunner(trace, [red('first'), red('second'), green()])

    await runRalphLoop([wave(1, [unit('component', 'Button')])], {
      maxTries: 2,
    }, { createAgent, git, runCommand })

    expect(trace).toEqual([
      'base',
      'create:1:Button',
      'agent:create:worktree-1-Button',
      'prompt:Button:initial',
      'test:worktree-1-Button',
      'prompt:Button:first',
      'test:worktree-1-Button',
      'prompt:Button:second',
      'test:worktree-1-Button',
      'dispose:Button',
      'merge:branch-1-Button:Button',
      'remove:branch-1-Button',
    ])
  })

  test('keeps a red worktree after exhausting the retry budget', async () => {
    const trace: string[] = []
    const git = new FakeGit(trace)
    const createAgent = createAgentFactory(trace)
    const runCommand = createCommandRunner(trace, [red('first'), red('last')])

    const execution = runRalphLoop([wave(3, [unit('layout', 'Dashboard')])], {
      maxTries: 1,
    }, { createAgent, git, runCommand })

    expect(execution).rejects.toEqual(new RalphLoopError(
      'Dashboard',
      'branch-3-Dashboard',
      'worktree-3-Dashboard',
      red('last'),
    ))
    await execution.catch(() => undefined)
    expect(trace).toEqual([
      'base',
      'create:3:Dashboard',
      'agent:create:worktree-3-Dashboard',
      'prompt:Dashboard:initial',
      'test:worktree-3-Dashboard',
      'prompt:Dashboard:first',
      'test:worktree-3-Dashboard',
      'dispose:Dashboard',
    ])
  })

  test('builds a prompt with the unit contract and commit cadence', () => {
    const prompt = buildInitialPrompt(unit('action', 'Create account'))

    expect(prompt).toContain('inspire_kb/auth/account/create.md')
    expect(prompt).toContain('Red:')
    expect(prompt).toContain('Green:')
    expect(prompt).toContain('Blue:')
    expect(prompt).toContain('Commit the completed cycle')
    expect(prompt).toContain('Do not modify inspire_kb')
    expect(prompt).toContain('Do not add comments')
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
    this.trace.push(`create:${String(waveId)}:${target.name}`)
    return Promise.resolve({
      branch: `branch-${String(waveId)}-${target.name}`,
      path: `worktree-${String(waveId)}-${target.name}`,
    })
  }

  merge(worktree: Worktree, target: Unit): Promise<void> {
    this.trace.push(`merge:${worktree.branch}:${target.name}`)
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
  wave_id: waveId,
  units,
})

const unit = (type: Unit['type'], name: string): Unit => ({
  type,
  name,
  path: type === 'action' ? 'auth/account/create.md' : `${name}.md`,
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
