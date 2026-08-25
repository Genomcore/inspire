---
id: auth.login
module: auth
screen: login
lifecycle: draft
---

<!-- Required: the identity block, H1, the Features line, ## Bindings.
## Notes
     Optional / presence-free: ## Module-specific deviations, ## Current prototype, ## Notes.
     This split is the single source of the two lists the validator encodes. -->
# Sign in

**Features:** FEAT-01
**Pattern:** [[../patterns/form]]

## Bindings

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `sign-in` | [[auth.session.create\|auth::session::create]] | primary action | → [[auth.home]] | state `denied` |

### States

| Key | When | Presentation |
|---|---|---|
| `denied` | `sign-in` rejects | the form keeps its email and clears the password |
