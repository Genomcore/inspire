---
name: inspire-learn
description: "Skill-learnings journal: capture durable, write-once, version-stamped insights about the inspire-* skills themselves in .inspire_kb/98_skill_learnings/, so a fork's improvements flow back upstream to INSPIRE core. One timestamp-named Markdown file per learning (YYYYMMDD_<slug>). Use to record a learning after skill friction or a local skill change, list / show them, or purge old ones. Not for product work — that is the tracker (inspire-task)."
---

# /inspire_learn — Skill-learnings journal

## Scope

The **self-learning layer** —
[`.inspire_kb/98_skill_learnings/`](../../../.inspire_kb/98_skill_learnings):
**one Markdown file per learning**, **write-once** (created once, never edited). A
learning is a durable, shareable insight about an `inspire-*` **skill itself** — not
about the product. Forks diverge from the template and rarely merge back; this layer
is the low-friction channel that carries a fork's skill improvements *back upstream* to
INSPIRE core, where they inform the next release. The fork only ever **writes**
learnings and is unaware of any central system — the read is always a pull from above.

Two properties make the org-wide sweep cheap and safe:

- **Timestamp-named** — files are `YYYYMMDD_<slug>.md`, so a sweep selects a
  date range by comparing the first 8 characters, without opening a single file.
- **Write-once** — a file below the sweep's date cursor can never have changed, so it
  is skipped forever; already-processed learnings are never re-worked.

Every learning also **freezes the INSPIRE version it was captured on** (from the root
`.inspire.lock`), so the central team can tell whether a newer release already
addressed it.

The on-disk contract — naming, write-once rules, frontmatter schema, enums, and the purge/sweep semantics — lives in
[`references/learnings-format.md`](references/learnings-format.md). **Read it before
`note` or `purge`.**

## When to capture a learning

Record one when a session surfaces something **generalizable about a skill**:

- the operator corrects how a skill behaved, in a way that should change the skill;
- a fork edits a skill locally (an `inspire-*/SKILL.md` under `.claude/skills/`) and
  the change is worth sending upstream (`local-override`);
- a recurring friction — an `AskUserQuestion` that should have a default, a step that
  always needs rework, drift from what the skill anticipated;
- a new pattern the skill doesn't cover but should.

If the signal is **local, actionable work** ("someone here should fix this"), file a
skill-feedback ticket with `inspire-task` instead. A confirmed ticket that generalizes
graduates into a learning (see *Relationship to the tracker*).

## Invocation

- `/inspire_learn note {title} [--skill X --category improvement --related a,b --supersedes id]`
- `/inspire_learn list [--since YYYYMMDD --until YYYYMMDD --skill X --category Z]` (read-only)
- `/inspire_learn show {id}` (read-only)
- `/inspire_learn purge [--months N | --before YYYYMMDD] [--confirm]`

## Subcommand: note {title} [--flags]

1. Resolve `@handle` from `git config user.email` (cached per session).
2. Resolve today's date from CLAUDE.md `currentDate` or `date +%Y-%m-%d`.
3. Read `inspire_version` + `template_sha` from `.inspire.lock` (repo root). If the
   lock is absent (e.g. running inside the template repo itself), fall back to
   `.inspire/manifest.json`; else record `unknown` and warn.
4. Build the filename `YYYYMMDD_<slug>.md`, where `<slug>` is a kebab-case short form
   of the title (~40 chars). Several learnings may share a date — the slug keeps each
   name distinct (filenames are unique within the folder by definition); pick a more
   specific slug if one would collide. `id` = the filename stem.
5. Apply flags: `--skill` (required — the skill the learning is about, or `runtime` for
   cross-cutting / methodology), `--category` (default `improvement`), `--related`
   (comma-separated IDs / wikilink targets), `--supersedes` (id of an earlier learning
   this revises).
6. Write the file **once** — frontmatter + the body skeleton (`## Trigger` ·
   `## Learning` · `## Local change` · `## Upstream suggestion`), filled from the
   conversation. There is no `status` and no `updated` field.
7. Print the new id to stdout.

> **Write-once.** After `note`, never edit the file. To revise, write a new learning
> with `--supersedes {old-id}`; the old one stays untouched.

## Subcommand: list [--filter]

1. Scan `.inspire_kb/98_skill_learnings/*.md`.
2. `--since` / `--until` filter on the **filename date prefix** (cheap — no frontmatter
   read). `--skill` / `--category` / `--reporter` filter on frontmatter.
3. Print a compact table to stdout: `date | category | skill | version | title`.
4. Read-only.

## Subcommand: show {id}

Read the file and print frontmatter + body. Read-only.

## Subcommand: purge [--months N | --before YYYYMMDD] [--confirm]

Local housekeeping — delete learnings older than a threshold (default `--months 6`),
matched on the **filename date prefix**. **Dry-run by default**: list exactly which
files would be removed and stop. Delete only when the operator passes `--confirm` (or
approves in the conversation). Old learnings have long since been read by the upstream
pull; deleted files remain recoverable from git history anyway. Purge only ever removes
whole files — it never edits one, so the write-once contract holds.

## Rules

> **Output language — the one exception.** Skill learnings are authored in **English**,
> whatever the project's `output_language` is: their reader is the cross-org INSPIRE
> core team, not the product team. Everything else in
> [`_references/output-language.md`](../_references/output-language.md) still holds —
> machine-read tokens stay verbatim.

1. **Write-once.** Never edit a learning after `note`. Revise by writing a new one with
   `--supersedes`; retire old ones only in bulk via `purge`.
2. **One file per learning**, named `YYYYMMDD_<slug>.md`; `id` = the stem.
3. **`inspire_version` / `template_sha` are frozen at capture** — the whole point is
   knowing which release a learning was based on.
4. **No `status`, no `updated`.** Processing state lives centrally, keyed by `id` and
   the date prefix — not inside the fork.
5. **A learning is about a skill, not the product.** Product work → `inspire-task`.
6. **Concurrent captures are safe** — distinct filenames, no locking, no shared
   mutation.

## Relationship to the tracker (`inspire-task`)

`99_tracker` skill-feedback tickets and `98_skill_learnings` nodes are two trackers for
two audiences: a ticket tracks **local, actionable** friction for this project's team;
a learning carries a **generalizable, version-stamped** insight to INSPIRE core. A
confirmed friction ticket graduates into a learning — the ticket tracks the local fix,
the learning links back with `[[TASK-…]]` and goes upstream.

## Related skills

- By convention, an `inspire-*` skill **offers** `/inspire_learn note` when the
  operator's feedback would change how the skill should behave — the operator decides
  when the insight is worth capturing (mirrors how skills surface skill-feedback tickets
  conversationally).
- `/inspire_task` handles the local, closeable side of the same feedback signal.
