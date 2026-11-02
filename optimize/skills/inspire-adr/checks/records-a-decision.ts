import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'judge',
  rubric: `The ADR states the decision the user gave, not a weaker or different one; it explains the context that forced it;
it names at least one alternative and why it was discarded; and its consequences say what the affected modules must now do.
1.0 when all four hold, 0.5 when one is missing or vague, 0 when the decision itself is wrong or absent.`,
})
