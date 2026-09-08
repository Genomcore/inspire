---
id: F06-tdd
title: "F6 TDD — tests that can actually fail"
created: 2026-08-13
updated: 2026-08-25
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Very High
skills: [code, feature]
status: Open
blocked_by: []
related_to: [F07-gates]
---

## Description

Theme: **falsifiability.** The incremental half of the guardrail doctrine, inside
`inspire-code`. Add a mutation step after green to the tdd loop — invert a condition, move
a boundary, drop a side effect; a surviving mutant is a test gap, the named failure mode
of generated tests. Add the criterion↔test link consuming F02's stable `AC-n` ids, checked
one way only (every criterion needs a test; not every test needs a criterion). Widen test
derivation: project conventions and ADR invariants join criteria and descriptors as
inputs, declared once instead of restated per feature.

## Acceptance criteria

- [ ] `references/tdd.md` carries the mutation step; a worked example shows a surviving
      mutant handled as a test gap.
- [ ] Coverage check: every `AC-n` in a feature maps to at least one claiming test.
- [ ] Review Phase 0 consumes the check's output instead of asserting coverage in prose.

## Notes

**Amended 2026-08-25 (emanation-loop epic, per its design doc D11):** the epic
(`feat-emanation-loop` → release 0.8.0) becomes this focus's **v1 vehicle**.
Tests derive from claims (the derived contract's keyed ids + fingerprints),
written by the tester persona blind to bodies under the all-red phase invariant;
the criterion↔test coverage check lands as the `gate` script's evidence
(claim coverage × citing tests × suite result). The **mutation-step idea
survives as a quality-overseer tactic, not a pipeline stage**. The original
acceptance criteria map accordingly: AC-2's coverage check is `gate`'s claim
coverage; AC-1's mutation step re-homes to the quality overseer's doctrine.

Hard dependency: F02-contracts ships the criterion IDs — **discharged** in 0.7.0
(`inspire-feature/templates/use-case.md.template:38-39` carries `AC-1`/`AC-2`), so
`blocked_by` is empty and the coverage check has ids to bind to. Soft edge into
F07-gates: prove the cheap checks before building the architecture. Bundles CODE-01/02
from the vectors report; source doctrine:
`../../sandbox/docs/inspire-guardrails-deck.html`, links 1–2.
