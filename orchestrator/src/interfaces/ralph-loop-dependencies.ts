import type { AgentFactory } from '../types/agent-factory'
import type { CommandRunner } from '../types/command-runner'
import type { Git } from './git'

export interface RalphLoopDependencies {
  createAgent?: AgentFactory
  git?: Git
  runCommand?: CommandRunner
}
