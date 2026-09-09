---
id: 090-emanate-report-shape
title: "090 — emanate: the log is a diary, and the report never gets written"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-09
epic: follow-up
size: S
importance: High
skills: [code]
status: Done
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
`form → proceeding`, which was false within the minute. The file is untracked in that
project, which nothing INSPIRE ships caused — see the fourth criterion.

The operator, meanwhile, received eight status essays in the chat and no summary, and had
to probe the session to learn where things stood. The chat and the log had swapped roles:
progress went to the person, and the record went nowhere a person would read first.

One more defect of the same kind: the log's headline recommendation on `immutable`
("make the oracle venue-aware, or give the gate a deferred status") was retracted twice in
the conversation that followed — first as "wrong oracle class", then as "an enforcement
gap, emit a trigger" — and the log was never corrected. A report that carries a position
its author no longer holds is claiming something that did not happen.

## Acceptance criteria

- [x] The log has a **skeleton**, written at t=0 and appended to at fixed points: an
      identity block at t=0; one block per wave close; one closing block at the run's end
      carrying every line § The run report lists. The skeleton lives in `run.md` or in a
      `references/report-skeleton.md` it points at, so an orchestrator fills a shape
      instead of composing one.
- [x] **Progress goes to the log; the chat receives the report once** — at the run's
      end, or when a stall cascade empties the frontier. Interim operator-facing prose is
      limited to a one-line pointer at the log.
      **Already met when this ticket was written.** `run.md` § Liveness says exactly
      this, in the paragraph `090-emanate-turn-liveness` landed: "The chat gets the
      report, once", the log named as progress's home, and a turn between two wave
      closes having "nothing operator-facing to write at all". What was missing is the
      thing that paragraph points at — it defers to "the schedule § The run report
      sets", and no such schedule existed until the skeleton below. The referent, not
      the rule, was the gap.
- [x] **The last position wins.** A conclusion the orchestrator revises later in the same
      session is corrected in place in the log, never appended beside the old one.
- [x] Whether `.inspire/last-emanation.log` is git-tracked or ignored is decided, and the
      decision is stated where an orchestrator reads it.
      **The premise stated when this ticket was written is false: no such call was ever
      made for `.inspire/last-upgrade.log`.** `materialize.sh:400` `seed_gitignore` writes
      a marker-delimited block whose entire content is `.claude/settings.local.json`. No
      release has ever named either log there, so both are tracked by default rather than
      by a decision. The marker also makes a second run a no-op, so a line added to the
      block would reach **new inits only** and never an upgraded project.
      **Resolved: tracked, stated in doctrine, no `materialize.sh` change.** INSPIRE
      never excluded the file; a project whose own `*.log` rule hides it did that itself,
      and `materialize.sh`'s standing rule (lines 431–452, "report, never rewrite — the
      operator's .gitignore is the operator's") forbids editing it to fix that.
- [ ] **Or the ticket closes Done with the skeleton alone**, if the honest finding is that
      § The run report already says everything above and only the orchestrator ignored it.
      Then the skeleton is the whole deliverable, because a shape is harder to ignore than
      a paragraph.
      **This exit was not taken, and it was close.** § The run report did specify every
      line of content, so the criterion is nearly true — but it specified *content* and
      never a shape, and the two rules above (last position wins, tracking) were absent
      rather than ignored. The skeleton is the bulk of the deliverable; it is not the
      whole of it.

## Resolution

`inspire-emanate/references/report-skeleton.md` is the shape: the identity block at
t=0, one block per wave close, the closing block at the exit, each a slot per line
`run.md` § The run report names. `run.md` points at it and keeps the meaning — a line
added to its list gets a slot there carrying its label and nothing more, so the two
files cannot drift into two answers about what a line means. Two rules bind every
slot, stated in both files: the last position wins (a revised answer is corrected
where it stands, and the identity block's `status` is the worked example), and the
file is tracked.

**The last criterion is deliberately left unticked.** It offered closing on the
skeleton alone if § The run report already said everything; it did not — it specified
content and never a shape, and the two rules above were absent rather than ignored.
Claiming that exit would claim something that did not happen.

## Notes

Field evidence: `gs/.inspire/last-emanation.log` from run `20260908-102102-qcpd`. Its
content is good — the wave-1 findings are exactly what a postmortem needs — which is what
makes the missing shape a doctrine problem rather than a diligence one. The orchestrator
wrote a great deal; it just never wrote *the report*.
