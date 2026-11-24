---
id: findings.finding_call
module: findings
entity: finding_call
lifecycle: draft
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
| `depth` | integer | A field. |

### id
Constraints: `nonnull, unique, immutable`

### sample
Constraints: `nonnull`

### depth
Constraints: `default(0)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
