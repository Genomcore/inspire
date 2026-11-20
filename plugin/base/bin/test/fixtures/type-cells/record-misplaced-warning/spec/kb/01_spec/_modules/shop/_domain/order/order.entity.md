---
id: shop.order
module: shop
entity: order
lifecycle: draft
---

## Purpose
An order.

## Fields

| Field          | Type         | Notes |
|----------------|--------------|-------|
| `id`           | uuid         | Key.  |
| `tags`         | list<string> | A list of scalars is stored as one value. |
| `address`      | record       | Not here. |
| `address.city` | string       | Not here either. |
