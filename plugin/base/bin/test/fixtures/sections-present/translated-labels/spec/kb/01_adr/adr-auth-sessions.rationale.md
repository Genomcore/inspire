# Los tokens de sesión son opacos — justificación

**Decision:** [[adr-auth-sessions]]

## Context: Contexto
Las sesiones necesitan un identificador seguro en tránsito.

## Consequences: Consecuencias
Los clientes no pueden inspeccionar un token.

### Breaking changes: Cambios incompatibles
- Ninguno.

## Alternatives considered: Alternativas consideradas
1. **JWT firmados.** Descartado: la revocación es más difícil.

## Related ADRs: ADR relacionados
- [[adr-auth-password-hashing]] — decisión hermana.
