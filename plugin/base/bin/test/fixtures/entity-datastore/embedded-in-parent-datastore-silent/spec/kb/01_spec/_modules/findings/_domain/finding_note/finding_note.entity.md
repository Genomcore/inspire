---
id: findings.finding_note
module: findings
entity: finding_note
lifecycle: draft
datastore: analytics
embedded_in: findings.molecular_finding
---

## Purpose
The finding_note entity.

## Rationale
A fixture.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | A field. |
| `text` | string | A field. |

### id
Constraints: `nonnull, unique, immutable`

## Touched by

| Action | Touch | Notes |
|---|---|---|
