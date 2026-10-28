---
id: F14-semantic-types
title: "F14 SEMANTIC TYPES — the ownership split: universal · project · language profile"
created: 2026-08-25
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-10-28
epic: roadmap
size: M
importance: High
skills: [code, bootstrap]
status: Done
blocked_by: []
related_to: [F06-tdd, F07-gates]
---

## Description

Theme: **ownership.** Semantic types today conflate three owners in one place:
the universal vocabulary and its predicates (INSPIRE's), a project's own domain
types (the project's), and per-target rendering tables hardcoded in
`type-mapping.md` (the stack's). The emanation-loop design (D5, resolving the
brainstorm's A21) splits them three ways: the universal vocabulary + predicates
stay in the stack-agnostic runtime reference; project semantic types get a
dedicated seeded `00_bootstrap` file; per-target rendering moves into a new
**language profile** axis (`inspire-code/profiles/typescript.md` ships;
framework profiles declare `language: typescript`; projects add other
languages). A stack that declares no language profile is an
emanation-readiness refusal — never a silent generic emission — while attended
subcommands keep the never-block rule.

Filed as its own ticket per filing rule 1: the work crosses focus boundaries
(profile layer + bootstrap seeds + the reference), so it fits no open focus's
surface. Delivery vehicle: the emanation-loop epic (`feat-emanation-loop` →
release 0.8.0), profile-layer package T3; the readiness refusal is enforced by
the epic's `plan` tool.

## Acceptance criteria

- [ ] `profiles/typescript.md` carries the per-target rendering tables
      refactored out of `type-mapping.md`; the framework profiles declare
      `language:`.
- [ ] A seeded `00_bootstrap` file exists for project semantic types; the
      universal vocabulary stays in the runtime reference and the split is
      documented in `profiles/README.md`.
- [ ] A unit whose stack declares no language profile is refused at
      emanation-readiness with a report naming the missing profile.

## Notes

Source decisions: emanation-loop design doc D5 (rendering home), D6 (binding /
persistence conventions live in the same profile layer as seeds, freely edited,
never upgraded over). Closes when 0.8.0 ships T3, or independently if the epic
reshapes.

## Closed 2026-10-28 — shipped

Each criterion, checked against the tree at 0.12.1:

- [x] `inspire-code/profiles/typescript.md` carries the rendering, and
      `type-mapping.md` names the language profile as the home of every per-target
      answer. `react.md`, `nestjs.md` and `angular.md` declare `language:`.
- [x] `00_bootstrap/semantic-types.md` is seeded. `type-mapping.md` keeps the
      universal vocabulary, and `profiles/README.md` documents the three homes.
- [x] `PR-06` (`bin/lib/plan-checks.sh`, `plan_check_language`) refuses a unit
      whose framework profile reaches no language profile, and names the profile.

What the 2026-10-27 design review asked of semantic types beyond this split (overridable
defaults, a collection type, a support table) is `B3-overridable-types`.
