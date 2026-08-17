---
id: auth::user::create
lifecycle: draft
---

# auth::user::create

## Purpose

An organization may override the platform defaults.

The action then writes the row and emits an audit event and returns the id and
closes the transaction and releases the lock and answers the caller at last.
