---
id: auth.user
module: auth
entity: user
lifecycle: draft
---

## Purpose
Authenticated user.

## Rationale
Identity-model rationale.

## Invariants
None beyond Fields constraints.

## Fields

| Field           | Type      | Notes               |
|-----------------|-----------|---------------------|
| `id`            | uuid      | Primary key.        |
| `email`         | email     | Unique login.       |
| `password_hash` | string    | Argon2id digest.    |
| `created_at`    | timestamp | Set at insert.      |
