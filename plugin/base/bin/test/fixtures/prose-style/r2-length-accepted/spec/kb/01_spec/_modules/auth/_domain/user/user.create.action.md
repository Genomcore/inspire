---
id: auth::user::create
lifecycle: accepted
---

# auth::user::create

## Purpose

When the operator submits the form the system validates the email against the tenant's domain allow-list and, if that passes, hashes the password and writes the user row, emitting an audit event afterwards and answering the caller with the new identifier once the transaction commits.
