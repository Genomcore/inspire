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
Crear un usuario.

## ACT2: Entradas

| Parameter | Type  | Required | Description |
|-----------|-------|----------|-------------|
| `email`   | email | yes      | Acceso.     |

## ACT3: Salidas

| Field | Type | Description          |
|-------|------|----------------------|
| `id`  | uuid | Id del nuevo usuario.|

## ACT4: Entidades

### [[auth.user|auth::user]]
**Effect:** create

| Field | Touch   | Type | Mapping  | Notes |
|-------|---------|------|----------|-------|
| `id`  | written | uuid | `uuid()` |       |

## ACT6: Comportamiento
1. Persistir.

## ACT8: Errores
- `none`
