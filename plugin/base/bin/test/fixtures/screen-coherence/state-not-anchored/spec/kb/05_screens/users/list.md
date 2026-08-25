---
id: users.list
module: users
screen: list
lifecycle: draft
---

# Users

**Features:** FEAT-01

## Purpose

An administrator comes here to find one member of the workspace among many.
The roster leads, so the reader sees who exists before choosing anyone to act
on.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
| `offline` | a deviation of this module covers the offline case | a banner |
| `sparkly` | the mood takes it | confetti |
