import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'judge',
  rubric: `Checklist 4 (inspire-code-react): no user-visible literal — labels, headings, buttons, aria-labels, empty,
loading and error text, units, error messages coming from the api layer — all come from the i18n layer, in every
language the project has. Judge the files in the change. 1.0 none. 0.5 one or two slipped through. 0 mostly literal.`,
})
