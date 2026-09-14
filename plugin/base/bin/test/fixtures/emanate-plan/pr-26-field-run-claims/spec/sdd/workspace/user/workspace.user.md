---
id: workspace.user
module: workspace
entity: user
lifecycle: accepted
---

## Purpose
The staff record every actor in the suite resolves to, per [[workspace-access]].

## Rationale
Staff are a discrete object because [[adr-workspace-01-access]] scopes every
actor to one row here.

## Invariants
- `I1` — Every staff reference in the suite resolves to a row here.
- `I2` — An unassigned role is the absence of an assignment row, never a sentinel user.

## Fields

| Field   | Type  | Notes                |
|---------|-------|----------------------|
| `id`    | uuid  | Primary key.         |
| `email` | email | The identity handle. |

### id
Constraints: `nonnull, unique, immutable`

### email
Constraints: `nonnull, pattern(/^[a-z]{3,8}@.+$/)`

## Touched by

| Action | Touch | Notes |
|--------|-------|-------|
