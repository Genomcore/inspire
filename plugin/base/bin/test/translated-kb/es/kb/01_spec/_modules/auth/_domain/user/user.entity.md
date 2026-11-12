---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## ENT1: Propósito
La entidad de cuenta de usuario, fundamentada en [adr-auth-sessions](../../_adr/auth-sessions.adr.md).

## ENT2: Justificación
El modelo de identidad sigue [adr-auth-sessions](../../_adr/auth-sessions.adr.md).

## ENT3: Invariantes
- `I1` — unique(org_id, email) — Un correo es único por organización.
- `I2` — unique(nickname) — Un apodo es único.

## ENT4: Campos

| Nombre   | Tipo  | Notas                              |
|----------|-------|------------------------------------|
| `id`     | uuid  | La clave primaria.                 |
| `org_id` | uuid  | La organización propietaria.       |
| `email`  | email | El identificador canónico de acceso. |

### id
Constraints: `nonnull, unique, immutable`

### org_id
Constraints: `nonnull, immutable`

### email
Constraints: `nonnull, pattern(/.+@.+/)`

### ghost
Constraints: `nonnull`

## ENT5: Modificada por

| Acción | Contacto | Notas |
|---|---|---|
| [auth::user::create](user.create.action.md) | write | Inserta la fila. |
| [auth::user::get](user.get.action.md) | read | Lee una fila. |
