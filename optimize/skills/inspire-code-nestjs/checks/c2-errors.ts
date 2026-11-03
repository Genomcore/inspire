import { defineCheck, offences, verdict } from '../../../lib/check.ts'

// Checklist 2: no service throws an HTTP exception; every thrown error carries cause; no controller has
// try/catch; each domain error has an exception filter.
const HTTP = /\b(Http|NotFound|BadRequest|Conflict|Forbidden|Unauthorized|UnprocessableEntity|InternalServerError)Exception\b/

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict([
    ...offences(ctx, /^source\/src\/.*\/application\/.*\.ts$/, HTTP, /\.spec\.ts$/),
    ...offences(ctx, /^source\/src\/.*\.controller\.ts$/, /\btry\s*\{|\bcatch\s*\(|\.catch\(/),
  ], 'HTTP exception in a service or controller catch introduced'),
})
