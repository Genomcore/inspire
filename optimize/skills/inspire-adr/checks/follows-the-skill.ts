import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'agent',
  prompt: `Read .claude/skills/inspire-adr/SKILL.md, then the ADR this run created under inspire_kb/01_adr/.
Score 1 if the ADR follows every convention the skill sets for create (filename, H1, status, modules affected,
surfaces frontmatter, sections); subtract 0.25 per convention broken, floor 0. Name the broken ones in the reason.`,
})
