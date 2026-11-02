---
id: auth::user::create
module: auth
entity: user
action: create
lifecycle: accepted
requires: []
superseded_by: null
---

## Purpose: Propósito
Crear un usuario.

## Inputs: Entradas

| Parameter | Type  | Required | Description |
|-----------|-------|----------|-------------|
| `email`   | email | yes      | Acceso.     |

## Outputs: Salidas

| Field | Type | Description          |
|-------|------|----------------------|
| `id`  | uuid | Id del nuevo usuario.|

## Entities: Entidades

### [[auth.user|auth::user]]
**Effect:** create

| Field | Touch   | Type | Mapping  | Notes |
|-------|---------|------|----------|-------|
| `id`  | written | uuid | `uuid()` |       |

## Behavior: Comportamiento
1. Persistir.

## Errors: Errores
- `none`
