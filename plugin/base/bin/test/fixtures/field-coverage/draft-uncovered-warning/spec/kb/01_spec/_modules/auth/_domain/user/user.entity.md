---
id: auth.user
module: auth
entity: user
lifecycle: draft
---

## Purpose
User entity (draft) — `email` declared but no action touches it.

## Rationale
Identity-model rationale.

## Invariants
None beyond Fields constraints.

## Fields

| Field   | Type  | Notes               |
|---------|-------|---------------------|
| `id`    | uuid  | Primary key.        |
| `email` | email | Unique login.       |
