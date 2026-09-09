---
id: 090-lesson-skill-adr-citations
title: "090 — `inspire-lesson` sends a project's operator to a harness-only ADR"
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
related_to: [090-lessons-readme-adr-link, F11-lessons]
---

## Description

Two shipped files cite `adr-runtime-lifecycle-and-lessons` by absolute GitHub URL:

| file | what it defers |
|---|---|
| `inspire-lesson/SKILL.md:23` | the flow that writes lessons into a skill and re-derives them against a new base — "its design is D5 and D6 of …" |
| `references/lessons-format.md:122` | archiving — "performed by the update flow that does not exist yet — its design is D6 of …" |

The URLs resolve, so nothing is broken. What is wrong is the layer. `docs/adr/` records
decisions about the **INSPIRE harness**; it never materializes, so a citation from the
payload asks a project's operator to leave their project and read the methodology's own
internals to learn why a skill they are holding does not do something. Anything we ship
explains itself where it ships — the relevant skill's `references/`, or the layer README.

This reverses a deliberate call. The 0.7.0 close (C5-P2, recorded in `F11-lessons`) cut
`## Materialization & updates (roadmap · v1)` from `SKILL.md` and noted that "both files
now cite the ADR by absolute URL because `docs/` is not materialized into a project." The
premise was right and the conclusion was the wrong half of it: not materialized means not
cited, not cited-by-URL.

## Acceptance criteria

- [ ] Neither `SKILL.md` nor `lessons-format.md` links into `docs/adr/`.
- [ ] What each sentence actually needs stays, in the skill's own references: that
      re-application and archiving are designed and unbuilt (so an operator writing a
      lesson today knows what does and does not happen to it), and the archive semantics
      `lessons-format.md` § Archive already owns as an on-disk contract.
- [ ] The prose stays present-tense about the runtime — the C5-P2 rule that removed the
      roadmap section in the first place is not undone by re-importing the roadmap in
      another form.
- [ ] The rule is written where the next author meets it: `CLAUDE.md`'s `docs/adr/` bullet
      says ADRs are about the harness itself and are never a destination for shipped
      payload; shipped explanation goes to the skill's `references/` or the layer README.
- [ ] No other file under `plugin/base/skills/` links into `docs/`; the sweep is one grep
      and its result is recorded here either way.

## Notes

F11's surface touches this — its suggested follow-up is to "restore the operative prose to
`inspire-lesson/SKILL.md` as present-tense behavior" once `apply` is built, which would
rewrite both sentences anyway. This stands alone under rule 1 regardless: F11 is an L-sized
focus about building a flow, this is a layering fix worth making whether or not that flow
is ever built, and if F11 lands first it absorbs this ticket rather than colliding with it.

The related sweep for the KB skeleton is `090-lessons-readme-adr-link`, where the same ADR
is cited by a relative path that resolves to nothing in a materialized project.
