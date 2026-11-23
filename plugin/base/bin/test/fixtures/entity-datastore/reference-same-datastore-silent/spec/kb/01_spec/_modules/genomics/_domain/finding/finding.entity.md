---
id: genomics.finding
module: genomics
entity: finding
lifecycle: draft
---

## Purpose
The finding entity.

## Rationale
A fixture.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | Primary key. |
| `parent_id` | uuid | The parent row. |

### id
Constraints: `nonnull, unique, immutable`

### parent_id
Constraints: `nonnull, references(genomics.sample)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
