---
id: 090-emanate-brief-paraphrase
title: "090 — emanate: spawn briefs restate doctrine and get it wrong"
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

`run.md` § persona says a spawn brief is **four things** — the role shell, the role-doc
pointer, the unit's resolved profiles, the project's wire conventions — and that this
skill "never restates a role's judgment". In the first field run the orchestrator wrote a
5.6 KB shared brief plus a unit-specific *"What you emit"* paragraph per persona, and two
of its own sentences caused real damage:

- The entity brief said to emit *"domain type, DTOs, semantic-type validators at the
  owning boundary, the Prisma model, and one migration"*. `contracter.md` § Emission maps
  an entity's fields to the persistence model and one migration; a DTO derives from an
  **action's** inputs — that second half is a reading, not a quote: the table states the
  entity row outright and never names where a DTO comes from, so the decisive fact is the
  **absence** of an entity-to-DTO row rather than a rule saying otherwise.
  The contracter obeyed, both overseers rejected the DTO as a
  mass-assignment shape, and a rework cycle was spent on an instruction the persona never
  chose. The orchestrator recorded the fault as its own.
- A rework hand-back told the `workspace.user` contracter to rewrite a stale sentence in
  its **applied** migration's header. The persona refused and measured why: Prisma
  checksums migration files, and one comment line made `migrate dev` demand a schema
  reset while `migrate status` and `migrate deploy` still passed. The instruction would
  have cleared every check in the run and detonated in the next worktree.

Two related lane violations from the same session. The orchestrator wrote a lint probe
**inside a persona's worktree** to verify a finding, then deleted it before harvest. And
in the conversation after the run it ran `INSERT`/`UPDATE`/`DELETE` by hand against the
shared development database to test a claim. § One unit, eight phases gives the
orchestrator **four** writes, not the two stated when this ticket was written: a worktree
at prepare, one commit at harvest, the results manifest at verify, one merge commit at
promote. The two later ones are outside any phase worktree, which is what makes the
criterion below the right shape — the bound is *inside a phase worktree*, not a count.
No phase touches a plane either way.

## Acceptance criteria

- [ ] `run.md` § persona carries the negative: **a brief is pointers and facts** — paths,
      the contract file, the profile set, the wire rows, the environment prefix — and
      **never a restatement of what the role emits.** A unit-specific "what you emit"
      paragraph is named as forbidden, with the DTO case as the example.
- [ ] Rework hand-backs carry the overseer's findings verbatim plus any corrected input
      (a truncated bullet, a missed clause); they add no instruction of the
      orchestrator's own. Where the orchestrator disagrees with an overseer it says so in
      the log, not in the hand-back.
- [ ] The eight-phase table's *writes* column is stated as normative: outside prepare
      and harvest the orchestrator writes nothing in a phase worktree. A claim it wants
      verified goes to an overseer or is recorded as unverified in the log.
- [ ] Live infrastructure is touched only by verify's declared commands and by
      personas in their worktrees. The orchestrator never runs ad hoc SQL or shell
      against a plane, during the run or in the conversation that follows it.

## Notes

The refusal is the encouraging half of this ticket: the persona's role doc gave it enough
to decline a wrong instruction with evidence, which is the behaviour the loop wants. The
fix is to give the orchestrator fewer sentences in which to be wrong, not to make
personas more compliant.
