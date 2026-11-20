---
id: shop::order::get
module: shop
entity: order
action: get
lifecycle: accepted
---

## Purpose
Read one order.

## Inputs

| Parameter | Type    | Required | Description |
|-----------|---------|----------|-------------|
| `id`      | `uuid`  | yes      | The order.  |
| `limit`   | integer | no       | Lines to return. |

## Outputs

| Field              | Type    | Description |
|--------------------|---------|-------------|
| `id`               | uuid    | The order. |
| `items`            | line    | One row per line. |
| `items[].quantity` | integer | How many. |
| `items[].price`    | money   | Unit price. |

## Entities

### [shop.order](order.entity.md)
**As input:** id · **Effect:** read

| Field    | Touch | Type   | Mapping    | Notes |
|----------|-------|--------|------------|-------|
| `id`     | key   | uuid   | `input.id` |       |
| `status` | read  | enum   | —          |       |
| `total`  | read  | money  | —          |       |
