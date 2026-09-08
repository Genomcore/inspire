---
id: F02-contracts
title: "F2 CONTRACTS — pin every artifact's shape"
created: 2026-08-13
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: roadmap
size: L
importance: Very High
skills: [domain, feature, adr, screens, module, workspace]
status: Done
blocked_by: []
related_to: [F01-derive]
---

## Description

Theme: **definition — what each artifact is.** Eight of thirteen artifact kinds exist only
as prose implied inside a SKILL.md; twelve concrete inconsistencies are already observable,
and the one pinned layer (domain) disagrees with itself across six definition sites.
Adjudicate the domain layer rule-by-rule — script wins vs prose wins, per rule (D1) — then
ship one template file per artifact kind, stable acceptance-criterion IDs (`AC-n`) in the
feature template, a widened `sections-present` / `SDD_SPEC_ROOT` beyond `04_domain` with a
section-order check, and fixed defaults (the `surfaces:` examples, the three maturity
ladders).

## Acceptance criteria

- [x] D1 adjudicated and recorded per rule; the four known domain-layer divergences fixed.
      — `3e1068a` (Form A, effect enum, Why→Purpose, serve.mjs retired, surfaces defaults).
- [x] Every artifact kind has exactly one template file; skills reference, never restate.
      — nine `templates/*.md.template` across seven skills (adr · action · entity ·
      use-case · module-hub · component-entry · pattern-entry · screen · spike); shipped
      by `9caf605`.
- [x] Feature template carries stable `AC-n` ids (unblocks F06-tdd). —
      `inspire-feature/templates/use-case.md.template:38-39`.
- [x] Validators cover shape presence and order beyond `04_domain`. —
      `bin/sections-present.sh` scopes features/ADR/screens at `:419-421`, each with its
      own severity row; the §3.5 coverage table was recorded against this criterion.

## Notes

The foundation release: F03 (style validator), F04 (mechanization) and F06
(criterion↔test link) all bind to what this pins. Bundles SHAPE-01..05. Soft edge: after
F01-derive so the inventory is one kind smaller.

Ladder unification (Q5) deferred — shelf note. The §3.5 validator coverage table
recorded against the "validators cover" AC. `validated` effect verb settled dead
(the 7-value enum is the authority). `## Externally populated entities` is
reference prose, not an artifact section. Cross-ref ticket
070-format-doc-consolidation.

## Closing note (2026-08-19)

Shipped in **0.7.0** (PR #14, merge `21f3fd8`, tag `v0.7.0`). Verified against the tree at
close, not against the release notes.

**Two residuals, both with a home — neither is orphaned by this closure:**

- The artifact's shape still lives in two places for the domain layer
  (`templates/*.md.template` plus `references/format-*.md`) →
  [[070-format-doc-consolidation]].
- Q5, maturity-ladder unification, filed at close as its own ticket rather than left as a
  shelf note inside an archived file → [[070-ladder-unification]].
