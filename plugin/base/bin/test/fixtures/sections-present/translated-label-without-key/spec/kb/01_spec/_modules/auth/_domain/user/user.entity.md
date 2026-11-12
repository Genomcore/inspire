---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose: Propósito
La cuenta de usuario.

## Rationale: Justificación
Modelo de identidad.

## Invariants: Invariantes
None beyond Fields constraints.

## Campos

| Field | Type | Notes          |
|-------|------|----------------|
| `id`  | uuid | Clave primaria.|

## Touched by: Modificada por

| Action                                  | Touch   | Notes            |
|-----------------------------------------|---------|------------------|
| [auth::user::create](user.create.action.md) | write   | Inserta la fila. |
