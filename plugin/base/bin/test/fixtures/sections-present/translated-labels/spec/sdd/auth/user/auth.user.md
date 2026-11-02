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

## Fields: Campos

| Field | Type | Notes          |
|-------|------|----------------|
| `id`  | uuid | Clave primaria.|

## Touched by: Modificada por

| Action                                  | Touch   | Notes            |
|-----------------------------------------|---------|------------------|
| [[auth.user.create|auth::user::create]] | write   | Inserta la fila. |
