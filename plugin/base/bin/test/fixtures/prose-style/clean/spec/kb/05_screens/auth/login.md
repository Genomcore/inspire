---
id: auth.login
module: auth
screen: login
lifecycle: draft
---

# Sign in

**Features:** FEAT-01
**Pattern:** [[../patterns/form]]

## Purpose

A returning member arrives here with no session and wants one. The form asks
for an email and a password, and nothing else competes for attention.

## Bindings

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `sign-in` | [[auth.session.create\|auth::session::create]] | primary action | → [[auth.home]] | state `denied` |

### States

| Key | When | Presentation |
|---|---|---|
| `denied` | `sign-in` rejects | the form keeps the email |
