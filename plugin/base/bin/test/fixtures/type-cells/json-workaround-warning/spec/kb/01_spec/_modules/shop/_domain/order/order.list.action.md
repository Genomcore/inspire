---
id: shop::order::list
module: shop
entity: order
action: list
lifecycle: stable
---

## Purpose
List orders.

## Inputs

| Parameter | Type    | Required | Description |
|-----------|---------|----------|-------------|
| `limit`   | integer | no       | Page size.  |

## Outputs

| Field                 | Type    | Description |
|-----------------------|---------|-------------|
| `items`               | list    | One row per order. |
| `items[].id`          | uuid    | The order. |
| `items[].buyer`       | object  | Who placed it. |
| `items[].buyer.id`    | uuid    | The buyer. |
