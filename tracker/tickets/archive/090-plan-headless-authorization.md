---
id: 090-plan-headless-authorization
title: "090 — an access rule stated in prose emanates as a public route, and nothing warns"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-09
epic: follow-up
size: M
importance: High
skills: [code, domain]
status: Done
blocked_by: []
related_to: [F07-gates, 090-actor-head-without-a-role]
---

## Description

`profiles/nestjs.md` § Bindings is explicit and correct: a `P{n} — actor({role})`
precondition renders as the route's role guard, and **"no `actor(…)` precondition → no
guard and a public route."** The guard is derived so it can never disagree with the
specification. The other half of the design is what makes the failure silent: a
prose-only precondition derives a **test**-oracle claim about its prose, so no denial is
ever asserted, no guard is ever emitted, and the suite goes green.

Measured across the `gs` vault by the first field run's orchestrator, after two security
overseers reached the edge of it independently:

```
precondition bullets in 04_domain:              158
  carrying a `P{n} — actor({role})` head:         0
  stating an authorization rule in prose:        51   (49 action descriptors)
```

Forty-nine descriptors say things like *"the caller must hold an administration
membership on the organisation"*, and every one would emanate unauthenticated.
`workspace.user.create` becomes a public user-creation endpoint; `workspace.role.list`
publicly enumerates the permission model. `emanate-plan.sh` reported the vault **READY**
with one unrelated warning. `review.sh` exits 0: `keyed-heads.md` § Coherence checks four
joins, none of which asks whether prose that *reads* like an access rule has a head.

This is a project-authoring gap first — the vault's owner restates 51 bullets in
vocabulary V3 — and a tooling gap second: a vault can be one edit away from shipping every
route public and nothing in the tool chain says so. One reason the bullets are prose is
also worth the ticket: `workspace.membership.list`'s rule reasons from **membership**, not
from a role, and `actor(role)` may simply not fit it. Then the format owes a head, or a
documented way to say "authenticated, no role".

## Acceptance criteria

- [x] A check exists, in the cheapest layer that can own it, that **warns** when a
      precondition or error bullet is prose-only and its prose names an authorization
      concept. The vocabulary (role, membership, permission, administrator, forbidden,
      authenticated, …) lives in **one** place a reader can inspect. Owner decided inside
      the ticket: a plan readiness class (`PR-2x`, warning, so `ready` does not flip) or a
      keyed-heads coherence warning surfaced by `review.sh` — not both.
- [x] `nestjs.md` § Bindings' "no head → public" sentence gains the pointer to that
      check, so the rendering rule and its safety net are read together.
- [x] The head grammar question is answered or handed on: either `actor(...)` already
      expresses "any authenticated caller" and the format doc says how, or the ticket
      names the V3 gap for `format-action.md`'s owner without solving it here.
- [x] Goldens: a fixture with a prose-only bullet naming a role warns; one with an
      `actor()` head does not; one whose prose is a genuine business precondition with no
      authorization vocabulary does not.

## Resolution

`PR-25`, a warning, in `plan-checks.sh` § `plan_check_authorization`. `derive` emits an
`A` record per headless precondition or error carrying its key and its prose;
`plan_ingest` matches them in **one** pass per unit, since an `awk` per bullet is what a
whole-vault plan cannot afford, and reports one finding per unit naming every key —
the remedy is one touch of the descriptor. It fires during ingest, so it covers the
whole frontier rather than what realization leaves: an already-realized unit's route
is public today, which is more worth saying than less.

The vocabulary is `KH_PROSE_AUTHZ_PHRASES` in `_keyed-heads.sh`, beside `W-1`'s
constraint list, and the matcher moved there with it — `cm_prose_hits` became
`kh_prose_hits`, so one answer to "does this prose say X" cannot become two. Both
lists are heuristics and neither gets to block anything.

`nestjs.md` § Bindings' "no head → public" sentence points at the check, and
`keyed-heads.md` § V3 carries the other direction: writing an access rule as prose is
not a weaker claim, it is no claim at all. The head-grammar question is handed on as
[`090-actor-head-without-a-role`](090-actor-head-without-a-role.md) — V3 can spell
neither "any authenticated caller" nor a membership relationship, and choosing a head
changes the closed vocabulary and every profile's rendering contract, which is the
format owner's call and not a warning's.

Goldens `emanate-plan/pr-25-prose-only-access-rule` (warns, `ready` stays true),
`pr-25-actor-head-does-not-warn` and `pr-25-business-precondition-does-not-warn`.

## Notes

The security overseer's doctrine case, verbatim from the run: *an endpoint reachable
without its guard is blocking even when every test passes, because the tests prove what
they assert and nobody asserted the negative.* This check is the t=0 version of that
sentence.

**Owner decided: plan, as `PR-25`.** An emanation run never invokes `review.sh` — a
`grep` over the whole `inspire-emanate` skill returns no reference to it — so a check
that lived only there would be invisible to the hands-off run this ticket exists to
protect. The vocabulary sits in `_keyed-heads.sh` beside `W-1`'s constraint-word list and
shares its matcher, so review's half and plan's half cannot drift into two answers about
what prose says.

**Head grammar: handed on, as [`090-actor-head-without-a-role`](090-actor-head-without-a-role.md).**
V3 has no spelling for "any authenticated caller" and none for a membership relationship,
so `actor(...)` does not already cover the two shapes the field run met. Choosing a head
changes the closed vocabulary and every framework profile's rendering contract, which is
the format owner's call and not a warning's.
