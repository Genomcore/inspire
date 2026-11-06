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
Create a user. This descriptor documents markdown *about* markdown, which is
where a boolean fence toggle breaks: the outer fences below quote inner fence
markers, and the sections after them must still be read.

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

A four-backtick fence quoting an unbalanced three-backtick one — a toggle would
be left stuck open here, swallowing every section below:

````markdown
Open a code block like this:
```
````

A backtick fence quoting the other marker character — a toggle would close on
the inner `~~~`, exposing the header it wraps:

```markdown
~~~
## Errors
quoted, not declared
~~~
```

1. Persist.

## Errors
- `none`
