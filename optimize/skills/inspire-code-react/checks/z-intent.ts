import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'agent',
  prompt: `This is the original intent of the inspire-code-react skill: the agent implements the requested frontend
feature completely, in this project's React architecture (components render, hooks orchestrate, api/ holds data access),
with tests. Read .claude/skills/inspire-code-react/SKILL.md and the files the run changed under source/web/. Score 1 when
the feature is complete and fits the project; subtract 0.25 for each missing part of the feature or each parallel
structure it invents; floor 0. Name what is missing in the reason.`,
})
