---
id: shop::order::search
module: shop
entity: order
action: search
lifecycle: accepted
---

## Purpose
Search orders.

## Inputs

| Parameter | Type      | Required | Description |
|-----------|-----------|----------|-------------|
| `ids`     | list<int> | no       | Only these orders. |

## Outputs

| Field          | Type             | Description |
|----------------|------------------|-------------|
| `a`            | list<address>    | Unknown element. |
| `b`            | list<>           | No element. |
| `c`            | list<list<uuid>> | A list of lists. |
| `d`            | list             | No element, not declared. |
| `e`            | array<uuid>      | Another spelling. |
| `f`            | object           | Another spelling. |
| `owner`        | record           | No rows under it. |
| `lines[].qty`  | integer          | No parent row. |
| `total`        | integer          | A scalar. |
| `total.cents`  | integer          | Under a scalar. |
| `rows[]`       | uuid             | Names no field. |
| `codes`        | list<uuid>       | A list of scalars. |
| `codes[].x`    | string           | Under a list of scalars. |
