import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'agent',
  prompt: `This is the original intent of the inspire-code-nestjs skill: the agent implements the requested backend
feature completely in this project's four-layer NestJS architecture (domain, application, infrastructure, controllers),
with the unit and e2e specs the skill requires. New routes and DTO fields have Swagger documentation; new application services have colocated unit specs. Score 1 when the feature is complete and fits the project; subtract 0.25 for each missing part,
missing required spec or parallel structure; floor 0. Name what is missing in the reason.`,
})
