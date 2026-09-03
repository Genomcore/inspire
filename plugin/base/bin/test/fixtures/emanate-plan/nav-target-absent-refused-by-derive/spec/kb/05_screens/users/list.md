---
id: users.list
module: users
screen: list
lifecycle: accepted
---

# Users

**Features:** FEAT-01

## Purpose

An administrator comes here to find one account among many, and leaves for the
one they were looking for — a screen nobody has written yet. `PR-02`'s
navigation arm is a warning, but no vault reaches it: derive refuses the roster
over `DR-R3` first, so the dangling link arrives as `PR-01`, an error.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the roster feed |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `row` | [[users.detail]] | clicking a row |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message |
