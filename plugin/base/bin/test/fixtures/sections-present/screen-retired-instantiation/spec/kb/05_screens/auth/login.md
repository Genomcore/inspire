---
id: auth.login
module: auth
screen: login
lifecycle: draft
---

# Sign in

**Features:** FEAT-01

## Purpose

A returning member arrives here with no session and wants one. The form asks
for an email and a password, and nothing else competes for attention.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.session.read\|auth::session::read]] | the current session |

## Instantiation

- **Data:** the `auth::user` entity.
