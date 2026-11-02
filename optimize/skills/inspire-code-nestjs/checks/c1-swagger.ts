import { changed, defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 1: every route you added or touched has @ApiOperation and one @ApiResponse per status it can
// return; every field of its request, response and page DTOs has @ApiProperty.
const ROUTE = /@(Get|Post|Put|Patch|Delete)\(/g
const count = (body: string, re: RegExp) => (body.match(re) ?? []).length

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict([
    ...changed(ctx, /^source\/src\/.*\.controller\.ts$/).flatMap(([p, b]) => {
      const routes = count(b, ROUTE), ops = count(b, /@ApiOperation\(/g), res = count(b, /@ApiResponse\(|@Api(Ok|Created|NoContent|BadRequest|NotFound|Conflict|Unauthorized|Forbidden|UnprocessableEntity)Response\(/g)
      return ops < routes || res < routes ? [`${p}: ${routes} route(s), ${ops} @ApiOperation, ${res} @ApiResponse`] : []
    }),
    ...changed(ctx, /^source\/src\/.*\/dto\/.*\.ts$|^source\/src\/.*\.(dto|response|query|request)\.ts$/, /\.spec\.ts$/).flatMap(([p, b]) => {
      const fields = count(b, /^[ \t]+(readonly[ \t]+)?\w+[?!]?[ \t]*:[ \t]*[^=(\n]+;[ \t]*$/gm), documented = count(b, /@ApiProperty(Optional)?\(/g)
      return documented < fields ? [`${p}: ${fields} field(s), ${documented} @ApiProperty`] : []
    }),
  ], 'Swagger missing on a route or DTO you added or touched'),
})
