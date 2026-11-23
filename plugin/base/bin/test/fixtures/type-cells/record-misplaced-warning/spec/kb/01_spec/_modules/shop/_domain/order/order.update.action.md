---
id: shop::order::update
module: shop
entity: order
action: update
lifecycle: draft
---

## Purpose
Change an order.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id`      | uuid | yes      | The order.  |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | The order.  |

## Entities

### [shop.order](order.entity.md)
**As input:** id · **Effect:** update

| Field     | Touch   | Type          | Mapping         | Notes |
|-----------|---------|---------------|-----------------|-------|
| `id`      | key     | uuid          | `input.id`      |       |
| `tags`    | written | list<string>  | `input.tags`    |       |
| `address` | written | list<record>  | `input.address` |       |
