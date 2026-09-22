import type { Git } from '@/interfaces/git'
import type { AgentFactory } from '@/types/agent-factory'
import type { CommandRunner } from '@/types/command-runner'

export interface RalphLoopDependencies {
  createAgent?: AgentFactory
  git?: Git
  runCommand?: CommandRunner
}
