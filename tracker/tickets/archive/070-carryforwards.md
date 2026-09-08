---
id: 070-carryforwards
title: "070 — consolidated 0.7.0 carry-forwards"
created: 2026-08-18
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: follow-up
size: M
importance: Low
skills: [workspace, lesson, task]
status: Cancelled
blocked_by: []
related_to: []
---

## Description

Consolidated 0.7.0 carry-forwards — small, independent items surfaced during the
release that were arbitrated as "recorded, not fixed" rather than blocking the
packet. One bullet each; not a single theme.

**Cancelled 2026-08-19, not abandoned.** "Not a single theme" was the honest description
and also the defect: a nine-bullet bag is never anyone's next task, and its contents were
invisible to anyone scanning the open set. Every bullet was routed to a ticket whose theme
it actually shares. Nothing was dropped — the table below is the complete accounting, and
the two rows marked *no work* say why they were never tickets.

## Where every bullet went

| Bullet | Destination |
|---|---|
| prose-style R3: `cannot` missing from the stopword list | [[070-prose-style-nits]] |
| prose-style R4 reports the glossary's spelling, not the artifact's | [[070-prose-style-nits]] |
| R4 synonyms containing `.` or `::` can never match | [[070-prose-style-nits]] |
| Q9 — the 250-vs-300 threshold (arrived here from F03-style) | [[070-prose-style-nits]] |
| `test-materialize.sh:119` tracked-file check needs a SKIP path | [[070-relocate-validator-tests]] |
| `test-materialize.sh:755,758` labels name v0.3, exercise v0.6.0 | [[070-relocate-validator-tests]] |
| Mutation harnesses must restore file modes (chmod before mv) | [[070-relocate-validator-tests]] |
| `review.workflow.mjs` synthesizer completeness instrumentation | [[F04-mech]] |
| `update/SKILL.md:130`'s unconditional "it becomes an ask" | *no work — see below* |
| Entry↔reference truth class (module/feature create plan-gate) | *no work — see below* |

## The two that were never work

- **`update/SKILL.md:130`.** "It becomes an ask" is stated unconditionally, though
  byte-identical content makes the noop branch unreachable for genuinely divergent
  content. The original bullet already classified this: *"nuance note, not a bug."* The
  prose is not wrong for any input an operator can produce.
- **Entry↔reference truth class.** Module and feature entries claimed a create plan-gate
  their edits flows never had. **This was fixed inside 0.7.0** by narrowing the entries;
  the bullet recorded the *class* for future watchfulness, not an outstanding defect. If a
  create plan-gate is ever wanted, it is a deliberate behavior change and gets its own
  ticket.
