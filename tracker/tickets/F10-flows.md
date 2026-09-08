---
id: F10-flows
title: "F10 FLOWS — journeys as first-class knowledge"
created: 2026-08-13
updated: 2026-08-25
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: Mid
skills: [screens, feature, prototype, adr]
status: Open
blocked_by: []
related_to: [F09-screens, F01-derive]
---

## Description

Theme: **the missing box.** No artifact kind holds a path through screens: the feature
file's "Main flow" is per-use-case prose that structurally cannot cite the screen layer,
and two existing mechanisms already produce flow knowledge with nowhere to put it —
extract's `navigation` slice is dropped on the floor, and the prototype skill routes
"that's not the flow" feedback to artifacts that cannot hold it. This is a design track
first: decide whether a flow becomes an artifact kind, its relation to feature use-cases
on one side and positional surface identity on the other, where UX lives (D5 — artifact
kind or ADR concern), and nav's authored home. It becomes a release when the design is
endorsed.

## Acceptance criteria

- [ ] Design doc answers: flow artifact yes/no, its home, its surface scoping, its
      relation to use-cases, UX's home (D5), nav's home.
- [ ] The last index mirror (the screens `_index.md`) retires once nav is rehomed —
      closing F01-derive's final item.
- [ ] Cross-surface journeys (mobile → web handoff) are expressible or explicitly
      declared out of scope.

## Notes

Design track — timeboxed, never a release gate. The prototype triangulation matrix is
reusable for flow drift almost verbatim. Bundles FLOW-04 + D5 + INDEX-04.

The "surface-binding artifact" phantom from the 0.7.0 D1 adjudication is recorded here as
F10-adjacent — no such artifact exists; if F10 wants one it is new design, not recovery.

**Amended 2026-08-25 (emanation-loop epic, per its design doc D11):** the
design track is **answered** by the emanation brainstorm/design: **no flow
artifact — the feature is the journey**; navigation's authored home is the
screen's own bindings (screen-owned navigation outcomes, design D10/A14), never
a separate flow file. AC-1 is thereby satisfied outside this ticket; AC-3's
cross-surface question dissolves with it. The ticket stays open on its **sole
residue: retiring the screens `_index.md`** once the epic's screen bindings
land (nav's rehoming is what it was waiting for). Note the epic's trust-scope
package keeps `_index.md` *derived, never endorsable* while it still exists —
that is posture, not the retirement.

**F01-derive closed 2026-08-19** having retired every index mirror except the screens
`_index.md`, which is authored nav and could not go before nav had a home. AC-2 above is
therefore no longer a shared item — it is the *sole* surviving index obligation in the
whole runtime, and F10 is its only owner.
