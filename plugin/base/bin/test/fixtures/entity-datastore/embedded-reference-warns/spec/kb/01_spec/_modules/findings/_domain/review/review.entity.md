---
id: findings.review
module: findings
entity: review
lifecycle: draft
---

## Purpose
The review entity.

## Rationale
A fixture.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | uuid | A field. |
| `call_id` | uuid | A field. |

### id
Constraints: `nonnull, unique, immutable`

### call_id
Constraints: `references(findings.finding_call)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
