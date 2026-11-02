import { defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 4: no user-visible literal in JSX — text, aria-label, placeholder, title, alt, units — outside the i18n layer.
const TEXT = /(?<![=-])>\s*[A-Za-z][^<>{}]*[A-Za-z.!?:]\s*(<|$)|(?<![=-])>\s*[A-Za-z]{2,}[^<>{}]*\{/
const ATTR = /\b(aria-label|placeholder|title|alt)=\s*["'][^"'{]*[A-Za-z]/
const EXPR = /\{\s*['"][^'"]*[A-Za-z]{2,}[^'"]*['"]\s*\}|\`[^\`]*\}\s+[A-Za-z]{1,}[^\`]*\`/
const CODE = /^\s*(\/\/|\*|import)|className|key=|console\./

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => {
    const tsx = tree(ctx, /^source\/web\/src\/.*\.tsx$/, /i18n/)
    return verdict([...scan(tsx, TEXT, CODE), ...scan(tsx, ATTR), ...scan(tsx, EXPR, CODE)], 'user-visible literal in JSX (use the i18n layer)')
  },
})
