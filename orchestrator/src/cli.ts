import { runRalphLoop } from '@/ralph-loop/run-ralph-loop'
import type { EmanationPlan } from '@/interfaces/emanation-plan'

const input = JSON.parse(await Bun.stdin.text()) as unknown
if (input === null || typeof input !== 'object' ||
    !('schema' in input) || input.schema !== 'inspire.emanation-plan/2' ||
    !('ready' in input) || input.ready !== true ||
    !('waves' in input) || !Array.isArray(input.waves)) {
  throw new Error('Ralph loop requires a ready emanation plan')
}

const result = await runRalphLoop(input as EmanationPlan, { maxTries: 2 })
for (const failure of result.stalled) {
  console.error(`stalled: ${failure.message}\n${failure.testResult.stdout}\n${failure.testResult.stderr}`)
}
for (const unitId of result.blocked) console.error(`blocked: ${unitId} (stalled dependency)`)
if (result.stalled.length || result.blocked.length) process.exitCode = 1
