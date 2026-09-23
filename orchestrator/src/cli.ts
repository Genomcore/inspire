import { parseArgs } from 'node:util'

import { runRalphLoop } from '@/ralph-loop/run-ralph-loop'
import type { EmanationPlan } from '@/interfaces/emanation-plan'

const { values } = parseArgs({
  options: {
    'repo-root': { type: 'string' },
    'max-tries': { type: 'string' },
    'test-command': { type: 'string' },
  },
  strict: true,
})

const maxTries = Number(values['max-tries'] ?? '2')
if (!Number.isInteger(maxTries) || maxTries < 0) {
  throw new Error('--max-tries must be a nonnegative integer')
}

const testCommand = (values['test-command'] ?? 'bun test').trim().split(/\s+/)
const input = JSON.parse(await Bun.stdin.text()) as unknown
if (input === null || typeof input !== 'object' ||
    !('schema' in input) || input.schema !== 'inspire.emanation-plan/2' ||
    !('ready' in input) || input.ready !== true ||
    !('waves' in input) || !Array.isArray(input.waves)) {
  throw new Error('Ralph loop requires a ready emanation plan')
}
const plan = input as EmanationPlan

await runRalphLoop(plan, {
  maxTries,
  testCommand,
  ...(values['repo-root'] ? { repoRoot: values['repo-root'] } : {}),
})
