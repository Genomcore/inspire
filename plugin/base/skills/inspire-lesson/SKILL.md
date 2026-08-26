---
name: inspire-lesson
description: "Lessons catalog: capture durable, write-once, version-stamped LESSONS that change how an inspire-* skill behaves in this project — each a single one-line instruction (\"do X this way\"), materialized into the skill so the agent internalizes it. One timestamp-named file per lesson (YYYYMMDD_<slug>) in inspire_kb/98_lessons/. A lesson is relevant HERE; whether it generalizes is decided upstream. Use to record a lesson after skill friction or a deliberate skill change, list / show them, or purge the archive. Not for product work — that is the tracker (inspire-task), nor for spike/prototype learnings."
---

# /inspire-lesson — Lessons catalog

## Scope

The **self-teaching layer** —
[`inspire_kb/98_lessons/`](../../../inspire_kb/98_lessons): **one Markdown file
per lesson**, **write-once** (created once, never edited). A lesson is a durable,
transmissible instruction about how an `inspire-*` **skill itself** should behave —
not about the product. It can be *learned* or *taught*; the folder is a **catalog of
lessons** this project holds.

Two audiences read the catalog:

1. **This project, across releases** — the catalog is what keeps the agents behaving
   as you taught them once a release moves the base underneath them. The flow that
   writes lessons into a skill, and re-derives them against a new base, is **not
   built**: its design is D5 and D6 of
   [`adr-runtime-lifecycle-and-lessons`](https://github.com/Genomcore/inspire/blob/main/docs/adr/adr-runtime-lifecycle-and-lessons.md),
   and building it is future work the operator tracks. Capturing still pays now —
   a lesson written today is one that flow will find.
2. **INSPIRE core, via the observer** — an external pull-from-above reads the catalog
   across many forks and distills the patterns worth folding into the next release.
   The fork only ever **writes** lessons and is unaware of any central system.

Two properties keep the org-wide sweep cheap and safe:

- **Timestamp-named** — files are `YYYYMMDD_<slug>.md`, so a sweep selects a date
  range by comparing the first 8 characters, without opening a file.
- **Write-once** — a file below the sweep's date cursor can never have changed, so it
  is skipped forever; already-processed lessons are never re-worked.

Every lesson **freezes the INSPIRE version it was captured on** (from the root
`.inspire.lock`), so the observer can tell whether a newer release already learned it.

The on-disk contract — naming, the one-line body format, write-once rules, frontmatter
schema, enums, archive + purge semantics — lives in
[`references/lessons-format.md`](references/lessons-format.md). **Read it before `note`
or `purge`.**

## What a lesson is

- **One line, atomic.** The body is a single imperative — *"When generating a NestJS
  controller, keep DTOs in a separate file."* At most a positive/negative pair (*do
  this* / *not that*), plus an optional **example as support only**. The one-line limit
  *enforces* atomicity: you cannot pack two intents into one imperative without it
  obviously being two lessons. This keeps the catalog small and every lesson easy to
  reason about — and makes update-time reconciliation clean.
- **Relevant here, not "upstream-worthy."** You capture a lesson because it matters to
  **you, in this project** — never because you have judged it generalizable. Whether it
  generalizes is decided **upstream**, by the observer, from the pattern many forks'
  lessons form. Capture asks only *"is this worth keeping?"*
- **Materialized, not consulted.** The intent is that a lesson is written *into* the
  skill so the taught behavior **becomes** the behavior — the agent acts on it, it does
  not check a footnote and apply it if it happens to notice. The model is Terraform's
  **desired state**: the lessons are the source of truth a run declares, and the skill
  file is the result it reconciles to them.

## When to capture a lesson

Record one when a session surfaces something **you want the skill to keep doing (or
stop doing)**:

- the operator corrects how a skill behaved, in a way that should stick;
- a deliberate local change to how an `inspire-*` skill works;
- a recurring friction — an `AskUserQuestion` that should have a default, a step that
  always needs rework, drift from what the skill anticipated;
- a house convention or preference the skill should honor;
- a pattern the skill doesn't cover but should.

If the signal is **local, actionable work** ("someone here should fix this"), file a
skill-feedback ticket with `inspire-task` instead. A confirmed ticket that should change
how a skill behaves graduates into a lesson (see *Relationship to the tracker*).

## Invocation

- `/inspire-lesson note {title} [--skill X --category preference --supersedes id]`
- `/inspire-lesson list [--since YYYYMMDD --until YYYYMMDD --skill X --category Z]` (read-only)
- `/inspire-lesson show {id}` (read-only)
- `/inspire-lesson purge [--months N | --before YYYYMMDD] [--confirm]`

## Subcommand: note {title} [--flags]

