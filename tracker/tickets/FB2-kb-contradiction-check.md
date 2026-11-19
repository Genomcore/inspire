---
id: FB2-kb-contradiction-check
title: "FB2 — a KB that contradicts itself reaches the Factory"
created: 2026-11-06
updated: 2026-11-17
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: High
skills: [adr, workspace]
status: Open
blocked_by: []
related_to: [B1-decisions-in-context, B4-one-home-per-value, B1-adr-decision-rationale, 0180-derive-only-refusals]
---

## Origin

The maintainers of INSPIRE and of the INSPIRE Factory held the second block of a follow-up review
of the Factory on 2026-11-06. The block covered how a unit's agent works during a run, starting
with what it does when the KB contradicts itself. This ticket records one of its directions that
needs work in this repository. The review's working notes are not public, so this ticket states
the direction in full.

**Direction:** before any unit is queued for emanation, the KB is free of contradictions. A
coherence check at the level of the KB runs before a run is launched. This check is harder to
build than the stop during a run, which the Factory files on its side, so the stop comes first.
People still review ADRs; the check does not replace that.

## Description

### What happens today

**Mechanical checks are narrow.** `entity-coherence.sh` (a field typed two ways, a write on an
external entity), `screen-coherence.sh` (duplicate ids, route collisions), `keys-present.sh`
(duplicate error codes). Nothing checks ADR against ADR, ADR against `stack.md`, a tracker ticket
against an ADR, or a value stated twice. `derived-contract.md` never reads ADRs.

**Judgment only.** The workspace review (Phase 3) calls an ADR that contradicts the spec
"critical", and `bootstrap-review.md:25` checks the stack against ADRs. These are reviews, not
gates.

**Authority.** `_references/authority.md` ranks runtime, project, ADR, module and artifact.
"Contradicting a current ADR is always a finding" (line 70). Where neither scope contains the
other, "neither wins… say so" (line 39). Tracker tickets and open questions are not on the
ladder, and no rule says they are not authority.

### What this ticket asks for

- A check, run before a plan is queued, that reports contradictions:
  - ADR against ADR;
  - ADR against `stack.md` and the config;
  - ADR against the spec artifacts;
  - a tracker ticket against an ADR.
- A contradiction blocks the queue until it is fixed at its home.
- Mechanical where a script can find it; a review where only judgment can.
- `authority.md` says that tracker tickets and open questions are not authority.
- **A KB the deriver refuses is a contradiction too.** The same check derives the contract of
  every unit the plan holds, and reports each refusal with its remedy. A spec that passes
  `review.sh` but that the Factory refuses contradicts the Factory's rules, and a run finds it
  only when the unit starts. When a Factory checkout is configured, the attended check (for
  example `/inspire-config review`) runs the Factory's `derive` over the units. Without one, it
  says the check was skipped.

### Open questions

- A script, a review skill, or both?
- Scope: the units of the plan, or the whole KB?
- Where it runs: a hook, a skill the operator calls, or the Factory before planning (then a
  Factory port, filed when this ships)?
- Is this the workspace review's Phase 3, made a gate?

## Acceptance criteria

- [ ] A KB with a planted contradiction of each kind above is reported, and a KB without one
      passes.
- [ ] `authority.md` states that tracker tickets and open questions are not authority.
- [ ] With a Factory checkout configured, the check reports every unit the deriver refuses,
      with its class and remedy. Without one, it says the derive step was skipped.

## Notes

- `B1-decisions-in-context`: its digest gives the check every live decision.
- `B4-one-home-per-value`: a value in two layers is one kind of contradiction. Its open question
  (script or judgment) is the same.
- `B1-adr-decision-rationale`: binding decision files make ADR comparisons smaller.
- Factory note: if the check runs in the Factory before planning, the Factory work is filed in the
  Factory's tracker when this ticket ships.

**Amended 2026-11-17 (a governed project's Factory run).**

A governed project's first full INSPIRE Factory run (Factory 0.18.0, 2026-11-16) built 54
units and refused six at derive, before any agent started. The six refusals blocked seven
more units: the project's API bundle and six screens. Every refused spec had passed
`review.sh` and been promoted to `accepted`. The run's plan
said it was ready and listed no finding: the planner does not derive contracts, so each refusal
appeared only when its unit started, after the run had already built 54 units. The Factory
already ships `derive` for one unit, which is how the project checked its fixes. This ticket
now asks for the attended side of that check. The Factory side, where the planner derives every
unit and reports the plan as not ready, is Factory work in the Factory's tracker.
