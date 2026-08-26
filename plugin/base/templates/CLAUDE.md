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

- **Knowledge base** — [`inspire_kb/`](inspire_kb/), one numbered layer per
  concern: `00_bootstrap` (stack + design system) · `01_adr` (architecture
  decisions) · `02_modules` · `03_features` · `04_domain` (the
  machine-checkable domain model) · `05_screens` · `06_spikes` ·
  `98_lessons` · `99_tracker`. Each layer folder has its own README.
- **Skills** — the `inspire-*` slash commands (`inspire-bootstrap`,
  `inspire-module`, `inspire-feature`, `inspire-domain`, `inspire-screens`,
  `inspire-adr`, `inspire-code`, …) read and write these layers. Operate the
  KB through a skill rather than editing it by hand.
- **Validators** — `.inspire/bin/review.sh` checks the domain layer for
  mechanical and coherence errors; it is also callable from CI
  (`.inspire/bin/review.sh [scope]`, exit 0 clean / 1 on any error finding).
- **Runtime version** — `.inspire.lock` records which INSPIRE release this
  project was materialized from; `/inspire:update` refreshes it.

Haven't run it yet? Start with `/inspire-bootstrap init`.
