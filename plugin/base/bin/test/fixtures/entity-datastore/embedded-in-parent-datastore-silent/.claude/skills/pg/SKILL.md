---
name: pg
description: "postgres conventions."
stack: postgres
layer: backend
---

## Layering

Not applicable.

## Persistence

One table per entity; an embedded entity is one array per field of its parent's table.
