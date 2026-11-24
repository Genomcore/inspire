---
id: shop::order::list
module: shop
entity: order
action: list
lifecycle: accepted
---

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ids[]`   | uuid | no       | A list written with brackets. |

## Outputs

| Field              | Type     | Description |
|--------------------|----------|-------------|
| `A`                | json     | (A) universal json with rows under it. |
| `A[].id`           | uuid     | |
| `meta.total`       | integer  | (B) dotted row, no parent row. |
| `C`                | rows     | (C) project type on json, rows under it. |
| `C[].id`           | uuid     | |
| `D`                | tag_list | (D) project type on string, rows under it. |
| `D[].name`         | string   | |
| `E`                | record   | (E) project type named record, no rows. |
