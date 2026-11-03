import { defineCheck, offences, verdict } from '../../../lib/check.ts'

// Checklist 2: no literal route path outside src/routes.tsx — not in navigate(), <Link to>,
// <Navigate to>, href, a redirect or a not-found "home" link.
const LITERAL = /(navigate\(\s*['"`]\/|\bto=\s*\{?\s*['"`]\/|<Navigate[^>]*to=\s*\{?\s*['"`]\/|href=\s*\{?\s*['"`]\/(?!\/)|redirect\(\s*['"`]\/)/

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict(offences(ctx, /^source\/web\/src\/.*\.tsx?$/, LITERAL, /\/src\/(routes|route-table)[^/]*\.tsx?$/, undefined), 'introduced rule violation'),
})
