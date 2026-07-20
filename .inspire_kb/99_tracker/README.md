# 06 · Tracker

The project's **work tracker** — tickets and the work log. Known items live
here so they are surfaced as `(tracked: TASK-{id})` instead of being
re-discovered as new findings on every review.

- **Skill:** `inspire-workspace` (task subcommands — `task list`, `task
  create`, …).
- **Layout:**
  ```
  99_tracker/
    tickets/         # one file per ticket
    serve.mjs        # local Kanban server (node serve.mjs)
  ```

The tracker is cross-cutting: any skill that finds actionable work can file a
ticket here rather than blocking.
