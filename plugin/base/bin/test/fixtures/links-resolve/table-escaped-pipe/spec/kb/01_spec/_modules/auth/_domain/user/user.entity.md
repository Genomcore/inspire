---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
Every link below sits in a table cell, where a pipe is escaped.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes |
|-------|------|-------|
| `id`  | uuid | Set by [create\|mint](user.create.action.md). |
| `email` | email | Checked by [[auth.user.create\|auth::user::create]]. |
| `name` | text | Owned by [owner\|keeper](user.owner.action.md). |
