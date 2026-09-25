import { runRalphLoop } from '@/ralph-loop/run-ralph-loop'
import type { EmanationPlan } from '@/interfaces/emanation-plan'

const input = JSON.parse(await Bun.stdin.text()) as unknown
if (input === null || typeof input !== 'object' ||
    !('schema' in input) || input.schema !== 'inspire.emanation-plan/2' ||
    !('ready' in input) || input.ready !== true ||
    !('waves' in input) || !Array.isArray(input.waves)) {
  throw new Error('Ralph loop requires a ready emanation plan')
}

await runRalphLoop(input as EmanationPlan, { maxTries: 2 })
