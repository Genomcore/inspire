---
id: app.detail
module: users
screen: detail
lifecycle: accepted
---

# Usuario

**Features:** FEAT-01

## SCR1: Propósito

Un administrador llega aquí para leer una cuenta completa.

## SCR2: Vínculos

### SCR3: Parámetros

| Clave | En | Tipo | Obligatorio | Notas |
|---|---|---|---|---|
| `id` | path | uuid | yes | la cuenta mostrada |

### SCR4: Datos

| Clave | Acción | Notas |
|---|---|---|
| `record` | [auth::user::get](../../../_modules/auth/_domain/user/user.get.action.md) | la cuenta indicada por param `id` |

### SCR7: Estados

| Clave | Cuándo | Presentación |
|---|---|---|
| `missing` | `record` no devuelve nada | el mensaje de no encontrado |

## SCR8: Representación

### Table

| Valor | Tipo de campo | Componente | Tratamiento | Alineación | Estrecho |
|---|---|---|---|---|---|
| `email` | email | `link` | texto de cuerpo | left | always |
| `org_id` | uuid | — | atenuado | left | wide |
