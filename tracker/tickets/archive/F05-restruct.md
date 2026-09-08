---
id: F05-restruct
title: "F5 RESTRUCT — rebuild the skills once, merge cost paid once"
created: 2026-08-13
updated: 2026-08-18
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-18
epic: roadmap
size: L
importance: Mid
skills: [bootstrap, module, feature, domain, screens, prototype, workspace, adr, task, code, surface, extract, lesson]
status: Done
blocked_by: []
related_to: [F04-mech, F11-lessons]
---

## Description

Theme: **the skills as artifact — rebuilt once.** The skills get the treatment the KB got.
Split the seven monolithic SKILL.md files (bootstrap 364, screens 337, feature 330, module
307, adr 207, prototype 144, spike 101 lines) into index + on-demand references — the
pattern `domain` and `code` already prove; dedupe the ~200 lines of copied boilerplate
(output-language blockquote ×14, stamp block ×7); seed lesson-capture triggers across all
14 skills (today the convention exists in exactly one); apply the Claude-5 authoring rules
to the older prose (the deferred retrofit).

## Acceptance criteria

- [x] No SKILL.md loads its full reference material upfront; boilerplate replaced by
      shared-reference links. — the five ≥300-line monoliths split (bootstrap 379→206,
      module 312→82, feature 308→94, screens 337→220, workspace 332→194 lines) into
      entry + references; adr/prototype/spike deliberately kept single-file (design
      scoped W1 to the five); boilerplate deduped to shared references.
- [x] All 14 skills carry the capture-trigger convention. — pointer blockquote ×13 +
      inspire-lesson owns the protocol itself in `_references/lesson-capture.md`.
- [x] Retrofit applied; behavior spot-verified per skill (the reason it was deferred). —
      Claude-5 rubric retrofit applied to all 14 (two waves, nothing descoped); behavior
      verified per flow class with defect-seeded fixtures (15/15 defects still caught
      post-edit).

## Notes

Everything here diverges every skill file at once — an upgrade then classifies them all;
batching means the operator's three-way merge cost is paid a single time. Schedule in a
quiet window after the contract wave (soft: after F04-mech). Hard prerequisite for
F11-lessons. Bundles CTX-04 + LOOP-01 + the Claude-5 retrofit.

Severity-grammar unification was descoped to F04 by the F05 spec's own fence.
