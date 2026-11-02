import { defineCheck, offences, verdict } from '../../../lib/check.ts'

// Checklist 3: nothing under domain/ imports @nestjs/*, typeorm, class-validator or class-transformer.
export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict(offences(ctx, /^source\/src\/.*\/domain\/.*\.ts$/, /from\s+['\"](@nestjs\/|typeorm|class-validator|class-transformer)/, /\.spec\.ts$/, undefined), 'introduced rule violation'),
})
