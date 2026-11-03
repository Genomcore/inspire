---
id: TASK-m4r8ka
title: Wire the landing "See live demo" action to the demo console screen
created: 2026-09-18
updated: 2026-09-18
reporter: "@joaquim.ballester"
closed_by: "@joaquim.ballester"
closed_at: 2026-09-18
epic: landing
size: S
importance: Mid
skills: [screens]
status: Done
blocked_by: []
related_to: []
---

## Description

`landing.index` has a "See live demo" call to action with no target screen, because
the demo console module is not created yet.

## Acceptance criteria

- The demo console module exists with at least one screen.
- `landing.index` declares a `### Navigation` row `demo` targeting that screen id.
