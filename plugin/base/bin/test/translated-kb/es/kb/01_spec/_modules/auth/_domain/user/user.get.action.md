---
id: auth::user::get
module: auth
entity: user
action: get
lifecycle: accepted
requires: []
superseded_by: null
---

## ACT1: Propósito
Leer una cuenta de usuario, según [adr-auth-sessions](../../_adr/auth-sessions.adr.md).

## ACT2: Entradas

| Parámetro | Tipo | Obligatorio | Descripción          |
|-----------|------|-------------|----------------------|
| `id`      | uuid | yes         | La cuenta a leer.    |

## ACT3: Salidas
La fila completa de [auth::user](user.entity.md).

## ACT4: Entidades

### [auth::user](user.entity.md)
**Effect:** read

| Campo    | Contacto | Tipo  | Correspondencia | Notas |
|----------|----------|-------|-----------------|-------|
| `id`     | read     | uuid  | `id`            |       |
| `org_id` | read     | uuid  |                 |       |
| `email`  | read     | email |                 |       |

## ACT5: Precondiciones
None.

## ACT6: Comportamiento
1. `B1` — Cargar la fila.

## ACT7: Postcondiciones
None.

## ACT8: Errores
- `not_found` — mensaje para el operador: "Cuenta desconocida."
