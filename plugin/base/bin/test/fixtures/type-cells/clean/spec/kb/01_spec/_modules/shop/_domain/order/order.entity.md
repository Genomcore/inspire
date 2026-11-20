---
id: shop.order
module: shop
entity: order
lifecycle: accepted
---

## Purpose
An order.

## Fields

| Field        | Type                  | Notes |
|--------------|-----------------------|-------|
| `id`         | uuid                  | Key.  |
| `status`     | enum                  | Members on the Constraints line. |
| `channel`    | `enum<web,store>`     | Inline members. |
| `total`      | money                 | Project type on a universal base. |
| `placed_at`  | timestamp             | |
| `lines`      | json                  | |
