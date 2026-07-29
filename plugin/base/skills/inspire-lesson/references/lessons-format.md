# Lessons — on-disk format

Lessons live as **one file per lesson** under `inspire_kb/98_lessons/`, and they are
**write-once**: created once, never edited. The `.md` files are the only source of
truth — no generated index, no mutable status. "Already processed" is not a field a
fork toggles; it is decided centrally by the observer's date cursor (see *Sweeping by
date*).

## Storage layout & naming

- `inspire_kb/98_lessons/YYYYMMDD_<slug>.md` — one node per lesson, flat.
- `inspire_kb/98_lessons/archive/YYYYMMDD_<slug>.md` — lessons the base has since
  learned (moved here by an update; see *Archive*). Same naming, same write-once rule.

The filename **starts with the capture date** (`YYYYMMDD`) so the org-wide sweep can
select a date range by string comparison on the first 8 characters alone — no need to
open the file or parse frontmatter:

```bash
# every lesson captured on/after 2026-07-01, across all forks, without reading a
# single byte of frontmatter:
find . -path '*/98_lessons/*.md' -not -path '*/archive/*' | awk -F/ '$NF >= "20260701"'
```

`<slug>` is a kebab-case short form of the title (~40 chars). Several lessons may share
the same date — the slug distinguishes them, and filenames are unique within the folder
by definition (POSIX), so no numeric disambiguation is added; pick a more specific slug
if one would ever collide.

## The body — one line, atomic

The body is the **instruction that gets materialized into the skill**. Keep it to a
**single imperative line**:

```markdown
When generating a NestJS controller, keep DTOs in a separate file.
```

At most, add a negative and/or a support example. Only the instruction (and the `Not:`
line) is ever materialized — the **example is support only** (for the operator's review,
the update-time classifier, and the observer); an `apply` never writes it into the skill:

```markdown
When generating a NestJS controller, keep DTOs in a separate file.
Not: DTOs declared inline in the controller.

> Example: `user.dto.ts` beside `user.controller.ts`.
```

The one-line limit is the **atomicity guardrail**: a compound intent won't fit in one
imperative without obviously being two lessons — so write two. The "when" / trigger goes
**inside** the line, not in a separate section.

## Write-once contract

A lesson is an **immutable record**. Once written:

- **Never edit it** — not the body, not the frontmatter, not to "mark it done".
- To **revise or replace** one, write a *new* lesson that sets `supersedes` to the old
  one's `id`. The old file stays exactly as it was (an update may move it to `archive/`,
  but never edits it).
- To **remove** old, archived lessons in bulk, use `/inspire_lesson purge` (age-based;
  removes whole files, never in-place edits).

This is what lets the observer trust that a lesson it processed once will not silently
change underneath it.

## Frontmatter schema

```yaml
---
id: 20260722_nestjs-dtos-separate-file                # = filename stem
kind: lesson                                          # constant
title: NestJS controllers keep DTOs in a separate file
skill: code                        # which skill this lesson teaches (enum below)
category: preference               # preference | improvement | bug | friction | pattern
created: 2026-07-22                # YYYY-MM-DD — matches the filename date prefix
reporter: "@handle"                # git handle who captured it
inspire_version: "0.1.0"           # FROZEN at capture — from .inspire.lock
template_sha: "abe68b3"            # FROZEN at capture — from .inspire.lock
supersedes: null                   # id of an earlier lesson this revises, or null
related_to: []                     # IDs / wikilink targets: [[TASK-…]], ADRs, features
---

When generating a NestJS controller, keep DTOs in a separate file.
```

There is **no `status` and no `updated` field** — both would require mutation, which
write-once forbids. Processing state (proposed → distilled → adopted) is tracked by the
observer, keyed by `id` and the date prefix, not inside the fork.

## Enums

- **`skill`**: `bootstrap | module | feature | domain | screens | prototype | spike |
  adr | code | extract | task | workspace | lesson`, or `runtime` for cross-cutting
  lessons (install, hooks, validators, the methodology itself).
- **`category`** — why the lesson exists (descriptive, for the observer's clustering):
  - `preference` — a house convention / the way this project wants it done.
  - `improvement` — the skill works, but should do better here.
  - `bug` — the skill does the wrong thing.
  - `friction` — a recurring rough edge (a missing default, a needless prompt).
  - `pattern` — something the skill doesn't cover but should.

## Version stamp

`inspire_version` + `template_sha` are copied from `.inspire.lock` (repo root, written
by `materialize.sh`) **at capture time** and, like everything else, never rewritten. They
let the observer answer "was this already learned?" — by checking whether the release
that carries it is newer than the one the lesson was based on. If the lock is absent
(e.g. inside the template repo), fall back to `plugin/.claude-plugin/plugin.json`; else
record `unknown`.

## Archive

An update classifies each lesson against the new base. A lesson the base has **absorbed**
(now does natively) is moved verbatim into `98_lessons/archive/` — no longer taught to
new versions, but kept as durable provenance (and as confirmation, for the observer,
that a generalization landed). Archiving is a **move, never an edit**. A **partially**
absorbed lesson is superseded: the original moves to `archive/` and a new lesson carries
only the residual. (Archiving is performed by the v1 update flow — see
[`docs/adr/adr-runtime-lifecycle-and-lessons`](../../../../docs/adr/adr-runtime-lifecycle-and-lessons.md).)

## Sweeping by date (org level)

The observer keeps a **date cursor** — the last capture date it ingested. Each run it
selects only live-catalog files whose 8-char prefix is `>` the cursor (as shown above),
ingests them, and advances the cursor. Because lessons are write-once, a file below the
cursor can never have changed, so it is safe to skip forever — the sweep never re-reads
or re-processes old lessons.

## Purging (fork level)

`/inspire_lesson purge` is local housekeeping — it deletes **archived** lessons older
than a threshold (default 6 months), matched on the date prefix. It is **dry-run by
default** and requires explicit confirmation to delete. It is fully optional: archived
lessons have already been read by the observer, and deleted files remain recoverable
from git history anyway. Purge only ever *removes whole files* — it never edits one, so
the write-once contract holds.

## Consumption — the pull from the observer

The fork produces nothing beyond these files: no bundle, no push, no command that
contacts a remote. It is unaware that a central system exists. Consumption is always a
**pull from above** — the observer pulls a fork's repository and reads the raw
`98_lessons/*.md` (frontmatter + body) plus the repo's `.inspire.lock` directly. From
the lock it learns the fork's runtime version; from each lesson's frozen
`inspire_version` / `template_sha` it learns which release the lesson was based on.
