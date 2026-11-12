---
id: app.list
module: users
screen: list
lifecycle: accepted
---

# Usuarios

**Features:** FEAT-01
**Pattern:** [list](../../../_design-system/patterns/list.pattern.md)

## SCR1: Propósito

Un administrador llega aquí para encontrar a un miembro del espacio entre muchos.

## SCR2: Vínculos

### SCR3: Parámetros

| Clave | En | Tipo | Obligatorio | Notas |
|---|---|---|---|---|
| `q` | query | string | no | el texto de búsqueda |

### SCR4: Datos

| Clave | Acción | Notas |
|---|---|---|
| `main` | [auth::user::get](../../../_modules/auth/_domain/user/user.get.action.md) | el listado, filtrado por param `q` |

### SCR5: Envíos

| Clave | Acción | Disparador | Si tiene éxito | Si falla |
|---|---|---|---|---|
| `create` | [auth::user::create](../../../_modules/auth/_domain/user/user.create.action.md) | acción principal | → [users.detail](detail.screen.md) param `id` | state `gone` |

### SCR6: Navegación

| Clave | Destino | Disparador |
|---|---|---|
| `row` | [users.detail](detail.screen.md) param `id`, param `tab` | pulsar una fila |

### SCR7: Estados

| Clave | Cuándo | Presentación |
|---|---|---|
| `empty` | `main` no devuelve filas | el mensaje de colección vacía |
| `filtered` | `q` tiene valor | el texto de búsqueda en el campo |
