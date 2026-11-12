---
id: app.login
module: auth
screen: login
lifecycle: draft
---

<!-- A commented-out header line is not a declaration:
**Features:** FEAT-01
-->
# Sign in

**Pattern:** [form](../../../_design-system/patterns/form.pattern.md)

## Purpose

A returning member arrives here with no session and wants one. The form asks
for an email and a password, and nothing else competes for attention.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [auth::session::read](../../../_modules/auth/_domain/session/session.read.action.md) | the current session |
