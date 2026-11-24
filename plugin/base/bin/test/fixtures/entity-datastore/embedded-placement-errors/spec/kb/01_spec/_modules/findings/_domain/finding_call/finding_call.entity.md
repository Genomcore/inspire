---
id: findings.finding_call
module: findings
entity: finding_call
lifecycle: draft
datastore: analytics
embedded_in: findings.molecular_finding
---

## Purpose
The finding_call entity.

## Rationale
A fixture.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | A field. |
| `sample` | string | A field. |
| `taken_at` | timestamp | A field. |

### id
Constraints: `nonnull, unique, immutable`

### sample
Constraints: `nonnull, unique`

### taken_at
Constraints: `immutable`

## Touched by

| Action | Touch | Notes |
|---|---|---|
