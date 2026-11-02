import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { changed, defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 5: every application service you created or changed has its colocated *.spec.ts.
export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict(
    changed(ctx, /^source\/src\/.*\/application\/.*\.service\.ts$/).map(([p]) => p.replace(/\.ts$/, '.spec.ts')).filter((s) => !existsSync(join(ctx.workdir, s))),
    'application service without its colocated unit spec',
  ),
})
