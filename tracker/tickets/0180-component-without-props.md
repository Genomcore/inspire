---
id: 0180-component-without-props
title: "0180 — a component with no props passes review and is refused by the Factory"
created: 2026-11-17
updated: 2026-11-17
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [screens]
status: Open
blocked_by: []
related_to: [0180-derive-only-refusals]
---

## Origin

A governed project's first full INSPIRE Factory run (Factory 0.18.0, 2026-11-16) refused the
component `brand-backdrop` at derive, before any agent started. The entry is decorative: its
`## CMP2: API / Slots` section reads "None.", so it has no props table. The entry had passed
`review.sh`. The project unblocked the run by adding a placeholder `className` prop, which
stays until this ticket is decided.

## Description

### What happens today

- **The Factory refuses it.** `derived-contract.md` § Refusal defines `DR-C2`: "a component
  entry declares no `## API / Slots` props table, or one with no rows: its props are the whole
  of its contract".
- **INSPIRE says so and checks nothing.** `inspire-screens/references/screen-catalog.md` says
  the deriver refuses "an entry with no props table". `sections-present.sh` checks that
  `CMP2` is present, and no rule checks that it holds a row. `derived-contract.md` states that
  no review rule owns a catalog entry's shape, so every `DR-C*` class is found only by a run.
- **The template does not say a row is required.** `component.template.md` shows one
  placeholder row under `## CMP2: API / Slots` and says nothing about an entry with no props.

A component with no props is a real case: a backdrop, a divider, a decorative frame. INSPIRE and
the Factory disagree on whether it is valid, and the author learns the Factory's answer only
when a run starts.

### What this ticket asks for

Decide whether a component may have no props, then make INSPIRE and the Factory agree:

- **It may not:** a rule in `review.sh`'s default list (for example in
  `design-system-coherence.sh`) reports a component whose `CMP2` table has no row, at the same
  severity ramp as the other component checks. `component.template.md` says that at least one
  row is required, and what to write for a decorative component.
- **It may:** `CMP2` gets a declared empty form (for example the single line `None.`), and
  `screen-catalog.md` and `DR-C2` in `derived-contract.md` accept it. The Factory's matching
  change is filed in its tracker when this ships.

## Acceptance criteria

- [ ] The decision and its reason are recorded in this ticket's close note.
- [ ] If a row is required, a review rule reports an empty `CMP2` with a fixture, and the
      template says so.
- [ ] If an empty `CMP2` is valid, its form is written in `screen-catalog.md`,
      `component.template.md` and `DR-C2`, and a fixture shows that the review accepts it.

## Notes

- Factory note: either way the Factory's deriver must give the same answer as the review. The
  Factory work is filed in its tracker when this ships.
