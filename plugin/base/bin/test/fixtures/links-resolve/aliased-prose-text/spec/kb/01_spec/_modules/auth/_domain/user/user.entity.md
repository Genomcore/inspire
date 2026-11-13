---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
The text of a link is for the reader, and no tool reads an id from it:
[the action that mints one](user.create.action.md) resolves by its path, and
[auth::user::create](user.mint.action.md) names the right id in its text and still
points at no file.

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
