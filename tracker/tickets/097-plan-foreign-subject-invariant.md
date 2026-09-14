---
id: 097-plan-foreign-subject-invariant
title: "097 — plan: a prose-only invariant about another entity passes every gate until GV-01"
created: 2026-09-10
updated: 2026-09-10
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [code, domain]
status: Open
blocked_by: []
related_to: [090-reference-data-home, 090-actor-head-without-a-role]
---

## Description

Both entity units of the second field run (`20260910-081400-pocm`, `gs`, 2026-09-10)
stalled at their contracter gate on the same defect, four instances of it, and each
instance names a *different* entity as the invariant's real subject:

| claim | prose | its subject |
|---|---|---|
| `workspace.role/inv/I1` | "A role grants nothing on its own. Only a membership grants access." | `workspace.membership`, wave 2 |
| `workspace.role/inv/I2` | "The catalog ships with the platform. No action writes it." | `population: external`, already in the contract; `workspace.role.list`'s `Q1`, which has a venue |
| `workspace.user/inv/I1` | "Every staff reference in the suite resolves to a row here." | 22 entities declaring `references(workspace.user)`, already store claims on their own migrations |
| `workspace.user/inv/I2` | "An unassigned role is the absence of an assignment row, never a sentinel user." | `case.case_assignment`, whose § Rationale carries the sentence |

Each is prose-only, so it derives `oracle: test` and `GV-01` demands a citing test. On the
entity it is filed on, the only assertable form is an absence — no scope column, no writer,
no sentinel field — which is green the moment the tester's declaration-only tree is packed
and stays green through every mutation that actually violates the rule. The contracters
reported all four as `error · specification`; both quality overseers rejected with
"not fixable in code"; the arbitration rule routed rather than reworked; the cascade blocked
`workspace.membership`, `workspace.membership.list` and `workspace.login`.

**The hole, named by `workspace.user`'s quality overseer.** `keyed-heads.md` § Coherence
checks that a *headed* V2 invariant names real fields of this entity and that a `P`/`Q` head
names a touched entity. A prose-only invariant has no head, so **no rule reads its
subject**. Nothing mechanical distinguishes "an invariant about this entity" from "an
invariant about another entity, filed here", and the `draft → accepted` gate passes both.
It is the analogue, one level up, of the `immutable` hole the first run hit: a claim that
derives an oracle it has no venue for.

Detection happened at the earliest phase the loop has, and it still cost two contracter
spawns, four overseer reads and a wave. A plan-time warning moves it to t=0, where the
operator can fix the vault before a wave is spent — the shape `PR-25` already has for an
access rule stated in prose.

## Acceptance criteria

- [ ] `emanate-plan.sh` gains a warning — `PR-26`, in `PR-25`'s vocabulary — that fires on
      a **prose-only** `## Invariants` entry which either names a token resolving to a
      different entity document (its id, or a field of it), or names no field of its own
      entity at all. A heuristic, never a refusal; `ready` never flips on it.
- [ ] Goldens for both shapes and a negative: an invariant naming only its own fields does
      not fire; the four `gs` claims above, reduced to fixtures, all fire. The
      `golden/emanate-plan` shard count is checked after the fixtures land.
- [ ] `keyed-heads.md` § Coherence states the limit — a prose-only invariant's subject is
      read by nothing — and points at `PR-26` as the safety net, the way the nestjs
      profile's public-route rule points at `PR-25`.
- [ ] The authoring side says it once, where invariants are written: an invariant's
      subject is the entity it is filed on; a rule about another entity goes on that
      entity, or on the referrer where the reference is, which 0.9.3 already ruled for
      cross-entity rules; a restatement of `population:` or of an action's `Q` head is not
      an invariant. `inspire-domain`'s guidance and the `04_domain` README carry it.
- [ ] **Or Done with zero code changed**, if the honest finding is that the contracter's
      `error · specification` exit is the intended detection and its cost is acceptable —
      then `derived-contract.md` says so in as many words, and the authoring rule above is
      still written.

## Notes

The remedy for the `gs` vault itself is two `/inspire-domain update` passes, quoted
verbatim in the run report, and is the project's work.

`090-reference-data-home` owns the other half of `role/inv/I2`: a catalog that "ships with
the platform" has no declared home for its rows, so an invariant about them has no owner.
`090-actor-head-without-a-role` is adjacent: `role/inv/I1` is a denial, and the head that
would give it a venue is an `actor(...)` head on the path that enforces it.
