---
# surfaces: [console]
---

# Session tokens are opaque

**Status:** design
**Modules affected:** [[auth]]
<!-- Status maturity ladder: design | prototyped | implemented | superseded by [[x]] | rejected.
     design = the design workspace.
     ## Consequences is named here on purpose: a guidance comment is not a section. -->

## Context
Sessions need a transport-safe identifier.

## Decision
Session tokens are opaque strings, minted server-side.

## Consequences
Clients cannot introspect a token.

### Breaking changes
- None.

## Alternatives considered
1. **Signed JWTs.** Rejected: revocation is harder.

## Related ADRs
- [[adr-auth-password-hashing]] — sibling decision.
