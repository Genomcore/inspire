---
id: B1-decisions-in-context
title: "B1 — a session starts without the project's decisions in context"
created: 2026-10-23
updated: 2026-10-23
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: High
skills: [adr, code]
status: Open
blocked_by: []
related_to: [B1-adr-decision-rationale]
---

## Origin

The INSPIRE maintainers held a design review on 2026-10-23 while preparing the training of
new INSPIRE operators. This ticket records one of its decisions. The review's working notes
are not public, so this ticket states everything needed to act on the decision.

**Decision:** every INSPIRE session, for specification or for code, starts with all of
the project's live decisions in context. ADRs are the main guardrails on what may be
built and how.

## Description

Today a session sees an ADR only when a skill reads it on purpose. `inspire-code`
re-reads the ADRs that specify the unit it is building. A specification session, or a
code session working outside a unit, can contradict a decision it never loaded.

`plugin/base/hooks/session-start.sh` already injects context into every session: the
project's `output_language` and the writing contract. The proposal is to add a **decision
digest** there: every live decision, as its binding statement only.

Questions the design answers:

- **What goes in.** Only live decisions; superseded and rejected ADRs are left out. The
  design also decides whether decisions at `design` maturity are included or flagged.
- **Size.** The digest grows with the project. It needs a size budget, and a rule for
  what happens past it: truncate, scope, or link. A digest built from the decision files
  that `B1-adr-decision-rationale` introduces stays small. One built from whole ADRs
  does not.
- **Scope.** Whether an ADR's `surfaces:` field narrows the digest for a session working
  on one surface.
- **The emanation process.** Emanation, the unattended KB-to-code loop, runs agents
  outside the attended session. How those agents receive the digest is up to the
  INSPIRE Factory, the separate service that runs emanation. INSPIRE's part is a digest
  the emanation process can read, produced by the same script the hook uses.

## Acceptance criteria

- [ ] Every attended session in a materialized project starts with the decision digest
      in context.
- [ ] The digest is also available as a script's output, so the emanation process can
      consume it.
- [ ] The digest has a stated size budget and a stated rule for going over it.
- [ ] A project with no ADRs gets no digest and pays no cost.
- [ ] The digest is built mechanically by a script under `plugin/base/bin/` (materialized
      as `.inspire/bin/`), never by a model summarizing ADRs. A golden fixture pins its
      output.

## Notes

- This ticket does not depend on `B1-adr-decision-rationale`. It can read each ADR's
  `## Decision` section today. The split makes the digest shorter and its source
  cleaner, which is why the two are related.
