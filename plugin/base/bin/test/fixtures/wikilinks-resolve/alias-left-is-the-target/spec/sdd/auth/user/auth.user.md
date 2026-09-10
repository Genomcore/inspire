---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
An aliased prose link puts the target on the left and a phrase a human reads on
the right: [[auth.user.create|the action that mints one]]. The target is what
must resolve, and the phrase is never looked up.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
