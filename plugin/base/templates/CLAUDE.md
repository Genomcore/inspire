# {Project Name}

> **Provisional stub.** Seeded by `/inspire:init`. Run `/inspire-bootstrap init`
> to replace the placeholders below with this project's real name, purpose and
> stack — it edits this file in place rather than appending to it.

**Purpose:** <!-- TODO(/inspire-bootstrap init): one or two sentences on what this product does and for whom. -->

**Stack:** <!-- TODO(/inspire-bootstrap init): summary of inspire_kb/00_bootstrap/stack.md. -->

## This project is governed by INSPIRE

[INSPIRE](https://inspire.openbims.dev) is a specification-driven methodology:
intent is captured in a knowledge base, load-bearing decisions are recorded,
and code is generated from what is specified.

- **Knowledge base** — [`inspire_kb/`](inspire_kb/): `00_bootstrap` (project,
  stack, glossary) · `01_spec` (the specification, one directory per concept:
  global ADRs, the design system, modules with their features and
  machine-checkable domain model, bundles, faces with their screens, and
  processes) · `06_spikes` · `98_lessons` · `99_tracker`. Each folder has its
  own README. Every artifact has a typed extension (`*.module.md`,
  `*.entity.md`, `*.screen.md` …), and tools find it by that extension, never by
  its directory.
- **Skills** — the `inspire-*` slash commands (`inspire-bootstrap`,
  `inspire-module`, `inspire-feature`, `inspire-domain`, `inspire-face`,
  `inspire-screens`, `inspire-process`, `inspire-adr`, …) read and write it. Operate the
  KB through a skill rather than editing it by hand.
- **Validators** — `.inspire/bin/review.sh` checks the specification for
  mechanical and coherence errors; it is also callable from CI
  (`.inspire/bin/review.sh [scope]`, exit 0 clean / 1 on any error finding).
- **Runtime version** — `.inspire.lock` records which INSPIRE release this
  project was materialized from; `/inspire:update` refreshes it.

## How prose is written here

The writing contract —
[`.claude/skills/_references/writing-style.md`](.claude/skills/_references/writing-style.md)
— binds KB artifacts, operator-facing reports and replies in this project alike.
Five rules cover most of it:

- **State what is.** Not what an artifact was, not what it will be, not what it
  is not or will never be. A present-tense prohibition is a rule, not negative
  space, and it stays.
- **One sentence, one claim; one paragraph, one idea.** Length is only where to
  look.
- **Name the thing, not a figure of speech.** No metaphor, no intensifiers.
- **Say it once.** No paragraph restating the table above it.
- **Say each fact once, then stop.** Cut the prose, never the evidence.

`.inspire/bin/prose-style.sh` checks the greppable part at review time.

Haven't run it yet? Start with `/inspire-bootstrap init`.
