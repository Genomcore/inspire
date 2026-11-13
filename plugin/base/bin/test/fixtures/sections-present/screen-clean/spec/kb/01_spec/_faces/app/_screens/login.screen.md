---
id: app.login
module: auth
screen: login
lifecycle: draft
---

<!-- Required: the identity block, H1, the Features line, ## Purpose, ## Bindings.
## Notes
     Optional / presence-free: ## Module-specific deviations, ## Current prototype, ## Notes.
     This split is the single source of the two lists the validator encodes. -->
# Sign in

**Features:** FEAT-01
**Pattern:** [form](../../../_design-system/patterns/form.pattern.md)

## Purpose

A returning member arrives here with no session and wants one. The form asks
for an email and a password, and nothing else competes for attention.

## Bindings

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `sign-in` | [auth::session::create](../../../_modules/auth/_domain/session/session.create.action.md) | primary action | → [auth.home](../../auth/_screens/home.screen.md) | state `denied` |

### States

| Key | When | Presentation |
|---|---|---|
| `denied` | `sign-in` rejects | the form keeps its email and clears the password |
