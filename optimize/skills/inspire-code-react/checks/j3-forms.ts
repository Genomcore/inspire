import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'judge',
  rubric: `Checklist 5 (inspire-code-react): every form error is linked (aria-invalid + aria-describedby), announced when
it appears (role="alert" or aria-live, server-side field errors included) and on a failed submit focus moves to the first
invalid field. 1.0 every form/dialog in the change does all of it, or the change has no form. 0.5 linked but not announced
or not focused. 0 plain text errors.`,
})
