---
id: auth.user
module: auth
entity: user
lifecycle: draft
---

## Purpose
User entity.

## Rationale
Grounded in [adr-auth-sessions](../../../../_adr/auth-sessions.adr.md), which exists, and
in [adr-auth-gone](../../../../_adr/auth-gone.adr.md), which does not. The action is a
sibling, so a path that climbs one level names nothing:
[auth::user::create](../user.create.action.md). A draft is no excuse.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
