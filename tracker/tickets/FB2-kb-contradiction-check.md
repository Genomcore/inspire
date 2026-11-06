---
id: FB2-kb-contradiction-check
title: "FB2 — a KB that contradicts itself reaches the Factory"
created: 2026-11-06
updated: 2026-11-06
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: High
skills: [adr, workspace]
status: Open
blocked_by: []
related_to: [B1-decisions-in-context, B4-one-home-per-value, B1-adr-decision-rationale]
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

## Notes

- `B1-decisions-in-context`: its digest gives the check every live decision.
- `B4-one-home-per-value`: a value in two layers is one kind of contradiction. Its open question
  (script or judgment) is the same.
- `B1-adr-decision-rationale`: binding decision files make ADR comparisons smaller.
- Factory note: if the check runs in the Factory before planning, the Factory work is filed in the
  Factory's tracker when this ticket ships.
