---
id: B3-screen-parameters
title: "B3 — Screens declare their input parameters"
created: 2026-10-27
updated: 2026-10-27
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: High
skills: [screens]
status: Open
blocked_by: []
related_to: [B3-navigation-map]
---

## Origin

The INSPIRE maintainers held the third session of a design review on 2026-10-27 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** a screen gets a section for its input parameters: path parameters, query
parameters and display flags (for example a quick view versus an advanced view). Each one
says whether it travels in the path or the query. It is better for the spec to state
them than for the code to deduce them.

## Description

### What happens today

A screen's route is derived from `module` + `screen` (`/users/list`).
`inspire-screens/references/screen-routes.md` leaves "parameter syntax for a detail
screen's record" to the framework profile, and the screen format has no place to declare
a parameter. So a screen can't say it takes a record id, a filter, or a mode flag that
loads no data.

The review's second session put "navigation and route parameters" on hold for this
session. This ticket settles the parameters half. The navigation map has its own
ticket, `B3-navigation-map`, so parameters can land without waiting for that session.

### What this ticket asks for

- A keyed `### Parameters` table under `## Bindings`, with the columns key, in
  (`path` · `query`), semantic type, required, and notes.
- A parameter doesn't have to feed a data binding. A mode flag is a valid parameter on
  its own.
- The route map renders path parameters into the route. The exact syntax stays with the
  framework profile.
- `screen-coherence.sh` checks that a `### Data` row or a navigation that relies on a
  parameter names one that is declared.
- Every declared input parameter has its own associated test, mode flags included. A
  parameter that no test covers is a finding, not an accepted gap.

### Open questions

- Nested routes (a record inside a record, such as an annotation of a study) came up but
  weren't settled. Are they parameters too, or a separate shape?
- For native targets with no URL, are these the same declaration, read as the screen's
  inputs?

## Acceptance criteria

- [ ] `format-screen.md` defines the `### Parameters` table, and the screens README and
      `screen-routes.md` describe it.
- [ ] `/inspire-screens routes` renders declared path parameters into the route map.
- [ ] `screen-coherence.sh` reports a reference to an undeclared parameter, with golden
      fixtures for the pass and fail cases.
- [ ] A declared parameter that no test covers is reported as a finding.
- [ ] The two open questions have written answers in this ticket's close note.
