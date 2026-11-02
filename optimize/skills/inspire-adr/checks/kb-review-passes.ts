import { spawnSync } from 'node:child_process'
import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'deterministic',
  run: ({ workdir }) => {
    const review = spawnSync('bash', ['.inspire/bin/review.sh', 'inspire_kb/01_adr'], { cwd: workdir, encoding: 'utf8' })
    return review.status === 0 ? 1 : { score: 0, reason: `review.sh failed: ${review.stderr.trim().slice(0, 500)}` }
  },
})
