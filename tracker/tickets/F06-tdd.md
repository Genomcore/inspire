---
id: F06-tdd
title: "F6 TDD — tests that can actually fail"
created: 2026-08-13
updated: 2026-10-28
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

- [x] `references/tdd.md` carries the mutation step; a worked example shows a surviving
      mutant handled as a test gap. *Shipped:* step 7, "The mutation drill", with a table
      of mutations and what each survivor tells, and the rule that every survivor is a
      test gap.
- [x] Coverage check: every `AC-n` in a feature maps to at least one claiming test.
      *Shipped:* `bin/criteria-have-tests.sh`, which `tdd.md` runs: a warning while the
      feature is 🟡 Planned, blocking from 🔵 on.
- [ ] Review Phase 0 consumes the check's output instead of asserting coverage in prose.
- [ ] **No tests is not a pass.** With zero test files, `criteria-have-tests.sh` still
      fails when a feature in scope is past 🟡 Planned, and `declared-errors-tested.sh`
      still fails when a descriptor in scope is past `draft`. The single summary message
      may stay, at error severity. A golden fixture per rule pins it: a 🟢 feature, or an
      `accepted` descriptor, in a project with no tests, fails.

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

**Amended 2026-10-28 (tracker pass): one criterion remains, and it is attended.** AC-1
and AC-2 have shipped. AC-3 has not: review Phase 0
(`inspire-code/references/review-dimensions.md` § Phase 0) still asks in prose whether
every testable criterion is covered, and never reads `criteria-have-tests.sh`. Claim
coverage of code that emanation builds is the INSPIRE Factory's, which counts the
`@claim` citations itself, so this ticket closes on attended review alone.

**Amended 2026-10-28 (fourth design-review session): no tests is not a pass.** The
review decided that tests stop being the only source of truth: work is correct only when
every claim in the KB is covered by at least one test and that test is green, so with no
tests nothing passes. Both coverage rules break that today. When they find no test file
at all, they emit one warning and stop, whatever the feature's state or the descriptor's
lifecycle (`criteria-have-tests.sh`, `declared-errors-tested.sh`, the `no test files
found` early exit). The per-criterion check, an error from 🔵 In progress on, never runs,
so a project with 🟢 Implemented features and no tests passes pre-PR. Once one test file
exists, every untested criterion is reported. The suppression was meant to keep one clear
message instead of a hundred, not to turn an error into a warning. The defect is in the
check this focus shipped, so it is a criterion here rather than a ticket of its own. The
INSPIRE Factory's half, an empty suite completing a unit, is in the Factory's tracker.
