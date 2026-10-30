# Self-improving skills: from a complaint to a rule that holds

Status: **draft**, for discussion. Nothing here is built yet.

## Goal

When a person complains about code the agents wrote, two things should follow without
anyone rewriting a skill by hand:

1. **The complaint does not happen again** in the next run.
2. **The skill learns it**, so the agent gets it right the first time instead of being
   caught and repaired.

The first is a guard and the second is learning. They are separate on purpose: the guard
is cheap and works on day one, and learning is expensive and only pays off at volume.

## What already exists

| Piece | Where | What it gives this design |
|---|---|---|
| Lessons | `inspire_kb/98_lessons/`, skill `inspire-lesson` | A complaint already has a home: a write-once, one-line imperative about how a skill must behave here, version-stamped. The flow that writes lessons *into* the skills is not built yet (the skill says so). |
| Friction tickets | `99_tracker`, skill `inspire-task` | A recurring friction ticket already *graduates* into a lesson. |
| Review checks | INSPIRE Factory, `.inspire/emanate.yml` | `review: { skills, read, focus, min_confidence }` runs a read-only reviewer over a unit's diff. A failing check sends the unit to repair. `read:` can point at any file of the project. |
| Run checks | INSPIRE Factory, `.inspire/emanate.yml` | Mechanical checks (lint, tests, a grep) that gate a merge. |
| The bench | `inspire-bench` | Runs a case end to end and counts rule compliance with greps. The MUST rewrite of the stack skills (PR #64) was a manual pass of exactly this loop: change a rule, run the bench, keep it only where it improved. |
| SkillOpt | `microsoft/SkillOpt` (MIT) | Treats a skill document as trainable text: rollouts → an optimizer proposes bounded edits → an edit is kept only if a held-out score strictly improves. A trial on one unit is running (see below). |

## Design

### 1. Capture: a complaint becomes a lesson with a check

A complaint is captured with `/inspire-lesson note`, as today. The new part is that a lesson
may carry **how to tell it was broken**, written once at capture like the rest of the lesson:

```yaml
---
id: 20261028_nestjs-no-try-catch-in-controllers
kind: lesson
title: NestJS controllers never catch exceptions
skill: inspire-code-nestjs
category: bug
check:
  grep: { pattern: '\btry\s*\{', paths: 'source/src/**/*.controller.ts', expect: absent }
---

A controller MUST NOT contain try/catch; map domain errors in an exception filter.
```

- `check.grep` is a mechanical check. It is preferred whenever the complaint can be stated
  as one, because it is cheap and deterministic.
- `check.review` is a question for the reviewer, for what needs judgement ("the component
  does not call the HTTP client directly").
- No `check` at all is legal. Such a lesson still teaches, but nothing guards it.

### 2. Guard: the Factory refuses a unit that repeats a lesson

Every lesson with a check runs on every unit:

- the `grep` checks as one run check, next to lint and the tests;
- the `review` checks as one review check that reads the lessons
  (`read: [inspire_kb/98_lessons]`, `focus:` "the diff repeats none of these lessons").

A unit that repeats a complaint fails the check and goes to repair in the same run. This
alone meets goal 1, and it needs no change to any skill.

Cost: review checks are slow. In the bench, a52 (eight review checks) took 94 min against
36 min for a53 without them. Every complaint that fits a grep should be a grep.

### 3. Learn: the lessons are written into the skill

The guard catches a repeat after the fact. Learning moves the rule into the skill, so the
check rarely fires. Two ways, chosen by volume:

| | Assisted rewrite | SkillOpt |
|---|---|---|
| When | A few complaints a week, one or two skills | Many complaints across skills and projects, where fixing one breaks another |
| How | An agent turns the lesson into an edit of the skill; a bench run validates it; a person reviews the PR | The lesson checks are the score; SkillOpt optimizes the skill against all of them at once on bench units, and the gate keeps an edit only if it helps |
| Cost | Minutes of a person, one bench run | Many unit runs (20–40 min each with Opus) |

The assisted rewrite is the starting point. SkillOpt becomes an option once the lesson
checks are numerous enough to be a score worth optimizing; at that point it needs no new
artifact, because the checks it would optimize against already exist.

The result of either way is an ordinary PR to the skill, reviewed by a person. Nothing
changes a skill unattended.

## Open questions

1. **`skill:` enum.** It still lists `code`, which 0.13.0 removes. A lesson about a stack
   rule must name the stack skill (`inspire-code-nestjs`) or a stack id (`nestjs`). Which?
2. **Where the check lives.** In the lesson's frontmatter (one file, write-once) or in a
   separate checks file (editable when a pattern turns out wrong)? A wrong grep in a
   write-once file can only be fixed by superseding the lesson.
3. **Lesson language for the reviewer.** Lessons are authored in English for the observer.
   The reviewer reads them as-is; does a check written for one project leak into
   another's review through the observer?
4. **Gaming the check.** An optimizer that sees the raw check ("`SwaggerModule.setup(` not
   found") tends to write rules that satisfy the grep, not the intent. SkillOpt-Sleep feeds
   its optimizer a description of the rule instead of the check. We should do the same.
5. **Noise.** One run of the same configuration varies (a47 vs a49: 73 vs 69 min, 8 vs 9
   attempts). A learning gate on one rollout can accept luck. How many repeats per
   evaluation?
6. **Re-applying on update.** `/inspire:update` replaces a shipped skill. A lesson written
   into it must survive the next release: this is the re-application flow the lessons
   README already names as missing.

## SkillOpt trial

Running on `samples.sample.create` (simple-case, branch `bench/a57-skillopt-nestjs` at
`5121482`), Opus 5.5 high in both roles:

- Seed: the `inspire-code-nestjs` body from a53, before the MUST rewrite.
- Score: 11 checks: lint, typecheck, unit and e2e tests, claim citations, and the six nestjs
  rules the bench measures. Validated against what the a56 agent produced for this unit
  (11/11, the same 33 files).
- Question: does SkillOpt find on its own what the MUST rewrite found by hand (Swagger,
  `/api/docs`, no try/catch), and are its edits rules or grep-shaped tricks?

Result: _pending_.

## Phases

1. Lesson `check:` field and its schema in `lessons-format.md`; `skill:` enum fixed.
2. Factory: one run check for the `grep` checks and one review check for the `review`
   checks, both generated from `inspire_kb/98_lessons/`.
3. Assisted rewrite: a command that turns lessons into a skill PR and runs the bench on it.
4. Only if volume calls for it: SkillOpt with the lesson checks as its score.
