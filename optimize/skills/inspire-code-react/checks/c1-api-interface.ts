import { defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 1: every data access goes through an api/ client interface with a real and a mock
// implementation, selected in one place; hooks are its only callers.
const FETCHES = /\b(fetch|fetchImpl)\(|typeof fetch\b/

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => {
    const src = tree(ctx, /^source\/web\/src\/.*\.tsx?$/)
    const api = src.filter(([p]) => /\/src\/api\//.test(p))
    const iface = [...new Set(api.flatMap(([, b]) => [...b.matchAll(/export\s+(?:interface|type)\s+(\w*Clients?)\b/g)].map((m) => m[1])))]
    const names = iface.length ? new RegExp(`\\b(${iface.join('|')})\\b`) : /$^/
    const problems: string[] = []
    if (!iface.length) problems.push('no exported client interface (…Client) in api/')
    const withTests = [...api, ...tree(ctx, /^source\/web\/test\/.*\.tsx?$/)]
    if (iface.length && !withTests.some(([, b]) => /mock/i.test(b) && names.test(b))) problems.push(`no mock implementation of ${iface.join('/')}`)
    problems.push(
      ...src.filter(([, b]) => FETCHES.test(b) && !names.test(b)).map(([p]) => `${p}: calls fetch without implementing the client interface`),
      ...scan(src.filter(([p]) => !/\/src\/api\//.test(p)), /\bhttp\w*Client\b|from\s+['"][^'"]*api\/[^'"]*http[^'"]*['"]/).map((s) => `uses the real implementation directly: ${s}`),
    )
    return verdict(problems, 'data access not behind the client interface')
  },
})
