import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'judge',
  rubric: `Checklist 1 (inspire-code-react): every data access goes through an api/ client interface with a real and a
mock implementation, selected in one place; hooks are its only callers. Judge the api/ and hooks/ files in the change.
1.0: one typed client interface, a real (HTTP) implementation that is the only fetch caller, a mock implementation, one
selection point, hooks obtain the client from it. 0.5: the interface exists but some data access (for example a status
or health client) bypasses it, or there is no mock/selection. 0: hooks call fetch-based functions directly.`,
})
