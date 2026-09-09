---
id: 090-plan-headless-authorization
title: "090 — an access rule stated in prose emanates as a public route, and nothing warns"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [code, domain]
status: Open
blocked_by: []
related_to: [F07-gates]
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

- [ ] A check exists, in the cheapest layer that can own it, that **warns** when a
      precondition or error bullet is prose-only and its prose names an authorization
      concept. The vocabulary (role, membership, permission, administrator, forbidden,
      authenticated, …) lives in **one** place a reader can inspect. Owner decided inside
      the ticket: a plan readiness class (`PR-2x`, warning, so `ready` does not flip) or a
      keyed-heads coherence warning surfaced by `review.sh` — not both.
- [ ] `nestjs.md` § Bindings' "no head → public" sentence gains the pointer to that
      check, so the rendering rule and its safety net are read together.
- [ ] The head grammar question is answered or handed on: either `actor(...)` already
      expresses "any authenticated caller" and the format doc says how, or the ticket
      names the V3 gap for `format-action.md`'s owner without solving it here.
- [ ] Goldens: a fixture with a prose-only bullet naming a role warns; one with an
      `actor()` head does not; one whose prose is a genuine business precondition with no
      authorization vocabulary does not.

## Notes

The security overseer's doctrine case, verbatim from the run: *an endpoint reachable
without its guard is blocking even when every test passes, because the tests prove what
they assert and nobody asserted the negative.* This check is the t=0 version of that
sentence.
