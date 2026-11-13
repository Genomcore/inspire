---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## ENT1: Propósito
La cuenta de usuario.

## ENT2: Justificación
Modelo de identidad.

## ENT3: Invariantes
None beyond Fields constraints.

## ENT4: Campos

| Field | Type | Notes          |
|-------|------|----------------|
| `id`  | uuid | Clave primaria.|

## ENT5: Modificada por

| Action                                  | Touch   | Notes            |
|-----------------------------------------|---------|------------------|
| [auth::user::create](user.create.action.md) | write   | Inserta la fila. |
