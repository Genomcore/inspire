---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: superseded
requires:
  - "[[auth.user.gone|auth::user::gone]]"
superseded_by: "[[auth.user.next|auth::user::next]]"
---

## Purpose
Create a user.
