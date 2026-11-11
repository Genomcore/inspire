# Session tokens are opaque

**Status:** superseded by [[adr-auth-sessions-v2]]
Supersedes: [[adr-auth-cookies]]

## Context

**Status:** the route used to serve a cookie, and the header is written by the gateway.
Supersedes: [[adr-auth-cookies]] — the token used to live there.
The identifier migrated from the query string, and this line is not exempt.

## Decision

The server mints an opaque token.

## Consequences

A client cannot read a token.

### Breaking changes

- The route previously returned a JWT, and it used to accept one as well.
- ~~The legacy header~~ has no reader.

## Alternatives considered

1. **Signed JWTs.** Rejected, because a revocation costs more.

## Related ADRs

- [[adr-auth-password-hashing]] — this used to live there, and it previously did.
