# FEAT-01: Operator sign-in

## Main flow

When the operator submits the form the system validates the email against the tenant's domain allow-list and, if that passes, hashes the password and writes the user row, emitting an audit event afterwards.

## Acceptance criteria

- [ ] AC-1: A wrong password previously returned a detailed error.
