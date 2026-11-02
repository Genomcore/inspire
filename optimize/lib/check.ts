import { readdirSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'

export type Kind = 'deterministic' | 'judge' | 'agent'

export type Context = {
  task: string
  workdir: string
  output: string
  files: Record<string, string>
}

export type Verdict = { score: number; reason: string }

type Base = { pass?: number }

export type Check =
  | (Base & { kind: 'deterministic'; run: (ctx: Context) => number | Verdict | Promise<number | Verdict> })
  | (Base & { kind: 'judge'; rubric: string })
  | (Base & { kind: 'agent'; prompt: string; tools?: string[] })

export const defineCheck = (check: Check): Check => check

type Entry = [path: string, body: string]

const SKIP = new Set(['node_modules', '.git', 'dist', 'coverage'])

const walk = (dir: string): string[] =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    SKIP.has(e.name) ? [] : e.isDirectory() ? walk(join(dir, e.name)) : [join(dir, e.name)],
  )

export const changed = (ctx: Context, path: RegExp, except?: RegExp): Entry[] =>
  Object.entries(ctx.files).filter(([p]) => path.test(p) && !except?.test(p))

export const tree = (ctx: Context, path: RegExp, except?: RegExp): Entry[] =>
  walk(join(ctx.workdir, 'source'))
    .map((f) => relative(ctx.workdir, f))
    .filter((p) => path.test(p) && !except?.test(p))
    .map((p) => [p, readFileSync(join(ctx.workdir, p), 'utf8')])

export const scan = (entries: Entry[], bad: RegExp, allow?: RegExp): string[] =>
  entries.flatMap(([p, body]) =>
    body.split('\n').flatMap((line, i) =>
      bad.test(line) && !allow?.test(line) ? [`${p}:${i + 1} ${line.trim().slice(0, 100)}`] : [],
    ),
  )

export const offences = (ctx: Context, path: RegExp, bad: RegExp, except?: RegExp): string[] =>
  scan(changed(ctx, path, except), bad)

export const verdict = (problems: string[], what: string): Verdict =>
  problems.length
    ? { score: Math.max(0, 1 - problems.length / 4), reason: `${what} (${problems.length}): ${problems.slice(0, 5).join(' | ')}` }
    : { score: 1, reason: '' }
