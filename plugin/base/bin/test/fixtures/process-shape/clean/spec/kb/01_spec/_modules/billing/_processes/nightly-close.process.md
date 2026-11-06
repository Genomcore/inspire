---
id: billing.nightly-close
lifecycle: accepted
---
# Nightly close
## Trigger
Every night at 02:00 UTC.

## Requires
- [[billing.invoice.close|billing::invoice::close]]

## Behaviour
- B1: close every overdue invoice.

## Affects
- [[billing.invoice|billing::invoice]]
