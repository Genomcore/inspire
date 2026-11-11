# Los tokens de sesión son opacos — justificación

**Decision:** [[adr-auth-sessions]]

## ADR1: Contexto
Las sesiones necesitan un identificador seguro en tránsito.

## ADR3: Consecuencias
Los clientes no pueden inspeccionar un token.

### ADR4: Cambios incompatibles
- Ninguno.

## ADR5: Alternativas consideradas
1. **JWT firmados.** Descartado: la revocación es más difícil.

## ADR6: ADR relacionados
- [[adr-auth-password-hashing]] — decisión hermana.
