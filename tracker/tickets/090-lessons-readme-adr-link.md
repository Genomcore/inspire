---
id: 090-lessons-readme-adr-link
title: "090 — the lessons layer README links to an ADR the project does not have"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [lesson]
status: Open
blocked_by: []
related_to: [090-lesson-skill-adr-citations, F11-lessons]
---

## Description

`plugin/base/kb/98_lessons/README.md:13` closes its first audience bullet with

> (materialization / update model — roadmap, v1; see
> [`docs/adr/adr-runtime-lifecycle-and-lessons`](../../docs/adr/adr-runtime-lifecycle-and-lessons.md))

The link is relative, and the file it sits in is **payload**: it materializes as
`inspire_kb/98_lessons/README.md`, from where `../../docs/adr/` resolves to a project's
own root — which holds no `docs/adr/`. Every governed project therefore ships a dead
link, and it is dead in the one direction that matters: the reader who follows it is the
operator asking why the catalog never re-applies.

`docs/adr/` is for the INSPIRE harness itself and does not materialize. Anything shipped
explains itself in the relevant skill's `references/` or in the layer README — here, the
README already has the floor and can simply say the thing.

## Acceptance criteria

- [ ] `98_lessons/README.md` no longer links into `docs/adr/`, by relative path or
      absolute URL.
- [ ] What the citation was carrying — that re-application across releases is designed
      but not built — is stated in the README's own words, or dropped as already implied
      by the "roadmap, v1" it sits beside.
- [ ] No other file under `plugin/base/kb/` links into `docs/`; the sweep is one grep and
      its result is recorded here either way.
- [ ] Ratifying part of the status quo closes this: if the sentence reads correctly with
      the parenthetical simply gone, deleting it is the fix and this closes **Done** with
      nothing written.

## Notes

The sibling case in the `inspire-lesson` skill is `090-lesson-skill-adr-citations`; it is
filed separately because it cites the same ADR *deliberately* and by working absolute
URL, so it is a layering decision to reverse rather than a broken path to repair.
