import type { Git } from '@/interfaces/git'
import type { CommandRunner } from '@/types/command-runner'

export interface RalphLoopDependencies {
  git?: Git
  runCommand?: CommandRunner
}
