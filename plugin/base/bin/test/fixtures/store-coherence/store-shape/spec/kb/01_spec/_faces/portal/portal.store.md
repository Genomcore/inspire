---
lifecycle: accepted
---

# Store: portal

## STO1: Purpose

What the portal keeps between screens.

## STO2: Server keys

| Key | Action | Load | On error | Notes |
|---|---|---|---|---|
| `me` | the user | start-up | — | |
| `studies` | [studies::study::list](../../_modules/studies/_domain/study/study.list.action.md) | on boot | — | |
| `study` | [studies::study::get](../../_modules/studies/_domain/study/study.get.action.md) | on change of `nope` | retry | |
| `a` | [studies::study::get](../../_modules/studies/_domain/study/study.get.action.md) | on change of `b` | — | |
| `b` | [studies::study::get](../../_modules/studies/_domain/study/study.get.action.md) | on change of `a` | — | |
| `c` | [studies::study::get](../../_modules/studies/_domain/study/study.get.action.md) | on change of `c` | — | |

## STO3: Client keys

| Key | Type | Initial | Persist | Notes |
|---|---|---|---|---|
| `currentStudyId` | id | — | forever | |
| `theme` | — | light | none | |
| `me` | id | — | none | |

## STO4: On error

| Class | Outcome |
|---|---|
| `timeout` | keep |
| `other` | keep |
| `other` | retry |
