import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'agent',
  prompt: `Review the ADR introduced by the diff.
Score 1 if it uses a slug-only adr-*.md filename under inspire_kb/01_adr/, a human H1,
**Status:** design, **Modules affected:** with module wikilinks, and the sections Context,
Decision, Consequences (including Breaking changes), Alternatives considered and Related ADRs.
A surfaces field is optional for suite-wide decisions. Do not infer roster or link errors from
files absent from the diff. Subtract 0.25 per convention broken, floor 0; name each one.`,
})