1. Resolve `@handle` from `git config user.email` (cached per session).
2. Resolve today's date from CLAUDE.md `currentDate` or `date +%Y-%m-%d`.
3. Read `inspire_version` + `template_sha` from `.inspire.lock` (repo root). If the
   lock is absent (e.g. inside the template repo itself), fall back to
   `plugin/.claude-plugin/plugin.json`; else record `unknown` and warn.
4. Build the filename `YYYYMMDD_<slug>.md`, where `<slug>` is a kebab-case short form
   of the title (~40 chars). Several lessons may share a date — the slug keeps each
   name distinct; pick a more specific slug if one would collide. `id` = the filename
   stem.
5. Apply flags: `--skill` (required — the skill the lesson teaches, or `runtime` for
   cross-cutting / methodology), `--category` (default `preference`), `--supersedes`
   (id of an earlier lesson this revises).
6. **Draft the one-line instruction with the operator and confirm it.** Keep it to a
   single imperative; add the optional `Not:` negative and a `> Example:` support line
   only if they genuinely help. Write the file **once** — frontmatter + the one-line
   body (see [`references/lessons-format.md`](references/lessons-format.md)).
7. Print the new id to stdout.

> **Write-once.** After `note`, never edit the file. To revise, write a new lesson with
> `--supersedes {old-id}`; the old one stays untouched.

## Subcommand: list [--filter]

1. Scan `inspire_kb/98_lessons/*.md` (the live catalog; `--archived` also scans
   `98_lessons/archive/`).
2. `--since` / `--until` filter on the **filename date prefix** (cheap — no frontmatter
   read). `--skill` / `--category` / `--reporter` filter on frontmatter.
3. Print a compact table to stdout: `date | category | skill | version | instruction`.
4. Read-only.

## Subcommand: show {id}

Read the file and print frontmatter + body. Read-only.

## Subcommand: purge [--months N | --before YYYYMMDD] [--confirm]

Local housekeeping — delete **archived** lessons (those the base has already learned,
under `98_lessons/archive/`) older than a threshold (default `--months 6`), matched on
the **filename date prefix**. **Dry-run by default**: list exactly which files would be
removed and stop. Delete only when the operator passes `--confirm` (or approves in the
conversation). Purge is **fully optional** — the archive is durable provenance, and
deleted files remain recoverable from git history. Purge only ever removes whole files;
it never edits one, so the write-once contract holds. (Until the update flow exists,
`archive/` is empty and purge is a no-op — archiving is populated by an update.)

## Rules

> **Output language — the one exception.** Lessons are authored in **English**,
> whatever the project's `output_language` is: their reader is the observer / the
> cross-org INSPIRE core team, not the product team. Everything else in
> [`_references/output-language.md`](../_references/output-language.md) still holds —
> machine-read tokens stay verbatim.

> **Writing contract.** Lessons follow
> [`_references/writing-style.md`](../_references/writing-style.md) in full. Because
> lessons are always `en`, R1–R6 apply here whatever the fork's `output_language` is.
> The mechanical checks follow the *project's* declared language, so in a non-`en` fork
> this contract lives entirely in your judgment. Atomicity is this layer's own local
> rule, Rule 3 below.

1. **Write-once.** Never edit a lesson after `note`. Revise by writing a new one with
   `--supersedes`; retire old ones only in bulk via `purge` on the archive.
2. **One file per lesson**, named `YYYYMMDD_<slug>.md`; `id` = the stem.
3. **One line, atomic.** The body is a single imperative (+ optional `Not:` / example);
   split anything compound into separate lessons.
4. **`inspire_version` / `template_sha` are frozen at capture** — the whole point is
   knowing which release a lesson was based on.
5. **No `status`, no `updated`.** Processing state lives centrally, keyed by `id` and
   the date prefix — not inside the fork.
6. **A lesson is about a skill, not the product.** Product work → `inspire-task`. Spike
   / prototype **learnings** are a different thing (product insight) — not lessons.
7. **Concurrent captures are safe** — distinct filenames, no locking, no shared mutation.

## Relationship to the tracker (`inspire-task`)

`99_tracker` skill-feedback tickets and `98_lessons` nodes are two records for two
audiences, and which signal goes where is the routing stated once in
[`_references/lesson-capture.md`](../_references/lesson-capture.md) § Ticket vs. lesson
— applied above under *When to capture a lesson*.

What this section owns is the **graduation**. A friction ticket the team has confirmed,
and that should durably change how a skill behaves, becomes a lesson: the ticket keeps
tracking the local fix, while the new lesson carries the instruction and links back
with `[[TASK-…]]`. Both records stay: the ticket is the local work, and the lesson is
what the skill learns from it — and, via the observer, what INSPIRE core may learn.

## Related skills

- The offer protocol the other skills follow lives in
  [`_references/lesson-capture.md`](../_references/lesson-capture.md) — they offer
  `/inspire-lesson note`; the operator decides.
- `/inspire-task` handles the local, closeable side of the same feedback signal.
