import { changed, defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 6: reads are TanStack Query hooks keyed ['{screen-id}', '{key}']; mutations invalidate those keys.
const SCREEN_KEY = /\[\s*['"][a-z][\w-]*\.[\w.-]+['"]\s*,\s*['"][\w.-]+['"]/

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => {
    const src = tree(ctx, /^source\/web\/src\/.*\.tsx?$/)
    const reads = src.filter(([, b]) => /\buse(Infinite|Suspense)?Query\(/.test(b))
    const writes = src.filter(([, b]) => /\buseMutation\(/.test(b))
    const keyed = src.some(([, b]) => SCREEN_KEY.test(b))
    const fetching = src.filter(([p, b]) => /\/src\/hooks\//.test(p) && /\b(useEffect|useState)\b/.test(b) && /client\.|api\./.test(b) && !/use(Infinite)?Query\(|useMutation\(/.test(b))
    return verdict([
      ...(reads.length && !keyed ? ['no queryKey of the form [\'{screen-id}\', \'{key}\']'] : []),
      ...writes.filter(([, b]) => !/invalidateQueries/.test(b)).map(([p]) => `${p}: mutation without invalidateQueries`),
      ...fetching.map(([p]) => `${p}: hook loads data with useEffect/useState instead of TanStack Query`),
    ], 'data keys not built on TanStack Query')
  },
})
