---
kind: bootstrap-stack
status: active
profiles: [react, nestjs]
wire_conventions: [rest]
---

# Tech stack

The stack this fixture's units are emanated under. It declares test
infrastructure and `nestjs` carries the probe recipe for it — so `PR-22` is
silent — but its `## Worktree recipe` is the skeleton's own empty table, so
nothing says how a fresh phase worktree reaches those components and `PR-24`
warns. A heading with no rows is the state a seeded project starts in, and it
has to read as absent rather than as a declared recipe of nothing.

## Language

- **TypeScript**, end to end.

## Wire conventions

| Decision | Answer |
|---|---|
| Existence leak | `404` |

## Test infrastructure

| Component | Purpose |
|---|---|
| `postgres` | the e2e database |

## Worktree recipe

| Step | Command |
|---|---|
