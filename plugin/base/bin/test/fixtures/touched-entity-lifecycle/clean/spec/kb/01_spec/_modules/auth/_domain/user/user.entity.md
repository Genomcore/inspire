---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
The user account entity.

## Rationale
Identity model.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |

## Touched by

| Action                                  | Touch | Notes |
|-----------------------------------------|-------|-------|
| [[auth.user.create|auth::user::create]] | write | Insert. |
