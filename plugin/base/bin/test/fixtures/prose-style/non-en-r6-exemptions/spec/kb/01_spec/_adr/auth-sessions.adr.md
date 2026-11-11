# Los tokens de sesión son opacos

**Status:** superseded by [[adr-auth-sessions-v2]]

## ADR1: Contexto

**Status:** la ruta servía anteriormente una cookie.
La cadena de consulta llevaba anteriormente el identificador.

## ADR2: Decisión

El servidor emite un token opaco.

## ADR3: Consecuencias

Un cliente no puede leer el token.

### ADR4: Cambios incompatibles

- La ruta devolvía anteriormente un JWT.
- ~~La cabecera antigua~~ no tiene lector.

## ADR6: ADRs relacionados

- [[adr-auth-password-hashing]] — esto vivía anteriormente allí.
