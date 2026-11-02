export type Kind = 'deterministic' | 'judge' | 'agent'

export type Context = {
  task: string
  workdir: string
  output: string
  files: Record<string, string>
  diff: string
  changes: Record<string, {
    before: string | null
    after: string | null
    added: Array<{ line: number; text: string }>
    patch: string
  }>
}

export type Verdict = { score: number; reason: string }

type Base = { pass?: number }

export type Check =
  | (Base & { kind: 'deterministic'; run: (ctx: Context) => number | Verdict | Promise<number | Verdict> })
  | (Base & { kind: 'judge'; rubric: string })
  | (Base & { kind: 'agent'; prompt: string })

export const defineCheck = (check: Check): Check => check

// Preserve original line numbers; unchanged lines are never scanned.
export const offences = (ctx: Context, path: RegExp, bad: RegExp, except?: RegExp, allow?: RegExp): string[] =>
  Object.entries(ctx.changes).filter(([p]) => path.test(p) && !except?.test(p)).flatMap(([p, change]) =>
    change.added.filter(({ text }) => bad.test(text) && !allow?.test(text))
      .map(({ line, text }) => `${p}:${line} ${text.trim().slice(0, 100)}`),
  )

export const verdict = (problems: string[], what: string): Verdict =>
  problems.length
    ? { score: Math.max(0, 1 - problems.length / 4), reason: `${what} (${problems.length}): ${problems.slice(0, 5).join(' | ')}` }
    : { score: 1, reason: '' }
