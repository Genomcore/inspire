---
id: case.case_assignment
module: case
entity: case_assignment
lifecycle: accepted
---

## Purpose
The row that assigns a case to a staff member, per [[workspace-access]].

## Rationale
The assignment is its own object because [[adr-workspace-01-access]] models an
absent assignment as an absent row.

## Invariants
- `I1` — unique(case_id, user_id) — One assignment per case per staff row.

## Fields

| Field     | Type | Notes                   |
|-----------|------|-------------------------|
| `id`      | uuid | Primary key.            |
| `case_id` | uuid | The case assigned.      |
| `user_id` | uuid | The staff row assigned. |

### id
Constraints: `nonnull, unique, immutable`

### case_id
Constraints: `nonnull, immutable`

### user_id
Constraints: `nonnull, immutable, references(workspace.user)`

## Touched by

| Action | Touch | Notes |
|--------|-------|-------|
