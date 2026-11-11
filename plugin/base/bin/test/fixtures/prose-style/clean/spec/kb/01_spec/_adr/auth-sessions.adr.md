# Session tokens are opaque

**Status:** design

## Context

A session needs an identifier that travels safely over a network.

## Decision

The server mints an opaque token, and it stores the token beside the user.

## Consequences

A client cannot read anything out of a token.

### Breaking changes

- None.

## Alternatives considered

1. **Signed JWTs.** Rejected, because a revocation costs more.

## Related ADRs

- [[adr-auth-password-hashing]] — a sibling decision.
