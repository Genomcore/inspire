---
id: app.list
module: users
screen: list
lifecycle: accepted
---

# Usuarios

**Features:** FEAT-01
**Pattern:** [[../patterns/list]]

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
| `main` | [[auth.user.get\|auth::user::get]] | el listado, filtrado por param `q` |

### SCR5: Envíos

| Clave | Acción | Disparador | Si tiene éxito | Si falla |
|---|---|---|---|---|
| `create` | [[auth.user.create\|auth::user::create]] | acción principal | → [[users.detail]] param `id` | state `gone` |

### SCR6: Navegación

| Clave | Destino | Disparador |
|---|---|---|
| `row` | [[users.detail]] param `id`, param `tab` | pulsar una fila |

### SCR7: Estados

| Clave | Cuándo | Presentación |
|---|---|---|
| `empty` | `main` no devuelve filas | el mensaje de colección vacía |
| `filtered` | `q` tiene valor | el texto de búsqueda en el campo |
