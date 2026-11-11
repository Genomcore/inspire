# Task tracker — on-disk format

Tickets live as **one file per ticket**. The `.md` files are the **only source of
truth** — no generated indexes or caches.

## Storage layout

- **Open tickets** → `inspire_kb/99_tracker/tickets/TASK-{id}.md`
- **Closed tickets** (`status` ∈ {`Done`, `Cancelled`}) →
  `inspire_kb/99_tracker/tickets/archive/TASK-{id}.md`

The archive subfolder keeps the active set lean: agents scanning "what's pending"
read only `inspire_kb/99_tracker/tickets/*.md` (top-level, non-recursive). `close`
moves the file; `show` / `update` look in `tickets/` first, then `tickets/archive/`.

## Frontmatter schema

```yaml
---
id: TASK-a3k7m2                    # 6 chars base36 random, must match filename
title: Add pagination to the agents list
created: 2026-05-07                # YYYY-MM-DD
updated: 2026-05-07                # auto-updated by skill on each change
reporter: "@handle"                # git handle
closed_by: null                    # @handle when status ∈ {Done, Cancelled}
closed_at: null                    # YYYY-MM-DD when status ∈ {Done, Cancelled}
epic: {module-or-area}             # see enum below
size: M                            # S | M | L | XL
importance: High                   # Very Low | Low | Mid | High | Very High
skills: [prototype, screens]            # which layer skills execute the work
status: Open                       # Open | Done | Cancelled
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
