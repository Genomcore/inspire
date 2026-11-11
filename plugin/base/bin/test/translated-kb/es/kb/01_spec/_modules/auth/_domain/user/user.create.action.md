---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: accepted
requires: []
superseded_by: null
---

## ACT1: Propósito
Crear una cuenta de usuario, según [[adr-auth-sessions]].

## ACT2: Entradas

| Parámetro | Tipo  | Obligatorio | Descripción             |
|-----------|-------|-------------|-------------------------|
| `email`   | email | yes         | El identificador de acceso. |

### email
Constraints: `len(3, 254)`

## ACT3: Salidas

| Campo | Tipo | Descripción               |
|-------|------|---------------------------|
| `id`  | uuid | El id del nuevo usuario.  |

## ACT4: Entidades

### [[auth.user|auth::user]]
**Effect:** create

| Campo    | Contacto | Tipo  | Correspondencia | Notas |
|----------|----------|-------|-----------------|-------|
| `id`     | written  | uuid  | `uuid()`        |       |
| `org_id` | written  | uuid  | `current_org`   |       |
| `email`  | written  | email | `input.email`   |       |
| `phone`  | written  | text  | `null`          |       |

## ACT5: Precondiciones
- `P1` — actor(admin) — Solo un administrador da de alta cuentas.

## ACT6: Comportamiento
1. `B1` — Validar el correo.
2. `B2` — Persistir la fila.

## ACT7: Postcondiciones
- `Q1` — created(auth.user) — Existe exactamente una fila.
- `Q2` — returns(id) — Quien llama recibe el identificador.

## ACT8: Errores
- `email_exists` — unique(email) — mensaje para el operador: "Ya existe."
- `email_exists` — unique(org_id) — mensaje para el operador: "Conflicto."
