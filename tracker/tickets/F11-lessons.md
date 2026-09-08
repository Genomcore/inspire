---
id: F11-lessons
title: "F11 LESSONS — the loop closes where it was opened"
created: 2026-08-13
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: L
importance: Mid
skills: [lesson, workspace]
status: Open
blocked_by: []
related_to: []
---

## Description

Theme: **consumption.** Lesson capture is built and rigorous (write-once,
timestamp-named, version-stamped, upgrade-tested); consumption is zero — no skill, hook or
validator reads `98_lessons/` back, and the update skill explicitly refuses to. Close the
local loop: wire D6 classification into `/inspire:update` so `archive/` finally fills;
build the apply step (a lesson materializes into the skill it targets, behind a plan
gate); emit the per-skill changelog at release so absorption is detectable. Plus the cheap
data-loss fix: warn when a pre-0.3 `98_skill_learnings/` sits invisible beside the
current catalog.

## Acceptance criteria

- [ ] An upgrade classifies lessons (absorbed / untouched / partial / contradicted) and
      moves absorbed ones to `archive/`.
- [ ] `apply` materializes a lesson into its target skill with an operator-visible plan.
- [ ] Legacy `98_skill_learnings/` presence produces a warning.

## Notes

Hard dependency: F05-restruct seeds the capture triggers — without them the catalog never
accumulates the signal this loop closes on. **Discharged**: F05 shipped in 0.7.0
(`d93eb59` — the pointer blockquote in 13 skills plus
`_references/lesson-capture.md`, which `inspire-lesson` owns), so this ticket is
unblocked and the catalog is now accumulating. The upstream observer stays shelved: it needs
this local loop's output, plus infrastructure and an owner that do not exist. Bundles
LOOP-02..04 + LOOP-06.

## Notes from the 0.7.0 close (C5-P2)

### Observation

`inspire-lesson` captures lessons but nothing applies them. The half that makes a
lesson *materialized, not consulted* — writing it into the skill so the taught
behavior becomes the behavior — is unbuilt. The design exists: D5 and D6 of
`docs/adr/adr-runtime-lifecycle-and-lessons.md`.

### What the flow must do

- **`apply` reconciles a skill to `base + lessons`** — Terraform's desired-state
  model. A hand edit to a skill that was **not** captured as a lesson is **drift**,
  and is overwritten on the next apply. To persist a change, write the lesson.
- **Update is a rebuild, not a merge.** On a new release each lesson is classified
  against the new base:
  - **absorbed** — the base learned it; the lesson moves to `98_lessons/archive/`;
  - **untouched** — kept, and re-applied;
  - **partial** — superseded; a new lesson carries only the residual;
  - **contradicted** — the operator decides; local wins by default.
  The skill is then rebuilt as *new base + surviving lessons*.
- **Gated, not silent.** The rebuild runs behind a plan + drift-check gate.
- **The teaching debt shrinks every release**, as absorbed lessons leave the live
  catalog for the archive.

### Where it surfaced

C5-P2 (0.7.0). The section describing this flow lived in `inspire-lesson/SKILL.md`
as `## Materialization & updates (roadmap · v1)` and was removed: shipped skill
prose states what the runtime does now, and this describes what it does not do yet.
`references/lessons-format.md` § Archive keeps the archive semantics (it is an
on-disk contract, true whenever the flow lands), and both files now cite the ADR
by absolute URL because `docs/` is not materialized into a project.

### Suggested follow-up

Build `apply` + the update-time reconciliation behind the plan/drift-check gate,
then restore the operative prose to `inspire-lesson/SKILL.md` as present-tense
behavior — not as a roadmap.
