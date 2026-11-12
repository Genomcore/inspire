---
id: nightly-close
lifecycle: accepted
---
# Nightly close
## Trigger
Every night at 02:00 UTC.

## Requires
- [billing::invoice::close](../_domain/invoice/invoice.close.action.md)

## Behaviour
- B1: close every overdue invoice.

## Affects
- [billing::invoice](../_domain/invoice/invoice.entity.md)
