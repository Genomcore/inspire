---
id: 0230-component-uses-a-component-without-an-edge
title: "0230 — a component built from other components declares no edge to them"
created: 2026-11-25
updated: 2026-11-25
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [screens]
status: Open
blocked_by: []
related_to: [0180-component-without-props]
---

## Description

Met on the `wishlist-app` bench case (INSPIRE 0.23.0, Factory 0.25.0, 2026-11-25, run
`run-nFlgdn`). The same gap was in the project's first build (INSPIRE 0.18.0, Factory 0.19.0,
2026-11-16, `run-Z9X6tT`), where timing hid it.

### What happened

Five components are built from other components, and their specs say so in
`## CMP1: Structure`:

| Component | Uses |
|---|---|
| `item-form` | `button`, `text-field`, `select-field` |
| `item-row` | `button` |
| `empty-state` | `illustration`, `button` |
| `copy-field` | `text-field`, `button` |
| `wishlist-form` | `text-field`, `button` |

Others do too (`confirm-dialog`, `gift-row`, `select-field` on `text-field`). In both plans
each of them has `requires: []`, so the Factory may start one before the
components it uses exist. On 2026-11-16, `item-form` finished before `select-field` existed and
`copy-field` before `text-field`, and their agents improvised the missing parts. On 2026-11-25,
four of these units stopped: their agents would not build a component that belongs to another
unit, and the Factory's claim tool refused it as "neither the assigned unit, nor one of its
members, nor a unit it requires".

### What happens today

- `_references/derived-contract.md` § `requires`: "A component declares none — A17's rule is
  that catalog entries order only by a *declared* edge between them, never by an assumed
  tier."
- `inspire-screens/SKILL.md` says patterns, components and layouts are siblings, and that a
  pattern declares the shared components it references on a `**Components:**` line. Nothing
  says how a component declares the components it is built from, and
  `component.template.md` has no place for it.
- So a component that uses another one, which is the normal case for a form or a list row, has
  a real dependency that A17 asks to declare and the format gives no way to declare.

### What this ticket asks for

- A component entry can declare the components it is built from, as a declared edge in the
  sense of A17, and the derived contract records each one in `requires`.
- `component.template.md`, `screen-catalog.md` and the screens skill say when the line is
  required: a component named in `## CMP1: Structure` that has its own catalog entry.
- A review rule reports a component named in a component's structure and missing from its
  declared edges, so the gap is found before a run.
- A cycle between components is refused, with the entries that form it.
- The change keeps the derive of an entry without the new line as it is today, with the same
  fingerprints, so a project that has not edited its components derives as before.

### Open questions

- The same `**Components:**` header line as a pattern, or a column in `## CMP1: Structure`?
  The header line is what the Factory's deriver already reads for a pattern.
- Is the review rule a script (component names in backticks that match a catalog entry) or a
  judgment of the workspace review? A name in backticks is not always a use: in this KB
  `button` names `page-banner` as one of its users, and `wishlist-form` sizes its panel "as
  `item-form`".
- Does `/inspire:update` add the line to existing components, or does the review rule report
  them and the operator fixes them?

## Acceptance criteria

- [ ] A fixture component that declares the components it uses derives with each of them in
      `requires`.
- [ ] A fixture component that names a catalog component in its structure without declaring
      it is reported by review.
- [ ] A fixture component without the new line derives with the same contract and fingerprints
      as before.

## Notes

- Factory note: the Factory's deriver reads `requires` for patterns and screens only
  (`orchestrator/src/contracts/derive-catalog.ts` reads `**Components:**` for a pattern and
  never for a component). When this ships, the Factory needs matching work: read the new
  declaration on a component, order the units by it, and let the claim tool accept the
  required components. It is filed in the Factory's tracker then, and the Factory's support is
  released before or with the INSPIRE release that writes the new line.
