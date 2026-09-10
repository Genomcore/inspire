---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
Both halves of a kebab-case module are reachable from another module — the
action [[knowledge-base::entry::promote]] through the id index, and the entity
[[knowledge-base::entry]] through the entity-path map. Neither resolves unless
the domain finders saw the hyphen in the module segment.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
