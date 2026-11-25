---
name: ch
description: "clickhouse conventions."
stack: clickhouse
layer: backend
---

## Layering

Not applicable.

## Persistence

One table per entity; an embedded entity is one array per field of its parent's table.
