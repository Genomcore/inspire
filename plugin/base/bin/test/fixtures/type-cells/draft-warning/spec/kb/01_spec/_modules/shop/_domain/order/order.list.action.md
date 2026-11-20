---
id: shop::order::list
module: shop
entity: order
action: list
lifecycle: draft
---

## Purpose
List orders.

## Inputs

| Parameter | Type         | Required | Description |
|-----------|--------------|----------|-------------|
| `cursor`  | varchar(64)  | no       | Where to resume. |

## Outputs

| Field             | Type   | Description |
|-------------------|--------|-------------|
| `items`           | list   | One row per order. |
| `items[].id`      | uuid   | The order. |

## Entities

### [shop.order](order.entity.md)
**Effect:** read

| Field      | Touch | Type | Mapping | Notes |
|------------|-------|------|---------|-------|
| `id`       | read  | uuid | —       |       |
| `quantity` | read  | bool | —       |       |
