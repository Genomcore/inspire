# Los tokens de sesión son opacos — justificación

**Decision:** [adr-auth-sessions](auth-sessions.adr.md)

## ADR1: Contexto
Una sesión necesita un identificador que viaje seguro por la red.

## ADR3: Consecuencias
Un cliente no puede leer nada de un token.

### ADR4: Cambios incompatibles
- Ninguno.

## ADR5: Alternativas consideradas
1. **JWT firmados.** Descartado, porque revocarlos cuesta más.

## ADR6: ADR relacionados
- Ninguno.
