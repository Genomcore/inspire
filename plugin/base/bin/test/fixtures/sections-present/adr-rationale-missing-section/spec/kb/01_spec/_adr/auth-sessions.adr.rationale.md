# Session tokens are opaque — rationale

**Decision:** [[adr-auth-sessions]]

## Context
Sessions need a transport-safe identifier.

## Consequences
Clients cannot introspect a token.


## Related ADRs
- [[adr-auth-password-hashing]] — sibling decision.
