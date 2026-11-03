import { defineCheck, offences, verdict } from '../../../lib/check.ts'

// Checklist 3: no mock, spy, MSW handler or response payload defined inside a spec.
const INLINE = /(jest\.(fn|mock|spyOn)\(|\.mock(Resolved|Rejected|Return|Implementation)(Value)?(Once)?\(|\bhttp\.(get|post|put|patch|delete)\(|\bglobal\.fetch\s*=|new Response\()/

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict(offences(ctx, /^source\/web\/test\/.*\.spec\.tsx?$/, INLINE, undefined, /mocks\//), 'introduced rule violation'),
})
