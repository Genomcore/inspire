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

| Parameter | Type         | Required | Description |
|-----------|--------------|----------|-------------|
| `id`      | `uuid`       | yes      | The order.  |
| `limit`   | integer      | no       | Lines to return. |
| `skus`    | list<string> | no       | Only these lines. |

## Outputs

| Field                     | Type           | Description |
|---------------------------|----------------|-------------|
| `id`                      | uuid           | The order. |
| `items`                   | `list<record>` | One row per line. |
| `items[].quantity`        | integer        | How many. |
| `items[].price`           | money          | Unit price. |
| `items[].reservation`     | record         | Who holds it. |
| `items[].reservation.id`  | uuid           | The reservation. |
| `prices`                  | list<money>    | Each line's price. |
| `buyer`                   | record         | Who placed it. |
| `buyer.id`                | uuid           | The buyer. |

## Entities

### [shop.order](order.entity.md)
**As input:** id · **Effect:** read

| Field    | Touch | Type   | Mapping    | Notes |
|----------|-------|--------|------------|-------|
| `id`     | key   | uuid   | `input.id` |       |
| `status` | read  | enum   | —          |       |
| `total`  | read  | money  | —          |       |
