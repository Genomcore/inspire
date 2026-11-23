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
| `sample_id` | uuid | A field. |

### id
Constraints: `nonnull, unique, immutable`

### sample_id
Constraints: `nonnull, references(findings.sample)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
