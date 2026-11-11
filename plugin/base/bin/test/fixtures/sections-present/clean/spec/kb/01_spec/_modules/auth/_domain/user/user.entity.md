---
id: auth.user
module: auth
entity: user
lifecycle: draft
---

## Purpose
The user account entity.

## Rationale
Identity model rationale.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |

## Touched by

| Action                                  | Touch   | Notes             |
|-----------------------------------------|---------|-------------------|
| [[auth.user.create|auth::user::create]] | write   | Inserts the row.  |
