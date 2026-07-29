---
id: auth.user
module: auth
entity: user
lifecycle: draft
---

## Purpose
The user account entity, still in design.

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
