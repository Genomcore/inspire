---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: accepted
requires: ["[[auth.user.update|auth::user::update]]"]
---

## Purpose
Create a user. Its frontmatter still holds a wikilink.
