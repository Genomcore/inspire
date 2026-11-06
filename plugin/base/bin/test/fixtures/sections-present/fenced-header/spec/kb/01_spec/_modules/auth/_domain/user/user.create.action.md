---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Create a user. The `## Errors` section is quoted inside a fence below and
declared nowhere, so it is missing: a header inside a fenced code block
documents a section, it does not declare one.

## Inputs

| Parameter | Type  | Required | Description |
|-----------|-------|----------|-------------|
| `email`   | email | yes      | Login.      |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | New user id.|

## Entities

### [[auth.user|auth::user]]
**Effect:** create

| Field | Touch   | Type | Mapping  | Notes |
|-------|---------|------|----------|-------|
| `id`  | written | uuid | `uuid()` |       |

## Behavior

```markdown
## Errors
- `auth::user::duplicate` — the address is taken.
```

1. Persist. The fence above is the shape an error list takes; this section is
   non-empty and must not be cut short by the header quoted inside it.
