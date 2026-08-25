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
| `main` | [[auth.user.search\|auth::user::search]] | a second feed under one key |
|  | [[auth.user.count\|auth::user::count]] | a row that keys nothing |

### Slots

| Key | What the screen provides |
|---|---|
| `title` | the collection's name |
