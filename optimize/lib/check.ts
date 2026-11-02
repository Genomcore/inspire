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
