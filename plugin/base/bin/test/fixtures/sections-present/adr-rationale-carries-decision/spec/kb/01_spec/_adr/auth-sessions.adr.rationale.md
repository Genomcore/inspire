# Session tokens are opaque — rationale

**Decision:** [[adr-auth-sessions]]

## Context
Sessions need a transport-safe identifier.

## Consequences
Clients cannot introspect a token.

### Breaking changes
- None.

## Alternatives considered
1. **Signed JWTs.** Rejected: revocation is harder.

## Related ADRs
- [[adr-auth-password-hashing]] — sibling decision.

## Decision
Session tokens are opaque.
