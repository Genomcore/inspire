export type UnitKind =
  | 'action'
  | 'component'
  | 'entity'
  | 'pattern'
  | 'screen'

export type Requirement = {
  kind: UnitKind
  id: string
  ordering: boolean
}

export type Unit = {
  kind: UnitKind
  id: string
  path: string
  module: string | null
  surface: string | null
  population: 'internal' | 'external' | null
  profiles: string[]
  requires: Requirement[]
  claims: number
}

export type Wave = {
  wave: number
  units: Unit[]
}

export type EmanationPlan = {
  schema: 'inspire.emanation-plan/2'
  scope: string[]
  ready: boolean
  floor: number
  ceiling: number | null
  deliverable_waves: number
  realized: string[]
  realized_all: boolean
  reemanate: {
    selectors: string[]
    units: string[]
  } | null
  goal: {
    selector: string
    units: string[]
    floor: number
  } | null
  preflight: {
    components: Array<{
      name: string
      purpose: string | null
    }>
    probe_profiles: string[]
    worktree_recipe: Array<{
      step: string
      command: string | null
    }>
  }
  wire_conventions: {
    ids: string[]
    decisions: Array<{
      decision: string
      answer: string | null
    }>
  }
  waves: Wave[]
  findings: Array<{
    code: string
    severity: 'error' | 'warning'
    unit: string | null
    target: string | null
    owner: string | null
    message: string
    remedy: string
    derive_class: string | null
  }>
}

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
