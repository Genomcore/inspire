---
name: inspire-task
description: "Task tracker: create / update / close / list / show tickets in .inspire_kb/99_tracker/. A plain-file kanban (one Markdown file per ticket, no external tool) for tracking work, drift, and skill-feedback. Use to open, advance, close, or query tickets."
---

# /inspire_task — Task tracker

## Scope

A plain-file ticket tracker under
[`.inspire_kb/99_tracker/`](../../../.inspire_kb/99_tracker): **one Markdown file
per ticket**, the only source of truth — no external tool, no generated cache. Open
tickets live at `tickets/*.md`; closed ones are archived under `tickets/archive/*.md`
so default scans see only active work. A read-only Kanban web view is available via
`node .inspire_kb/99_tracker/serve.mjs`.

The on-disk contract — storage layout, frontmatter schema, enums, ID scheme — lives
in [`references/tracker-format.md`](references/tracker-format.md). **Read it before
any subcommand that writes** (`create`, `update`, `close`).

## Invocation

- `/inspire_task create {title} [--epic X --size M --importance Mid --skills a,b]`
- `/inspire_task update TASK-{id} [--field value ...]`
- `/inspire_task close TASK-{id} [--cancelled --reason "..."]`
- `/inspire_task list [--status X --epic Y --skill prototype]` (read-only)
- `/inspire_task show TASK-{id}` (read-only)

## Subcommand: create {title} [--flags]

1. Resolve `@handle` from `git config user.email` (cached per session).
2. Resolve today's date from CLAUDE.md `currentDate` or `date +%Y-%m-%d`.
3. Generate a random 6-char base36 ID; verify the file doesn't exist; regenerate
   if it does.
4. Apply flags `--epic` (required), `--size` (default M), `--importance` (default
   Mid), `--skills` (comma-separated, default empty), `--status` (default Open),
   `--blocked-by`, `--related-to`.
5. Write the file with frontmatter + an empty `## Description` body (or `--body`).
6. Print the new ID to stdout.

## Subcommand: update TASK-{id} [--flags]

1. Resolve the ticket path (`tickets/` then `tickets/archive/`). Error if neither.
2. Apply flag changes (validate against the enums in the format reference).
3. Set `updated` to today.
4. **Status transitions move the file:**
   - New `status` ∈ {`Done`, `Cancelled`} and file in `tickets/` → write to
     `tickets/archive/` and remove the original; fill `closed_by` / `closed_at`.
   - Back to `Open` from `tickets/archive/` → write to `tickets/`; clear
     `closed_by` / `closed_at`.
   - Otherwise, write in place.
5. Show a diff before saving.

## Subcommand: close TASK-{id} [--cancelled --reason "..."]

Shortcut that transitions an open ticket to a closed status and archives it:
default `status: Done`; with `--cancelled`, `status: Cancelled` (append a
`## Cancellation reason` if `--reason` given). Sets `closed_by` / `closed_at` /
`updated`, and **moves the file** to `tickets/archive/`.

## Subcommand: list [--filter]

1. Scan `.inspire_kb/99_tracker/tickets/*.md` (top-level, non-recursive — excludes
   `archive/`). Parse frontmatter.
2. With `--include-archived` (or `--all`), also scan `tickets/archive/*.md`.
3. Filters: `--status`, `--epic`, `--size`, `--importance`, `--reporter`,
   `--skill` (matches if `skills` contains the value), `--blocked`.
4. Print a compact table to stdout: `id | status | epic | size | importance |
   skills | title`.
5. Read-only.

## Subcommand: show TASK-{id}

Read the file (`tickets/` then `tickets/archive/`) and print frontmatter + body.
Read-only.

## Skill-feedback tickets (convention)

When a skill's usage produces a friction signal worth capturing — operator
pushback, a recurring `AskUserQuestion` that should default, drift from what the
skill anticipated — file a standard ticket:

```yaml
epic: skill-feedback
skills: [<source-skill>]
size: S
importance: Low
```

**Title format:** `{skill-name}: <short friction observation>`. **Body:**
`## Observation` · `## Where it surfaced` · `## Suggested follow-up`. It reuses
standard ticket infrastructure — no new tooling; the operator decides when an
observation deserves a ticket, and skills surface candidates conversationally.

## Rules

> **Output language.** Write ticket prose in the project's declared
> `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Machine-read
> tokens (frontmatter keys/values, enum values, `TASK-` IDs, filenames) stay
> verbatim.

1. **One file per ticket.** Filename = `TASK-{id}.md`; the `id` field matches.
2. **IDs never reused.** Don't delete files — archive them.
3. **Open vs archived location is derived from `status`.** Keep the location
   consistent with `status` on every transition.
4. **`updated` is auto-managed.** Don't edit it by hand.
5. **`closed_by` / `closed_at` only when status ∈ {Done, Cancelled}.**
6. **Body markdown is free.** Description / Acceptance criteria / Notes suggested.
7. **Concurrent edits are safe** — random IDs, no locking.
8. **Server is read-only.** `.inspire_kb/99_tracker/serve.mjs` never writes; it
   scans both `tickets/` and `tickets/archive/`.

## Related skills

- Every skill consults the tracker (`list`) at the start of multi-step work and
  files a **skill-feedback ticket** when a session surfaces friction.
- `/inspire_workspace structure` validates the tracker's on-disk invariants
  (location ↔ status, ID format, no duplicates).
