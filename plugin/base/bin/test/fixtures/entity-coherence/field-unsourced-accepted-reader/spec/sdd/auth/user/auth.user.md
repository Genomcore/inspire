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

| Field       | Type      | Notes         |
|-------------|-----------|---------------|
| `id`        | uuid      | Primary key.  |
| `last_seen` | timestamp | Last seen.    |
