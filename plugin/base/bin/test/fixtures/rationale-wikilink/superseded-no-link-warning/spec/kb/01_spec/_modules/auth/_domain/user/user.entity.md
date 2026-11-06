---
id: auth.user
module: auth
entity: user
lifecycle: superseded
superseded_by: auth.account
---

## Purpose
The retired user entity, replaced by the account entity.

## Rationale
We needed a user account. No back-sourcing here on purpose: the object is
history, so the missing wikilink is a warning, not an error.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
