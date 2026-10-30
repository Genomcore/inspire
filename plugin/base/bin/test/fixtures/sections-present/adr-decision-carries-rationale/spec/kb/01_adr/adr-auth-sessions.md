---
# surfaces: [console]
---

# Session tokens are opaque

**Status:** design
**Modules affected:** [[auth]]
**Rationale:** [[adr-auth-sessions.rationale]]
<!-- Status maturity ladder: design | prototyped | implemented | superseded by [[x]] | rejected.
     ## Context is named here on purpose: a guidance comment is not a section. -->

## Decision
Session tokens are opaque strings, minted server-side.

## Context
Sessions need a transport-safe identifier.

## Related ADRs
- None.
