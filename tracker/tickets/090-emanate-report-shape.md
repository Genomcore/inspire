---
id: 090-emanate-report-shape
title: "090 — emanate: the log is a diary, and the report never gets written"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: [090-emanate-turn-liveness]
---

## Description

`run.md` § The run report specifies what `.inspire/last-emanation.log` carries by the
final wave: the run's identity, the budget answer, **delivered · stalled · blocked** each
unit named with its branch, per-unit rework and infrastructural-retry counters, dropped
harvest paths, the drill and verify measurements, the pre-PR list, and the operator's
next act. The first field run left a 299-line file that has none of that shape. It is a
well-written **diary** — wave-1 narrative, findings, the orchestrator's decisions — with
no opening skeleton, no per-wave block and no closing section. Its last line says
`form → proceeding`, which was false within the minute. The file is untracked.

The operator, meanwhile, received eight status essays in the chat and no summary, and had
to probe the session to learn where things stood. The chat and the log had swapped roles:
progress went to the person, and the record went nowhere a person would read first.

One more defect of the same kind: the log's headline recommendation on `immutable`
("make the oracle venue-aware, or give the gate a deferred status") was retracted twice in
the conversation that followed — first as "wrong oracle class", then as "an enforcement
gap, emit a trigger" — and the log was never corrected. A report that carries a position
its author no longer holds is claiming something that did not happen.

## Acceptance criteria

- [ ] The log has a **skeleton**, written at t=0 and appended to at fixed points: an
      identity block at t=0; one block per wave close; one closing block at the run's end
      carrying every line § The run report lists. The skeleton lives in `run.md` or in a
      `references/report-skeleton.md` it points at, so an orchestrator fills a shape
      instead of composing one.
- [ ] **Progress goes to the log; the chat receives the report once** — at the run's
      end, or when a stall cascade empties the frontier. Interim operator-facing prose is
      limited to a one-line pointer at the log.
- [ ] **The last position wins.** A conclusion the orchestrator revises later in the same
      session is corrected in place in the log, never appended beside the old one.
- [ ] Whether `.inspire/last-emanation.log` is git-tracked or ignored is decided and
      `/inspire:init`'s seeded `.gitignore` block says so — the same call already made for
      `.inspire/last-upgrade.log`.
- [ ] **Or the ticket closes Done with the skeleton alone**, if the honest finding is that
      § The run report already says everything above and only the orchestrator ignored it.
      Then the skeleton is the whole deliverable, because a shape is harder to ignore than
      a paragraph.

## Notes

Field evidence: `gs/.inspire/last-emanation.log` from run `20260908-102102-qcpd`. Its
content is good — the wave-1 findings are exactly what a postmortem needs — which is what
makes the missing shape a doctrine problem rather than a diligence one. The orchestrator
wrote a great deal; it just never wrote *the report*.
