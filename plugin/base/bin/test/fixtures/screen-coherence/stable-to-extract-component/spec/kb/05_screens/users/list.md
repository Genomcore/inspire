---
id: users.list
module: users
screen: list
lifecycle: stable
---

# Users

**Features:** FEAT-01
**Components:** [[../components/data-table]], [[../components/bulk-bar]]

## Purpose

An administrator comes here to find one member of the workspace among many.
The roster leads, so the reader sees who exists before choosing anyone to act
on.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.user.list\|auth::user::list]] | the primary table feed |
