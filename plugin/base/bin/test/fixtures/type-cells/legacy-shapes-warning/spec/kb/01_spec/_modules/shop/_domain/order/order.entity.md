---
id: shop.order
module: shop
entity: order
lifecycle: accepted
---

## Fields

| Field          | Type   | Notes |
|----------------|--------|-------|
| `id`           | uuid   | Key. |
| `address.city` | string | A dotted field name. |
| `extra`        | record | Project type named record. |
