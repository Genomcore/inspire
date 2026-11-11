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
| `main` | [[orders.order.list\|orders::order::list]] | feed |
### Dispatches
| Key | Action | Outcome |
|---|---|---|
| `close` | [[billing.invoice.close\|billing::invoice::close]] | refresh `main` |
| `pay` | [[billing.invoice.pay\|billing::invoice::pay]] | refresh `main` |
