---
id: 090-actor-head-without-a-role
title: "090 — V3 can say which role may act, and cannot say that anyone signed in may"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [domain]
status: Open
blocked_by: []
related_to: [090-plan-headless-authorization]
---

## Description

Vocabulary V3 of [`keyed-heads.md`](../../plugin/base/skills/_references/keyed-heads.md)
offers exactly one authorization head, `actor({role})` — "only that role may invoke the
action". Every other access rule an action can have owns no head, so it is written as
prose, and a prose precondition renders **no guard**: the framework profile's
`## Bindings` derives the guard from `actor(...)` and derives a public route from its
absence.

Two rules the field run met fall in that gap, and neither is exotic:

- **Authenticated, no role.** "Any signed-in caller may read their own profile" has no
  role to name. `actor(user)` is a lie if `user` is not a role the system has, and
  omitting the head says *public*, which is the opposite of what was meant.
- **Membership rather than role.** `workspace.membership.list`'s rule reasons from a
  relationship between the caller and the row — "the caller must hold a membership on the
  organisation" — not from a role the caller carries globally. `actor({role})` has nowhere
  to put the relationship.

`PR-25` now warns whenever a headless precondition or error reads like an access rule,
which makes the gap costly rather than merely untidy: for these two shapes the warning is
correct about the exposure and there is **no head the author can write to clear it**. A
safety net with a permanently unsatisfiable remedy is a net people learn to ignore.

Filed by the package that added `PR-25`, which deliberately did not solve it: choosing a
head is a change to the closed vocabulary and to the rendering contract every framework
profile implements, and that belongs with the format's owner rather than with a warning.

## Acceptance criteria

- [ ] The **authenticated-no-role** case has one stated answer: either an existing V3
      spelling already covers it and `keyed-heads.md` § V3 plus
      [`format-action.md`](../../plugin/base/skills/inspire-domain/references/format-action.md)
      say which, or V3 gains a head for it and every shipped framework profile's
      `## Bindings` states what it renders.
- [ ] The **membership** case has one stated answer, and "prose, because the relationship
      is the action's own business logic and the guard is a role check that cannot express
      it" is an acceptable one — but then it is written down, so that `PR-25`'s warning on
      such a bullet is a known accepted cost rather than an open question.
- [ ] Ratifying the current vocabulary closes this **Done with no code changed**, provided
      both answers are written where an author looking for a head will find them.
- [ ] If a head is added: `KH_V3` gains it at its arity, `head-referents.sh` decides
      whether its argument resolves to anything, and the golden fixtures cover it.

## Notes

`actor(...)`'s own doctrine is unaffected and is not in question here: a trust-boundary
claim is a precondition of the action, true wherever it runs, and never a surface-side
annotation. The gap is only in what the argument list can say.
