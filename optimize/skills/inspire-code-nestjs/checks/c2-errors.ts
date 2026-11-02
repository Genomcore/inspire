import { changed, defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 2: no service throws an HTTP exception; every thrown error carries cause; no controller has
// try/catch; each domain error has an exception filter.
const HTTP = /\b(Http|NotFound|BadRequest|Conflict|Forbidden|Unauthorized|UnprocessableEntity|InternalServerError)Exception\b/

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => {
    const src = tree(ctx, /^source\/src\/.*\.ts$/, /\.spec\.ts$/)
    const errors = src.filter(([p]) => /\/domain\//.test(p)).flatMap(([, b]) => [...b.matchAll(/class\s+(\w+)\s+extends\s+\w*Error\b/g)].map((m) => m[1]))
    const caught = src.flatMap(([, b]) => [...b.matchAll(/@Catch\(([^)]*)\)/g)].map((m) => m[1])).join(',')
    return verdict([
      ...scan(src.filter(([p]) => /\/application\//.test(p)), HTTP).map((s) => `HTTP exception in a service: ${s}`),
      ...scan(src.filter(([p]) => /\.controller\.ts$/.test(p)), /\btry\s*\{|\bcatch\s*\(|\.catch\(/).map((s) => `controller catches: ${s}`),
      ...scan(changed(ctx, /^source\/src\/.*\/application\/.*\.ts$/, /\.spec\.ts$/), /throw new Error\((?![^)]*cause)/).map((s) => `Error without cause: ${s}`),
      ...errors.filter((e) => !new RegExp(`\\b${e}\\b`).test(caught)).map((e) => `domain error ${e} has no @Catch filter`),
    ], 'errors not translated by filters')
  },
})
