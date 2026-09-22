import type {
  EmanationPlan,
  Unit,
  UnitKind,
  Wave,
} from '../../plugin/base/bin/schemas/emanation-plan'

export type { EmanationPlan, Unit, UnitKind, Wave }

export type Worktree = {
  branch: string
  path: string
}

export type CommandResult = {
  exitCode: number
  stdout: string
  stderr: string
}

export type CommandRunner = (
  command: readonly string[],
  cwd: string,
) => Promise<CommandResult>

export type Agent = {
  prompt: (message: string) => Promise<void>
  dispose: () => void | Promise<void>
}

export type AgentFactory = (cwd: string) => Promise<Agent>

export type Git = {
  currentBranch: () => Promise<string>
  createWorktree: (
    baseBranch: string,
    waveId: number,
    unit: Unit,
  ) => Promise<Worktree>
  merge: (worktree: Worktree, unit: Unit) => Promise<void>
  remove: (worktree: Worktree) => Promise<void>
}

export type RalphLoopOptions = {
  maxTries: number
  repoRoot?: string
  testCommand?: readonly string[]
}

export type RalphLoopDependencies = {
  createAgent?: AgentFactory
  git?: Git
  runCommand?: CommandRunner
}
