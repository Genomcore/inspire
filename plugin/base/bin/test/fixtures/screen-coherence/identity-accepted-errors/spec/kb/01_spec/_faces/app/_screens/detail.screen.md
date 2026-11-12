---
id: nowhere.detail
module: users
screen: detail
lifecycle: accepted
---

# People

**Features:** FEAT-01

## Purpose

A coordinator comes here to find one person in the directory among many. The
list leads, so the reader sees who exists before choosing anyone to open.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [auth::user::list](../../../_modules/auth/_domain/user/user.list.action.md) | the primary table feed |
