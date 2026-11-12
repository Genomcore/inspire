---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
Sibling cross-reference [auth::user::create](user.create.action.md) resolves, and so
does [adr-auth-sessions](../../../../_adr/auth-sessions.adr.md#decision), a path that
climbs out of the module. A web page ([the spec](https://example.org/spec.md)) and an
anchor in this file ([Fields](#fields)) are not KB links.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
