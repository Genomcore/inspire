---
id: shop::order::create
module: shop
entity: order
action: create
lifecycle: accepted
---

## Purpose
Place an order.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `note`    | —    | no       | Free text.  |

## Outputs

| Field     | Type          | Description |
|-----------|---------------|-------------|
| `id`      | uuid          | The order.  |
| `balance` | ledger_amount | What the ledger holds. |

## Entities

### [shop.order](order.entity.md)
**Effect:** create

| Field      | Touch   | Type | Mapping          | Notes |
|------------|---------|------|------------------|-------|
| `id`       | written | uuid | `uuid()`         |       |
| `shipping` | written | text | `input.shipping` |       |
