---
id: auth::user::update
module: auth
entity: user
action: update
lifecycle: accepted
requires:
  - "[auth::user::create](user.create.action.md)"
superseded_by: "[auth::user::replace](user.replace.action.md)"
---

## Purpose
Update a user. The links that matter are in the frontmatter.
