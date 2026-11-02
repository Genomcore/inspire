import { defineCheck } from '../../../../lib/check.ts'

export default defineCheck({
  kind: 'deterministic',
  run: ({ files }) => {
    const adrs = Object.keys(files).filter((p) => /^inspire_kb\/01_adr\/adr-[a-z0-9-]+\.md$/.test(p))
    if (adrs.length !== 1) return { score: 0, reason: `expected one new adr-*.md in inspire_kb/01_adr, got ${adrs.length}` }
    const body = files[adrs[0]]
    if (!/\*\*Status:\*\*\s*design\b/.test(body)) return { score: 0, reason: `${adrs[0]} has no **Status:** design line` }
    if (!/\*\*Modules affected:\*\*/.test(body)) return { score: 0, reason: `${adrs[0]} has no **Modules affected:** line` }
    return 1
  },
})
