---
lifecycle: accepted
---

# Store: portal

## STO1: Purpose

What the portal keeps between screens.

## STO2: Server keys

| Key | Action | Load | On error | Notes |
|---|---|---|---|---|
| `me` | [auth::user::me](../../_modules/auth/_domain/user/user.me.action.md) | start-up | — | |
| `invoices` | [billing::invoice::list](../../_modules/billing/_domain/invoice/invoice.list.action.md) | first read | — | |

## STO3: Client keys

| Key | Type | Initial | Persist | Notes |
|---|---|---|---|---|
| `currentStudyId` | id | — | local | the study being worked on |

## STO4: On error

| Class | Outcome |
|---|---|
| `unauthenticated` | → [portal.studies](_screens/studies.screen.md) |
| `other` | keep |
