---
id: B4-one-home-per-value
title: "B4 — a rule's value is copied across layers, and the copies drift"
created: 2026-10-28
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [feature, domain, workspace]
status: Open
blocked_by: []
related_to: [B1-adr-decision-rationale]
---

## Origin

The INSPIRE maintainers held the fourth session of a design review on 2026-10-28 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** a decision is never split or copied across artifacts. Each artifact type
states one kind of thing. The feature says *that* a limit exists and why. The domain (an
action's precondition or an entity's invariant) holds the value: 72 hours, 24, or three
weeks. Anything else that needs the value cites the domain claim instead of copying it.
A citation must be checkable: the cited artifact has to say what it is cited for.

## Description

### What happens today

The case that prompted the decision: a feature said bookings more than 70 hours ahead
are forbidden, and cited another feature that never mentioned a limit. The domain said
72 hours.

The writing rule R8, "say it once" (`_references/writing-style.md`), binds a single
artifact only. Workspace review rule 8 reports two layers answering one question
differently as drift. That is judgment, and it catches a contradiction only once the
copies already disagree. Nothing says which layer owns a concrete value. A citation is
a wikilink to a whole file, so nothing points at the claim being cited.

The split mirrors `B1-adr-decision-rationale`, which separates an ADR's binding decision
from its rationale. Here the feature carries the rationale and the domain carries the
binding value.

### What this ticket asks for

- A short table of what each artifact type states, and what it leaves to another type.
  The first row: the feature states that a limit exists and why, and the domain states
  the value.
- `inspire-feature` and `inspire-domain` write to that table. A feature that needs the
  value links the keyed domain claim (for example `P2` of the booking action) instead of
  copying it.
- The workspace review reports a value stated in two layers, and a citation whose target
  does not say what it is cited for.

### Open questions

- How does a link point at one keyed claim rather than at its file? Obsidian has block
  and heading links. The keyed ids could serve as anchors.
- Can a script find any of this (the same number in a feature and in a descriptor), or
  is it judgment only, as R8 is today?
- Does the table belong in `_references/authority.md` (which layer wins) or in the
  writing style (what each layer writes)?

## Acceptance criteria

- [ ] The table of what each artifact type states has one home, and the feature and
      domain skills cite it rather than restating it.
- [ ] A feature can link one keyed domain claim, and the authoring skills do so instead
      of copying a value.
- [ ] The workspace review reports a value stated in two layers, and a citation whose
      target does not support it.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- No Factory port. The INSPIRE Factory reads the domain claim, and the domain claim keeps
  the value.
