---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
Grounded in [[adr-auth-sessions]], for the reasons in [[adr-auth-sessions.rationale]], not in [[adr-auth-cookies.rationale]].

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
