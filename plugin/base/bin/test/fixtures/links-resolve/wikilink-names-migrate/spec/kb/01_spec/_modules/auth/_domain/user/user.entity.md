---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
Minted by [auth::user::create](user.create.action.md), and by the same action again
through a wikilink that still resolves: [[auth.user.create|auth::user::create]]. A
second wikilink to it is the same finding: [[auth.user.create]].

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
