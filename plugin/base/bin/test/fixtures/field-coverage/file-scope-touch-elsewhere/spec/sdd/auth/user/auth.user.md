---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity at accepted — `email` is uncovered, should be error.

## Rationale
Identity-model rationale.

## Invariants
None beyond Fields constraints.

## Fields

| Field   | Type  | Notes               |
|---------|-------|---------------------|
| `id`    | uuid  | Primary key.        |
| `email` | email | Unique login.       |
