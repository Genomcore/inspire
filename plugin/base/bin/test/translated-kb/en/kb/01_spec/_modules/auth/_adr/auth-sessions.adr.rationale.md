# Session tokens are opaque — rationale

**Decision:** [[adr-auth-sessions]]

## ADR1: Context
A session needs an identifier that travels safely over a network.

## ADR3: Consequences
A client cannot read anything out of a token.

### ADR4: Breaking changes
- None.

## ADR5: Alternatives considered
1. **Signed JWTs.** Rejected, because a revocation costs more.

## ADR6: Related ADRs
- None.
