---
id: 0200-inputs-and-states-without-a-rule
title: "0200 — an action leaves input combinations and states without a rule"
created: 2026-11-20
updated: 2026-11-20
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Medium
skills: [domain]
status: Open
blocked_by: []
related_to: [FB2-kb-contradiction-check]
---

## Description

Early adopters met this on genomics-suite, ticket GSTKT-78 (INSPIRE 0.20.0, Factory 0.22.1 in
`strict` mode, 2026-11-19). `review.sh` returned 0 errors before each run, and units stopped
because the action did not say what to do with a combination of its inputs, or with a state of
the data:

| Run | Unit | What had no rule |
|---|---|---|
| run-baCbUx | `findings.interpretation.classify` | `recorded_at` sent without `guideline_version` |
| run-1on7Zi | `findings.interpretation.classify` | `guideline_version` sent without `recorded_at` |
| run-1on7Zi | `cases.case.open` | two participants that resolve to the same individual |
| run-Q5AfiN | `findings.interpretation.classify` | a classification when the organisation has no framework version in force |

Each stop cost a run of one to two hours, and the fix was one sentence in `## Behavior` and,
sometimes, an error in `## Errors`. Logs: `Genomcore/inspire-factory-logs`,
`runs/genomics-suite/<run>/state.json`, field `spec_issues`.

### What happens today

`inspire-domain`'s interview prompts for actions (`references/interview-prompts-action.md`)
probe preconditions and existence one at a time. Nothing asks, for optional inputs that travel
together, which combinations are valid, nor what happens when two references in a list resolve
to the same record. The review rules check the shape of a descriptor, not whether its rules
cover its inputs.

### What this ticket asks for

- Interview probes, in `interview-prompts-action.md`, for:
  - optional inputs that depend on each other: which combinations are refused, and with which
    error;
  - a list of references: what happens when two of them name the same record;
  - a configuration or reference data the action needs: what happens when none is in force.
- A review step (`/inspire-domain review` or the workspace review) that lists the optional inputs
  of an action and flags each dependency between them that `## Behavior` does not rule on.

If the maintainers judge the probes enough and the review step not worth its cost, the ticket
closes Done with the probes only, and a note saying so.

## Acceptance criteria

- [ ] The probes are in `interview-prompts-action.md`.
- [ ] A fixture action with two dependent optional inputs and no rule for them is flagged by the
      review step, or the ticket records why there is no review step.
