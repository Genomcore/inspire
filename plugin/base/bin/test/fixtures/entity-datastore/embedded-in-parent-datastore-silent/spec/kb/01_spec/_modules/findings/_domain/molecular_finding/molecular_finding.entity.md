---
id: findings.molecular_finding
module: findings
entity: molecular_finding
lifecycle: draft
datastore: analytics
---

## Purpose
The molecular_finding entity.

## Rationale
A fixture.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | A field. |
| `gene` | string | A field. |

### id
Constraints: `nonnull, unique, immutable`

### gene
Constraints: `nonnull`

## Touched by

| Action | Touch | Notes |
|---|---|---|
