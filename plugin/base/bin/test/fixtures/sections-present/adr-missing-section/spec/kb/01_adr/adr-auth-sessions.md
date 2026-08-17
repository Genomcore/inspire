# Session tokens are opaque

**Status:** design

## Context
Sessions need a transport-safe identifier.

## Decision
Session tokens are opaque strings, minted server-side.

## Consequences
Clients cannot introspect a token.

### Breaking changes
- None.
