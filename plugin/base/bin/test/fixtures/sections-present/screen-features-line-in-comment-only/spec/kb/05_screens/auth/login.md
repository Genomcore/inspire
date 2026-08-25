---
id: auth.login
module: auth
screen: login
lifecycle: draft
---

<!-- A commented-out header line is not a declaration:
**Features:** FEAT-01
-->
# Sign in

**Pattern:** [[../patterns/form]]

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.session.read\|auth::session::read]] | the current session |
