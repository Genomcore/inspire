# Skill learnings — on-disk format

Learnings live as **one file per learning** under `.inspire_kb/98_skill_learnings/`,
and they are **write-once**: created once, never edited. The `.md` files are the only
source of truth — no generated index, no mutable status. "Already processed" is not a
field a fork toggles; it is decided centrally by the org sweep's date cursor (see
*Sweeping by date*).

## Storage layout & naming

- `.inspire_kb/98_skill_learnings/YYYYMMDD_<slug>.md` — one node per learning, flat.
  (No `learning_` infix — they are in the learnings folder by definition.)

The filename **starts with the capture date** (`YYYYMMDD`) so the org-wide sweep can
select a date range by string comparison on the first 8 characters alone — no need to
open the file or parse frontmatter:

```bash
# every learning captured on/after 2026-07-01, across all forks, without reading a
# single byte of frontmatter:
find . -path '*/98_skill_learnings/*.md' | awk -F/ '$NF >= "20260701"'
```

`<slug>` is a kebab-case short form of the title (~40 chars). Several learnings may
share the same date — the slug distinguishes them, and filenames are unique within the
folder by definition (POSIX), so no numeric disambiguation is added; pick a more
specific slug if one would ever collide.

## Write-once contract

A learning is an **immutable record of an observation**. Once written:

- **Never edit it** — not the body, not the frontmatter, not to "mark it done".
- To **revise or replace** one, write a *new* learning that sets `supersedes` to the
  old one's `id`. The old file stays exactly as it was.
- To **remove** old, already-harvested learnings in bulk, use `/inspire_learn purge`
  (age-based; removes whole files, never in-place edits).

This is what lets the central team trust that a learning it processed once will not
silently change underneath it.

## Frontmatter schema

```yaml
---
id: 20260722_tdd-reads-acceptance-criteria            # = filename stem
kind: skill-learning                                  # constant
title: tdd should re-read ADR acceptance criteria before writing tests
skill: code                        # which skill this is about (enum below)
category: improvement              # improvement | bug | friction | local-override | new-pattern
created: 2026-07-22                # YYYY-MM-DD — matches the filename date prefix
reporter: "@handle"                # git handle who captured it
inspire_version: "0.1.0"           # FROZEN at capture — from .inspire.lock
template_sha: "abe68b3"            # FROZEN at capture — from .inspire.lock
related_to: []                     # IDs / wikilink targets: [[TASK-…]], ADRs, features
supersedes: null                   # id of an earlier learning this revises, or null
---

## Trigger
...what surfaced it — the operator's correction, the friction, the local edit...

## Learning
...the generalizable insight — stated so INSPIRE core can act on it...

## Local change
...what this fork changed (if any); reference the diff / the edited skill file...

## Upstream suggestion
...how INSPIRE core could adopt it — the concrete change to the skill / runtime...
```

There is **no `status` and no `updated` field** — both would require mutation, which
write-once forbids. Lifecycle (proposed → processed → adopted) is tracked by the
central aggregator, keyed by `id` and the date prefix, not inside the fork.

## Enums

- **`skill`**: `bootstrap | module | feature | domain | screens | prototype | spike |
  adr | code | extract | task | workspace | learn`, or `runtime` for cross-cutting
  learnings (install, hooks, validators, the methodology itself).
- **`category`**:
  - `improvement` — the skill works, but could be better.
  - `bug` — the skill does the wrong thing.
  - `friction` — a recurring rough edge (a missing default, a needless prompt).
  - `local-override` — this fork changed the skill and the change is worth upstreaming.
  - `new-pattern` — something the skill doesn't cover but should.

## Version stamp

`inspire_version` + `template_sha` are copied from `.inspire.lock` (repo root, written
by `install.sh`) **at capture time** and, like everything else, never rewritten. They
let the central team answer "was this already addressed?" — by checking whether the
release that carries the fix is newer than the one the learning was based on. If the
lock is absent (e.g. inside the template repo), fall back to `.inspire/manifest.json`;
else record `unknown`.

## Sweeping by date (org level)

The external aggregator keeps a **date cursor** — the last capture date it ingested.
Each run it selects only files whose 8-char prefix is `>` the cursor (as shown above),
ingests them, and advances the cursor. Because learnings are write-once, a file below
the cursor can never have changed, so it is safe to skip forever — the sweep never
re-reads or re-processes old learnings.

## Purging (fork level)

`/inspire_learn purge` is local housekeeping — it deletes learnings older than a
threshold (default 6 months), matched on the date prefix. It is **dry-run by default**
and requires explicit confirmation to delete. Old learnings have long since been read
by the upstream pull; deleted files remain recoverable from git history anyway. Purge
only ever *removes whole files* — it never edits one, so the write-once contract holds.

## Consumption — the pull from upstream

The fork produces nothing beyond these files: no bundle, no push, no command that
contacts a remote. It is unaware that a central system exists. Consumption is always a
**pull from above** — INSPIRE core pulls a fork's repository and reads the raw
`98_skill_learnings/*.md` (frontmatter + body) plus the repo's `.inspire.lock`
directly. From the lock it learns the fork's runtime version; from each learning's
frozen `inspire_version` / `template_sha` it learns which release the observation was
based on.
