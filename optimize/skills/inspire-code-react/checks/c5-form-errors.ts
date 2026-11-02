import { changed, defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 5: every form error is linked (aria-invalid + aria-describedby), announced
// (role="alert" or aria-live) and receives focus on a failed submit.
export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict(
    tree(ctx, /^source\/web\/src\/.*\.tsx?$/).filter(([, b]) => /aria-invalid/.test(b)).flatMap(([p, b]) => [
      ...(/aria-describedby/.test(b) ? [] : [`${p}: aria-invalid without aria-describedby`]),
      ...(/role=["']alert["']|aria-live/.test(b) ? [] : [`${p}: field errors not announced (role="alert" / aria-live)`]),
      ...(/\.focus\(|setFocus\(/.test(b) ? [] : [`${p}: no focus move on a failed submit`]),
    ]),
    'form errors not linked, announced and focused',
  ),
})
