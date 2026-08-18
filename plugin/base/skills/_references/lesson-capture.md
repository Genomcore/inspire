# Lesson capture (shared reference)

Every `inspire-*` skill except `inspire-lesson` itself follows the same offer
protocol, defined once here rather than thirteen times.

## The offer

At a natural pause, when the operator's feedback should durably change how
this skill behaves, offer `/inspire_lesson note`. **Never auto-write a
lesson** — the skill only ever proposes; the operator decides what is worth
keeping.

The situations worth an offer are not enumerated here: the owning skill's
five-bullet list is the only list, in
[`inspire-lesson/SKILL.md`](../inspire-lesson/SKILL.md) § When to capture a
lesson.

## Ticket vs. lesson

One routing decision: local, actionable work ("someone here should fix this")
gets a ticket via [`inspire-task/SKILL.md`](../inspire-task/SKILL.md); an
instruction that should durably change how a skill behaves gets a lesson via
[`inspire-lesson/SKILL.md`](../inspire-lesson/SKILL.md). A confirmed ticket can
later graduate into a lesson — the full rule lives in
[`inspire-lesson/SKILL.md`](../inspire-lesson/SKILL.md) § Relationship to the
tracker.

## Authority

This file owns only the offer protocol above. When to capture, atomicity, and
the on-disk format are `inspire-lesson`'s authority, not this file's.
