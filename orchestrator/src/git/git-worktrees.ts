import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'

import { requireSuccess } from '@/commands/run-command'
import type { Git } from '@/interfaces/git'
import type { Unit } from '@/interfaces/unit'
import type { Worktree } from '@/interfaces/worktree'
import type { CommandRunner } from '@/types/command-runner'

export class GitWorktrees implements Git {
  constructor(
    private readonly repoRoot: string,
    private readonly runCommand: CommandRunner,
  ) {}

  async currentBranch(): Promise<string> {
    const result = await this.git(['branch', '--show-current'])
    return result.stdout.trim()
  }

  async createWorktree(
    baseBranch: string,
    waveId: number,
    unit: Unit,
  ): Promise<Worktree> {
    const branch = [
      'ralph',
      waveId,
      slug(unit.kind),
      slug(unit.id),
      crypto.randomUUID().slice(0, 8),
    ].join('-')
    const path = join(this.repoRoot, '.claude', 'worktrees', branch)
    await mkdir(join(this.repoRoot, '.claude', 'worktrees'), { recursive: true })
    await this.git(['worktree', 'add', '-b', branch, path, baseBranch])
    return { branch, path }
  }

  async merge(worktree: Worktree, unit: Unit): Promise<void> {
    const status = await this.git([
      '-C',
      worktree.path,
      'status',
      '--porcelain',
    ])
    if (status.stdout !== '') {
      throw new Error(`uncommitted changes in ${worktree.path}`)
    }
    await this.git([
      'merge',
      '--no-ff',
      worktree.branch,
      '-m',
      `merge(ralph): ${unit.kind} ${unit.id}`,
    ])
  }

  async remove(worktree: Worktree): Promise<void> {
    await this.git(['worktree', 'remove', worktree.path])
    await this.git(['branch', '-d', worktree.branch])
  }

  private git(args: readonly string[]) {
    return requireSuccess(this.runCommand, ['git', ...args], this.repoRoot)
  }
}

const slug = (value: string): string =>
  value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
