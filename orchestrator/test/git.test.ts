import { afterEach, describe, expect, test } from 'bun:test'
import {
  access,
  mkdtemp,
  rm,
  writeFile,
} from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { runCommand } from '../src/command'
import { GitWorktrees } from '../src/git'
import type { Unit } from '../src/types'

const roots: string[] = []

afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => rm(root, {
    force: true,
    recursive: true,
  })))
})

describe('GitWorktrees', () => {
  test('creates, merges, and removes a unit worktree', async () => {
    const root = await createRepository()
    const git = new GitWorktrees(root, runCommand)
    const baseBranch = await git.currentBranch()
    const target = unit()

    const worktree = await git.createWorktree(baseBranch, 2, target)
    await writeFile(join(worktree.path, 'result.txt'), 'green\n')
    await gitCommand(worktree.path, ['add', 'result.txt'])
    await gitCommand(worktree.path, ['commit', '-m', 'feat: finish entity'])
    await git.merge(worktree, target)
    await git.remove(worktree)

    expect(await Bun.file(join(root, 'result.txt')).text()).toBe('green\n')
    expect((await gitCommand(root, ['branch', '--list', worktree.branch])).stdout).toBe('')
    expect(await fileExists(worktree.path)).toBeFalse()
  })

  test('does not merge an uncommitted agent cycle', async () => {
    const root = await createRepository()
    const git = new GitWorktrees(root, runCommand)
    const target = unit()
    const worktree = await git.createWorktree(
      await git.currentBranch(),
      1,
      target,
    )
    await writeFile(join(worktree.path, 'result.txt'), 'green\n')

    expect(await errorMessage(git.merge(worktree, target))).toBe(
      `uncommitted changes in ${worktree.path}`,
    )
    expect(await fileExists(join(root, 'result.txt'))).toBeFalse()
    expect(await fileExists(worktree.path)).toBeTrue()
  })
})

const createRepository = async (): Promise<string> => {
  const root = await mkdtemp(join(tmpdir(), 'inspire-ralph-'))
  roots.push(root)
  await gitCommand(root, ['init'])
  await gitCommand(root, ['config', 'user.email', 'ralph@example.com'])
  await gitCommand(root, ['config', 'user.name', 'Ralph Loop'])
  await writeFile(join(root, '.gitignore'), '.claude/worktrees/\n')
  await writeFile(join(root, 'seed.txt'), 'seed\n')
  await gitCommand(root, ['add', '.gitignore', 'seed.txt'])
  await gitCommand(root, ['commit', '-m', 'chore: seed'])
  return root
}

const gitCommand = async (cwd: string, args: string[]) => {
  const result = await runCommand(['git', ...args], cwd)
  if (result.exitCode !== 0) {
    throw new Error(result.stderr)
  }
  return result
}

const unit = (): Unit => ({
  type: 'entity',
  name: 'Account',
  path: 'auth/account.md',
})

const fileExists = async (path: string): Promise<boolean> =>
  access(path).then(() => true, () => false)

const errorMessage = async (promise: Promise<void>): Promise<string> =>
  promise.then(
    () => '',
    (error: unknown) => error instanceof Error ? error.message : String(error),
  )
