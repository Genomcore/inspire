import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'judge',
  rubric: `Checklist 3 (inspire-code-react): no mock, spy, MSW handler or response payload is defined inside a spec; specs
import them from the shared web/test/mocks/ layer and override only the fields they care about. Judge the spec files in
the change. 1.0 none inline. 0.5 fixture objects or payloads inline in one or two specs. 0 most specs build their own.`,
})
