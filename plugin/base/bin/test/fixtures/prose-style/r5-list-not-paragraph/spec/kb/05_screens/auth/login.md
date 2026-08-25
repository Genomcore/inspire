---
id: auth.login
module: auth
screen: login
lifecycle: draft
---

# Sign in

**Features:** FEAT-01
**Pattern:** [[../patterns/form]]

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[auth.session.read\|auth::session::read]] | the current session |

## Module-specific deviations

- The first row of the list.
- The second row of the list.
- The third row of the list.
- The fourth row of the list.
- The fifth row of the list.
- The sixth row of the list.
- The seventh row of the list.
- The eighth row of the list.

## Notes

The action creates a user. The tenant owns that user. An email names the user.
A password guards the user. A session follows the sign-in. An audit event trails
the write. A ticket tracks the rest.
