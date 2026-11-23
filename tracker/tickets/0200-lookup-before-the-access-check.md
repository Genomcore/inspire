---
id: 0200-lookup-before-the-access-check
title: "0200 — an action can look up a record by alias before it checks the caller's rights"
created: 2026-11-20
updated: 2026-11-20
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Medium
skills: [domain]
status: Open
blocked_by: []
related_to: [FB2-kb-contradiction-check]
---

## Description

Early adopters met this on genomics-suite, ticket GSTKT-78 (INSPIRE 0.20.0, Factory 0.22.1 in
`strict` mode, 2026-11-19). `review.sh` returned 0 errors before each run, and three units
stopped because a create that replays a held alias did so before, or without, the check of the
caller's rights:

| Run | Unit | What the agent found |
|---|---|---|
| run-baCbUx | `individuals.individual.create` | the alias replay (`B9`) runs before the authorization (`B1`) |
| run-baCbUx | `studies.study.create` | a held alias in a project the caller does not administer has no rule |
| run-1on7Zi | `individuals.individual.create` | a held alias of a person outside the caller's studies has no rule |

Run in that order, the action tells a caller with no rights that the alias exists, and can hand
back the record. The project's ADR on external identifiers asks for the rights check, and the
descriptors did not apply it. Logs: `Genomcore/inspire-factory-logs`,
`runs/genomics-suite/<run>/state.json`, field `spec_issues`.

### What happens today

`_references/conventions/rest.md` decides how an existing record the caller may not see is
answered (`403` or `404`). Nothing in `inspire-domain` says that a step that finds a record by a
caller-supplied key, such as an alias replay or an upsert, runs after the step that checks the
caller's rights over it, and no review looks at the order of `## Behavior` steps.

### What this ticket asks for

- A rule in `inspire-domain`'s action format: a step that finds an existing record from a
  caller-supplied key runs after the rights check over that record, and an existing record the
  caller may not see is answered as `rest.md`'s existence-leak policy says.
- An interview probe for actions with an idempotent replay or an upsert: "who may receive the
  record that already holds this key?"
- The workspace review flags an action whose lookup step comes before its rights step.

## Acceptance criteria

- [ ] The rule and the probe are in `inspire-domain`.
- [ ] A fixture action whose alias replay comes before its access check is flagged by the review.
