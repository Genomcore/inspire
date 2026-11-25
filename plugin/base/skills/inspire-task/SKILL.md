---
name: inspire-task
description: "Task tracker: create / update / close / list / show tickets in inspire_kb/99_tracker/. A plain-file kanban (one Markdown file per ticket, no external tool) for tracking work, drift, and skill-feedback. Use to open, advance, close, or query tickets."
---

# /inspire-task — Task tracker

## Scope

A plain-file ticket tracker under
`inspire_kb/99_tracker`: **one Markdown file
per ticket**, the only source of truth — no external tool, no generated cache. Only
open tickets live on disk, at `tickets/*.md`. Closing a ticket deletes its file, and git
history keeps it, so every scan sees only active work. A project that still has a
`tickets/archive/` folder from an earlier version keeps reading it until the operator
deletes it ([format reference](references/tracker-format.md) § Projects that still have
`tickets/archive/`).

The on-disk contract — storage layout, frontmatter schema, enums, ID scheme — lives
in [`references/tracker-format.md`](references/tracker-format.md). **Read it before
any subcommand that writes** (`create`, `update`, `close`).

## Invocation

- `/inspire-task create {title} [--epic X --size M --importance Mid --skills a,b]`
- `/inspire-task update TASK-{id} [--field value ...]`
- `/inspire-task close TASK-{id} [--cancelled --reason "..."]`
- `/inspire-task list [--status X --epic Y --skill prototype]` (read-only)
- `/inspire-task show TASK-{id}` (read-only)

## Subcommand: create {title} [--flags]

1. Resolve `@handle` from `git config user.email` (cached per session).
2. Resolve today's date from CLAUDE.md `currentDate` or `date +%Y-%m-%d`.
3. Generate a random 6-char base36 ID. Regenerate it while `tickets/TASK-{id}.md`
   exists or git history holds a file of that name (`git log --all --format=
   --name-only -- '*TASK-{id}.md'` prints anything).
4. Apply flags `--epic` (required), `--size` (default M), `--importance` (default
   Mid), `--skills` (comma-separated, default empty), `--status` (default Open),
   `--blocked-by`, `--related-to`.
5. Write the file with frontmatter + an empty `## Description` body (or `--body`).
6. Print the new ID to stdout.

## Subcommand: update TASK-{id} [--flags]

1. Resolve the ticket: `tickets/TASK-{id}.md`, else a closed ticket (format
   reference § Closed tickets). Error if neither.
2. Apply flag changes (validate against the enums in the format reference).
3. Set `updated` to today.
4. **Status transitions:**
   - New `status` ∈ {`Done`, `Cancelled`} on an open ticket → run `close`.
   - `status: Open` on a closed ticket → reopen it: write its last version back to
     `tickets/TASK-{id}.md` with `status: Open` and `closed_by` / `closed_at` set to
     `null`.
   - Otherwise, write in place.
5. Show a diff before saving.

## Subcommand: close TASK-{id} [--cancelled --reason "..."]

Closes an open ticket: `Done` by default, `Cancelled` with `--cancelled`.

1. **Delete the file.** Git history keeps the ticket; the closed ticket is never
   written back to disk.
2. **Drop the id from the other open tickets.** Remove `TASK-{id}` from every open
   ticket's `blocked_by` and `related_to`, set their `updated`, and, for a
   `blocked_by` entry, add a line to that ticket's `## Notes` saying the blocker closed.
3. **Propose the commit message** that records the close, since the file no longer
   can: `docs(tracker): close TASK-{id} — {Done|Cancelled}: {title}`, with the
   `--reason` text as its body. Committing stays the operator's call.

## Subcommand: list [--filter]

1. Scan `inspire_kb/99_tracker/tickets/*.md` (top-level, non-recursive). Parse
   frontmatter.
2. With `--all` (or its older name `--include-archived`), also list the closed tickets
   (format reference § Closed tickets), with the status their close commit gives.
3. Filters: `--status`, `--epic`, `--size`, `--importance`, `--reporter`,
   `--skill` (matches if `skills` contains the value), `--blocked`.
4. Print a compact table to stdout: `id | status | epic | size | importance |
   skills | title`.
5. Read-only.

## Subcommand: show TASK-{id}

Read `tickets/TASK-{id}.md`, else the closed ticket (format reference § Closed
tickets), and print frontmatter + body, saying when the ticket is closed. Read-only.

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

A ticket captures **local, actionable** friction. The ticket-vs-lesson routing and the
offer protocol live in
[`_references/lesson-capture.md`](../_references/lesson-capture.md); the rule for a
confirmed ticket **graduating** into a lesson lives in
[`inspire-lesson/SKILL.md`](../inspire-lesson/SKILL.md) § Relationship to the tracker.

## Rules

> **Output language.** Write ticket prose in the project's declared
> `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Machine-read
> tokens (frontmatter keys/values, enum values, `TASK-` IDs, filenames) stay
> verbatim.

> **Writing contract.** Ticket prose follows
> [`_references/writing-style.md`](../_references/writing-style.md).

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **One file per ticket.** Filename = `TASK-{id}.md`; the `id` field matches.
2. **IDs never reused.** `create` checks git history, so a closed ticket's id stays
   taken.
3. **Every ticket on disk is `Open`.** Closing deletes the file; reopening writes it
   back.
4. **`updated` is auto-managed.** Don't edit it by hand.
5. **`closed_by` / `closed_at` stay `null` on disk.** The close commit records who
   closed the ticket and when.
6. **Body markdown is free.** Description / Acceptance criteria / Notes suggested.
7. **Concurrent edits are safe** — random IDs, no locking.

## Related skills

- Every skill consults the tracker (`list`) at the start of multi-step work and
  files a **skill-feedback ticket** when a session surfaces friction.
- `/inspire-workspace structure` validates the tracker's on-disk invariants
  (every ticket on disk is `Open`, ID format, no duplicates).
