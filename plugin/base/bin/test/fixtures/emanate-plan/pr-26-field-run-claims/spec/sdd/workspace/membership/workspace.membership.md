---
id: workspace.membership
module: workspace
entity: membership
lifecycle: accepted
---

## Purpose
The grant that confers a position on a staff row, per [[workspace-access]].

## Rationale
The grant is its own object because [[adr-workspace-01-access]] separates it
from the position it confers.

## Invariants
- `I1` — unique(user_id, role_id) — One grant per position per staff row.

## Fields

| Field     | Type | Notes                  |
|-----------|------|------------------------|
| `id`      | uuid | Primary key.           |
| `user_id` | uuid | The staff row granted. |
| `role_id` | uuid | The position granted.  |

### id
Constraints: `nonnull, unique, immutable`

### user_id
Constraints: `nonnull, immutable, references(workspace.user)`

### role_id
Constraints: `nonnull, immutable, references(workspace.role)`

## Touched by

| Action | Touch | Notes |
|--------|-------|-------|
