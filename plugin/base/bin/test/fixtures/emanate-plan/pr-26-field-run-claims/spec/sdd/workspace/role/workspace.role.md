---
id: workspace.role
module: workspace
entity: role
lifecycle: accepted
---

## Purpose
A named position in the platform's access model, per [[workspace-access]].

## Rationale
The position is its own object because [[adr-workspace-01-access]] separates it
from the grant that confers it.

## Invariants
- `I1` — A role grants nothing on its own. Only a membership grants access.
- `I2` — The catalog ships with the platform. No action writes it.

## Fields

| Field  | Type   | Notes              |
|--------|--------|--------------------|
| `id`   | uuid   | Primary key.       |
| `slug` | string | The stable handle. |

### id
Constraints: `nonnull, unique, immutable`

### slug
Constraints: `nonnull, len(3, 64)`

## Touched by

| Action | Touch | Notes |
|--------|-------|-------|
