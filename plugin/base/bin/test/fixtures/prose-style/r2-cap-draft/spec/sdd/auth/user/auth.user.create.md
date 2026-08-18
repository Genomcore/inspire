---
id: auth::user::create
lifecycle: draft
---

# auth::user::create

## Purpose

When the operator submits the form the system validates the email against the tenant's domain allow-list and, if that passes, hashes the password and writes the user row, emitting an audit event afterwards.
