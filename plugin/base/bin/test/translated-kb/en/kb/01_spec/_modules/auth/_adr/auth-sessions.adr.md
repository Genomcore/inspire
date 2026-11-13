# Session tokens are opaque

**Status:** design
**Modules affected:** [auth](../../auth.module.md)
**Rationale:** [adr-auth-sessions.rationale](auth-sessions.adr.rationale.md)

## ADR2: Decision
The server mints an opaque token, and it stores the token beside the user.
