---
id: auth::user::create
lifecycle: draft
---

# auth::user::create

## Purpose

The `organization` column keeps the id, and [[org.workspace|org::workspace]] holds the rest.

The action then writes the row and emits an audit event and returns the id and
closes the transaction and releases the lock and answers the caller at last.
