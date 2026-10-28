---
id: B3-navigation-map
title: "B3 — The navigation map: a design session on whether to store it"
created: 2026-10-27
updated: 2026-10-27
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [screens]
status: Open
blocked_by: []
related_to: [B3-screen-parameters]
---

## Origin

The INSPIRE maintainers held the third session of a design review on 2026-10-27 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** the navigation map gets its own design session, tracked by this ticket.
The session's first question is whether INSPIRE needs a stored navigation artifact at
all.

## Description

### What happens today

Screens declare `### Navigation` rows and dispatch outcomes (`→ [[screen]]`).
`/inspire-screens routes` computes the route map and the transition graph from them each
time it runs. The screens README says "nothing stores it" on purpose, because a stored
copy of a derived value drifts.

In the review's second session, navigation came out as the weakest part of the largest
emanation run so far. Routes are designed for the web only, and native navigation
(stacks, tabs, modals) isn't covered. Storing the app's navigation tree as an artifact
was proposed then, and put on hold until this session.

### What this ticket asks for

- One design session, scheduled on its own, ending in a decision this ticket records.
- Question 1: store a navigation artifact, or keep deriving the map and fix whatever made
  navigation weak in emanation? Storing it reverses "nothing stores it", so the decision
  must say what makes drift impossible or detectable.
- Whatever the answer, the result has to work for native targets as well as the web.

### Open questions for the session

- Must a `### Navigation` row or a `→ [[screen]]` outcome say which values it passes to
  the target's required parameters? (See `B3-screen-parameters`.)
- What went wrong in the emanation run: missing information in the spec, or code that
  ignored what was there?
- Shell-level navigation (menus, tabs, the start screen): which artifact owns it?

## Acceptance criteria

- [ ] The session is held, and its decision on storing versus deriving the map is
      recorded in this ticket's close note or in an ADR.
- [ ] The decision covers native targets as well as the web.
- [ ] The open questions have written answers.
- [ ] Keeping the map derived is a valid outcome. If the session decides that, this
      ticket closes Done with no code change, and any fix it calls for is filed as its
      own ticket.
