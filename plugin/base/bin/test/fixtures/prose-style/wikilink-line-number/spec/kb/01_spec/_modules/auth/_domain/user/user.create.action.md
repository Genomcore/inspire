---
id: auth::user::create
lifecycle: draft
---

# auth::user::create

## Purpose

The action creates a user.

The action follows the model recorded in [[adr-auth-sessions]] and hashes the password with a very long sentence that runs well past the word signal on purpose, so the locator has a wikilink-bearing line to find and report.
