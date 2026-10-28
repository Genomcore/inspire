---
id: B3-screen-parameters
title: "B3 — Screens declare their input parameters"
created: 2026-10-27
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: "@djessy.czaplicki"
closed_at: 2026-10-28
epic: roadmap
size: M
importance: High
skills: [screens]
status: Done
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

- [x] `format-screen.md` defines the `### Parameters` table, and the screens README and
      `screen-routes.md` describe it.
- [x] `/inspire-screens routes` renders declared path parameters into the route map.
- [x] `screen-coherence.sh` reports a reference to an undeclared parameter, with golden
      fixtures for the pass and fail cases.
- [x] A declared parameter that no test covers is reported as a finding.
- [x] The two open questions have written answers in this ticket's close note.

## Resolution

`### Parameters` is a fifth `## Bindings` subsection — Key · In · Type · Required ·
Notes — and every row is a claim, `{id}/param/{key}`. Reliance is written as a
`param \`{key}\`` token: in a `### Data` row's cells, it must name a parameter this
screen declares; after the link of a `### Navigation` target or a `→ [[…]]` dispatch
outcome, it must name one the target declares.

Every acceptance criterion holds:

- `format-screen.md` carries the table, its own section and the claim family; the
  screens README, `screen-routes.md`, `screen-checks.md`, `screen-create.md`, the
  skill and the screen template describe it.
- The route map appends one segment per `path` parameter, in row order
  (`/users/detail/{id}`), and the syntax stays the framework profile's. The derived
  contract carries the same: `route.path` lists the path parameters and
  `route.default` renders them.
- `screen-coherence.sh` reports an undeclared parameter (`DR-S14` in derive) and a
  malformed row — an `In` outside `path` · `query`, a `Required` outside `yes` ·
  `no`, an optional path parameter (`DR-S13`). Golden fixtures:
  `parameters-clean`, `parameters-undeclared`, `parameters-shape` in review;
  `screen-parameters`, `screen-parameters-route`, `dr-s13-parameter-shape`,
  `dr-s14-undeclared-parameter`, `dr-t1-parameter-type` in derive.
- A parameter is a `test` claim, so a parameter no test cites is `GV-01` at the
  gate, mode flags included — `emanate-gate` fixture `gv-01-uncited-parameter`.

The two open questions:

- **Nested routes are parameters.** A record inside a record declares two path
  parameters, outer first — an annotation of a study declares `study`, then
  `annotation`. There is no separate shape: the route still derives from
  `module` + `screen`, and how the segments interleave with the path is the
  framework profile's rendering.
- **Native targets read the same declaration** as the screen's typed inputs — the
  arguments its navigation passes. `In` is the profile's to map; the table does not
  change.

## Notes

- A state's `When` may now anchor on a parameter key, so a mode flag that loads no
  data still anchors the state it produces.
- Not checked mechanically: a transition into a screen that does not pass one of
  its required parameters. `/inspire-screens routes` reports it as a question,
  because a profile may carry the value implicitly.
- **Factory port (2026-10-28 tracker pass).** The INSPIRE Factory derives contracts
  with its own reader of the KB, and it counts test citations for the code it builds.
  A `### Parameters` table that derives claims, and the "every parameter has a test"
  rule, need the matching change in the Factory's deriver, filed in the Factory's
  tracker when this ticket's format lands: `{id}/param/{key}`, `DR-S13` and
  `DR-S14`.
