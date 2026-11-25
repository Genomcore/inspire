# Task tracker — on-disk format

Tickets live as **one file per ticket**. The `.md` files are the **only source of
truth** — no generated indexes or caches.

## Storage layout

- **Open tickets** → `inspire_kb/99_tracker/tickets/TASK-{id}.md`
- **Closed tickets** (`status` ∈ {`Done`, `Cancelled`}) are deleted. Git history keeps
  them.

Agents scanning "what's pending" read `inspire_kb/99_tracker/tickets/*.md`
(top-level, non-recursive), and everything they find is open.

### Closed tickets

A closed ticket is read from git history, never from disk:

- **Its last version:** find the commit that deleted it, `git log -1
  --diff-filter=D --format=%H -- inspire_kb/99_tracker/tickets/TASK-{id}.md`, and read
  `git show {commit}^:inspire_kb/99_tracker/tickets/TASK-{id}.md`.
- **Its status and reason:** the message of that commit (`close` proposes
  `docs(tracker): close TASK-{id} — {Done|Cancelled}: {title}`).
- **Every closed ticket:** `git log --diff-filter=D --name-only --format= --
  inspire_kb/99_tracker/tickets/`, less the ids that are on disk again (reopened).

### Projects that still have `tickets/archive/`

Earlier versions moved closed tickets to `inspire_kb/99_tracker/tickets/archive/`.
While that folder exists, its files count as closed tickets too: `show`, `update` and
`list --all` read them there first. The first time `inspire-task` finds the folder in a
session, it offers to delete it (`git rm -r`), since git history keeps every file, and
deletes it only on the operator's yes.

## Frontmatter schema

```yaml
---
id: TASK-a3k7m2                    # 6 chars base36 random, must match filename
title: Add pagination to the agents list
created: 2026-05-07                # YYYY-MM-DD
updated: 2026-05-07                # auto-updated by skill on each change
reporter: "@handle"                # git handle
closed_by: null                    # stays null: a closed ticket is deleted
closed_at: null                    # stays null: a closed ticket is deleted
epic: {module-or-area}             # see enum below
size: M                            # S | M | L | XL
importance: High                   # Very Low | Low | Mid | High | Very High
skills: [prototype, screens]            # which layer skills execute the work
status: Open                       # Open on disk; Done | Cancelled name a close
blocked_by: []                     # list of ticket / feature / ADR IDs
related_to: [TASK-xxx]             # list of IDs
# faces: [id-a]                    # optional — face ids; omit = the whole project; see enum below
# bundles: [id-b]                  # optional — bundle ids; omit = the whole project
---

## Description
...free body markdown; suggested: Description / Acceptance criteria / Notes...
```

## Enums

- **`epic`**: a **project-defined** slug — usually a module from
  `inspire_kb/01_spec/` (a `*.module.md`'s id), plus cross-cutting areas. Recommended baseline:
  `workspace | meta | tooling | docs | skill-feedback`, extended with the
  project's own module slugs.
- **`size`**: `S | M | L | XL`
- **`importance`**: `Very Low | Low | Mid | High | Very High`
- **`status`**: `Open | Done | Cancelled` — there is no in-flight state. `Open` =
  not yet done, `Done` = completed and verified, `Cancelled` = won't do (reason in
  body).
- **`skills`** (multi-select, may be empty): `bootstrap | module | feature |
  domain | process | screens | prototype | workspace | adr | task | code | face |
  config` — which
  skills cover the work. `[]` means the work doesn't map to a skill (tooling, ops,
  packaging).
- **`faces`** / **`bundles`**: optional — lists of face ids (`*.face.md`) and bundle
  ids (`*.bundle.md`); useful for filtering work by application or API, never
  required. Absent means the whole project. Semantics per
  [`_references/face-scope.md`](../../_references/face-scope.md).

## ID scheme

Format: `TASK-` + 6 chars from `[a-z0-9]` (base36). Example: `TASK-a3k7m2`.

- **Generation:** random. 36⁶ ≈ 2.18B combinations; collision at 10k tickets ≈ 10⁻⁵.
- **Defense in depth:** before writing, verify the file doesn't exist; regenerate
  on the improbable collision.
- **Concurrency:** no coordination needed — random IDs effectively never collide.
- **Stable forever:** cancelled tickets keep their ID; IDs are never reused.
