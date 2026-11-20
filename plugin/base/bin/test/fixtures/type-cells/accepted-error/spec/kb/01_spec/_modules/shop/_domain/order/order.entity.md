---
id: shop.order
module: shop
entity: order
lifecycle: accepted
---

## Purpose
An order.

## Fields

| Field      | Type     | Notes |
|------------|----------|-------|
| `id`       | uuid     | Key.  |
| `shipping` | address  | Not declared anywhere. |
| `tenant`   | tenant   | Project type with no base. |
