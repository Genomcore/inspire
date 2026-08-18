# Session tokens are opaque

**Status:** design

## Context
Sessions need a transport-safe identifier.

## Decision
Session tokens are opaque strings, minted server-side.

## Consequences
Clients cannot introspect a token.

<!--
### Breaking changes
- commented out while we work out whether anything actually breaks
-->

## Alternatives considered
1. **Signed JWTs.** Rejected: revocation is harder.

## Related ADRs
- [[adr-auth-password-hashing]] — sibling decision.
