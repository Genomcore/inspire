---
id: portal.orders
module: orders
screen: list
lifecycle: accepted
---
# Orders
## Bindings
### Data
| Key | Action | Notes |
|---|---|---|
| `main` | [orders::order::list](../../../_modules/orders/_domain/order/order.list.action.md) | feed |
### Dispatches
| Key | Action | Outcome |
|---|---|---|
| `close` | [billing::invoice::close](../../../_modules/billing/_domain/invoice/invoice.close.action.md) | refresh `main` |
| `pay` | [billing::invoice::pay](../../../_modules/billing/_domain/invoice/invoice.pay.action.md) | refresh `main` |
