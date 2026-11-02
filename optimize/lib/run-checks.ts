import { spawn } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import type { Check, Context, Kind, Verdict } from './check.ts'

const ORDER: Kind[] = ['deterministic', 'judge', 'agent']
const DEFAULT_PASS: Record<Kind, number> = { deterministic: 1, judge: 0.7, agent: 0.7 }
const AGENT_TOOLS = ['Read', 'Glob', 'Grep']
const CLAUDE = process.env.CLAUDE_CLI_BIN ?? 'claude'
const SKIPPED = 'skipped: an earlier tier failed'
const SCHEMA = JSON.stringify({
  type: 'object',
  properties: { score: { type: 'number', minimum: 0, maximum: 1 }, reason: { type: 'string' } },
  required: ['score', 'reason'],
})

const evidence = (ctx: Context) =>
  [
    '## Task given to the agent under test',
    ctx.task,
    '## Final message of the agent under test',
    ctx.output,
    '## Files it created or changed',
    ...Object.entries(ctx.files).map(([path, body]) => `### ${path}\n${body}`),
  ].join('\n\n')

const judgePrompt = (rubric: string, ctx: Context) =>
  `You grade one run of an AI agent. Score it from 0 to 1 against the rubric and give a one-sentence reason.\n\n## Rubric\n${rubric}\n\n${evidence(ctx)}`

const agentPrompt = (prompt: string, ctx: Context) =>
  `You review one run of an AI agent. The workspace it worked in is your current directory. Score it from 0 to 1 and give a one-sentence reason.\n\n## What to review\n${prompt}\n\n${evidence(ctx)}`

function claude(prompt: string, cwd: string, tools: string[]): Promise<Verdict> {
  const args = ['-p', '--output-format', 'json', '--json-schema', SCHEMA, '--strict-mcp-config', '--tools', tools.join(',')]
  return new Promise((done, fail) => {
    const child = spawn(CLAUDE, args, { cwd })
    let out = ''
    let err = ''
    child.stdout.on('data', (d) => (out += d))
    child.stderr.on('data', (d) => (err += d))
    child.on('error', fail)
    child.on('close', (code) => {
      const verdict = code === 0 ? JSON.parse(out).structured_output : null
      verdict ? done(verdict) : fail(new Error(`claude exited ${code}: ${err.trim() || out.trim()}`))
    })
    child.stdin.end(prompt)
  })
}

async function evaluate(check: Check, ctx: Context): Promise<Verdict> {
  if (check.kind === 'deterministic') {
    const v = await check.run(ctx)
    return typeof v === 'number' ? { score: v, reason: '' } : v
  }
  if (check.kind === 'judge') return claude(judgePrompt(check.rubric, ctx), tmpdir(), [])
  return claude(agentPrompt(check.prompt, ctx), ctx.workdir, check.tools ?? AGENT_TOOLS)
}

const safely = (check: Check, ctx: Context): Promise<Verdict> =>
  evaluate(check, ctx).catch((e: Error) => ({ score: 0, reason: `check error: ${e.message}` }))

const [contextPath, ...checkPaths] = process.argv.slice(2)
const ctx: Context = JSON.parse(readFileSync(contextPath, 'utf8'))
const checks = await Promise.all(
  checkPaths.map(async (path) => {
    const check: Check = (await import(pathToFileURL(resolve(path)).href)).default
    if (!ORDER.includes(check?.kind)) throw new Error(`${path}: default export is not a defineCheck(...)`)
    return { path, check }
  }),
)

const results: Array<Verdict & { check: string; kind: Kind; passed: boolean }> = []
let tripped = false
for (const kind of ORDER) {
  const tier = checks.filter((c) => c.check.kind === kind)
  const verdicts = tripped
    ? tier.map(() => ({ score: 0, reason: SKIPPED }))
    : await Promise.all(tier.map((c) => safely(c.check, ctx)))
  tier.forEach(({ path, check }, i) =>
    results.push({ check: path, kind, ...verdicts[i], passed: !tripped && verdicts[i].score >= (check.pass ?? DEFAULT_PASS[kind]) }),
  )
  tripped ||= results.some((r) => !r.passed)
}

const score = results.length ? results.reduce((sum, r) => sum + r.score, 0) / results.length : 0
process.stdout.write(JSON.stringify({ score, passed: !tripped, results }))
