---
id: 070-format-doc-consolidation
title: "070 — domain artifact shape lives in two places"
created: 2026-08-18
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Mid
skills: [domain]
status: Open
blocked_by: []
related_to: [F02-contracts, 070-glossary-population, 070-ladder-unification]
---

## Description

Domain artifact shape lives in two places: `templates/*.md.template` (the skeleton) and
`references/format-*.md` (the rules plus a copyable canonical example). The 0.7.0 T7
review's MAJOR-3 proved the drift surface — a vacuous fixture assertion existed because
the canonical example and the template had already diverged from each other without
either side failing.

## Acceptance criteria

- [ ] Format docs (`format-action.md`, `format-entity.md`) drop the copyable canonical
      example and point instead at the template plus an `examples/` directory.
- [ ] The prose-style gate's rider (T9: both templates + all three canonical examples
      reworded to pass at `accepted`) is preserved by whatever replaces the inline
      example.
- [ ] No second source of truth for an artifact's shape remains once this ships.

## Notes

Not 0.7.0 scope — ticketed instead, per the operator design question recorded
2026-08-17. Cross-ref F02-contracts (the layer that pins artifact shape).

**One of the three unfinished pieces of the contract wave.** F02-contracts and F03-style
shipped in 0.7.0 and are archived; what they deferred lives on as
[[070-format-doc-consolidation]] (one artifact shape, two files),
[[070-glossary-population]] (a contract rule reads a file nothing writes) and
[[070-ladder-unification]] (four maturity vocabularies). Separate work, one origin — read
the other two before scoping this one.
