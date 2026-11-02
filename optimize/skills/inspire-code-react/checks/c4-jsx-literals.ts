import { defineCheck, offences, verdict } from '../../../lib/check.ts'

// Checklist 4: no user-visible literal in JSX — text, aria-label, placeholder, title, alt, units — outside the i18n layer.
const TEXT = /(?<![=-])>\s*[A-Za-z][^<>{}]*[A-Za-z.!?:]\s*(<|$)|(?<![=-])>\s*[A-Za-z]{2,}[^<>{}]*\{/
const ATTR = /\b(aria-label|placeholder|title|alt)=\s*["'][^"'{]*[A-Za-z]/
const EXPR = /\{\s*['"][^'"]*[A-Za-z]{2,}[^'"]*['"]\s*\}|\`[^\`]*\}\s+[A-Za-z]{1,}[^\`]*\`/
const CODE = /^\s*(\/\/|\*|import)|className|key=|console\./

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => {
    const path = /^source\/web\/src\/.*\.tsx$/
    return verdict([
      ...offences(ctx, path, TEXT, /i18n/, CODE),
      ...offences(ctx, path, ATTR, /i18n/),
      ...offences(ctx, path, EXPR, /i18n/, CODE),
    ], 'user-visible literal introduced in JSX (use the i18n layer)')
  },
})
