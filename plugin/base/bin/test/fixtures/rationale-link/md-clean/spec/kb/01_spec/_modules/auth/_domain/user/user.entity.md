---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
Grounded in [adr-plt-01-identity-model](../../../../_adr/plt-01-identity-model.adr.md) and [pdd-auth-identity-system](../../../../pdd-auth-identity-system.md).

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
